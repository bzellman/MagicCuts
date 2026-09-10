import SwiftUI
import UniformTypeIdentifiers
import simd

struct RoomsView: View {
    @Bindable var library: ProLibrary
    @Environment(RoomSession.self) private var session
    @State private var capturing = false
    @State private var recovered: RoomRevision?
    @State private var discardDraft: RoomRevision?
    @State private var importing = false
    @State private var importBusy = false
    private var latest: [RoomRevisionIndex] {
        var seen = Set<UUID>()
        return library.index.roomRevisions.sorted { $0.date > $1.date }.filter { seen.insert($0.roomID).inserted }
    }
    var body: some View {
        List {
            if session.cameraActive { Section { RoomOrientationBanner() } }
            Section {
                Button { capturing = true } label: { Label("Capture a room", systemImage: "viewfinder") }.frame(minHeight: 44)
                    .accessibilityIdentifier("rooms.capture")
                Text("Keep a room's observed surfaces, locate yourself on return, and see where measurements were captured.")
                    .font(.callout).foregroundStyle(ProTheme.secondary)
            }
            if !library.recoveredRooms.isEmpty {
                Section("Recovered scans") {
                    ForEach(library.recoveredRooms) { room in
                        Button { recovered = room } label: {
                            Label("\(room.roomName) · \(room.endedAt.formatted(date: .abbreviated, time: .shortened))", systemImage: "arrow.counterclockwise")
                        }.swipeActions { Button("Discard", role: .destructive) { discardDraft = room } }
                    }
                }
            }
            DraftRecoverySection(library: library, isRoom: true)
            Section("Your rooms") {
                if latest.isEmpty {
                    ContentUnavailableView("Make space for measurements", systemImage: "square.3.layers.3d", description: Text("Your first room starts with a slow walk around the space. Capture needs a device with LiDAR."))
                }
                ForEach(latest) { room in
                    NavigationLink { RoomDetailView(id: room.id, library: library) } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(room.roomName, systemImage: "square.3.layers.3d").font(.system(.headline, design: .rounded))
                            let revisions = library.index.roomRevisions.filter { $0.roomID == room.roomID }.count
                            let pins = library.index.fieldCaptures.filter { $0.placement?.roomID == room.roomID }.count
                            Text("\(revisions) revisions · \(pins) measurements").font(.callout).foregroundStyle(ProTheme.secondary)
                            Text(room.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(ProTheme.secondary)
                            if room.demonstration { Text("Illustrative sample room").font(.caption).foregroundStyle(ProTheme.band) }
                        }.padding(.vertical, 8)
                    }
                }
            }
            if let error = library.error { InlineFailure(message: error) }
        }
        .navigationTitle("Rooms").refreshable { await library.reload() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { importing = true } label: { Label("Import room archive", systemImage: "square.and.arrow.down") }.disabled(importBusy)
        } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            Task {
                importBusy = true; defer { importBusy = false }
                do {
                    let room = try await FieldExport.importRoom(result.get())
                    if library.index.roomRevisions.contains(where: { $0.id == room.id }) {
                        guard try await library.archive.loadRoomRevision(room.id) == room else { throw InstrumentError.storage("This revision already exists with different geometry. The saved room has been kept.") }
                    } else { try await library.save(room) }
                } catch { library.error = error.localizedDescription }
            }
        }
        .sheet(isPresented: $capturing) { RoomCaptureView(library: library, purpose: .newRoom) }
        .sheet(item: $recovered) { RoomSaveView(room: $0, library: library) }
        .confirmationDialog("Discard recovered scan?", isPresented: Binding(get: { discardDraft != nil }, set: { if !$0 { discardDraft = nil } }), titleVisibility: .visible) {
            if let draft = discardDraft {
                Button("Discard this scan", role: .destructive) { Task {
                    do { try await library.archive.discardRoomDraft(draft.id); await library.reload() }
                    catch { library.error = error.localizedDescription }
                    discardDraft = nil
                } }
            }
        } message: { Text("This removes the unfinished scan. Saved revisions remain available.") }
    }
}

struct RoomDetailView: View {
    let id: UUID
    @Bindable var library: ProLibrary
    @Environment(RoomSession.self) private var session
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var room: RoomRevision?
    @State private var failure: String?
    @State private var mode = 0
    @State private var selectedDimensionID: UUID?
    @State private var selectedComponentID: UUID?
    @State private var selectedCaptureID: UUID?
    @State private var locatedEvidence = RoomLocatedEvidence()
    @State private var captureMode: RoomCaptureRoute?
    @State private var comparison: RoomRevision?
    @State private var exporting = false
    @State private var orientationUnavailable = false
    @State private var deleting = false
    @Environment(\.dismiss) private var dismiss
    private var pins: [FieldCaptureIndex] {
        guard let room else { return [] }
        return library.index.fieldCaptures.filter { $0.placement?.roomID == room.roomID && $0.placement?.coordinateFrameID == room.coordinateFrameID }
            .sorted { $0.date < $1.date }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let room {
                    if room.demonstration { Label("Illustrative sample room", systemImage: "info.circle").font(.callout).foregroundStyle(ProTheme.band) }
                    if session.cameraActive { RoomOrientationBanner() }
                    if dynamicType.isAccessibilitySize { displayPicker.pickerStyle(.menu) }
                    else { displayPicker.pickerStyle(.segmented) }
                    if mode == 0 { RoomMeshCanvas(room: room, pins: pins, selectedDimension: room.dimensions.first { $0.id == selectedDimensionID }, selectedComponent: room.components.first { $0.id == selectedComponentID }, onSelectPin: { selectedCaptureID = $0 }).frame(minHeight: 340) }
                    if mode == 1 {
                        RoomPlanCanvas(room: room, pins: pins, samplePositions: locatedEvidence.positions, pose: session.reference?.coordinateFrameID == room.coordinateFrameID ? session.currentPose : nil, selectedDimensionID: selectedDimensionID, selectedComponentID: selectedComponentID, onSelectDimension: { selectedDimensionID = $0; selectedComponentID = nil }, onSelectPin: { selectedCaptureID = $0 }).frame(height: 340)
                    }
                    if mode != 2 {
                        Text(mode == 0 ? "Observed surfaces only. Blank areas have no captured geometry. Drag to orbit the mesh; pinch to zoom." : "Observed surfaces only. Blank areas have no captured geometry. Tap a numbered pin or a dimension to inspect it.").font(.caption).foregroundStyle(ProTheme.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 24) {
                            VStack(alignment: .leading) {
                                Text("\(room.triangleCount.formatted())").font(.system(.title2, design: .rounded).weight(.semibold))
                                Text("mesh triangles").font(.caption).foregroundStyle(ProTheme.secondary)
                            }
                            if let area = room.floorArea {
                                VStack(alignment: .leading) {
                                    Text("\(area.formatted(.number.precision(.fractionLength(1)))) m²").font(.system(.title2, design: .rounded).weight(.semibold))
                                    Text("recognized footprint estimate").font(.caption).foregroundStyle(ProTheme.secondary)
                                }
                            }
                        }
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { locateButton(room); updateButton }
                        VStack { locateButton(room); updateButton }
                    }
                    if !room.dimensions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Dimensions").font(.headline)
                            ForEach(room.dimensions) { dimension in
                                Button { selectedDimensionID = dimension.id; selectedComponentID = nil } label: {
                                    HStack {
                                        if selectedDimensionID == dimension.id { Image(systemName: "checkmark.circle.fill") }
                                        LabeledContent(dimension.title, value: "\(dimension.meters.formatted(.number.precision(.fractionLength(2)))) m")
                                    }.frame(minHeight: 44)
                                }.buttonStyle(.plain).accessibilityAddTraits(selectedDimensionID == dimension.id ? .isSelected : [])
                            }
                        }
                    }
                    if let volume = room.estimatedVolume {
                        LabeledContent("Height-extruded volume estimate", value: "\(volume.formatted(.number.precision(.fractionLength(1)))) m³")
                        Text("Recognized footprint × consistent wall height. This is a height extrusion: ceiling shape and unrecognized floor voids are not measured by this estimate.").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                    recognizedComponents(room)
                    measurementList
                    if locatedEvidence.totalPositionCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recorded positions").font(.headline)
                            Text("\(locatedEvidence.totalPositionCount) located samples. The plan shows up to 3,000 observed positions; gaps are not connected.").font(.caption).foregroundStyle(ProTheme.secondary)
                            ForEach(locatedEvidence.recordings) { recording in
                                NavigationLink(recording.title) { SessionDetailView(id: recording.id, library: library) }.frame(minHeight: 44)
                            }
                            ForEach(locatedEvidence.captures) { capture in
                                NavigationLink(capture.title) { FieldCaptureDetailView(id: capture.id, library: library) }.frame(minHeight: 44)
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Revisions").font(.headline)
                        Text("\(room.endedAt.formatted(date: .abbreviated, time: .shortened)) · \(room.alignment.title)").font(.callout)
                        ForEach(library.index.roomRevisions.filter { $0.roomID == room.roomID && $0.id != room.id }) { revision in
                            HStack {
                                NavigationLink(revision.date.formatted(date: .abbreviated, time: .shortened)) { RoomDetailView(id: revision.id, library: library) }
                                Spacer()
                                Button("Compare") { Task {
                                    do { comparison = try await library.archive.loadRoomRevision(revision.id) }
                                    catch { failure = error.localizedDescription }
                                } }.frame(minHeight: 44)
                            }
                        }
                    }
                    if let comparison { RoomRevisionComparison(current: room, earlier: comparison) }
                    ForEach(room.warnings, id: \.self) { Text($0).font(.callout).foregroundStyle(ProTheme.secondary) }

                } else if failure == nil { ProgressView("Opening room…") }
                if let failure { InlineFailure(message: failure) }
            }.padding(22).frame(maxWidth: 800).frame(maxWidth: .infinity)
        }.background(MC.canvas).scrollEdgeEffectStyle(.hard, for: .all).navigationTitle(room?.roomName ?? "Room").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Export room", systemImage: "square.and.arrow.up") { exporting = true }
                    Button("Delete this revision", systemImage: "trash", role: .destructive) { deleting = true }
                        .disabled(session.cameraActive && session.reference?.id == id)
                } label: { Label("Room actions", systemImage: "ellipsis.circle") }
            }
        }
        .task(id: id) {
            do {
                let loaded = try await library.archive.loadRoomRevision(id)
                room = loaded
                locatedEvidence = try await library.archive.locatedEvidence(in: loaded)
            }
            catch { failure = error.localizedDescription }
        }
        .alert("Orientation map unavailable", isPresented: $orientationUnavailable) {
            Button("OK", role: .cancel) { }
        } message: { Text("This revision can be viewed and measured, but it has no saved camera map for locating your phone. Place readings manually, or use Update room to capture a new pass with orientation data.") }
        .navigationDestination(item: $selectedCaptureID) { FieldCaptureDetailView(id: $0, library: library) }
        .sheet(isPresented: $exporting) { if let room { RoomExportView(room: room) } }
        .sheet(item: $captureMode) { route in RoomCaptureView(library: library, purpose: route.purpose, reference: room) }
        .confirmationDialog("Delete this room revision?", isPresented: $deleting, titleVisibility: .visible) {
            Button("Delete revision", role: .destructive) { Task {
                do { _ = try await library.archive.deleteRoomRevision(id); await library.reload(); dismiss() }
                catch { failure = error.localizedDescription }
            } }
        } message: { Text("Revisions referenced by measurements or later scans must be kept.") }
    }
    private func recognizedComponents(_ room: RoomRevision) -> some View {
        let components = room.components.filter { ["Wall", "Door", "Window", "Opening"].contains($0.category) }
        return DisclosureGroup("Recognized walls and openings · \(components.count)") {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(components.enumerated()), id: \.element.id) { index, component in
                    Button { selectedComponentID = component.id; selectedDimensionID = nil } label: {
                        HStack(alignment: .top) {
                            if selectedComponentID == component.id { Image(systemName: "checkmark.circle.fill") }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(component.category) \(index + 1)").font(.headline)
                                Text("\(component.dimensions.x.formatted(.number.precision(.fractionLength(2)))) m wide × \(component.dimensions.y.formatted(.number.precision(.fractionLength(2)))) m high").monospacedDigit()
                                Text("Recognized estimate · \(component.confidence.lowercased()) confidence").font(.caption).foregroundStyle(ProTheme.secondary)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }.buttonStyle(.plain).accessibilityAddTraits(selectedComponentID == component.id ? .isSelected : [])
                }
            }.padding(.top, 12)
        }
    }
    private var displayPicker: some View {
        Picker("Room display", selection: $mode) {
            Text("Mesh").tag(0); Text("Plan").tag(1); Text("Measurements").tag(2)
        }.accessibilityIdentifier("room.display")
    }
    private func locateButton(_ room: RoomRevision) -> some View {
        Button { if room.worldMapData == nil { orientationUnavailable = true } else { captureMode = RoomCaptureRoute(purpose: .localize) } } label: { Label("Locate in room", systemImage: "location.viewfinder").frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).disabled(session.cameraActive)
    }
    private var updateButton: some View {
        Button { captureMode = RoomCaptureRoute(purpose: .update) } label: { Label("Update room", systemImage: "plus.viewfinder").frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.bordered).controlSize(.large).disabled(session.cameraActive)
    }
    private var measurementList: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Measurements in this space").font(.headline)
            if pins.isEmpty { Text("Locate in the room, then capture a reading from any instrument. Saved captures can also be placed manually.").font(.callout).foregroundStyle(ProTheme.secondary) }
            ForEach(Array(pins.enumerated()), id: \.element.id) { index, pin in
                NavigationLink { FieldCaptureDetailView(id: pin.id, library: library) } label: {
                    HStack(alignment: .top) {
                        Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.white).frame(width: 26, height: 26).background(MC.action, in: Circle())
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pin.title).font(.headline)
                            if let metric = pin.metrics.first { Text("\(metric.formatted) \(metric.unit)").monospacedDigit() }
                            Text(pin.placement?.method.title ?? "").font(.caption).foregroundStyle(ProTheme.secondary)
                            if let placement = pin.placement, session.canPin,
                               let pose = session.currentPose, session.reference?.coordinateFrameID == placement.coordinateFrameID,
                               let direction = SpatialMath.direction(from: pose, to: placement.pose.position) {
                                Label("\(direction.meters.formatted(.number.precision(.fractionLength(1)))) m from you", systemImage: "location.north.fill")
                                    .font(.callout).rotationEffect(.zero)
                                Image(systemName: "arrow.up").rotationEffect(.radians(direction.radians)).accessibilityLabel("Direction \(Int(direction.radians * 180 / .pi)) degrees relative to camera")
                            }
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(ProTheme.secondary)
                    }.frame(minHeight: 44)
                }.buttonStyle(.plain)
            }
        }
    }

}

private struct RoomCaptureRoute: Identifiable { let id = UUID(); let purpose: RoomSessionPurpose }

struct RoomRevisionComparison: View {
    let current: RoomRevision
    let earlier: RoomRevision
    @State private var sharedProjection: RoomProjection?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare observed coverage").font(.headline)
            Text(current.coordinateFrameID == earlier.coordinateFrameID ? "These passes share a restored coordinate frame. Differences in observation are not proof that a physical object moved." : "These passes have separate coordinate frames. Their positions cannot be overlaid reliably.")
                .font(.callout).foregroundStyle(ProTheme.secondary)
            Text("Earlier · \(earlier.endedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption)
            RoomPlanCanvas(room: earlier, sharedProjection: sharedProjection).frame(height: 220)
            Text("This revision · \(current.endedAt.formatted(date: .abbreviated, time: .shortened))").font(.caption)
            RoomPlanCanvas(room: current, sharedProjection: sharedProjection).frame(height: 220)
            LabeledContent("Observed triangles", value: "\(earlier.triangleCount) → \(current.triangleCount)")
        }.task(id: earlier.id) {
            guard current.coordinateFrameID == earlier.coordinateFrameID else { sharedProjection = nil; return }
            sharedProjection = await Task.detached(priority: .userInitiated) {
                guard let a = current.bounds, let b = earlier.bounds else { return RoomProjection(current) }
                return RoomProjection(bounds: (SpatialVector(simd_min(a.minimum.simd, b.minimum.simd)), SpatialVector(simd_max(a.maximum.simd, b.maximum.simd))))
            }.value
        }
    }
}

struct RoomOrientationBanner: View {
    @Environment(RoomSession.self) private var session
    var body: some View {
        if session.cameraActive {
            VStack(alignment: .leading, spacing: 8) {
                Label(session.canPin ? "Located in \(session.roomName)" : session.phase.title, systemImage: "camera.fill").font(.callout.bold())
                Text(session.canPin ? "Camera tracking is active. New measurements retain their position while tracking is reliable." : session.instruction).font(.caption)
                Button("End room orientation") { session.end() }.frame(minHeight: 44)
            }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(ProTheme.signal.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct RoomCaptureView: View {
    @Bindable var library: ProLibrary
    let purpose: RoomSessionPurpose
    var reference: RoomRevision?
    @Environment(RoomSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var saving = false
    @State private var keepOrientation = false
    @State private var cancelConfirmation = false
    @State private var showObservedMesh = true
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if session.cameraActive {
                        ZStack {
                            RoomCameraView(session: session, showObservedMesh: purpose != .localize && showObservedMesh).frame(height: 340).clipShape(RoundedRectangle(cornerRadius: 16))
                            Image(systemName: "plus").font(.title).foregroundStyle(.white).shadow(radius: 2).accessibilityHidden(true)
                        }
                    }
                    if session.cameraActive && purpose != .localize {
                        Toggle("Show observed surfaces", isOn: $showObservedMesh)
                        Text("The mesh overlay shows observed geometry. Its surface colors are not accuracy scores.").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                    Label(session.phase.title, systemImage: session.canPin ? "location.fill" : "viewfinder").font(.system(.title2, design: .rounded).weight(.semibold))
                    Text(session.instruction).font(.callout)
                    if let failure = session.failure { InlineFailure(message: failure) }
                    if session.phase == .locating, let data = reference?.referenceImage, let image = UIImage(data: data) {
                        Text("Match this saved view").font(.headline)
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220).clipShape(RoundedRectangle(cornerRadius: 12)).accessibilityLabel("Reference camera photo from the saved room scan")
                    }
                    if purpose == .update, session.phase == .locating || session.phase == .unavailable {
                        Button("Capture a separate pass") { Task { await session.start(.update, reference: reference, archive: library.archive, unaligned: true) } }.frame(minHeight: 44)
                        Text("A separate pass preserves this room's history, but its measurements use a new coordinate frame.").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                    if session.cameraActive {
                        LabeledContent("Observed vertices", value: session.vertexCount.formatted())
                        if let distance = session.distance {
                            LabeledContent("Surface at reticle", value: "\(distance.formatted(.number.precision(.fractionLength(2)))) m")
                            Text("Depth estimate · \(session.confidence == 2 ? "high" : "limited") confidence").font(.caption).foregroundStyle(ProTheme.secondary)
                        }
                        if purpose != .localize {
                            Button(session.firstPoint == nil ? "Set first dimension point" : "Set second dimension point") { session.selectPoint() }
                                .buttonStyle(.bordered).controlSize(.large).disabled(!session.tracked || (session.confidence ?? 0) < 1).frame(minHeight: 44)
                            if session.firstPoint != nil || !session.dimensions.isEmpty { Button("Undo last point") { session.undoPoint() }.frame(minHeight: 44) }
                            ForEach(session.dimensions) { dimension in LabeledContent(dimension.title, value: "\(dimension.meters.formatted(.number.precision(.fractionLength(2)))) m") }
                        }
                    }
                    if session.phase == .processing { ProgressView("Preparing saved geometry…") }
                    if session.phase == .review, let room = session.draft {
                        RoomMeshCanvas(room: room)
                        Button("Review and save room") { saving = true }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44)
                    }
                    if session.canFinish { Button("Finish scan") { session.finish() }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44) }
                    if session.canPin {
                        Button("Use this orientation") { keepOrientation = true; dismiss() }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44)
                        Text("Keep the camera unobstructed while you capture readings. Tracking ends when you close MagicCuts or choose End room orientation.").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                }.padding(22).frame(maxWidth: 800).frame(maxWidth: .infinity)
            }.background(MC.canvas).navigationTitle(purpose == .localize ? "Locate in room" : "Capture room").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") {
                if session.cameraActive && purpose != .localize { cancelConfirmation = true } else { dismiss() }
            } } }
            .task { await session.start(purpose, reference: reference, archive: library.archive) }
            .sheet(isPresented: $saving) {
                if let room = session.draft { RoomSaveView(room: room, library: library) { dismiss() } }
            }
            .confirmationDialog("Close this scan?", isPresented: $cancelConfirmation, titleVisibility: .visible) {
                Button("Keep recovery copy and close") { session.backgrounded(); dismiss() }
            } message: { Text("The observed mesh will be kept as a recovered scan. Live orientation will stop.") }
        }.interactiveDismissDisabled(session.cameraActive && purpose != .localize)
        .onDisappear { if !keepOrientation { session.end() } }
    }
}

struct RoomSaveView: View {
    let room: RoomRevision
    @Bindable var library: ProLibrary
    var onSaved: (() -> Void)?
    @State private var name = ""
    @State private var working = false
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Room name") { TextField("Name this space", text: $name).accessibilityIdentifier("room.name") }
                Section {
                    RoomPlanCanvas(room: room).frame(height: 230)
                    LabeledContent("Mesh triangles", value: room.triangleCount.formatted())
                    LabeledContent("Orientation map", value: room.worldMapData == nil ? "Unavailable" : "Retained")
                    Text("Each revision keeps its observed surfaces. Unseen areas and newly missing surfaces are not filled in from an earlier pass.").font(.callout).foregroundStyle(ProTheme.secondary)
                    if room.worldMapData == nil { Text("You can review this scan and place measurements manually. A recovered partial scan may not include an orientation map.").font(.callout) }
                }
                ForEach(room.warnings, id: \.self) { Text($0).font(.callout) }
                if let failure { InlineFailure(message: failure) }
            }.navigationTitle("Save room").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() }.disabled(working) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task {
                    working = true; defer { working = false }
                    var value = room; value.roomName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    do { try await library.save(value); dismiss(); onSaved?() }
                    catch { failure = error.localizedDescription }
                } }.disabled(working || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("room.save") }
            }.onAppear { name = room.roomName }.interactiveDismissDisabled(working)
        }
    }
}

struct DraftRecoverySection: View {
    @Bindable var library: ProLibrary
    var isRoom: Bool
    @State private var discarding: UnreadableDraft?
    var body: some View {
        let drafts = library.unreadableDrafts.filter { $0.isRoom == isRoom }
        if !drafts.isEmpty {
            Section("Recovery needs attention") {
                Text("These unfinished files couldn't be read. Other saved work is available. Keep the files for recovery, or discard them to clear their protected references.")
                    .font(.callout).foregroundStyle(ProTheme.secondary)
                ForEach(Array(drafts.enumerated()), id: \.element.id) { offset, draft in
                    Button("Discard unreadable \(isRoom ? "scan" : "recording") \(offset + 1)", role: .destructive) { discarding = draft }
                        .frame(minHeight: 44)
                }
            }
            .confirmationDialog("Discard this unreadable file?", isPresented: Binding(get: { discarding != nil }, set: { if !$0 { discarding = nil } }), titleVisibility: .visible) {
                if let draft = discarding {
                    Button("Discard file", role: .destructive) { Task {
                        do { try await library.archive.discardUnreadableDraft(draft); await library.reload() }
                        catch { library.error = error.localizedDescription }
                        discarding = nil
                    } }
                }
            } message: { Text("The unfinished file will be removed permanently. Your saved rooms and measurements will remain.") }
        }
    }
}
