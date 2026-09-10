import Foundation

struct DeviceInfo: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let requiredSignalStrength: Int
    let serviceUUIDs: [String]
    init(id: String, name: String, rssi: Int, serviceUUIDs: [String] = []) {
        self.id = id; self.name = name; requiredSignalStrength = rssi; self.serviceUUIDs = serviceUUIDs
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        requiredSignalStrength = try c.decode(Int.self, forKey: .requiredSignalStrength)
        serviceUUIDs = try c.decodeIfPresent([String].self, forKey: .serviceUUIDs) ?? []
    }
}

@MainActor
final class SharedDeviceStorage {
    static let shared: SharedDeviceStorage = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") || NSClassFromString("XCTestCase") != nil {
            return SharedDeviceStorage(defaults: UserDefaults(suiteName: "MagicCuts.UITests"))
        }
        #endif
        return SharedDeviceStorage()
    }()
    private let defaults: UserDefaults?
    init(defaults: UserDefaults? = UserDefaults(suiteName: "group.com.bradzellman.magiccuts")) { self.defaults = defaults }
    func replace(_ devices: [DeviceInfo]) throws {
        guard let defaults else { throw BluetoothError.storage }
        let data = try JSONEncoder().encode(devices)
        defaults.set(data, forKey: "monitored_devices")
        guard defaults.data(forKey: "monitored_devices") == data else { throw BluetoothError.storage }
    }
    func getAllDevices() throws -> [DeviceInfo] {
        guard let defaults else { throw BluetoothError.storage }
        guard let data = defaults.data(forKey: "monitored_devices") else { return [] }
        return try JSONDecoder().decode([DeviceInfo].self, from: data)
    }
    func getDevice(id: String) throws -> DeviceInfo? { try getAllDevices().first { $0.id == id } }
}
