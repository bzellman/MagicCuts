import SwiftUI
import SwiftData

struct MonitoredDevicesView: View {
    let radio: any RadioScanning
    @Environment(\.modelContext) private var context
    @Query(sort: \MonitoredDevice.name) private var devices: [MonitoredDevice]
    @Query(sort: \TestRecord.date, order: .reverse) private var records: [TestRecord]
    @State private var error: String?
    @State private var pendingDelete: MonitoredDevice?
    var body: some View {
        List {
            if let error {
                Section {
                    InlineFailure(message: error)
                    Button("Retry sync", action: reconcile)
                }
            }
            if devices.isEmpty {
                Section {
                    ContentUnavailableView("Your devices, within reach", systemImage: "wave.3.right", description: Text("Save a Bluetooth device to check its signal in Shortcuts."))
                    NavigationLink { discovery } label: { HandoffRow(title: "Find a device", symbol: "plus") }.accessibilityIdentifier("saved-devices.find")
                }
            } else {
                Section {
                    ForEach(devices) { device in
                        NavigationLink { DeviceDetailView(device: device, radio: radio) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(device.name).font(.headline)
                                Text(progress(device)).font(.callout).foregroundStyle(.secondary)
                                Text("Threshold \(device.requiredSignalStrength) dBm").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }.padding(.vertical, 8)
                        }.accessibilityIdentifier("saved-device.\(device.persistentIdentifier)").swipeActions { Button("Delete", role: .destructive) { pendingDelete = device } }
                    }
                } header: { Text("Saved devices") }
                Section { NavigationLink { discovery } label: { HandoffRow(title: "Find a device", symbol: "plus") }.accessibilityIdentifier("saved-devices.find") }
            }
        }.scrollContentBackground(.hidden).background(MC.canvas).navigationTitle("Devices")
            .toolbar { NavigationLink { HelpView() } label: { Label("Help", systemImage: "questionmark.circle") } }
            .task { reconcile() }
            .confirmationDialog("Delete device and its test history?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("Delete device", role: .destructive) {
                    guard let device = pendingDelete else { return }
                    do { try DeviceRepository(context: context).delete(device) } catch { self.error = error.localizedDescription }
                    pendingDelete = nil
                }
            }
    }
    private var discovery: some View { DeviceDiscoveryView(bluetoothViewModel: BluetoothViewModel(radio: radio)) }
    private func reconcile() { do { try DeviceRepository(context: context).reconcile(); error = nil } catch { self.error = "Shortcuts sync failed. \(error.localizedDescription)" } }
    private func progress(_ device: MonitoredDevice) -> String {
        let evidence = records.filter { $0.deviceID == device.persistentIdentifier }.compactMap(\.evidence).filter { !$0.isDraft && $0.threshold == device.requiredSignalStrength && $0.startedAt >= device.validationResetAt }
        let nearby = evidence.first { $0.position == .nearby }?.validated == true
        let away = evidence.first { $0.position == .away }?.validated == true
        return nearby && away ? "Both positions tested" : nearby || away ? "One position left to test" : "Ready to calibrate"
    }
}
