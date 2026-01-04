//
//  BluetoothViewModel.swift
//  MagicCuts
//
//  Bluetooth device discovery with batched UI updates.
//

import Foundation
import CoreBluetooth
import Combine

/// A discovered Bluetooth peripheral with its RSSI and service UUIDs.
struct DiscoveredPeripheral: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let rssi: Int
    let serviceUUIDs: [CBUUID]

    var name: String {
        peripheral.name ?? "Unknown Device"
    }

    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        lhs.id == rhs.id && lhs.rssi == rhs.rssi && lhs.serviceUUIDs == rhs.serviceUUIDs
    }
}

/// Alert model for Bluetooth-related errors.
struct BluetoothAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

/// ViewModel for Bluetooth device discovery with batched UI updates.
@MainActor
class BluetoothViewModel: NSObject, ObservableObject {
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published var isScanning = false
    @Published var authorizationStatus: CBManagerAuthorization = CBManager.authorization
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var activeAlert: BluetoothAlert?

    private var centralManager: CBCentralManager!
    private var discoveredPeripheralsDict: [UUID: DiscoveredPeripheral] = [:]
    private var pendingUpdates: [UUID: DiscoveredPeripheral] = [:]
    private var updateTask: Task<Void, Never>?

    /// Debounce interval for batching UI updates (750ms)
    private let debounceInterval: UInt64 = 750_000_000 // nanoseconds

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func startScanning() {
        guard authorizationAllowsScanning else {
            presentAlert(
                title: "Bluetooth Access Needed",
                message: "Grant Bluetooth permissions in Settings to scan for devices."
            )
            return
        }
        guard centralManager.state == .poweredOn else {
            presentAlert(
                title: "Turn On Bluetooth",
                message: "Enable Bluetooth to discover nearby devices."
            )
            return
        }

        isScanning = true
        discoveredPeripheralsDict.removeAll()
        pendingUpdates.removeAll()
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        print("📡 [BT] Started scanning")
    }

    func stopScanning() {
        centralManager.stopScan()
        updateTask?.cancel()
        updateTask = nil
        isScanning = false
        print("📡 [BT] Stopped scanning")
    }

    // MARK: - Private

    private var authorizationAllowsScanning: Bool {
        switch CBManager.authorization {
        case .restricted, .denied:
            return false
        default:
            return true
        }
    }

    private func presentAlert(title: String, message: String) {
        activeAlert = BluetoothAlert(title: title, message: message)
    }

    private func schedulePublishUpdates() {
        // If no task is running, start one
        guard updateTask == nil else { return }

        updateTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: self?.debounceInterval ?? 750_000_000)

            guard !Task.isCancelled else { return }

            self?.publishUpdates()
        }
    }

    private func publishUpdates() {
        // Merge pending updates into main dictionary
        discoveredPeripheralsDict.merge(pendingUpdates) { _, new in new }
        pendingUpdates.removeAll()

        // Update published array
        discoveredPeripherals = Array(discoveredPeripheralsDict.values)

        updateTask = nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothViewModel: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            bluetoothState = central.state
            authorizationStatus = CBManager.authorization

            switch central.state {
            case .poweredOn:
                print("📡 [BT] Bluetooth is On")
            case .poweredOff:
                print("📡 [BT] Bluetooth is Off")
                isScanning = false
                presentAlert(
                    title: "Bluetooth Off",
                    message: "Turn Bluetooth on to continue scanning for devices."
                )
            case .unsupported:
                print("📡 [BT] Bluetooth is not supported")
                presentAlert(
                    title: "Unsupported",
                    message: "This device does not support Bluetooth LE scanning."
                )
            case .unauthorized:
                print("📡 [BT] Bluetooth is not authorized")
                presentAlert(
                    title: "Permission Needed",
                    message: "Grant Bluetooth access in Settings to discover devices."
                )
            case .resetting:
                print("📡 [BT] Bluetooth is resetting")
            case .unknown:
                print("📡 [BT] Bluetooth state is unknown")
            @unknown default:
                print("📡 [BT] Unknown Bluetooth state")
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssiInt = RSSI.intValue

        // Filter out invalid devices
        guard let name = peripheral.name,
              !name.isEmpty,
              rssiInt != 127,
              rssiInt < 0 else {
            return
        }

        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []

        let discovered = DiscoveredPeripheral(
            id: peripheral.identifier,
            peripheral: peripheral,
            rssi: rssiInt,
            serviceUUIDs: serviceUUIDs
        )

        Task { @MainActor in
            pendingUpdates[peripheral.identifier] = discovered
            schedulePublishUpdates()
        }
    }
}
