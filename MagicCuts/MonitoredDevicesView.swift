
import SwiftUI
import SwiftData

struct MonitoredDevicesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MonitoredDevice.name) private var monitoredDevices: [MonitoredDevice]
    @State private var selectedDevice: MonitoredDevice? = nil

    var body: some View {
        VStack {
            if monitoredDevices.isEmpty {
                Spacer()
                Image(systemName: "checklist.unchecked")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No Monitored Devices")
                    .font(.title)
                    .padding(.top)
                Text("Add devices from the Discover screen to see them here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
            } else {
                List {
                    ForEach(monitoredDevices) { device in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                    .font(.headline)
                                Text("Required RSSI: \(device.requiredSignalStrength)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { self.selectedDevice = device }) {
                                Image(systemName: "pencil.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    .onDelete(perform: deleteDevice)
                }
            }
        }
        .navigationTitle("Monitored Devices")
        .sheet(item: $selectedDevice) { device in
            EditDeviceView(device: device)
        }
    }

    private func deleteDevice(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(monitoredDevices[index])
            }

            // Re-sync remaining devices to SharedDeviceStorage
            syncAllDevicesToSharedStorage()
        }
    }

    private func syncAllDevicesToSharedStorage() {
        // Clear existing and re-sync all remaining devices
        SharedDeviceStorage.shared.clearAllDevices()
        for device in monitoredDevices {
            if let uuid = device.uuid {
                SharedDeviceStorage.shared.saveDevice(
                    id: uuid.uuidString,
                    name: device.name,
                    rssi: device.requiredSignalStrength,
                    serviceUUIDs: device.serviceUUIDs
                )
            }
        }
    }
}
