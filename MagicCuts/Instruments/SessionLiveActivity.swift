import ActivityKit
import Foundation

@MainActor
final class SessionLiveActivity {
    private var activityID: String?
    private var work: Task<Void, Never>?
    private var lastUpdate = -Double.infinity
    private var generation = UUID()

    func start(id: UUID, kind: InstrumentKind, source: MeasurementSource) -> String? {
        guard (UserDefaults.standard.object(forKey: "showSessionLiveActivity") as? Bool) ?? true else { return nil }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return "Live Activities are unavailable or disabled. The recording is still available in MagicCuts." }
        let state = SessionActivityAttributes.ContentState(value: "—", unit: kind.unit, status: "Waiting for a reading", sampleCount: 0)
        do {
            let attributes = SessionActivityAttributes(sessionID: id, instrument: kind.title, symbol: kind.symbol, source: source.reportName)
            activityID = try Activity.request(attributes: attributes, content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(15)), pushType: nil).id
            generation = UUID(); lastUpdate = -.infinity
            return nil
        } catch { return "The Lock Screen session couldn't be started. Recording continues in MagicCuts. \(error.localizedDescription)" }
    }

    func update(kind: InstrumentKind, point: MeasurementPoint?, phase: InstrumentPhase, count: Int, force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard let activityID, force || now - lastUpdate >= 5 else { return }
        lastUpdate = now
        let state = SessionActivityAttributes.ContentState(value: point.map { kind.formatted($0.value) } ?? "—", unit: kind.unit, status: phase == .running ? "Measuring in MagicCuts" : phase.title, readingDate: point?.date, sampleCount: count)
        let previous = work, token = generation
        work = Task { [weak self] in
            await previous?.value
            guard self?.generation == token else { return }
            await Self.updateActivity(id: activityID, state: state, staleDate: phase.isActive ? (point?.date ?? .now).addingTimeInterval(kind.maximumAge) : nil)
        }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil; generation = UUID()
        let previous = work
        work = Task { await previous?.value; await Self.endActivity(id: activityID) }
    }

    // ActivityKit's Activity is not Sendable. Resolve each handle inside the
    // asynchronous operation instead of transferring a stored main-actor handle.
    nonisolated private static func updateActivity(id: String, state: SessionActivityAttributes.ContentState, staleDate: Date?) async {
        guard let activity = Activity<SessionActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.update(ActivityContent(state: state, staleDate: staleDate))
    }

    nonisolated private static func endActivity(id: String) async {
        guard let activity = Activity<SessionActivityAttributes>.activities.first(where: { $0.id == id }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    nonisolated static func endAbandoned() async {
        for activity in Activity<SessionActivityAttributes>.activities {
            var state = activity.content.state
            state.status = "Session interrupted · open MagicCuts to recover"
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(1800)))
        }
    }
}
