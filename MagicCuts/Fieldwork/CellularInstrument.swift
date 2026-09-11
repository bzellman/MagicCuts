import Foundation
import Observation
import CoreTelephony
import MetricKit
#if canImport(WirelessInsights)
import WirelessInsights
#endif
import CryptoKit

nonisolated struct CellularForecast: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var receivedAt: Date
    var startsAt: Date
    var duration: Double
    var impact: String
    var predictionConfidence: String
    var startConfidence: String
    var durationConfidence: String
    var endsAt: Date { startsAt.addingTimeInterval(duration) }
    var isValid: Bool { duration.isFinite && duration >= 0 && duration <= 7 * 24 * 3600 }
}

nonisolated struct CellularHistoryBucket: Codable, Equatable, Identifiable, Sendable {
    var id: Int
    var lowerBars: Double
    var upperBars: Double
    var count: Int
    var isValid: Bool { lowerBars.isFinite && upperBars.isFinite && lowerBars <= upperBars && count >= 0 }
}

nonisolated struct CellularHistory: Codable, Equatable, Sendable {
    var beginsAt: Date
    var endsAt: Date
    var receivedAt: Date
    var buckets: [CellularHistoryBucket]
    var totalCount: Int { buckets.reduce(0) { $0 + $1.count } }
    var isValid: Bool { endsAt >= beginsAt && buckets.count <= 100 && buckets.allSatisfy(\.isValid) && buckets.allSatisfy { $0.count <= 1_000_000_000 } }
    func record(installationID: String) -> FieldCapture {
        let digest = SHA256.hash(data: Data("\(installationID)|\(beginsAt.timeIntervalSince1970)|\(endsAt.timeIntervalSince1970)|cellular-history".utf8))
        let bytes = Array(digest.prefix(16))
        let id = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
        return FieldCapture(id: id, title: "Cellular history", kind: .cellular, date: endsAt, source: "MetricKit · this installation",
            method: "Delayed MetricKit aggregate of application runtime by cellular condition. Bucket counts describe this app's observed interval; they are not current signal readings or a general coverage survey.",
            metadata: ["Received": receivedAt.formatted(date: .abbreviated, time: .standard)], cellularHistory: self)
    }
}

nonisolated struct CellularTechnology: Identifiable, Equatable, Sendable {
    var id: Int
    var name: String
    var dataService: Bool
}

@MainActor @Observable
final class CellularInstrument {
    private(set) var technologies: [CellularTechnology] = []
    private(set) var technologyDate: Date?
    private(set) var technologyEvents: [FieldSample] = []
    @ObservationIgnored var positionProvider: ((Date) -> RoomPlacement?)?
    private(set) var forecasts: [CellularForecast] = []
    private(set) var forecastDate: Date?
    private(set) var forecastStatus = "Predictions have not been requested"
    private(set) var forecasting = false
    private(set) var historyFailure: String?
    @ObservationIgnored private let telephony = CTTelephonyNetworkInfo()
    @ObservationIgnored private var notification: NSObjectProtocol?
    @ObservationIgnored private var subscriber: CellularMetricSubscriber?
    #if canImport(WirelessInsights)
    @ObservationIgnored private var predictionProvider: ServicePredictionProvider?
    #endif
    @ObservationIgnored private var predictionTask: Task<Void, Never>?
    @ObservationIgnored private var forecastGeneration = UUID()

    func start(library: ProLibrary) {
        guard notification == nil else { return }
        refreshTechnology()
        notification = NotificationCenter.default.addObserver(forName: .CTServiceRadioAccessTechnologyDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshTechnology() }
        }
        let subscriber = CellularMetricSubscriber { [weak self, weak library] history in
            Task { @MainActor [weak self, weak library] in
                guard let self, let library else { return }
                do {
                    let installationID = try await library.archive.installationID()
                    for item in history where item.isValid {
                        let capture = item.record(installationID: installationID)
                        guard !library.index.fieldCaptures.contains(where: { $0.id == capture.id }) else { continue }
                        try await library.save(capture)
                    }
                    self.historyFailure = nil
                } catch { self.historyFailure = "Cellular history couldn't be saved: \(error.localizedDescription)" }
            }
        }
        self.subscriber = subscriber
        MXMetricManager.shared.add(subscriber)
        subscriber.didReceive(MXMetricManager.shared.pastPayloads)
    }
    func stop() {
        stopForecasts()
        if let notification { NotificationCenter.default.removeObserver(notification) }; notification = nil
        if let subscriber { MXMetricManager.shared.remove(subscriber) }; subscriber = nil
    }
    func refreshTechnology() {
        let values = telephony.serviceCurrentRadioAccessTechnology ?? [:]
        let latest = values.keys.sorted().enumerated().map { index, key in
            CellularTechnology(id: index + 1, name: Self.technologyName(values[key] ?? ""), dataService: key == telephony.dataServiceIdentifier)
        }
        let date = Date()
        if technologyEvents.isEmpty || latest != technologies {
            let detail = latest.isEmpty ? "Technology unavailable" : latest.map { "Service \($0.id): \($0.name)\($0.dataService ? " · Data service" : "")" }.joined(separator: "; ")
            technologyEvents.append(FieldSample(date: date, elapsed: max(0, date.timeIntervalSince(technologyEvents.first?.date ?? date)), values: [:], detail: detail, placement: positionProvider?(date)))
            if technologyEvents.count > 1000 { technologyEvents.removeFirst(technologyEvents.count - 1000) }
        }
        technologies = latest; technologyDate = date
    }
    var technologyCapture: FieldCapture? {
        guard let date = technologyDate else { return nil }
        return FieldCapture(title: "Reported cellular technology", kind: .cellular, date: date, source: "Core Telephony",
            method: "Changes in reported radio registration during this app session. Service numbers are local display labels. Registration does not measure signal strength or prove a request route. Gaps between events have no sampled values.",
            samples: technologyEvents, metadata: ["observedContext": "Most recent 1,000 changes"], placement: positionProvider?(date))
    }
    func startForecasts() {
        stopForecasts(); forecasts = []; forecastDate = nil
        #if !canImport(WirelessInsights)
        forecastStatus = "Service predictions require a supported physical device."
        return
        #else
        let provider = ServicePredictionProvider(); predictionProvider = provider
        forecasting = true; forecastStatus = "Waiting for service predictions"
        let token = forecastGeneration
        predictionTask = Task { [weak self] in
            do {
                for try await values in provider.servicePredictions {
                    guard let self, self.forecastGeneration == token, !Task.isCancelled else { return }
                    let date = Date()
                    self.forecasts = values.map { value in
                        CellularForecast(receivedAt: date, startsAt: value.predictedStartTime, duration: value.predictedInterval,
                            impact: Self.impactName(value.impact), predictionConfidence: Self.confidenceName(value.confidenceScore.prediction),
                            startConfidence: Self.confidenceName(value.confidenceScore.startTime), durationConfidence: Self.confidenceName(value.confidenceScore.duration))
                    }.filter(\.isValid).sorted { $0.startsAt < $1.startsAt }
                    self.forecastDate = date
                    self.forecastStatus = self.forecasts.isEmpty ? "No service degradation predictions returned" : "Latest service predictions"
                }
                guard let self, self.forecastGeneration == token else { return }; self.forecasting = false
            } catch {
                guard let self, self.forecastGeneration == token, !Task.isCancelled else { return }
                self.forecasting = false
                if let failure = error as? ServicePredictionError, failure == .unsupportedDevice {
                    self.forecastStatus = "Service predictions are not supported on this device."
                } else { self.forecastStatus = "Service predictions are unavailable. Check this build's capability and try again: \(error.localizedDescription)" }
            }
        }
        #endif
    }
    func stopForecasts() {
        forecastGeneration = UUID(); predictionTask?.cancel(); predictionTask = nil
        #if canImport(WirelessInsights)
        predictionProvider = nil
        #endif
        if forecasting { forecastStatus = "Prediction updates stopped" }; forecasting = false
    }
    var forecastCapture: FieldCapture? {
        guard let forecastDate else { return nil }
        return FieldCapture(title: "Cellular forecast", kind: .cellular, date: forecastDate, source: "WirelessInsights",
            method: "System forecasts of possible service degradation, received at the capture time. A predicted event is not a measured outage. Missing predictions do not establish healthy service.",
            metadata: ["status": forecastStatus], forecasts: forecasts)
    }
    nonisolated static func technologyName(_ raw: String) -> String {
        switch raw {
        case CTRadioAccessTechnologyLTE: "LTE"
        case CTRadioAccessTechnologyNR: "5G NR"
        case CTRadioAccessTechnologyNRNSA: "5G NR non-standalone"
        case CTRadioAccessTechnologyGPRS: "GPRS"
        case CTRadioAccessTechnologyEdge: "EDGE"
        case CTRadioAccessTechnologyWCDMA: "WCDMA"
        case CTRadioAccessTechnologyHSDPA: "HSDPA"
        case CTRadioAccessTechnologyHSUPA: "HSUPA"
        case CTRadioAccessTechnologyCDMA1x: "CDMA 1x"
        case CTRadioAccessTechnologyCDMAEVDORev0: "EV-DO Rev. 0"
        case CTRadioAccessTechnologyCDMAEVDORevA: "EV-DO Rev. A"
        case CTRadioAccessTechnologyCDMAEVDORevB: "EV-DO Rev. B"
        case CTRadioAccessTechnologyeHRPD: "eHRPD"
        default: "Technology unavailable"
        }
    }
    #if canImport(WirelessInsights)
    private static func confidenceName(_ confidence: ServicePrediction.Confidence) -> String {
        switch confidence { case .low: "Low"; case .medium: "Medium"; case .high: "High"; @unknown default: "Unknown" }
    }
    private static func impactName(_ impact: ServicePrediction.Impact) -> String {
        switch impact { case .low: "Low"; case .medium: "Medium"; case .high: "High"; @unknown default: "Unknown" }
    }
    #endif
}

// MetricKit owns the delivery queue. Convert framework objects into Sendable value data before handing them to the UI.
nonisolated private final class CellularMetricSubscriber: NSObject, MXMetricManagerSubscriber {
    let onHistory: @Sendable ([CellularHistory]) -> Void
    init(onHistory: @escaping @Sendable ([CellularHistory]) -> Void) { self.onHistory = onHistory }
    func didReceive(_ payloads: [MXMetricPayload]) {
        let history = payloads.compactMap { payload -> CellularHistory? in
            guard let metric = payload.cellularConditionMetrics else { return nil }
            let buckets = metric.histogrammedCellularConditionTime.bucketEnumerator.allObjects.enumerated().compactMap { index, object -> CellularHistoryBucket? in
                guard let bucket = object as? MXHistogramBucket<MXUnitSignalBars> else { return nil }
                return CellularHistoryBucket(id: index, lowerBars: bucket.bucketStart.value, upperBars: bucket.bucketEnd.value, count: bucket.bucketCount)
            }
            return CellularHistory(beginsAt: payload.timeStampBegin, endsAt: payload.timeStampEnd, receivedAt: .now, buckets: buckets)
        }
        if !history.isEmpty { onHistory(history) }
    }
}
