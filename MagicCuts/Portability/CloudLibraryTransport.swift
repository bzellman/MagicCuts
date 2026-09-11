import CloudKit
import Foundation

nonisolated protocol CloudAccountReading: Sendable {
    func accountID() async throws -> String
}

nonisolated struct SystemCloudAccount: CloudAccountReading {
    func accountID() async throws -> String {
        let container = CKContainer(identifier: CloudLibraryTransport.containerIdentifier)
        switch try await container.accountStatus() {
        case .available: break
        case .noAccount, .restricted: throw CloudLibraryError.signedOut
        default: throw CloudLibraryError.accountUnavailable
        }
        return try await container.userRecordID().recordName
    }
}

#if DEBUG
nonisolated struct UnavailableTestCloudAccount: CloudAccountReading {
    func accountID() async throws -> String { throw CloudLibraryError.accountUnavailable }
}
#endif

nonisolated struct CloudSyncConsent: Codable, Equatable, Sendable {
    var enabled = false
    var accountID: String?
    var installationID: String?

    func permits(account: String, installation: String) -> Bool {
        enabled && accountID == account && installationID == installation
    }
}

nonisolated struct CloudLibraryState: Codable, Sendable {
    var format = 1
    var consent = CloudSyncConsent()
    var engine: CKSyncEngine.State.Serialization?
    var serverFields: [String: Data] = [:]
    var acknowledged: [String: LibraryVersion] = [:]
    var lastSync: Date?
}

nonisolated struct CloudSyncSnapshot: Sendable {
    var enabled = false
    var busy = false
    var message = "Saved on this device"
    var failure = false
    var lastSync: Date?
    var installationID = ""
    var libraryRevision = 0
}

actor CloudLibraryTransport: CKSyncEngineDelegate {
    nonisolated static let containerIdentifier = "iCloud.com.bradZellman.MagicCuts"
    nonisolated static let zoneName = "MagicCutsLibrary"
    nonisolated static let recordType = "LibraryItem"
    nonisolated let updates: AsyncStream<CloudSyncSnapshot>
    private let continuation: AsyncStream<CloudSyncSnapshot>.Continuation
    private let archive: InstrumentArchive
    private let preferences: UserDefaults
    private let makeContainer: @Sendable () -> CKContainer
    private let accountReader: any CloudAccountReading
    private var state = CloudLibraryState()
    private var snapshot = CloudSyncSnapshot()
    private var loaded = false
    private var engine: CKSyncEngine?
    private var cloud: CKContainer?
    private var transferDirectory: URL?
    private var fetchFailed = false
    private var sendFailed = false
    private var fetching = false
    private var sending = false
    private var operationGeneration = 0

    init(archive: InstrumentArchive, preferencesSuite: String? = nil,
         accountReader: any CloudAccountReading = SystemCloudAccount(),
         makeContainer: @escaping @Sendable () -> CKContainer = { CKContainer(identifier: CloudLibraryTransport.containerIdentifier) }) {
        self.archive = archive
        self.makeContainer = makeContainer
        self.accountReader = accountReader
        preferences = preferencesSuite.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        let stream = AsyncStream<CloudSyncSnapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        updates = stream.stream
        continuation = stream.continuation
    }

    deinit { continuation.finish() }

    func currentSettings() async throws -> CloudSyncSnapshot {
        try await load()
        return snapshot
    }

    private func publish() {
        snapshot.enabled = state.consent.enabled
        snapshot.lastSync = state.lastSync
        continuation.yield(snapshot)
    }

    private func load() async throws {
        guard !loaded else { return }
        let installation = try await archive.installationID()
        let data = try await archive.loadSyncState()
        guard !loaded else { return }
        let saved = try data.map { try JSONDecoder().decode(CloudLibraryState.self, from: $0) } ?? CloudLibraryState()
        guard saved.format == 1 else { throw InstrumentError.storage("Update MagicCuts to read this device's iCloud settings.") }
        state = saved
        snapshot.installationID = installation
        // Consent never migrates to another installation through an iCloud device backup.
        if state.consent.installationID != installation ||
            preferences.string(forKey: "icloud.optInInstallation") != installation ||
            !preferences.bool(forKey: "icloud.optedIn") {
            state.consent.enabled = false
        }
        loaded = true
        publish()
    }

    func resume() async {
        do {
            try await load()
            guard state.consent.enabled else { publish(); return }
            try await verifyAccount()
            try await startEngineIfNeeded()
            try await queueLocalChanges()
        } catch { await report(error) }
    }

    func enable() async {
        operationGeneration += 1
        let generation = operationGeneration
        do {
            try await load()
            guard operationGeneration == generation else { return }
            snapshot.busy = true; snapshot.failure = false; snapshot.message = "Connecting to iCloud…"; publish()
            let account = try await accountReader.accountID()
            guard operationGeneration == generation else { return }
            if state.consent.accountID != account {
                state.engine = nil; state.serverFields = [:]; state.acknowledged = [:]; state.lastSync = nil
            }
            state.consent = CloudSyncConsent(enabled: true, accountID: account, installationID: snapshot.installationID)
            try await persist()
            guard operationGeneration == generation, state.consent.enabled else { return }
            preferences.set(snapshot.installationID, forKey: "icloud.optInInstallation")
            preferences.set(true, forKey: "icloud.optedIn")
            try await startEngineIfNeeded()
            try await syncNow()
        } catch {
            guard operationGeneration == generation else { return }
            if !preferences.bool(forKey: "icloud.optedIn") { state.consent.enabled = false }
            await report(error)
        }
    }

    func disable(message: String = "Sync is off. Your local and iCloud copies are kept.") async {
        operationGeneration += 1
        // Save a separate opt-out before waiting for network cancellation or file access.
        preferences.set(false, forKey: "icloud.optedIn")
        state.consent.enabled = false
        let previous = engine
        engine = nil
        snapshot.busy = false; snapshot.failure = false; snapshot.message = message; publish()
        do { try await persist() }
        catch { snapshot.failure = true; snapshot.message = "Sync stopped, but its settings couldn't be saved. \(error.localizedDescription)"; publish() }
        await previous?.cancelOperations()
        cleanTransfers()
    }

    func syncNow() async throws {
        try await load()
        guard state.consent.enabled else { return }
        try await verifyAccount()
        try await startEngineIfNeeded()
        guard let current = engine else { return }
        snapshot.busy = true; snapshot.failure = false; snapshot.message = "Syncing your library…"; publish()
        try await current.fetchChanges()
        guard engine === current, state.consent.enabled else { return }
        try await queueLocalChanges()
        try await current.sendChanges()
        guard engine === current, state.consent.enabled else { return }
        try await finishIfCurrent()
    }

    func localLibraryChanged() async {
        guard state.consent.enabled, engine != nil else { return }
        do { try await queueLocalChanges() }
        catch { await report(error) }
    }

    func suspend() async {
        let previous = engine
        engine = nil
        await previous?.cancelOperations()
        cleanTransfers()
    }

    func retry() async {
        do {
            try await load()
            guard state.consent.enabled else { return }
            try await syncNow()
        } catch { await report(error) }
    }

    private func container() -> CKContainer {
        if let cloud { return cloud }
        let value = makeContainer()
        cloud = value
        return value
    }

    private func verifyAccount() async throws {
        let generation = operationGeneration
        let account = try await accountReader.accountID()
        guard operationGeneration == generation else { throw CancellationError() }
        guard state.consent.permits(account: account, installation: snapshot.installationID) else {
            if let current = engine { await disableForAccountChange(current) }
            else { await disable(message: "Your Apple Account changed. Turn on sync again to use the current account.") }
            throw CloudLibraryError.accountChanged
        }
    }

    private func startEngineIfNeeded() async throws {
        guard engine == nil, state.consent.enabled else { return }
        _ = try await archive.prepareSync()
        guard engine == nil, state.consent.enabled else { return }
        if state.engine == nil { state.acknowledged = [:] }
        fetching = false; sending = false; fetchFailed = false; sendFailed = false
        var configuration = CKSyncEngine.Configuration(database: container().privateCloudDatabase, stateSerialization: state.engine, delegate: self)
        configuration.automaticallySync = true
        let current = CKSyncEngine(configuration)
        engine = current
        current.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneName: Self.zoneName))])
    }

    private func queueLocalChanges() async throws {
        guard let current = engine, state.consent.enabled else { return }
        let index = try await archive.prepareSync()
        guard engine === current, state.consent.enabled else { return }
        let pending = index.versions.filter { state.acknowledged[$0.key] != $0.value }.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord(recordID($0.key))
        }
        let acknowledged = current.state.pendingRecordZoneChanges.filter { change in
            if case .saveRecord(let id) = change, let version = index.versions[id.recordName] {
                return state.acknowledged[id.recordName] == version
            }
            return false
        }
        current.state.remove(pendingRecordZoneChanges: acknowledged)
        if !pending.isEmpty {
            if !snapshot.failure { snapshot.message = "Changes waiting for iCloud" }
            publish()
            current.state.add(pendingRecordZoneChanges: pending)
        }
    }

    private func recordID(_ key: String) -> CKRecord.ID {
        CKRecord.ID(recordName: key, zoneID: CKRecordZone.ID(zoneName: Self.zoneName))
    }

    private func persist() async throws { try await archive.saveSyncState(LibraryCoding.encode(state)) }

    private func finishIfCurrent() async throws {
        snapshot.busy = fetching || sending
        guard let current = engine, !snapshot.busy, !fetchFailed, !sendFailed, !snapshot.failure else { publish(); return }
        let index = try await archive.loadIndex()
        let pending = index.versions.contains { state.acknowledged[$0.key] != $0.value }
        if !pending && current.state.pendingDatabaseChanges.isEmpty && current.state.zoneIDsWithUnfetchedServerChanges.isEmpty {
            state.lastSync = .now
            snapshot.message = "Library up to date"
            try await persist()
        } else { snapshot.message = "Changes waiting for iCloud" }
        publish()
    }

    private func report(_ error: Error, resetFetch: Bool = false) async {
        if error is CancellationError { return }
        if (error as? CloudLibraryError) == .signedOut || (error as? CKError)?.code == .notAuthenticated {
            let message = "iCloud is signed out or restricted. Sync is off and your local library is kept. Check your Apple Account, then turn on sync again."
            if let current = engine { await disableForAccountChange(current, message: message) }
            else { await disable(message: message) }
            return
        }
        if let issue = error as? CloudLibraryError, case .externalDeletion = issue, let current = engine {
            state.engine = nil; state.serverFields = [:]; state.acknowledged = [:]
            await disableForAccountChange(current, message: "Your iCloud library changed outside MagicCuts. Sync is off and local data is kept. Turn on sync to upload it again.")
            return
        }
        if resetFetch {
            state.engine = nil
            let previous = engine
            engine = nil
            // Await cancellation outside delegate delivery to avoid waiting on this event itself.
            Task { await previous?.cancelOperations() }
        }
        snapshot.busy = false; snapshot.failure = true
        snapshot.message = CloudLibraryError.message(for: error)
        do { try await persist() }
        catch { snapshot.message += " The sync checkpoint couldn't be saved. Your local library is kept." }
        publish()
    }

    func handleEvent(_ event: CKSyncEngine.Event, syncEngine current: CKSyncEngine) async {
        guard engine === current, state.consent.enabled else { return }
        do {
            switch event {
            case .stateUpdate(let event):
                state.engine = event.stateSerialization
                try await persist()
            case .accountChange(let event):
                switch event.changeType {
                case .signIn(let user):
                    if user.recordName != state.consent.accountID { await disableForAccountChange(current) }
                case .signOut, .switchAccounts: await disableForAccountChange(current)
                @unknown default: await disableForAccountChange(current)
                }
            case .fetchedDatabaseChanges(let event):
                if event.deletions.contains(where: { $0.zoneID.zoneName == Self.zoneName }) {
                    state.engine = nil; state.serverFields = [:]; state.acknowledged = [:]
                    await disableForAccountChange(current, message: "Your iCloud library was removed. Local data is kept. Turn on sync to upload it again.")
                }
            case .fetchedRecordZoneChanges(let event):
                try await verifyAccount()
                for change in event.modifications where change.record.recordID.zoneID.zoneName == Self.zoneName {
                    guard engine === current, state.consent.enabled else { return }
                    try await receive(change.record, current: current)
                }
                // This app uses tombstone records for deletions. A hard delete indicates an external reset.
                if event.deletions.contains(where: { $0.recordID.zoneID.zoneName == Self.zoneName }) { throw CloudLibraryError.externalDeletion }
                try await persist()
                try await queueLocalChanges()
            case .sentRecordZoneChanges(let event):
                for record in event.savedRecords {
                    let version = try decodeVersion(record)
                    state.acknowledged[record.recordID.recordName] = version
                    state.serverFields[record.recordID.recordName] = try systemFields(record)
                    removeTransfer(version.revision)
                }
                for failure in event.failedRecordSaves {
                    if failure.error.code == .serverRecordChanged, let server = failure.error.serverRecord {
                        try await receive(server, current: current)
                        guard engine === current, state.consent.enabled else { return }
                    } else {
                        sendFailed = true
                        if failure.error.code == .zoneNotFound || failure.error.code == .unknownItem { throw CloudLibraryError.externalDeletion }
                        snapshot.failure = true; snapshot.message = CloudLibraryError.message(for: failure.error)
                    }
                }
                try await persist()
                try await queueLocalChanges()
            case .sentDatabaseChanges(let event):
                if let failure = event.failedZoneSaves.first { throw failure.error }
            case .willFetchChanges:
                fetching = true; fetchFailed = false; snapshot.busy = true; snapshot.failure = sendFailed
                if !snapshot.failure { snapshot.message = "Syncing your library…" }; publish()
            case .willSendChanges:
                sending = true; sendFailed = false; snapshot.busy = true; snapshot.failure = fetchFailed
                if !snapshot.failure { snapshot.message = "Syncing your library…" }; publish()
            case .didFetchRecordZoneChanges(let event):
                if let error = event.error {
                    fetchFailed = true; snapshot.failure = true; snapshot.message = CloudLibraryError.message(for: error); publish()
                }
            case .didFetchChanges: fetching = false; try await finishIfCurrent()
            case .didSendChanges: sending = false; try await finishIfCurrent()
            case .willFetchRecordZoneChanges: break
            @unknown default: break
            }
        } catch { await report(error, resetFetch: true) }
    }

    private func disableForAccountChange(_ current: CKSyncEngine, message: String = "Your Apple Account changed. Turn on sync again to use the current account.") async {
        operationGeneration += 1
        preferences.set(false, forKey: "icloud.optedIn")
        state.consent.enabled = false; engine = nil; state.engine = nil
        snapshot.busy = false; snapshot.failure = false; snapshot.message = message
        do { try await persist() }
        catch { snapshot.failure = true; snapshot.message += " The sync checkpoint couldn't be saved." }
        publish()
        Task { await current.cancelOperations() }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine current: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        guard engine === current, state.consent.enabled else { return nil }
        do {
            try await verifyAccount()
            guard engine === current, state.consent.enabled else { return nil }
            let changes = current.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }.prefix(16)
            let keys = Set(changes.compactMap { change -> String? in
                if case .saveRecord(let id) = change { return id.recordName }
                return nil
            })
            // Materialize one payload at a time; a room's mesh and orientation map can be much larger than scalar sessions.
            var values: [CKRecord] = []
            for key in keys.sorted() {
                let records = try await archive.syncRecords(keys: [key])
                guard engine === current, state.consent.enabled else { return nil }
                guard records.count == 1, let record = records.first else { throw CloudLibraryError.invalidRecord }
                values.append(try makeCloudRecord(record))
            }
            return values.isEmpty ? nil : CKSyncEngine.RecordZoneChangeBatch(recordsToSave: values, atomicByZone: false)
        } catch {
            await report(error, resetFetch: true)
            return nil
        }
    }

    private func receive(_ record: CKRecord, current: CKSyncEngine) async throws {
        let version = try decodeVersion(record)
        let payload: Data?
        if version.deleted { payload = nil }
        else {
            guard let asset = record["payload"] as? CKAsset, let url = asset.fileURL else { throw CloudLibraryError.invalidRecord }
            payload = try Data(contentsOf: url)
        }
        let value = LibraryRecord(key: record.recordID.recordName, version: version, payload: payload)
        let changed = try await archive.mergeSyncRecord(value)
        guard engine === current, state.consent.enabled else { return }
        state.serverFields[value.key] = try systemFields(record)
        state.acknowledged[value.key] = version
        if changed { snapshot.libraryRevision += 1; publish() }
    }

    private func decodeVersion(_ record: CKRecord) throws -> LibraryVersion {
        guard record.recordType == Self.recordType, record.recordID.zoneID.zoneName == Self.zoneName,
              let format = record["format"] as? NSNumber, format.intValue == 1,
              let data = record["revision"] as? Data else { throw CloudLibraryError.invalidRecord }
        return try JSONDecoder().decode(LibraryVersion.self, from: data)
    }

    private func makeCloudRecord(_ value: LibraryRecord) throws -> CKRecord {
        let record: CKRecord
        if let data = state.serverFields[value.key] {
            let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
            decoder.requiresSecureCoding = true
            defer { decoder.finishDecoding() }
            guard let restored = CKRecord(coder: decoder) else { throw CloudLibraryError.invalidRecord }
            record = restored
        } else { record = CKRecord(recordType: Self.recordType, recordID: recordID(value.key)) }
        record["format"] = NSNumber(value: 1)
        record["revision"] = try LibraryCoding.encode(value.version) as NSData
        if let payload = value.payload {
            let url = try transferURL(value.version.revision)
            try payload.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            record["payload"] = CKAsset(fileURL: url)
        } else { record["payload"] = nil }
        return record
    }

    private func systemFields(_ record: CKRecord) throws -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        if let error = coder.error { throw error }
        return coder.encodedData
    }

    private func transferURL(_ revision: UUID) throws -> URL {
        if transferDirectory == nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-iCloud-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            transferDirectory = directory
        }
        guard let transferDirectory else { throw CloudLibraryError.invalidRecord }
        return transferDirectory.appendingPathComponent(revision.uuidString + ".json")
    }

    private func removeTransfer(_ revision: UUID) {
        guard let transferDirectory else { return }
        let url = transferDirectory.appendingPathComponent(revision.uuidString + ".json")
        // These are disposable upload copies; the committed library is the durable source.
        try? FileManager.default.removeItem(at: url)
    }

    private func cleanTransfers() {
        if let transferDirectory { try? FileManager.default.removeItem(at: transferDirectory) }
        transferDirectory = nil
    }
}

nonisolated enum CloudLibraryError: LocalizedError, Equatable {
    case accountUnavailable, signedOut, accountChanged, externalDeletion, invalidRecord
    var errorDescription: String? {
        switch self {
        case .accountUnavailable: "iCloud is unavailable. Check your Apple Account and iCloud settings, then try again. Your library stays on this device."
        case .signedOut: "Sign in to your Apple Account and allow iCloud, then turn on sync again. Your library stays on this device."
        case .accountChanged: "Your Apple Account changed. Sync is off until you turn it on for the current account."
        case .externalDeletion: "An iCloud library item was removed outside MagicCuts. Sync paused to protect the remaining copies. Contact support before resetting sync."
        case .invalidRecord: "An iCloud item couldn't be read. Update MagicCuts and try again. Your local library is kept."
        }
    }

    static func message(for error: Error) -> String {
        guard let cloud = error as? CKError else { return error.localizedDescription }
        switch cloud.code {
        case .quotaExceeded: return "Your iCloud storage is full. Free some space, then try again. Changes are saved on this device."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .zoneBusy, .requestRateLimited:
            return "iCloud couldn't connect. Changes are saved on this device. Try again when iCloud is available."
        case .notAuthenticated, .accountTemporarilyUnavailable: return CloudLibraryError.accountUnavailable.localizedDescription
        case .badContainer, .badDatabase, .missingEntitlement, .permissionFailure:
            return "iCloud isn't available for this build of MagicCuts. Your local library is kept. Contact support for help."
        default: return "iCloud sync paused. Your local library is kept. Try again; contact support if this continues."
        }
    }
}
