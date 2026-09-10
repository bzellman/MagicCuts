import Foundation
import Observation
@preconcurrency import ARKit
import RoomPlan
import AVFoundation
import CoreImage
import UIKit
import simd

nonisolated enum RoomSessionPhase: String, Sendable {
    case idle, preparing, locating, scanning, located, measuring, processing, review, interrupted, unavailable
    var title: String {
        switch self {
        case .idle: "Ready"; case .preparing: "Preparing camera"; case .locating: "Locating room"
        case .scanning: "Scanning"; case .located: "Located in room"; case .measuring: "Measuring"
        case .processing: "Preparing room"; case .review: "Review scan"; case .interrupted: "Tracking interrupted"
        case .unavailable: "Capture unavailable"
        }
    }
}

nonisolated enum RoomSessionPurpose: Sendable { case newRoom, update, localize, measurement }

@MainActor @Observable
final class RoomSession: NSObject, @preconcurrency ARSessionDelegate {
    private(set) var phase: RoomSessionPhase = .idle
    private(set) var purpose: RoomSessionPurpose = .newRoom
    private(set) var instruction = "Start a scan or locate yourself in a saved room."
    private(set) var failure: String?
    private(set) var currentPose: SpatialTransform?
    private(set) var currentPoseDate: Date?
    private(set) var surfacePoint: SpatialVector?
    private(set) var distance: Double?
    private(set) var confidence: UInt8?
    private(set) var depth: DepthEvidence?
    private(set) var surfaceFit: SurfaceFit?
    private(set) var vertexCount = 0
    private(set) var draft: RoomRevision?
    private(set) var reference: RoomRevision?
    private(set) var dimensions: [SpatialDimension] = []
    private(set) var firstPoint: SpatialVector?
    private(set) var tracked = false
    private(set) var cameraActive = false
    private(set) var captureVersion = 0
    @ObservationIgnored let arSession = ARSession()
    @ObservationIgnored private var capture: RoomCaptureSession?
    @ObservationIgnored private var bridge: RoomPlanBridge?
    @ObservationIgnored private var patches: [UUID: RoomMeshPatch] = [:]
    @ObservationIgnored private var semantic: CapturedRoom?
    @ObservationIgnored private var history: [(Date, SpatialTransform)] = []
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var roomID = UUID()
    @ObservationIgnored private var revisionID = UUID()
    @ObservationIgnored private var frameID = UUID()
    @ObservationIgnored private var installationID = ""
    @ObservationIgnored private var startedAt = Date()
    @ObservationIgnored private var lastFrameTime = -Double.infinity
    @ObservationIgnored private var lastCheckpoint = -Double.infinity
    @ObservationIgnored private var checkpointing = false
    @ObservationIgnored private var completionStarted = false
    @ObservationIgnored private var finishing = false
    @ObservationIgnored private var timeout: Task<Void, Never>?
    @ObservationIgnored private var completionTask: Task<Void, Never>?
    @ObservationIgnored private var archive: InstrumentArchive?
    @ObservationIgnored private var priorPhase: RoomSessionPhase = .idle
    @ObservationIgnored private var hasRestoredFrame = false
    @ObservationIgnored private var provenance: RoomCaptureProvenance?

    var roomName: String { reference?.roomName ?? draft?.roomName ?? "New room" }
    var canPin: Bool { cameraActive && tracked && phase == .located && reference != nil }
    var canFinish: Bool { (phase == .scanning || phase == .interrupted) && (purpose == .newRoom || purpose == .update) && !patches.isEmpty && !finishing }

    override init() {
        super.init()
        arSession.delegate = self
        arSession.delegateQueue = .main
    }

    func start(_ purpose: RoomSessionPurpose, reference: RoomRevision? = nil, archive: InstrumentArchive, unaligned: Bool = false) async {
        end()
        self.purpose = purpose; self.reference = reference; self.archive = archive
        phase = .preparing; failure = nil; draft = nil; dimensions = []; firstPoint = nil
        patches = [:]; semantic = nil; history = []; currentPose = nil; depth = nil; vertexCount = 0
        completionStarted = false; finishing = false; hasRestoredFrame = false; checkpointing = false
        roomID = reference?.roomID ?? UUID(); revisionID = UUID()
        frameID = unaligned ? UUID() : reference?.coordinateFrameID ?? UUID()
        startedAt = .now; lastFrameTime = -.infinity; lastCheckpoint = -.infinity
        let token = generation
        guard ARWorldTrackingConfiguration.isSupported,
              ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth),
              ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) else {
            phase = .unavailable; failure = "This capture needs a LiDAR-equipped device. Saved rooms and manual measurement pins remain available."
            return
        }
        let authorized = await AVCaptureDevice.requestAccess(for: .video)
        guard token == generation, !Task.isCancelled else { return }
        guard authorized else { phase = .unavailable; failure = "Allow camera access in Settings to capture or locate a room."; return }
        do {
            installationID = try await archive.installationID()
            guard token == generation, !Task.isCancelled else { return }
            let config = ARWorldTrackingConfiguration()
            config.frameSemantics = .sceneDepth
            provenance = RoomCaptureProvenance(systemVersion: UIDevice.current.systemVersion, deviceFamily: UIDevice.current.model,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                reconstruction: ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) ? "Mesh with classification" : "Mesh",
                depthSource: "ARFrame.sceneDepth", events: [])
            // Raw depth remains available for surface fitting; do not flatten it with plane detection.
            config.sceneReconstruction = purpose == .localize ? [] : (ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) ? .meshWithClassification : .mesh)
            if reference != nil, !unaligned {
                guard let data = reference?.worldMapData,
                      let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
                    throw InstrumentError.unavailable("This revision has no usable orientation map. Place a pin manually or capture a separate revision.")
                }
                config.initialWorldMap = map
                phase = .locating
                instruction = "Return to the saved reference view and move the phone slowly."
            } else {
                phase = purpose == .measurement ? .measuring : .scanning
                instruction = "Move slowly and look at surfaces from more than one angle."
            }
            cameraActive = true
            arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
            if phase == .scanning { startRoomPlan(token: token) }
            if phase == .locating {
                timeout = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(15)) } catch { return }
                    guard let self, self.generation == token, self.phase == .locating else { return }
                    self.instruction = "Try matching the reference photo. You can keep trying, place a manual pin, or save a separate scan."
                }
            }
        } catch {
            phase = .unavailable; failure = error.localizedDescription
        }
    }

    private func startRoomPlan(token: UUID) {
        guard purpose != .measurement, RoomCaptureSession.isSupported, capture == nil else { return }
        let bridge = RoomPlanBridge(onRoom: { [weak self] room in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }; self.semantic = room
            }
        }, onInstruction: { [weak self] text in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token, self.phase == .scanning else { return }; self.instruction = text
            }
        }, onEnd: { [weak self] data, error in
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                self.complete(data: data, error: error, token: token)
            }
        })
        self.bridge = bridge
        let capture = RoomCaptureSession(arSession: arSession)
        capture.delegate = bridge; self.capture = capture
        var configuration = RoomCaptureSession.Configuration(); configuration.isCoachingEnabled = true
        capture.run(configuration: configuration)
    }

    func finish() {
        guard canFinish else { return }
        finishing = true; phase = .processing; instruction = "Saving surface and orientation data…"
        let token = generation
        if let capture { capture.stop(pauseARSession: false) }
        else { complete(data: nil, error: nil, token: token) }
        timeout?.cancel()
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(20)) } catch { return }
            guard let self, self.generation == token, !self.completionStarted else { return }
            self.complete(data: nil, error: "Room recognition did not finish. The observed mesh was retained.", token: token)
        }
    }

    private func complete(data: CapturedRoomData?, error: String?, token: UUID) {
        guard !completionStarted else { return }
        completionStarted = true; phase = .processing
        completionTask = Task { [weak self] in
            guard let self else { return }
            var warnings = error.map { [$0] } ?? []
            if let data {
                do {
                    let built = try await RoomBuilder(options: []).capturedRoom(from: data)
                    guard self.generation == token, !Task.isCancelled else { return }
                    self.semantic = built
                }
                catch { warnings.append("Room recognition: \(error.localizedDescription)") }
            }
            guard self.generation == token, !Task.isCancelled else { return }
            var map: Data?
            do { map = try await self.worldMap() }
            catch { warnings.append("Orientation data unavailable: \(error.localizedDescription)") }
            guard self.generation == token, !Task.isCancelled else { return }
            let photo = self.referencePhoto()
            self.arSession.pause(); self.cameraActive = false; self.tracked = false
            var revision = self.makeRevision()
            revision.worldMapData = map; revision.referenceImage = photo; revision.warnings = warnings
            if let semantic = self.semantic {
                do { revision.semanticData = try JSONEncoder().encode(semantic) }
                catch { revision.warnings.append("Recognized room data couldn't be retained: \(error.localizedDescription)") }
            }
            guard revision.isValid else { self.phase = .unavailable; self.failure = "No usable mesh was captured. Try scanning more of the room."; return }
            self.draft = revision; self.phase = .review; self.instruction = "Inspect coverage before saving this revision."
            if let archive = self.archive {
                do { try await archive.saveRoomDraft(revision) }
                catch { if self.generation == token { self.failure = "The recovery copy couldn't be saved. Keep this review open and try Save: \(error.localizedDescription)" } }
            }
        }
    }

    func end() {
        generation = UUID(); timeout?.cancel(); timeout = nil; completionTask?.cancel(); completionTask = nil
        capture?.delegate = nil; capture?.stop(pauseARSession: true); capture = nil; bridge = nil
        arSession.pause(); cameraActive = false; tracked = false; currentPose = nil; currentPoseDate = nil
        surfacePoint = nil; distance = nil; confidence = nil; surfaceFit = nil; depth = nil; history = []; phase = .idle
    }

    func backgrounded() {
        guard cameraActive else { return }
        let snapshot = (purpose == .newRoom || purpose == .update) ? makeRevision() : nil
        end(); phase = .interrupted
        let token = generation
        if let snapshot {
            if let archive, snapshot.isValid {
                Task { [weak self] in
                    do { try await archive.saveRoomDraft(snapshot) }
                    catch { if self?.generation == token { self?.failure = "Interrupted scan recovery couldn't be saved: \(error.localizedDescription)" } }
                }
            }
        }
        instruction = "Camera tracking stopped while MagicCuts was in the background. Locate the room again before adding tracked pins."
    }

    func placement(at date: Date = .now) -> RoomPlacement? {
        guard canPin, let reference,
              let closest = history.min(by: { abs($0.0.timeIntervalSince(date)) < abs($1.0.timeIntervalSince(date)) }),
              abs(closest.0.timeIntervalSince(date)) <= 0.3,
              Date().timeIntervalSince(closest.0) <= 1 else { return nil }
        return RoomPlacement(roomID: reference.roomID, revisionID: reference.id, coordinateFrameID: frameID,
                             pose: closest.1, observedAt: closest.0, method: .relocalized)
    }

    func selectPoint() {
        guard tracked, let surfacePoint, let confidence, confidence >= 1 else { return }
        if let firstPoint {
            guard firstPoint.distance(to: surfacePoint) > 0.005 else { failure = "Move the reticle to a different surface point."; return }
            dimensions.append(SpatialDimension(title: "Dimension \(dimensions.count + 1)", start: firstPoint, end: surfacePoint))
            self.firstPoint = nil; failure = nil
        } else { firstPoint = surfacePoint; failure = nil }
    }

    func undoPoint() {
        if firstPoint != nil { firstPoint = nil }
        else if !dimensions.isEmpty { dimensions.removeLast() }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard cameraActive, frame.timestamp - lastFrameTime >= 0.12 else { return }
        lastFrameTime = frame.timestamp
        let now = Date().addingTimeInterval(frame.timestamp - ProcessInfo.processInfo.systemUptime)
        if case .normal = frame.camera.trackingState { tracked = true } else { tracked = false }
        let state = tracked ? "Tracking normal" : Self.trackingExplanation(frame.camera.trackingState)
        if provenance?.events.last?.state != state, (provenance?.events.count ?? 1000) < 1000 {
            provenance?.events.append(RoomTrackingEvent(elapsed: max(0, now.timeIntervalSince(startedAt)), state: state))
        }
        if tracked, phase == .locating {
            hasRestoredFrame = true; timeout?.cancel()
            phase = purpose == .localize ? .located : .scanning
            instruction = purpose == .localize ? "Your position is tracked. Capture measurements here or open another instrument." : "Room located. Scan the areas you want to observe again."
            if purpose == .update { startRoomPlan(token: generation) }
        }
        if !tracked {
            history = []; surfacePoint = nil; distance = nil; currentPose = nil; currentPoseDate = nil; surfaceFit = nil; depth = nil
            if phase == .located || phase == .scanning || phase == .measuring { priorPhase = phase; phase = .interrupted }
            instruction = Self.trackingExplanation(frame.camera.trackingState)
            return
        }
        if phase == .interrupted { phase = priorPhase; instruction = "Tracking recovered." }
        let pose = SpatialTransform(frame.camera.transform)
        currentPose = pose; currentPoseDate = now; history.append((now, pose)); history.removeAll { now.timeIntervalSince($0.0) > 5 }
        let evidence = DepthProcessing.read(frame: frame)
        depth = evidence?.image; surfacePoint = evidence?.centerPoint; confidence = evidence?.centerConfidence
        distance = surfacePoint.map { pose.position.distance(to: $0) }; surfaceFit = evidence?.fit
        if phase == .scanning, !finishing, !checkpointing, frame.timestamp - lastCheckpoint > 10 {
            lastCheckpoint = frame.timestamp
            let revision = makeRevision()
            if revision.isValid, let archive {
                checkpointing = true
                let token = generation
                Task { [weak self] in
                    do { try await archive.saveRoomDraft(revision) }
                    catch { if self?.generation == token { self?.failure = "Recovery save failed: \(error.localizedDescription)" } }
                    if self?.generation == token { self?.checkpointing = false }
                }
            }
        }
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { collect(anchors) }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { collect(anchors) }
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        guard phase == .scanning || phase == .measuring else { return }
        for anchor in anchors { patches.removeValue(forKey: anchor.identifier) }
        vertexCount = patches.values.reduce(0) { $0 + $1.vertices.count }; captureVersion += 1
    }
    func session(_ session: ARSession, didFailWithError error: Error) {
        sessionWasInterrupted(session); failure = error.localizedDescription
    }
    func sessionWasInterrupted(_ session: ARSession) {
        guard cameraActive else { return }
        tracked = false; history = []; currentPose = nil; currentPoseDate = nil
        surfacePoint = nil; distance = nil; confidence = nil; surfaceFit = nil; depth = nil
        if phase != .interrupted { priorPhase = phase }
        phase = .interrupted
    }

    private func collect(_ anchors: [ARAnchor]) {
        guard tracked, phase == .scanning || phase == .measuring, !finishing else { return }
        for case let anchor as ARMeshAnchor in anchors {
            let geometry = anchor.geometry
            guard geometry.vertices.count > 0, geometry.faces.primitiveType == .triangle else { continue }
            var vertices: [SpatialVector] = []; vertices.reserveCapacity(geometry.vertices.count)
            for index in 0..<geometry.vertices.count {
                let address = geometry.vertices.buffer.contents().advanced(by: geometry.vertices.offset + index * geometry.vertices.stride)
                let floats = address.assumingMemoryBound(to: Float.self)
                vertices.append(SpatialVector(x: floats[0], y: floats[1], z: floats[2]))
            }
            var indices: [UInt32] = []; indices.reserveCapacity(geometry.faces.count * 3)
            let faces = geometry.faces.buffer.contents()
            for index in 0..<(geometry.faces.count * geometry.faces.indexCountPerPrimitive) {
                let p = faces.advanced(by: index * geometry.faces.bytesPerIndex)
                indices.append(geometry.faces.bytesPerIndex == 4 ? p.load(as: UInt32.self) : UInt32(p.load(as: UInt16.self)))
            }
            var classes: [UInt8] = []
            if let source = geometry.classification {
                classes = (0..<source.count).map { source.buffer.contents().advanced(by: source.offset + $0 * source.stride).load(as: UInt8.self) }
            }
            let patch = RoomMeshPatch(id: anchor.identifier, transform: SpatialTransform(anchor.transform), vertices: vertices,
                                      triangleIndices: indices, classifications: classes, observedAt: .now)
            if patch.isValid { patches[anchor.identifier] = patch }
        }
        vertexCount = patches.values.reduce(0) { $0 + $1.vertices.count }; captureVersion += 1
        if vertexCount > 1_800_000 { instruction = "This scan is large. Finish and review before capturing another pass."; if canFinish { finish() } }
    }

    private func makeRevision() -> RoomRevision {
        var captureProvenance = provenance
        if let configuration = arSession.configuration as? ARWorldTrackingConfiguration {
            captureProvenance?.meshPlaneDetection = [configuration.planeDetection.contains(.horizontal) ? "Horizontal" : nil,
                configuration.planeDetection.contains(.vertical) ? "Vertical" : nil].compactMap { $0 }.joined(separator: ", ")
        }
        return RoomRevision(id: revisionID, roomID: roomID, roomName: reference?.roomName ?? "New room", parentRevisionID: reference?.id,
                     coordinateFrameID: frameID, startedAt: startedAt, endedAt: .now, installationID: installationID,
                     meshes: patches.values.sorted { $0.id.uuidString < $1.id.uuidString },
                     components: semantic.map(Self.components) ?? [], dimensions: dimensions,
                     alignment: hasRestoredFrame ? .relocalized : .tracked, provenance: captureProvenance)
    }

    private func worldMap() async throws -> Data? {
        guard let frame = arSession.currentFrame, frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            arSession.getCurrentWorldMap { map, error in
                if let error { continuation.resume(throwing: error); return }
                do { continuation.resume(returning: try map.map { try NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func referencePhoto() -> Data? {
        guard let frame = arSession.currentFrame else { return nil }
        let image = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        guard let cg = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .right).jpegData(compressionQuality: 0.65)
    }

    private static func components(_ room: CapturedRoom) -> [RoomComponent] {
        let surfaces = room.walls + room.doors + room.windows + room.openings + room.floors
        var result = surfaces.map { surface in
            let category: String
            switch surface.category {
            case .wall: category = "Wall"; case .door: category = "Door"; case .window: category = "Window"
            case .opening: category = "Opening"; case .floor: category = "Floor"; @unknown default: category = "Surface"
            }
            let transform = SpatialTransform(surface.transform)
            return RoomComponent(id: surface.identifier, category: category, transform: transform, dimensions: SpatialVector(surface.dimensions),
                                 confidence: confidenceName(surface.confidence), outline: surface.polygonCorners.map { transform.worldPoint(SpatialVector($0)) },
                                 complete: surface.completedEdges.count == 4 && surface.confidence == .high)
        }
        result += room.objects.map { RoomComponent(id: $0.identifier, category: "Object", transform: SpatialTransform($0.transform), dimensions: SpatialVector($0.dimensions), confidence: confidenceName($0.confidence)) }
        return result
    }
    private static func confidenceName(_ confidence: CapturedRoom.Confidence) -> String {
        switch confidence { case .high: "High"; case .medium: "Medium"; case .low: "Low"; @unknown default: "Unknown" }
    }
    private static func trackingExplanation(_ state: ARCamera.TrackingState) -> String {
        switch state {
        case .normal: "Tracking available."
        case .notAvailable: "Camera tracking is unavailable."
        case .limited(let reason):
            switch reason {
            case .initializing: "Move slowly while the camera finds stable surfaces."
            case .excessiveMotion: "Move the phone more slowly."
            case .insufficientFeatures: "Look toward a textured, well-lit surface."
            case .relocalizing: "Return to the saved reference view to locate the room."
            @unknown default: "Hold the phone steady while tracking recovers."
            }
        }
    }
}

nonisolated private final class RoomPlanBridge: RoomCaptureSessionDelegate, Sendable {
    let onRoom: @Sendable (CapturedRoom) -> Void
    let onInstruction: @Sendable (String) -> Void
    let onEnd: @Sendable (CapturedRoomData, String?) -> Void
    init(onRoom: @escaping @Sendable (CapturedRoom) -> Void, onInstruction: @escaping @Sendable (String) -> Void, onEnd: @escaping @Sendable (CapturedRoomData, String?) -> Void) {
        self.onRoom = onRoom; self.onInstruction = onInstruction; self.onEnd = onEnd
    }
    func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) { onRoom(room) }
    func captureSession(_ session: RoomCaptureSession, didProvide instruction: RoomCaptureSession.Instruction) {
        let text: String
        switch instruction {
        case .moveCloseToWall: text = "Move closer to the wall."
        case .moveAwayFromWall: text = "Step back to include more of the wall."
        case .slowDown: text = "Move the phone more slowly."
        case .turnOnLight: text = "More light will help capture this area."
        case .lowTexture: text = "Look toward an area with more surface detail."
        case .normal: text = "Look around slowly and revisit missed surfaces."
        @unknown default: text = "Keep the phone steady and observe the room."
        }
        onInstruction(text)
    }
    func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) { onEnd(data, error?.localizedDescription) }
}
