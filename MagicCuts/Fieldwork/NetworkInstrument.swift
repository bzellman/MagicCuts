import Foundation
import Observation
import Network

nonisolated enum NetworkTestMode: String, CaseIterable, Identifiable, Sendable {
    case latency, download, upload
    var id: String { rawValue }
    var title: String {
        switch self { case .latency: "Response time"; case .download: "Download"; case .upload: "Upload" }
    }
    var method: String {
        switch self { case .latency: "HEAD"; case .download: "GET"; case .upload: "POST" }
    }
    var explanation: String {
        switch self {
        case .latency: "20 uncached HEAD requests, 0.7 seconds apart. Each request has a 6-second limit. The endpoint must support HEAD."
        case .download: "One GET request with an 8 MiB response limit. Choose a test file you control. Timing includes server and protocol overhead."
        case .upload: "One POST sends 2 MiB of generated test bytes. Choose an endpoint intended to receive test uploads. The response is limited to 1 MiB."
        }
    }
}

nonisolated struct RequestMetricTimes: Sendable {
    var dnsStart: Date?; var dnsEnd: Date?
    var connectStart: Date?; var connectEnd: Date?
    var tlsStart: Date?; var tlsEnd: Date?
    var requestStart: Date?; var requestEnd: Date?
    var responseStart: Date?; var responseEnd: Date?
    func phases(relativeTo origin: Date) -> [RequestPhase] {
        let values: [(String, String, Date?, Date?)] = [
            ("dns", "DNS", dnsStart, dnsEnd), ("connect", "Connection", connectStart, connectEnd),
            ("tls", "TLS", tlsStart, tlsEnd), ("request", "Send request", requestStart, requestEnd),
            ("wait", "Wait for response", requestEnd, responseStart), ("download", "Receive response", responseStart, responseEnd)]
        return values.compactMap { id, name, start, end in
            guard let start, let end, end >= start else { return nil }
            return RequestPhase(id: id, name: name, start: max(0, start.timeIntervalSince(origin)), end: max(0, end.timeIntervalSince(origin)))
        }
    }
}

// URLSession invokes callbacks on its delegate queue. The lock also protects cancellation and request registration.
nonisolated final class NetworkProbeClient: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private struct Pending {
        let continuation: CheckedContinuation<NetworkProbe, Never>
        let date: Date
        let clock: ContinuousClock.Instant
        let elapsed: Double
        let limit: Int
        var received = 0
        var status: Int?
        var transactions: [RequestTransaction] = []
        var failure: String?
    }
    private let lock = NSLock()
    private var pending: [Int: Pending] = [:]
    private var session: URLSession!
    init(protocolClasses: [AnyClass]? = nil) {
        super.init()
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil; config.httpCookieStorage = nil; config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 6; config.timeoutIntervalForResource = 20
        config.waitsForConnectivity = false
        if let protocolClasses { config.protocolClasses = protocolClasses }
        let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: config, delegate: self, delegateQueue: queue)
    }
    func request(_ url: URL, mode: NetworkTestMode, elapsed: Double) async -> NetworkProbe {
        let cancellation = RequestCancellation()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: mode == .latency ? 6 : 20)
                request.httpMethod = mode.method; request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
                request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
                if mode == .download { request.setValue("bytes=0-8388607", forHTTPHeaderField: "Range") }
                if mode == .upload {
                    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                    // Deterministic, nonsensitive bytes. POST only after an explicit upload action.
                    request.httpBody = Data((0..<(2 * 1024 * 1024)).map { UInt8(truncatingIfNeeded: $0 &* 73 &+ 19) })
                }
                let task = session.dataTask(with: request)
                lock.withLock { pending[task.taskIdentifier] = Pending(continuation: continuation, date: .now, clock: .now, elapsed: elapsed,
                    limit: mode == .download ? 8 * 1024 * 1024 : 1024 * 1024) }
                cancellation.register(task); task.resume()
            }
        } onCancel: { cancellation.cancel() }
    }
    func close() { session.invalidateAndCancel() }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping @Sendable (URLSession.ResponseDisposition) -> Void) {
        let allowed = lock.withLock {
            guard var value = pending[dataTask.taskIdentifier] else { return false }
            value.status = (response as? HTTPURLResponse)?.statusCode
            if response.expectedContentLength > Int64(value.limit), dataTask.originalRequest?.httpMethod != "HEAD" {
                value.failure = "Response exceeds the configured byte limit. Choose a smaller test resource."
            }
            pending[dataTask.taskIdentifier] = value
            return value.failure == nil
        }
        completionHandler(allowed ? .allow : .cancel)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let exceeded = lock.withLock {
            guard var value = pending[dataTask.taskIdentifier] else { return false }
            value.received += data.count
            if value.received > value.limit { value.failure = "Response byte limit reached. This transfer is incomplete." }
            pending[dataTask.taskIdentifier] = value
            return value.failure != nil
        }
        if exceeded { dataTask.cancel() }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        lock.withLock {
            guard var value = pending[task.taskIdentifier] else { return }
            value.transactions = metrics.transactionMetrics.map { item in
                let times = RequestMetricTimes(dnsStart: item.domainLookupStartDate, dnsEnd: item.domainLookupEndDate,
                    connectStart: item.connectStartDate, connectEnd: item.connectEndDate, tlsStart: item.secureConnectionStartDate,
                    tlsEnd: item.secureConnectionEndDate, requestStart: item.requestStartDate, requestEnd: item.requestEndDate,
                    responseStart: item.responseStartDate, responseEnd: item.responseEndDate)
                return RequestTransaction(phases: times.phases(relativeTo: value.date), protocolName: item.networkProtocolName,
                    reused: item.isReusedConnection, cellular: item.isCellular, cached: item.resourceFetchType == .localCache,
                    status: (item.response as? HTTPURLResponse)?.statusCode, host: item.request.url?.host ?? "Unknown host")
            }
            pending[task.taskIdentifier] = value
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let value = lock.withLock({ pending.removeValue(forKey: task.taskIdentifier) }) else { return }
        var failure = value.failure
        if failure == nil, let error {
            let ns = error as NSError
            // Avoid serializing URL query strings from localized URLSession errors.
            failure = "Request failed (\(ns.domain), \(ns.code)). \(Self.explanation(ns.code))"
        }
        if failure == nil, let status = value.status, !(200..<300).contains(status) { failure = "HTTP \(status). This response is excluded from successful timings." }
        if failure == nil && value.status == nil { failure = "No HTTP response was returned." }
        value.continuation.resume(returning: NetworkProbe(date: value.date, elapsed: value.elapsed,
            durationMS: value.clock.duration(to: .now).secondsValue * 1000, status: value.status, error: failure,
            transactions: value.transactions, receivedBytes: Int64(value.received), sentBytes: task.countOfBytesSent))
    }
    private static func explanation(_ code: Int) -> String {
        switch code {
        case NSURLErrorTimedOut: "The request timed out."
        case NSURLErrorCancelled: "The request was canceled."
        case NSURLErrorNotConnectedToInternet: "No usable network route was available."
        case NSURLErrorCannotFindHost: "The host could not be resolved."
        case NSURLErrorCannotConnectToHost: "The host could not be reached."
        case NSURLErrorAppTransportSecurityRequiresSecureConnection: "Use HTTPS, or a permitted local network endpoint."
        default: "Check the endpoint and connection, then try again."
        }
    }
}

nonisolated private final class RequestCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var task: URLSessionTask?
    private var canceled = false
    func register(_ task: URLSessionTask) {
        let shouldCancel = lock.withLock { self.task = task; return canceled }
        if shouldCancel { task.cancel() }
    }
    func cancel() { let current = lock.withLock { canceled = true; return task }; current?.cancel() }
}

@MainActor @Observable
final class NetworkInstrument {
    private(set) var running = false
    private(set) var probes: [NetworkProbe] = []
    private(set) var status = "Choose an endpoint to test"
    private(set) var failure: String?
    private(set) var path = "No path observation"
    private(set) var endpointLabel = ""
    private(set) var mode: NetworkTestMode = .latency
    private(set) var startedAt = Date()
    private(set) var cellularOnly = false
    @ObservationIgnored var positionProvider: ((Date) -> RoomPlacement?)?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var client: NetworkProbeClient?
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var generation = UUID()
    func start(endpoint: String, mode: NetworkTestMode, cellularOnly: Bool = false) {
        stop(); probes = []; failure = nil
        guard let url = EndpointPolicy.url(endpoint) else { failure = "Enter a valid HTTP or HTTPS endpoint without embedded credentials."; return }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = nil; components?.fragment = nil
        endpointLabel = components?.string ?? (url.host ?? "Endpoint")
        self.mode = mode; self.cellularOnly = cellularOnly; startedAt = .now
        running = true; status = "Testing endpoint"
        let token = generation, origin = ContinuousClock.now
        let client = NetworkProbeClient(); self.client = client
        let monitor = NWPathMonitor(); self.monitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let value = path.status == .satisfied ? (path.usesInterfaceType(.wifi) ? "Wi-Fi" : path.usesInterfaceType(.cellular) ? "Cellular" : "Other interface") + (path.isExpensive ? " · Metered" : "") + (path.isConstrained ? " · Low Data Mode" : "") : "No usable path"
            Task { @MainActor [weak self] in guard self?.generation == token else { return }; self?.path = value }
        }
        monitor.start(queue: .main)
        task = Task { [weak self] in
            for index in 0..<(mode == .latency ? 20 : 1) {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                let placement = self.positionProvider?(.now)
                var probe = await client.request(url, mode: mode, elapsed: origin.duration(to: .now).secondsValue)
                guard self.generation == token, !Task.isCancelled else { return }
                probe.placement = placement
                self.probes.append(probe)
                self.status = "\(self.probes.count) \(mode == .latency ? "of 20 requests" : "transfer") complete"
                if index < 19 && mode == .latency { do { try await Task.sleep(for: .milliseconds(700)) } catch { return } }
            }
            guard let self, self.generation == token else { return }
            self.running = false; self.status = "Test complete"; client.close(); self.client = nil
            self.monitor?.cancel(); self.monitor = nil
        }
    }
    func stop() {
        generation = UUID(); task?.cancel(); task = nil; client?.close(); client = nil
        monitor?.cancel(); monitor = nil
        if running { status = "Test stopped. Completed requests retained." }
        running = false
    }
    var capture: FieldCapture? {
        guard !probes.isEmpty else { return nil }
        var metrics = FieldStatistics.networkMetrics(probes, cellularOnly: cellularOnly)
        if mode != .latency, let probe = probes.first, probe.succeeded, (!cellularOnly || probe.verifiedCellular), probe.durationMS > 0 {
            let bytes = mode == .download ? probe.receivedBytes : probe.sentBytes
            metrics.append(.init(id: "transfer", title: "\(mode.title) goodput", value: Double(bytes) * 8 / (probe.durationMS * 1000), unit: "Mbit/s", qualifier: "Whole request, including overhead"))
            metrics.append(.init(id: "bytes", title: "\(mode.title) bytes", value: Double(bytes), unit: "bytes"))
        }
        return FieldCapture(title: cellularOnly ? "Cellular \(mode.title.lowercased())" : "Network \(mode.title.lowercased())",
            kind: cellularOnly ? .cellular : .network, date: startedAt, source: endpointLabel,
            method: "\(mode.explanation) No redirects. URLSession transaction metrics identify the actual route. System path observations are context only. TLS is nested in connection setup. Failed requests are excluded from response-time statistics.",
            metrics: metrics, metadata: ["method": mode.method, "pathContext": path, "completion": status,
                "routeRule": cellularOnly ? "Statistics include only transactions verified as cellular and not cached. Turn Wi-Fi off yourself to choose cellular." : "All observed routes", "endpointQuery": "Omitted from saved capture"],
            probes: probes, placement: probes.first?.placement)
    }
}
