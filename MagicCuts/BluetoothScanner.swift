import Foundation

@MainActor
struct RadioSession {
    let events: AsyncThrowingStream<RadioEvent, Error>
    let cancel: @MainActor () -> Void
}

@MainActor
protocol RadioScanning: AnyObject {
    func session(services: [String]) -> RadioSession
    func proximitySession(id: UUID, services: [String]) -> RadioSession
    func stop()
}

extension RadioScanning {
    func proximitySession(id: UUID, services: [String]) -> RadioSession { session(services: services) }
}

/// Owns one scan at a time. Every callback, timeout and cancellation is serialized on the main actor.
@MainActor
final class BluetoothRadio: RadioScanning {
    private let makeTransport: @MainActor () -> any BluetoothTransport
    private let fallbackDelay: Duration
    private let rssiInterval: Duration
    private let maxRSSIAttempts: Int
    private var transport: (any BluetoothTransport)?
    private var continuation: AsyncThrowingStream<RadioEvent, Error>.Continuation?
    private var sessionID: UUID?
    private var initialization: Task<Void, Never>?
    private var fallback: Task<Void, Never>?
    private var polling: Task<Void, Never>?
    private var services: [String] = []
    private var targetID: UUID?
    private var scanning = false
    private var targetObserved = false
    private var directActive = false
    private var connected = false
    private var awaitingRSSI = false
    private var rssiAttempts = 0

    init(makeTransport: @escaping @MainActor () -> any BluetoothTransport = { CoreBluetoothTransport() },
         fallbackDelay: Duration = .milliseconds(1500), rssiInterval: Duration = .milliseconds(350), maxRSSIAttempts: Int = 5) {
        self.makeTransport = makeTransport
        self.fallbackDelay = fallbackDelay
        self.rssiInterval = rssiInterval
        self.maxRSSIAttempts = max(1, maxRSSIAttempts)
    }

    func session(services: [String]) -> RadioSession {
        session(services: services, targetID: nil)
    }

    func proximitySession(id: UUID, services: [String]) -> RadioSession {
        session(services: services, targetID: id)
    }

    private func session(services: [String], targetID: UUID?) -> RadioSession {
        guard services.allSatisfy(ServiceIdentifier.isValid) else {
            return RadioSession(events: AsyncThrowingStream { $0.finish(throwing: BluetoothError.storage) }, cancel: {})
        }
        stop()
        let id = UUID()
        sessionID = id
        self.services = services
        self.targetID = targetID
        targetObserved = false
        let transport = makeTransport()
        self.transport = transport
        let stream = AsyncThrowingStream<RadioEvent, Error> { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard self?.sessionID == id else { return }
                    self?.stop()
                }
            }
            transport.onEvent = { [weak self] event in
                guard let self, self.sessionID == id else { return }
                self.receive(event, sessionID: id)
            }
            initialization = Task { [weak self] in
                do {
                    while self?.transport?.authorizationPending == true {
                        guard self?.sessionID == id else { return }
                        try await Task.sleep(for: .milliseconds(100))
                    }
                    try await Task.sleep(for: .seconds(5))
                } catch { return }
                guard self?.sessionID == id, self?.scanning == false else { return }
                self?.finish(BluetoothError.initialization)
            }
            // Lazy creation prevents a permission prompt during welcome or launch.
            transport.start()
        }
        return RadioSession(events: stream, cancel: { [weak self] in
            guard self?.sessionID == id else { return }
            self?.stop()
        })
    }

    func stop() { finish(CancellationError()) }

    private func finish(_ error: Error) {
        guard let completion = continuation else { return }
        continuation = nil
        sessionID = nil
        initialization?.cancel()
        initialization = nil
        fallback?.cancel()
        fallback = nil
        scanning = false
        transport?.onEvent = nil
        stopDirectConnection()
        transport?.stop()
        transport = nil
        completion.finish(throwing: error)
    }

    private func receive(_ event: BluetoothTransportEvent, sessionID id: UUID) {
        switch event {
        case .ready:
            guard !scanning else { return }
            scanning = true
            initialization?.cancel()
            initialization = nil
            transport?.scan(services: services)
            continuation?.yield(.ready(Date()))
            guard let targetID else { return }
            if !services.isEmpty {
                fallback = Task { [weak self, fallbackDelay] in
                    do { try await Task.sleep(for: fallbackDelay) } catch { return }
                    guard let self, self.sessionID == id, !self.targetObserved else { return }
                    self.fallback = nil
                    self.transport?.scan(services: [])
                }
            }
            directActive = true
            transport?.connect(id: targetID, services: services)
        case .failure(let error): finish(error)
        case .device(let device):
            guard scanning, SignalSample.isValid(device.rssi) else { return }
            if device.id == targetID { observeTarget() }
            continuation?.yield(.device(device))
        case .connected:
            guard directActive, !connected else { return }
            connected = true
            requestRSSI()
        case .connectionEnded:
            stopDirectConnection()
        case .rssi(let value):
            guard directActive, connected, awaitingRSSI else { return }
            awaitingRSSI = false
            if let value, SignalSample.isValid(value), let targetID {
                observeTarget()
                continuation?.yield(.device(RadioDevice(id: targetID, name: "", rssi: value, services: services, lastSeen: .now)))
            }
            // Await each response before another read; a missing callback is bounded by the session deadline.
            guard rssiAttempts < maxRSSIAttempts else { stopDirectConnection(); return }
            polling = Task { [weak self, rssiInterval] in
                do { try await Task.sleep(for: rssiInterval) } catch { return }
                guard let self, self.sessionID == id, self.directActive, self.connected else { return }
                self.polling = nil
                self.requestRSSI()
            }
        }
    }

    private func observeTarget() {
        targetObserved = true
        fallback?.cancel()
        fallback = nil
    }

    private func requestRSSI() {
        awaitingRSSI = true
        rssiAttempts += 1
        transport?.readRSSI()
    }

    private func stopDirectConnection() {
        polling?.cancel()
        polling = nil
        connected = false
        awaitingRSSI = false
        rssiAttempts = 0
        guard directActive else { return }
        directActive = false
        transport?.disconnect()
    }
}

@MainActor
final class ProximitySampler {
    private let radio: any RadioScanning
    init(radio: any RadioScanning) { self.radio = radio }

    func collect(id: UUID, services: [String], duration: Duration = .seconds(10), stoppingAtThreshold: Int? = nil, onReady: @escaping @MainActor (Date) -> Void = { _ in }, onSample: @escaping @MainActor (SignalSample) -> Void = { _ in }) async throws -> [SignalSample] {
        try Task.checkCancellation()
        let session = stoppingAtThreshold == nil ? radio.session(services: services) : radio.proximitySession(id: id, services: services)
        var samples: [SignalSample] = []
        var deadline: Task<Void, Never>?
        var windowCompleted = false
        defer { deadline?.cancel(); session.cancel() }
        do {
            for try await event in session.events {
                try Task.checkCancellation()
                switch event {
                case .ready(let date):
                    if deadline == nil {
                        onReady(date)
                        deadline = Task { @MainActor in
                            do { try await Task.sleep(for: duration) } catch { return }
                            windowCompleted = true
                            session.cancel()
                        }
                    }
                case .device(let device):
                    guard !windowCompleted, deadline != nil, device.id == id, SignalSample.isValid(device.rssi) else { continue }
                    let sample = SignalSample(date: device.lastSeen, rssi: device.rssi)
                    samples.append(sample)
                    onSample(sample)
                    if let stoppingAtThreshold, sample.rssi >= stoppingAtThreshold {
                        try Task.checkCancellation()
                        return samples
                    }
                }
            }
        } catch {
            if !windowCompleted || !(error is CancellationError) || Task.isCancelled { throw error }
        }
        try Task.checkCancellation()
        guard windowCompleted else { throw BluetoothError.unavailable }
        return samples
    }
}

/// Predictable observations for previews and UI tests; never selected in production.
@MainActor
final class DemoRadio: RadioScanning {
    static let deviceID = UUID(uuidString: "AAAAAAAA-1111-2222-3333-444444444444")!
    private var continuation: AsyncThrowingStream<RadioEvent, Error>.Continuation?
    private var task: Task<Void, Never>?
    private var sessionID: UUID?
    var readings = [-68, -66, -62, -65]
    var failure: BluetoothError?
    var timestampOffset: TimeInterval = 0
    var interruptAfterReadings = false
    func session(services: [String]) -> RadioSession {
        stop()
        let id = UUID()
        sessionID = id
        let stream = AsyncThrowingStream<RadioEvent, Error> { continuation in
            self.continuation = continuation
            if let failure { continuation.finish(throwing: failure); return }
            continuation.yield(.ready(Date()))
            task = Task {
                for value in readings {
                    guard !Task.isCancelled else { return }
                    continuation.yield(.device(RadioDevice(id: Self.deviceID, name: "Desk sensor", rssi: value, services: ["180F"], lastSeen: Date().addingTimeInterval(timestampOffset))))
                    continuation.yield(.device(RadioDevice(id: UUID(uuidString: "BBBBBBBB-1111-2222-3333-444444444444")!, name: "", rssi: -74, services: [], lastSeen: Date().addingTimeInterval(timestampOffset))))
                    try? await Task.sleep(for: .milliseconds(100))
                }
                if interruptAfterReadings { continuation.finish(throwing: CancellationError()) }
            }
        }
        return RadioSession(events: stream, cancel: { [weak self] in
            guard self?.sessionID == id else { return }
            self?.stop()
        })
    }
    func stop() { sessionID = nil; task?.cancel(); task = nil; continuation?.finish(throwing: CancellationError()); continuation = nil }
}
