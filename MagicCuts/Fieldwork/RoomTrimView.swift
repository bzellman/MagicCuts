import SwiftUI

nonisolated struct RoomTrimDestination: Hashable {
    let revisionID: UUID
}

struct RoomTrimView: View {
    let room: RoomRevision
    @Bindable var library: ProLibrary
    @Binding var savedRevision: RoomTrimDestination?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var selection = RoomMeshTrim(minX: 0, maxX: 1, minZ: 0, maxZ: 1)
    @State private var projection: RoomProjection?
    @State private var undoSelection: RoomMeshTrim?
    @State private var preview: RoomRevision?
    @State private var previewRequest: UUID?
    @State private var working = false
    @State private var saving = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let preview {
                        Label("Preview trim", systemImage: "scissors").font(.headline)
                        RoomMeshCanvas(room: preview).frame(minHeight: 340)
                        Text("\(preview.triangleCount.formatted()) triangles after trimming").font(.callout)
                        Text("Save creates a new revision. Your original scan and saved readings remain available.")
                            .font(.callout).foregroundStyle(ProTheme.secondary)
                        Button("Adjust selection", systemImage: "crop") { self.preview = nil }
                            .frame(minHeight: 44).accessibilityIdentifier("room.trim.adjust")
                    } else if let projection {
                        Text("Select the area to trim").font(.title2.weight(.semibold))
                        Text("Drag a rectangle over the unwanted hallway, or move its corners. The selection cuts through the full height of the scan.")
                            .font(.callout).foregroundStyle(ProTheme.secondary)
                        if dynamicType.isAccessibilitySize { operationPicker.pickerStyle(.menu) }
                        else { operationPicker.pickerStyle(.segmented) }
                        RoomTrimSelectionCanvas(room: room, projection: projection, selection: $selection, undoSelection: $undoSelection)
                            .frame(height: 320)
                        Label(selection.keepSelection ? "Keep inside the outline; remove the shaded area." : "Remove the shaded area; keep the rest of the room.", systemImage: "scissors")
                            .font(.caption).foregroundStyle(ProTheme.secondary)
                        if dynamicType.isAccessibilitySize {
                            VStack(alignment: .leading, spacing: 12) { undoButton; resetButton(projection) }
                        } else {
                            HStack { undoButton; Spacer(); resetButton(projection) }
                        }
                        DisclosureGroup("Adjust edges") {
                            VStack(spacing: 12) {
                                boundary("Left edge", key: \.minX, limits: (projection.center.x - projection.extent / 2)...(selection.maxX - 0.05))
                                boundary("Right edge", key: \.maxX, limits: (selection.minX + 0.05)...(projection.center.x + projection.extent / 2))
                                boundary("Top edge", key: \.minZ, limits: (projection.center.y - projection.extent / 2)...(selection.maxZ - 0.05))
                                boundary("Bottom edge", key: \.maxZ, limits: (selection.minZ + 0.05)...(projection.center.y + projection.extent / 2))
                            }.padding(.top, 12)
                        }.multilineTextAlignment(.leading).accessibilityIdentifier("room.trim.edges")
                        Text("The original scan is kept in Revisions. You can inspect the result before saving.")
                            .font(.caption).foregroundStyle(ProTheme.secondary)
                    } else { ProgressView("Opening floor plan…") }
                    if let failure { InlineFailure(message: failure) }
                }.padding(22).frame(maxWidth: 800).frame(maxWidth: .infinity)
                    .disabled(working || saving)
            }
            .background(MC.canvas).navigationTitle("Trim room").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(saving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if preview != nil {
                        Button(saving ? "Saving…" : "Save revision") { Task { await save() } }
                            .disabled(saving).accessibilityIdentifier("room.trim.save")
                    } else {
                        Button(working ? "Preparing…" : "Preview trim") { working = true; previewRequest = UUID() }
                            .disabled(working || projection == nil || !selection.isValid)
                            .accessibilityIdentifier("room.trim.preview")
                    }
                }
            }
            .overlay { if working { ProgressView("Trimming surfaces…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)) } }
            .interactiveDismissDisabled(saving)
            .task {
                let value = await Task.detached(priority: .userInitiated) { RoomProjection(room) }.value
                guard !Task.isCancelled else { return }
                projection = value; resetSelection(value)
            }
            .task(id: previewRequest) {
                guard previewRequest != nil else { return }
                await preparePreview()
            }
        }
    }

    private var undoButton: some View {
        Button("Undo selection", systemImage: "arrow.uturn.backward") {
            if let undoSelection { selection = undoSelection; self.undoSelection = nil }
        }.disabled(undoSelection == nil).frame(minHeight: 44)
    }
    private func resetButton(_ projection: RoomProjection) -> some View {
        Button("Reset") { resetSelection(projection) }.frame(minHeight: 44)
    }
    private var operationPicker: some View {
        Picker("Trim operation", selection: $selection.keepSelection) {
            Text("Remove selection").tag(false)
            Text("Keep selection").tag(true)
        }.accessibilityIdentifier("room.trim.operation")
    }
    private func resetSelection(_ projection: RoomProjection) {
        let half = projection.extent / 5
        undoSelection = selection
        selection = RoomMeshTrim(minX: projection.center.x - half, maxX: projection.center.x + half,
                                 minZ: projection.center.y - half, maxZ: projection.center.y + half,
                                 keepSelection: selection.keepSelection)
    }
    private func boundary(_ title: String, key: WritableKeyPath<RoomMeshTrim, Float>, limits: ClosedRange<Float>) -> some View {
        Stepper {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                Text("\(selection[keyPath: key].formatted(.number.precision(.fractionLength(2)))) m")
                    .font(.callout).foregroundStyle(ProTheme.secondary)
            }
        } onIncrement: { moveBoundary(key, by: 0.1, limits: limits) }
          onDecrement: { moveBoundary(key, by: -0.1, limits: limits) }
    }
    private func moveBoundary(_ key: WritableKeyPath<RoomMeshTrim, Float>, by delta: Float, limits: ClosedRange<Float>) {
        undoSelection = selection
        selection[keyPath: key] = min(limits.upperBound, max(limits.lowerBound, selection[keyPath: key] + delta))
    }
    private func preparePreview() async {
        let room = room, selection = selection
        failure = nil
        let task = Task.detached(priority: .userInitiated) { try RoomMeshTrimmer.trim(room, selection: selection) }
        defer { working = false }
        do {
            let result = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
            try Task.checkCancellation()
            preview = result
        } catch is CancellationError { }
        catch { failure = error.localizedDescription }
    }
    private func save() async {
        guard let preview else { return }
        saving = true; failure = nil
        defer { saving = false }
        do {
            try await library.save(preview)
            savedRevision = RoomTrimDestination(revisionID: preview.id)
            dismiss()
        } catch { failure = error.localizedDescription }
    }
}

private struct RoomTrimSelectionCanvas: View {
    let room: RoomRevision
    let projection: RoomProjection
    @Binding var selection: RoomMeshTrim
    @Binding var undoSelection: RoomMeshTrim?
    @State private var drawing = false
    @State private var handleOrigin: RoomMeshTrim?

    var body: some View {
        GeometryReader { geometry in
            let a = projection.screen(.init(x: selection.minX, y: 0, z: selection.minZ), size: geometry.size)
            let b = projection.screen(.init(x: selection.maxX, y: 0, z: selection.maxZ), size: geometry.size)
            let rect = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
            ZStack {
                RoomPlanCanvas(room: room, sharedProjection: projection).allowsHitTesting(false)
                Canvas { context, size in
                    var shading = Path()
                    if selection.keepSelection { shading.addRect(CGRect(origin: .zero, size: size)) }
                    shading.addRect(rect)
                    context.fill(shading, with: .color(ProTheme.band.opacity(0.25)), style: FillStyle(eoFill: true))
                    context.stroke(Path(rect), with: .color(ProTheme.band), style: StrokeStyle(lineWidth: 3, dash: [7, 4]))
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 3).onChanged { value in
                    if !drawing { undoSelection = selection; drawing = true }
                    let start = point(value.startLocation, size: geometry.size), end = point(value.location, size: geometry.size)
                    guard abs(end.x - start.x) >= 0.05, abs(end.z - start.z) >= 0.05 else { return }
                    selection.minX = min(start.x, end.x); selection.maxX = max(start.x, end.x)
                    selection.minZ = min(start.z, end.z); selection.maxZ = max(start.z, end.z)
                }.onEnded { _ in drawing = false })
                ForEach(0..<4) { index in
                    let right = index % 2 == 1, bottom = index >= 2
                    Image(systemName: "circle.fill")
                        .font(.system(size: 16)).foregroundStyle(ProTheme.band)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                        .position(x: right ? b.x : a.x, y: bottom ? b.y : a.y)
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            if handleOrigin == nil { handleOrigin = selection; undoSelection = selection }
                            guard let origin = handleOrigin else { return }
                            let scale = projection.extent / Float(min(geometry.size.width, geometry.size.height))
                            let x = (right ? origin.maxX : origin.minX) + Float(value.translation.width) * scale
                            let z = (bottom ? origin.maxZ : origin.minZ) + Float(value.translation.height) * scale
                            let half = projection.extent / 2
                            if right { selection.maxX = min(projection.center.x + half, max(selection.minX + 0.05, x)) }
                            else { selection.minX = max(projection.center.x - half, min(selection.maxX - 0.05, x)) }
                            if bottom { selection.maxZ = min(projection.center.y + half, max(selection.minZ + 0.05, z)) }
                            else { selection.minZ = max(projection.center.y - half, min(selection.maxZ - 0.05, z)) }
                        }.onEnded { _ in handleOrigin = nil })
                        .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Top-down trim selection")
            .accessibilityHint("Use Adjust edges below to move each edge.")
            .accessibilityIdentifier("room.trim.canvas")
        }
    }
    private func point(_ location: CGPoint, size: CGSize) -> SpatialVector {
        var point = projection.world(location, size: size, height: 0)
        let half = projection.extent / 2
        point.x = min(projection.center.x + half, max(projection.center.x - half, point.x))
        point.z = min(projection.center.y + half, max(projection.center.y - half, point.z))
        return point
    }
}

#if DEBUG
#Preview("Trim room") {
    RoomTrimView(room: FieldDemo.room(), library: ProLibrary(archive: InstrumentArchive(useSharedContainer: false)), savedRevision: .constant(nil))
}
#endif
