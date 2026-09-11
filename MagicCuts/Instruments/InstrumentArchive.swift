import Foundation
import Observation

nonisolated struct UnreadableDraft: Identifiable, Equatable, Sendable {
    var id: String
    var isRoom: Bool
}
nonisolated struct LibraryDraftRecovery: Sendable {
    var rooms: [RoomRevision] = []
    var recordings: [RecordedSession] = []
    var unreadable: [UnreadableDraft] = []
}

actor InstrumentArchive {
    private let root: URL?

    init(root: URL? = nil, useSharedContainer: Bool = true) {
        if let root { self.root = root }
        else if useSharedContainer {
            self.root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bradzellman.magiccuts")?
                .appendingPathComponent("ProLibrary", isDirectory: true)
        } else {
            self.root = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-Pro-\(UUID().uuidString)", isDirectory: true)
        }
    }

    func loadIndex() throws -> ProLibraryIndex {
        let url = try indexURL()
        var coordinationError: NSError?
        var outcome: Result<ProLibraryIndex, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            outcome = Result { try Self.readIndex(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw InstrumentError.storage("The local library couldn't be opened. Try again.") }
        return try outcome.get()
    }

    func loadSession(_ id: UUID) throws -> RecordedSession {
        let url = try directory().appendingPathComponent(id.uuidString + ".json")
        return try JSONDecoder().decode(RecordedSession.self, from: Data(contentsOf: url))
    }

    func loadRoomRevision(_ id: UUID) throws -> RoomRevision {
        let value = try JSONDecoder().decode(RoomRevision.self, from: Data(contentsOf: payloadURL(.roomRevision, id)))
        guard value.isValid else { throw InstrumentError.storage("This room's geometry couldn't be read. Your saved file has been kept.") }
        return value
    }

    func loadFieldCapture(_ id: UUID) throws -> FieldCapture {
        let value = try JSONDecoder().decode(FieldCapture.self, from: Data(contentsOf: payloadURL(.fieldCapture, id)))
        guard value.isValid else { throw InstrumentError.storage("This capture couldn't be read. Your saved file has been kept.") }
        return value
    }

    func saveRoomRevision(_ revision: RoomRevision) throws -> ProLibraryIndex {
        guard revision.isValid else { throw InstrumentError.storage("The scan has no usable surface mesh or contains invalid geometry. Continue scanning or retry.") }
        let url = try payloadURL(.roomRevision, revision.id)
        var wrote = false
        return try update({ index in
            guard !index.roomRevisions.contains(where: { $0.id == revision.id }) else {
                throw InstrumentError.storage("This revision is already saved. Create a new revision to keep another scan.")
            }
            index.roomRevisions.insert(RoomRevisionIndex(revision), at: 0)
        }, beforeWrite: {
            guard !FileManager.default.fileExists(atPath: url.path) else {
                throw InstrumentError.storage("A capture file already exists for this revision. Recover it from Rooms before saving again.")
            }
            try Self.write(revision, to: url); wrote = true
        }, undoWrite: {
            if wrote { try FileManager.default.removeItem(at: url) }
        })
    }

    func saveRoomDraft(_ revision: RoomRevision) throws {
        guard revision.isValid else { return }
        let index = try loadIndex()
        guard !index.roomRevisions.contains(where: { $0.id == revision.id }), index.versions[LibraryRecord.key(.roomRevision, revision.id)]?.deleted != true else { return }
        let url = try directory().appendingPathComponent("room-\(revision.id).draft.json")
        if FileManager.default.fileExists(atPath: url.path),
           let existing = try? JSONDecoder().decode(RoomRevision.self, from: Data(contentsOf: url)), existing.endedAt > revision.endedAt { return }
        try Self.write(revision, to: url)
    }

    func loadDraftRecovery() throws -> LibraryDraftRecovery {
        let urls = try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let index = try loadIndex()
        var recovery = LibraryDraftRecovery()
        for url in urls where url.lastPathComponent.hasSuffix(".draft.json") {
            let isRoom = url.lastPathComponent.hasPrefix("room-")
            do {
                let data = try Data(contentsOf: url)
                if isRoom {
                    let revision = try JSONDecoder().decode(RoomRevision.self, from: data)
                    guard revision.isValid, url.lastPathComponent == "room-\(revision.id).draft.json" else { throw InstrumentError.storage("Invalid scan") }
                    if !index.roomRevisions.contains(where: { $0.id == revision.id }), index.versions[LibraryRecord.key(.roomRevision, revision.id)]?.deleted != true { recovery.rooms.append(revision) }
                } else {
                    let recording = try JSONDecoder().decode(RecordedSession.self, from: data)
                    guard url.lastPathComponent == "\(recording.id).draft.json" else { throw InstrumentError.storage("Invalid recording") }
                    recovery.recordings.append(recording)
                }
            } catch { recovery.unreadable.append(UnreadableDraft(id: url.lastPathComponent, isRoom: isRoom)) }
        }
        recovery.rooms.sort { $0.endedAt > $1.endedAt }
        recovery.recordings.sort { $0.endedAt > $1.endedAt }
        return recovery
    }

    func loadRoomDrafts() throws -> [RoomRevision] {
        let recovery = try loadDraftRecovery()
        guard !recovery.unreadable.contains(where: \.isRoom) else {
            throw InstrumentError.storage("An unfinished scan couldn't be read. Its file and spatial references have been kept; review it in Rooms.")
        }
        return recovery.rooms
    }

    func discardUnreadableDraft(_ draft: UnreadableDraft) throws {
        // Only a filename discovered in the recovery directory can be removed.
        guard try loadDraftRecovery().unreadable.contains(draft) else { return }
        try FileManager.default.removeItem(at: directory().appendingPathComponent(draft.id))
    }

    func discardRoomDraft(_ id: UUID) throws {
        let url = try directory().appendingPathComponent("room-\(id).draft.json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func saveFieldCapture(_ capture: FieldCapture) throws -> ProLibraryIndex {
        guard capture.isValid else { throw InstrumentError.storage("This capture contains invalid readings and couldn't be saved.") }
        let url = try payloadURL(.fieldCapture, capture.id)
        var previous: Data?
        return try update({ index in
            index.fieldCaptures.removeAll { $0.id == capture.id }
            index.fieldCaptures.insert(FieldCaptureIndex(capture), at: 0)
        }, beforeWrite: {
            if FileManager.default.fileExists(atPath: url.path) { previous = try Data(contentsOf: url) }
            try Self.write(capture, to: url)
        }, undoWrite: {
            if let previous { try previous.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
            else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }, forcedKey: LibraryRecord.key(.fieldCapture, capture.id))
    }

    func deleteFieldCapture(_ id: UUID) throws -> ProLibraryIndex {
        // Keep the source file until the index transaction succeeds. Tombstones protect offline copies.
        let index = try update { $0.fieldCaptures.removeAll { $0.id == id } }
        let url = try payloadURL(.fieldCapture, id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        return index
    }

    func deleteRoomRevision(_ id: UUID) throws -> ProLibraryIndex {
        let drafts = try loadDrafts()
        let roomDrafts = try loadRoomDrafts()
        guard !roomDrafts.contains(where: { $0.parentRevisionID == id }) else {
            throw InstrumentError.storage("A recovered scan references this revision. Save or discard that scan first.")
        }
        guard !drafts.contains(where: { $0.points.contains { $0.placement?.revisionID == id } }) else {
            throw InstrumentError.storage("An unfinished recording references this room revision. Save or discard that recording first.")
        }
        let index = try update { index in
            guard !index.referencedRoomRevisionIDs.contains(id) else {
                throw InstrumentError.storage("This revision has measurement pins or later revisions. Keep it as their spatial reference.")
            }
            index.roomRevisions.removeAll { $0.id == id }
        }
        let url = try payloadURL(.roomRevision, id)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        return index
    }

    private func payloadURL(_ kind: LibraryRecordKind, _ id: UUID) throws -> URL {
        let prefix = kind == .roomRevision ? "room-" : kind == .fieldCapture ? "capture-" : ""
        return try directory().appendingPathComponent(prefix + id.uuidString + ".json")
    }

    func saveDraft(_ session: RecordedSession) throws {
        guard !session.points.isEmpty else { return }
        try Self.write(session, to: directory().appendingPathComponent(session.id.uuidString + ".draft.json"))
    }

    func loadDrafts() throws -> [RecordedSession] {
        let recovery = try loadDraftRecovery()
        guard !recovery.unreadable.contains(where: { !$0.isRoom }) else {
            throw InstrumentError.storage("An unfinished recording couldn't be read. Its file and spatial references have been kept; review it in Sessions.")
        }
        return recovery.recordings
    }

    func discardDraft(_ id: UUID) throws {
        let url = try directory().appendingPathComponent(id.uuidString + ".draft.json")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    func saveSession(_ session: RecordedSession) throws -> ProLibraryIndex {
        guard !session.points.isEmpty else { throw InstrumentError.noReadings }
        let url = try directory().appendingPathComponent(session.id.uuidString + ".json")
        var previous: Data?
        return try update({ index in
            index.sessions.removeAll { $0.id == session.id }
            index.sessions.insert(SessionIndexEntry(session), at: 0)
        }, beforeWrite: {
            if FileManager.default.fileExists(atPath: url.path) { previous = try Data(contentsOf: url) }
            try Self.write(session, to: url)
        }, undoWrite: {
            if let previous { try previous.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
            else if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        }, forcedKey: LibraryRecord.key(.session, session.id))
    }

    func deleteSession(_ id: UUID) throws -> ProLibraryIndex {
        let url = try directory().appendingPathComponent(id.uuidString + ".json")
        var backup: Data?
        return try update({ index in
            guard !index.reports.contains(where: { $0.sessionIDs.contains(id) }) else {
                throw InstrumentError.storage("This session is attached to a field report. Remove it from that report before deleting it.")
            }
            index.sessions.removeAll { $0.id == id }
        }, beforeWrite: {
            if FileManager.default.fileExists(atPath: url.path) {
                backup = try Data(contentsOf: url)
                try FileManager.default.removeItem(at: url)
            }
        }, undoWrite: {
            if let backup { try backup.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        })
    }

    func saveProfile(_ profile: CalibrationProfile) throws -> ProLibraryIndex {
        try update { index in
            index.profiles.removeAll { $0.id == profile.id }
            index.profiles.insert(profile, at: 0)
        }
    }

    func deleteProfile(_ id: UUID) throws -> ProLibraryIndex { try update { $0.profiles.removeAll { $0.id == id } } }

    func saveWorkflow(_ recipe: WorkflowRecipe) throws -> ProLibraryIndex {
        guard !recipe.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !recipe.conditions.isEmpty, recipe.conditions.count <= 8,
              recipe.conditions.allSatisfy({ $0.threshold.isFinite && (1 ... 10).contains($0.window) }) else {
            throw InstrumentError.unavailable("Give the workflow a name and one to eight valid conditions.")
        }
        return try update { index in
            index.workflows.removeAll { $0.id == recipe.id }
            index.workflows.insert(recipe, at: 0)
        }
    }

    func deleteWorkflow(_ id: UUID) throws -> ProLibraryIndex { try update { $0.workflows.removeAll { $0.id == id } } }

    func saveGroup(_ group: DeviceGroup) throws -> ProLibraryIndex {
        guard !group.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !group.deviceIDs.isEmpty else {
            throw InstrumentError.unavailable("Name the group and select at least one saved device.")
        }
        if let minimum = group.minimumMatches, !(1 ... group.deviceIDs.count).contains(minimum) {
            throw InstrumentError.unavailable("The minimum count must fit the number of devices in the group.")
        }
        return try update { index in
            index.groups.removeAll { $0.id == group.id }
            index.groups.insert(group, at: 0)
        }
    }

    func deleteGroup(_ id: UUID) throws -> ProLibraryIndex { try update { $0.groups.removeAll { $0.id == id } } }

    func saveReport(_ report: FieldReport) throws -> ProLibraryIndex {
        guard !report.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw InstrumentError.storage("Give this report a title.") }
        return try update { index in
            guard report.sessionIDs.allSatisfy({ id in index.sessions.contains { $0.id == id } }) else {
                throw InstrumentError.storage("An attached session is unavailable on this device. Finish syncing, or remove the unavailable attachment before saving.")
            }
            index.reports.removeAll { $0.id == report.id }
            index.reports.insert(report, at: 0)
        }
    }

    func deleteReport(_ id: UUID) throws -> ProLibraryIndex { try update { $0.reports.removeAll { $0.id == id } } }

    func installationID() throws -> String {
        var url = try directory().appendingPathComponent("installation-id.json")
        var coordinationError: NSError?
        var outcome: Result<String, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinated in
            outcome = Result {
                if FileManager.default.fileExists(atPath: coordinated.path) {
                    let value = try JSONDecoder().decode(UUID.self, from: Data(contentsOf: coordinated))
                    return value.uuidString
                }
                let value = UUID()
                try Self.write(value, to: coordinated)
                return value.uuidString
            }
        }
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw InstrumentError.storage("This device's library identity couldn't be saved.") }
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try url.setResourceValues(resources)
        return try outcome.get()
    }

    func mirrorDeviceSetups(_ setups: [PortableDeviceSetup]) throws -> ProLibraryIndex {
        let localID = try installationID()
        guard setups.allSatisfy({ $0.installationID == localID }) else { throw InstrumentError.storage("These setups belong to another device.") }
        let incomingIDs = Set(setups.map(\.id))
        return try update { index in
            index.deviceSetups.removeAll { $0.installationID == localID || incomingIDs.contains($0.id) }
            index.deviceSetups.append(contentsOf: setups)
            index.deviceSetups.sort { $0.id.uuidString < $1.id.uuidString }
        }
    }

    func prepareSync() throws -> ProLibraryIndex { try update { _ in } }

    func pruneDeletedSessionFiles() throws {
        let url = try indexURL()
        let directory = try directory()
        let recordingReferences = Set(try loadDrafts().flatMap { $0.points.compactMap { $0.placement?.revisionID } })
        let recoveredReferences = Set(try loadRoomDrafts().compactMap(\.parentRevisionID))
        var coordinationError: NSError?
        var outcome: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinated in
            outcome = Result {
                let index = try Self.readIndex(coordinated)
                let attached = Set(index.reports.flatMap(\.sessionIDs))
                for (key, version) in index.versions where version.deleted {
                    let record = LibraryRecord(key: key, version: version)
                    guard let (kind, id) = record.identity else { continue }
                    let prefix: String
                    switch kind {
                    case .session:
                        guard !attached.contains(id), !index.sessions.contains(where: { $0.id == id }) else { continue }
                        prefix = ""
                    case .roomRevision:
                        guard !index.referencedRoomRevisionIDs.contains(id), !recordingReferences.contains(id),
                              !recoveredReferences.contains(id), !index.roomRevisions.contains(where: { $0.id == id }) else { continue }
                        prefix = "room-"
                    case .fieldCapture:
                        guard !index.fieldCaptures.contains(where: { $0.id == id }) else { continue }
                        prefix = "capture-"
                    default: continue
                    }
                    for suffix in [".json", ".draft.json"] {
                        let file = directory.appendingPathComponent(prefix + id.uuidString + suffix)
                        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
                    }
                }
            }
        }
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw InstrumentError.storage("Deleted measurement files couldn't be cleared.") }
        try outcome.get()
    }

    func syncRecords(keys: Set<String>? = nil) throws -> [LibraryRecord] {
        let index = try loadIndex()
        let payloads = try index.recordPayloads()
        return try index.versions.keys.filter { keys?.contains($0) ?? true }.sorted().map { key in
            guard let version = index.versions[key] else { throw InstrumentError.storage("A library revision is missing.") }
            var record = LibraryRecord(key: key, version: version, payload: version.deleted ? nil : payloads[key])
            guard let (kind, id) = record.identity else { throw InstrumentError.storage("An unrecognized library item couldn't be synced.") }
            if !version.deleted {
                switch kind {
                case .session:
                    var session = try loadSession(id)
                    if session.metadata["installationID"] == nil { session.metadata["installationID"] = "unverified-legacy-source" }
                    if session.reference?.metadata["installationID"] == nil { session.reference?.metadata["installationID"] = "unverified-legacy-source" }
                    record.payload = try LibraryCoding.encode(session)
                case .profile:
                    var profile = try LibraryCoding.decode(CalibrationProfile.self, from: record)
                    if profile.metadata["installationID"] == nil { profile.metadata["installationID"] = "unverified-legacy-source" }
                    record.payload = try LibraryCoding.encode(profile)
                case .roomRevision: record.payload = try LibraryCoding.encode(loadRoomRevision(id))
                case .fieldCapture: record.payload = try LibraryCoding.encode(loadFieldCapture(id))
                default: break
                }
                guard record.payload != nil else { throw InstrumentError.storage("An item is missing from the local library. Sync paused to keep your iCloud copy safe.") }
            }
            return record
        }
    }

    @discardableResult
    func mergeSyncRecord(_ record: LibraryRecord) throws -> Bool {
        guard record.format == 1, let (kind, id) = record.identity,
              record.version.sequence > 0, record.version.sequence < Int64.max,
              UUID(uuidString: record.version.writer) != nil,
              record.version.deleted == (record.payload == nil) else {
            throw InstrumentError.storage("An iCloud item couldn't be read. Update MagicCuts and try again; your local library is unchanged.")
        }
        // Decode and validate before touching the index or its sample files.
        let value = try ValidatedLibraryValue(record)
        let sessionURL = try payloadURL(kind, id)
        let draftReferences: Set<UUID>
        if kind == .roomRevision, record.version.deleted {
            draftReferences = Set(try loadDrafts().flatMap { $0.points.compactMap { $0.placement?.revisionID } })
                .union(try loadRoomDrafts().compactMap(\.parentRevisionID))
        } else { draftReferences = [] }
        var accepted = false
        var previousSession: Data?
        var wroteSession = false
        var deleteSessionBytes = false
        _ = try update({ index in
            index.sequence = max(index.sequence, record.version.sequence)
            if let current = index.versions[record.key] {
                if current.deleted && !record.version.deleted { return }
                if current.deleted == record.version.deleted && current >= record.version { return }
            }
            value.apply(to: &index, id: id)
            index.sequence = max(index.sequence, record.version.sequence)
            index.versions[record.key] = record.version
            deleteSessionBytes = record.version.deleted && (
                (kind == .session && !index.reports.contains { $0.sessionIDs.contains(id) }) || kind == .fieldCapture ||
                (kind == .roomRevision && !index.referencedRoomRevisionIDs.contains(id) && !draftReferences.contains(id)))
            accepted = true
        }, beforeWrite: {
            guard accepted, [.session, .roomRevision, .fieldCapture].contains(kind) else { return }
            if case .session(let session) = value {
                if FileManager.default.fileExists(atPath: sessionURL.path) { previousSession = try Data(contentsOf: sessionURL) }
                try Self.write(session, to: sessionURL)
                wroteSession = true
            } else if !record.version.deleted, let payload = record.payload {
                if FileManager.default.fileExists(atPath: sessionURL.path) { previousSession = try Data(contentsOf: sessionURL) }
                if kind == .roomRevision, let previousSession,
                   try JSONDecoder().decode(RoomRevision.self, from: previousSession) != JSONDecoder().decode(RoomRevision.self, from: payload) {
                    throw InstrumentError.storage("A synced room revision conflicts with its original geometry. Your local copy has been kept.")
                }
                try payload.write(to: sessionURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
                wroteSession = true
            } else if deleteSessionBytes, FileManager.default.fileExists(atPath: sessionURL.path) {
                previousSession = try Data(contentsOf: sessionURL)
                try FileManager.default.removeItem(at: sessionURL)
                wroteSession = true
            }
        }, undoWrite: {
            guard wroteSession else { return }
            if let previousSession { try previousSession.write(to: sessionURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
            else { try FileManager.default.removeItem(at: sessionURL) }
        }, recordsLocalChanges: false)
        return accepted
    }

    func loadSyncState() throws -> Data? {
        let url = try directory().appendingPathComponent("icloud-state.json")
        return FileManager.default.fileExists(atPath: url.path) ? try Data(contentsOf: url) : nil
    }

    func saveSyncState(_ data: Data) throws {
        var url = try directory().appendingPathComponent("icloud-state.json")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var resources = URLResourceValues()
        resources.isExcludedFromBackup = true
        try url.setResourceValues(resources)
    }

    private func directory() throws -> URL {
        guard let root else { throw InstrumentError.storage("The shared library is unavailable. Open MagicCuts to repair access.") }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func indexURL() throws -> URL { try directory().appendingPathComponent("index.json") }

    private func update(_ mutation: (inout ProLibraryIndex) throws -> Void, beforeWrite: (() throws -> Void)? = nil, undoWrite: (() throws -> Void)? = nil, forcedKey: String? = nil, recordsLocalChanges: Bool = true) throws -> ProLibraryIndex {
        let url = try indexURL()
        let writer = recordsLocalChanges ? try installationID() : ""
        var coordinationError: NSError?
        var outcome: Result<ProLibraryIndex, Error>?
        // Read within the coordinated write: the app and Shortcuts never replace each other's stale index.
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinatedURL in
            outcome = Result {
                var index = try Self.readIndex(coordinatedURL)
                let previous = index
                try mutation(&index)
                do {
                    try beforeWrite?()
                    if recordsLocalChanges { try index.stampChanges(from: previous, writer: writer, forcedKey: forcedKey) }
                    try Self.write(index, to: coordinatedURL)
                } catch {
                    let original = error
                    do { try undoWrite?() }
                    catch { throw InstrumentError.storage("The library couldn't be saved or restored. Keep this recording open and try again. \(original.localizedDescription) \(error.localizedDescription)") }
                    throw original
                }
                return index
            }
        }
        if let coordinationError { throw coordinationError }
        guard let outcome else { throw InstrumentError.storage("The library couldn't be saved. Try again.") }
        return try outcome.get()
    }

    private static func readIndex(_ url: URL) throws -> ProLibraryIndex {
        guard FileManager.default.fileExists(atPath: url.path) else { return ProLibraryIndex() }
        let index = try JSONDecoder().decode(ProLibraryIndex.self, from: Data(contentsOf: url))
        guard index.version == 1 else { throw InstrumentError.storage("This library was made by a newer version of MagicCuts. Update the app to open it.") }
        return index
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

@MainActor
@Observable
final class ProLibrary {
    private(set) var index = ProLibraryIndex()
    private(set) var loading = false
    private(set) var recovered: [RecordedSession] = []
    private(set) var recoveredRooms: [RoomRevision] = []
    private(set) var unreadableDrafts: [UnreadableDraft] = []
    var error: String?
    @ObservationIgnored let archive: InstrumentArchive
    let sync: CloudLibrarySync

    init(archive: InstrumentArchive = InstrumentArchive()) {
        self.archive = archive
        sync = CloudLibrarySync(archive: archive)
    }

    func reload() async {
        loading = true
        defer { loading = false }
        do {
            index = try await archive.loadIndex()
            let recovery = try await archive.loadDraftRecovery()
            recovered = recovery.recordings.filter { draft in
                !index.sessions.contains { $0.id == draft.id } && index.versions[LibraryRecord.key(.session, draft.id)]?.deleted != true
            }
            recoveredRooms = recovery.rooms
            unreadableDrafts = recovery.unreadable
            error = nil
            await cleanDeletedFiles()
        }
        catch { self.error = "Your local library couldn't be opened. \(error.localizedDescription)" }
    }

    func cleanDeletedFiles() async {
        do { try await archive.pruneDeletedSessionFiles() }
        catch { self.error = "Your library is open, but deleted measurement files couldn't be cleared. \(error.localizedDescription)" }
    }

    func save(_ session: RecordedSession) async throws {
        index = try await archive.saveSession(session)
        error = nil
    }
    func save(_ profile: CalibrationProfile) async throws {
        index = try await archive.saveProfile(profile)
        error = nil
    }
    func save(_ recipe: WorkflowRecipe) async throws {
        index = try await archive.saveWorkflow(recipe)
        error = nil
    }
    func save(_ group: DeviceGroup) async throws {
        index = try await archive.saveGroup(group)
        error = nil
    }
    func save(_ report: FieldReport) async throws {
        index = try await archive.saveReport(report)
        error = nil
    }

    func save(_ revision: RoomRevision) async throws {
        index = try await archive.saveRoomRevision(revision)
        recoveredRooms.removeAll { $0.id == revision.id }
        do { try await archive.discardRoomDraft(revision.id); error = nil }
        catch { self.error = "Room saved. Its recovery copy couldn't be removed: \(error.localizedDescription)" }
    }

    func save(_ capture: FieldCapture) async throws {
        index = try await archive.saveFieldCapture(capture)
        error = nil
    }

    func seedDemoIfNeeded() async {
        guard AppRuntime.isInstrumentDemo, index.sessions.isEmpty else { return }
        let session = InstrumentDemo.session()
        do {
            try await save(session)
            if let summary = session.summary {
                try await save(CalibrationProfile(name: "At desk", kind: .bluetooth, sourceID: session.source.id, sourceName: session.source.name, date: session.startedAt, points: session.points, summary: summary, metadata: session.metadata))
            }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--cloud-setup-demo") {
                let origin = "BBBBBBBB-1111-2222-3333-444444444444"
                let remote = UUID(uuidString: "CCCCCCCC-1111-2222-3333-444444444444")!
                let now = Date()
                let evidence = TestEvidence(startedAt: now.addingTimeInterval(-10), endedAt: now, threshold: -70, position: .nearby, isDraft: false,
                    samples: [SignalSample(date: now.addingTimeInterval(-5), rssi: -64), SignalSample(date: now, rssi: -63)], failure: nil)
                let setup = PortableDeviceSetup(id: remote, installationID: origin,
                    device: DeviceInfo(id: remote.uuidString, name: "Studio sensor · sample", rssi: -70, serviceUUIDs: ["180F"]),
                    tests: [PortableDeviceTest(id: UUID(), date: now, payload: try LibraryCoding.encode(evidence))])
                let version = LibraryVersion(sequence: index.sequence + 1, writer: origin, revision: UUID(), deleted: false)
                try await archive.mergeSyncRecord(LibraryRecord(key: LibraryRecord.key(.deviceSetup, setup.id), version: version, payload: LibraryCoding.encode(setup)))
                _ = try await archive.saveGroup(DeviceGroup(name: "Studio readiness · sample", deviceIDs: [remote]))
                index = try await archive.loadIndex()
            }
            #endif
        } catch { self.error = error.localizedDescription }
    }
}

nonisolated enum InstrumentDemo {
    static func session(kind: InstrumentKind = .bluetooth) -> RecordedSession {
        let now = Date()
        let points = (0 ..< 120).map { index -> MeasurementPoint in
            let time = Double(index) / 6
            let value: Double
            switch kind {
            case .bluetooth: value = -63 + sin(time * 0.8) * 2 + cos(time * 2.3)
            case .tilt: value = 2.4 + sin(time) * 0.3
            case .vibration: value = 0.012 + abs(sin(time * 2)) * 0.004
            case .rotation: value = 12 + sin(time) * 4
            case .magnetic: value = 48 + sin(time) * 2
            case .pressure: value = 1013.2 + sin(time / 5) * 0.2
            case .altitude: value = time * 0.18
            case .heading: value = 144 + sin(time / 2) * 3
            case .speed: value = 1.4 + sin(time / 3) * 0.2
            case .sound: value = -32 + sin(time) * 4
            case .network: value = 26 + abs(sin(time * 1.4)) * 18
            case .battery: value = 84
            }
            return MeasurementPoint(elapsed: time, date: now.addingTimeInterval(time - 20), value: value, auxiliary: kind == .tilt ? ["pitch": 2.4, "roll": 0.8] : [:])
        }
        let source = kind == .bluetooth
            ? MeasurementSource(id: "AAAAAAAA-1111-2222-3333-444444444444", name: "Desk sensor", deviceID: UUID(uuidString: "AAAAAAAA-1111-2222-3333-444444444444"), serviceUUIDs: ["180F"], threshold: -70)
            : .phone
        return RecordedSession(title: "Desk setup", kind: kind, source: source, startedAt: now.addingTimeInterval(-20), endedAt: now, points: points, events: [CaptureEvent(elapsed: 12, text: "Door closed")], method: kind.method, termination: "Sample session", metadata: ["fixture": "Illustrative sample data"])
    }
}
