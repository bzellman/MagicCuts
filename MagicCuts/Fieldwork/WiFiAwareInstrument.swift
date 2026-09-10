import Foundation
import Observation
import Network
import SwiftUI
#if canImport(WiFiAware)
import WiFiAware
#endif
#if canImport(DeviceDiscoveryUI)
import DeviceDiscoveryUI
#endif

nonisolated struct AwareDeviceSummary: Identifiable, Sendable { var id: UInt64; var name: String }

@MainActor @Observable
final class WiFiAwareInstrument {
    private(set) var status = "Pair devices to use Wi-Fi Aware"
    private(set) var failure: String?
    private(set) var running = false
    private(set) var paired: [AwareDeviceSummary] = []
    private(set) var discovered: [AwareDeviceSummary] = []
    private(set) var metrics: [FieldMetric] = []
    private(set) var reportDate: Date?
    private(set) var samples: [FieldSample] = []
    private(set) var reportPeer = "Wi-Fi Aware peer"
    @ObservationIgnored var positionProvider: ((Date) -> RoomPlacement?)?
    @ObservationIgnored var onConnection: ((NetworkConnection<TCP>, String) async -> Void)?
    @ObservationIgnored private var transportTask: Task<Void, Never>?
    @ObservationIgnored private var deviceTask: Task<Void, Never>?
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    #if canImport(WiFiAware)
    @ObservationIgnored private var endpoints: [UInt64: WAEndpoint] = [:]
    #endif
    var supported: Bool {
        #if canImport(WiFiAware)
        WACapabilities.supportedFeatures.contains(.wifiAware)
        #else
        false
        #endif
    }
    func watchDevices() {
        guard supported, deviceTask == nil else { return }
        #if canImport(WiFiAware)
        deviceTask = Task { [weak self] in
            do {
                for try await devices in WAPairedDevice.allDevices {
                    guard let self, !Task.isCancelled else { return }
                    self.paired = devices.values.map { AwareDeviceSummary(id: $0.id, name: String(($0.name ?? "Paired device").prefix(100))) }.sorted { $0.name < $1.name }
                }
            } catch { guard !Task.isCancelled else { return }; self?.failure = "Paired devices unavailable: \(error.localizedDescription)" }
        }
        #endif
    }
    func host() {
        stopTransport(); failure = nil; metrics = []; reportDate = nil; samples = []
        guard supported else { status = "Wi-Fi Aware is unavailable on this device"; return }
        watchDevices()
        #if canImport(WiFiAware)
        guard let service = WAPublishableService.allServices[PeerProtocol.service] else { failure = "The Wi-Fi Aware service is missing from this build."; return }
        running = true; status = "Publishing to paired devices"
        let token = generation
        transportTask = Task { [weak self] in
            do {
                let parameters = NWParametersBuilder<TCP>.parameters { TCP() }.wifiAware { $0.performanceMode = .bulk }
                let listener = try NetworkListener<TCP>(for: .wifiAware(.connecting(to: service, from: .allPairedDevices)), using: parameters)
                    .newConnectionLimit(1)
                listener.onStateUpdate { [weak self] _, state in
                    guard let self, self.generation == token else { return }
                    if case .ready = state { self.status = "Wi-Fi Aware host ready" }
                    if case .waiting(let error) = state { self.status = "Wi-Fi Aware waiting: \(error.localizedDescription)" }
                    if case .failed(let error) = state { self.failure = Self.explain(error); self.running = false }
                }
                try await listener.run { [weak self] connection in
                    guard let self, self.generation == token else { return }
                    self.status = "Connecting to paired participant"
                    await self.onConnection?(connection, "Paired Wi-Fi Aware device")
                }
            } catch { guard let self, self.generation == token, !Task.isCancelled else { return }; self.failure = error.localizedDescription; self.running = false }
        }
        #endif
    }
    func browse() {
        stopTransport(); failure = nil; metrics = []; reportDate = nil; samples = []
        guard supported else { status = "Wi-Fi Aware is unavailable on this device"; return }
        watchDevices()
        #if canImport(WiFiAware)
        guard let service = WASubscribableService.allServices[PeerProtocol.service] else { failure = "The Wi-Fi Aware service is missing from this build."; return }
        running = true; status = "Discovering paired hosts"
        let token = generation
        transportTask = Task { [weak self] in
            do {
                let browser = NetworkBrowser(for: .wifiAware(.connecting(to: .allPairedDevices, from: service)))
                browser.onStateUpdate { [weak self] _, state in
                    guard let self, self.generation == token else { return }
                    if case .waiting(let error) = state { self.status = "Wi-Fi Aware waiting: \(error.localizedDescription)" }
                    if case .failed(let error) = state { self.failure = Self.explain(error); self.running = false }
                }
                try await browser.run { [weak self] endpoints in
                    guard let self, self.generation == token else { return }
                    self.endpoints = Dictionary(endpoints.prefix(40).map { ($0.device.id, $0) }, uniquingKeysWith: { first, _ in first })
                    self.discovered = self.endpoints.values.map { AwareDeviceSummary(id: $0.device.id, name: String(($0.device.name ?? "Paired host").prefix(100))) }.sorted { $0.name < $1.name }
                }
            } catch { guard let self, self.generation == token, !Task.isCancelled else { return }; self.failure = error.localizedDescription; self.running = false }
        }
        #endif
    }
    func connect(_ id: UInt64) {
        #if canImport(WiFiAware)
        guard let endpoint = endpoints[id], connectionTask == nil else { return }
        let token = generation
        status = "Connecting to selected paired device"
        connectionTask = Task { [weak self] in
            guard let self, self.generation == token else { return }
            let parameters = NWParametersBuilder<TCP>.parameters { TCP() }.wifiAware { $0.performanceMode = .bulk }
            let connection = NetworkConnection<TCP>(to: endpoint, using: parameters)
            await self.onConnection?(connection, String((endpoint.device.name ?? "Wi-Fi Aware peer").prefix(100)))
        }
        #endif
    }
    func observe(_ path: NWPath) async {
        #if canImport(WiFiAware)
        let token = generation
        do {
            guard let aware = try await path.wifiAware, generation == token, !Task.isCancelled else { return }
            let report = aware.performance
            guard report.timestamp != reportDate else { return }
            var metrics: [FieldMetric] = []
            if let value = report.signalStrength, value.isFinite, (0...1).contains(value) { metrics.append(.init(id: "strength", title: "Normalized signal strength", value: value, unit: "0–1", qualifier: "Observed for this peer link")) }
            if let value = report.throughputCeiling, value.isFinite, value >= 0 { metrics.append(.init(id: "ceiling", title: "Ideal throughput ceiling", value: value, unit: "Mbit/s", qualifier: "Hardware ceiling estimate")) }
            if let value = report.throughputCapacity, value.isFinite, value >= 0 { metrics.append(.init(id: "capacity", title: "Current throughput capacity", value: value, unit: "Mbit/s", qualifier: "System estimate, not a transfer test")) }
            for category in WAAccessCategory.allCases {
                if let duration = report.transmitLatency[category]?.average {
                    let name = Self.categoryName(category), value = duration.secondsValue * 1000
                    if value.isFinite && value >= 0 { metrics.append(.init(id: "latency-\(name)", title: "Transmit latency · \(name)", value: value, unit: "ms", qualifier: "Reported average")) }
                }
            }
            self.metrics = metrics; reportDate = report.timestamp; reportPeer = String((aware.endpoint.device.name ?? "Wi-Fi Aware peer").prefix(100))
            samples.append(FieldSample(date: report.timestamp, elapsed: report.timestamp.timeIntervalSince(samples.first?.date ?? report.timestamp), values: Dictionary(uniqueKeysWithValues: metrics.map { ($0.id, $0.value) }), placement: positionProvider?(report.timestamp)))
            if samples.count > 600 { samples.removeFirst(samples.count - 600) }
        } catch { guard generation == token, !Task.isCancelled else { return }; failure = "Link report unavailable: \(error.localizedDescription)"; metrics = []; reportDate = nil }
        #endif
    }
    var capture: FieldCapture? {
        guard let reportDate, !metrics.isEmpty else { return nil }
        return FieldCapture(title: "Wi-Fi Aware link", kind: .peer, date: reportDate, source: reportPeer,
            method: "Wi-Fi Aware report for this app's paired peer connection. Signal strength is normalized 0–1, not RSSI in dBm. Throughput capacity and ceiling are system estimates. Missing optional fields are unavailable.",
            metrics: metrics, samples: samples, metadata: ["transport": "Wi-Fi Aware", "mode": "Bulk"], placement: samples.last?.placement)
    }
    private func stopTransport() {
        generation = UUID(); transportTask?.cancel(); transportTask = nil; connectionTask?.cancel(); connectionTask = nil
        running = false; discovered = []
        #if canImport(WiFiAware)
        endpoints = [:]
        #endif
    }
    func stop() { stopTransport(); deviceTask?.cancel(); deviceTask = nil; status = "Wi-Fi Aware stopped" }
    #if canImport(WiFiAware)
    private static func explain(_ error: NWError) -> String {
        if case .entitlementMissing = error.wifiAware { return "This installed build does not have the Wi-Fi Aware entitlement." }
        if case .noPairedDevices = error.wifiAware { return "Pair both devices before advertising or discovering." }
        return "Wi-Fi Aware unavailable: \(error.localizedDescription)"
    }
    private static func categoryName(_ category: WAAccessCategory) -> String {
        switch category {
        case .bestEffort: "Best effort"; case .background: "Background"
        case .interactiveVideo: "Interactive video"; case .interactiveVoice: "Interactive voice"
        @unknown default: "Other"
        }
    }
    #endif
}

struct WiFiAwarePairingControls: View {
    let host: Bool
    var body: some View {
        #if canImport(WiFiAware) && canImport(DeviceDiscoveryUI)
        if WACapabilities.supportedFeatures.contains(.wifiAware) {
            if host, let service = WAPublishableService.allServices[PeerProtocol.service] {
                DevicePairingView(.wifiAware(.connecting(to: service, from: .userSpecifiedDevices))) {
                    Label("Pair as host", systemImage: "plus.circle").frame(minHeight: 44)
                } fallback: { Text("Device pairing unavailable") }
            } else if let service = WASubscribableService.allServices[PeerProtocol.service] {
                DevicePicker(.wifiAware(.connecting(to: .userSpecifiedDevices, from: service))) { _ in
                    // Pairing grants system access. The user separately chooses a discovered host to connect.
                } label: { Label("Pair with a host", systemImage: "plus.circle").frame(minHeight: 44) }
                fallback: { Text("Device pairing unavailable") }
            }
        } else { Text("Wi-Fi Aware pairing needs supported physical devices.").font(.callout).foregroundStyle(ProTheme.secondary) }
        #else
        Text("Wi-Fi Aware pairing needs supported physical devices.").font(.callout).foregroundStyle(ProTheme.secondary)
        #endif
    }
}
