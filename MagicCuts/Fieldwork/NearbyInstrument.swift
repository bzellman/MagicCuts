import Foundation
import Observation
@preconcurrency import NearbyInteraction
import simd

@MainActor @Observable
final class NearbyInstrument: NSObject, @preconcurrency NISessionDelegate {
    private(set) var active = false
    private(set) var status = "Start ranging on both connected devices"
    private(set) var distance: Double?
    private(set) var direction: SpatialVector?
    private(set) var observedAt: Date?
    private(set) var samples: [FieldSample] = []
    private(set) var failure: String?
    @ObservationIgnored var positionProvider: ((Date) -> RoomPlacement?)?
    @ObservationIgnored var onToken: ((Data) async throws -> Void)?
    @ObservationIgnored private var session: NISession?
    @ObservationIgnored private var peerToken: NIDiscoveryToken?
    @ObservationIgnored private var configuration: NINearbyPeerConfiguration?
    @ObservationIgnored private var began = ContinuousClock.now
    @ObservationIgnored private var lastSample = -Double.infinity

    var fresh: Bool { active && observedAt.map { Date().timeIntervalSince($0) <= 2 } == true }
    // Matches Apple's Nearby Interaction sample: lateral angle from the reported unit-vector x component.
    var azimuth: Double? { fresh ? direction.map { asin(max(-1, min(1, Double($0.x)))) } : nil }
    func start() async {
        stop(keepPeer: true); failure = nil; samples = []; began = .now; lastSample = -.infinity
        guard NISession.deviceCapabilities.supportsPreciseDistanceMeasurement else {
            status = "Precise ranging unavailable"; failure = "This device does not support Nearby Interaction distance measurements. Peer network tests remain available."
            return
        }
        let session = NISession(); self.session = session; session.delegate = self; session.delegateQueue = .main
        guard let token = session.discoveryToken else { failure = "A discovery token is not available. Try starting ranging again."; return }
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
            guard data.count <= 16_384 else { throw PeerError.invalidMessage }
            active = true; status = "Waiting for the other device to start ranging"
            try await onToken?(data)
            guard self.session === session, active else { return }
            runIfReady()
        } catch { stop(keepPeer: true); failure = error.localizedDescription }
    }
    func receiveToken(_ data: Data) throws {
        guard data.count <= 16_384,
              let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else { throw PeerError.invalidMessage }
        peerToken = token
        if active { runIfReady() }
    }
    private func runIfReady() {
        guard active, let session, let peerToken else { return }
        let configuration = NINearbyPeerConfiguration(peerToken: peerToken)
        self.configuration = configuration
        session.run(configuration)
        status = "Point both back cameras toward each other with the phones upright"
    }
    func stop(keepPeer: Bool = false) {
        session?.delegate = nil; session?.invalidate(); session = nil; configuration = nil
        if !keepPeer { peerToken = nil }
        active = false; clearReading(); status = "Ranging stopped"
    }
    private func clearReading() { distance = nil; direction = nil; observedAt = nil }
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard self.session === session, active, let peerToken,
              let object = nearbyObjects.first(where: { $0.discoveryToken == peerToken }) else { return }
        let date = Date(), elapsed = began.duration(to: .now).secondsValue
        distance = object.distance.flatMap { $0.isFinite && $0 >= 0 ? Double($0) : nil }
        direction = object.direction.flatMap { vector in
            let value = SpatialVector(vector)
            return value.isFinite && simd_length(vector) > 0.5 && simd_length(vector) < 1.5 ? value : nil
        }
        observedAt = distance != nil || direction != nil ? date : nil
        status = distance == nil ? "Move closer and keep a clear line of sight" : direction == nil ? "Distance available · direction unavailable" : "Distance and direction available"
        if elapsed - lastSample >= 0.2, distance != nil || direction != nil {
            lastSample = elapsed
            var values: [String: Double] = [:]
            if let distance { values["distance"] = distance }
            if let direction { values["directionX"] = Double(direction.x); values["directionY"] = Double(direction.y); values["directionZ"] = Double(direction.z) }
            samples.append(FieldSample(date: date, elapsed: elapsed, values: values, detail: status, placement: positionProvider?(date)))
            if samples.count > 1500 { samples.removeFirst(samples.count - 1500) }
        }
    }
    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        guard self.session === session else { return }
        clearReading(); status = "Peer ranging ended. Start ranging again on both devices."; active = false
    }
    func sessionWasSuspended(_ session: NISession) {
        guard self.session === session else { return }
        clearReading(); status = "Ranging suspended"; active = false
    }
    func sessionSuspensionEnded(_ session: NISession) {
        guard self.session === session else { return }
        clearReading(); status = "Start ranging again to continue"; active = false
    }
    func session(_ session: NISession, didInvalidateWith error: Error) {
        guard self.session === session else { return }
        clearReading(); active = false; self.session = nil; configuration = nil
        status = "Ranging unavailable"; failure = error.localizedDescription
    }
    func capture(peerName: String) -> FieldCapture? {
        guard fresh, let observedAt else { return nil }
        var metrics: [FieldMetric] = []
        if let distance { metrics.append(.init(id: "distance", title: "Peer distance", value: distance, unit: "m", qualifier: "Nearby Interaction")) }
        if let azimuth { metrics.append(.init(id: "lateralAngle", title: "Left/right angle", value: azimuth * 180 / .pi, unit: "°", qualifier: "Relative to the upright phone")) }
        return FieldCapture(title: "Nearby range", kind: .nearby, date: observedAt, source: peerName,
            method: "Nearby Interaction between two participating devices. Direction is optional and relative to this phone. No direction is inferred from signal strength. Live values expire after two seconds without an update.",
            metrics: metrics, samples: samples, metadata: ["directionStatus": direction == nil ? "Range only" : "Vector available"], placement: positionProvider?(observedAt))
    }
}
