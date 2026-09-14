import AppIntents
import Foundation

struct IsDeviceNearbyIntent: AppIntent {
    static let title: LocalizedStringResource = "Check if Bluetooth Device is Nearby"
    static let description = IntentDescription("Returns true if a valid Bluetooth reading meets your saved threshold. False means not detected above threshold, not confirmed absence. Bluetooth failures stop the shortcut with an error.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @Parameter(title: "Device to Check") var device: MonitoredDeviceEntity
    static var parameterSummary: some ParameterSummary { Summary("Check if \(\.$device) is nearby") }
    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        try await ProAccess.require()
        let result = try await Self.check(id: device.id, storage: .shared, radio: BluetoothRadio())
        return .result(value: result)
    }
    @MainActor
    static func check(id: UUID, storage: SharedDeviceStorage, radio: any RadioScanning, duration: Duration = .seconds(10)) async throws -> Bool {
        guard let saved = try storage.getDevice(id: id.uuidString) else { throw BluetoothError.deletedDevice }
        guard (-100 ... -1).contains(saved.requiredSignalStrength) else { throw BluetoothError.invalidThreshold }
        guard let radioID = saved.radioUUID else { throw BluetoothError.storage }
        let samples = try await ProximitySampler(radio: radio).collect(id: radioID, services: saved.serviceUUIDs, duration: duration, stoppingAtThreshold: saved.requiredSignalStrength)
        return samples.contains { $0.rssi >= saved.requiredSignalStrength }
    }
}

struct MonitoredDeviceEntity: AppEntity {
    var id: UUID
    var name: String
    var requiredSignalStrength: Int
    var serviceUUIDs: [String]
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Monitored Device"
    static let defaultQuery = MonitoredDeviceQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct MonitoredDeviceQuery: EntityQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [MonitoredDeviceEntity] { try load().filter { identifiers.contains($0.id) } }
    @MainActor func suggestedEntities() async throws -> [MonitoredDeviceEntity] { try load() }
    @MainActor private func load() throws -> [MonitoredDeviceEntity] {
        try SharedDeviceStorage.shared.getAllDevices().compactMap { info in
            guard let id = UUID(uuidString: info.id) else { return nil }
            return MonitoredDeviceEntity(id: id, name: info.name, requiredSignalStrength: info.requiredSignalStrength, serviceUUIDs: info.serviceUUIDs)
        }
    }
}
