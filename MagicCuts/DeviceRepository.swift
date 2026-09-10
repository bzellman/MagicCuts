import Foundation
import SwiftData
import AppIntents

struct TestDeviceIdentity {
    let id: String
    let name: String
    let persistentID: PersistentIdentifier
    init(_ device: MonitoredDevice) {
        id = device.persistentIdentifier
        name = device.name
        persistentID = device.persistentModelID
    }
}

@Model
final class TestRecord {
    var identifier: UUID = UUID()
    var deviceID: String = ""
    var deviceName: String = ""
    var date: Date = Date()
    var payload: Data = Data()
    init(identity: TestDeviceIdentity, evidence: TestEvidence) throws {
        deviceID = identity.id
        deviceName = identity.name
        date = evidence.endedAt
        payload = try JSONEncoder().encode(evidence)
    }
    var evidence: TestEvidence? { try? JSONDecoder().decode(TestEvidence.self, from: payload) }
}

@MainActor
final class DeviceRepository {
    let context: ModelContext
    let shared: SharedDeviceStorage
    private let refreshShortcuts: @MainActor () -> Void
    init(context: ModelContext, shared: SharedDeviceStorage? = nil, refreshShortcuts: (@MainActor () -> Void)? = nil) {
        self.context = context
        self.shared = shared ?? .shared
        self.refreshShortcuts = refreshShortcuts ?? { MagicCutsShortcuts.updateAppShortcutParameters() }
    }
    func reconcile() throws {
        let devices = try context.fetch(FetchDescriptor<MonitoredDevice>())
        try shared.replace(devices.map { DeviceInfo(id: $0.persistentIdentifier, name: $0.name, rssi: $0.requiredSignalStrength, serviceUUIDs: $0.serviceUUIDs) })
        refreshShortcuts()
    }
    func existingDevice(_ persistentID: PersistentIdentifier) throws -> MonitoredDevice {
        guard let device = try context.fetch(FetchDescriptor<MonitoredDevice>()).first(where: { $0.persistentModelID == persistentID }) else {
            throw BluetoothError.deletedDevice
        }
        return device
    }
    func save(_ device: MonitoredDevice?, id: UUID, name: String, threshold: Int, services: [String]) throws {
        guard services.allSatisfy(ServiceIdentifier.isValid) else { throw BluetoothError.storage }
        guard (-100 ... -1).contains(threshold) else { throw ValidationError.threshold }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ValidationError.name }
        let target: MonitoredDevice
        if let device {
            target = try existingDevice(device.persistentModelID)
            guard target.uuid == id else { throw BluetoothError.deletedDevice }
        }
        else {
            let all = try context.fetch(FetchDescriptor<MonitoredDevice>())
            guard !all.contains(where: { $0.uuid == id }) else { throw ValidationError.duplicate }
            target = MonitoredDevice(persistentIdentifier: id, name: trimmed, requiredSignalStrength: threshold, serviceUUIDs: services)
            context.insert(target)
        }
        let normalizedServices = Array(Set(services.map { $0.uppercased() })).sorted()
        if target.requiredSignalStrength != threshold || target.serviceUUIDs.sorted() != normalizedServices { target.validationResetAt = Date() }
        target.name = trimmed
        target.requiredSignalStrength = threshold
        target.serviceUUIDs = normalizedServices
        try persistChanges()
        do { try reconcile() } catch { throw ValidationError.sync }
    }
    func delete(_ device: MonitoredDevice) throws {
        let records = try context.fetch(FetchDescriptor<TestRecord>()).filter { $0.deviceID == device.persistentIdentifier }
        records.forEach { context.delete($0) }
        context.delete(device)
        try persistChanges()
        do { try reconcile() } catch { throw ValidationError.sync }
    }
    func record(_ evidence: TestEvidence, device: MonitoredDevice) throws {
        try record(evidence, identity: TestDeviceIdentity(device))
    }
    func record(_ evidence: TestEvidence, identity: TestDeviceIdentity) throws {
        let device = try existingDevice(identity.persistentID)
        guard device.persistentIdentifier == identity.id else {
            throw BluetoothError.deletedDevice
        }
        context.insert(try TestRecord(identity: identity, evidence: evidence))
        try persistChanges()
    }
    private func persistChanges() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    enum ValidationError: LocalizedError {
        case name, duplicate, sync, threshold
        var errorDescription: String? {
            switch self {
            case .threshold: "Choose a threshold from −100 to −1 dBm."
            case .name: "Give this device a name."
            case .duplicate: "This device is already saved. Open it from Devices."
            case .sync: "Saved in MagicCuts, but Shortcuts could not be updated. Return to Devices and tap Retry sync."
            }
        }
    }
}
