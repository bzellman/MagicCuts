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
                    VStack(spacing: 0) {
                        InstrumentArc(value: -62, range: -100 ... -40, band: -66 ... -60, threshold: -70)
                        MeasurementValue(value: -62, kind: .bluetooth).padding(.top, -8)
                        Text("Example · 8 dB above your threshold").font(.callout).foregroundStyle(ProTheme.band).padding(.top, 8)
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
    @State private var selectedTab = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    init(radio: any RadioScanning, access: ProAccess, guidanceWarning: String?, requestedRecordingID: UUID? = nil) {
        self.radio = radio; self.access = access; self.guidanceWarning = guidanceWarning
        self.requestedRecordingID = requestedRecordingID
        let archive = InstrumentArchive(useSharedContainer: !AppRuntime.isUITesting)
        _library = State(initialValue: ProLibrary(archive: archive))
        _engine = State(initialValue: InstrumentEngine(archive: archive))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Instruments", systemImage: "waveform.path", value: 0) {
                NavigationStack { InstrumentWorkspaceView(engine: engine, library: library, access: access, radio: radio) }
            }
            Tab("Sessions", systemImage: "doc.text", value: 1) {
                NavigationStack { SessionsView(library: library, activeRecordingID: engine.recordingID) }
            }
            Tab("Workflows", systemImage: "arrow.triangle.branch", value: 2) {
                NavigationStack { WorkflowsView(library: library, radio: AppRuntime.isUITesting ? DemoRadio() : BluetoothRadio()) }
            }
        }
        .task {
            await SessionLiveActivity.endAbandoned()
            await library.sync.mirrorDevices(in: context)
            await library.reload()
            await library.seedDemoIfNeeded()
            await library.sync.transport.resume()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { engine.interruptedByBackground() }
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
        .onChange(of: selectedTab) { old, new in
            if old == 0, new != 0, !engine.recording { engine.pause() }
        }
        .onChange(of: requestedRecordingID, initial: true) { _, id in
            if let id { selectedTab = engine.recordingID == id ? 0 : 1 }
        }
        .onDisappear {
            engine.stop(reason: "Pro experience closed"); engine.endLiveActivity()
            Task { await library.sync.transport.suspend() }
        }
    }
}

struct InstrumentWorkspaceView: View {
    @Bindable var engine: InstrumentEngine
    @Bindable var library: ProLibrary
    @Bindable var access: ProAccess
    let radio: any RadioScanning
    @Query(sort: \MonitoredDevice.name) private var devices: [MonitoredDevice]
    @State private var mode: InstrumentViewMode = .live
    @State private var chosenKind: InstrumentKind = .bluetooth
    @State private var chosenDeviceID: String?
    @State private var selectedElapsed: Double?
    @State private var baselineID: UUID?
    @State private var picker = false
    @State private var settings = false
    @State private var baselineSheet = false
    @State private var saveSheet = false
    @State private var devicesSheet = false
    @State private var endpointSheet = false
    @State private var markSheet = false
    @State private var calibrationSheet = false
    @State private var failure: String?
    @State private var endpoint = ""
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.horizontalSizeClass) private var horizontalSize

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
            VStack(spacing: 16) {
                sourceControl
                InstrumentSegments(selection: $mode)
                statusLine
                if let message = failure ?? engine.phase.explanation { recovery(message) }
                if chosenKind == .bluetooth, source.deviceID == nil {
                    ContentUnavailableView("Choose your first device", systemImage: "wave.3.right", description: Text("Save a Bluetooth device, then find a useful threshold for your setup."))
                    Button("Find a device") { devicesSheet = true }.buttonStyle(ControlStyle())
                } else {
                    if mode == .compare { comparison }
                    else if mode == .inspect { inspection }
                    else { liveFace }
                    if !engine.points.isEmpty {
                        if mode != .inspect { history(height: mode == .compare ? 190 : 120) }
                        if mode != .compare { statistics }
                        baselineControl
                        if chosenKind == .bluetooth {
                            Button("Calibrate nearby and away") { engine.pause(); calibrationSheet = true }
                                .font(.system(.headline, design: .rounded)).frame(minHeight: 44).disabled(engine.recording)
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
                if dynamicType.isAccessibilitySize, source.deviceID != nil || chosenKind != .bluetooth { recordingControls }
            }
            .padding(.horizontal, 22).padding(.top, 8).padding(.bottom, 28)
            .frame(maxWidth: 680).frame(maxWidth: .infinity)
        }
        .background(MC.canvas)
        .navigationTitle("Instruments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button { settings = true } label: { Label("Settings", systemImage: "gearshape") }.frame(minWidth: 44, minHeight: 44) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !dynamicType.isAccessibilitySize, source.deviceID != nil || chosenKind != .bluetooth { recordingControls }
        }
        .sheet(isPresented: $picker) {
            InstrumentPickerView(selected: chosenKind) { choice in
                chosenKind = choice; selectedElapsed = nil; baselineID = nil; picker = false
                if choice == .network && endpoint.isEmpty { endpointSheet = true }
                else if choice == .bluetooth && source.deviceID == nil { devicesSheet = true }
                else { Task { await start() } }
            }
        }
        .sheet(isPresented: $settings) { ProSettingsView(access: access, library: library) }
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
        .task {
            if AppRuntime.isInstrumentDemo {
                engine.loadDemo(kind: chosenKind)
            }
        }
        .onChange(of: mode) { _, _ in selectedElapsed = nil }
        .onChange(of: baselineID) { _, _ in selectedElapsed = nil }
    }

    private var sourceControl: some View {
        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            Button {
                engine.pause(); picker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: chosenKind.symbol).foregroundStyle(ProTheme.signal)
                    Text(chosenKind.title).font(.system(.headline, design: .rounded))
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold)).foregroundStyle(ProTheme.secondary)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(engine.recording).accessibilityIdentifier("instrument.choose")
            if !dynamicType.isAccessibilitySize { Spacer(minLength: 4) }
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
                    Text(source.name).font(.callout).foregroundStyle(ProTheme.signal).lineLimit(2).frame(minHeight: 44)
                }.disabled(engine.recording).accessibilityIdentifier("instrument.device-menu")
            } else if chosenKind == .network {
                Button(source.name) { engine.pause(); endpointSheet = true }.font(.callout).frame(minHeight: 44).disabled(engine.recording)
            }
        }
    }

    private var statusLine: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let stale = engine.latest.map { context.date.timeIntervalSince($0.date) > chosenKind.maximumAge } ?? false
            HStack(spacing: 8) {
                if engine.phase == .starting { ProgressView().controlSize(.small) }
                else { Circle().fill(engine.phase.isActive && !stale ? ProTheme.signal : Color.secondary).frame(width: 5, height: 5).accessibilityHidden(true) }
                Text(engine.demonstration ? "Sample session" : selectedElapsed != nil ? "Inspecting a reading" : stale && engine.phase == .running ? "Waiting for a fresh reading" : engine.phase.title)
                    .accessibilityIdentifier("instrument.phase")
                Spacer()
                if let point = selectedPoint {
                    if selectedElapsed != nil { Text("\(point.elapsed.formatted(.number.precision(.fractionLength(1))))s") }
                    else if !engine.demonstration { Text(point.date, style: .relative) }
                }
            }.font(.caption).foregroundStyle(ProTheme.secondary).monospacedDigit()
        }
    }

    private var liveFace: some View {
        VStack(spacing: 8) {
            if chosenKind == .tilt {
                LevelInstrument(point: selectedPoint, reference: baseline?.points.last)
            } else if chosenKind == .heading {
                CompassInstrument(heading: selectedPoint?.value, baseline: baseline?.summary.median)
            } else {
                InstrumentArc(value: selectedPoint?.value, range: range, band: observedBand, threshold: source.threshold)
            }
            MeasurementValue(value: selectedPoint?.value, kind: chosenKind)
                .padding(.top, dynamicType.isAccessibilitySize ? 0 : -16)
            if let baseline, let value = selectedPoint?.value {
                Text(baselineChange(value: value, baseline: baseline))
                    .font(.callout).foregroundStyle(ProTheme.signal).multilineTextAlignment(.center)
            } else if let threshold = source.threshold, let value = selectedPoint?.value {
                Text("\(abs(value - threshold).formatted(.number.precision(.fractionLength(0)))) dB \(value >= threshold ? "above" : "below") your threshold")
                    .font(.callout).foregroundStyle(value >= threshold ? ProTheme.band : .secondary)
            } else {
                Text(chosenKind == .sound ? "Digital level · not dB SPL" : source.name)
                    .font(.callout).foregroundStyle(ProTheme.secondary)
            }
        }.frame(maxWidth: .infinity).padding(.bottom, 4)
    }

    private func baselineChange(value: Double, baseline: CalibrationProfile) -> String {
        if chosenKind == .tilt, let point = selectedPoint, let reference = baseline.points.last,
           let angle = MeasurementMath.tiltDifference(point, reference: reference) {
            return "\(chosenKind.formatted(angle))° from \(baseline.name)"
        }
        return "\(chosenKind.formatted(MeasurementMath.delta(value, baseline: baseline.summary.median, kind: chosenKind), signed: true)) \(chosenKind.deltaUnit) from \(baseline.name)"
    }

    private var inspection: some View {
        VStack(alignment: .leading, spacing: 22) {
            MeasurementValue(value: selectedPoint?.value, kind: chosenKind)
            LinearInstrumentScale(range: range, value: selectedPoint?.value, band: observedBand, threshold: source.threshold)
            history(height: 260)
        }
    }

    @ViewBuilder private var comparison: some View {
        if let baseline, let summary = engine.summary {
            VStack(alignment: .leading, spacing: 24) {
                comparisonReading(title: baseline.name, summary: baseline.summary)
                comparisonReading(title: "Current measurement", summary: summary)
                VStack(spacing: 4) {
                    Text("Change in median").font(.callout).foregroundStyle(ProTheme.secondary)
                    MeasurementValue(value: MeasurementMath.delta(summary.median, baseline: baseline.summary.median, kind: chosenKind), kind: chosenKind, signed: true)
                        .foregroundStyle(ProTheme.signal)
                }.frame(maxWidth: .infinity)
                Text("Both measurements use the same scale. Dashed line: \(baseline.name). Solid line: current measurement.")
                    .font(.caption).foregroundStyle(ProTheme.secondary)
            }
        } else {
            ContentUnavailableView("Compare with a baseline", systemImage: "slider.horizontal.3", description: Text("Save a reference from a measured setup, then see how your next measurement changes."))
            if !availableProfiles.isEmpty {
                profileMenu
            } else {
                Button("Set baseline") { baselineSheet = true }.buttonStyle(ControlStyle()).disabled((engine.summary?.count ?? 0) < 3)
            }
        }
    }

    private func comparisonReading(title: String, summary: MeasurementSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            layout {
                Text(title).font(.system(.headline, design: .rounded))
                Spacer()
                MeasurementValue(value: summary.median, kind: chosenKind, compact: true)
            }
            LinearInstrumentScale(range: range, value: summary.median, band: summary.q25 ... summary.q75)
        }
    }

    private func history(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
            layout {
                Text(chosenKind.unit).font(.caption).foregroundStyle(ProTheme.secondary)
                Spacer()
                if selectedElapsed != nil {
                    Button("Return to live") { selectedElapsed = nil }.font(.caption.weight(.semibold)).frame(minHeight: 44)
                } else {
                    Text("Touch to inspect").font(.caption).foregroundStyle(ProTheme.secondary)
                }
            }
            InstrumentHistoryChart(points: engine.points, kind: chosenKind, range: range, baseline: mode == .compare ? baseline?.points ?? [] : [], threshold: source.threshold, events: engine.events, selectedElapsed: $selectedElapsed, height: height)
            Text("Elapsed seconds · gaps are unobserved").font(.caption).foregroundStyle(ProTheme.secondary)
        }
    }

    private var statistics: some View {
        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 20)) : AnyLayout(HStackLayout(alignment: .top, spacing: 20))
        return layout {
            statistic("Median", value: engine.summary.map { "\(chosenKind.formatted($0.median)) \(chosenKind.unit)" } ?? "—")
            Spacer()
            statistic(chosenKind == .network ? "95th percentile" : "Middle 50% spread", value: engine.summary.map { "\(chosenKind.formatted(chosenKind == .network ? $0.p95 : $0.spread)) \(chosenKind == .network ? chosenKind.unit : chosenKind.deltaUnit)" } ?? "—")
        }.padding(.vertical, 4)
    }

    private func statistic(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).foregroundStyle(ProTheme.secondary)
            Text(value).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
        }
    }

    private var baselineControl: some View {
        VStack(spacing: 8) {
            if !availableProfiles.isEmpty { profileMenu }
            else if baselineID != nil {
                Text("This baseline doesn't match the current source or input. Capture a new reference.")
                    .font(.callout).foregroundStyle(ProTheme.secondary)
            }
        }
    }

    private var profileMenu: some View {
        Menu {
            Button("No baseline") { baselineID = nil }
            ForEach(availableProfiles) { profile in Button(profile.name) { baselineID = profile.id } }
            Button("Capture another baseline") { baselineSheet = true }
        } label: {
            HStack { Image(systemName: "slider.horizontal.3"); Text(baseline?.name ?? "Choose baseline"); Spacer(); Image(systemName: "chevron.up.chevron.down").font(.caption) }
                .font(.callout).frame(minHeight: 44)
        }.accessibilityIdentifier("instrument.baseline")
    }

    private var methodDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How this is measured").font(.system(.headline, design: .rounded))
            Text(chosenKind.method).font(.callout).foregroundStyle(ProTheme.secondary)
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
            if engine.recording {
                HStack {
                    Label("\(engine.recordingDuration.formatted(.number.precision(.fractionLength(0))))s · \(engine.recordingCount) readings", systemImage: "record.circle").font(.caption).monospacedDigit()
                    Spacer()
                    Button("Mark") { markSheet = true }.font(.callout).frame(minHeight: 44)
                    Button(engine.phase == .paused ? "Resume" : "Pause") {
                        if engine.phase == .paused { Task { await engine.resume(radio: radio) } }
                        else { engine.pause() }
                    }.font(.callout).frame(minHeight: 44)
                }
            }
            let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 12))
            layout {
                Button {
                    if engine.recording {
                        engine.stop(); saveSheet = true
                    } else {
                        Task {
                            if !engine.phase.isActive { await start() }
                            guard engine.phase.isActive else { return }
                            engine.beginRecording()
                        }
                    }
                } label: {
                    Label { Text(engine.recording ? "Finish recording" : "Record session").font(.system(.callout, design: .rounded).weight(.semibold)) }
                        icon: { Image(systemName: engine.recording ? "stop.fill" : "record.circle") }
                }.buttonStyle(ControlStyle()).accessibilityIdentifier("instrument.record")
                if !engine.recording {
                    Button("Set baseline") { baselineSheet = true }
                        .buttonStyle(ControlStyle(primary: false))
                        .frame(maxWidth: dynamicType.isAccessibilitySize || horizontalSize == .regular ? .infinity : 140)
                        .disabled((engine.summary?.count ?? 0) < 3)
                        .accessibilityIdentifier("instrument.set-baseline")
                }
            }
            if !engine.phase.isActive && !engine.recording {
                Button(engine.phase == .paused ? "Resume measuring" : "Start measuring") { Task { await start() } }
                    .font(.system(.callout, design: .rounded).weight(.semibold)).frame(minHeight: 44)
                    .accessibilityIdentifier("instrument.start")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: 720).frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func start() async {
        failure = nil; selectedElapsed = nil
        await engine.start(kind: chosenKind, source: source, radio: radio)
    }
}
