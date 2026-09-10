import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CloudLibrarySync {
    private(set) var snapshot = CloudSyncSnapshot()
    private(set) var changingPreference = false
    var localFailure: String?
    @ObservationIgnored let transport: CloudLibraryTransport
    @ObservationIgnored private let archive: InstrumentArchive
    @ObservationIgnored private var listener: Task<Void, Never>?
    @ObservationIgnored private var preferenceGeneration = 0

    init(archive: InstrumentArchive) {
        self.archive = archive
        let accountReader: any CloudAccountReading
        #if DEBUG
        accountReader = AppRuntime.isUITesting ? UnavailableTestCloudAccount() : SystemCloudAccount()
        #else
        accountReader = SystemCloudAccount()
        #endif
        transport = CloudLibraryTransport(archive: archive, preferencesSuite: AppRuntime.isUITesting ? "MagicCuts.iCloud.UITests" : nil, accountReader: accountReader)
        let updates = transport.updates
        listener = Task { [weak self] in
            for await value in updates {
                guard !Task.isCancelled else { return }
                self?.snapshot = value
            }
        }
    }

    deinit { listener?.cancel() }

    func setEnabled(_ enabled: Bool) async {
        preferenceGeneration += 1
        let generation = preferenceGeneration
        changingPreference = true; localFailure = nil
        defer { if preferenceGeneration == generation { changingPreference = false } }
        if enabled {
            do {
                try await ProAccess.require()
                await transport.enable()
            } catch { localFailure = error.localizedDescription }
        } else { await transport.disable() }
    }

    func mirrorDevices(in context: ModelContext) async {
        do {
            let installation = try await archive.installationID()
            let devices = try context.fetch(FetchDescriptor<MonitoredDevice>())
            let tests = try context.fetch(FetchDescriptor<TestRecord>())
            let previous = try await archive.loadIndex()
            var restoredIDs: [String] = []
            for device in devices {
                let identity = device.portabilityIdentifier ?? UUID(uuidString: device.persistentIdentifier)
                if let saved = previous.deviceSetups.first(where: { $0.id == identity }), saved.installationID != installation {
                    device.portabilityIdentifier = UUID()
                    device.validationResetAt = .now
                    restoredIDs.append(device.persistentIdentifier)
                }
            }
            if !restoredIDs.isEmpty {
                do { try context.save() } catch { context.rollback(); throw error }
                for id in restoredIDs { UserDefaults.standard.removeObject(forKey: "shortcutVerified.\(id)") }
            }
            try DeviceRepository(context: context).reconcile()
            let setups = devices.compactMap { device -> PortableDeviceSetup? in
                guard let id = UUID(uuidString: device.persistentIdentifier) else { return nil }
                let records = tests.filter { $0.deviceID == device.persistentIdentifier }.map {
                    PortableDeviceTest(id: $0.identifier, date: $0.date, payload: $0.payload)
                }.sorted { $0.id.uuidString < $1.id.uuidString }
                return PortableDeviceSetup(id: device.portabilityIdentifier ?? id, installationID: installation,
                    device: DeviceInfo(id: device.persistentIdentifier, name: device.name, rssi: device.requiredSignalStrength, serviceUUIDs: device.serviceUUIDs), tests: records)
            }
            _ = try await archive.mirrorDeviceSetups(setups)
            localFailure = nil
            await transport.localLibraryChanged()
        } catch { localFailure = "Bluetooth setups couldn't be prepared for portability. \(error.localizedDescription)" }
    }
}

nonisolated struct LocalDeviceLink: Codable, Equatable, Sendable {
    var sourceID: String
    var localDeviceID: String
    var installationID: String
}

@MainActor
enum CloudDeviceLinks {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppRuntime.isUITesting || AppRuntime.isUnitTesting ? "MagicCuts.DeviceLinks.Tests" : "group.com.bradzellman.magiccuts")
    }

    static func load(installationID: String) throws -> [LocalDeviceLink] {
        guard let defaults else { throw BluetoothError.storage }
        guard let data = defaults.data(forKey: "icloud.localDeviceLinks") else { return [] }
        return try JSONDecoder().decode([LocalDeviceLink].self, from: data).filter { $0.installationID == installationID }
    }

    static func save(sourceID: String, localDeviceID: String?, installationID: String) throws {
        guard let defaults else { throw BluetoothError.storage }
        var links = try load(installationID: installationID).filter { $0.sourceID != sourceID }
        if let localDeviceID { links.append(LocalDeviceLink(sourceID: sourceID, localDeviceID: localDeviceID, installationID: installationID)) }
        let data = try LibraryCoding.encode(links)
        defaults.set(data, forKey: "icloud.localDeviceLinks")
        guard defaults.data(forKey: "icloud.localDeviceLinks") == data else { throw BluetoothError.storage }
    }

    static func resolve(_ sourceID: String, devices: [DeviceInfo], links: [LocalDeviceLink]) -> DeviceInfo? {
        if let device = devices.first(where: { $0.id == sourceID }) { return device }
        guard let link = links.first(where: { $0.sourceID == sourceID }) else { return nil }
        return devices.first { $0.id == link.localDeviceID }
    }

    static func expand(_ devices: [DeviceInfo], installationID: String) throws -> [DeviceInfo] {
        var values = devices
        for link in try load(installationID: installationID) where !values.contains(where: { $0.id == link.sourceID }) {
            guard let local = devices.first(where: { $0.id == link.localDeviceID }) else { continue }
            values.append(DeviceInfo(id: link.sourceID, name: local.name, rssi: local.requiredSignalStrength, serviceUUIDs: local.serviceUUIDs, radioID: local.id))
        }
        return values
    }
}
