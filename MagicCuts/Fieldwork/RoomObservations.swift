import Foundation

nonisolated struct RoomLocatedEvidence: Sendable {
    var positions: [SpatialVector] = []
    var totalPositionCount = 0
    var recordings: [SessionIndexEntry] = []
    var captures: [FieldCaptureIndex] = []
}

extension InstrumentArchive {
    func locatedEvidence(in room: RoomRevision) throws -> RoomLocatedEvidence {
        let index = try loadIndex()
        let revisions = Set(index.roomRevisions.filter { $0.roomID == room.roomID && $0.coordinateFrameID == room.coordinateFrameID }.map(\.id)).union([room.id])
        var result = RoomLocatedEvidence()
        func locations(_ placements: [RoomPlacement]) -> [SpatialVector] {
            placements.filter { $0.roomID == room.roomID && $0.coordinateFrameID == room.coordinateFrameID }.map { $0.pose.position }
        }
        func append(_ points: [SpatialVector]) {
            result.totalPositionCount += points.count
            let remaining = max(0, 3000 - result.positions.count)
            guard remaining > 0 else { return }
            let step = max(1, Int(ceil(Double(points.count) / Double(remaining))))
            result.positions += stride(from: 0, to: points.count, by: step).map { points[$0] }
        }
        for entry in index.sessions where !revisions.isDisjoint(with: entry.roomRevisionIDs ?? []) {
            let recording = try loadSession(entry.id)
            let points = locations(recording.points.compactMap(\.placement))
            if !points.isEmpty { result.recordings.append(entry); append(points) }
        }
        for entry in index.fieldCaptures where !revisions.isDisjoint(with: entry.roomRevisionIDs ?? []) {
            let capture = try loadFieldCapture(entry.id)
            let points = locations(capture.samples.compactMap(\.placement) + capture.probes.compactMap(\.placement))
            if !points.isEmpty { result.captures.append(entry); append(points) }
        }
        return result
    }
}
