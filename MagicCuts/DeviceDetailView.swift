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
    @Query(sort: \TestRecord.date, order: .reverse) private var allRecords: [TestRecord]
    @AppStorage("technicalMode") private var technical = false
    @State private var edit = false
    @State private var rename = false
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
                Text("Proximity").font(.largeTitle.bold())
                ModeTabs()
                if !(-100 ... -1).contains(device.requiredSignalStrength) { InlineFailure(message: BluetoothError.invalidThreshold.localizedDescription) }
                if AppRuntime.isUITesting { Text("Demo readings").font(.caption).foregroundStyle(.secondary) }
                SignalGauge(threshold: device.requiredSignalStrength, samples: running != nil ? samples : (latest?.samples ?? []), showMeasurements: technical)
                Button("Edit threshold") { edit = true; TuneTip().invalidate(reason: .actionPerformed) }
                    .buttonStyle(ControlStyle(primary: false)).disabled(running != nil).accessibilityIdentifier("threshold.edit")
                if let error { InlineFailure(message: error) }
                if let latest {
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
                testControls
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
                Divider()
                NavigationLink { TestHistoryView(device: device) } label: { HandoffRow(title: "Test history (\(records.count))", symbol: "chevron.right") }
                if technical {
                    Text("Device identifier").font(.headline)
                    Text(device.persistentIdentifier).font(.caption.monospaced()).textSelection(.enabled)
                    Text("Advertised services").font(.headline)
                    Text(device.serviceUUIDs.isEmpty ? "None saved" : device.serviceUUIDs.joined(separator: ", ")).font(.caption.monospaced()).textSelection(.enabled)
                }
            }.padding(MC.inset).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.background(MC.canvas).navigationTitle(device.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Rename", systemImage: "pencil") { rename = true }.disabled(running != nil) }
            .sheet(isPresented: $edit) { EditDeviceView(device: device, radio: radio) }
            .sheet(isPresented: $rename) { RenameDeviceView(device: device) }
            .onDisappear { cancel() }
            .onChange(of: phase) { _, value in if value != .active && running != nil { cancel(); error = "Test interrupted. Keep MagicCuts open and try again." } }
    }
    private var testControls: some View {
        let layout = dynamicType.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 1)) : AnyLayout(HStackLayout(spacing: 1))
        return layout {
            if let running {
                HStack { ProgressView().tint(.white); Text("Testing \(running.title.lowercased())…") }.font(.headline).foregroundStyle(.white).padding().frame(maxWidth: .infinity).background(MC.action)
                Button("Stop") { cancel() }.buttonStyle(ControlStyle(primary: false)).accessibilityIdentifier("test.stop")
            } else {
                Button { run(.nearby) } label: { Label("Test nearby", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right") }.buttonStyle(ControlStyle(radius: 0)).accessibilityIdentifier("test.nearby")
                Button { run(.away) } label: { Text("Test away") }.buttonStyle(ControlStyle(primary: false, radius: 0)).accessibilityIdentifier("test.away")
            }
        }.clipShape(RoundedRectangle(cornerRadius: 12))
    }
    private func cancel() { task?.cancel(); task = nil; running = nil }
    private func run(_ position: TestPosition) {
        guard let id = device.uuid else { error = "Device identifier is invalid."; return }
        guard (-100 ... -1).contains(device.requiredSignalStrength) else { error = BluetoothError.invalidThreshold.localizedDescription; return }
        running = position; samples = []; error = nil
        let threshold = device.requiredSignalStrength
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
            let evidence = TestEvidence(startedAt: start, endedAt: Date(), threshold: threshold, position: position, isDraft: false, samples: samples, failure: failure)
            do { try DeviceRepository(context: context).record(evidence, identity: identity) } catch { self.error = "Could not save test: \(error.localizedDescription)" }
            running = nil
            if position == .away { ValidateTip().invalidate(reason: .actionPerformed) }
        }
    }
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
