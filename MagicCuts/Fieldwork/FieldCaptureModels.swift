import Foundation

nonisolated enum FieldCaptureKind: String, Codable, CaseIterable, Sendable {
    case reading, nfc, network, cellular, peer, nearby, depth, surface
    var title: String {
        switch self {
        case .reading: "Measurement"; case .nfc: "NFC read"; case .network: "Network test"
        case .cellular: "Cellular test"; case .peer: "Peer test"; case .nearby: "Nearby range"
        case .depth: "Depth capture"; case .surface: "Surface measurement"
        }
    }
    var symbol: String {
        switch self {
        case .reading: "mappin.and.ellipse"; case .nfc: "wave.3.right.circle"; case .network: "network"
        case .cellular: "antenna.radiowaves.left.and.right"; case .peer: "point.3.connected.trianglepath.dotted"
        case .nearby: "location.north.circle"; case .depth: "viewfinder"; case .surface: "ruler"
        }
    }
}

nonisolated struct FieldMetric: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var title: String
    var value: Double
    var unit: String
    var qualifier: String = "Observed"
    var formatted: String { value.formatted(.number.precision(.fractionLength(0...2))) }
}

nonisolated struct FieldSample: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var date: Date
    var elapsed: Double
    var values: [String: Double]
    var detail: String = ""
    var placement: RoomPlacement?
}

nonisolated struct CaptureDiagnostic: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var date: Date = .now
    var step: String
    var outcome: String
    var duration: Double?
}

nonisolated struct NFCRecordData: Codable, Equatable, Identifiable, Sendable {
    var id: Int
    var format: UInt8
    var type: Data
    var identifier: Data
    var payload: Data
    var decoded: String?
    var link: URL?
    var byteCount: Int { type.count + identifier.count + payload.count }
    var isValid: Bool {
        id >= 0 && format <= 7 && type.count <= 255 && identifier.count <= 255 && payload.count <= 1_048_576
            && (decoded?.utf8.count ?? 0) <= 2_097_152 && (link?.absoluteString.utf8.count ?? 0) <= 1_048_576
    }
}

nonisolated struct NFCReadData: Codable, Equatable, Sendable {
    var protocolName: String
    var identifier: Data?
    var manufacturer: String?
    var status: String
    var capacity: Int?
    var messageBytes: Int?
    var records: [NFCRecordData]
    var isValid: Bool {
        protocolName.count <= 200 && status.count <= 200 && (identifier?.count ?? 0) <= 256
            && (capacity.map { $0 >= 0 && $0 <= 16_777_216 } ?? true)
            && (messageBytes.map { $0 >= 0 && $0 <= 1_048_576 } ?? true)
            && records.count <= 512 && records.allSatisfy(\.isValid)
            && records.reduce(0, { $0 + $1.byteCount }) <= 1_048_576
    }
}

nonisolated struct RequestPhase: Codable, Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var start: Double
    var end: Double
    var duration: Double { max(0, end - start) }
    var isValid: Bool { !id.isEmpty && id.count <= 100 && name.count <= 100 && start.isFinite && end.isFinite && start >= 0 && end >= start }
}

nonisolated struct RequestTransaction: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var phases: [RequestPhase]
    var protocolName: String?
    var reused: Bool
    var cellular: Bool
    var cached: Bool
    var status: Int?
    var host: String
    var isValid: Bool { phases.count <= 30 && phases.allSatisfy(\.isValid) && host.count <= 1000 && (protocolName?.count ?? 0) <= 100 }
}

nonisolated struct NetworkProbe: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var date: Date
    var elapsed: Double
    var durationMS: Double
    var status: Int?
    var error: String?
    var transactions: [RequestTransaction]
    var receivedBytes: Int64 = 0
    var sentBytes: Int64 = 0
    var placement: RoomPlacement?
    var succeeded: Bool { error == nil && status.map { (200..<300).contains($0) } == true }
    var verifiedCellular: Bool { !transactions.isEmpty && transactions.allSatisfy { $0.cellular && !$0.cached } }
    var isValid: Bool {
        durationMS.isFinite && durationMS >= 0 && elapsed.isFinite && elapsed >= 0 && transactions.count <= 100
            && transactions.allSatisfy(\.isValid) && (placement?.isValid ?? true) && receivedBytes >= 0 && sentBytes >= 0
            && (error?.count ?? 0) <= 4000
    }
}

nonisolated struct DepthEvidence: Codable, Equatable, Sendable {
    var width: Int
    var height: Int
    var meters: [Float?]
    var confidence: [UInt8]
    var minimum: Float
    var maximum: Float
    var cameraPose: SpatialTransform
    /// fx, fy, cx, cy for this retained downsampled depth grid, in pixels.
    var intrinsics: [Float]?
    var centerPoint: SpatialVector?
    var isValid: Bool {
        width > 0 && height > 0 && width <= 1024 && height <= 1024 && meters.count == width * height
            && (confidence.isEmpty || confidence.count == meters.count) && confidence.allSatisfy { $0 <= 2 }
            && minimum.isFinite && maximum.isFinite && minimum < maximum && cameraPose.isValid
            && meters.allSatisfy { $0.map { $0.isFinite && $0 > 0 } ?? true }
            && (intrinsics.map { $0.count == 4 && $0.allSatisfy(\.isFinite) && $0[0] > 0 && $0[1] > 0 } ?? true)
            && (centerPoint?.isFinite ?? true)
    }
}

nonisolated struct FieldCapture: Codable, Equatable, Identifiable, Sendable {
    var format = 1
    var id = UUID()
    var title: String
    var kind: FieldCaptureKind
    var date = Date()
    var source: String
    var method: String
    var metrics: [FieldMetric] = []
    var samples: [FieldSample] = []
    var diagnostics: [CaptureDiagnostic] = []
    var metadata: [String: String] = [:]
    var nfc: NFCReadData?
    var probes: [NetworkProbe] = []
    var depth: DepthEvidence?
    var surface: SurfaceFit?
    var forecasts: [CellularForecast]?
    var cellularHistory: CellularHistory?
    var dimensions: [SpatialDimension]?
    var placement: RoomPlacement?
    var demonstration = false
    var isValid: Bool {
        format == 1 && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 200
            && !method.isEmpty && method.count <= 8000 && source.count <= 8000
            && metrics.count <= 100 && metrics.allSatisfy { $0.value.isFinite && $0.title.count <= 200 && $0.unit.count <= 100 && $0.id.count <= 200 && $0.qualifier.count <= 1000 }
            && Set(metrics.map(\.id)).count == metrics.count
            && samples.count <= 50_000 && samples.allSatisfy { $0.elapsed.isFinite && $0.values.count <= 100 && $0.detail.count <= 4000 && $0.values.values.allSatisfy(\.isFinite) && ($0.placement?.isValid ?? true) }
            && probes.count <= 1000 && probes.allSatisfy(\.isValid) && (nfc?.isValid ?? true)
            && diagnostics.count <= 1000 && diagnostics.allSatisfy { $0.step.count <= 200 && $0.outcome.count <= 4000 && ($0.duration.map { $0.isFinite && $0 >= 0 } ?? true) }
            && metadata.count <= 200 && metadata.allSatisfy { $0.key.count <= 200 && $0.value.count <= 16_000 }
            && (depth?.isValid ?? true) && (surface?.isValid ?? true) && (placement?.isValid ?? true)
            && (forecasts?.count ?? 0) <= 1000 && (forecasts?.allSatisfy(\.isValid) ?? true) && (cellularHistory?.isValid ?? true)
            && (dimensions?.count ?? 0) <= 1000 && (dimensions?.allSatisfy(\.isValid) ?? true)
    }
    static func reading(_ point: MeasurementPoint, kind: InstrumentKind, source: MeasurementSource) -> Self {
        Self(title: kind.title, kind: .reading, date: point.date, source: source.reportName, method: kind.method,
             metrics: [FieldMetric(id: kind.rawValue, title: kind.title, value: point.value, unit: kind.unit)],
             placement: point.placement)
    }
}

nonisolated struct FieldCaptureIndex: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var kind: FieldCaptureKind
    var date: Date
    var source: String
    var metrics: [FieldMetric]
    var placement: RoomPlacement?
    var demonstration: Bool
    var roomRevisionIDs: [UUID]?
    init(_ capture: FieldCapture) {
        id = capture.id; title = capture.title; kind = capture.kind; date = capture.date; source = capture.source
        metrics = capture.metrics; placement = capture.placement; demonstration = capture.demonstration
        var revisions = Set(capture.samples.compactMap { $0.placement?.revisionID } + capture.probes.compactMap { $0.placement?.revisionID })
        if let placement { revisions.insert(placement.revisionID) }
        roomRevisionIDs = revisions.isEmpty ? nil : revisions.sorted { $0.uuidString < $1.uuidString }
    }
}

nonisolated enum FieldStatistics {
    static func percentile(_ values: [Double], fraction: Double) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty else { return nil }
        let position = min(1, max(0, fraction)) * Double(sorted.count - 1)
        let lower = Int(position), upper = min(sorted.count - 1, lower + 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }
    static func networkMetrics(_ probes: [NetworkProbe], cellularOnly: Bool = false) -> [FieldMetric] {
        let eligible = probes.filter { !cellularOnly || $0.verifiedCellular }
        let values = eligible.filter(\.succeeded).map(\.durationMS)
        var result = [FieldMetric(id: "attempts", title: "Attempts", value: Double(probes.count), unit: "requests"),
                      FieldMetric(id: "failed", title: "Request failures", value: Double(probes.filter { !$0.succeeded }.count), unit: "requests")]
        if cellularOnly { result.append(FieldMetric(id: "verified", title: "Verified cellular", value: Double(eligible.count), unit: "requests")) }
        if let median = percentile(values, fraction: 0.5), let p95 = percentile(values, fraction: 0.95), let maximum = values.max() {
            result += [FieldMetric(id: "median", title: "Median", value: median, unit: "ms"),
                       FieldMetric(id: "p95", title: "p95", value: p95, unit: "ms"),
                       FieldMetric(id: "maximum", title: "Observed maximum", value: maximum, unit: "ms"),
                       FieldMetric(id: "variation", title: "p95 − median", value: p95 - median, unit: "ms")]
        }
        return result
    }
}
