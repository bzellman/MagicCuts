
import SwiftUI
import AppIntents
import CoreBluetooth
import SwiftData

struct IsDeviceNearbyIntent: AppIntent {
    static var title: LocalizedStringResource = "Check if Bluetooth Device is Nearby"
    static var description: IntentDescription = IntentDescription("Scans for a specific Bluetooth device and checks if its signal strength (RSSI) is within the required range.")

    static var openAppWhenRun: Bool = false  // Required for Bluetooth discovery to work
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

        // Inline Bluetooth scanner
        final class Scanner: NSObject, CBCentralManagerDelegate {
            private var centralManager: CBCentralManager?
            private var continuation: CheckedContinuation<Bool, Error>?
            private var strongestRSSI: Int = -127
            private let targetUUID: UUID
            private let requiredRSSI: Int
            private let serviceFilters: [CBUUID]
            private let queue = DispatchQueue(label: "com.bradzellman.MagicCuts.bt", qos: .userInitiated)
            private var hasFinished = false

            init(targetUUID: UUID, requiredRSSI: Int, serviceFilters: [CBUUID]) {
                self.targetUUID = targetUUID
                self.requiredRSSI = requiredRSSI
                self.serviceFilters = serviceFilters
                super.init()
            }

            func scan() async throws -> Bool {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation

                    print("📡 [BT] Creating CBCentralManager...")
                    self.centralManager = CBCentralManager(
                        delegate: self,
                        queue: queue,
                        options: [CBCentralManagerOptionShowPowerAlertKey: false]
                    )

                    // 10-second scan timeout
                    queue.asyncAfter(deadline: .now() + 10) { [weak self] in
                        guard let self = self else { return }
                        print("📡 [BT] ⏰ Timeout - finishing scan")
                        self.finish()
                    }
                }
            }

            func centralManagerDidUpdateState(_ central: CBCentralManager) {
                print("📡 [BT] State: \(central.state.rawValue)")
                if #available(iOS 13.0, *) {
                    print("📡 [BT] Authorization: \(CBManager.authorization.rawValue)")
                }

                switch central.state {
                case .poweredOn:
                    let filtersDescription = serviceFilters.map { $0.uuidString }
                    print("📡 [BT] ✅ Starting scan for \(targetUUID) with filters: \(filtersDescription)")
                    central.scanForPeripherals(
                        withServices: serviceFilters.isEmpty ? nil : serviceFilters,
                        options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                    )

                case .poweredOff, .unauthorized, .unsupported:
                    print("📡 [BT] ❌ Bluetooth unavailable: \(central.state)")
                    continuation?.resume(throwing: BluetoothError.unavailable)
                    continuation = nil

                default:
                    break
                }
            }

            func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
                let rssi = RSSI.intValue

                if peripheral.identifier == targetUUID {
                    print("📡 [BT] 🎯 Found target! RSSI: \(rssi)")
                    if rssi > strongestRSSI {
                        strongestRSSI = rssi
                        print("📡 [BT] 📶 New strongest: \(strongestRSSI)")
                    }

                    if strongestRSSI >= requiredRSSI {
                        print("📡 [BT] 🟢 Threshold met, finishing scan early")
                        finish()
                    }
                }
            }

            private func finish() {
                guard !hasFinished else { return }
                hasFinished = true

                centralManager?.stopScan()

                let isNearby = strongestRSSI >= requiredRSSI
                print("📡 [BT] Result: \(isNearby) (strongest: \(strongestRSSI), required: \(requiredRSSI))")

                continuation?.resume(returning: isNearby)
                continuation = nil
            }
        }

        enum BluetoothError: Error {
            case unavailable
        }

        // Perform the scan
        do {
            let scanner = Scanner(
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

// AppEntity for our MonitoredDevice to make it selectable in Shortcuts
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

// Simple UserDefaults-based storage to avoid SwiftData XPC issues
class DeviceStorage {
    static let shared = DeviceStorage()
    private let devicesKey = "monitored_devices"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var defaults: UserDefaults? {
        let suite = UserDefaults(suiteName: "group.com.bradzellman.magiccuts")
        print("💾 [Storage] UserDefaults suite initialized: \(suite != nil)")
        return suite
    }

    func saveDevice(_ entity: MonitoredDeviceEntity) async {
        print("💾 [Storage] saveDevice called for: \(entity.name)")
        guard let defaults = defaults else {
            print("💾 [Storage] ❌ Failed to get UserDefaults suite")
            return
        }

        var devices = loadDeviceInfos()
        print("💾 [Storage] Current device count: \(devices.count)")

        if let index = devices.firstIndex(where: { $0.id == entity.id.uuidString }) {
            devices[index] = DeviceInfo(
                id: entity.id.uuidString,
                name: entity.name,
                requiredSignalStrength: entity.requiredSignalStrength,
                serviceUUIDs: entity.serviceUUIDs
            )
        } else {
            devices.append(
                DeviceInfo(
                    id: entity.id.uuidString,
                    name: entity.name,
                    requiredSignalStrength: entity.requiredSignalStrength,
                    serviceUUIDs: entity.serviceUUIDs
                )
            )
        }

        persist(devices, defaults: defaults)
        print("💾 [Storage] ✅ Saved \(devices.count) devices")
    }

    func getAllDevices() async -> [MonitoredDeviceEntity] {
        print("💾 [Storage] getAllDevices called")
        let devices = loadDeviceInfos()
        print("💾 [Storage] Returning \(devices.count) devices")

        return devices.compactMap { info in
            guard let uuid = UUID(uuidString: info.id) else {
                print("💾 [Storage] ⚠️ Invalid UUID stored: \(info.id)")
                return nil
            }
            print("💾 [Storage] Parsed device: \(info.name) (\(uuid))")
            return MonitoredDeviceEntity(
                id: uuid,
                name: info.name,
                requiredSignalStrength: info.requiredSignalStrength,
                serviceUUIDs: info.serviceUUIDs
            )
        }
    }

    func getDevice(id: UUID) async -> MonitoredDeviceEntity? {
        print("💾 [Storage] getDevice called for: \(id)")
        let device = await getAllDevices().first { $0.id == id }
        print("💾 [Storage] Found: \(device?.name ?? "nil")")
        return device
    }

    // MARK: - Private helpers

    private func loadDeviceInfos() -> [DeviceInfo] {
        guard let defaults = defaults else {
            print("💾 [Storage] ❌ Failed to get UserDefaults suite")
            return []
        }

        if let data = defaults.data(forKey: devicesKey) {
            do {
                let decoded = try decoder.decode([DeviceInfo].self, from: data)
                print("💾 [Storage] Decoded \(decoded.count) devices from JSON")
                return decoded
            } catch {
                print("💾 [Storage] ⚠️ Failed to decode JSON: \(error)")
            }
        }

        if let raw = defaults.array(forKey: devicesKey) as? [[String: Any]] {
            print("💾 [Storage] Raw data count: \(raw.count)")
            let fallback = raw.compactMap { dict -> DeviceInfo? in
                guard let id = dict["id"] as? String,
                      let name = dict["name"] as? String,
                      let rssi = dict["rssi"] as? Int else {
                    print("💾 [Storage] ⚠️ Failed to parse legacy device: \(dict)")
                    return nil
                }
                let services = dict["services"] as? [String] ?? dict["serviceUUIDs"] as? [String] ?? []
                return DeviceInfo(id: id, name: name, requiredSignalStrength: rssi, serviceUUIDs: services)
            }
            return fallback
        }

        print("💾 [Storage] No devices found in storage")
        return []
    }

    private func persist(_ devices: [DeviceInfo], defaults: UserDefaults) {
        do {
            let data = try encoder.encode(devices)
            defaults.set(data, forKey: devicesKey)
            defaults.synchronize()
        } catch {
            print("💾 [Storage] ❌ Failed to encode devices: \(error)")
        }
    }
}

// Query to provide the list of saved devices to the Shortcuts app
struct MonitoredDeviceQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [MonitoredDeviceEntity] {
        print("🔍 [Query] entities(for:) called with \(identifiers.count) identifiers")
        let allDevices = await DeviceStorage.shared.getAllDevices()
        print("🔍 [Query] Found \(allDevices.count) devices in storage")
        let filtered = allDevices.filter { identifiers.contains($0.id) }
        print("🔍 [Query] Returning \(filtered.count) matching devices")
        return filtered
    }

    func suggestedEntities() async throws -> [MonitoredDeviceEntity] {
        print("🔍 [Query] suggestedEntities() called")
        let devices = await DeviceStorage.shared.getAllDevices()
        print("🔍 [Query] Returning \(devices.count) suggested devices")
        for device in devices {
            print("🔍 [Query]   - \(device.name) (\(device.id))")
        }
        return devices
    }
}
