import Foundation

nonisolated struct SignalSample: Codable, Equatable, Sendable {
    let date: Date
    let rssi: Int
    static func isValid(_ value: Int) -> Bool { (-126 ... -1).contains(value) }
}

nonisolated enum TestPosition: String, Codable, CaseIterable, Sendable {
    case nearby, away, draft
    var title: String { switch self { case .nearby: "Nearby"; case .away: "Away"; case .draft: "Draft" } }
}

nonisolated enum SampleClassification: String, Codable, Sendable {
    case above, below, mixed, notObserved, sparse
    var title: String {
        switch self {
        case .above: "All samples above threshold"
        case .below: "All samples below threshold"
        case .mixed: "Signal crosses the threshold"
        case .notObserved: "Device not observed"
        case .sparse: "Not enough readings"
        }
    }
}

nonisolated struct TestEvidence: Codable, Equatable, Sendable {
    let startedAt: Date
    let endedAt: Date
    let threshold: Int
    let position: TestPosition
    let isDraft: Bool
    let samples: [SignalSample]
    let failure: String?
    var classification: SampleClassification {
        if samples.isEmpty { return .notObserved }
        if samples.count < 2 { return .sparse }
        let passing = samples.filter { $0.rssi >= threshold }.count
        return passing == samples.count ? .above : passing == 0 ? .below : .mixed
    }
    var validated: Bool {
        failure == nil && !isDraft && ((position == .nearby && classification == .above) || (position == .away && classification == .below))
    }
    var summary: String { failure ?? classification.title }
    var range: String {
        guard let low = samples.map(\.rssi).min(), let high = samples.map(\.rssi).max() else { return "No readings" }
        return "\(low) to \(high) dBm"
    }
}

nonisolated enum BluetoothError: LocalizedError, Equatable {
    case poweredOff, denied, unsupported, initialization, resetting, deletedDevice, storage, unavailable, invalidThreshold
    var errorDescription: String? {
        switch self {
        case .invalidThreshold: "This device has an unusable threshold. Open MagicCuts, edit its threshold, and apply a value from −100 to −1 dBm."
        case .poweredOff: "Bluetooth is off. Turn it on and try again."
        case .denied: "Bluetooth access is unavailable. Check MagicCuts permissions in Settings."
        case .unsupported: "Bluetooth scanning is not supported on this device."
        case .initialization: "Bluetooth did not become ready. Try again."
        case .resetting: "Bluetooth is restarting. Wait a moment and try again."
        case .deletedDevice: "This device is no longer saved. Choose another device in Shortcuts."
        case .storage: "Device settings could not be read. Open MagicCuts to repair Shortcuts access."
        case .unavailable: "Bluetooth is unavailable. Try again."
        }
    }
}

nonisolated struct RadioDevice: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var rssi: Int
    var services: [String]
    var lastSeen: Date
    var displayName: String { name.isEmpty ? "Unnamed device · \(id.uuidString.prefix(4))" : name }
}

nonisolated enum RadioEvent: Sendable { case ready(Date), device(RadioDevice) }

nonisolated enum ServiceIdentifier {
    static func isValid(_ value: String) -> Bool {
        if value.count == 4 || value.count == 8 {
            return value.utf8.allSatisfy { byte in
                (48...57).contains(byte) || (65...70).contains(byte) || (97...102).contains(byte)
            }
        }
        return value.count == 36 && UUID(uuidString: value) != nil
    }
}
