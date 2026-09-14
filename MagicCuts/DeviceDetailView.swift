import SwiftUI
import SwiftData
import TipKit

@MainActor
struct DeviceDetailView: View {
    let device: MonitoredDevice
    let radio: any RadioScanning
    private let modelID: PersistentIdentifier
    @Query private var savedDevices: [MonitoredDevice]
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \TestRecord.date, order: .reverse) private var allRecords: [TestRecord]
    @AppStorage("technicalMode") private var technical = false
    @State private var editor: Editor = .none
    @State private var draftThreshold = -70
    @State private var draftName = ""
    @State private var draftResult: TestEvidence?
    @State private var running: TestPosition?
    @State private var task: Task<Void, Never>?
    @State private var samples: [SignalSample] = []
    @State private var error: String?
    private var records: [TestRecord] { allRecords.filter { $0.deviceID == device.persistentIdentifier } }
    private var current: [TestEvidence] { records.compactMap(\.evidence).filter { !$0.isDraft && $0.threshold == device.requiredSignalStrength && $0.startedAt >= device.validationResetAt } }
    private var latestNearby: TestEvidence? { current.first { $0.position == .nearby } }
    private var latestAway: TestEvidence? { current.first { $0.position == .away } }
    private var validated: Bool { latestNearby?.validated == true && latestAway?.validated == true }
    private var latest: TestEvidence? { records.first?.evidence }
    private var editingThreshold: Bool { editor == .threshold }
    private var gaugeThreshold: Int { editingThreshold ? draftThreshold : device.requiredSignalStrength }
    private var gaugeSamples: [SignalSample] {
        if running != nil { return samples }
        if editingThreshold { return draftResult?.samples ?? [] }
        return latest?.samples ?? []
    }
    init(device: MonitoredDevice, radio: any RadioScanning) {
        self.device = device
        self.radio = radio
        modelID = device.persistentModelID
    }
    var body: some View {
        if savedDevices.contains(where: { $0.persistentModelID == modelID }) {
            detailContent
        } else {
            ContentUnavailableView("Device deleted", systemImage: "trash", description: Text("This device was removed. Return to Devices to choose another."))
                .navigationTitle("Device deleted")
                .onAppear { cancel() }
        }
    }
    private var detailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if editor == .name {
                    TextField("Device name", text: $draftName).textFieldStyle(.roundedBorder).disabled(running != nil).accessibilityIdentifier("device.name")
                    Text("Choose a name you’ll recognize in Shortcuts.").font(.callout).foregroundStyle(.secondary)
                }
                if !(-100 ... -1).contains(device.requiredSignalStrength) { InlineFailure(message: BluetoothError.invalidThreshold.localizedDescription) }
                if AppRuntime.isUITesting { Text("Demo readings").font(.caption).foregroundStyle(.secondary) }
                SignalGauge(threshold: gaugeThreshold, samples: gaugeSamples, onChange: editingThreshold && running == nil ? { draftThreshold = $0; draftResult = nil; samples = [] } : nil, showMeasurements: technical || editingThreshold)
                    .disabled(editingThreshold && running != nil)
                if editingThreshold {
                    Text("Nearby when RSSI ≥ \(draftThreshold) dBm").font(.callout).monospacedDigit()
                } else {
                    Button("Edit threshold") { beginThresholdEdit() }
                        .buttonStyle(ControlStyle(primary: false)).disabled(running != nil || editor == .name).accessibilityIdentifier("threshold.edit")
                }
                if let error { InlineFailure(message: error) }
                if editingThreshold, let draftResult {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draftResult.summary).font(.headline)
                        Text("Draft test · not saved validation").font(.caption)
                    }
                } else if !editingThreshold, let latest {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(latest.summary).font(.headline)
                        if latest.isDraft { Text("Draft test · not saved validation").font(.caption) }
                        if latest.threshold != device.requiredSignalStrength || latest.startedAt < device.validationResetAt {
                            Label("Setup changed. Test again.", systemImage: "arrow.clockwise").font(.callout)
                        }
                        if technical {
                            Text("\(latest.samples.count) samples · \(latest.endedAt.timeIntervalSince(latest.startedAt), specifier: "%.1f") s · tested at \(latest.threshold) dBm").font(.caption).monospacedDigit()
                            Text(latest.endedAt, style: .date).font(.caption)
                            Text(latest.endedAt, style: .time).font(.caption)
                        }
                    }
                }
                Text("Walls and movement change signal. Test nearby and away.").font(.callout).foregroundStyle(.secondary)
                if editingThreshold {
                    Button(running == .draft ? "Stop test" : "Test draft") {
                        if running == .draft { cancel() } else { run(.draft) }
                    }.buttonStyle(ControlStyle(primary: false)).accessibilityIdentifier("draft.test")
                    Button("Apply threshold") { applyThreshold() }
                        .buttonStyle(ControlStyle()).disabled(running != nil).accessibilityIdentifier("threshold.apply")
                    Text("Signal is not an exact distance.").font(.caption).foregroundStyle(.secondary)
                }
                if records.isEmpty { TipView(TuneTip()) }
                else if !validated { TipView(ValidateTip()) }
                else { TipView(ShortcutTip()) }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Setup").font(.headline)
                    Label("Device saved", systemImage: "checkmark.circle")
                    Label(latestNearby?.validated == true ? "Nearby tested" : "Test nearby", systemImage: latestNearby?.validated == true ? "checkmark.circle" : "circle")
                    Label(latestAway?.validated == true ? "Away tested" : "Test away", systemImage: latestAway?.validated == true ? "checkmark.circle" : "circle")
                    ShortcutConfirmation(device: device)
                }.font(.callout)
                NavigationLink { ShortcutsSetupView(device: device) } label: { HandoffRow(title: "Configure Shortcut") }
                    .disabled(editor != .none || running != nil)
                Divider()
                NavigationLink { TestHistoryView(device: device) } label: { HandoffRow(title: "Test history (\(records.count))", symbol: "chevron.right") }
                    .disabled(editor != .none || running != nil)
                if technical {
                    Text("Device identifier").font(.headline)
                    Text(device.persistentIdentifier).font(.caption.monospaced()).textSelection(.enabled)
                    Text("Advertised services").font(.headline)
                    Text(device.serviceUUIDs.isEmpty ? "None saved" : device.serviceUUIDs.joined(separator: ", ")).font(.caption.monospaced()).textSelection(.enabled)
                }
            }.padding(MC.inset).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.background(MC.canvas).navigationTitle(device.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { technical = false } label: {
                            if !technical { Label("Simple", systemImage: "checkmark") } else { Text("Simple") }
                        }.accessibilityIdentifier("mode.simple")
                        Button { technical = true } label: {
                            if technical { Label("Technical", systemImage: "checkmark") } else { Text("Technical") }
                        }.accessibilityIdentifier("mode.technical")
                    } label: {
                        Text(technical ? "Technical" : "Simple")
                    }
                    .accessibilityIdentifier("mode.detail")
                    .accessibilityLabel("Reading detail")
                    .accessibilityValue(technical ? "Technical" : "Simple")
                    .disabled(editor != .none)
                }
            }
            .toolbar { toolbar }
            .safeAreaInset(edge: .top, spacing: 0) {
                if editor == .none {
                    testControls.padding(.horizontal, MC.inset).padding(.vertical, 8).background(MC.canvas)
                }
            }
            .onDisappear { cancel() }
            .onChange(of: phase) { _, value in if value == .background && running != nil { cancel(); error = "Test interrupted. Keep MagicCuts open and try again." } }
    }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        if editor == .threshold {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { abandonEditor() }.foregroundStyle(.primary).accessibilityIdentifier("threshold.cancel")
            }
        } else if editor == .name {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { abandonEditor() }.foregroundStyle(.primary)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveName() }.disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || running != nil)
            }
        } else {
            ToolbarItem(placement: .primaryAction) {
                Button("Rename", systemImage: "pencil") { beginRename() }.disabled(running != nil)
            }
        }
    }
    private var testControls: some View {
        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 1)) : AnyLayout(HStackLayout(spacing: 1))
        return layout {
            if let running, running != .draft {
                HStack { ProgressView().tint(MC.onAction); Text("Testing \(running.title.lowercased())…") }.font(.headline).foregroundStyle(MC.onAction).padding().frame(maxWidth: .infinity).background(MC.action)
                Button("Stop") { cancel() }.buttonStyle(ControlStyle(primary: false)).accessibilityIdentifier("test.stop")
            } else {
                Button { run(.nearby) } label: { Label("Test nearby", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }.buttonStyle(ControlStyle(radius: 0)).accessibilityIdentifier("test.nearby")
                Button { run(.away) } label: { Text("Test away") }.buttonStyle(ControlStyle(primary: false, radius: 0)).accessibilityIdentifier("test.away")
            }
        }.clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func beginThresholdEdit() {
        cancel()
        draftThreshold = min(-1, max(-100, device.requiredSignalStrength))
        draftResult = nil
        samples = []
        error = nil
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { editor = .threshold }
        TuneTip().invalidate(reason: .actionPerformed)
    }
    private func beginRename() {
        cancel()
        draftName = device.name
        error = nil
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { editor = .name }
    }
    private func abandonEditor() {
        cancel()
        draftResult = nil
        samples = []
        error = nil
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { editor = .none }
    }
    private func cancel() { task?.cancel(); task = nil; running = nil }
    private func applyThreshold() {
        do {
            let repository = DeviceRepository(context: context)
            let device = try repository.existingDevice(modelID)
            guard let id = device.uuid else { throw BluetoothError.deletedDevice }
            try repository.save(device, id: id, name: device.name, threshold: draftThreshold, services: device.serviceUUIDs)
            abandonEditor()
        } catch { self.error = error.localizedDescription }
    }
    private func saveName() {
        do {
            let repository = DeviceRepository(context: context)
            let device = try repository.existingDevice(modelID)
            guard let id = device.uuid else { throw BluetoothError.deletedDevice }
            try repository.save(device, id: id, name: draftName, threshold: device.requiredSignalStrength, services: device.serviceUUIDs)
            abandonEditor()
        } catch { self.error = error.localizedDescription }
    }
    private func run(_ position: TestPosition) {
        guard let id = device.uuid else { error = "Device identifier is invalid."; return }
        let threshold = position == .draft ? draftThreshold : device.requiredSignalStrength
        if position != .draft {
            guard (-100 ... -1).contains(threshold) else { error = BluetoothError.invalidThreshold.localizedDescription; return }
        }
        running = position; samples = []; error = nil
        if position == .draft { draftResult = nil }
        let identity = TestDeviceIdentity(device)
        let services = device.serviceUUIDs
        var start = Date()
        task = Task { @MainActor in
            var failure: String?
            do {
                let duration: Duration = AppRuntime.testDuration
                _ = try await ProximitySampler(radio: radio).collect(id: id, services: services, duration: duration, onReady: { start = $0 }, onSample: { samples.append($0) })
            } catch is CancellationError {
                if !Task.isCancelled { running = nil; self.error = "Test interrupted by another Bluetooth operation. Try again." }
                return
            } catch { failure = error.localizedDescription }
            guard !Task.isCancelled else { return }
            let evidence = TestEvidence(startedAt: start, endedAt: Date(), threshold: threshold, position: position, isDraft: position == .draft, samples: samples, failure: failure)
            if position == .draft { draftResult = evidence }
            do { try DeviceRepository(context: context).record(evidence, identity: identity) } catch { self.error = "Could not save test: \(error.localizedDescription)" }
            running = nil
            if position == .away { ValidateTip().invalidate(reason: .actionPerformed) }
        }
    }
}

private enum Editor {
    case none, threshold, name
}

struct ShortcutConfirmation: View {
    let device: MonitoredDevice
    @AppStorage private var threshold: String
    init(device: MonitoredDevice) { self.device = device; _threshold = AppStorage(wrappedValue: "", "shortcutVerified.\(device.persistentIdentifier)") }
    var body: some View { Label(threshold == device.confirmationKey ? "Shortcut verified by you" : "Verify in Shortcuts", systemImage: threshold == device.confirmationKey ? "checkmark.circle" : "circle") }
}

struct TestHistoryView: View {
    let deviceID: String
    init(device: MonitoredDevice) { deviceID = device.persistentIdentifier }
    @Environment(\.modelContext) private var context
    @Query(sort: \TestRecord.date, order: .reverse) private var all: [TestRecord]
    @State private var clear = false
    @State private var error: String?
    private var records: [TestRecord] { all.filter { $0.deviceID == deviceID } }
    var body: some View {
        List {
            if let error { InlineFailure(message: error) }
            if records.isEmpty { ContentUnavailableView("No tests yet", systemImage: "waveform.path", description: Text("Run a nearby or away test to record observations.")) }
            ForEach(records) { record in
                if let evidence = record.evidence {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(evidence.position.title) · \(evidence.summary)").font(.headline)
                        Text(record.date, format: .dateTime).font(.caption)
                        Text("Threshold \(evidence.threshold) dBm · \(evidence.samples.count) readings · \(evidence.range)").font(.callout).monospacedDigit()
                        if evidence.isDraft { Text("Draft settings").font(.caption) }
                        DisclosureGroup("Readings") { ForEach(Array(evidence.samples.enumerated()), id: \.offset) { _, sample in HStack { Text(sample.date, style: .time); Spacer(); Text("\(sample.rssi) dBm").monospacedDigit() }.font(.caption) } }
                    }.padding(.vertical, 6)
                } else { Text("This test record could not be read.") }
            }.onDelete { offsets in delete(offsets.map { records[$0] }) }
        }.navigationTitle("Test history")
            .toolbar { Button("Clear", role: .destructive) { clear = true }.disabled(records.isEmpty) }
            .confirmationDialog("Delete this device’s test history?", isPresented: $clear, titleVisibility: .visible) { Button("Clear history", role: .destructive) { delete(records) } }
    }
    private func delete(_ items: [TestRecord]) { items.forEach { context.delete($0) }; do { try context.save() } catch { context.rollback(); self.error = error.localizedDescription } }
}
