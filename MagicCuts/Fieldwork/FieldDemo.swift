#if DEBUG
import Foundation
import simd

nonisolated enum FieldDemo {
    static let roomID = UUID(uuidString: "11111111-ABCD-1234-ABCD-111111111111")!
    static let frameID = UUID(uuidString: "22222222-ABCD-1234-ABCD-222222222222")!
    static let revisionID = UUID(uuidString: "33333333-ABCD-1234-ABCD-333333333333")!
    static let earlierID = UUID(uuidString: "44444444-ABCD-1234-ABCD-444444444444")!
    static func room(earlier: Bool = false, enclosed: Bool = false) -> RoomRevision {
        let date = Date(timeIntervalSince1970: 1_789_069_800).addingTimeInterval(earlier ? -86400 : 0)
        let width: Float = 4.8, length: Float = 3.84, height: Float = 2.7
        func surface(_ origin: SIMD3<Float>, _ across: SIMD3<Float>, _ up: SIMD3<Float>, nx: Int = 18, ny: Int = 12) -> RoomMeshPatch {
            var vertices: [SpatialVector] = [], triangles: [UInt32] = []
            for y in 0...ny { for x in 0...nx { vertices.append(SpatialVector(origin + across * Float(x) / Float(nx) + up * Float(y) / Float(ny))) } }
            for y in 0..<ny { for x in 0..<nx {
                let a = UInt32(y * (nx + 1) + x), b = a + 1, c = a + UInt32(nx + 1), d = c + 1
                triangles += [a, c, b, b, c, d]
            } }
            return RoomMeshPatch(id: UUID(), transform: SpatialTransform(), vertices: vertices, triangleIndices: triangles, observedAt: date)
        }
        let depth: Float = earlier ? 3.1 : length
        var meshes = [surface(.zero, SIMD3(width, 0, 0), SIMD3(0, 0, depth)),
                      surface(.zero, SIMD3(width, 0, 0), SIMD3(0, height, 0)),
                      surface(.zero, SIMD3(0, 0, depth), SIMD3(0, height, 0)),
                      surface(SIMD3(width, 0, 0), SIMD3(0, 0, depth), SIMD3(0, height, 0))]
        if enclosed {
            meshes.append(surface(SIMD3(0, height, 0), SIMD3(width, 0, 0), SIMD3(0, 0, depth)))
            meshes.append(surface(SIMD3(0, 0, depth), SIMD3(width, 0, 0), SIMD3(0, height, 0)))
            meshes.append(surface(SIMD3(width, 0, 1), SIMD3(2, 0, 0), SIMD3(0, 0, 1)))
            meshes.append(surface(SIMD3(width, 0, 1), SIMD3(2, 0, 0), SIMD3(0, height, 0)))
        }
        let shift: Float = earlier ? 0 : 0.25
        meshes.append(surface(SIMD3(0.7 + shift, 0.75, 0.8), SIMD3(1.4, 0, 0), SIMD3(0, 0, 0.75), nx: 10, ny: 6))
        for x: Float in [0.8 + shift, 2 + shift] {
            for z: Float in [0.9, 1.45] { meshes.append(surface(SIMD3(x, 0, z), SIMD3(0.07, 0, 0), SIMD3(0, 0.75, 0), nx: 1, ny: 4)) }
        }
        let floor = RoomComponent(id: UUID(), category: "Floor", transform: SpatialTransform(), dimensions: .init(x: width, y: 0, z: length), confidence: "High",
            outline: [.init(x: 0, y: 0, z: 0), .init(x: width, y: 0, z: 0), .init(x: width, y: 0, z: length), .init(x: 0, y: 0, z: length)], complete: !earlier)
        var components = [floor]
        for (x, z, w, angle) in [(width/2, Float(0), width, Float(0)), (Float(0), length/2, length, Float.pi/2), (width, length/2, length, Float.pi/2)] {
            var matrix = simd_float4x4(simd_quatf(angle: angle, axis: SIMD3(0, 1, 0))); matrix.columns.3 = SIMD4(x, height/2, z, 1)
            components.append(RoomComponent(id: UUID(), category: "Wall", transform: SpatialTransform(matrix), dimensions: .init(x: w, y: height, z: 0), confidence: "High"))
        }
        return RoomRevision(id: earlier ? earlierID : revisionID, roomID: roomID, roomName: "Studio · sample", parentRevisionID: earlier ? nil : earlierID,
            coordinateFrameID: frameID, startedAt: date.addingTimeInterval(-90), endedAt: date, installationID: "55555555-ABCD-1234-ABCD-555555555555",
            meshes: meshes, components: components,
            dimensions: [.init(title: "Desk width", start: .init(x: 0.7 + shift, y: 0.75, z: 0.8), end: .init(x: 2.1 + shift, y: 0.75, z: 0.8))],
            alignment: earlier ? .tracked : .relocalized, warnings: ["Illustrative geometry and measurements. No physical room was scanned for this sample."], demonstration: true)
    }
    static func placement(x: Float, z: Float, revision: RoomRevision) -> RoomPlacement {
        var matrix = matrix_identity_float4x4; matrix.columns.3 = SIMD4(x, 1.2, z, 1)
        return RoomPlacement(roomID: revision.roomID, revisionID: revision.id, coordinateFrameID: revision.coordinateFrameID,
            pose: SpatialTransform(matrix), observedAt: revision.endedAt, method: .manual, note: "Illustrative placement")
    }
    static func network(revision: RoomRevision) -> FieldCapture {
        let probes = (0..<20).map { index -> NetworkProbe in
            let milliseconds = 22 + Double(index % 4) * 3.2 + (index == 12 ? 41 : 0)
            let failure = index == 8
            let phases = index == 0 ? [RequestPhase(id: "dns", name: "DNS", start: 0, end: 0.004), .init(id: "connect", name: "Connection", start: 0.004, end: 0.017),
                .init(id: "tls", name: "TLS", start: 0.008, end: 0.017), .init(id: "wait", name: "Wait for response", start: 0.018, end: 0.022)] :
                [RequestPhase(id: "request", name: "Send request", start: 0, end: 0.001), .init(id: "wait", name: "Wait for response", start: 0.001, end: milliseconds / 1000)]
            return NetworkProbe(date: revision.endedAt.addingTimeInterval(Double(index)), elapsed: Double(index), durationMS: milliseconds,
                status: failure ? 503 : 200, error: failure ? "HTTP 503. Excluded from successful timings." : nil,
                transactions: [.init(phases: phases, protocolName: "h2", reused: index > 0, cellular: false, cached: false, status: failure ? 503 : 200, host: "example.test")])
        }
        return FieldCapture(title: "At the window · sample", kind: .network, date: revision.endedAt, source: "example.test · sample endpoint",
            method: "Illustrative uncached HEAD requests. TLS overlaps connection setup. Failed requests are excluded from response-time statistics.",
            metrics: FieldStatistics.networkMetrics(probes), probes: probes, placement: placement(x: 4.2, z: 1.8, revision: revision), demonstration: true)
    }
    @MainActor static func seed(_ library: ProLibrary) async {
        guard AppRuntime.isUITesting, ProcessInfo.processInfo.arguments.contains("--room-demo"), library.index.roomRevisions.isEmpty else { return }
        do {
            let earlier = room(earlier: true), latest = room(enclosed: ProcessInfo.processInfo.arguments.contains("--room-enclosed-demo"))
            try await library.save(earlier); try await library.save(latest)
            try await library.save(network(revision: latest))
            let payload = Data([2]) + Data("enStudio sensor".utf8)
            let read = NFCReadData(protocolName: "ISO 14443 · sample", identifier: Data([4, 82, 91, 17, 32, 71, 128]), status: "Read-only", capacity: 144, messageBytes: 20,
                records: [.init(id: 0, format: 1, type: Data([0x54]), identifier: Data(), payload: payload, decoded: "Studio sensor")])
            try await library.save(FieldCapture(title: "Desk tag · sample", kind: .nfc, date: latest.endedAt, source: "ISO 14443 · sample",
                method: "Illustrative NDEF read. No physical tag was read for this sample.",
                diagnostics: [.init(step: "Detect", outcome: "One tag", duration: 0.25), .init(step: "Connect", outcome: "Connected", duration: 0.018), .init(step: "Read NDEF", outcome: "One text record", duration: 0.042)],
                nfc: read, placement: placement(x: 1.7, z: 1.2, revision: latest), demonstration: true))
            try await library.save(FieldCapture(title: "Room noise · sample", kind: .reading, date: latest.endedAt, source: "Microphone · sample",
                method: "Illustrative digital audio level, not calibrated sound-pressure level.", metrics: [.init(id: "sound", title: "Audio level", value: -41.2, unit: "dBFS")],
                placement: placement(x: 2.4, z: 3, revision: latest), demonstration: true))
        } catch { library.error = "Sample room could not be prepared: \(error.localizedDescription)" }
    }
}
#endif
