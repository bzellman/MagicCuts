import SwiftUI
import RealityKit
import ARKit
import simd

nonisolated struct RoomProjection: Sendable {
    var center: SIMD2<Float>
    var extent: Float
    init(_ room: RoomRevision) { self.init(bounds: room.bounds) }
    init(bounds: (minimum: SpatialVector, maximum: SpatialVector)?) {
        center = SIMD2(((bounds?.minimum.x ?? -2) + (bounds?.maximum.x ?? 2)) / 2,
                       ((bounds?.minimum.z ?? -2) + (bounds?.maximum.z ?? 2)) / 2)
        extent = max(1, max((bounds?.maximum.x ?? 2) - (bounds?.minimum.x ?? -2),
                            (bounds?.maximum.z ?? 2) - (bounds?.minimum.z ?? -2))) * 1.2
    }
    func screen(_ point: SpatialVector, size: CGSize) -> CGPoint {
        let scale = Float(min(size.width, size.height)) / extent
        return CGPoint(x: Double((point.x - center.x) * scale) + size.width / 2,
                       y: Double((point.z - center.y) * scale) + size.height / 2)
    }
    func world(_ point: CGPoint, size: CGSize, height: Float) -> SpatialVector {
        let scale = extent / Float(max(1, min(size.width, size.height)))
        return SpatialVector(x: center.x + Float(point.x - size.width / 2) * scale,
                             y: height, z: center.y + Float(point.y - size.height / 2) * scale)
    }
}

struct RoomPlanCanvas: View {
    let room: RoomRevision
    var pins: [FieldCaptureIndex] = []
    var samplePositions: [SpatialVector] = []
    var sharedProjection: RoomProjection?
    var pose: SpatialTransform?
    var proposedPoint: SpatialVector?
    var onPoint: ((SpatialVector) -> Void)?
    var selectedDimensionID: UUID?
    var selectedComponentID: UUID?
    var onSelectDimension: ((UUID) -> Void)?
    var onSelectPin: ((UUID) -> Void)?
    @State private var projection: RoomProjection?
    @State private var triangles: [[SpatialVector]] = []
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                guard let projection = sharedProjection ?? projection else { return }
                let grid = Color.secondary.opacity(0.12)
                var gridPath = Path()
                let step = max(0.25, pow(10, floor(log10(Double(projection.extent / 6)))))
                let half = Double(projection.extent / 2)
                for offset in stride(from: -ceil(half / step) * step, through: half, by: step) {
                    let x = Float(offset) + projection.center.x, z = Float(offset) + projection.center.y
                    gridPath.move(to: projection.screen(.init(x: x, y: 0, z: projection.center.y - projection.extent / 2), size: size))
                    gridPath.addLine(to: projection.screen(.init(x: x, y: 0, z: projection.center.y + projection.extent / 2), size: size))
                    gridPath.move(to: projection.screen(.init(x: projection.center.x - projection.extent / 2, y: 0, z: z), size: size))
                    gridPath.addLine(to: projection.screen(.init(x: projection.center.x + projection.extent / 2, y: 0, z: z), size: size))
                }
                context.stroke(gridPath, with: .color(grid), lineWidth: 0.5)
                for triangle in triangles {
                    var path = Path(); path.addLines(triangle.map { projection.screen($0, size: size) }); path.closeSubpath()
                    context.fill(path, with: .color(ProTheme.signal.opacity(0.025)))
                    context.stroke(path, with: .color(ProTheme.signal.opacity(0.10)), lineWidth: 0.4)
                }
                for component in room.components where ["Wall", "Door", "Window", "Opening"].contains(component.category) {
                    let a = component.transform.worldPoint(.init(x: -component.dimensions.x / 2, y: 0, z: 0))
                    let b = component.transform.worldPoint(.init(x: component.dimensions.x / 2, y: 0, z: 0))
                    var path = Path(); path.move(to: projection.screen(a, size: size)); path.addLine(to: projection.screen(b, size: size))
                    context.stroke(path, with: .color(component.id == selectedComponentID ? ProTheme.band : component.category == "Wall" ? .primary : ProTheme.signal),
                                   style: StrokeStyle(lineWidth: component.id == selectedComponentID ? 6 : component.category == "Wall" ? 3 : 2, dash: component.category == "Opening" ? [4, 4] : []))
                }
                for dimension in room.dimensions {
                    var path = Path(); path.move(to: projection.screen(dimension.start, size: size)); path.addLine(to: projection.screen(dimension.end, size: size))
                    context.stroke(path, with: .color(dimension.id == selectedDimensionID ? ProTheme.signal : ProTheme.band), style: StrokeStyle(lineWidth: dimension.id == selectedDimensionID ? 4 : 2, dash: [4, 3]))
                }
                for position in samplePositions {
                    let point = projection.screen(position, size: size)
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)), with: .color(ProTheme.band.opacity(0.65)))
                }
                for (index, pin) in pins.enumerated() {
                    guard let placement = pin.placement else { continue }
                    let point = projection.screen(placement.pose.position, size: size)
                    let circle = Path(ellipseIn: CGRect(x: point.x - 12, y: point.y - 12, width: 24, height: 24))
                    context.fill(circle, with: .color(MC.action))
                    context.draw(Text("\(index + 1)").font(.system(size: 12, weight: .bold)).foregroundStyle(.white), at: point)
                }
                if let pose { drawPosition(pose.position, heading: pose.heading, context: &context, projection: projection, size: size) }
                if let proposedPoint { drawPosition(proposedPoint, heading: 0, context: &context, projection: projection, size: size) }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { event in
                guard let projection = sharedProjection ?? projection else { return }
                if let onPoint { onPoint(projection.world(event.location, size: geometry.size, height: proposedPoint?.y ?? 1.2)); return }
                for pin in pins {
                    guard let placement = pin.placement else { continue }
                    let p = projection.screen(placement.pose.position, size: geometry.size)
                    if hypot(p.x - event.location.x, p.y - event.location.y) < 22 { onSelectPin?(pin.id); return }
                }
                for dimension in room.dimensions {
                    let a = projection.screen(dimension.start, size: geometry.size), b = projection.screen(dimension.end, size: geometry.size)
                    let dx = b.x - a.x, dy = b.y - a.y, length = dx * dx + dy * dy
                    guard length > 0 else { continue }
                    let t = min(1, max(0, ((event.location.x - a.x) * dx + (event.location.y - a.y) * dy) / length))
                    if hypot(event.location.x - a.x - t * dx, event.location.y - a.y - t * dy) < 16 { onSelectDimension?(dimension.id); return }
                }
            })
        }
        .background(MC.canvas).clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityLabel("Room floor plan. \(pins.count) measurement pins and \(samplePositions.count) recorded sample positions. Blank space has no observed geometry.")
        .accessibilityHint(onPoint == nil ? "Measurements are listed below." : "Use the coordinate fields below to place a pin without touching the plan.")
        .task(id: room.id) {
            let room = room
            let result = await Task.detached(priority: .userInitiated) {
                let projection = RoomProjection(room)
                // A bounded visual sample only. The full mesh remains in the saved revision.
                let strideCount = max(1, room.triangleCount / 10_000)
                var triangles: [[SpatialVector]] = []
                for mesh in room.meshes {
                    for i in stride(from: 0, to: mesh.triangleIndices.count, by: 3 * strideCount) {
                        triangles.append((0..<3).map { mesh.transform.worldPoint(mesh.vertices[Int(mesh.triangleIndices[i + $0])]) })
                    }
                }
                return (projection, triangles)
            }.value
            guard !Task.isCancelled else { return }; projection = result.0; triangles = result.1
        }
    }
    private func drawPosition(_ point: SpatialVector, heading: Double, context: inout GraphicsContext, projection: RoomProjection, size: CGSize) {
        let p = projection.screen(point, size: size)
        context.fill(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(ProTheme.band))
        var arrow = Path(); arrow.move(to: p)
        arrow.addLine(to: CGPoint(x: p.x + sin(heading) * 26, y: p.y - cos(heading) * 26))
        context.stroke(arrow, with: .color(ProTheme.band), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }
}

struct RoomMeshCanvas: View {
    let room: RoomRevision
    var pins: [FieldCaptureIndex] = []
    var selectedDimension: SpatialDimension?
    var selectedComponent: RoomComponent?
    var onSelectPin: ((UUID) -> Void)?
    @State private var yaw: Float = 0.6
    @State private var elevation: Float = 0.65
    @State private var zoom: Float = 1
    @State private var dragOrigin: SIMD2<Float>?
    @State private var pinchOrigin: Float?
    @State private var failure: String?
    var body: some View {
        VStack(spacing: 8) {
            RoomMeshScene(room: room, pins: pins, selectedDimension: selectedDimension, selectedComponent: selectedComponent, onSelectPin: onSelectPin, yaw: yaw, elevation: elevation, zoom: zoom, failure: $failure)
                .frame(minHeight: 280).clipShape(RoundedRectangle(cornerRadius: 16))
                .gesture(DragGesture().onChanged { value in
                    if dragOrigin == nil { dragOrigin = SIMD2(yaw, elevation) }
                    yaw = (dragOrigin?.x ?? yaw) - Float(value.translation.width) / 180
                    elevation = max(0.08, min(1.5, (dragOrigin?.y ?? elevation) + Float(value.translation.height) / 240))
                }.onEnded { _ in dragOrigin = nil })
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    if pinchOrigin == nil { pinchOrigin = zoom }
                    zoom = max(0.4, min(3, (pinchOrigin ?? 1) / Float(value.magnification)))
                }.onEnded { _ in pinchOrigin = nil })
                .accessibilityLabel("Three-dimensional observed room mesh. \(room.vertexCount) vertices, \(pins.count) pins.")
            ViewThatFits(in: .horizontal) {
                HStack { navigationButtons; Spacer(); resetButton }
                VStack { navigationButtons; resetButton }
            }.buttonStyle(.borderless).frame(minHeight: 44)
            if let failure { InlineFailure(message: failure) }
        }
    }
    private var navigationButtons: some View {
        HStack(spacing: 4) {
            Button { yaw -= .pi / 6 } label: { Image(systemName: "rotate.left").font(.system(size: 22)).frame(width: 44, height: 44) }.accessibilityLabel("Rotate left")
            Button { yaw += .pi / 6 } label: { Image(systemName: "rotate.right").font(.system(size: 22)).frame(width: 44, height: 44) }.accessibilityLabel("Rotate right")
            Button { zoom = max(0.4, zoom * 0.8) } label: { Image(systemName: "plus.magnifyingglass").font(.system(size: 22)).frame(width: 44, height: 44) }.accessibilityLabel("Zoom in")
            Button { zoom = min(3, zoom * 1.25) } label: { Image(systemName: "minus.magnifyingglass").font(.system(size: 22)).frame(width: 44, height: 44) }.accessibilityLabel("Zoom out")
        }
    }
    private var resetButton: some View { Button("Reset view") { yaw = 0.6; elevation = 0.65; zoom = 1 }.frame(minHeight: 44) }

}

private struct RoomMeshScene: UIViewRepresentable {
    let room: RoomRevision
    let pins: [FieldCaptureIndex]
    var selectedDimension: SpatialDimension?
    var selectedComponent: RoomComponent?
    var onSelectPin: ((UUID) -> Void)?
    let yaw: Float
    let elevation: Float
    let zoom: Float
    @Binding var failure: String?
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        view.environment.background = .color(.secondarySystemBackground)
        context.coordinator.view = view
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:))))
        view.scene.addAnchor(context.coordinator.anchor)
        context.coordinator.anchor.addChild(context.coordinator.camera)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onSelectPin = onSelectPin
        if coordinator.roomID != room.id {
            coordinator.roomID = room.id; coordinator.task?.cancel(); coordinator.geometry.removeFromParent()
            let geometry = Entity(); coordinator.geometry = geometry; coordinator.anchor.addChild(geometry)
            let room = room
            coordinator.task = Task {
                do {
                    let bounds = await Task.detached(priority: .userInitiated) { room.bounds }.value
                    try Task.checkCancellation()
                    coordinator.center = ((bounds?.minimum.simd ?? SIMD3(-2, 0, -2)) + (bounds?.maximum.simd ?? SIMD3(2, 2, 2))) / 2
                    coordinator.radius = max(2, simd_length((bounds?.maximum.simd ?? SIMD3(2, 2, 2)) - (bounds?.minimum.simd ?? SIMD3(-2, 0, -2))))
                    coordinator.positionCamera(yaw: yaw, elevation: elevation, zoom: zoom)
                    for patch in room.meshes {
                        try Task.checkCancellation()
                        var descriptor = MeshDescriptor(name: patch.id.uuidString)
                        descriptor.positions = MeshBuffers.Positions(patch.vertices.map(\.simd))
                        descriptor.primitives = .triangles(patch.triangleIndices)
                        let resource = try MeshResource.generate(from: [descriptor])
                        var material = SimpleMaterial(color: .init(red: 0.55, green: 0.68, blue: 0.76, alpha: 1), roughness: 0.9, isMetallic: false)
                        material.faceCulling = .none
                        let entity = ModelEntity(mesh: resource, materials: [material])
                        entity.transform = Transform(matrix: patch.transform.matrix); geometry.addChild(entity)
                        await Task.yield()
                    }
                } catch is CancellationError { }
                catch { failure = "The 3D preview couldn't be drawn: \(error.localizedDescription). The plan and saved geometry are still available." }
            }
        }
        let signature = pins.map { $0.id.uuidString + String(describing: $0.placement?.pose.elements) }.joined()
        if coordinator.pinSignature != signature {
            coordinator.pinSignature = signature; coordinator.markers.children.removeAll()
            for pin in pins {
                guard let placement = pin.placement else { continue }
                let marker = ModelEntity(mesh: .generateSphere(radius: 0.07), materials: [UnlitMaterial(color: .systemBlue)])
                marker.name = "pin-" + pin.id.uuidString; marker.generateCollisionShapes(recursive: false)
                marker.position = placement.pose.position.simd; coordinator.markers.addChild(marker)
            }
        }
        if coordinator.componentID != selectedComponent?.id {
            coordinator.componentID = selectedComponent?.id; coordinator.component.children.removeAll()
            if let component = selectedComponent {
                var material = UnlitMaterial(color: .systemOrange); material.triangleFillMode = .lines
                let box = ModelEntity(mesh: .generateBox(size: simd_max(component.dimensions.simd, SIMD3<Float>(repeating: 0.025))), materials: [material])
                box.transform = Transform(matrix: component.transform.matrix); coordinator.component.addChild(box)
            }
        }
        if coordinator.dimensionID != selectedDimension?.id {
            coordinator.dimensionID = selectedDimension?.id; coordinator.dimension.children.removeAll()
            if let dimension = selectedDimension {
                let start = dimension.start.simd, end = dimension.end.simd, delta = end - start
                let length = simd_length(delta)
                if length > 0 {
                    let line = ModelEntity(mesh: .generateBox(size: SIMD3(0.02, 0.02, length)), materials: [UnlitMaterial(color: .systemOrange)])
                    line.position = (start + end) / 2
                    line.orientation = simd_quatf(from: SIMD3(0, 0, 1), to: delta / length)
                    coordinator.dimension.addChild(line)
                    for point in [start, end] {
                        let endpoint = ModelEntity(mesh: .generateSphere(radius: 0.045), materials: [UnlitMaterial(color: .systemOrange)])
                        endpoint.position = point; coordinator.dimension.addChild(endpoint)
                    }
                }
            }
        }
        coordinator.positionCamera(yaw: yaw, elevation: elevation, zoom: zoom)
    }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { coordinator.task?.cancel(); view.scene.anchors.removeAll() }
    final class Coordinator: NSObject {
        weak var view: ARView?
        var onSelectPin: ((UUID) -> Void)?
        var dimensionID: UUID?
        let dimension = Entity()
        var componentID: UUID?
        let component = Entity()
        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            guard let view, let entity = view.entity(at: recognizer.location(in: view)), entity.name.hasPrefix("pin-"),
                  let id = UUID(uuidString: String(entity.name.dropFirst(4))) else { return }
            onSelectPin?(id)
        }
        var roomID: UUID?
        var pinSignature = ""
        let anchor = AnchorEntity(world: .zero)
        let camera = PerspectiveCamera()
        let markers = Entity()
        var geometry = Entity()
        var center = SIMD3<Float>.zero
        var radius: Float = 5
        var task: Task<Void, Never>?
        func positionCamera(yaw: Float, elevation: Float, zoom: Float) {
            let offset = SIMD3(sin(yaw) * cos(elevation), sin(elevation), cos(yaw) * cos(elevation)) * radius * zoom
            camera.look(at: center, from: center + offset, relativeTo: nil)
        }
        override init() {
            super.init()
            anchor.addChild(component)
            anchor.addChild(dimension)
            anchor.addChild(markers)
            let light = DirectionalLight(); light.light.intensity = 3000
            light.look(at: .zero, from: SIMD3(2, 6, 4), relativeTo: nil); anchor.addChild(light)
        }
    }
}

struct RoomCameraView: UIViewRepresentable {
    let session: RoomSession
    var showObservedMesh = false
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        view.session = session.arSession
        view.scene.addAnchor(context.coordinator.anchor)
        return view
    }
    func updateUIView(_ view: ARView, context: Context) {
        let coordinator = context.coordinator
        if showObservedMesh { view.debugOptions.insert(.showSceneUnderstanding) }
        else { view.debugOptions.remove(.showSceneUnderstanding) }
        coordinator.anchor.isEnabled = session.tracked
        let signature = session.dimensions.map(\.id.uuidString).joined() + String(describing: session.firstPoint)
        guard coordinator.signature != signature else { return }
        coordinator.signature = signature; coordinator.anchor.children.removeAll()
        // Keep the camera legible while every measured endpoint remains in the saved data/list.
        for dimension in session.dimensions.suffix(8) {
            let start = dimension.start.simd, end = dimension.end.simd, delta = end - start, length = simd_length(delta)
            guard length > 0 else { continue }
            let line = ModelEntity(mesh: .generateBox(size: SIMD3(0.012, 0.012, length)), materials: [UnlitMaterial(color: .systemYellow)])
            line.position = (start + end) / 2
            line.orientation = simd_quatf(from: SIMD3(0, 0, 1), to: delta / length)
            coordinator.anchor.addChild(line); coordinator.addPoint(start); coordinator.addPoint(end)
        }
        if let point = session.firstPoint { coordinator.addPoint(point.simd) }
    }
    static func dismantleUIView(_ view: ARView, coordinator: Coordinator) { view.scene.anchors.removeAll() }
    final class Coordinator {
        let anchor = AnchorEntity(world: .zero)
        var signature = ""
        func addPoint(_ position: SIMD3<Float>) {
            let point = ModelEntity(mesh: .generateSphere(radius: 0.025), materials: [UnlitMaterial(color: .systemYellow)])
            point.position = position; anchor.addChild(point)
        }
    }
}
