
import SwiftUI
import SwiftData

struct EditDeviceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var device: MonitoredDevice

    @State private var signalStrength: Double
    @StateObject private var tester: BluetoothTestViewModel
    @State private var saveError: BluetoothAlert?

    private var isNameValid: Bool {
        !device.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init(device: MonitoredDevice) {
        self.device = device
        _signalStrength = State(initialValue: Double(device.requiredSignalStrength))
        _tester = StateObject(wrappedValue: BluetoothTestViewModel())
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device Details")) {
                    TextField("Device Name", text: $device.name)
                    if !isNameValid {
                        Text("Device name is required")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Signal Strength (RSSI)")) {
                    VStack {
                        HStack {
                            Text("Far")
                                .foregroundColor(.secondary)
                            Slider(value: $signalStrength, in: -100...0, step: 1)
                            Text("Close")
                                .foregroundColor(.secondary)
                        }
                        Text("Required: \(Int(signalStrength))")
                            .font(.headline)
                    }
                    .padding(.vertical)
                }

                Section(header: Text("Test Proximity")) {
                    if tester.isTesting {
                        HStack {
                            ProgressView()
                            Text("Testing device...")
                                .font(.subheadline)
                        }
                    } else if let result = tester.lastResult {
                        Label(result ? "Passes current threshold" : "Did not meet threshold",
                              systemImage: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result ? .green : .red)
                        if let strongest = tester.strongestRSSI {
                            Text("Strongest RSSI detected: \(strongest)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Run a test to see if the device currently meets the RSSI requirement.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }

                    Button(tester.isTesting ? "Testing..." : "Run Test") {
                        guard let uuid = device.uuid else {
                            tester.activeAlert = BluetoothAlert(
                                title: "Device Not Saved",
                                message: "Save the device before running a proximity test."
                            )
                            return
                        }
                        tester.testDevice(
                            id: uuid,
                            requiredRSSI: device.requiredSignalStrength,
                            serviceUUIDs: device.serviceUUIDs
                        )
                    }
                    .disabled(tester.isTesting)
                }
            }
            .navigationTitle("Edit Device")
            .navigationBarItems(leading: Button("Cancel") { dismiss() },
                                trailing: Button("Save") { saveAndDismiss() }
                                    .disabled(!isNameValid))
            .alert(item: $tester.activeAlert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(item: $saveError) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onDisappear { tester.cancelTest() }
    }
    
    private func saveAndDismiss() {
        device.requiredSignalStrength = Int(signalStrength)
        do {
            try modelContext.save()

            // Sync to SharedDeviceStorage for extension access
            if let uuid = device.uuid {
                SharedDeviceStorage.shared.saveDevice(
                    id: uuid.uuidString,
                    name: device.name,
                    rssi: device.requiredSignalStrength,
                    serviceUUIDs: device.serviceUUIDs
                )
            }
            dismiss()
        } catch {
            print("Failed to save device: \(error.localizedDescription)")
            saveError = BluetoothAlert(
                title: "Save Failed",
                message: "Could not save changes: \(error.localizedDescription)"
            )
        }
    }
}
