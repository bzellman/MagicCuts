import Foundation
import simd

/// A vertical selection through the entire room, expressed in its existing coordinate frame.
nonisolated struct RoomMeshTrim: Codable, Equatable, Sendable {
    var minX: Float
    var maxX: Float
    var minZ: Float
    var maxZ: Float
    var keepSelection = false

    var isValid: Bool {
        [minX, maxX, minZ, maxZ].allSatisfy { $0.isFinite && abs($0) <= 100_000 }
            && maxX - minX >= 0.01 && maxZ - minZ >= 0.01
    }
    func contains(_ point: SpatialVector) -> Bool {
        point.x >= minX && point.x <= maxX && point.z >= minZ && point.z <= maxZ
    }
    private var planes: [(axis: Int, sign: Float, boundary: Float)] {
        [(0, 1, minX), (0, -1, maxX), (2, 1, minZ), (2, -1, maxZ)]
    }

    /// Partitions a convex polygon into its inside and outside portions without capping
    /// the opening or inventing unobserved surfaces. Also works for two-point segments.
    func partition(_ polygon: [SIMD3<Float>]) -> (inside: [SIMD3<Float>], outside: [[SIMD3<Float>]]) {
        var inside = polygon
        var outside: [[SIMD3<Float>]] = []
        for plane in planes {
            guard !inside.isEmpty else { break }
            var next: [SIMD3<Float>] = [], rejected: [SIMD3<Float>] = []
            var a = inside[inside.count - 1]
            var da = (a[plane.axis] - plane.boundary) * plane.sign
            for b in inside {
                let db = (b[plane.axis] - plane.boundary) * plane.sign
                if (da >= 0) != (db >= 0) {
                    var crossing = a + (b - a) * (da / (da - db))
                    crossing[plane.axis] = plane.boundary
                    next.append(crossing); rejected.append(crossing)
                }
                if db >= 0 { next.append(b) } else { rejected.append(b) }
                a = b; da = db
            }
            if !rejected.isEmpty { outside.append(rejected) }
            inside = next
        }
        return (inside, outside)
    }

    func retainsEntireSegment(from start: SpatialVector, to end: SpatialVector) -> Bool {
        if keepSelection { return contains(start) && contains(end) }
        let intersection = partition([start.simd, end.simd]).inside
        guard let first = intersection.first else { return true }
        return intersection.allSatisfy { simd_distance_squared(first, $0) < 1e-12 }
    }

    static func hasArea(_ polygon: [SIMD3<Float>]) -> Bool {
        guard polygon.count >= 3 else { return false }
        return (1..<(polygon.count - 1)).contains {
            simd_length_squared(simd_cross(polygon[$0] - polygon[0], polygon[$0 + 1] - polygon[0])) > 1e-16
        }
    }
}

nonisolated enum RoomMeshTrimmer {
    static func trim(_ source: RoomRevision, selection: RoomMeshTrim, date: Date = .now) throws -> RoomRevision {
        try Task.checkCancellation()
        guard selection.isValid, source.isValid else { throw InstrumentError.storage("Choose a valid area to trim.") }
        var result = source
        result.id = UUID(); result.parentRevisionID = source.id
        result.endedAt = max(source.endedAt, date)
        result.meshTrim = selection
        var changed = false
        result.meshes = try source.meshes.compactMap { patch in
            try Task.checkCancellation()
            let matrix = patch.transform.matrix
            let world = patch.vertices.map { vertex -> SIMD3<Float> in
                let p = matrix * SIMD4(vertex.x, vertex.y, vertex.z, 1)
                return SIMD3(p.x, p.y, p.z)
            }
            var vertices: [SpatialVector] = [], indices: [UInt32] = [], classifications: [UInt8] = []
            var lookup: [SIMD3<Float>: UInt32] = [:]
            var patchChanged = false
            func append(_ polygon: [SIMD3<Float>], classification: UInt8?) {
                guard polygon.count >= 3 else { return }
                for j in 1..<(polygon.count - 1) {
                    let triangle = [polygon[0], polygon[j], polygon[j + 1]]
                    guard simd_length_squared(simd_cross(triangle[1] - triangle[0], triangle[2] - triangle[0])) > 1e-16 else { continue }
                    for point in triangle {
                        if let index = lookup[point] { indices.append(index) }
                        else {
                            let index = UInt32(vertices.count)
                            lookup[point] = index; vertices.append(SpatialVector(point)); indices.append(index)
                        }
                    }
                    if let classification { classifications.append(classification) }
                }
            }
            for i in stride(from: 0, to: patch.triangleIndices.count, by: 3) {
                if i.isMultiple(of: 3000) { try Task.checkCancellation() }
                let triangle = (0..<3).map { world[Int(patch.triangleIndices[i + $0])] }
                let parts = selection.partition(triangle)
                let retained: [[SIMD3<Float>]] = selection.keepSelection ? [parts.inside] : parts.outside
                let untouched = selection.keepSelection ? !parts.outside.contains(where: RoomMeshTrim.hasArea) : !RoomMeshTrim.hasArea(parts.inside)
                if !untouched { patchChanged = true }
                let classification = patch.classifications.isEmpty ? nil : patch.classifications[i / 3]
                if untouched { append(triangle, classification: classification) }
                else { for polygon in retained { append(polygon, classification: classification) } }
            }
            guard patchChanged else { return patch }
            changed = true
            guard !indices.isEmpty else { return nil }
            return RoomMeshPatch(id: patch.id, transform: SpatialTransform(), vertices: vertices,
                                 triangleIndices: indices, classifications: classifications, observedAt: patch.observedAt)
        }
        guard changed else { throw InstrumentError.storage("This selection doesn't remove any captured surfaces. Adjust the area and try again.") }
        guard !result.meshes.isEmpty else { throw InstrumentError.storage("This would remove the entire room. Keep some surfaces or adjust the selection.") }
        // A recognized wall/floor that crosses the cut is no longer a complete semantic
        // object. Retain only untouched components; don't report stale area or volume.
        result.components = source.components.filter { component in
            let corners: [SpatialVector]
            if !component.outline.isEmpty { corners = component.outline }
            else {
                let half = component.dimensions.simd / 2
                corners = [-half.x, half.x].flatMap { x in
                    [-half.z, half.z].map { z in component.transform.worldPoint(.init(x: x, y: 0, z: z)) }
                }
            }
            if selection.keepSelection { return corners.allSatisfy(selection.contains) }
            let lowX = corners.map(\.x).min() ?? 0, highX = corners.map(\.x).max() ?? 0
            let lowZ = corners.map(\.z).min() ?? 0, highZ = corners.map(\.z).max() ?? 0
            return highX < selection.minX || lowX > selection.maxX || highZ < selection.minZ || lowZ > selection.maxZ
        }
        result.dimensions = source.dimensions.filter { selection.retainsEntireSegment(from: $0.start, to: $0.end) }
        result.semanticData = nil
        let warning = "Trimmed from an earlier revision. Recognized elements and dimensions crossing the cut are omitted. Saved readings keep their original positions. The original scan remains in Revisions."
        if !result.warnings.contains(warning) { result.warnings.append(warning) }
        guard result.isValid else { throw InstrumentError.storage("The trimmed mesh exceeds the room's storage limits. Try a smaller cut.") }
        return result
    }
}
