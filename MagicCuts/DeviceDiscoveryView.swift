
import SwiftUI
import SwiftData
import CoreBluetooth

struct DeviceDiscoveryView: View {
    @ObservedObject var bluetoothViewModel: BluetoothViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var monitoredDevices: [MonitoredDevice]
    
    // Enum to represent all sorting options
    enum SortMethod: String, CaseIterable, Identifiable {
        case alphabeticalAscending = "Alphabetical (A-Z)"
        case alphabeticalDescending = "Alphabetical (Z-A)"
        case signalStrengthDescending = "Signal (Strongest First)"
        case signalStrengthAscending = "Signal (Weakest First)"
        var id: String { self.rawValue }
    }
    
    @State private var sortMethod: SortMethod = .alphabeticalAscending
    
    // State for the data displayed in the list
    @State private var displayedPeripherals: [DiscoveredPeripheral] = []
    
    // State for loading indicator
    @State private var isTogglePending = false
    
    private var monitoredDeviceIDs: Set<UUID> {
        Set(monitoredDevices.compactMap { $0.uuid })
    }

    var body: some View {
        VStack {
            if !bluetoothViewModel.isScanning && displayedPeripherals.isEmpty {
                // State 1: Before scanning has started
                emptyStateView(imageName: "magnifyingglass", title: "Ready to Scan", description: "Tap 'Start Scanning' to find nearby Bluetooth devices.")
            } else if bluetoothViewModel.isScanning && displayedPeripherals.isEmpty {
                // State 2: Scanning, but no devices found yet
                scanningStateView
            } else {
                // State 3: Results are available
                List(displayedPeripherals) { peripheral in
                    listRow(for: peripheral)
                }
            }
        }
        .navigationTitle("Devices")
        .toolbar { toolbarContent }
        .onAppear { sortData() }
        .onChange(of: bluetoothViewModel.discoveredPeripherals) { sortData() }
        .onChange(of: sortMethod) { sortData() }
        .alert(item: $bluetoothViewModel.activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func sortData() {
        let peripherals = bluetoothViewModel.discoveredPeripherals
        switch sortMethod {
        case .alphabeticalAscending:
            displayedPeripherals = peripherals.sorted { $0.name < $1.name }
        case .alphabeticalDescending:
            displayedPeripherals = peripherals.sorted { $0.name > $1.name }
        case .signalStrengthDescending:
            displayedPeripherals = peripherals.sorted { $0.rssi > $1.rssi }
        case .signalStrengthAscending:
            displayedPeripherals = peripherals.sorted { $0.rssi < $1.rssi }
        }
    }
    
    // MARK: - Subviews

    @ViewBuilder
    private func emptyStateView(imageName: String, title: String, description: String) -> some View {
        Spacer()
        Image(systemName: imageName)
            .font(.system(size: 60))
            .foregroundColor(.secondary)
        Text(title)
            .font(.title)
            .padding(.top)
        Text(description)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        Spacer()
    }
    
    @ViewBuilder
    private var scanningStateView: some View {
        Spacer()
        ProgressView()
            .scaleEffect(1.5)
        Text("Scanning for Devices...")
            .font(.title2)
            .padding(.top)
        Spacer()
    }
    
    @ViewBuilder
    private func listRow(for peripheral: DiscoveredPeripheral) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(peripheral.name)
                    .font(.headline)
            }
            Spacer()
            Text("RSSI: \(peripheral.rssi)")
                .font(.subheadline)
            
            if monitoredDeviceIDs.contains(peripheral.id) {
                Button(action: { removeDevice(with: peripheral.id) }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(BorderlessButtonStyle())
            } else {
                Button(action: { addDevice(peripheral) }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // Sorting picker in the navigation bar
        ToolbarItem(placement: .navigationBarTrailing) {
            Picker("Sort by", selection: $sortMethod) {
                ForEach(SortMethod.allCases) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .fixedSize()
        }
        
        // Scan button in the bottom toolbar
        ToolbarItemGroup(placement: .bottomBar) {
            Spacer()
            if isTogglePending {
                ProgressView()
            } else {
                Button(bluetoothViewModel.isScanning ? "Stop Scanning" : "Start Scanning") {
                    Task {
                        isTogglePending = true
                        if bluetoothViewModel.isScanning {
                            bluetoothViewModel.stopScanning()
                        } else {
                            bluetoothViewModel.startScanning()
                        }
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        isTogglePending = false
                    }
                }
                .tint(bluetoothViewModel.isScanning ? .red : .accentColor)
                .disabled(isTogglePending)
            }
            Spacer()
        }
    }
    
    // MARK: - Data Functions
    
    private func addDevice(_ peripheral: DiscoveredPeripheral) {
        let serviceUUIDs = peripheral.serviceUUIDs.map { $0.uuidString }
        let newDevice = MonitoredDevice(
            persistentIdentifier: peripheral.id,
            name: peripheral.name,
            requiredSignalStrength: -70,
            serviceUUIDs: serviceUUIDs
        )
        modelContext.insert(newDevice)
        saveContext()

        // Sync to SharedDeviceStorage for extension access
        SharedDeviceStorage.shared.saveDevice(
            id: peripheral.id.uuidString,
            name: peripheral.name,
            rssi: -70,
            serviceUUIDs: serviceUUIDs
        )
    }

    private func removeDevice(with id: UUID) {
        if let deviceToRemove = monitoredDevices.first(where: { $0.uuid == id }) {
            modelContext.delete(deviceToRemove)
            saveContext()

            // Re-sync all devices to SharedDeviceStorage
            syncAllDevicesToSharedStorage()
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
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
