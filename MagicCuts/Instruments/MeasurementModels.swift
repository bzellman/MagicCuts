import Foundation

nonisolated enum InstrumentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case bluetooth, tilt, vibration, rotation, magnetic, pressure, altitude, heading, speed, sound, network, battery
    var id: String { rawValue }
    var title: String {
        switch self {
        case .bluetooth: "Bluetooth"
        case .tilt: "Level"
        case .vibration: "Vibration"
        case .rotation: "Rotation"
        case .magnetic: "Magnetic field"
        case .pressure: "Pressure"
        case .altitude: "Elevation change"
        case .heading: "Compass"
        case .speed: "Speed"
        case .sound: "Sound level"
        case .network: "Connection"
        case .battery: "Battery"
        }
    }
    var symbol: String {
        switch self {
        case .bluetooth: "wave.3.right"
        case .tilt: "level"
        case .vibration: "waveform.path"
        case .rotation: "gyroscope"
        case .magnetic: "sensor"
        case .pressure: "barometer"
        case .altitude: "mountain.2"
        case .heading: "location.north.circle"
        case .speed: "speedometer"
        case .sound: "waveform"
        case .network: "network"
        case .battery: "battery.100percent"
        }
    }
    var unit: String {
        switch self {
        case .bluetooth: "dBm"
        case .tilt, .heading: "°"
        case .vibration: "g RMS"
        case .rotation: "°/s"
        case .magnetic: "µT"
        case .pressure: "hPa"
        case .altitude: "m"
        case .speed: "m/s"
        case .sound: "dBFS"
        case .network: "ms"
        case .battery: "%"
        }
    }
    var deltaUnit: String { self == .bluetooth ? "dB" : unit }
    var group: String {
        switch self {
        case .bluetooth, .network: "Connectivity"
        case .tilt, .vibration, .rotation, .magnetic: "Motion"
        case .pressure, .altitude, .heading, .speed: "Environment"
        case .sound: "Audio"
        case .battery: "Device"
        }
    }
    var summary: String {
        switch self {
        case .bluetooth: "Find a useful threshold and understand signal variation."
        case .tilt: "Align a surface and compare it to your own reference."
        case .vibration: "Compare movement strength and repeated vibration."
        case .rotation: "Measure how quickly your device is turning."
        case .magnetic: "Observe the local magnetic field and changes from a reference."
        case .pressure: "Measure air pressure and changes during a session."
        case .altitude: "Track barometric height change from the start of a session."
        case .heading: "Find a magnetic bearing and mark a direction."
        case .speed: "Read location-based speed with accuracy and freshness."
        case .sound: "Compare digital microphone levels and find clipping."
        case .network: "Measure response time to an endpoint you choose."
        case .battery: "Record charge, power and thermal-state changes."
        }
    }
    var method: String {
        switch self {
        case .bluetooth: "Received Bluetooth advertisement power. It is not a distance measurement."
        case .tilt: "Tilt from the device's gravity vector. Flat face-up is zero; a saved baseline is your reference."
        case .vibration: "Root mean square of gravity-separated user acceleration over the latest one second."
        case .rotation: "Magnitude of the device rotation-rate vector."
        case .magnetic: "Magnitude of the calibrated magnetic-field vector. This does not identify metals or objects."
        case .pressure: "Device barometer pressure, converted from kilopascals to hectopascals."
        case .altitude: "Barometric relative altitude since the first reading in this session."
        case .heading: "Magnetic heading. Statistics unwrap around the circular mean so north does not become south; interval endpoints may extend past 0° or 360°. Nearby magnets and calibration quality affect the result."
        case .speed: "Core Location speed. Invalid values and readings older than five seconds are excluded."
        case .sound: "Microphone RMS in digital full-scale decibels. This is not a calibrated sound-pressure or hearing-safety meter."
        case .network: "Elapsed time for an uncached HTTP HEAD request. This includes application and server work; it is not ICMP ping."
        case .battery: "System-reported battery charge. Thermal state is categorical, not a temperature reading."
        }
    }
    var defaultRange: ClosedRange<Double> {
        switch self {
        case .bluetooth: -100 ... -40
        case .tilt: 0 ... 10
        case .vibration: 0 ... 0.2
        case .rotation: 0 ... 180
        case .magnetic: 0 ... 100
        case .pressure: 950 ... 1050
        case .altitude: -10 ... 10
        case .heading: 0 ... 360
        case .speed: 0 ... 15
        case .sound: -80 ... 0
        case .network: 0 ... 500
        case .battery: 0 ... 100
        }
    }
    var decimals: Int { switch self { case .vibration: 3; case .tilt, .rotation, .magnetic, .pressure, .altitude, .speed: 1; default: 0 } }
    var maximumAge: TimeInterval { switch self { case .pressure, .altitude, .battery: 20; case .network: 10; default: 5 } }
    func formatted(_ value: Double, signed: Bool = false) -> String {
        guard value.isFinite else { return "—" }
        return value.formatted(.number.precision(.fractionLength(decimals)).sign(strategy: signed ? .always() : .automatic))
    }
    func displayRange(values: [Double]) -> ClosedRange<Double> {
        if self == .heading || self == .battery { return defaultRange }
        let finite = values.filter(\.isFinite)
        guard let low = finite.min(), let high = finite.max() else { return defaultRange }
        let span = defaultRange.upperBound - defaultRange.lowerBound
        let step = pow(10, floor(log10(span / 6)))
        return min(defaultRange.lowerBound, floor(low / step) * step) ... max(defaultRange.upperBound, ceil(high / step) * step)
    }
}

nonisolated struct MeasurementPoint: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let elapsed: TimeInterval
    let date: Date
    let value: Double
    let segment: Int
    var auxiliary: [String: Double]
    var placement: RoomPlacement?
    init(id: UUID = UUID(), elapsed: TimeInterval, date: Date = .now, value: Double, segment: Int = 0, auxiliary: [String: Double] = [:], placement: RoomPlacement? = nil) {
        self.id = id
        self.elapsed = elapsed
        self.date = date
        self.value = value
        self.segment = segment
        self.auxiliary = auxiliary
        self.placement = placement
    }
}

nonisolated struct CaptureEvent: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var elapsed: TimeInterval
    var text: String
}

nonisolated struct MeasurementSource: Codable, Equatable, Sendable {
    var id: String
    var name: String
    var deviceID: UUID?
    var serviceUUIDs: [String] = []
    var threshold: Double?
    var endpoint: String?
    static let phone = MeasurementSource(id: "this-device", name: "This device")
    static func bluetooth(_ device: DeviceInfo) -> Self {
        MeasurementSource(id: device.id, name: device.name, deviceID: device.radioUUID, serviceUUIDs: device.serviceUUIDs, threshold: Double(device.requiredSignalStrength))
    }
    var reportName: String {
        guard let endpoint, let url = URL(string: endpoint), let host = url.host else { return name }
        return host + url.path
    }
}

nonisolated struct RecordedSession: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var kind: InstrumentKind
    var source: MeasurementSource
    var startedAt: Date
    var endedAt: Date
    var points: [MeasurementPoint]
    var events: [CaptureEvent]
    var method: String
    var termination: String
    var metadata: [String: String]
    var reference: CalibrationProfile? = nil
    var duration: TimeInterval { max(0, endedAt.timeIntervalSince(startedAt)) }
    var summary: MeasurementSummary? { MeasurementMath.summary(points.map(\.value), kind: kind) }
}

nonisolated struct SessionIndexEntry: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var kind: InstrumentKind
    var sourceName: String
    var startedAt: Date
    var duration: TimeInterval
    var sampleCount: Int
    var median: Double?
    var roomRevisionIDs: [UUID]?
    init(_ session: RecordedSession) {
        id = session.id; title = session.title; kind = session.kind; sourceName = session.source.reportName
        startedAt = session.startedAt; duration = session.duration; sampleCount = session.points.count
        median = session.summary?.median
        let revisions = Set(session.points.compactMap { $0.placement?.revisionID })
        roomRevisionIDs = revisions.isEmpty ? nil : revisions.sorted { $0.uuidString < $1.uuidString }
    }
}

nonisolated struct CalibrationProfile: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var kind: InstrumentKind
    var sourceID: String
    var sourceName: String
    var date: Date
    var points: [MeasurementPoint]
    var summary: MeasurementSummary
    var metadata: [String: String]
    func matches(kind: InstrumentKind, source: MeasurementSource, metadata current: [String: String]) -> Bool {
        guard self.kind == kind, sourceID == source.id else { return false }
        guard metadata["installationID"] == current["installationID"] else { return false }
        for key in ["audioInput", "audioSampleRate", "referenceFrame"] {
            if metadata[key] != current[key] { return false }
        }
        return true
    }
}

nonisolated enum RuleComparison: String, Codable, CaseIterable, Sendable {
    case atLeast, atMost
    var title: String { self == .atLeast ? "At least" : "At most" }
    func passes(_ value: Double, threshold: Double) -> Bool { self == .atLeast ? value >= threshold : value <= threshold }
}

nonisolated struct WorkflowCondition: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var kind: InstrumentKind
    var source: MeasurementSource
    var comparison: RuleComparison
    var threshold: Double
    var window: Double = 5
}

nonisolated struct WorkflowRecipe: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var requiresAll = true
    var conditions: [WorkflowCondition]
    var createdAt = Date()
}

nonisolated struct DeviceGroup: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var deviceIDs: [UUID]
    var requiresAll = true
    var minimumMatches: Int? = nil
}

nonisolated struct FieldProtocolStep: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var complete = false
}

nonisolated struct FieldReport: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var title: String
    var location = ""
    var notes = ""
    var steps: [FieldProtocolStep] = []
    var sessionIDs: [UUID] = []
    var updatedAt = Date()
}

nonisolated struct WorkflowReading: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var title: String
    var value: Double?
    var unit: String
    var passed: Bool?
    var detail: String
}

nonisolated struct WorkflowOutcome: Codable, Equatable, Sendable {
    var readings: [WorkflowReading]
    var requiresAll: Bool
    var minimumMatches: Int? = nil
    var passed: Bool? {
        guard !readings.isEmpty else { return nil }
        let values = readings.compactMap(\.passed)
        if let minimumMatches {
            guard (1 ... readings.count).contains(minimumMatches) else { return nil }
            let matches = values.filter { $0 }.count
            if matches >= minimumMatches { return true }
            if matches + readings.count - values.count < minimumMatches { return false }
            return nil
        }
        if requiresAll {
            if values.contains(false) { return false }
            return values.count == readings.count ? true : nil
        }
        if values.contains(true) { return true }
        return values.count == readings.count ? false : nil
    }
}

nonisolated struct ProLibraryIndex: Codable, Sendable {
    var version = 1
    var sessions: [SessionIndexEntry] = []
    var profiles: [CalibrationProfile] = []
    var workflows: [WorkflowRecipe] = []
    var groups: [DeviceGroup] = []
    var reports: [FieldReport] = []
    var deviceSetups: [PortableDeviceSetup] = []
    var roomRevisions: [RoomRevisionIndex] = []
    var fieldCaptures: [FieldCaptureIndex] = []
    var sequence: Int64 = 0
    var versions: [String: LibraryVersion] = [:]

    init() {}
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        sessions = try values.decodeIfPresent([SessionIndexEntry].self, forKey: .sessions) ?? []
        profiles = try values.decodeIfPresent([CalibrationProfile].self, forKey: .profiles) ?? []
        workflows = try values.decodeIfPresent([WorkflowRecipe].self, forKey: .workflows) ?? []
        groups = try values.decodeIfPresent([DeviceGroup].self, forKey: .groups) ?? []
        reports = try values.decodeIfPresent([FieldReport].self, forKey: .reports) ?? []
        deviceSetups = try values.decodeIfPresent([PortableDeviceSetup].self, forKey: .deviceSetups) ?? []
        roomRevisions = try values.decodeIfPresent([RoomRevisionIndex].self, forKey: .roomRevisions) ?? []
        fieldCaptures = try values.decodeIfPresent([FieldCaptureIndex].self, forKey: .fieldCaptures) ?? []
        sequence = try values.decodeIfPresent(Int64.self, forKey: .sequence) ?? 0
        versions = try values.decodeIfPresent([String: LibraryVersion].self, forKey: .versions) ?? [:]
    }
}

nonisolated enum InstrumentError: LocalizedError, Equatable {
    case unavailable(String), denied(String), invalidEndpoint, noReadings, storage(String), requiresPro
    var errorDescription: String? {
        switch self {
        case .unavailable(let message), .denied(let message), .storage(let message): message
        case .invalidEndpoint: "Enter an http or https endpoint you own or have permission to test."
        case .noReadings: "No current readings were received. Check the source and try another measurement."
        case .requiresPro: "MagicCuts Pro is required. Open MagicCuts to purchase or restore Pro, then run this action again."
        }
    }
}
