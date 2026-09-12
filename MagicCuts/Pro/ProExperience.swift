import SwiftUI
import SwiftData
import StoreKit

struct ProRootView: View {
    let radio: any RadioScanning
    var guidanceWarning: String?
    @State private var access = ProAccess.shared
    @State private var requestedRecordingID: UUID?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch access.state {
            case .checking: ProgressView("Checking Pro…")
            case .locked: ProPaywallView(access: access)
            case .unlocked: ProWorkspaceView(radio: radio, access: access, guidanceWarning: guidanceWarning, requestedRecordingID: requestedRecordingID)
            }
        }
        .tint(ProTheme.signal)
        .task { await access.load() }
        .onOpenURL { url in
            if url.scheme == "magiccuts", url.host == "session" { requestedRecordingID = UUID(uuidString: url.lastPathComponent) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await access.refresh() } }
        }
    }
}

struct ProPaywallView: View {
    @Bindable var access: ProAccess
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Make every reading useful.").font(.system(.largeTitle, design: .rounded).bold())
                        Text("Local instruments. Meaningful comparisons. Results you can put to work in Shortcuts.")
                            .font(.title3).foregroundStyle(ProTheme.secondary)
                    }
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            InstrumentArc(value: -62, range: -100 ... -40, band: -66 ... -60, threshold: -70)
                            VStack(spacing: 4) {
                                MeasurementValue(value: -62, kind: .bluetooth)
                                ChapterLine(parts: ["Example", "8 dB above threshold"], tint: ProTheme.band)
                            }.padding(.bottom, 8)
                        }
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        feature("Measure", text: "Bluetooth, motion, pressure, sound, location and connection tools.", symbol: "gauge.with.dots.needle.50percent")
                        feature("Understand", text: "Named baselines, guided calibration and aligned comparisons.", symbol: "slider.horizontal.3")
                        feature("Put it to work", text: "Local sessions, PDF and data exports, groups and Shortcuts workflows.", symbol: "arrow.triangle.branch")
                    }
                    Text("One Pro purchase unlocks the whole app. Available measurements depend on your device, permissions and connected equipment.")
                        .font(.footnote).foregroundStyle(ProTheme.secondary)
                    if let message = access.message { InlineFailure(message: message) }
                    VStack(spacing: 10) {
                        Button {
                            Task { await access.purchase() }
                        } label: {
                            HStack {
                                if access.isWorking { ProgressView().tint(.white) }
                                Text(access.product.map { "Unlock Pro · \($0.displayPrice)" } ?? "Unlock Pro")
                            }
                        }
                        .buttonStyle(ControlStyle())
                        .disabled(access.product == nil || access.isWorking)
                        .accessibilityIdentifier("pro.purchase")
                        Text("One-time purchase. No subscription or MagicCuts account.").font(.caption).foregroundStyle(ProTheme.secondary).frame(maxWidth: .infinity)
                        HStack {
                            Button("Restore purchases") { Task { await access.restore() } }.disabled(access.isWorking).frame(minHeight: 44)
                            Spacer()
                            if access.product == nil { Button("Try again") { Task { await access.loadProduct() } }.frame(minHeight: 44) }
                        }.font(.callout)
                        HStack {
                            Link("Privacy", destination: URL(string: "https://bradzellman.com/magiccuts-policies.html#privacy")!)
                            Spacer()
                            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        }.font(.footnote).frame(minHeight: 44)
                    }
                }
                .padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(MC.canvas)
            .navigationTitle("MagicCuts Pro")
            .navigationBarTitleDisplayMode(.inline)
        }.accessibilityIdentifier("pro.paywall")
    }

    private func feature(_ title: String, text: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title3).foregroundStyle(ProTheme.signal).frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(.headline, design: .rounded))
                Text(text).font(.callout).foregroundStyle(ProTheme.secondary)
            }
        }
    }
}

struct ProWorkspaceView: View {
    let radio: any RadioScanning
    @Bindable var access: ProAccess
    var guidanceWarning: String?
    var requestedRecordingID: UUID?
    @State private var engine: InstrumentEngine
    @State private var library: ProLibrary
    @State private var roomSession: RoomSession
    @State private var cellular = CellularInstrument()
    @State private var settings = false
    @State private var openSessions = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    init(radio: any RadioScanning, access: ProAccess, guidanceWarning: String?, requestedRecordingID: UUID? = nil) {
        self.radio = radio; self.access = access; self.guidanceWarning = guidanceWarning
        self.requestedRecordingID = requestedRecordingID
        let archive = InstrumentArchive(root: AppRuntime.roomUITestLibrary, useSharedContainer: !AppRuntime.isUITesting)
        _library = State(initialValue: ProLibrary(archive: archive))
        let roomSession = RoomSession()
        let engine = InstrumentEngine(archive: archive)
        engine.positionProvider = { [weak roomSession] date in roomSession?.placement(at: date) }
        _roomSession = State(initialValue: roomSession)
        _engine = State(initialValue: engine)
    }

    var body: some View {
        NavigationStack {
            InstrumentWorkspaceView(engine: engine, library: library, radio: radio, guidanceWarning: guidanceWarning)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { settings = true } label: {
                            Image(systemName: "gearshape")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityIdentifier("settings.open")
                    }
                }
                .toolbarBackground(MC.canvas, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .background(OpaqueNavigationBar())
                .sheet(isPresented: $settings) {
                    ProSettingsView(access: access, library: library, radio: workflowRadio, activeRecordingID: engine.recordingID)
                }
                .sheet(isPresented: $openSessions) {
                    NavigationStack {
                        SessionsView(library: library, activeRecordingID: engine.recordingID)
                            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { openSessions = false } } }
                    }
                }
        }
        .environment(roomSession)
        .environment(cellular)
        .onAppear { ProTheme.applyOpaqueNavigationBar() }
        .onChange(of: roomSession.cameraActive) { _, active in UIApplication.shared.isIdleTimerDisabled = active }
        .task {
            await SessionLiveActivity.endAbandoned()
            await library.sync.mirrorDevices(in: context)
            await library.reload()
            await library.seedDemoIfNeeded()
            #if DEBUG
            await FieldDemo.seed(library)
            #endif
            cellular.positionProvider = { [weak roomSession] date in roomSession?.placement(at: date) }
            if !AppRuntime.isUITesting { cellular.start(library: library) }
            await library.sync.transport.resume()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { engine.interruptedByBackground(); roomSession.backgrounded(); cellular.stopForecasts() }
            else if phase == .active {
                Task {
                    await library.sync.mirrorDevices(in: context)
                    await library.reload()
                    await library.sync.transport.resume()
                }
            }
        }
        .onChange(of: library.index.sequence) { _, _ in
            Task { await library.cleanDeletedFiles(); await library.sync.transport.localLibraryChanged() }
        }
        .onChange(of: library.sync.snapshot.libraryRevision) { _, _ in Task { await library.reload() } }
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            Task { await library.sync.mirrorDevices(in: context); await library.reload() }
        }
        .onChange(of: requestedRecordingID, initial: true) { _, id in
            if id != nil { openSessions = true }
        }
        .onDisappear {
            engine.stop(reason: "Pro experience closed"); engine.endLiveActivity()
            roomSession.end()
            cellular.stop()
            UIApplication.shared.isIdleTimerDisabled = false
            Task { await library.sync.transport.suspend() }
        }
    }

    private var workflowRadio: any RadioScanning { AppRuntime.isUITesting ? DemoRadio() : BluetoothRadio() }
}

struct InstrumentWorkspaceView: View {
    @Bindable var engine: InstrumentEngine
    @Bindable var library: ProLibrary
    let radio: any RadioScanning
    var guidanceWarning: String?
    @Query(sort: \MonitoredDevice.name) private var devices: [MonitoredDevice]
    @State private var mode: InstrumentViewMode = .live
    @State private var chosenKind: InstrumentKind = .bluetooth
    @State private var chosenDeviceID: String?
    @State private var selectedElapsed: Double?
    @State private var baselineID: UUID?
    @State private var picker = false
    @State private var pickerDetent: PresentationDetent = .large
    @State private var baselineSheet = false
    @State private var saveSheet = false
    @State private var devicesSheet = false
    @State private var endpointSheet = false
    @State private var markSheet = false
    @State private var calibrationSheet = false
    @State private var startFlow = false
    @State private var chooseWorkflow = false
    @State private var newWorkflow = false
    @State private var roomCapture = false
    @State private var pendingFlow: String?
    @State private var failure: String?
    @State private var endpoint = ""
    @State private var fieldCapture: FieldCapture?
    @Environment(RoomSession.self) private var roomSession
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var source: MeasurementSource {
        if chosenKind == .bluetooth {
            if let device = devices.first(where: { $0.persistentIdentifier == chosenDeviceID }) ?? devices.first {
                return .bluetooth(DeviceInfo(id: device.persistentIdentifier, name: device.name, rssi: device.requiredSignalStrength, serviceUUIDs: device.serviceUUIDs))
            }
            if AppRuntime.isInstrumentDemo { return InstrumentDemo.session().source }
            return MeasurementSource(id: "unselected-bluetooth", name: "Choose a device")
        }
        if chosenKind == .network {
            return MeasurementSource(id: endpoint, name: URL(string: endpoint)?.host ?? "Choose an endpoint", endpoint: endpoint.isEmpty ? nil : endpoint)
        }
        return .phone
    }
    private var selectedPoint: MeasurementPoint? {
        guard let selectedElapsed else { return engine.latest }
        return engine.points.min { abs($0.elapsed - selectedElapsed) < abs($1.elapsed - selectedElapsed) }
    }
    private var baseline: CalibrationProfile? { library.index.profiles.first { $0.id == baselineID && $0.matches(kind: chosenKind, source: source, metadata: engine.metadata) } }
    private var availableProfiles: [CalibrationProfile] { library.index.profiles.filter { $0.matches(kind: chosenKind, source: source, metadata: engine.metadata) } }
    private var range: ClosedRange<Double> { chosenKind.displayRange(values: engine.points.map(\.value) + (baseline?.points.map(\.value) ?? [])) }
    private var observedBand: ClosedRange<Double>? {
        guard let summary = engine.summary, summary.count >= 3 else { return nil }
        return summary.q25 ... summary.q75
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                RoomOrientationBanner()
                if let guidanceWarning {
                    Text(guidanceWarning).font(.footnote).foregroundStyle(ProTheme.secondary)
                }
                homeSelector
                if chosenKind == .bluetooth || chosenKind == .network {
                    sourceChip
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                InstrumentSegments(selection: $mode)
                if let message = failure ?? engine.phase.explanation { recovery(message) }
                if chosenKind == .bluetooth, source.deviceID == nil {
                    ContentUnavailableView("Choose your first device", systemImage: "wave.3.right", description: Text("Save a Bluetooth device, then find a useful threshold for your setup."))
                    Button("Find a device") { devicesSheet = true }.buttonStyle(ControlStyle())
                } else {
                    if mode == .compare { comparison }
                    else if mode == .inspect { inspection }
                    else { liveFace }
                    if !engine.points.isEmpty, mode == .live || (mode == .compare && baseline != nil) {
                        if mode != .inspect { history(height: 120, subordinate: mode == .compare) }
                        if mode == .live {
                            baselineControl
                            if chosenKind == .bluetooth {
                                Button("Calibrate nearby and away") { engine.pause(); calibrationSheet = true }
                                    .font(.system(.callout, design: .rounded).weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                                    .disabled(engine.recording)
                            }
                        }
                    }
                    if mode == .inspect {
                        if let spectrum = engine.spectrum { SpectrumChart(spectrum: spectrum) }
                        methodDetails
                    }
                }
                if let error = library.error { InlineFailure(message: error) }
                if let warning = engine.persistenceWarning {
                    InlineFailure(message: warning)
                    Button("Retry recovery save") { engine.retryCheckpoint() }.frame(minHeight: 44)
                }
                if let warning = engine.liveActivityWarning { Text(warning).font(.caption).foregroundStyle(ProTheme.secondary) }
                if dynamicType.isAccessibilitySize, source.deviceID != nil || chosenKind != .bluetooth {
                    if engine.recording { recordingControls } else { homeActions }
                }
            }
            .padding(.horizontal, 22).padding(.top, 8)
            .padding(.bottom, dynamicType.isAccessibilitySize ? 64 : 28)
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(MC.canvas)
        .scrollEdgeEffectStyle(.hard, for: .top)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(MC.canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .overlay {
            GeometryReader { proxy in
                let cover = proxy.safeAreaInsets.top + 12
                MC.canvas
                    .frame(width: proxy.size.width, height: cover)
                    .position(x: proxy.size.width / 2, y: -proxy.safeAreaInsets.top + cover / 2)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .background(OpaqueNavigationBar())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicType.isAccessibilitySize {
                if engine.recording { recordingControls }
                else if source.deviceID != nil || chosenKind != .bluetooth { homeActions }
            }
        }
        .sheet(isPresented: $picker) {
            InstrumentPickerView(selected: chosenKind) { choice in
                chosenKind = choice; selectedElapsed = nil; baselineID = nil; picker = false
                if choice == .network && endpoint.isEmpty { endpointSheet = true }
                else if choice == .bluetooth && source.deviceID == nil { devicesSheet = true }
                else { Task { await start() } }
            }
            .presentationDetents([.medium, .large], selection: $pickerDetent)
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $fieldCapture) { FieldCaptureSaveView(capture: $0, library: library) }
        .sheet(isPresented: $devicesSheet, onDismiss: { if chosenKind == .bluetooth { Task { await start() } } }) {
            ContentView(radio: radio)
                .safeAreaInset(edge: .bottom) { Button("Done") { devicesSheet = false }.frame(maxWidth: .infinity, minHeight: 44).background(.bar) }
        }
        .sheet(isPresented: $endpointSheet) {
            EndpointConfigurationView(endpoint: $endpoint) {
                endpointSheet = false
                Task { await start() }
            }
        }
        .sheet(isPresented: $baselineSheet) { BaselineEditorView(engine: engine, library: library) { id in baselineID = id } }
        .sheet(isPresented: $saveSheet) { SaveSessionView(engine: engine, library: library, baseline: baseline) }
        .sheet(isPresented: $markSheet) { SessionMarkView { engine.mark($0) } }
        .sheet(isPresented: $calibrationSheet) {
            BluetoothCalibrationView(source: source, radio: radio, library: library)
        }
        .sheet(isPresented: $startFlow, onDismiss: {
            if pendingFlow == "choose" { chooseWorkflow = true }
            if pendingFlow == "create" { newWorkflow = true }
            pendingFlow = nil
        }) {
            StartFlowPrompt(
                onChoose: { pendingFlow = "choose"; startFlow = false },
                onCreate: { pendingFlow = "create"; startFlow = false }
            )
        }
        .sheet(isPresented: $chooseWorkflow) { WorkflowChooseView(library: library, radio: radio) }
        .sheet(isPresented: $newWorkflow) { WorkflowEditorView(library: library, recipe: nil) }
        .sheet(isPresented: $roomCapture) { RoomCaptureView(library: library, purpose: .newRoom) }
        .task {
            if AppRuntime.isInstrumentDemo {
                engine.loadDemo(kind: chosenKind)
            }
        }
        .onChange(of: picker) { _, open in if open { pickerDetent = .large } }
        .onChange(of: mode) { _, new in
            selectedElapsed = nil
            if new == .compare, baselineID == nil, let first = availableProfiles.first {
                baselineID = first.id
            }
        }
        .onChange(of: baselineID) { _, _ in selectedElapsed = nil }
    }

    @ViewBuilder private var homeSelector: some View {
        if dynamicType.isAccessibilitySize {
            VStack(spacing: 10) {
                instrumentPickerButton
                newRoomButton
            }
        } else {
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    instrumentPickerButton.gridCellColumns(2)
                    newRoomButton
                }
            }
        }
    }

    private var instrumentPickerButton: some View {
        Button {
            engine.pause(); picker = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: chosenKind.symbol).foregroundStyle(ProTheme.signal).accessibilityHidden(true)
                Text(chosenKind.title).font(.system(.headline, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(ProTheme.secondary).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 14)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(engine.recording)
        .accessibilityLabel("Instruments")
        .accessibilityValue(chosenKind.title)
        .accessibilityIdentifier("instrument.choose")
    }

    private var newRoomButton: some View {
        Button { engine.pause(); roomCapture = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "viewfinder")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
                if dynamicType.isAccessibilitySize || sizeClass == .regular {
                    Text(dynamicType.isAccessibilitySize ? "New room" : "Room")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .lineLimit(dynamicType.isAccessibilitySize ? 2 : 1)
                        .minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 6)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(engine.recording)
        .accessibilityLabel("New room")
        .accessibilityIdentifier("rooms.capture")
    }

    private var homeActions: some View {
        let split = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
        return VStack(spacing: 10) {
            if !engine.phase.isActive {
                Button(engine.phase == .paused ? "Resume measuring" : "Start measuring") { Task { await start() } }
                    .font(.system(.callout, design: .rounded).weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("instrument.start")
            }
            split {
                Button {
                    if let point = selectedPoint { fieldCapture = .reading(point, kind: chosenKind, source: source) }
                } label: {
                    Label("Log", systemImage: "plus.viewfinder").font(.system(.callout, design: .rounded).weight(.semibold))
                }
                .buttonStyle(ControlStyle())
                .disabled(selectedPoint == nil)
                .accessibilityIdentifier("instrument.log")
                .accessibilityLabel("Log")

                Button { Task { await beginRecording() } } label: {
                    Label("Record", systemImage: "record.circle").font(.system(.callout, design: .rounded).weight(.semibold))
                }
                .buttonStyle(ControlStyle(primary: false))
                .accessibilityIdentifier("instrument.record")
            }
            Button { startFlow = true } label: {
                Label("Start Flow", systemImage: "arrow.triangle.branch").font(.system(.callout, design: .rounded).weight(.semibold))
            }
            .buttonStyle(ControlStyle(primary: false))
            .accessibilityIdentifier("instrument.start-flow")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(dynamicType.isAccessibilitySize ? MC.canvas : Color.clear)
        .background { if !dynamicType.isAccessibilitySize { Rectangle().fill(.bar) } }
    }

    private var liveFace: some View {
        VStack(spacing: 8) {
            if dynamicType.isAccessibilitySize {
                MeasurementValue(value: selectedPoint?.value, kind: chosenKind)
                readingChapter
                liveInstrument
            } else {
                ZStack(alignment: chosenKind == .heading ? .center : .bottom) {
                    liveInstrument
                    MeasurementValue(value: selectedPoint?.value, kind: chosenKind)
                        .padding(.bottom, chosenKind == .heading ? 0 : 48)
                }
                readingChapter
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var liveInstrument: some View {
        if chosenKind == .tilt {
            LevelInstrument(point: selectedPoint, reference: baseline?.points.last)
        } else if chosenKind == .heading {
            CompassInstrument(heading: selectedPoint?.value, baseline: baseline?.summary.median)
        } else {
            InstrumentArc(value: selectedPoint?.value, range: range, band: observedBand, threshold: source.threshold)
        }
    }

    private var readingChapter: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let stale = engine.latest.map { context.date.timeIntervalSince($0.date) > chosenKind.maximumAge } ?? false
            let phase = engine.demonstration
                ? "Sample session"
                : selectedElapsed != nil ? "Pinned reading"
                : stale && engine.phase == .running ? "Waiting for a fresh reading"
                : engine.phase.title
            Group {
                if dynamicType.isAccessibilitySize {
                    VStack(spacing: 4) {
                        if engine.phase == .starting { ProgressView().controlSize(.mini) }
                        Text(phase).accessibilityIdentifier("instrument.phase")
                        if !chapterInterpretation.isEmpty { Text(chapterInterpretation) }
                    }
                } else {
                    HStack(spacing: 5) {
                        if engine.phase == .starting { ProgressView().controlSize(.mini) }
                        Text(phase).accessibilityIdentifier("instrument.phase")
                        if !chapterInterpretation.isEmpty {
                            Text("·").accessibilityHidden(true)
                            Text(chapterInterpretation)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                }
            }
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(chapterTint)
            .multilineTextAlignment(.center)
            .monospacedDigit()
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var sourceChip: some View {
        if chosenKind == .bluetooth {
            Menu {
                ForEach(devices) { device in
                    Button(device.name) {
                        chosenDeviceID = device.persistentIdentifier; baselineID = nil
                        Task { await start() }
                    }
                }
                Button("Manage devices") { engine.pause(); devicesSheet = true }
            } label: {
                HStack(spacing: 3) {
                    Text(source.name)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 8, weight: .semibold)).accessibilityHidden(true)
                }
                .foregroundStyle(ProTheme.signal)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(engine.recording)
            .accessibilityIdentifier("instrument.device-menu")
        } else if chosenKind == .network {
            Button(source.name) { engine.pause(); endpointSheet = true }
                .foregroundStyle(ProTheme.signal)
                .frame(minHeight: 44)
                .disabled(engine.recording)
        } else {
            Text(source.name)
        }
    }

    private var chapterInterpretation: String {
        if let baseline, let value = selectedPoint?.value { return baselineChange(value: value, baseline: baseline) }
        if chosenKind == .tilt, let point = selectedPoint {
            let pitch = point.auxiliary["pitch"] ?? 0
            let roll = point.auxiliary["roll"] ?? 0
            if abs(pitch) < 0.5 && abs(roll) < 0.5 { return "Level" }
            return "R \(roll.formatted(.number.precision(.fractionLength(1))))° · P \(pitch.formatted(.number.precision(.fractionLength(1))))°"
        }
        if let threshold = source.threshold, let value = selectedPoint?.value {
            return "\(abs(value - threshold).formatted(.number.precision(.fractionLength(0)))) dB \(value >= threshold ? "above" : "below")"
        }
        if chosenKind == .sound { return "Digital level, not dB SPL" }
        return ""
    }

    private var chapterTint: Color {
        if baseline != nil { return ProTheme.signal }
        if let threshold = source.threshold, let value = selectedPoint?.value, value >= threshold { return ProTheme.band }
        return ProTheme.secondary
    }

    private func baselineChange(value: Double, baseline: CalibrationProfile) -> String {
        if chosenKind == .tilt, let point = selectedPoint, let reference = baseline.points.last,
           let angle = MeasurementMath.tiltDifference(point, reference: reference) {
            return "\(chosenKind.formatted(angle))° from \(baseline.name)"
        }
        return "\(chosenKind.formatted(MeasurementMath.delta(value, baseline: baseline.summary.median, kind: chosenKind), signed: true)) \(chosenKind.deltaUnit) from \(baseline.name)"
    }

    private var inspection: some View {
        VStack(alignment: .leading, spacing: 14) {
            MeasurementValue(value: selectedPoint?.value, kind: chosenKind)
                .frame(maxWidth: .infinity)
            Text(chosenKind.method)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(ProTheme.secondary)
            if let summary = engine.summary, summary.count >= 3 {
                ChapterLine(parts: [
                    "Median \(chosenKind.formatted(summary.median)) \(chosenKind.unit)",
                    "Middle 50% \(chosenKind.formatted(summary.spread)) \(chosenKind.deltaUnit)"
                ])
            }
            LinearInstrumentScale(range: range, value: selectedPoint?.value, band: observedBand, threshold: source.threshold)
            history(height: 168)
        }
    }

    @ViewBuilder private var comparison: some View {
        if let baseline, let summary = engine.summary {
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 4) {
                    MeasurementValue(
                        value: MeasurementMath.delta(summary.median, baseline: baseline.summary.median, kind: chosenKind),
                        kind: chosenKind,
                        signed: true
                    )
                    ChapterLine(parts: ["Change in median", baseline.name])
                }
                .frame(maxWidth: .infinity)
                comparisonReading(title: baseline.name, summary: baseline.summary)
                comparisonReading(title: "Current", summary: summary)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("No baseline yet")
                    .font(.system(.headline, design: .rounded))
                Text("Save a reference from this setup, then Compare shows the change in median.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(ProTheme.secondary)
                if !availableProfiles.isEmpty {
                    profileMenu
                } else {
                    Button("Set baseline") { baselineSheet = true }
                        .buttonStyle(ControlStyle())
                        .disabled((engine.summary?.count ?? 0) < 3)
                }
            }
        }
    }

    private func comparisonReading(title: String, summary: MeasurementSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ChapterLine(parts: [
                title,
                "\(chosenKind.formatted(summary.median)) \(chosenKind.unit)"
            ])
            LinearInstrumentScale(range: range, value: summary.median, band: summary.q25 ... summary.q75)
        }
    }

    private func history(height: CGFloat, subordinate: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !subordinate || selectedElapsed != nil {
                HStack {
                    if selectedElapsed != nil {
                        Button("Return to live") { selectedElapsed = nil }
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                            .frame(minHeight: 44)
                    } else {
                        Text("Touch a reading")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(ProTheme.secondary)
                    }
                    Spacer()
                }
            }
            InstrumentHistoryChart(points: engine.points, kind: chosenKind, range: range, baseline: mode == .compare ? baseline?.points ?? [] : [], threshold: source.threshold, events: engine.events, selectedElapsed: $selectedElapsed, height: height)
            if !subordinate {
                Text("Elapsed seconds · gaps are unobserved")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(ProTheme.secondary)
            }
        }
    }

    private var baselineControl: some View {
        VStack(spacing: 8) {
            if !availableProfiles.isEmpty { profileMenu }
            else if baselineID != nil {
                Text("This baseline doesn't match the current source or input. Capture a new reference.")
                    .font(.callout).foregroundStyle(ProTheme.secondary)
            }
            Button("Set baseline") { baselineSheet = true }
                .buttonStyle(ControlStyle(primary: false))
                .disabled((engine.summary?.count ?? 0) < 3 || engine.recording)
                .accessibilityIdentifier("instrument.set-baseline")
        }
    }

    private var profileMenu: some View {
        Menu {
            Button("No baseline") { baselineID = nil }
            ForEach(availableProfiles) { profile in Button(profile.name) { baselineID = profile.id } }
            Button("Capture another baseline") { baselineSheet = true }
        } label: {
            HStack {
                Image(systemName: "slider.horizontal.3").accessibilityHidden(true)
                Text(baseline?.name ?? "Choose baseline")
                    .lineLimit(1)
                    .minimumScaleFactor(dynamicType.isAccessibilitySize ? 0.4 : 0.8)
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down").font(.caption).accessibilityHidden(true)
            }
            .font(.callout)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .clipped()
            .contentShape(Rectangle())
        }.accessibilityIdentifier("instrument.baseline")
    }

    private var methodDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Evidence").font(.system(.headline, design: .rounded))
            if chosenKind == .network {
                LabeledContent("Successful responses", value: "\(engine.completedRequests)")
                LabeledContent("Failed requests", value: "\(engine.failedRequests)")
                LabeledContent("Observed path", value: engine.pathDescription)
            }
            LabeledContent("Retained readings", value: "\(engine.points.count)")
            ForEach(engine.metadata.keys.sorted().filter { !["audioInput", "referenceFrame", "installationID"].contains($0) }, id: \.self) { key in
                LabeledContent(MeasurementMetadata.label(key), value: engine.metadata[key] ?? "").font(.caption)
            }
            ForEach(engine.events.suffix(10)) { event in
                HStack(alignment: .top) { Text("\(event.elapsed.formatted(.number.precision(.fractionLength(1))))s").monospacedDigit(); Text(event.text) }.font(.caption)
            }
        }
    }

    private func recovery(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(message).font(.callout)
            HStack {
                Button("Try again") { Task { await start() } }.frame(minHeight: 44)
                Spacer()
                if case .denied = engine.phase {
                    Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!).frame(minHeight: 44)
                }
            }
        }.padding(16).background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private var recordingControls: some View {
        VStack(spacing: 10) {
            HStack {
                Label("\(engine.recordingDuration.formatted(.number.precision(.fractionLength(0))))s · \(engine.recordingCount) readings", systemImage: "record.circle")
                    .font(.caption).monospacedDigit().foregroundStyle(ProTheme.secondary)
                Spacer()
                Button("Mark") { markSheet = true }.font(.callout.weight(.semibold)).frame(minHeight: 44)
                Button(engine.phase == .paused ? "Resume" : "Pause") {
                    if engine.phase == .paused { Task { await engine.resume(radio: radio) } }
                    else { engine.pause() }
                }.font(.callout.weight(.semibold)).frame(minHeight: 44)
            }
            Button {
                engine.stop(); saveSheet = true
            } label: {
                Label { Text("Finish recording").font(.system(.callout, design: .rounded).weight(.semibold)) }
                    icon: { Image(systemName: "stop.fill") }
            }
            .buttonStyle(ControlStyle())
            .accessibilityIdentifier("instrument.record")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func start() async {
        failure = nil; selectedElapsed = nil
        await engine.start(kind: chosenKind, source: source, radio: radio)
    }

    private func beginRecording() async {
        if !engine.phase.isActive { await start() }
        guard engine.phase.isActive else { return }
        engine.beginRecording()
    }
}
