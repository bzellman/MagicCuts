import XCTest
import simd
import CoreNFC
@testable import MagicCuts

nonisolated final class RoomInstrumentTests: XCTestCase {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-RoomTests-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private func room() -> RoomRevision {
        var value = FieldDemo.room(); value.id = UUID(); value.roomID = UUID(); value.parentRevisionID = nil
        return value
    }
    func testRoomAndNestedMeasurementPlacementsSurviveOfflineReopen() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root), room = room()
        _ = try await archive.saveRoomRevision(room)
        let placement = FieldDemo.placement(x: 1.7, z: 0.9, revision: room)
        var capture = FieldDemo.network(revision: room)
        capture.probes[0].placement = placement; capture.placement = nil
        _ = try await archive.saveFieldCapture(capture)
        let reopened = InstrumentArchive(root: root)
        let savedRoom = try await reopened.loadRoomRevision(room.id)
        let savedCapture = try await reopened.loadFieldCapture(capture.id)
        XCTAssertEqual(savedRoom, room); XCTAssertEqual(savedCapture, capture)
        let index = try await reopened.loadIndex()
        XCTAssertTrue(index.referencedRoomRevisionIDs.contains(room.id))
        do { _ = try await reopened.deleteRoomRevision(room.id); XCTFail("Per-request locations own their source geometry") } catch { }
        _ = try await reopened.deleteFieldCapture(capture.id)
        _ = try await reopened.deleteRoomRevision(room.id)
        let final = try await reopened.loadIndex(); XCTAssertTrue(final.roomRevisions.isEmpty)
    }
    func testIndexCommitFailureRollsBackNewRoomAndRestoresEditedCapture() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root), originalRoom = room(), pendingRoom = room()
        _ = try await archive.saveRoomRevision(originalRoom)
        let capture = FieldDemo.network(revision: originalRoom)
        _ = try await archive.saveFieldCapture(capture)
        try await archive.saveRoomDraft(pendingRoom)
        var index = try await archive.loadIndex(); index.sequence = .max
        // Revision exhaustion fails the index transaction after the payload has been written.
        let indexData = try JSONEncoder().encode(index)
        try indexData.write(to: root.appendingPathComponent("index.json"), options: .atomic)
        do { _ = try await archive.saveRoomRevision(pendingRoom); XCTFail("Index commit must fail") } catch { }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("room-\(pendingRoom.id).json").path))
        var edited = capture; edited.title = "Unsaved edit"
        do { _ = try await archive.saveFieldCapture(edited); XCTFail("Index commit must fail") } catch { }
        let retainedCapture = try await archive.loadFieldCapture(capture.id)
        let retainedRoom = try await archive.loadRoomRevision(originalRoom.id)
        let drafts = try await archive.loadRoomDrafts()
        XCTAssertEqual(retainedCapture, capture); XCTAssertEqual(retainedRoom, originalRoom)
        XCTAssertEqual(drafts, [pendingRoom])
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("index.json")), indexData)
    }
    @MainActor func testUnreadableDraftDoesNotHideOtherWorkAndProtectsSpatialReferences() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root), saved = room(), recoverable = room()
        _ = try await archive.saveRoomRevision(saved)
        try await archive.saveRoomDraft(recoverable)
        let filename = "room-\(UUID()).draft.json"
        try Data("interrupted JSON".utf8).write(to: root.appendingPathComponent(filename))
        let library = ProLibrary(archive: archive); await library.reload()
        XCTAssertEqual(library.index.roomRevisions.count, 1)
        XCTAssertEqual(library.recoveredRooms, [recoverable])
        XCTAssertEqual(library.unreadableDrafts.map(\.id), [filename])
        do { _ = try await archive.deleteRoomRevision(saved.id); XCTFail("Unknown draft references must retain geometry") } catch { }
        try await archive.discardUnreadableDraft(library.unreadableDrafts[0])
        await library.reload(); XCTAssertTrue(library.unreadableDrafts.isEmpty)
        XCTAssertEqual(library.recoveredRooms, [recoverable])
        _ = try await archive.deleteRoomRevision(saved.id)
    }
    func testRecordedPositionsStayInTheirCoordinateFrame() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root), saved = room()
        _ = try await archive.saveRoomRevision(saved)
        var recording = InstrumentDemo.session()
        recording.points[0].placement = FieldDemo.placement(x: 1, z: 2, revision: saved)
        var unrelated = recording.points[0].placement!; unrelated.coordinateFrameID = UUID()
        recording.points[1].placement = unrelated
        _ = try await archive.saveSession(recording)
        let evidence = try await archive.locatedEvidence(in: saved)
        XCTAssertEqual(evidence.totalPositionCount, 1); XCTAssertEqual(evidence.recordings.map(\.id), [recording.id])
        XCTAssertEqual(evidence.positions, [recording.points[0].placement!.pose.position])
    }
    func testRevisionIsImmutableAndRecoveryCannotReplaceIt() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root), original = room()
        try await archive.saveRoomDraft(original)
        let drafts = try await archive.loadRoomDrafts(); XCTAssertEqual(drafts, [original])
        _ = try await archive.saveRoomRevision(original)
        var changed = original; changed.meshes[0].vertices[0].x += 1
        do { _ = try await archive.saveRoomRevision(changed); XCTFail("A saved revision cannot change geometry") } catch { }
        let reopened = try await archive.loadRoomRevision(original.id); XCTAssertEqual(reopened, original)
        let finalDrafts = try await archive.loadRoomDrafts(); XCTAssertTrue(finalDrafts.isEmpty)
    }
    func testConcurrentCloudPassesSurviveAndNativeJSONFormattingDoesNotConflict() async throws {
        let a = try folder(), b = try folder()
        defer { try? FileManager.default.removeItem(at: a); try? FileManager.default.removeItem(at: b) }
        let first = InstrumentArchive(root: a), second = InstrumentArchive(root: b), original = room()
        _ = try await first.saveRoomRevision(original)
        let originalRecords = try await first.syncRecords()
        for record in originalRecords { try await second.mergeSyncRecord(record) }
        var passA = original; passA.id = UUID(); passA.parentRevisionID = original.id
        var passB = original; passB.id = UUID(); passB.parentRevisionID = original.id
        passB.coordinateFrameID = UUID()
        _ = try await first.saveRoomRevision(passA); _ = try await second.saveRoomRevision(passB)
        let firstRecords = try await first.syncRecords(), secondRecords = try await second.syncRecords()
        for record in firstRecords { try await second.mergeSyncRecord(record) }
        for record in secondRecords { try await first.mergeSyncRecord(record) }
        let aIndex = try await first.loadIndex(), bIndex = try await second.loadIndex()
        XCTAssertEqual(Set(aIndex.roomRevisions.map(\.id)), Set([original.id, passA.id, passB.id]))
        XCTAssertEqual(Set(aIndex.roomRevisions.map(\.id)), Set(bIndex.roomRevisions.map(\.id)))
        var reencoded = try XCTUnwrap(originalRecords.first)
        reencoded.version.sequence += 100
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted]
        reencoded.payload = try encoder.encode(original)
        let accepted = try await second.mergeSyncRecord(reencoded); XCTAssertTrue(accepted)
        var corrupt = original; corrupt.meshes[0].vertices[0].x += 5
        reencoded.version.sequence += 1; reencoded.payload = try encoder.encode(corrupt)
        do { try await second.mergeSyncRecord(reencoded); XCTFail("Conflicting same-ID geometry must not overwrite") } catch { }
        let retained = try await second.loadRoomRevision(original.id); XCTAssertEqual(retained, original)
    }
    func testRemoteDeletionRetainsGeometryOwnedByAnUnfinishedRecording() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root), room = room()
        _ = try await archive.saveRoomRevision(room)
        var session = InstrumentDemo.session()
        session.points[0].placement = FieldDemo.placement(x: 1, z: 1, revision: room)
        try await archive.saveDraft(session)
        let records = try await archive.syncRecords()
        var deletion = try XCTUnwrap(records.first)
        deletion.version.sequence += 1; deletion.version.deleted = true; deletion.payload = nil
        try await archive.mergeSyncRecord(deletion)
        try await archive.pruneDeletedSessionFiles()
        let retained = try await archive.loadRoomRevision(room.id); XCTAssertEqual(retained, room)
        try await archive.discardDraft(session.id)
        try await archive.pruneDeletedSessionFiles()
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("room-\(room.id).json").path))
    }
    func testOldIndexAndMeasurementDecodeWithoutSpatialFields() throws {
        let index = try JSONDecoder().decode(ProLibraryIndex.self, from: Data("{\"version\":1,\"sessions\":[],\"profiles\":[],\"groups\":[],\"workflows\":[],\"reports\":[]}".utf8))
        XCTAssertTrue(index.roomRevisions.isEmpty); XCTAssertTrue(index.fieldCaptures.isEmpty)
        let point = InstrumentDemo.session().points[0]
        let data = try JSONEncoder().encode(point)
        let decoded = try JSONDecoder().decode(MeasurementPoint.self, from: data)
        XCTAssertNil(decoded.placement)
    }
    func testSpatialValidationRejectsCorruptMeshesAndNonrigidFrames() throws {
        var room = room(); XCTAssertTrue(room.isValid)
        room.meshes[0].triangleIndices[0] = UInt32.max; XCTAssertFalse(room.isValid)
        var transform = SpatialTransform(); transform.elements[0] = 2; XCTAssertFalse(transform.isValid)
        transform = SpatialTransform(); transform.elements[3] = 1; XCTAssertFalse(transform.isValid)
        var evidence = FieldDemo.network(revision: self.room())
        evidence.probes[0].sentBytes = -1; XCTAssertFalse(evidence.isValid)
        evidence = FieldDemo.network(revision: self.room())
        evidence.probes[0].transactions[0].phases = [.init(id: "tls", name: "TLS", start: 2, end: 1)]
        XCTAssertFalse(evidence.isValid)
    }
    func testFloorAreaRejectsCrossingsAndIncompleteCoverage() throws {
        let points: [SpatialVector] = [.init(x: 10000, y: 0, z: 10000), .init(x: 10004, y: 0, z: 10000), .init(x: 10004, y: 0, z: 10003), .init(x: 10000, y: 0, z: 10003)]
        XCTAssertEqual(try XCTUnwrap(SpatialMath.polygonArea(points)), 12, accuracy: 0.00001)
        XCTAssertEqual(SpatialMath.polygonArea(points + [points[0]]), 12)
        XCTAssertNil(SpatialMath.polygonArea([points[0], points[2], points[1], points[3]]))
        var room = room(); room.components[0].complete = false
        XCTAssertNil(room.floorArea); XCTAssertNil(room.estimatedVolume)
    }
    func testSurfaceFitSeparatesSlopeFromNoiseAndRejectsDegenerateSamples() throws {
        let flat = (0..<12).flatMap { x in (0..<12).map { z in SpatialVector(x: Float(x) / 10, y: 1, z: Float(z) / 10) } }
        let horizontal = try XCTUnwrap(SurfaceFitting.fit(flat))
        XCTAssertEqual(horizontal.slopeDegrees, 0, accuracy: 0.01); XCTAssertEqual(horizontal.rmsMeters, 0, accuracy: 1e-8)
        let slope = try XCTUnwrap(SurfaceFitting.fit(flat.map { .init(x: $0.x, y: $0.x, z: $0.z) }))
        XCTAssertEqual(slope.slopeDegrees, 45, accuracy: 0.01)
        let wall = try XCTUnwrap(SurfaceFitting.fit(flat.map { .init(x: $0.x, y: $0.z, z: 1) }))
        XCTAssertEqual(wall.slopeDegrees, 90, accuracy: 0.01)
        let noisy = try XCTUnwrap(SurfaceFitting.fit(flat.enumerated().map { i, p in .init(x: p.x, y: p.y + (i.isMultiple(of: 2) ? 0.003 : -0.003), z: p.z) }))
        XCTAssertGreaterThan(noisy.rmsMeters, 0.002); XCTAssertLessThan(noisy.rmsMeters, 0.004)
        XCTAssertNil(SurfaceFitting.fit((0..<40).map { .init(x: Float($0), y: 0, z: 0) }))
        XCTAssertNil(SurfaceFitting.fit(Array(flat.prefix(10))))
    }
    func testRelativeBearingAndProjectionRespectTheOwningCoordinateFrame() throws {
        let pose = SpatialTransform()
        XCTAssertEqual(try XCTUnwrap(SpatialMath.direction(from: pose, to: .init(x: 0, y: 0, z: -2))).radians, 0, accuracy: 1e-6)
        XCTAssertEqual(try XCTUnwrap(SpatialMath.direction(from: pose, to: .init(x: 2, y: 0, z: 0))).radians, .pi/2, accuracy: 1e-6)
        let projection = RoomProjection(room()), point = SpatialVector(x: 2, y: 1.2, z: 1.5)
        let restored = projection.world(projection.screen(point, size: CGSize(width: 400, height: 300)), size: CGSize(width: 400, height: 300), height: point.y)
        XCTAssertLessThan(point.distance(to: restored), 1e-6)
    }
    func testNetworkStatisticsExcludeFailuresAndUnverifiedCellularTransactions() throws {
        let transaction = RequestTransaction(phases: [], reused: false, cellular: true, cached: false, host: "test")
        var probes = [10.0, 20, 30].map { NetworkProbe(date: .now, elapsed: 0, durationMS: $0, status: 200, transactions: [transaction]) }
        probes.append(.init(date: .now, elapsed: 0, durationMS: 999, error: "Timed out", transactions: [transaction]))
        probes.append(.init(date: .now, elapsed: 0, durationMS: 500, status: 200, transactions: []))
        var mixed = probes[0]; mixed.transactions.append(.init(phases: [], reused: false, cellular: false, cached: false, host: "test")); probes.append(mixed)
        let metrics = Dictionary(uniqueKeysWithValues: FieldStatistics.networkMetrics(probes, cellularOnly: true).map { ($0.id, $0.value) })
        XCTAssertEqual(metrics["attempts"], 6); XCTAssertEqual(metrics["failed"], 1); XCTAssertEqual(metrics["verified"], 4)
        XCTAssertEqual(metrics["median"], 20); XCTAssertEqual(try XCTUnwrap(metrics["p95"]), 29, accuracy: 0.001)
        XCTAssertFalse(mixed.verifiedCellular)
        var cached = probes[0]; cached.transactions[0].cached = true; XCTAssertFalse(cached.verifiedCellular)
        XCTAssertFalse(FieldStatistics.networkMetrics([probes[3]]).contains { $0.id == "median" })
    }
    @MainActor func testNDEFTextParsingPreservesUnknownRawBytes() throws {
        XCTAssertEqual(NFCRecordDecoder.decodeText(Data([2]) + Data("enHello".utf8)), "Hello")
        XCTAssertNil(NFCRecordDecoder.decodeText(Data([10, 1, 2])))
        let bytes = Data([0xff, 0x00, 0xfe])
        let payload = NFCNDEFPayload(format: .unknown, type: Data(), identifier: Data([1]), payload: bytes)
        let record = NFCRecordDecoder.record(payload, index: 0)
        XCTAssertEqual(record.payload, bytes); XCTAssertNil(record.decoded); XCTAssertTrue(record.isValid)
    }
    func testPortableExportsPreserveGeometryUnitsAndEscapeSpreadsheetFormulas() async throws {
        var room = room(); room.dimensions[0].title = "=HYPERLINK(unsafe)"
        let archive = try await FieldExport.room(room)
        let imported = try await FieldExport.importRoom(archive); XCTAssertEqual(imported, room)
        let mesh = try await FieldExport.exportRoom(room, format: .observedMesh)
        let obj = try String(contentsOf: mesh, encoding: .utf8)
        XCTAssertTrue(obj.contains("Units: meters")); XCTAssertTrue(obj.contains(room.coordinateFrameID.uuidString))
        XCTAssertEqual(obj.split(separator: "\n").filter { $0.hasPrefix("v ") }.count, room.vertexCount)
        XCTAssertEqual(obj.split(separator: "\n").filter { $0.hasPrefix("f ") }.count, room.triangleCount)
        let csv = try await FieldExport.exportRoom(room, format: .measurements)
        let text = try String(contentsOf: csv, encoding: .utf8)
        XCTAssertTrue(text.contains("'=HYPERLINK(unsafe)")); XCTAssertTrue(text.contains("m2"))
        do { _ = try await FieldExport.exportRoom(room, format: .recognizedModel); XCTFail("No synthesized model when RoomPlan data is absent") } catch { }
        for file in [archive, mesh, csv] { try FileManager.default.removeItem(at: file) }
    }
    func testPeerFramingAndCipherRejectTamperingReplayAndWrongParticipants() throws {
        XCTAssertThrowsError(try PeerProtocol.frame(Data()))
        XCTAssertThrowsError(try PeerProtocol.length(Data([0, 0, 0, 0])))
        XCTAssertThrowsError(try PeerProtocol.length(Data([255, 255, 255, 255])))
        let frame = try PeerProtocol.frame(Data([4, 5, 6])); XCTAssertEqual(try PeerProtocol.length(frame.prefix(4)), 3)
        var a = PeerCipher(), b = PeerCipher(), stranger = PeerCipher()
        let codeA = try a.establish(peerKey: b.publicKey), codeB = try b.establish(peerKey: a.publicKey)
        XCTAssertEqual(codeA, codeB); XCTAssertEqual(codeA.count, 6)
        _ = try stranger.establish(peerKey: a.publicKey)
        let original = try a.seal(Data("verified bytes".utf8))
        var modified = original; modified[modified.count - 1] ^= 1
        XCTAssertThrowsError(try b.open(modified)); XCTAssertThrowsError(try stranger.open(original))
        XCTAssertEqual(try b.open(original), Data("verified bytes".utf8)); XCTAssertThrowsError(try b.open(original))
        XCTAssertEqual(try a.open(b.seal(Data([1, 2, 3]))), Data([1, 2, 3]))
        let second = try a.seal(Data([9])); XCTAssertEqual(try b.open(second), Data([9]))
    }
}
