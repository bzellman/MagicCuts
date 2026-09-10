import XCTest
import Network
import Synchronization
@testable import MagicCuts

nonisolated final class FieldNetworkTests: XCTestCase {
    func testActualRequestTransactionsReuseConnectionAndBoundResponseBytes() async throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Loopback HTTP fixture is a simulator protocol test")
        #else
        let server = try LocalHTTPFixture(); try await server.start(); defer { server.stop() }
        let client = NetworkProbeClient(); defer { client.close() }
        let first = await client.request(server.url("ok"), mode: .latency, elapsed: 0)
        let second = await client.request(server.url("ok"), mode: .latency, elapsed: 1)
        XCTAssertTrue(first.succeeded, first.error ?? "No HTTP success")
        XCTAssertTrue(second.succeeded, second.error ?? "No HTTP success")
        XCTAssertFalse(first.transactions.isEmpty); XCTAssertFalse(second.transactions.isEmpty)
        XCTAssertTrue(second.transactions.contains { $0.reused }, "Persistent HTTP should expose reuse rather than fabricated DNS/TLS timing")
        XCTAssertFalse(first.verifiedCellular)
        XCTAssertTrue(second.transactions.allSatisfy { $0.phases.allSatisfy(\.isValid) })
        let error = await client.request(server.url("error"), mode: .latency, elapsed: 2)
        XCTAssertEqual(error.status, 503); XCTAssertFalse(error.succeeded)
        let redirect = await client.request(server.url("redirect"), mode: .latency, elapsed: 3)
        XCTAssertEqual(redirect.status, 302); XCTAssertFalse(redirect.succeeded)
        let hugeHead = await client.request(server.url("too-large"), mode: .latency, elapsed: 4)
        XCTAssertTrue(hugeHead.succeeded, "HEAD does not download the declared representation")
        let huge = await client.request(server.url("too-large"), mode: .download, elapsed: 5)
        XCTAssertFalse(huge.succeeded); XCTAssertTrue(huge.error?.contains("byte limit") == true)
        let upload = await client.request(server.url("ok"), mode: .upload, elapsed: 6)
        XCTAssertTrue(upload.succeeded, upload.error ?? "Upload failed")
        XCTAssertEqual(upload.sentBytes, 2 * 1024 * 1024)
        #endif
    }
    func testCanceledRequestSettlesPromptlyWithoutPersistingEndpointQuery() async throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("Loopback HTTP fixture is a simulator protocol test")
        #else
        let server = try LocalHTTPFixture(); try await server.start(); defer { server.stop() }
        let client = NetworkProbeClient(); defer { client.close() }
        let task = Task { await client.request(server.url("delay?private=never-save-me"), mode: .latency, elapsed: 0) }
        try await Task.sleep(for: .milliseconds(150))
        let time = ContinuousClock.now; task.cancel()
        let canceled = await task.value
        XCTAssertLessThan(time.duration(to: .now).secondsValue, 2)
        XCTAssertFalse(canceled.succeeded)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(canceled), as: UTF8.self).contains("never-save-me"))
        #endif
    }
    func testModernTCPPeerHandshakeAndVerifiedPayloadCrossTheNetwork() async throws {
        let parameters = PeerProtocol.tcpParameters
        let listener = try NetworkListener<TCP>(using: parameters).newConnectionLimit(1)
        let ready = AsyncThrowingStream<UInt16, Error>.makeStream()
        let receivedCode = Mutex<String?>(nil)
        listener.onStateUpdate { listener, state in
            if case .ready = state, let port = listener.port { ready.continuation.yield(port.rawValue); ready.continuation.finish() }
            if case .failed(let error) = state { ready.continuation.finish(throwing: error) }
        }
        let hosting = Task {
            try await listener.run { connection in
                let peer = PeerLink(connection: connection)
                try await peer.sendHello()
                let code = try await peer.receiveHello(); receivedCode.withLock { $0 = code }
                let message = try await peer.receive()
                guard message.kind == .upload, let data = message.payload else { throw PeerError.invalidMessage }
                try await peer.send(PeerMessage(kind: .uploaded, replyTo: message.id, digest: PeerProtocol.digest(data)))
            }
        }
        defer { hosting.cancel() }
        try await PeerDeadline.run(seconds: 6) {
            var iterator = ready.stream.makeAsyncIterator()
            guard let port = try await iterator.next() else { throw PeerError.ended }
            let connection = NetworkConnection<TCP>(to: NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!), using: PeerProtocol.tcpParameters)
            let peer = PeerLink(connection: connection)
            try await peer.sendHello(); let code = try await peer.receiveHello()
            let bytes = PeerProtocol.testData(), message = PeerMessage(kind: .upload, payload: bytes)
            try await peer.send(message)
            let response = try await peer.receive()
            XCTAssertEqual(response.replyTo, message.id); XCTAssertEqual(response.digest, PeerProtocol.digest(bytes))
            XCTAssertEqual(receivedCode.withLock { $0 }, code)
            await peer.stop()
        }
    }
    @MainActor func testProductionPeerControllersDiscoverVerifyRestartAndKeepCompletedResults() async throws {
        let host = PeerInstrument(), client = PeerInstrument()
        defer { client.stop(); host.stop() }
        host.host(); client.browse()
        try await eventually { client.peers.contains { $0.name == host.advertisedName } }
        let peer = try XCTUnwrap(client.peers.first { $0.name == host.advertisedName })
        client.connect(peer)
        try await eventually { host.verificationCode != nil && client.verificationCode != nil }
        XCTAssertEqual(host.verificationCode, client.verificationCode)
        host.confirm(); client.confirm()
        try await eventually { host.connected && client.connected }
        client.benchmark(); client.stopBenchmark(); client.benchmark()
        try await eventually(seconds: 20) { !client.testing }
        let capture = try XCTUnwrap(client.capture)
        XCTAssertTrue(capture.isValid)
        XCTAssertEqual(capture.samples.count, 20)
        XCTAssertEqual(capture.samples.filter { $0.values["rttMS"] == nil }.count, 0)
        XCTAssertEqual(capture.metrics.filter { $0.unit == "Mbit/s" }.count, 2)
        XCTAssertEqual(capture.metadata["completion"], "Benchmark complete · 4 MiB transferred and verified")
        client.stop()
        XCTAssertEqual(client.capture?.metadata["completion"], capture.metadata["completion"])
    }
    @MainActor private func eventually(seconds: Double = 10, _ predicate: () -> Bool) async throws {
        let began = ContinuousClock.now
        while !predicate() {
            guard began.duration(to: .now).secondsValue < seconds else { throw PeerError.timeout }
            try await Task.sleep(for: .milliseconds(100))
        }
    }
    func testTransactionTimelineKeepsTLSNestedAndUnknownPhasesAbsent() {
        let origin = Date()
        let times = RequestMetricTimes(connectStart: origin, connectEnd: origin.addingTimeInterval(0.12),
            tlsStart: origin.addingTimeInterval(0.04), tlsEnd: origin.addingTimeInterval(0.12),
            requestStart: origin.addingTimeInterval(0.13), requestEnd: origin.addingTimeInterval(0.14),
            responseStart: origin.addingTimeInterval(0.2), responseEnd: origin.addingTimeInterval(0.21))
        let phases = times.phases(relativeTo: origin)
        XCTAssertFalse(phases.contains { $0.id == "dns" })
        let connect = phases.first { $0.id == "connect" }!, tls = phases.first { $0.id == "tls" }!
        XCTAssertGreaterThanOrEqual(tls.start, connect.start); XCTAssertLessThanOrEqual(tls.end, connect.end)
        XCTAssertEqual(phases.first { $0.id == "wait" }!.duration, 0.06, accuracy: 0.00001)
    }
}

/// A real bounded loopback HTTP/1.1 participant, with keep-alive and deliberately incomplete responses.
nonisolated private final class LocalHTTPFixture: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "MagicCuts.HTTPFixture")
    private let connections = Mutex<[UUID: NWConnection]>([:])
    init() throws { listener = try NWListener(using: .tcp, on: .any) }
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumed = Mutex(false)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if resumed.withLock({ value in if value { return false }; value = true; return true }) { continuation.resume() }
                case .failed(let error):
                    if resumed.withLock({ value in if value { return false }; value = true; return true }) { continuation.resume(throwing: error) }
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { connection.cancel(); return }
                let id = UUID(); self.connections.withLock { $0[id] = connection }
                connection.start(queue: self.queue); self.receive(connection, id: id, previous: Data())
            }
            listener.start(queue: queue)
        }
    }
    func url(_ path: String) -> URL { URL(string: "http://127.0.0.1:\(listener.port!.rawValue)/\(path)")! }
    func stop() {
        listener.cancel()
        connections.withLock { value in for connection in value.values { connection.cancel() }; value = [:] }
    }
    private func receive(_ connection: NWConnection, id: UUID, previous: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, complete, error in
            guard let self else { return }
            guard !complete, error == nil, let data else { connection.cancel(); self.connections.withLock { $0[id] = nil }; return }
            let all = previous + data
            guard all.count <= 3 * 1024 * 1024 else { connection.cancel(); return }
            guard let split = all.range(of: Data("\r\n\r\n".utf8)) else { self.receive(connection, id: id, previous: all); return }
            let header = String(decoding: all[..<split.lowerBound], as: UTF8.self)
            let lines = header.components(separatedBy: "\r\n")
            let length = lines.first { $0.lowercased().hasPrefix("content-length:") }.flatMap { Int($0.split(separator: ":").last!.trimmingCharacters(in: .whitespaces)) } ?? 0
            guard all.count >= split.upperBound + length else { self.receive(connection, id: id, previous: all); return }
            let request = lines[0].split(separator: " ")
            guard request.count >= 2 else { connection.cancel(); return }
            let path = request[1], head = request[0] == "HEAD"
            if path.hasPrefix("/delay") { return }
            let status = path == "/error" ? "503 Unavailable" : path == "/redirect" ? "302 Found" : "200 OK"
            let body = head ? Data() : path == "/too-large" ? Data(repeating: 65, count: 4096) : Data("ok".utf8)
            let declared = path == "/too-large" ? 9 * 1024 * 1024 : head ? 2 : body.count
            let extra = path == "/redirect" ? "Location: /ok\r\n" : ""
            let response = Data("HTTP/1.1 \(status)\r\nContent-Length: \(declared)\r\nConnection: keep-alive\r\nContent-Type: application/octet-stream\r\n\(extra)\r\n".utf8) + body
            connection.send(content: response, completion: .contentProcessed { [weak self] error in
                if error == nil { self?.receive(connection, id: id, previous: Data()) }
            })
        }
    }
}
