import Foundation
import Observation

@MainActor
@Observable
final class WorkflowRunner {
    private(set) var running = false
    private(set) var progress = ""
    private(set) var outcome: WorkflowOutcome?
    private(set) var failure: String?
    @ObservationIgnored private var task: Task<Void, Never>?

    func run(_ recipe: WorkflowRecipe, radio: any RadioScanning) {
        guard !running else { return }
        running = true; outcome = nil; failure = nil
        task = Task {
            defer { running = false; task = nil }
            do {
                try await ProAccess.require()
                outcome = try await Self.evaluate(recipe, radio: radio) { progress = $0 }
            } catch is CancellationError { failure = "Run cancelled. Partial readings were not used as a result." }
            catch { failure = error.localizedDescription }
        }
    }

    func run(_ group: DeviceGroup, devices: [DeviceInfo], radio: any RadioScanning) {
        guard !running else { return }
        running = true; outcome = nil; failure = nil; progress = "Observing the group for ten seconds"
        task = Task {
            defer { running = false; task = nil }
            do {
                try await ProAccess.require()
                outcome = try await Self.evaluate(group, devices: devices, radio: radio, duration: AppRuntime.testDuration)
            } catch is CancellationError { failure = "Run cancelled. Partial readings were not used as a result." }
            catch { failure = error.localizedDescription }
        }
    }

    func cancel() { task?.cancel() }

    static func evaluate(_ recipe: WorkflowRecipe, radio: any RadioScanning, progress: (String) -> Void = { _ in }) async throws -> WorkflowOutcome {
        guard !recipe.conditions.isEmpty, recipe.conditions.count <= 8,
              recipe.conditions.allSatisfy({ $0.threshold.isFinite && (1 ... 10).contains($0.window) }) else {
            throw InstrumentError.unavailable("This workflow contains an invalid condition. Edit and save it again.")
        }
        var readings: [WorkflowReading] = []
        for (index, condition) in recipe.conditions.enumerated() {
            try Task.checkCancellation()
            progress("\(index + 1) of \(recipe.conditions.count) · \(condition.kind.title)")
            do {
                let value = try await measure(condition.kind, source: condition.source, seconds: condition.window, radio: radio)
                readings.append(WorkflowReading(id: condition.id, title: condition.kind.title + " · " + condition.source.reportName, value: value, unit: condition.kind.unit, passed: condition.comparison.passes(value, threshold: condition.threshold), detail: "Median over \(condition.window.formatted())s · \(condition.comparison.title.lowercased()) \(condition.kind.formatted(condition.threshold)) \(condition.kind.unit)"))
            } catch is CancellationError { throw CancellationError() }
            catch {
                readings.append(WorkflowReading(id: condition.id, title: condition.kind.title + " · " + condition.source.reportName, value: nil, unit: condition.kind.unit, passed: nil, detail: error.localizedDescription))
            }
        }
        return WorkflowOutcome(readings: readings, requiresAll: recipe.requiresAll)
    }

    static func measure(_ kind: InstrumentKind, source: MeasurementSource, seconds: Double, radio: any RadioScanning) async throws -> Double {
        guard (1 ... 10).contains(seconds) else { throw InstrumentError.unavailable("Choose a measurement window from one to ten seconds.") }
        let engine = InstrumentEngine()
        defer { engine.stop() }
        await engine.start(kind: kind, source: source, radio: radio)
        let began = ContinuousClock.now
        // Permission and sensor readiness precede the measurement window.
        while engine.latest == nil {
            try Task.checkCancellation()
            if let explanation = engine.phase.explanation { throw InstrumentError.unavailable(explanation) }
            guard began.duration(to: .now) < .seconds(16) else { throw InstrumentError.noReadings }
            try await Task.sleep(for: .milliseconds(100))
        }
        try await Task.sleep(for: AppRuntime.isUITesting ? .milliseconds(600) : .seconds(seconds))
        try Task.checkCancellation()
        if let explanation = engine.phase.explanation { throw InstrumentError.unavailable(explanation) }
        guard let latest = engine.latest,
              engine.demonstration || abs(latest.date.timeIntervalSinceNow) <= kind.maximumAge,
              let summary = engine.summary else { throw InstrumentError.noReadings }
        if kind != .battery && summary.count < 2 { throw InstrumentError.noReadings }
        return summary.median
    }

    static func evaluate(_ group: DeviceGroup, devices: [DeviceInfo], radio: any RadioScanning, duration: Duration = .seconds(10)) async throws -> WorkflowOutcome {
        guard !group.deviceIDs.isEmpty else { throw InstrumentError.unavailable("This group has no devices. Edit it in MagicCuts.") }
        let members = group.deviceIDs.map { id in devices.first { $0.id == id.uuidString } }
        let known = members.compactMap { $0 }
        // Every member is observed in one shared window. No service filter if a member has none.
        let services = known.contains { $0.serviceUUIDs.isEmpty } ? [] : Array(Set(known.flatMap(\.serviceUUIDs)))
        let session = radio.session(services: services)
        defer { session.cancel() }
        var timer: Task<Void, Never>?
        defer { timer?.cancel() }
        var completed = false
        var readyAt: Date?
        var samples: [UUID: [Int]] = [:]
        do {
            for try await event in session.events {
                try Task.checkCancellation()
                switch event {
                case .ready(let date):
                    guard readyAt == nil else { continue }
                    readyAt = date
                    timer = Task {
                        do { try await Task.sleep(for: duration) } catch { return }
                        completed = true; session.cancel()
                    }
                case .device(let device):
                    guard let readyAt, device.lastSeen >= readyAt, device.lastSeen <= Date().addingTimeInterval(1),
                          group.deviceIDs.contains(device.id), SignalSample.isValid(device.rssi) else { continue }
                    samples[device.id, default: []].append(device.rssi)
                }
            }
        } catch is CancellationError {
            if !completed { throw CancellationError() }
        }
        try Task.checkCancellation()
        guard completed else { throw BluetoothError.unavailable }
        let readings = zip(group.deviceIDs, members).map { id, device -> WorkflowReading in
            guard let device else { return WorkflowReading(id: id, title: "Deleted device", value: nil, unit: "dBm", passed: nil, detail: "A member is no longer saved. Edit this group.") }
            let values = (samples[id] ?? []).map(Double.init)
            guard (-100 ... -1).contains(device.requiredSignalStrength), values.count >= 2, let summary = MeasurementMath.summary(values) else {
                return WorkflowReading(id: id, title: device.name, value: nil, unit: "dBm", passed: nil, detail: "Not enough valid readings. Absence is not treated as away.")
            }
            return WorkflowReading(id: id, title: device.name, value: summary.median, unit: "dBm", passed: summary.median >= Double(device.requiredSignalStrength), detail: "\(values.count) readings · median compared with \(device.requiredSignalStrength) dBm")
        }
        return WorkflowOutcome(readings: readings, requiresAll: group.requiresAll, minimumMatches: group.minimumMatches)
    }
}
