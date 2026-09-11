import Foundation
import simd

nonisolated struct SpatialVector: Codable, Equatable, Sendable {
    var x: Float
    var y: Float
    var z: Float
    init(_ value: SIMD3<Float>) { x = value.x; y = value.y; z = value.z }
    init(x: Float, y: Float, z: Float) { self.x = x; self.y = y; self.z = z }
    var simd: SIMD3<Float> { SIMD3(x, y, z) }
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    var isBounded: Bool { isFinite && abs(x) <= 100_000 && abs(y) <= 100_000 && abs(z) <= 100_000 }
    func distance(to other: Self) -> Double { Double(simd_distance(simd, other.simd)) }
}

nonisolated struct SpatialTransform: Codable, Equatable, Sendable {
    var elements: [Float]
    init(_ matrix: simd_float4x4 = matrix_identity_float4x4) {
        elements = (0..<4).flatMap { column in (0..<4).map { matrix[column][$0] } }
    }
    var isValid: Bool {
        guard elements.count == 16, elements.allSatisfy(\.isFinite),
              abs(elements[3]) < 0.001, abs(elements[7]) < 0.001, abs(elements[11]) < 0.001,
              abs(elements[15] - 1) < 0.001, elements[12...14].allSatisfy({ abs($0) <= 100_000 }) else { return false }
        let x = SIMD3(elements[0], elements[1], elements[2]), y = SIMD3(elements[4], elements[5], elements[6]), z = SIMD3(elements[8], elements[9], elements[10])
        return abs(simd_length(x) - 1) < 0.02 && abs(simd_length(y) - 1) < 0.02 && abs(simd_length(z) - 1) < 0.02
            && abs(simd_dot(x, y)) < 0.02 && abs(simd_dot(x, z)) < 0.02 && abs(simd_dot(y, z)) < 0.02
            && simd_dot(simd_cross(x, y), z) > 0.98
    }
    var matrix: simd_float4x4 {
        guard isValid else { return matrix_identity_float4x4 }
        return simd_float4x4(columns: (
            SIMD4(elements[0], elements[1], elements[2], elements[3]),
            SIMD4(elements[4], elements[5], elements[6], elements[7]),
            SIMD4(elements[8], elements[9], elements[10], elements[11]),
            SIMD4(elements[12], elements[13], elements[14], elements[15])))
    }
    var position: SpatialVector { SpatialVector(SIMD3(matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z)) }
    var heading: Double { atan2(Double(-matrix.columns.2.x), Double(matrix.columns.2.z)) }
    func worldPoint(_ point: SpatialVector) -> SpatialVector {
        let p = matrix * SIMD4(point.x, point.y, point.z, 1)
        return SpatialVector(x: p.x, y: p.y, z: p.z)
    }
}

nonisolated enum SpatialPlacementMethod: String, Codable, Sendable {
    case tracked, relocalized, manual
    var title: String {
        switch self { case .tracked: "Tracked in this scan"; case .relocalized: "Located in saved room"; case .manual: "Placed manually" }
    }
}

nonisolated struct RoomPlacement: Codable, Equatable, Sendable {
    var roomID: UUID
    var revisionID: UUID
    var coordinateFrameID: UUID
    var pose: SpatialTransform
    var observedAt: Date
    var method: SpatialPlacementMethod
    var note: String = ""
    var isValid: Bool { pose.isValid && note.count <= 4000 && observedAt.timeIntervalSinceReferenceDate.isFinite }
}

nonisolated struct RoomMeshPatch: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var transform: SpatialTransform
    var vertices: [SpatialVector]
    var triangleIndices: [UInt32]
    var classifications: [UInt8] = []
    var observedAt: Date
    var isValid: Bool {
        transform.isValid && !vertices.isEmpty && vertices.count <= 500_000 && vertices.allSatisfy(\.isBounded)
            && !triangleIndices.isEmpty && triangleIndices.count.isMultiple(of: 3)
            && triangleIndices.count <= 3_000_000 && triangleIndices.allSatisfy { $0 < vertices.count }
            && (classifications.isEmpty || classifications.count == triangleIndices.count / 3)
    }
}

nonisolated struct RoomComponent: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var category: String
    var transform: SpatialTransform
    var dimensions: SpatialVector
    var confidence: String
    var outline: [SpatialVector] = []
    var complete = false
    var isValid: Bool { transform.isValid && dimensions.isBounded && [dimensions.x, dimensions.y, dimensions.z].allSatisfy { $0 >= 0 } && outline.count <= 1000 && outline.allSatisfy(\.isBounded) && category.count <= 100 && confidence.count <= 100 }
}

nonisolated struct SpatialDimension: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var start: SpatialVector
    var end: SpatialVector
    var createdAt: Date = .now
    var method = "Two selected surface points"
    var meters: Double { start.distance(to: end) }
    var isValid: Bool { start.isBounded && end.isBounded && meters.isFinite && !title.isEmpty && title.count <= 200 && method.count <= 4000 }
}

nonisolated struct RoomTrackingEvent: Codable, Equatable, Sendable {
    var elapsed: Double
    var state: String
}
nonisolated struct RoomCaptureProvenance: Codable, Equatable, Sendable {
    var systemVersion: String
    var deviceFamily: String
    var appVersion: String
    var reconstruction: String
    var depthSource: String
    var events: [RoomTrackingEvent]
    var meshPlaneDetection: String?
    var isValid: Bool {
        [systemVersion, deviceFamily, appVersion, reconstruction, depthSource].allSatisfy { $0.count <= 200 }
            && (meshPlaneDetection?.count ?? 0) <= 200 && events.count <= 1000 && events.allSatisfy { $0.elapsed.isFinite && $0.elapsed >= 0 && $0.state.count <= 200 }
    }
}

nonisolated struct RoomRevision: Codable, Equatable, Identifiable, Sendable {
    var format = 1
    var id = UUID()
    var roomID: UUID
    var roomName: String
    var parentRevisionID: UUID?
    var coordinateFrameID: UUID
    var startedAt: Date
    var endedAt: Date
    var installationID: String
    var meshes: [RoomMeshPatch]
    var components: [RoomComponent] = []
    var dimensions: [SpatialDimension] = []
    var semanticData: Data?
    var worldMapData: Data?
    var referenceImage: Data?
    var alignment: SpatialPlacementMethod
    var warnings: [String] = []
    var demonstration = false
    var provenance: RoomCaptureProvenance?
    var meshTrim: RoomMeshTrim?
    var vertexCount: Int { meshes.reduce(0) { $0 + $1.vertices.count } }
    var triangleCount: Int { meshes.reduce(0) { $0 + $1.triangleIndices.count / 3 } }
    var floorArea: Double? {
        let floors = components.filter { $0.category == "Floor" }
        guard !floors.isEmpty, floors.allSatisfy({ $0.complete }) else { return nil }
        let areas = floors.compactMap { SpatialMath.polygonArea($0.outline) }
        return areas.count == floors.count ? areas.reduce(0, +) : nil
    }
    var estimatedVolume: Double? {
        let walls = components.filter { $0.category == "Wall" }
        let heights = walls.map { Double($0.dimensions.y) }
        guard let area = floorArea, walls.count >= 3, walls.allSatisfy({ $0.confidence == "High" }),
              let low = heights.min(), let high = heights.max(), high - low < 0.15,
              let height = FieldStatistics.percentile(heights, fraction: 0.5) else { return nil }
        return area * height
    }
    var isValid: Bool {
        format == 1 && !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && roomName.count <= 200
            && !installationID.isEmpty && endedAt >= startedAt && !meshes.isEmpty && meshes.count <= 20_000
            && vertexCount <= 2_000_000 && meshes.allSatisfy(\.isValid)
            && components.count <= 10_000 && dimensions.count <= 1000 && warnings.count <= 100 && warnings.allSatisfy { $0.count <= 4000 }
            && components.allSatisfy(\.isValid) && dimensions.allSatisfy(\.isValid)
            && (worldMapData?.count ?? 0) <= 128_000_000 && (semanticData?.count ?? 0) <= 32_000_000
            && (referenceImage?.count ?? 0) <= 16_000_000 && (provenance?.isValid ?? true) && (meshTrim?.isValid ?? true)
    }
    var bounds: (minimum: SpatialVector, maximum: SpatialVector)? {
        var low = SIMD3<Float>(repeating: .infinity), high = SIMD3<Float>(repeating: -.infinity)
        for mesh in meshes {
            let matrix = mesh.transform.matrix
            for vertex in mesh.vertices {
                let p = matrix * SIMD4(vertex.x, vertex.y, vertex.z, 1)
                let v = SIMD3(p.x, p.y, p.z)
                low = simd_min(low, v); high = simd_max(high, v)
            }
        }
        guard low.x.isFinite, high.x.isFinite else { return nil }
        return (SpatialVector(low), SpatialVector(high))
    }
}

nonisolated struct RoomRevisionIndex: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var roomID: UUID
    var roomName: String
    var parentRevisionID: UUID?
    var coordinateFrameID: UUID
    var date: Date
    var vertexCount: Int
    var triangleCount: Int
    var hasWorldMap: Bool
    var demonstration: Bool
    init(_ revision: RoomRevision) {
        id = revision.id; roomID = revision.roomID; roomName = revision.roomName
        parentRevisionID = revision.parentRevisionID; coordinateFrameID = revision.coordinateFrameID
        date = revision.endedAt; vertexCount = revision.vertexCount; triangleCount = revision.triangleCount
        hasWorldMap = revision.worldMapData != nil; demonstration = revision.demonstration
    }
}

nonisolated enum SpatialMath {
    static func polygonArea(_ points: [SpatialVector]) -> Double? {
        guard points.count >= 3, points.count <= 1000, points.allSatisfy(\.isFinite) else { return nil }
        var points = points
        if points.first == points.last { points.removeLast() }
        guard points.count >= 3 else { return nil }
        // Reject crossings and repeated/zero-length edges before presenting a closed-floor estimate.
        func cross(_ a: SpatialVector, _ b: SpatialVector, _ c: SpatialVector) -> Double {
            (Double(b.x) - Double(a.x)) * (Double(c.z) - Double(a.z))
                - (Double(b.z) - Double(a.z)) * (Double(c.x) - Double(a.x))
        }
        func onSegment(_ a: SpatialVector, _ b: SpatialVector, _ c: SpatialVector) -> Bool {
            abs(cross(a, b, c)) < 1e-9 && c.x >= min(a.x, b.x) && c.x <= max(a.x, b.x)
                && c.z >= min(a.z, b.z) && c.z <= max(a.z, b.z)
        }
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            guard hypot(Double(b.x) - Double(a.x), Double(b.z) - Double(a.z)) > 1e-6 else { return nil }
            for j in points.indices where j > i + 1 && !(i == 0 && j == points.count - 1) {
                let c = points[j], d = points[(j + 1) % points.count]
                let abC = cross(a, b, c), abD = cross(a, b, d), cdA = cross(c, d, a), cdB = cross(c, d, b)
                if (abC * abD < 0 && cdA * cdB < 0) || onSegment(a, b, c) || onSegment(a, b, d)
                    || onSegment(c, d, a) || onSegment(c, d, b) { return nil }
            }
        }
        let origin = points[0]
        let twiceArea = points.indices.reduce(0.0) { $0 + cross(origin, points[$1], points[($1 + 1) % points.count]) }
        let area = abs(twiceArea) / 2
        return area > 0.0001 ? area : nil
    }
    static func direction(from pose: SpatialTransform, to point: SpatialVector) -> (meters: Double, radians: Double)? {
        guard pose.isValid, point.isFinite else { return nil }
        let inverse = simd_inverse(pose.matrix)
        let local = inverse * SIMD4(point.x, point.y, point.z, 1)
        guard local.x.isFinite, local.z.isFinite else { return nil }
        return (pose.position.distance(to: point), atan2(Double(local.x), Double(-local.z)))
    }
}
