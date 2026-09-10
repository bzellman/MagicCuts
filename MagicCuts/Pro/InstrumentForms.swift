import SwiftUI
import SwiftData

struct InstrumentPickerView: View {
    let selected: InstrumentKind
    let choose: (InstrumentKind) -> Void
    @Environment(\.dismiss) private var dismiss
    private let groups = ["Connectivity", "Motion", "Environment", "Audio", "Device"]
    var body: some View {
        NavigationStack {
            List {
                ForEach(groups, id: \.self) { group in
                    Section(group) {
                        ForEach(InstrumentKind.allCases.filter { $0.group == group }) { kind in
                            Button { choose(kind) } label: {
                                HStack(alignment: .top, spacing: 16) {
                                    Image(systemName: kind.symbol).font(.title3).foregroundStyle(ProTheme.signal).frame(width: 28)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(kind.title).font(.system(.headline, design: .rounded)).foregroundStyle(.primary)
                                        Text(kind.summary).font(.callout).foregroundStyle(ProTheme.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    if selected == kind { Image(systemName: "checkmark").foregroundStyle(ProTheme.signal) }
                                }.padding(.vertical, 8)
                            }.accessibilityIdentifier("instrument.pick.\(kind.rawValue)")
                        }
                    }
                }
            }
            .navigationTitle("Choose an instrument")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct EndpointConfigurationView: View {
    @Binding var endpoint: String
    let saved: () -> Void
    @State private var draft = ""
    @Environment(\.dismiss) private var dismiss
    private var valid: Bool { EndpointPolicy.url(draft) != nil }
    var body: some View {
        NavigationStack {
            Form {
                Section("Endpoint") {
                    TextField("https://your-server.example/health", text: $draft).keyboardType(.URL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("endpoint.address")
                }
                Section {
                    Text("Use a server or local device you own or have permission to test. MagicCuts makes up to 20 HEAD requests, one at a time. It does not follow redirects.")
                    Text("Response times include connection and server work. Failed requests are counted separately from successful response times.")
                }.font(.callout).foregroundStyle(ProTheme.secondary)
            }
            .navigationTitle("Test a connection").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Measure") { endpoint = draft.trimmingCharacters(in: .whitespacesAndNewlines); saved() }.disabled(!valid)
                }
            }
            .onAppear { draft = endpoint }
        }
    }
}

nonisolated enum EndpointPolicy {
    static func url(_ value: String) -> URL? {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil, url.fragment == nil else { return nil }
        return url
    }
}

struct BaselineEditorView: View {
    let engine: InstrumentEngine
    @Bindable var library: ProLibrary
    let saved: (UUID) -> Void
    @State private var name = ""
    @State private var failure: String?
    @State private var saving = false
    @State private var captured: RecordedSession?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("For example, At desk", text: $name).accessibilityIdentifier("baseline.name")
                } header: { Text("Name this reference") }
                if let captured, let summary = captured.summary {
                    Section {
                        MeasurementValue(value: summary.median, kind: captured.kind, compact: true)
                        LabeledContent("Readings", value: "\(summary.count)")
                        LabeledContent("Source", value: captured.source.reportName)
                        Text("A snapshot of the latest continuous measurement segment. Future readings will not change this reference.")
                            .font(.callout).foregroundStyle(ProTheme.secondary)
                    }
                }
                if let failure { Section { InlineFailure(message: failure) } }
            }
            .navigationTitle("Set baseline").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || captured == nil || saving) }
            }
            .task {
                do {
                    var session = try engine.currentSnapshot(title: "Baseline")
                    session.points = MeasurementMath.rebased(Array(session.points.filter { $0.segment == session.points.last?.segment }.suffix(300)))
                    guard session.points.count >= 3 else { throw InstrumentError.unavailable("Measure at least three readings in the current segment before setting a baseline.") }
                    captured = session
                } catch { failure = error.localizedDescription }
            }
            .interactiveDismissDisabled(saving)
        }
    }
    private func save() async {
        guard let captured, let summary = captured.summary else { return }
        saving = true; defer { saving = false }
        let profile = CalibrationProfile(name: name.trimmingCharacters(in: .whitespacesAndNewlines), kind: captured.kind, sourceID: captured.source.id, sourceName: captured.source.reportName, date: captured.endedAt, points: captured.points, summary: summary, metadata: captured.metadata)
        do { try await library.save(profile); saved(profile.id); dismiss() }
        catch { failure = error.localizedDescription }
    }
}

struct SessionMarkView: View {
    let mark: (String) -> Void
    @State private var text = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("For example, Door closed", text: $text, axis: .vertical).lineLimit(2 ... 5)
                Text("The mark appears at this point in your recording.").font(.callout).foregroundStyle(ProTheme.secondary)
            }
            .navigationTitle("Mark an event").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add mark") { mark(text); dismiss() }.disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
        }.presentationDetents([.medium, .large])
    }
}

struct SaveSessionView: View {
    let engine: InstrumentEngine
    @Bindable var library: ProLibrary
    var baseline: CalibrationProfile?
    @State private var title = ""
    @State private var failure: String?
    @State private var saving = false
    @State private var discard = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Session name") { TextField("Name this measurement", text: $title).accessibilityIdentifier("session.name") }
                Section {
                    LabeledContent("Instrument", value: engine.kind.title)
                    LabeledContent("Readings", value: "\(engine.recordingCount)")
                    Text(engine.termination).font(.callout).foregroundStyle(ProTheme.secondary)
                }
                if let failure { Section { InlineFailure(message: failure) } }
                Section { Button("Discard recording", role: .destructive) { discard = true }.disabled(saving) }
            }
            .navigationTitle("Save session").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Keep editing") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving || engine.recordingCount == 0).accessibilityIdentifier("session.save") }
            }
            .onAppear { title = "\(engine.kind.title) · \(Date.now.formatted(date: .abbreviated, time: .shortened))" }
            .interactiveDismissDisabled(saving)
            .confirmationDialog("Discard this recording?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard recording", role: .destructive) {
                    Task {
                        do { try await engine.discardRecording(); dismiss() }
                        catch { failure = "The recovery copy couldn't be removed. \(error.localizedDescription)" }
                    }
                }
            } message: { Text("This recording has not been saved.") }
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        do {
            var session = try engine.finishRecording(title: title.trimmingCharacters(in: .whitespacesAndNewlines))
            session.reference = baseline
            try await library.save(session)
            do { try await engine.discardRecording() }
            catch { library.error = "Session saved. Its temporary recovery copy couldn't be removed: \(error.localizedDescription)" }
            dismiss()
        } catch { failure = "The recording is still here. \(error.localizedDescription)" }
    }
}

struct ProSettingsView: View {
    @Bindable var access: ProAccess
    @Bindable var library: ProLibrary
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showSessionLiveActivity") private var showLiveActivity = true
    var body: some View {
        NavigationStack {
            List {
                Section("MagicCuts Pro") {
                    Label(access.developmentAccess ? "Development access" : "Pro unlocked", systemImage: "checkmark.seal")
                    Button("Restore purchases") { Task { await access.restore() } }.disabled(access.isWorking)
                    if let message = access.message { Text(message).font(.callout) }
                }
                Section("Your baselines") {
                    if library.index.profiles.isEmpty { Text("Saved references appear here.").foregroundStyle(ProTheme.secondary) }
                    ForEach(library.index.profiles) { profile in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(profile.name).font(.system(.headline, design: .rounded))
                            Text("\(profile.kind.title) · \(profile.sourceName)").font(.callout).foregroundStyle(ProTheme.secondary)
                            Text(profile.date, format: .dateTime.month().day().year()).font(.caption).foregroundStyle(ProTheme.secondary)
                        }.padding(.vertical, 4)
                    }.onDelete { offsets in
                        let ids = offsets.map { library.index.profiles[$0].id }
                        Task {
                            do { for id in ids { _ = try await library.archive.deleteProfile(id) }; await library.reload() }
                            catch { library.error = error.localizedDescription }
                        }
                    }
                }
                Section("Measurements and privacy") {
                    Toggle("Show sessions on the Lock Screen", isOn: $showLiveActivity)
                    Text("Applies to your next recording. The Lock Screen shows the latest reading and whether measurement has paused.")
                    Text("Sessions and baselines stay on this device. Microphone measurements retain numerical levels, not audio recordings. Connection tests contact only the endpoint you enter.")
                    Text("Measurements pause when MagicCuts leaves the foreground. Missing readings remain gaps. A saved session includes its source, method and interruptions.")
                    Link("Privacy policy", destination: URL(string: "https://bradzellman.com/magiccuts-policies.html#privacy")!)
                    NavigationLink("Bluetooth and Shortcuts help") { HelpView() }
                }.font(.callout)
                if let error = library.error { Section { InlineFailure(message: error) } }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct BluetoothCalibrationView: View {
    let source: MeasurementSource
    let radio: any RadioScanning
    @Bindable var library: ProLibrary
    @Query private var devices: [MonitoredDevice]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var near: [SignalSample] = []
    @State private var away: [SignalSample] = []
    @State private var running: TestPosition?
    @State private var current: [SignalSample] = []
    @State private var readyAt: Date?
    @State private var task: Task<Void, Never>?
    @State private var failure: String?
    @State private var applied = false
    @State private var saving = false
    private var proposal: Int? { MeasurementMath.signalThreshold(nearby: near.map { Double($0.rssi) }, away: away.map { Double($0.rssi) }) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Teach your setup what nearby means.").font(.system(.title, design: .rounded).bold())
                    Text("Keep the phone and \(source.name) in the positions you actually use. Capture each location for ten seconds.").foregroundStyle(ProTheme.secondary)
                    captureRow(.nearby, title: "1 · Your nearby position", samples: near)
                    captureRow(.away, title: "2 · Your away position", samples: away)
                    if let running {
                        VStack(alignment: .leading, spacing: 8) {
                            TimelineView(.periodic(from: .now, by: 0.2)) { context in
                                ProgressView(value: readyAt.map { min(1, context.date.timeIntervalSince($0) / 10) } ?? 0)
                            }
                            Text("\(readyAt == nil ? "Preparing Bluetooth" : "Measuring \(running.title.lowercased())") · \(current.count) readings").font(.callout)
                            Button("Cancel capture") { cancel() }.frame(minHeight: 44)
                        }
                    }
                    if !near.isEmpty && !away.isEmpty {
                        if let proposal {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested threshold").font(.system(.headline, design: .rounded))
                                MeasurementValue(value: Double(proposal), kind: .bluetooth)
                                Text("The middle halves of your two measurements are separated. This threshold sits between them. Save it, then run nearby and away tests to check it with fresh readings.")
                                    .font(.callout).foregroundStyle(ProTheme.secondary)
                                Button(applied ? "Threshold saved" : "Use this threshold") { Task { await apply(proposal) } }
                                    .buttonStyle(ControlStyle()).disabled(applied || saving || running != nil)
                            }
                        } else {
                            Text("These measurements overlap or contain too few readings. Move to more distinct positions and capture both again. There isn't a reliable threshold to suggest yet.")
                                .font(.callout).foregroundStyle(ProTheme.secondary)
                        }
                    }
                    if applied { Label("Open the device's setup to validate Nearby and Away with fresh readings.", systemImage: "checkmark.circle").foregroundStyle(ProTheme.band) }
                    if let failure { InlineFailure(message: failure) }
                }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.background(MC.canvas)
            .navigationTitle("Calibrate Bluetooth").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(saving) } }
            .onDisappear { cancel() }
            .onChange(of: scenePhase) { _, phase in if phase == .background && running != nil { cancel(); failure = "Capture paused when the app left the foreground. Try this position again." } }
        }
    }
    private func captureRow(_ position: TestPosition, title: String, samples: [SignalSample]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(.headline, design: .rounded))
            if let summary = MeasurementMath.summary(samples.map { Double($0.rssi) }) {
                LinearInstrumentScale(range: -100 ... -40, value: summary.median, band: summary.q25 ... summary.q75)
                Text("\(samples.count) readings · median \(Int(summary.median.rounded())) dBm").font(.callout).foregroundStyle(ProTheme.secondary)
            }
            Button(samples.isEmpty ? "Capture \(position.title.lowercased())" : "Capture again") { capture(position) }
                .buttonStyle(ControlStyle(primary: false)).disabled(running != nil || saving)
        }
    }
    private func capture(_ position: TestPosition) {
        guard let id = source.deviceID else { return }
        failure = nil; current = []; readyAt = nil; applied = false; running = position
        task = Task {
            do {
                let samples = try await ProximitySampler(radio: radio).collect(id: id, services: source.serviceUUIDs, duration: AppRuntime.testDuration, onReady: { readyAt = $0 }, onSample: { current.append($0) })
                try Task.checkCancellation()
                if position == .nearby { near = samples } else { away = samples }
                if samples.count < 3 { failure = "At least three readings are needed in each position. Try again with the device actively advertising." }
            } catch is CancellationError { }
            catch { failure = error.localizedDescription }
            running = nil; task = nil
        }
    }
    private func cancel() { task?.cancel(); task = nil; running = nil }
    private func apply(_ threshold: Int) async {
        guard let device = devices.first(where: { $0.persistentIdentifier == source.id }), let id = device.uuid else { failure = BluetoothError.deletedDevice.localizedDescription; return }
        saving = true; defer { saving = false }
        do {
            for (label, samples) in [("Nearby", near), ("Away", away)] {
                guard let first = samples.first, let summary = MeasurementMath.summary(samples.map { Double($0.rssi) }) else { continue }
                let points = samples.map { MeasurementPoint(elapsed: $0.date.timeIntervalSince(first.date), date: $0.date, value: Double($0.rssi)) }
                try await library.save(CalibrationProfile(name: "\(device.name) · \(label)", kind: .bluetooth, sourceID: source.id, sourceName: source.name, date: .now, points: points, summary: summary, metadata: ["calibration": "Nearby/away capture; proposed threshold \(threshold) dBm"]))
            }
            try DeviceRepository(context: context).save(device, id: id, name: device.name, threshold: threshold, services: device.serviceUUIDs)
            applied = true
        } catch { failure = error.localizedDescription }
    }
}
