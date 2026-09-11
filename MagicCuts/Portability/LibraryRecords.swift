import Foundation

// These records contain user-owned library data only. Entitlements, permissions,
// Shortcuts confirmations, live captures and iCloud consent never enter them.
nonisolated struct LibraryVersion: Codable, Equatable, Comparable, Sendable {
    var sequence: Int64
    var writer: String
    var revision: UUID
    var deleted: Bool

    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
        if lhs.writer != rhs.writer { return lhs.writer < rhs.writer }
        if lhs.revision == rhs.revision { return !lhs.deleted && rhs.deleted }
        return lhs.revision.uuidString < rhs.revision.uuidString
    }
}

nonisolated enum LibraryRecordKind: String, Codable, CaseIterable, Sendable {
    case session, profile, workflow, group, report, deviceSetup, roomRevision, fieldCapture
}

nonisolated struct LibraryRecord: Codable, Equatable, Sendable {
    var format = 1
    var key: String
    var version: LibraryVersion
    var payload: Data?

    var identity: (LibraryRecordKind, UUID)? {
        let parts = key.split(separator: ":")
        guard parts.count == 2, let kind = LibraryRecordKind(rawValue: String(parts[0])),
              let id = UUID(uuidString: String(parts[1])) else { return nil }
        return (kind, id)
    }

    static func key(_ kind: LibraryRecordKind, _ id: UUID) -> String { "\(kind.rawValue):\(id.uuidString)" }
}

nonisolated struct PortableDeviceTest: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var date: Date
    var payload: Data
    var evidence: TestEvidence? { try? JSONDecoder().decode(TestEvidence.self, from: payload) }
}

nonisolated struct PortableDeviceSetup: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var installationID: String
    var device: DeviceInfo
    var tests: [PortableDeviceTest]
}

nonisolated enum LibraryCoding {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<T: Decodable>(_ type: T.Type, from record: LibraryRecord) throws -> T {
        guard record.format == 1, let data = record.payload, !record.version.deleted else {
            throw InstrumentError.storage("This iCloud library uses an unsupported format. Update MagicCuts before syncing it.")
        }
        return try JSONDecoder().decode(type, from: data)
    }
}

nonisolated enum ValidatedLibraryValue {
    case deleted(LibraryRecordKind)
    case session(RecordedSession), profile(CalibrationProfile), workflow(WorkflowRecipe)
    case group(DeviceGroup), report(FieldReport), deviceSetup(PortableDeviceSetup)
    case roomRevision(RoomRevision), fieldCapture(FieldCapture)

    init(_ record: LibraryRecord) throws {
        guard let (kind, id) = record.identity else { throw Self.invalid }
        if record.version.deleted { self = .deleted(kind); return }
        switch kind {
        case .session:
            let value = try LibraryCoding.decode(RecordedSession.self, from: record)
            guard value.id == id, !value.points.isEmpty, value.points.allSatisfy({ $0.value.isFinite && $0.elapsed.isFinite && ($0.placement?.isValid ?? true) }),
                  value.metadata["installationID"] != nil else { throw Self.invalid }
            self = .session(value)
        case .profile:
            let value = try LibraryCoding.decode(CalibrationProfile.self, from: record)
            guard value.id == id, !value.points.isEmpty, value.points.allSatisfy({ $0.value.isFinite && ($0.placement?.isValid ?? true) }),
                  value.metadata["installationID"] != nil else { throw Self.invalid }
            self = .profile(value)
        case .workflow:
            let value = try LibraryCoding.decode(WorkflowRecipe.self, from: record)
            guard value.id == id, !value.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !value.conditions.isEmpty, value.conditions.count <= 8,
                  value.conditions.allSatisfy({ $0.threshold.isFinite && (1 ... 10).contains($0.window) }) else { throw Self.invalid }
            self = .workflow(value)
        case .group:
            let value = try LibraryCoding.decode(DeviceGroup.self, from: record)
            guard value.id == id, !value.deviceIDs.isEmpty,
                  value.minimumMatches.map({ (1 ... value.deviceIDs.count).contains($0) }) ?? true else { throw Self.invalid }
            self = .group(value)
        case .report:
            let value = try LibraryCoding.decode(FieldReport.self, from: record)
            guard value.id == id, !value.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Self.invalid }
            self = .report(value)
        case .deviceSetup:
            let value = try LibraryCoding.decode(PortableDeviceSetup.self, from: record)
            guard value.id == id, UUID(uuidString: value.device.id) != nil,
                  UUID(uuidString: value.installationID) != nil else { throw Self.invalid }
            self = .deviceSetup(value)
        case .roomRevision:
            let value = try LibraryCoding.decode(RoomRevision.self, from: record)
            guard value.id == id, value.isValid else { throw Self.invalid }
            self = .roomRevision(value)
        case .fieldCapture:
            let value = try LibraryCoding.decode(FieldCapture.self, from: record)
            guard value.id == id, value.isValid else { throw Self.invalid }
            self = .fieldCapture(value)
        }
    }

    private static var invalid: InstrumentError {
        .storage("An iCloud item contains unsupported data. Sync paused without replacing your local copy.")
    }

    func apply(to index: inout ProLibraryIndex, id: UUID) {
        func replace<T: Identifiable>(_ items: inout [T], with value: T) where T.ID == UUID {
            items.removeAll { $0.id == id }
            items.insert(value, at: 0)
        }
        switch self {
        case .session(let value): replace(&index.sessions, with: SessionIndexEntry(value))
        case .profile(let value): replace(&index.profiles, with: value)
        case .workflow(let value): replace(&index.workflows, with: value)
        case .group(let value): replace(&index.groups, with: value)
        case .report(let value): replace(&index.reports, with: value)
        case .deviceSetup(let value): replace(&index.deviceSetups, with: value)
        case .roomRevision(let value): replace(&index.roomRevisions, with: RoomRevisionIndex(value))
        case .fieldCapture(let value): replace(&index.fieldCaptures, with: FieldCaptureIndex(value))
        case .deleted(let kind):
            switch kind {
            case .session: index.sessions.removeAll { $0.id == id }
            case .profile: index.profiles.removeAll { $0.id == id }
            case .workflow: index.workflows.removeAll { $0.id == id }
            case .group: index.groups.removeAll { $0.id == id }
            case .report: index.reports.removeAll { $0.id == id }
            case .deviceSetup: index.deviceSetups.removeAll { $0.id == id }
            case .roomRevision: index.roomRevisions.removeAll { $0.id == id }
            case .fieldCapture: index.fieldCaptures.removeAll { $0.id == id }
            }
        }
    }
}

nonisolated extension ProLibraryIndex {
    var referencedRoomRevisionIDs: Set<UUID> {
        var ids = Set(roomRevisions.compactMap(\.parentRevisionID))
        ids.formUnion(fieldCaptures.compactMap { $0.placement?.revisionID })
        ids.formUnion(fieldCaptures.flatMap { $0.roomRevisionIDs ?? [] })
        ids.formUnion(sessions.flatMap { $0.roomRevisionIDs ?? [] })
        ids.formUnion(profiles.flatMap { $0.points.compactMap { $0.placement?.revisionID } })
        return ids
    }
    func recordPayloads() throws -> [String: Data] {
        var values: [String: Data] = [:]
        func add<T: Encodable & Identifiable>(_ items: [T], kind: LibraryRecordKind) throws where T.ID == UUID {
            for item in items { values[LibraryRecord.key(kind, item.id)] = try LibraryCoding.encode(item) }
        }
        // The session entry detects index mutations; the archive supplies full sample data when uploading.
        try add(sessions, kind: .session)
        try add(profiles, kind: .profile)
        try add(workflows, kind: .workflow)
        try add(groups, kind: .group)
        try add(reports, kind: .report)
        try add(deviceSetups, kind: .deviceSetup)
        try add(roomRevisions, kind: .roomRevision)
        try add(fieldCaptures, kind: .fieldCapture)
        return values
    }

    mutating func stampChanges(from previous: ProLibraryIndex, writer: String, forcedKey: String? = nil) throws {
        let before = try previous.recordPayloads()
        let after = try recordPayloads()
        let keys = Set(before.keys).union(after.keys)
        let changed = keys.filter { before[$0] != after[$0] || versions[$0] == nil || $0 == forcedKey }
        guard !changed.isEmpty else { return }
        guard !changed.contains(where: { previous.versions[$0]?.deleted == true && after[$0] != nil }) else {
            throw InstrumentError.storage("This item was deleted. Create a new item to keep your changes; deleted items aren't restored by an offline edit.")
        }
        guard sequence < Int64.max else { throw InstrumentError.storage("The library revision limit has been reached.") }
        sequence += 1
        for key in changed {
            versions[key] = LibraryVersion(sequence: sequence, writer: writer, revision: UUID(), deleted: after[key] == nil)
        }
    }
}
