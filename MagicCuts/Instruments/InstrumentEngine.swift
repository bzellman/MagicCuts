import Foundation
import Observation
import CoreMotion
import CoreLocation
import AVFAudio
import Network
import UIKit

nonisolated enum InstrumentPhase: Equatable {
    case idle, starting, running, paused, finished, unavailable(String), denied(String), failed(String)
    var isActive: Bool { self == .starting || self == .running }
    var title: String {
        switch self {
        case .idle: "Ready to measure"
        case .starting: "Waiting for a reading"
        case .running: "Live"
        case .paused: "Paused"
        case .finished: "Measurement ended"
        case .unavailable: "Unavailable"
        case .denied: "Permission needed"
        case .failed: "Measurement interrupted"
        }
    }
    var explanation: String? {
        switch self { case .unavailable(let value), .denied(let value), .failed(let value): value; default: nil }
    }
}

nonisolated private struct MotionReading: Sendable {
    var time: Double
    var gravityX: Double; var gravityY: Double; var gravityZ: Double
    var x: Double; var y: Double; var z: Double
    var rotation: Double
    var field: Double
    var fieldAccuracy: Int
}

nonisolated private final class ProbeDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
@Observable
final class InstrumentEngine: NSObject, CLLocationManagerDelegate {
    private(set) var kind: InstrumentKind = .bluetooth
    private(set) var source = MeasurementSource.phone
    private(set) var phase: InstrumentPhase = .idle
    private(set) var points: [MeasurementPoint] = []
    private(set) var events: [CaptureEvent] = []
    private(set) var metadata: [String: String] = [:]
    private(set) var spectrum: MeasurementSpectrum?
    private(set) var recording = false
    private(set) var recordingCount = 0
    private(set) var recordingDuration: TimeInterval = 0
    private(set) var completedRequests = 0
    private(set) var failedRequests = 0
    private(set) var pathDescription = "No path observation"
    private(set) var demonstration = false
    private(set) var termination = "Stopped by you"
    private(set) var recordingID: UUID?
    private(set) var persistenceWarning: String?
    private(set) var liveActivityWarning: String?
    var latest: MeasurementPoint? { points.last }
    var summary: MeasurementSummary? { MeasurementMath.summary(points.map(\.value), kind: kind) }

    @ObservationIgnored private var motion = CMMotionManager()
    @ObservationIgnored private var altimeter = CMAltimeter()
    @ObservationIgnored private var location: CLLocationManager?
    @ObservationIgnored private var audio: AVAudioEngine?
    @ObservationIgnored private var pathMonitor: NWPathMonitor?
    @ObservationIgnored private var requestSession: URLSession?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var readinessTimeout: Task<Void, Never>?
    @ObservationIgnored private var radioSession: RadioSession?
    @ObservationIgnored private var audioInterruption: NSObjectProtocol?
    @ObservationIgnored private var audioRouteChange: NSObjectProtocol?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var origin = ProcessInfo.processInfo.systemUptime
    @ObservationIgnored private var lastPublished = -Double.infinity
    @ObservationIgnored private var motionWindow: [MotionReading] = []
    @ObservationIgnored private var lastSpectrum = 0.0
    @ObservationIgnored private var segment = 0
    @ObservationIgnored private var recordedPoints: [MeasurementPoint] = []
    @ObservationIgnored private var recordedEvents: [CaptureEvent] = []
    @ObservationIgnored private var recordingStart: Date?
    @ObservationIgnored private var recordingOrigin = 0.0
    @ObservationIgnored private var batteryMonitoringWasEnabled = false
    @ObservationIgnored private let archive: InstrumentArchive
    @ObservationIgnored var positionProvider: ((Date) -> RoomPlacement?)?
    @ObservationIgnored private var checkpointTask: Task<Void, Never>?
    @ObservationIgnored private var lastCheckpoint = -Double.infinity
    @ObservationIgnored private let liveActivity = SessionLiveActivity()

    init(archive: InstrumentArchive = InstrumentArchive()) {
        self.archive = archive
        super.init()
    }

    func start(kind: InstrumentKind, source: MeasurementSource, radio: (any RadioScanning)? = nil) async {
        stop(reason: "Source changed")
        self.kind = kind; self.source = source; phase = .starting
        points = []; events = []; metadata = [:]; spectrum = nil; motionWindow = []
        completedRequests = 0; failedRequests = 0; segment = 0; demonstration = false
        origin = ProcessInfo.processInfo.systemUptime; startedAt = .now; lastPublished = -.infinity
        let token = UUID(); generation = token
        if AppRuntime.isInstrumentDemo { loadDemo(kind: kind); return }
        do {
            metadata["installationID"] = try await archive.installationID()
            switch kind {
            case .bluetooth:
                guard let id = source.deviceID else { throw InstrumentError.unavailable("Choose a saved Bluetooth device to measure its signal.") }
                let radio = radio ?? BluetoothRadio()
                let session = radio.session(services: source.serviceUUIDs)
                radioSession = session
                task = Task { [weak self, radio] in
                    _ = radio // Keep the radio alive for the lifetime of this session.
                    do {
                        for try await event in session.events {
                            guard let self, self.generation == token, !Task.isCancelled else { return }
                            if case .device(let device) = event, device.id == id {
                                self.append(Double(device.rssi), date: device.lastSeen, allowEverySample: true)
                            }
                        }
                    } catch {
                        guard let self, self.generation == token, !Task.isCancelled else { return }
                        self.fail(error.localizedDescription)
                    }
                }
            case .tilt, .vibration, .rotation, .magnetic: try startMotion(token: token)
            case .pressure, .altitude: try startAltimeter(token: token)
            case .heading, .speed: try startLocation()
            case .sound: try await startAudio(token: token)
            case .network: try startNetwork(token: token)
            case .battery: startBattery(token: token)
            }
            guard generation == token else { return }
            readinessTimeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self, self.generation == token, self.points.isEmpty else { return }
                self.fail("No readings arrived. Check the source and permissions, then try again.")
            }
        } catch {
            guard generation == token else { return }
            stopResources()
            generation = UUID()
            switch error {
            case InstrumentError.denied(let message): phase = .denied(message)
            case InstrumentError.unavailable(let message): phase = .unavailable(message)
            default: phase = .failed(error.localizedDescription)
            }
        }
    }

    func loadDemo(kind: InstrumentKind) {
        stop(reason: "Sample session")
        guard AppRuntime.isInstrumentDemo else { return }
        demonstration = true; self.kind = kind
        let demo = InstrumentDemo.session(kind: kind)
        source = demo.source; points = demo.points; events = demo.events; metadata = demo.metadata
        startedAt = demo.startedAt; origin = ProcessInfo.processInfo.systemUptime - 20
        phase = .running; lastPublished = -.infinity
    }

    func beginRecording() {
        guard phase.isActive, !recording else { return }
        recording = true
        recordingID = UUID(); persistenceWarning = nil; lastCheckpoint = -.infinity
        recordingStart = .now
        recordingOrigin = ProcessInfo.processInfo.systemUptime
        recordedPoints = []; recordedEvents = []; recordingCount = 0; recordingDuration = 0
        if demonstration {
            // Explicitly labeled UI fixture only.
            recordedPoints = InstrumentDemo.session(kind: kind).points
            recordingStart = Date().addingTimeInterval(-20)
            recordingOrigin -= 20
            recordingCount = recordedPoints.count; recordingDuration = 20
        }
        checkpoint(force: true)
        if let recordingID {
            liveActivityWarning = liveActivity.start(id: recordingID, kind: kind, source: source)
            updateLiveActivity(force: true)
        }
    }

    func mark(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - origin
        events.append(CaptureEvent(elapsed: elapsed, text: trimmed))
        if recording { recordedEvents.append(CaptureEvent(elapsed: ProcessInfo.processInfo.systemUptime - recordingOrigin, text: trimmed)) }
    }

    func pause() {
        guard phase.isActive else { return }
        mark("Paused")
        stopResources()
        generation = UUID()
        phase = .paused
        checkpoint(force: true)
        updateLiveActivity(force: true)
    }

    func resume(radio: (any RadioScanning)? = nil) async {
        let priorPoints = points, priorEvents = events, priorOrigin = origin, priorDate = startedAt
        let priorRecording = recording, priorRecorded = recordedPoints, priorRecordedEvents = recordedEvents
        let priorRecordingStart = recordingStart, priorRecordingOrigin = recordingOrigin
        let priorSegment = segment
        await start(kind: kind, source: source, radio: radio)
        points = priorPoints + points; events = priorEvents
        origin = priorOrigin; startedAt = priorDate; segment = priorSegment + 1
        recording = priorRecording; recordedPoints = priorRecorded; recordedEvents = priorRecordedEvents
        recordingStart = priorRecordingStart; recordingOrigin = priorRecordingOrigin
        lastPublished = -.infinity
        mark("Resumed · new sensor segment")
    }

    func stop(reason: String = "Stopped by you") {
        if recording { mark(reason) }
        stopResources()
        generation = UUID()
        termination = reason
        if phase != .idle { phase = .finished }
        checkpoint(force: true)
        updateLiveActivity(force: true)
    }

    func interruptedByBackground() {
        guard phase.isActive else { return }
        mark("App left the foreground")
        stop(reason: "Paused when the app left the foreground")
        phase = .paused
        updateLiveActivity(force: true)
    }

    func finishRecording(title: String) throws -> RecordedSession {
        guard let recordingStart, let recordingID, !recordedPoints.isEmpty else { throw InstrumentError.noReadings }
        let session = RecordedSession(id: recordingID, title: title, kind: kind, source: source, startedAt: recordingStart, endedAt: .now, points: recordedPoints, events: recordedEvents, method: kind.method, termination: termination, metadata: metadata)
        return session
    }

    func discardRecording() async throws {
        await checkpointTask?.value
        if let recordingID { try await archive.discardDraft(recordingID) }
        recording = false; recordingStart = nil; recordedPoints = []; recordedEvents = []
        recordingCount = 0; recordingDuration = 0
        recordingID = nil; persistenceWarning = nil
        liveActivity.end(); liveActivityWarning = nil
    }

    func endLiveActivity() { liveActivity.end() }

    private func updateLiveActivity(force: Bool = false) {
        guard recording else { return }
        liveActivity.update(kind: kind, point: latest, phase: phase, count: recordingCount, force: force)
    }

    func retryCheckpoint() { checkpoint(force: true) }

    private func checkpoint(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        guard recording, !recordedPoints.isEmpty, force || now - lastCheckpoint >= 30,
              let session = try? finishRecording(title: "Unfinished \(kind.title.lowercased()) session") else { return }
        lastCheckpoint = now
        let previous = checkpointTask
        let archive = archive
        checkpointTask = Task { [weak self] in
            await previous?.value
            do {
                try await archive.saveDraft(session)
                if self?.recordingID == session.id { self?.persistenceWarning = nil }
            } catch {
                if self?.recordingID == session.id { self?.persistenceWarning = "The recovery copy couldn't be updated. Keep MagicCuts open and save the session. \(error.localizedDescription)" }
            }
        }
    }

    func currentSnapshot(title: String) throws -> RecordedSession {
        guard !points.isEmpty else { throw InstrumentError.noReadings }
        return RecordedSession(title: title, kind: kind, source: source, startedAt: startedAt, endedAt: .now, points: points, events: events, method: kind.method, termination: phase.title, metadata: metadata)
    }

    private func append(_ value: Double, date: Date = .now, auxiliary: [String: Double] = [:], allowEverySample: Bool = false) {
        guard value.isFinite, phase == .starting || phase == .running,
              date.timeIntervalSinceNow <= 1, date.timeIntervalSinceNow >= -kind.maximumAge else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard allowEverySample || now - lastPublished >= 0.1 else { return }
        lastPublished = now
        if let last = points.last, now - origin - last.elapsed > max(2, kind.maximumAge) { segment += 1 }
        let point = MeasurementPoint(elapsed: now - origin, date: date, value: value, segment: segment, auxiliary: auxiliary.filter { $0.value.isFinite }, placement: positionProvider?(date))
        points.append(point)
        if points.count > 6000 { points.removeFirst(points.count - 6000) }
        phase = .running; readinessTimeout?.cancel(); readinessTimeout = nil
        if recording {
            recordedPoints.append(MeasurementPoint(elapsed: now - recordingOrigin, date: date, value: value, segment: segment, auxiliary: point.auxiliary, placement: point.placement))
            recordingCount = recordedPoints.count; recordingDuration = now - recordingOrigin
            checkpoint()
            updateLiveActivity()
            if recordedPoints.count >= 50_000 || recordingDuration >= 7200 {
                stop(reason: "Recording limit reached. Save this session to start another.")
            }
        }
    }

    private func fail(_ message: String) {
        stop(reason: message)
        phase = .failed(message)
    }

    private func stopResources() {
        task?.cancel(); task = nil
        readinessTimeout?.cancel(); readinessTimeout = nil
        radioSession?.cancel(); radioSession = nil
        motion.stopDeviceMotionUpdates(); altimeter.stopRelativeAltitudeUpdates()
        location?.stopUpdatingLocation(); location?.stopUpdatingHeading(); location?.delegate = nil; location = nil
        if let audio {
            audio.inputNode.removeTap(onBus: 0); audio.stop(); self.audio = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        if let audioInterruption { NotificationCenter.default.removeObserver(audioInterruption); self.audioInterruption = nil }
        if let audioRouteChange { NotificationCenter.default.removeObserver(audioRouteChange); self.audioRouteChange = nil }
        pathMonitor?.cancel(); pathMonitor = nil
        requestSession?.invalidateAndCancel(); requestSession = nil
        if kind == .battery { UIDevice.current.isBatteryMonitoringEnabled = batteryMonitoringWasEnabled }
    }

    private func startMotion(token: UUID) throws {
        guard motion.isDeviceMotionAvailable else { throw InstrumentError.unavailable("Motion measurements aren't available on this device.") }
        metadata["referenceFrame"] = "Device frame; gravity-separated user acceleration"
        motion.deviceMotionUpdateInterval = 1 / 50
        let frame: CMAttitudeReferenceFrame = kind == .magnetic ? .xArbitraryCorrectedZVertical : .xArbitraryZVertical
        guard CMMotionManager.availableAttitudeReferenceFrames().contains(frame) else { throw InstrumentError.unavailable("This motion reference isn't available on this device.") }
        motion.showsDeviceMovementDisplay = kind == .magnetic
        motion.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] data, error in
            let message = error?.localizedDescription
            let reading = data.map { data in
                let acceleration = data.userAcceleration, rate = data.rotationRate, field = data.magneticField.field, gravity = data.gravity
                return MotionReading(time: data.timestamp, gravityX: gravity.x, gravityY: gravity.y, gravityZ: gravity.z, x: acceleration.x, y: acceleration.y, z: acceleration.z, rotation: sqrt(rate.x * rate.x + rate.y * rate.y + rate.z * rate.z) * 180 / .pi, field: sqrt(field.x * field.x + field.y * field.y + field.z * field.z), fieldAccuracy: Int(data.magneticField.accuracy.rawValue))
            }
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if let message { self.fail(message) }
                else if let reading { self.receiveMotion(reading) }
            }
        }
    }

    private func receiveMotion(_ reading: MotionReading) {
        motionWindow.append(reading)
        motionWindow.removeAll { reading.time - $0.time > 3 }
        switch kind {
        case .tilt:
            let pitch = atan2(reading.gravityY, -reading.gravityZ) * 180 / .pi
            let roll = atan2(reading.gravityX, -reading.gravityZ) * 180 / .pi
            let angle = acos(min(1, max(-1, -reading.gravityZ))) * 180 / .pi
            append(angle, auxiliary: ["pitch": pitch, "roll": roll, "gravityX": reading.gravityX, "gravityY": reading.gravityY, "gravityZ": reading.gravityZ])
        case .vibration:
            let recent = motionWindow.filter { reading.time - $0.time <= 1 }
            guard let first = recent.first, reading.time - first.time >= 0.9 else { return }
            let magnitude = recent.map { sqrt($0.x * $0.x + $0.y * $0.y + $0.z * $0.z) }
            guard let rms = MeasurementMath.rms(magnitude) else { return }
            var extras = ["peak": magnitude.max() ?? 0, "window": recent.last!.time - recent.first!.time]
            if rms > 0 { extras["crest"] = (magnitude.max() ?? 0) / rms }
            if reading.time - lastSpectrum >= 1, motionWindow.count >= 128 {
                lastSpectrum = reading.time
                let axes: [(String, (MotionReading) -> Double)] = [("x", { $0.x }), ("y", { $0.y }), ("z", { $0.z })]
                let chosen = axes.max { a, b in
                    (MeasurementMath.rms(motionWindow.map(a.1)) ?? 0) < (MeasurementMath.rms(motionWindow.map(b.1)) ?? 0)
                }!
                spectrum = MeasurementMath.spectrum(motionWindow.map { MeasurementPoint(elapsed: $0.time, value: chosen.1($0)) })
                metadata["spectrumAxis"] = chosen.0
            }
            if let spectrum {
                metadata["sampleRateHz"] = spectrum.sampleRate.formatted(.number.precision(.fractionLength(1)))
                extras["frequencyResolution"] = spectrum.resolution
                if let dominant = spectrum.dominantFrequency { extras["dominantFrequency"] = dominant }
            }
            append(rms, auxiliary: extras)
        case .rotation: append(reading.rotation)
        case .magnetic:
            metadata["fieldCalibration"] = ["Uncalibrated", "Low", "Medium", "High"][min(3, max(0, reading.fieldAccuracy + 1))]
            guard reading.fieldAccuracy >= 0 else { return }
            append(reading.field)
        default: break
        }
    }

    private func startAltimeter(token: UUID) throws {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { throw InstrumentError.unavailable("A barometer isn't available on this device.") }
        guard CMAltimeter.authorizationStatus() != .denied, CMAltimeter.authorizationStatus() != .restricted else {
            throw InstrumentError.denied("Allow Motion & Fitness access in Settings to read the barometer.")
        }
        if kind == .altitude { metadata["referenceFrame"] = "Relative altitude session \(token.uuidString)" }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            let pressure = data?.pressure.doubleValue, height = data?.relativeAltitude.doubleValue
            let message = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if let message { self.fail(message); return }
                guard let pressure, let height else { return }
                self.append(self.kind == .pressure ? pressure * 10 : height, auxiliary: ["pressureHpa": pressure * 10, "relativeAltitude": height])
            }
        }
    }

    private func startLocation() throws {
        if kind == .heading, !CLLocationManager.headingAvailable() { throw InstrumentError.unavailable("A compass isn't available on this device.") }
        let manager = CLLocationManager()
        location = manager; manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = kCLHeadingFilterNone
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: beginLocation(manager)
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .denied, .restricted: throw InstrumentError.denied("Allow location access in Settings to use this instrument.")
        @unknown default: throw InstrumentError.unavailable("Location authorization is unavailable.")
        }
    }

    private func beginLocation(_ manager: CLLocationManager) {
        manager.startUpdatingLocation()
        if kind == .heading { manager.startUpdatingHeading() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager === location else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: beginLocation(manager)
        case .denied, .restricted:
            stop(reason: "Location permission unavailable")
            phase = .denied("Allow location access in Settings to use this instrument.")
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard manager === location, kind == .heading, newHeading.headingAccuracy >= 0 else { return }
        metadata["referenceFrame"] = "Magnetic north"
        append(newHeading.magneticHeading, date: newHeading.timestamp, auxiliary: ["accuracyDegrees": newHeading.headingAccuracy])
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard manager === location, let reading = locations.last, reading.horizontalAccuracy >= 0,
              reading.timestamp.timeIntervalSinceNow >= -5 else { return }
        metadata["locationAccuracy"] = "\(reading.horizontalAccuracy.formatted(.number.precision(.fractionLength(0)))) m"
        if kind == .speed, reading.speed >= 0 {
            append(reading.speed, date: reading.timestamp, auxiliary: ["accuracyMeters": reading.horizontalAccuracy, "speedAccuracy": reading.speedAccuracy])
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard manager === location else { return }
        if (error as? CLError)?.code == .locationUnknown { return }
        fail("Location couldn't be read. \(error.localizedDescription)")
    }

    private func startAudio(token: UUID) async throws {
        guard await AVAudioApplication.requestRecordPermission() else { throw InstrumentError.denied("Allow microphone access in Settings to measure sound.") }
        guard generation == token else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [])
        try session.setActive(true)
        let engine = AVAudioEngine()
        let format = engine.inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            try session.setActive(false)
            throw InstrumentError.unavailable("No microphone input is available.")
        }
        metadata["audioInput"] = session.currentRoute.inputs.map(\.uid).joined(separator: ",")
        metadata["audioInputName"] = session.currentRoute.inputs.map(\.portName).joined(separator: ", ")
        metadata["audioSampleRate"] = String(format.sampleRate)
        metadata["audioWindow"] = "1024 PCM frames; RMS; no audio file retained"
        engine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            let count = Int(buffer.frameLength)
            var squares = 0.0, peak = 0.0, clipped = 0
            for index in 0 ..< count {
                let value = Double(samples[index])
                squares += value * value
                peak = max(peak, abs(value))
                if abs(value) >= 0.999 { clipped += 1 }
            }
            let rms = sqrt(squares / Double(count))
            let clipping = Double(clipped) / Double(count)
            let peakLevel = MeasurementMath.powerLevel(rms: peak) ?? -160
            let level = MeasurementMath.powerLevel(rms: rms) ?? -160
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.append(level, auxiliary: ["peakDbfs": peakLevel, "clippingFraction": clipping, "silence": rms == 0 ? 1 : 0])
            }
        }
        audio = engine
        audioInterruption = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.fail("Audio was interrupted. Resume to begin a new segment.")
            }
        }
        audioRouteChange = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: session, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.fail("The microphone input changed. Resume to measure the new input.")
            }
        }
        try engine.start()
    }

    private func startNetwork(token: UUID) throws {
        guard let endpoint = source.endpoint, let url = EndpointPolicy.url(endpoint) else { throw InstrumentError.invalidEndpoint }
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            let connection = path.usesInterfaceType(.wifi) ? "Wi-Fi" : path.usesInterfaceType(.cellular) ? "Cellular" : path.usesInterfaceType(.wiredEthernet) ? "Wired" : "Other"
            let description = path.status == .satisfied ? connection + (path.isConstrained ? " · Low Data Mode" : "") + (path.isExpensive ? " · Metered" : "") : "No network path"
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.pathDescription = description
                self.metadata["networkPath"] = description
            }
        }
        monitor.start(queue: .main)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 6
        let session = URLSession(configuration: configuration, delegate: ProbeDelegate(), delegateQueue: nil)
        requestSession = session
        metadata["requestMethod"] = "HEAD; no redirects; uncached; 20 requests maximum"
        task = Task { [weak self] in
            for _ in 0 ..< 20 {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 5)
                request.httpMethod = "HEAD"
                let start = ProcessInfo.processInfo.systemUptime
                do {
                    let (_, response) = try await session.data(for: request)
                    guard self.generation == token, !Task.isCancelled else { return }
                    let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                    if (200 ..< 300).contains(code) {
                        self.completedRequests += 1
                        self.append((ProcessInfo.processInfo.systemUptime - start) * 1000, auxiliary: ["httpStatus": Double(code)], allowEverySample: true)
                    } else {
                        self.failedRequests += 1
                        self.events.append(CaptureEvent(elapsed: ProcessInfo.processInfo.systemUptime - self.origin, text: "HTTP \(code); excluded from successful-response timings"))
                    }
                } catch {
                    guard self.generation == token, !Task.isCancelled else { return }
                    self.failedRequests += 1
                    self.events.append(CaptureEvent(elapsed: ProcessInfo.processInfo.systemUptime - self.origin, text: "Request failed: \(error.localizedDescription)"))
                }
                self.metadata["completedRequests"] = String(self.completedRequests)
                self.metadata["failedRequests"] = String(self.failedRequests)
                do { try await Task.sleep(for: .seconds(0.7)) } catch { return }
            }
            guard let self, self.generation == token else { return }
            if self.points.isEmpty { self.fail("No successful responses. Check the endpoint, its HEAD support, and your network permissions.") }
            else { self.stop(reason: "Completed 20 endpoint requests") }
        }
    }

    private func startBattery(token: UUID) {
        batteryMonitoringWasEnabled = UIDevice.current.isBatteryMonitoringEnabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.generation == token else { return }
                let device = UIDevice.current
                self.metadata["powerState"] = switch device.batteryState {
                case .charging: "Charging"
                case .full: "Full"
                case .unplugged: "On battery"
                default: "Unknown"
                }
                self.metadata["thermalState"] = switch ProcessInfo.processInfo.thermalState {
                case .nominal: "Nominal"
                case .fair: "Fair"
                case .serious: "Serious"
                case .critical: "Critical"
                @unknown default: "Unknown"
                }
                self.metadata["lowPowerMode"] = ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off"
                if device.batteryLevel >= 0 { self.append(Double(device.batteryLevel) * 100) }
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
}
