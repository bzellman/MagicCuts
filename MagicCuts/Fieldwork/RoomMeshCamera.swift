import SwiftUI
import simd

nonisolated enum RoomMeshViewpoint: String, CaseIterable, Sendable {
    case outside = "Outside"
    case inside = "Inside"
}

nonisolated struct RoomMeshCameraLayout: Sendable {
    let minimum: SpatialVector
    let maximum: SpatialVector
    let center: SIMD3<Float>
    let radius: Float
    let interior: SpatialVector

    init(room: RoomRevision) {
        let bounds = room.bounds
        minimum = bounds?.minimum ?? .init(x: -2, y: 0, z: -2)
        maximum = bounds?.maximum ?? .init(x: 2, y: 2.5, z: 2)
        center = (minimum.simd + maximum.simd) / 2
        radius = max(2, simd_length(maximum.simd - minimum.simd))
        // Start above an actually observed low horizontal surface, avoiding the empty
        // center of an L-shaped capture. The plan lets the user choose another spot.
        var floorPoint: SIMD3<Float>?
        var nearest = Float.infinity
        for patch in room.meshes {
            let matrix = patch.transform.matrix
            let vertices = patch.vertices.map { point -> SIMD3<Float> in
                let p = matrix * SIMD4(point.x, point.y, point.z, 1)
                return SIMD3(p.x, p.y, p.z)
            }
            for i in stride(from: 0, to: patch.triangleIndices.count, by: 3) {
                let a = vertices[Int(patch.triangleIndices[i])]
                let b = vertices[Int(patch.triangleIndices[i + 1])]
                let c = vertices[Int(patch.triangleIndices[i + 2])]
                let normal = simd_cross(b - a, c - a)
                let length = simd_length(normal)
                let point = (a + b + c) / 3
                guard length > 1e-8, abs(normal.y) / length > 0.85,
                      point.y < minimum.y + max(0.2, (maximum.y - minimum.y) * 0.15) else { continue }
                let distance = simd_length_squared(SIMD2(point.x - center.x, point.z - center.z))
                if distance < nearest { floorPoint = point; nearest = distance }
            }
        }
        let floor = floorPoint ?? SIMD3(center.x, minimum.y, center.z)
        let height = max(0.05, maximum.y - floor.y)
        interior = SpatialVector(SIMD3(floor.x, floor.y + min(1.5, height * 0.6), floor.z))
    }

    func pose(viewpoint: RoomMeshViewpoint, interior: SpatialVector?, yaw: Float, elevation: Float, zoom: Float)
        -> (position: SIMD3<Float>, target: SIMD3<Float>, fieldOfView: Float) {
        let direction = SIMD3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation))
        switch viewpoint {
        case .outside: return (center + direction * radius * zoom, center, 60)
        case .inside:
            let position = (interior ?? self.interior).simd
            return (position, position + direction, max(30, min(110, 85 * zoom)))
        }
    }
}

struct RoomInteriorPositionControl: View {
    let room: RoomRevision
    let layout: RoomMeshCameraLayout
    @Binding var position: SpatialVector?

    private var current: SpatialVector { position ?? layout.interior }
    var body: some View {
        DisclosureGroup("Move viewpoint") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tap the floor plan to move your viewpoint.").font(.caption).foregroundStyle(ProTheme.secondary)
                RoomPlanCanvas(room: room, proposedPoint: current, onPoint: { position = $0 })
                    .frame(height: 180)
                coordinate("Left / right", axis: \.x, range: layout.minimum.x...layout.maximum.x)
                coordinate("Forward / back", axis: \.z, range: layout.minimum.z...layout.maximum.z)
                coordinate("Height", axis: \.y, range: layout.minimum.y...layout.maximum.y)
            }.padding(.top, 8)
        }
    }
    private func coordinate(_ title: String, axis: WritableKeyPath<SpatialVector, Float>, range: ClosedRange<Float>) -> some View {
        Stepper {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text("\(current[keyPath: axis].formatted(.number.precision(.fractionLength(1)))) m")
                    .font(.callout).foregroundStyle(ProTheme.secondary)
            }
        } onIncrement: { move(axis, by: 0.2, range: range) }
          onDecrement: { move(axis, by: -0.2, range: range) }
    }
    private func move(_ axis: WritableKeyPath<SpatialVector, Float>, by step: Float, range: ClosedRange<Float>) {
        var value = current
        value[keyPath: axis] = min(range.upperBound, max(range.lowerBound, value[keyPath: axis] + step))
        position = value
    }
}

#if DEBUG
#Preview("Inside room controls") {
    RoomMeshCanvas(room: FieldDemo.room()).padding()
}
#endif
