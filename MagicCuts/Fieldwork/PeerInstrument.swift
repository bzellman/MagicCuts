import Foundation
import Observation
import Network

nonisolated struct PeerDiscovery: Identifiable, Sendable {
    var id: String
    var name: String
    var endpoint: NWEndpoint
}

@MainActor @Observable
final class PeerInstrument {
    private(set) var status = "Choose one device to host, then find it from the other"
    private(set) var peers: [PeerDiscovery] = []
    private(set) var hosting = false
    private(set) var browsing = false
    private(set) var connected = false
    private(set) var peerName = "Participating device"
    private(set) var advertisedName = ""
    private(set) var verificationCode: String?
    private(set) var locallyConfirmed = false
    private(set) var remotelyConfirmed = false
    private(set) var testing = false
    private(set) var testStatus = "No benchmark yet"
    private(set) var samples: [FieldSample] = []
    private(set) var transferMetrics: [FieldMetric] = []
    private(set) var failure: String?
    private(set) var transportTitle = "Local peer"
    private(set) var pathDescription = "Path unavailable"
    let nearby = NearbyInstrument()
    let aware = WiFiAwareInstrument()
    @ObservationIgnored var positionProvider: ((Date) -> RoomPlacement?)?
    @ObservationIgnored private var listener: NetworkListener<TCP>?
    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var listeningTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var verificationTimeout: Task<Void, Never>?
    @ObservationIgnored private var testTask: Task<Void, Never>?
    @ObservationIgnored private var pathTask: Task<Void, Never>?
    @ObservationIgnored private var link: PeerLink?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var testDate = Date()
    @ObservationIgnored private var benchmarkID = UUID()
    @ObservationIgnored private var receivedTimes: [ContinuousClock.Instant] = []
    @ObservationIgnored private var remoteTransferActive = false
    @ObservationIgnored private var pending: [UUID: PendingReply] = [:]
    private struct PendingReply {
        let continuation: CheckedContinuation<PeerMessage, Error>
        let timeout: Task<Void, Never>
    }

    init() {
        nearby.onToken = { [weak self] data in
            guard let self, self.connected, let link = self.link else { throw PeerError.ended }
            try await link.send(PeerMessage(kind: .nearbyToken, payload: data))
        }
    }
    func host() {
        stop(); resetForConnection(); hosting = true; status = "Preparing local host"
        let token = generation
        advertisedName = "MagicCuts \(UUID().uuidString.prefix(4))"
        do {
            let parameters = PeerProtocol.tcpParameters
            let listener = try NetworkListener<TCP>(for: .bonjour(name: advertisedName, type: PeerProtocol.service), using: parameters)
                .newConnectionLimit(1)
            self.listener = listener
            listener.onStateUpdate { [weak self] _, state in
                guard let self, self.generation == token else { return }
                if case .ready = state { self.status = "Host ready · \(self.advertisedName). Find this name from the other device." }
                if case .failed(let error) = state { self.failure = "Local hosting failed: \(error.localizedDescription)"; self.hosting = false }
                if case .waiting(let error) = state { self.status = "Waiting for local network access: \(error.localizedDescription)" }
            }
            listeningTask = Task { [weak self] in
                do {
                    try await listener.run { [weak self] connection in
                        guard let self, self.generation == token, self.link == nil else { return }
                        self.begin(connection, name: "the other device", transport: "Local peer")
                        await self.connectionTask?.value
                    }
                } catch { guard let self, self.generation == token, !Task.isCancelled else { return }; self.failure = error.localizedDescription; self.hosting = false }
            }
        } catch { failure = error.localizedDescription; hosting = false }
    }
    func browse() {
        stop(); resetForConnection(); browsing = true; status = "Finding MagicCuts hosts"
        let token = generation
        let parameters = NWParameters.tcp; parameters.includePeerToPeer = true; parameters.prohibitedInterfaceTypes = [.cellular]
        let browser = NWBrowser(for: .bonjour(type: PeerProtocol.service, domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] state in
            let problem: String?
            switch state { case .failed(let error), .waiting(let error): problem = error.localizedDescription; default: problem = nil }
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if let problem { self.failure = "Discovery is waiting for local network access: \(problem)" }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let peers = results.compactMap { result -> PeerDiscovery? in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return PeerDiscovery(id: result.endpoint.debugDescription, name: String(name.prefix(100)), endpoint: result.endpoint)
            }.sorted { $0.name < $1.name }
            Task { @MainActor [weak self] in guard self?.generation == token else { return }; self?.peers = Array(peers.prefix(40)) }
        }
        browser.start(queue: .main)
    }
    func connect(_ peer: PeerDiscovery) {
        guard link == nil else { return }
        browser?.cancel(); browser = nil; browsing = false
        let parameters = PeerProtocol.tcpParameters
        begin(NetworkConnection<TCP>(to: peer.endpoint, using: parameters), name: peer.name, transport: "Local peer")
    }
    func startAware(host: Bool) {
        stop(); resetForConnection(); transportTitle = "Wi-Fi Aware"
        let token = generation
        aware.onConnection = { [weak self] connection, name in
            guard let self, self.generation == token, self.link == nil else { return }
            self.begin(connection, name: name, transport: "Wi-Fi Aware")
            await self.connectionTask?.value
        }
        if host { aware.host() } else { aware.browse() }
    }
    private func resetForConnection() {
        failure = nil; samples = []; transferMetrics = []; testStatus = "No benchmark yet"
        pathDescription = "Path unavailable"; receivedTimes = []; remoteTransferActive = false
        verificationCode = nil; locallyConfirmed = false; remotelyConfirmed = false
    }
    private func begin(_ connection: NetworkConnection<TCP>, name: String, transport: String) {
        guard link == nil else { return }
        let token = generation, link = PeerLink(connection: connection)
        self.link = link; peerName = name; transportTitle = transport; status = "Connecting securely"
        connectionTask = Task { [weak self] in
            do {
                let code = try await PeerDeadline.run(seconds: 12) {
                    try await link.sendHello(); return try await link.receiveHello()
                }
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.verificationCode = code; self.status = "Compare this code on both devices"
                self.verificationTimeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(90)) } catch { return }
                    guard let self, self.generation == token, !self.connected else { return }
                    self.failure = "Connection confirmation timed out. Connect again when both devices are ready."; self.stop()
                }
                while !Task.isCancelled {
                    let message = try await link.receive()
                    guard self.generation == token else { return }
                    try await self.handle(message, link: link)
                }
            } catch {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.failure = error.localizedDescription; self.stop()
            }
        }
    }
    func confirm() {
        guard verificationCode != nil, !locallyConfirmed, let link else { return }
        locallyConfirmed = true; updateConfirmation()
        let token = generation
        Task { [weak self] in
            do { try await link.send(PeerMessage(kind: .confirmed)) }
            catch { guard self?.generation == token else { return }; self?.failure = error.localizedDescription; self?.stop() }
        }
    }
    private func updateConfirmation() {
        connected = locallyConfirmed && remotelyConfirmed
        status = connected ? "Connected to \(peerName)" : locallyConfirmed ? "Waiting for confirmation on the other device" : "Compare this code on both devices"
        guard connected else { return }
        verificationTimeout?.cancel(); verificationTimeout = nil
        nearby.positionProvider = positionProvider
        aware.positionProvider = positionProvider
        let token = generation
        pathTask?.cancel()
        pathTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == token, let link = self.link else { return }
                if let path = await link.path() {
                    self.pathDescription = path.usesInterfaceType(.wifi) ? "Wi-Fi interface" : path.usesInterfaceType(.wiredEthernet) ? "Wired interface" : "Other interface"
                    if self.transportTitle == "Wi-Fi Aware" { await self.aware.observe(path) }
                }
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }
    private func handle(_ message: PeerMessage, link: PeerLink) async throws {
        let now = ContinuousClock.now
        receivedTimes.removeAll { $0.duration(to: now).secondsValue > 5 }; receivedTimes.append(now)
        guard receivedTimes.count <= 100 else { throw PeerError.invalidMessage }
        if message.kind == .confirmed { remotelyConfirmed = true; updateConfirmation(); return }
        guard connected else { throw PeerError.unconfirmed }
        if let reply = message.replyTo {
            if let pending = pending.removeValue(forKey: reply) { pending.timeout.cancel(); pending.continuation.resume(returning: message) }
            return
        }
        switch message.kind {
        case .ping: try await link.send(PeerMessage(kind: .pong, replyTo: message.id))
        case .upload:
            guard !remoteTransferActive, let data = message.payload else { throw PeerError.invalidMessage }
            remoteTransferActive = true; defer { remoteTransferActive = false }
            let digest = await Task.detached(priority: .userInitiated) { PeerProtocol.digest(data) }.value
            try await link.send(PeerMessage(kind: .uploaded, replyTo: message.id, digest: digest))
        case .download:
            guard !remoteTransferActive else { throw PeerError.invalidMessage }
            remoteTransferActive = true; defer { remoteTransferActive = false }
            let data = await Task.detached(priority: .userInitiated) { PeerProtocol.testData() }.value
            try await link.send(PeerMessage(kind: .downloaded, replyTo: message.id, payload: data, digest: PeerProtocol.digest(data)))
        case .nearbyToken: if let payload = message.payload { try nearby.receiveToken(payload) }
        case .nearbyStop: nearby.stop(); status = "Peer stopped ranging. Network connection remains available."
        default: throw PeerError.invalidMessage
        }
    }
    private func request(_ message: PeerMessage) async throws -> PeerMessage {
        guard connected, let link else { throw PeerError.ended }
        return try await withCheckedThrowingContinuation { continuation in
            let timeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(8)) } catch { return }
                self?.completeRequest(message.id, error: PeerError.timeout)
            }
            pending[message.id] = PendingReply(continuation: continuation, timeout: timeout)
            Task { [weak self] in
                do { try await link.send(message) }
                catch { self?.completeRequest(message.id, error: error) }
            }
        }
    }
    private func completeRequest(_ id: UUID, error: Error) {
        guard let pending = pending.removeValue(forKey: id) else { return }
        pending.timeout.cancel(); pending.continuation.resume(throwing: error)
    }
    func benchmark() {
        guard connected, !testing else { return }
        samples = []; transferMetrics = []; testing = true; failure = nil; testDate = .now
        benchmarkID = UUID()
        let token = generation, runID = benchmarkID, began = ContinuousClock.now
        testTask = Task { [weak self] in
            guard let self else { return }
            defer { if self.benchmarkID == runID { self.testing = false } }
            do {
                for index in 0..<20 {
                    try Task.checkCancellation(); guard self.generation == token else { return }
                    self.testStatus = "Response \(index + 1) of 20"
                    let date = Date(), start = ContinuousClock.now, position = self.positionProvider?(.now)
                    do {
                        let reply = try await self.request(PeerMessage(kind: .ping))
                        try Task.checkCancellation()
                        guard self.benchmarkID == runID else { return }
                        guard reply.kind == .pong else { throw PeerError.invalidMessage }
                        self.samples.append(FieldSample(date: date, elapsed: began.duration(to: start).secondsValue,
                            values: ["rttMS": start.duration(to: .now).secondsValue * 1000], detail: "Application echo round trip", placement: position))
                    } catch {
                        guard self.connected, self.generation == token, !Task.isCancelled else { throw error }
                        self.samples.append(FieldSample(date: date, elapsed: began.duration(to: start).secondsValue, values: [:], detail: error.localizedDescription, placement: position))
                        throw error
                    }
                    try await Task.sleep(for: .milliseconds(350))
                }
                let data = await Task.detached(priority: .userInitiated) { PeerProtocol.testData() }.value
                try Task.checkCancellation()
                guard self.benchmarkID == runID else { return }
                let expected = PeerProtocol.digest(data)
                self.testStatus = "Uploading 2 MiB of test bytes"
                let uploadStart = ContinuousClock.now
                let uploaded = try await self.request(PeerMessage(kind: .upload, payload: data))
                try Task.checkCancellation()
                guard self.benchmarkID == runID else { return }
                guard uploaded.kind == .uploaded, uploaded.digest == expected else { throw PeerError.integrity }
                self.transferMetrics.append(.init(id: "upload", title: "This device → peer", value: Double(data.count) * 8 / uploadStart.duration(to: .now).secondsValue / 1_000_000, unit: "Mbit/s", qualifier: "2 MiB application goodput, verified by peer digest"))
                self.testStatus = "Downloading 2 MiB of test bytes"
                let downloadStart = ContinuousClock.now
                let downloaded = try await self.request(PeerMessage(kind: .download))
                try Task.checkCancellation()
                guard self.benchmarkID == runID else { return }
                guard downloaded.kind == .downloaded, let payload = downloaded.payload,
                      payload.count == PeerProtocol.transferBytes, PeerProtocol.digest(payload) == expected else { throw PeerError.integrity }
                self.transferMetrics.append(.init(id: "download", title: "Peer → this device", value: Double(payload.count) * 8 / downloadStart.duration(to: .now).secondsValue / 1_000_000, unit: "Mbit/s", qualifier: "2 MiB application goodput, verified locally"))
                self.testStatus = "Benchmark complete · 4 MiB transferred and verified"
            } catch {
                guard self.generation == token, !Task.isCancelled else { return }
                self.failure = error.localizedDescription; self.testStatus = "Benchmark interrupted · completed observations retained"
            }
        }
    }
    func stopBenchmark() {
        benchmarkID = UUID(); testTask?.cancel(); testTask = nil
        if testing { testStatus = "Benchmark stopped · completed observations retained" }
        testing = false
        for id in Array(pending.keys) { completeRequest(id, error: CancellationError()) }
    }
    func stopNearby() {
        nearby.stop()
        let token = generation
        if let link { Task { [weak self] in
            do { try await link.send(PeerMessage(kind: .nearbyStop)) }
            catch { if self?.generation == token { self?.failure = "Ranging stopped here, but the peer could not be notified: \(error.localizedDescription)" } }
        } }
    }
    func stop() {
        generation = UUID(); stopBenchmark()
        verificationTimeout?.cancel(); verificationTimeout = nil; pathTask?.cancel(); pathTask = nil
        connectionTask?.cancel(); connectionTask = nil; listeningTask?.cancel(); listeningTask = nil
        browser?.cancel(); browser = nil; listener = nil; aware.stop(); nearby.stop()
        if let link { Task { await link.stop() } }; link = nil
        connected = false; hosting = false; browsing = false; peers = []; verificationCode = nil
        locallyConfirmed = false; remotelyConfirmed = false; status = "Disconnected"
    }
    var capture: FieldCapture? {
        guard !samples.isEmpty || !transferMetrics.isEmpty else { return nil }
        let rtt = samples.compactMap { $0.values["rttMS"] }
        var metrics = transferMetrics
        if let median = FieldStatistics.percentile(rtt, fraction: 0.5), let p95 = FieldStatistics.percentile(rtt, fraction: 0.95) {
            metrics += [.init(id: "median", title: "Median echo round trip", value: median, unit: "ms"),
                        .init(id: "p95", title: "p95 echo round trip", value: p95, unit: "ms")]
        }
        metrics.append(.init(id: "failures", title: "Failed echo requests", value: Double(samples.filter { $0.values["rttMS"] == nil }.count), unit: "requests"))
        return FieldCapture(title: "Peer benchmark", kind: .peer, date: testDate, source: peerName,
            method: "20 application echo requests, followed by one 2 MiB transfer in each direction with SHA-256 byte verification. Encrypted application traffic includes framing, scheduling, and processing overhead. These values are not PHY link speed or internet speed.",
            metrics: metrics, samples: samples, metadata: ["transport": transportTitle, "pathContext": pathDescription, "completion": testStatus], placement: samples.first?.placement)
    }
}

nonisolated enum PeerDeadline {
    static func run<T: Sendable>(seconds: Double, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask { try await Task.sleep(for: .seconds(seconds)); throw PeerError.timeout }
            defer { group.cancelAll() }
            guard let value = try await group.next() else { throw PeerError.ended }
            return value
        }
    }
}
