import XCTest
import PDFKit
import Network
import ActivityKit
import StoreKit
import StoreKitTest
@testable import MagicCuts

nonisolated final class ProMeasurementTests: XCTestCase {
    func testRobustStatisticsAndSilenceHaveDefinedUnits() throws {
        let summary = try XCTUnwrap(MeasurementMath.summary([-80, -70, -60, -50, .nan, .infinity]))
        XCTAssertEqual(summary.count, 4)
        XCTAssertEqual(summary.median, -65)
        XCTAssertEqual(summary.q25, -72.5)
        XCTAssertEqual(summary.q75, -57.5)
        XCTAssertEqual(summary.spread, 15)
        XCTAssertEqual(summary.p95, -51.5, accuracy: 0.0001)
        XCTAssertNil(MeasurementMath.summary([]))
        XCTAssertEqual(try XCTUnwrap(MeasurementMath.rms([3, 4])), sqrt(12.5), accuracy: 0.0001)
        XCTAssertTrue(try XCTUnwrap(MeasurementMath.rms([1e200, -1e200])).isFinite)
        XCTAssertEqual(MeasurementMath.powerLevel(rms: 0), -160)
        XCTAssertEqual(try XCTUnwrap(MeasurementMath.powerLevel(rms: 0.5)), -6.0206, accuracy: 0.0001)
        XCTAssertNil(MeasurementMath.powerLevel(rms: -1))
        XCTAssertNil(MeasurementMath.rms([.nan]))
    }

    func testNorthWrapAndTiltReferencesDoNotUseOrdinarySubtraction() throws {
        XCTAssertEqual(try XCTUnwrap(MeasurementMath.summary([359, 1], kind: .heading)).median, 0, accuracy: 0.0001)
        XCTAssertEqual(MeasurementMath.angularDifference(1, from: 359), 2)
        XCTAssertEqual(MeasurementMath.angularDifference(359, from: 1), -2)
        XCTAssertNil(MeasurementMath.summary([0, 90, 180, 270], kind: .heading), "A directionless circle has no useful center")
        let a = MeasurementPoint(elapsed: 0, value: 30, auxiliary: ["gravityX": 0.5, "gravityY": 0, "gravityZ": -sqrt(0.75)])
        let b = MeasurementPoint(elapsed: 1, value: 30, auxiliary: ["gravityX": -0.5, "gravityY": 0, "gravityZ": -sqrt(0.75)])
        XCTAssertEqual(try XCTUnwrap(MeasurementMath.tiltDifference(a, reference: b)), 60, accuracy: 0.0001)
        XCTAssertNil(MeasurementMath.tiltDifference(MeasurementPoint(elapsed: 0, value: 30), reference: b))
    }

    func testCalibrationRequiresSeparationAndEnoughFreshSamples() {
        XCTAssertEqual(MeasurementMath.signalThreshold(nearby: [-62, -60, -58, -60], away: [-82, -80, -78, -80]), -70)
        XCTAssertNil(MeasurementMath.signalThreshold(nearby: [-68, -63, -58], away: [-70, -64, -59]))
        XCTAssertNil(MeasurementMath.signalThreshold(nearby: [-60, -61], away: [-80, -81, -82]))
        XCTAssertNil(MeasurementMath.signalThreshold(nearby: [0, 127, .nan], away: [-80, -81, -82]))
    }

    func testSpectrumUsesMeasuredCadenceAndRejectsGaps() throws {
        let points = (0 ..< 128).map { index in MeasurementPoint(elapsed: Double(index) / 64, value: sin(2 * .pi * 4 * Double(index) / 64)) }
        let spectrum = try XCTUnwrap(MeasurementMath.spectrum(points))
        XCTAssertEqual(spectrum.sampleRate, 64, accuracy: 0.0001)
        XCTAssertEqual(spectrum.resolution, 0.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(spectrum.dominantFrequency), 4, accuracy: 0.0001)
        var gap = points
        gap[64] = MeasurementPoint(elapsed: points[64].elapsed, value: points[64].value, segment: 1)
        XCTAssertNil(MeasurementMath.spectrum(gap))
        gap = points
        gap[64] = MeasurementPoint(elapsed: points[64].elapsed + 0.01, value: points[64].value)
        XCTAssertNil(MeasurementMath.spectrum(gap))
        XCTAssertNil(MeasurementMath.spectrum(Array(points.prefix(100))))
    }

    func testDisplayedRangeRetainsTheContractAndChartReductionPreservesGaps() {
        XCTAssertEqual(InstrumentKind.bluetooth.displayRange(values: [-66, -60]), -100 ... -40)
        XCTAssertEqual(InstrumentKind.bluetooth.displayRange(values: [-110, -20]), -110 ... -20)
        XCTAssertEqual(MeasurementMath.scaleLabel(0.1, range: 0 ... 0.2), "0.10")
        let points = (0 ..< 100).map { index in MeasurementPoint(elapsed: Double(index), value: index == 24 ? 100 : 1, segment: index < 50 ? 0 : 1) }
        let reduced = MeasurementMath.plotPoints(points, kind: .vibration, limit: 20)
        XCTAssertTrue(reduced.contains { $0.value == 100 })
        XCTAssertTrue(reduced.contains { $0.elapsed == 49 })
        XCTAssertTrue(reduced.contains { $0.elapsed == 50 })
        XCTAssertEqual(reduced.first?.id, points.first?.id, "Plot identity stays stable between renders")
        let compass = [MeasurementPoint(elapsed: 0, value: 359), MeasurementPoint(elapsed: 1, value: 1)]
        let broken = MeasurementMath.plotPoints(compass, kind: .heading, limit: 20)
        XCTAssertNotEqual(broken[0].segment, broken[1].segment)
    }

    func testBaselineCompatibilityIncludesAudioInputAndReferenceFrame() throws {
        let session = InstrumentDemo.session(kind: .sound)
        let metadata = ["audioInput": "microphone-A", "audioSampleRate": "48000"]
        let profile = CalibrationProfile(name: "Quiet room", kind: .sound, sourceID: session.source.id, sourceName: session.source.name, date: .now, points: session.points, summary: try XCTUnwrap(session.summary), metadata: metadata)
        XCTAssertTrue(profile.matches(kind: .sound, source: .phone, metadata: metadata))
        XCTAssertFalse(profile.matches(kind: .sound, source: .phone, metadata: ["audioInput": "microphone-B", "audioSampleRate": "48000"]))
        XCTAssertFalse(profile.matches(kind: .sound, source: .phone, metadata: ["audioInput": "microphone-A", "audioSampleRate": "44100"]))
        XCTAssertFalse(profile.matches(kind: .bluetooth, source: .phone, metadata: metadata))
    }

    func testUnknownLogicForAllAnyAndMinimumCounts() {
        func outcome(_ values: [Bool?], all: Bool = true, minimum: Int? = nil) -> Bool? {
            WorkflowOutcome(readings: values.map { WorkflowReading(id: UUID(), title: "Condition", value: nil, unit: "", passed: $0, detail: "") }, requiresAll: all, minimumMatches: minimum).passed
        }
        XCTAssertNil(outcome([true, nil]))
        XCTAssertEqual(outcome([false, nil]), false)
        XCTAssertEqual(outcome([true, nil], all: false), true)
        XCTAssertNil(outcome([false, nil], all: false))
        XCTAssertEqual(outcome([false, false], all: false), false)
        XCTAssertEqual(outcome([true, true, nil], minimum: 2), true)
        XCTAssertEqual(outcome([true, false, nil], minimum: 3), false)
        XCTAssertNil(outcome([true, false, nil], minimum: 2))
        XCTAssertNil(outcome([], minimum: 1))
    }
}

nonisolated final class ProArchiveTests: XCTestCase {
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-ProTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testArchivesRoundTripAndReferencedSessionsCannotDisappear() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root)
        let session = InstrumentDemo.session()
        _ = try await archive.saveSession(session)
        let read = try await archive.loadSession(session.id)
        XCTAssertEqual(read, session)
        var report = FieldReport(title: "Desk comparison"); report.sessionIDs = [session.id]
        _ = try await archive.saveReport(report)
        do { _ = try await archive.deleteSession(session.id); XCTFail("Reports must not lose an attachment silently") } catch { }
        let retained = try await archive.loadSession(session.id)
        XCTAssertEqual(retained.id, session.id)
        _ = try await archive.deleteReport(report.id)
        _ = try await archive.deleteSession(session.id)
        let empty = try await archive.loadIndex()
        XCTAssertTrue(empty.sessions.isEmpty)
    }

    func testConcurrentArchiveWritersPreserveEachOthersChanges() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let first = InstrumentArchive(root: root), second = InstrumentArchive(root: root)
        let a = DeviceGroup(name: "Office", deviceIDs: [UUID()])
        let b = DeviceGroup(name: "Workshop", deviceIDs: [UUID()])
        async let x = first.saveGroup(a)
        async let y = second.saveGroup(b)
        _ = try await (x, y)
        let index = try await first.loadIndex()
        XCTAssertEqual(Set(index.groups.map(\.id)), Set([a.id, b.id]))
    }

    func testMalformedIndexIsNotOverwrittenByASave() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let corrupt = Data("corrupt index".utf8)
        let indexURL = root.appendingPathComponent("index.json")
        try corrupt.write(to: indexURL)
        let archive = InstrumentArchive(root: root)
        let session = InstrumentDemo.session()
        do { _ = try await archive.saveSession(session); XCTFail("A corrupt library needs a visible error") } catch { }
        XCTAssertEqual(try Data(contentsOf: indexURL), corrupt)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(session.id.uuidString + ".json").path), "A failed save must not leave an unindexed recording")
    }

    func testRecoveryDraftDoesNotBecomeACompletedSessionUntilSaved() async throws {
        let root = try folder(); defer { try? FileManager.default.removeItem(at: root) }
        let archive = InstrumentArchive(root: root)
        let session = InstrumentDemo.session()
        try await archive.saveDraft(session)
        let drafts = try await archive.loadDrafts(), index = try await archive.loadIndex()
        XCTAssertEqual(drafts, [session]); XCTAssertTrue(index.sessions.isEmpty)
        _ = try await archive.saveSession(session)
        try await archive.discardDraft(session.id)
        let after = try await archive.loadDrafts(), completed = try await archive.loadIndex()
        XCTAssertTrue(after.isEmpty); XCTAssertEqual(completed.sessions.map(\.id), [session.id])
    }

    func testOlderProIndexLoadsAdditiveReportField() throws {
        let data = Data("{\"version\":1,\"sessions\":[],\"profiles\":[],\"workflows\":[],\"groups\":[]}".utf8)
        XCTAssertTrue(try JSONDecoder().decode(ProLibraryIndex.self, from: data).reports.isEmpty)
    }
}

nonisolated final class ProCaptureTests: XCTestCase {
    @MainActor func testConnectionProbeUsesRealHTTPAndStopsAtItsRequestLimit() async throws {
        let endpoint = try LocalProbeEndpoint(status: "200 OK")
        let url = try await endpoint.start()
        defer { endpoint.stop() }
        let engine = InstrumentEngine()
        defer { engine.stop() }
        await engine.start(kind: .network, source: MeasurementSource(id: url.absoluteString, name: "Loopback", endpoint: url.absoluteString))
        for _ in 0 ..< 180 where engine.phase != .finished { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(engine.phase, .finished)
        XCTAssertEqual(engine.completedRequests, 20)
        XCTAssertEqual(engine.failedRequests, 0)
        XCTAssertEqual(engine.points.count, 20)
        XCTAssertTrue(engine.points.allSatisfy { $0.value > 0 && $0.auxiliary["httpStatus"] == 200 })
        XCTAssertFalse(engine.demonstration)

        let redirect = try LocalProbeEndpoint(status: "302 Found", location: url)
        let redirectURL = try await redirect.start()
        defer { redirect.stop() }
        await engine.start(kind: .network, source: MeasurementSource(id: redirectURL.absoluteString, name: "Redirect", endpoint: redirectURL.absoluteString))
        for _ in 0 ..< 30 where engine.failedRequests == 0 { try await Task.sleep(for: .milliseconds(100)) }
        engine.stop()
        XCTAssertGreaterThan(engine.failedRequests, 0)
        XCTAssertEqual(engine.completedRequests, 0, "A redirect must not silently test a different endpoint")
        XCTAssertTrue(engine.points.isEmpty)
        XCTAssertTrue(engine.events.contains { $0.text.contains("HTTP 302") })
    }

    @MainActor func testLiveActivityPublishesPausesAndEndsThroughActivityKit() async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { throw XCTSkip("Enable Live Activities for this runtime acceptance check") }
        await SessionLiveActivity.endAbandoned()
        let oldSetting = UserDefaults.standard.object(forKey: "showSessionLiveActivity")
        UserDefaults.standard.set(true, forKey: "showSessionLiveActivity")
        defer { UserDefaults.standard.set(oldSetting, forKey: "showSessionLiveActivity") }
        let sessionID = UUID(), controller = SessionLiveActivity()
        defer { controller.end() }
        XCTAssertNil(controller.start(id: sessionID, kind: .bluetooth, source: MeasurementSource(id: "activity-test", name: "Test sensor")))
        let activityID = try XCTUnwrap(Activity<SessionActivityAttributes>.activities.first { $0.attributes.sessionID == sessionID }?.id)
        let point = MeasurementPoint(elapsed: 1, value: -63)
        controller.update(kind: .bluetooth, point: point, phase: .running, count: 3, force: true)
        for _ in 0 ..< 50 {
            if Activity<SessionActivityAttributes>.activities.first(where: { $0.id == activityID })?.content.state.sampleCount == 3 { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(Activity<SessionActivityAttributes>.activities.first(where: { $0.id == activityID })?.content.state.value, "-63")
        controller.update(kind: .bluetooth, point: point, phase: .paused, count: 3, force: true)
        for _ in 0 ..< 50 {
            if Activity<SessionActivityAttributes>.activities.first(where: { $0.id == activityID })?.content.state.status == "Paused" { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertEqual(Activity<SessionActivityAttributes>.activities.first(where: { $0.id == activityID })?.content.state.status, "Paused")
        controller.end()
        for _ in 0 ..< 50 {
            if !Activity<SessionActivityAttributes>.activities.contains(where: { $0.id == activityID }) { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(Activity<SessionActivityAttributes>.activities.contains(where: { $0.id == activityID }))
    }

    @MainActor func testWorkflowWindowStartsAfterRadioReadiness() async throws {
        let radio = CaptureRadio()
        let source = MeasurementSource(id: radio.id.uuidString, name: "Test sensor", deviceID: radio.id)
        let task = Task { try await WorkflowRunner.measure(.bluetooth, source: source, seconds: 1, radio: radio) }
        try await Task.sleep(for: .milliseconds(250))
        radio.ready(); radio.send(-60)
        try await Task.sleep(for: .milliseconds(850))
        radio.send(-80)
        let value = try await task.value
        XCTAssertEqual(value, -70, "Initialization must not shorten the measurement window")
        XCTAssertTrue(radio.cancelled)
    }

    @MainActor func testPauseResumeAndCancelledCallbacksKeepDistinctSegments() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-CaptureTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let oldSetting = UserDefaults.standard.object(forKey: "showSessionLiveActivity")
        UserDefaults.standard.set(false, forKey: "showSessionLiveActivity")
        defer { UserDefaults.standard.set(oldSetting, forKey: "showSessionLiveActivity") }
        let archive = InstrumentArchive(root: root), radio = CaptureRadio()
        let engine = InstrumentEngine(archive: archive)
        let source = MeasurementSource(id: radio.id.uuidString, name: "Test sensor", deviceID: radio.id)
        await engine.start(kind: .bluetooth, source: source, radio: radio)
        radio.ready(); radio.send(-60)
        try await Task.sleep(for: .milliseconds(30))
        engine.beginRecording(); radio.send(-61); radio.send(-62)
        try await Task.sleep(for: .milliseconds(30))
        engine.pause()
        let paused = engine.recordingCount
        radio.send(-1)
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(engine.recordingCount, paused)
        await engine.resume(radio: radio)
        radio.ready(); radio.send(-70); radio.send(-72)
        try await Task.sleep(for: .milliseconds(30))
        engine.stop()
        let session = try engine.finishRecording(title: "Interrupted measurement")
        XCTAssertEqual(session.points.count, 4)
        XCTAssertEqual(Set(session.points.map(\.segment)).count, 2)
        XCTAssertEqual(session.id, try engine.finishRecording(title: "Retry save").id)
        XCTAssertTrue(session.events.contains { $0.text.contains("Resumed") })
        XCTAssertTrue(zip(session.points, session.points.dropFirst()).allSatisfy { $0.elapsed <= $1.elapsed })
        _ = try await archive.saveSession(session)
        try await engine.discardRecording()
        let drafts = try await archive.loadDrafts()
        XCTAssertTrue(drafts.isEmpty)
        XCTAssertFalse(engine.recording)
        XCTAssertTrue(radio.cancelled)
    }

    @MainActor func testGroupUsesOneWindowAndMissingMembersStayUnknown() async throws {
        let radio = CaptureRadio(), missing = UUID()
        let devices = [DeviceInfo(id: radio.id.uuidString, name: "Observed", rssi: -70), DeviceInfo(id: missing.uuidString, name: "Missing", rssi: -70)]
        let group = DeviceGroup(name: "Pair", deviceIDs: [radio.id, missing])
        let task = Task { try await WorkflowRunner.evaluate(group, devices: devices, radio: radio, duration: .milliseconds(90)) }
        try await Task.sleep(for: .milliseconds(20))
        radio.ready(); radio.send(-60); radio.send(-62)
        let result = try await task.value
        XCTAssertEqual(radio.sessionCount, 1)
        XCTAssertEqual(result.readings[0].value, -61)
        XCTAssertNil(result.readings[1].passed)
        XCTAssertNil(result.passed)
        XCTAssertTrue(radio.cancelled)
    }

    @MainActor func testGroupCancellationNeverReturnsAPartialSuccess() async throws {
        let radio = CaptureRadio()
        let devices = [DeviceInfo(id: radio.id.uuidString, name: "Observed", rssi: -70)]
        let task = Task { try await WorkflowRunner.evaluate(DeviceGroup(name: "One", deviceIDs: [radio.id]), devices: devices, radio: radio) }
        try await Task.sleep(for: .milliseconds(20))
        radio.ready(); radio.send(-50); radio.send(-51); task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation must remain cancellation") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertTrue(radio.cancelled)
    }
}

@MainActor
private final class CaptureRadio: RadioScanning {
    let id = UUID()
    var cancelled = false
    var sessionCount = 0
    private var continuation: AsyncThrowingStream<RadioEvent, Error>.Continuation?
    func session(services: [String]) -> RadioSession {
        sessionCount += 1; cancelled = false
        let stream = AsyncThrowingStream<RadioEvent, Error> { continuation = $0 }
        return RadioSession(events: stream) { self.cancelled = true; self.continuation?.finish(throwing: CancellationError()) }
    }
    func ready() { continuation?.yield(.ready(.now)) }
    func stop() { cancelled = true; continuation?.finish(throwing: CancellationError()) }
    func send(_ value: Int) { continuation?.yield(.device(RadioDevice(id: id, name: "Test", rssi: value, services: [], lastSeen: .now))) }
}

nonisolated final class ProReportTests: XCTestCase {
    @MainActor func testExportsContainAllReadingsAndPaginatedNotesWithoutEndpointQueries() throws {
        var session = InstrumentDemo.session(kind: .network)
        session.source = MeasurementSource(id: "https://example.test/health?token=private-test-marker", name: "example.test", endpoint: "https://example.test/health?token=private-test-marker")
        session.events = (0 ..< 80).map { CaptureEvent(elapsed: Double($0), text: "Observation \($0): A measured change in the connection was noted during this test.") }
        let files = try SessionReport.export(session)
        let json = try XCTUnwrap(files.first { $0.url.pathExtension == "json" })
        let text = try String(contentsOf: json.url, encoding: .utf8)
        XCTAssertFalse(text.contains("private-test-marker"))
        XCTAssertTrue(text.contains("https://example.test/health") || text.contains("https:\\/\\/example.test\\/health"))
        let csv = try String(contentsOf: XCTUnwrap(files.first { $0.url.pathExtension == "csv" }).url, encoding: .utf8)
        XCTAssertEqual(csv.components(separatedBy: "\r\n").count, session.points.count + 2)
        let pdf = try XCTUnwrap(PDFDocument(url: XCTUnwrap(files.first { $0.url.pathExtension == "pdf" }).url))
        XCTAssertGreaterThan(pdf.pageCount, 1)
        XCTAssertTrue(try XCTUnwrap(pdf.string).contains("Observation 79"))
        var report = FieldReport(title: "Connection field visit")
        report.sessionIDs = [session.id]; report.steps = [FieldProtocolStep(title: "Verify the endpoint", complete: true)]
        report.notes = "Checked by the operator; response times are not packet loss."
        let reportFiles = try FieldReportExport.export(report, sessions: [session])
        let combined = try XCTUnwrap(PDFDocument(url: XCTUnwrap(reportFiles.first { $0.url.pathExtension == "pdf" }).url))
        XCTAssertGreaterThan(combined.pageCount, pdf.pageCount)
        XCTAssertTrue(try XCTUnwrap(combined.string).contains("Verify the endpoint"))
    }
}

nonisolated final class ProPurchaseTests: XCTestCase {
    @MainActor func testPurchaseRestoreRefundAndPendingApprovalUseVerifiedEntitlements() async throws {
        let store = try SKTestSession(configurationFileNamed: "MagicCutsPro")
        store.resetToDefaultState(); store.clearTransactions(); store.disableDialogs = true
        defer { store.clearTransactions(); store.resetToDefaultState() }
        guard store.disableDialogs else {
            XCTFail("StoreKit Test could not configure its local environment. Stop before purchase; run the StoreKit scheme in a working Xcode test session.")
            return
        }
        XCTAssertFalse(AppRuntime.hasDevelopmentProAccess, "Purchase tests must never use development access")
        let access = ProAccess()
        await access.load()
        XCTAssertEqual(access.state, .locked)
        XCTAssertNotNil(access.product)
        do { try await ProAccess.require(); XCTFail("Every action must require Pro") } catch { }
        await access.purchase()
        XCTAssertTrue(access.unlocked, access.message ?? "Purchase must unlock Pro")
        try await ProAccess.require()
        let restored = ProAccess(observeTransactions: false)
        await restored.restore()
        XCTAssertTrue(restored.unlocked)
        let transaction = try XCTUnwrap(store.allTransactions().first)
        try store.refundTransaction(identifier: transaction.identifier)
        for _ in 0 ..< 40 where access.unlocked { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertEqual(access.state, .locked, "The transaction listener must remove access after a refund")
        do { try await ProAccess.require(); XCTFail("Refunded actions must be locked") } catch { }

        store.clearTransactions(); store.askToBuyEnabled = true
        await access.purchase()
        XCTAssertFalse(access.unlocked)
        XCTAssertTrue(access.message?.contains("awaiting approval") == true)
        let pending = try XCTUnwrap(store.allTransactions().first)
        try store.approveAskToBuyTransaction(identifier: pending.identifier)
        for _ in 0 ..< 40 where !access.unlocked { try await Task.sleep(for: .milliseconds(100)) }
        XCTAssertTrue(access.unlocked, "An approved pending purchase must unlock without relaunching")
    }
}

// Mutable listener state is confined to its serial callback queue.
nonisolated private final class LocalProbeEndpoint: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "MagicCuts.tests.loopback")
    private var ready: CheckedContinuation<URL, any Error>?

    init(status: String, location: URL? = nil) throws {
        listener = try NWListener(using: .tcp, on: .any)
        let redirect = location.map { "Location: \($0.absoluteString)\r\n" } ?? ""
        let response = Data("HTTP/1.1 \(status)\r\n\(redirect)Content-Length: 0\r\nConnection: close\r\n\r\n".utf8)
        listener.newConnectionHandler = { [queue] connection in
            connection.start(queue: queue)
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                guard error == nil, let data, String(decoding: data, as: UTF8.self).hasPrefix("HEAD ") else { connection.cancel(); return }
                connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self, let ready = self.ready else { return }
            switch state {
            case .ready:
                self.ready = nil
                guard let port = self.listener.port, let url = URL(string: "http://127.0.0.1:\(port.rawValue)/probe") else {
                    ready.resume(throwing: URLError(.badURL)); return
                }
                ready.resume(returning: url)
            case .failed(let error): self.ready = nil; ready.resume(throwing: error)
            default: break
            }
        }
    }

    func start() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { self.ready = continuation; self.listener.start(queue: self.queue) }
        }
    }
    func stop() { listener.cancel() }
}
