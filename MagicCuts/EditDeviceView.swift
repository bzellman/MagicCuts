import SwiftUI
import SwiftData

struct EditDeviceView: View {
    private let identity: TestDeviceIdentity
    let radio: any RadioScanning
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var threshold: Int
    @State private var task: Task<Void, Never>?
    @State private var testing = false
    @State private var samples: [SignalSample] = []
    @State private var result: TestEvidence?
    @State private var error: String?
    init(device: MonitoredDevice, radio: any RadioScanning) { self.identity = TestDeviceIdentity(device); self.radio = radio; _threshold = State(initialValue: min(-1, max(-100, device.requiredSignalStrength))) }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SignalGauge(threshold: threshold, samples: samples, onChange: { value in threshold = value; result = nil; samples = [] }).disabled(testing)
                    Text("Nearby when RSSI ≥ \(threshold) dBm").font(.callout).monospacedDigit()
                    if let result { Text(result.summary).font(.headline) }
                    if let error { InlineFailure(message: error) }
                    Text("Walls and movement change signal. Test nearby and away.").foregroundStyle(.secondary)
                    Button(testing ? "Stop test" : "Test draft") { if testing { cancel() } else { test() } }.buttonStyle(ControlStyle(primary: false)).accessibilityIdentifier("draft.test")
                    Button("Apply threshold") { save() }.buttonStyle(ControlStyle()).disabled(testing).accessibilityIdentifier("threshold.apply")
                    Text("Signal is not an exact distance.").font(.caption).foregroundStyle(.secondary)
                }.padding(MC.inset).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(MC.canvas).navigationTitle("Nearby threshold").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel(); dismiss() }.foregroundStyle(.primary) }.sharedBackgroundVisibility(.hidden) }
        }.presentationDetents([.large]).presentationDragIndicator(.visible)
            .onDisappear { cancel() }
            .onChange(of: phase) { _, value in if value != .active && testing { cancel(); error = "Test interrupted. Try again with MagicCuts open." } }
    }
    private func cancel() { task?.cancel(); task = nil; testing = false }
    private func save() {
        do {
            let repository = DeviceRepository(context: context)
            let device = try repository.existingDevice(self.identity.persistentID)
            guard let id = device.uuid else { throw BluetoothError.deletedDevice }
            try repository.save(device, id: id, name: device.name, threshold: threshold, services: device.serviceUUIDs)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
    private func test() {
        let device: MonitoredDevice
        do { device = try DeviceRepository(context: context).existingDevice(self.identity.persistentID) }
        catch { self.error = error.localizedDescription; return }
        guard let id = device.uuid else { error = BluetoothError.deletedDevice.localizedDescription; return }
        testing = true; samples = []; error = nil; result = nil
        let identity = TestDeviceIdentity(device)
        let services = device.serviceUUIDs
        var start = Date()
        let tested = threshold
        task = Task { @MainActor in
            var failure: String?
            do {
                let duration: Duration = AppRuntime.testDuration
                _ = try await ProximitySampler(radio: radio).collect(id: id, services: services, duration: duration, onReady: { start = $0 }, onSample: { samples.append($0) })
            } catch is CancellationError {
                if !Task.isCancelled { testing = false; self.error = "Test interrupted by another Bluetooth operation. Try again." }
                return
            } catch { failure = error.localizedDescription }
            guard !Task.isCancelled else { return }
            let evidence = TestEvidence(startedAt: start, endedAt: Date(), threshold: tested, position: .draft, isDraft: true, samples: samples, failure: failure)
            result = evidence
            do { try DeviceRepository(context: context).record(evidence, identity: identity) } catch { self.error = error.localizedDescription }
            testing = false
        }
    }
}

struct RenameDeviceView: View {
    private let identity: TestDeviceIdentity
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var error: String?
    init(device: MonitoredDevice) { self.identity = TestDeviceIdentity(device); _name = State(initialValue: device.name) }
    var body: some View {
        NavigationStack {
            Form {
                TextField("Device name", text: $name).accessibilityIdentifier("device.name")
                if let error { InlineFailure(message: error) }
            }.navigationTitle("Rename device")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(.primary) }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }
    }
    private func save() {
        do {
            let repository = DeviceRepository(context: context)
            let device = try repository.existingDevice(self.identity.persistentID)
            guard let id = device.uuid else { throw BluetoothError.deletedDevice }
            try repository.save(device, id: id, name: name, threshold: device.requiredSignalStrength, services: device.serviceUUIDs)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
