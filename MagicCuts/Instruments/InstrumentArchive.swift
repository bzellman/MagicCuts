import Foundation
import Observation

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

    func saveDraft(_ session: RecordedSession) throws {
        guard !session.points.isEmpty else { return }
        try Self.write(session, to: directory().appendingPathComponent(session.id.uuidString + ".draft.json"))
    }

    func loadDrafts() throws -> [RecordedSession] {
        let urls = try FileManager.default.contentsOfDirectory(at: directory(), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        return try urls.filter { $0.lastPathComponent.hasSuffix(".draft.json") }.map {
            try JSONDecoder().decode(RecordedSession.self, from: Data(contentsOf: $0))
        }.sorted { $0.endedAt > $1.endedAt }
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
        var coordinationError: NSError?
        var outcome: Result<Void, Error>?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forMerging, error: &coordinationError) { coordinated in
            outcome = Result {
                let index = try Self.readIndex(coordinated)
                let attached = Set(index.reports.flatMap(\.sessionIDs))
                for (key, version) in index.versions where version.deleted {
                    let record = LibraryRecord(key: key, version: version)
                    guard let (kind, id) = record.identity, kind == .session, !attached.contains(id),
                          !index.sessions.contains(where: { $0.id == id }) else { continue }
                    for suffix in [".json", ".draft.json"] {
                        let file = directory.appendingPathComponent(id.uuidString + suffix)
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
        let sessionURL = try directory().appendingPathComponent(id.uuidString + ".json")
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
            deleteSessionBytes = kind == .session && record.version.deleted && !index.reports.contains { $0.sessionIDs.contains(id) }
            accepted = true
        }, beforeWrite: {
            guard accepted, kind == .session else { return }
            if case .session(let session) = value {
                if FileManager.default.fileExists(atPath: sessionURL.path) { previousSession = try Data(contentsOf: sessionURL) }
                try Self.write(session, to: sessionURL)
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
            recovered = try await archive.loadDrafts().filter { draft in
                !index.sessions.contains { $0.id == draft.id } && index.versions[LibraryRecord.key(.session, draft.id)]?.deleted != true
            }
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
