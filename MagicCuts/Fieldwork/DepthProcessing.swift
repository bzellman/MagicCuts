import Foundation
import ARKit
import CoreVideo
import simd

nonisolated struct SurfaceFit: Codable, Sendable, Equatable {
    var center: SpatialVector
    var normal: SpatialVector
    var count: Int
    var rmsMeters: Double
    var peakToPeakMeters: Double
    var points: [SpatialVector] = []
    var isValid: Bool {
        center.isFinite && normal.isFinite && abs(simd_length(normal.simd) - 1) < 0.02
            && count >= 30 && count <= 1000 && points.count == count && points.allSatisfy(\.isFinite)
            && rmsMeters.isFinite && rmsMeters >= 0 && peakToPeakMeters.isFinite && peakToPeakMeters >= 0
    }
    var slopeDegrees: Double { acos(min(1, abs(Double(normal.y)))) * 180 / .pi }
    var metrics: [FieldMetric] {
        [FieldMetric(id: "slope", title: "Angle from horizontal", value: slopeDegrees, unit: "°", qualifier: "Estimated plane"),
         FieldMetric(id: "rms", title: "Plane residual RMS", value: rmsMeters * 1000, unit: "mm", qualifier: "Raw depth; includes sensor noise"),
         FieldMetric(id: "span", title: "Residual span", value: peakToPeakMeters * 1000, unit: "mm", qualifier: "Observed patch"),
         FieldMetric(id: "samples", title: "Depth samples", value: Double(count), unit: "points")]
    }
}

nonisolated enum SurfaceFitting {
    static func fit(_ points: [SpatialVector]) -> SurfaceFit? {
        let points = points.filter(\.isFinite)
        guard points.count >= 30 else { return nil }
        let mean = points.reduce(SIMD3<Double>.zero) { $0 + SIMD3(Double($1.x), Double($1.y), Double($1.z)) } / Double(points.count)
        var covariance = Array(repeating: Array(repeating: 0.0, count: 3), count: 3)
        for point in points {
            let delta = SIMD3(Double(point.x), Double(point.y), Double(point.z)) - mean
            for row in 0..<3 { for column in 0..<3 { covariance[row][column] += delta[row] * delta[column] / Double(points.count) } }
        }
        var vectors = [[1.0, 0, 0], [0.0, 1, 0], [0.0, 0, 1]]
        // Jacobi rotation of the symmetric covariance matrix. The least-variance axis is the normal.
        for _ in 0..<30 {
            let pair = [(0, 1), (0, 2), (1, 2)].max { abs(covariance[$0.0][$0.1]) < abs(covariance[$1.0][$1.1]) }!
            let (p, q) = pair
            guard abs(covariance[p][q]) > 1e-12 else { break }
            let angle = 0.5 * atan2(2 * covariance[p][q], covariance[q][q] - covariance[p][p])
            let c = cos(angle), s = sin(angle)
            let pp = covariance[p][p], qq = covariance[q][q], pq = covariance[p][q]
            covariance[p][p] = c*c*pp - 2*s*c*pq + s*s*qq
            covariance[q][q] = s*s*pp + 2*s*c*pq + c*c*qq
            covariance[p][q] = 0; covariance[q][p] = 0
            for k in 0..<3 {
                if k != p && k != q {
                    let kp = covariance[k][p], kq = covariance[k][q]
                    covariance[k][p] = c*kp - s*kq; covariance[p][k] = covariance[k][p]
                    covariance[k][q] = s*kp + c*kq; covariance[q][k] = covariance[k][q]
                }
                let vp = vectors[k][p], vq = vectors[k][q]
                vectors[k][p] = c*vp - s*vq; vectors[k][q] = s*vp + c*vq
            }
        }
        let order = (0..<3).sorted { covariance[$0][$0] < covariance[$1][$1] }
        guard covariance[order[1]][order[1]] > 1e-6 else { return nil }
        let i = order[0]
        var normal = simd_normalize(SIMD3(vectors[0][i], vectors[1][i], vectors[2][i]))
        if normal.y < 0 { normal = -normal }
        let residuals = points.map { simd_dot(SIMD3(Double($0.x), Double($0.y), Double($0.z)) - mean, normal) }
        guard let low = residuals.min(), let high = residuals.max() else { return nil }
        return SurfaceFit(center: SpatialVector(SIMD3<Float>(mean)), normal: SpatialVector(SIMD3<Float>(normal)), count: points.count,
                          rmsMeters: sqrt(residuals.reduce(0) { $0 + $1*$1 } / Double(points.count)), peakToPeakMeters: high - low, points: points)
    }
}

nonisolated struct DepthFrameEvidence {
    var image: DepthEvidence
    var centerPoint: SpatialVector?
    var centerConfidence: UInt8?
    var fit: SurfaceFit?
}

nonisolated enum DepthProcessing {
    static func read(frame: ARFrame) -> DepthFrameEvidence? {
        guard let depth = frame.sceneDepth else { return nil }
        let buffer = depth.depthMap
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_DepthFloat32 else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float>.stride
        let pixels = base.assumingMemoryBound(to: Float.self)
        let confidence = depth.confidenceMap
        if let confidence { CVPixelBufferLockBaseAddress(confidence, .readOnly) }
        defer { if let confidence { CVPixelBufferUnlockBaseAddress(confidence, .readOnly) } }
        let confidenceBase: UnsafeMutablePointer<UInt8>? = confidence.flatMap {
            guard CVPixelBufferGetWidth($0) == width, CVPixelBufferGetHeight($0) == height else { return nil }
            return CVPixelBufferGetBaseAddress($0)?.assumingMemoryBound(to: UInt8.self)
        }
        let confidenceStride = confidence.map(CVPixelBufferGetBytesPerRow) ?? 0
        let step = max(1, width / 64), targetWidth = width / step, targetHeight = height / step
        var values: [Float?] = [], levels: [UInt8] = []
        values.reserveCapacity(targetWidth * targetHeight); levels.reserveCapacity(targetWidth * targetHeight)
        for y in 0..<targetHeight { for x in 0..<targetWidth {
            let value = pixels[y*step*stride + x*step]
            values.append(value.isFinite && value > 0 ? value : nil)
            if let confidenceBase { levels.append(min(2, confidenceBase[y*step*confidenceStride + x*step])) }
        } }
        let pose = SpatialTransform(frame.camera.transform)
        var image = DepthEvidence(width: targetWidth, height: targetHeight, meters: values, confidence: levels,
                                  minimum: 0.25, maximum: 5, cameraPose: pose)
        let scaleX = Float(width) / Float(frame.camera.imageResolution.width)
        let scaleY = Float(height) / Float(frame.camera.imageResolution.height)
        let k = frame.camera.intrinsics
        let fx = k.columns.0.x * scaleX, fy = k.columns.1.y * scaleY
        let cx = k.columns.2.x * scaleX, cy = k.columns.2.y * scaleY
        guard fx > 0, fy > 0 else { return nil }
        image.intrinsics = [fx / Float(step), fy / Float(step), cx / Float(step), cy / Float(step)]
        func worldPoint(x: Int, y: Int) -> SpatialVector? {
            let z = pixels[y*stride + x]
            guard z.isFinite, z > 0 else { return nil }
            // ARKit camera coordinates face -Z and have +Y upward; image rows increase downward.
            return pose.worldPoint(SpatialVector(x: (Float(x)-cx)*z/fx, y: -(Float(y)-cy)*z/fy, z: -z))
        }
        let midX = width/2, midY = height/2
        var patch: [SpatialVector] = []
        for y in max(0, midY-12)...min(height-1, midY+12) {
            for x in max(0, midX-12)...min(width-1, midX+12) {
                guard confidenceBase.map({ $0[y*confidenceStride+x] >= 1 }) ?? true,
                      let point = worldPoint(x: x, y: y) else { continue }
                patch.append(point)
            }
        }
        image.centerPoint = worldPoint(x: midX, y: midY)
        return DepthFrameEvidence(image: image, centerPoint: worldPoint(x: midX, y: midY),
                                  centerConfidence: confidenceBase.map { $0[midY*confidenceStride+midX] }, fit: SurfaceFitting.fit(patch))
    }
}
