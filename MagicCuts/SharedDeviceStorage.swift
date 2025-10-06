//
//  SharedDeviceStorage.swift
//  MagicCuts
//
//  Shared between app and extension
//

import Foundation

struct DeviceInfo: Codable {
    let id: String
    let name: String
    let requiredSignalStrength: Int
    let serviceUUIDs: [String]
    
    init(id: String, name: String, requiredSignalStrength: Int, serviceUUIDs: [String] = []) {
        self.id = id
        self.name = name
        self.requiredSignalStrength = requiredSignalStrength
        self.serviceUUIDs = serviceUUIDs
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        requiredSignalStrength = try container.decode(Int.self, forKey: .requiredSignalStrength)
        serviceUUIDs = try container.decodeIfPresent([String].self, forKey: .serviceUUIDs) ?? []
    }
}

class SharedDeviceStorage {
    static let shared = SharedDeviceStorage()
    private let defaults: UserDefaults?
    private let devicesKey = "monitored_devices"

    init() {
        defaults = UserDefaults(suiteName: "group.com.bradzellman.magiccuts")
        print("💾 [SharedStorage] UserDefaults suite initialized: \(defaults != nil)")
    }

    func saveDevice(id: String, name: String, rssi: Int, serviceUUIDs: [String]? = nil) {
        guard let defaults = defaults else {
            print("💾 [SharedStorage] ❌ Failed to get UserDefaults suite")
            return
        }

        var devices = getAllDevices()

        let resolvedServices: [String]
        if let index = devices.firstIndex(where: { $0.id == id }) {
            let existing = devices[index]
            resolvedServices = serviceUUIDs ?? existing.serviceUUIDs
            devices[index] = DeviceInfo(id: id, name: name, requiredSignalStrength: rssi, serviceUUIDs: resolvedServices)
        } else {
            resolvedServices = serviceUUIDs ?? []
            devices.append(DeviceInfo(id: id, name: name, requiredSignalStrength: rssi, serviceUUIDs: resolvedServices))
        }

        if let encoded = try? JSONEncoder().encode(devices) {
            defaults.set(encoded, forKey: devicesKey)
            defaults.synchronize()
            print("💾 [SharedStorage] ✅ Saved \(devices.count) devices")
        }
    }

    func getAllDevices() -> [DeviceInfo] {
        guard let defaults = defaults else {
            print("💾 [SharedStorage] ❌ Failed to get UserDefaults suite")
            return []
        }

        guard let data = defaults.data(forKey: devicesKey),
              let devices = try? JSONDecoder().decode([DeviceInfo].self, from: data) else {
            print("💾 [SharedStorage] No devices found")
            return []
        }

        print("💾 [SharedStorage] Retrieved \(devices.count) devices")
        return devices
    }

    func getDevice(id: String) -> DeviceInfo? {
        return getAllDevices().first { $0.id == id }
    }
}
