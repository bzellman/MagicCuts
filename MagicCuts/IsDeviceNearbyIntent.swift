//
//  IsDeviceNearbyIntent.swift
//  MagicCuts
//
//  AppIntent for checking if a Bluetooth device is nearby via Shortcuts.
//

import SwiftUI
import AppIntents
import CoreBluetooth

struct IsDeviceNearbyIntent: AppIntent {
    static var title: LocalizedStringResource = "Check if Bluetooth Device is Nearby"
    static var description: IntentDescription = IntentDescription("Scans for a specific Bluetooth device and checks if its signal strength (RSSI) is within the required range.")

    static var openAppWhenRun: Bool = false
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    @Parameter(title: "Device to Check")
    var device: MonitoredDeviceEntity

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        print("🎯 [Intent] ========================================")
        print("🎯 [Intent] Starting IsDeviceNearbyIntent.perform()")
        print("🎯 [Intent] Device: \(device.name) (\(device.id))")
        print("🎯 [Intent] Required RSSI: \(device.requiredSignalStrength)")
        print("🎯 [Intent] Service UUID filters: \(device.serviceUUIDs)")
        print("🎯 [Intent] ========================================")

        let serviceFilters = device.serviceUUIDs.compactMap { CBUUID(string: $0) }
        if serviceFilters.isEmpty {
            print("📡 [BT] ⚠️ No service UUIDs stored for this device. Shortcut runs may require foreground access.")
        }

        do {
            let scanner = BluetoothScanner(
                targetUUID: device.id,
                requiredRSSI: device.requiredSignalStrength,
                serviceFilters: serviceFilters
            )
            let isNearby = try await scanner.scan()

            print("🎯 [Intent] ✅ Complete. Result: \(isNearby)")
            print("🎯 [Intent] ========================================")

            return .result(value: isNearby)

        } catch {
            print("🎯 [Intent] ❌ Error: \(error)")
            print("🎯 [Intent] ========================================")

            // Return false if Bluetooth unavailable
            return .result(value: false)
        }
    }
}

// MARK: - AppEntity for Shortcuts device selection

struct MonitoredDeviceEntity: AppEntity {
    var id: UUID
    var name: String
    var requiredSignalStrength: Int
    var serviceUUIDs: [String]

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Monitored Device"
    static var defaultQuery = MonitoredDeviceQuery()

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

// MARK: - EntityQuery for providing devices to Shortcuts

struct MonitoredDeviceQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [MonitoredDeviceEntity] {
        print("🔍 [Query] entities(for:) called with \(identifiers.count) identifiers")
        let allDevices = await loadAllDevices()
        print("🔍 [Query] Found \(allDevices.count) devices in storage")
        let filtered = allDevices.filter { identifiers.contains($0.id) }
        print("🔍 [Query] Returning \(filtered.count) matching devices")
        return filtered
    }

    func suggestedEntities() async throws -> [MonitoredDeviceEntity] {
        print("🔍 [Query] suggestedEntities() called")
        let devices = await loadAllDevices()
        print("🔍 [Query] Returning \(devices.count) suggested devices")
        for device in devices {
            print("🔍 [Query]   - \(device.name) (\(device.id))")
        }
        return devices
    }

    // MARK: - Private

    private func loadAllDevices() async -> [MonitoredDeviceEntity] {
        let deviceInfos = await SharedDeviceStorage.shared.getAllDevicesAsync()
        return deviceInfos.compactMap { info in
            guard let uuid = UUID(uuidString: info.id) else {
                print("🔍 [Query] ⚠️ Invalid UUID stored: \(info.id)")
                return nil
            }
            return MonitoredDeviceEntity(
                id: uuid,
                name: info.name,
                requiredSignalStrength: info.requiredSignalStrength,
                serviceUUIDs: info.serviceUUIDs
            )
        }
    }
}
