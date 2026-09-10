import Foundation
import CoreBluetooth

@MainActor
struct RadioSession {
    let events: AsyncThrowingStream<RadioEvent, Error>
    let cancel: @MainActor () -> Void
}

@MainActor
protocol RadioScanning: AnyObject {
    func session(services: [String]) -> RadioSession
    func stop()
}

/// Owns one scan at a time. Every callback, timeout and cancellation is serialized on the main actor.
@MainActor
final class BluetoothRadio: NSObject, RadioScanning, CBCentralManagerDelegate {
    private var central: CBCentralManager?
    private var continuation: AsyncThrowingStream<RadioEvent, Error>.Continuation?
    private var sessionID: UUID?
    private var initialization: Task<Void, Never>?
    private var services: [String] = []
    private var scanning = false

    func session(services: [String]) -> RadioSession {
        guard services.allSatisfy(ServiceIdentifier.isValid) else {
            return RadioSession(events: AsyncThrowingStream { $0.finish(throwing: BluetoothError.storage) }, cancel: {})
        }
        stop()
        let id = UUID()
        sessionID = id
        self.services = services
        let stream = AsyncThrowingStream<RadioEvent, Error> { continuation in
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard self?.sessionID == id else { return }
                    self?.stop()
                }
            }
            // Lazy creation prevents a permission prompt during welcome or launch.
            central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
            initialization = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard self?.sessionID == id, self?.scanning == false else { return }
                self?.finish(BluetoothError.initialization)
            }
        }
        return RadioSession(events: stream, cancel: { [weak self] in
            guard self?.sessionID == id else { return }
            self?.stop()
        })
    }

    func stop() { finish(CancellationError()) }

    private func finish(_ error: Error) {
        let completion = continuation
        continuation = nil
        sessionID = nil
        initialization?.cancel()
        initialization = nil
        scanning = false
        central?.stopScan()
        central?.delegate = nil
        central = nil
        completion?.finish(throwing: error)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === self.central, continuation != nil else { return }
        switch central.state {
        case .poweredOn:
            guard !scanning else { return }
            scanning = true
            initialization?.cancel()
            central.scanForPeripherals(withServices: services.isEmpty ? nil : services.map(CBUUID.init(string:)), options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            continuation?.yield(.ready(Date()))
        case .poweredOff: finish(BluetoothError.poweredOff)
        case .unauthorized: finish(BluetoothError.denied)
        case .unsupported: finish(BluetoothError.unsupported)
        case .resetting: finish(BluetoothError.resetting)
        case .unknown: break
        @unknown default: finish(BluetoothError.unavailable)
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard central === self.central, scanning, SignalSample.isValid(RSSI.intValue) else { return }
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = (advertisedName ?? peripheral.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        continuation?.yield(.device(RadioDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue, services: services, lastSeen: Date())))
    }
}

@MainActor
final class ProximitySampler {
    private let radio: any RadioScanning
    init(radio: any RadioScanning) { self.radio = radio }

    func collect(id: UUID, services: [String], duration: Duration = .seconds(10), onReady: @escaping @MainActor (Date) -> Void = { _ in }, onSample: @escaping @MainActor (SignalSample) -> Void = { _ in }) async throws -> [SignalSample] {
        try Task.checkCancellation()
        let session = radio.session(services: services)
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
                    guard deadline != nil, device.id == id, SignalSample.isValid(device.rssi) else { continue }
                    let sample = SignalSample(date: device.lastSeen, rssi: device.rssi)
                    samples.append(sample)
                    onSample(sample)
                }
            }
        } catch {
            if !windowCompleted || Task.isCancelled { throw error }
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
