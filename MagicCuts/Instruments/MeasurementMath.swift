import Foundation

nonisolated struct MeasurementSummary: Codable, Equatable, Sendable {
    var count: Int
    var minimum: Double
    var maximum: Double
    var median: Double
    var q25: Double
    var q75: Double
    var p95: Double
    var mean: Double
    var spread: Double { q75 - q25 }
}

nonisolated struct SpectrumBin: Identifiable, Equatable, Sendable {
    var frequency: Double
    var amplitude: Double
    var id: Double { frequency }
}

nonisolated struct MeasurementSpectrum: Sendable {
    var bins: [SpectrumBin]
    var sampleRate: Double
    var resolution: Double
    var dominantFrequency: Double?
}

nonisolated enum MeasurementMath {
    static func quantile(_ values: [Double], fraction: Double) -> Double? {
        let sorted = values.filter(\.isFinite).sorted()
        guard !sorted.isEmpty, fraction.isFinite, (0 ... 1).contains(fraction) else { return nil }
        return quantileSorted(sorted, fraction: fraction)
    }

    private static func quantileSorted(_ sorted: [Double], fraction: Double) -> Double {
        let index = Double(sorted.count - 1) * fraction
        let lower = Int(index), upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (index - Double(lower))
    }

    static func summary(_ values: [Double], kind: InstrumentKind? = nil) -> MeasurementSummary? {
        let finite = values.filter(\.isFinite)
        if kind == .heading {
            guard let center = circularMean(finite), var result = summary(finite.map { center + angularDifference($0, from: center) }) else { return nil }
            result.median = normalizedHeading(result.median)
            result.mean = center
            return result
        }
        let valid = finite.sorted()
        guard let minimum = valid.first, let maximum = valid.last else { return nil }
        let median = quantileSorted(valid, fraction: 0.5)
        let q25 = quantileSorted(valid, fraction: 0.25), q75 = quantileSorted(valid, fraction: 0.75)
        let p95 = quantileSorted(valid, fraction: 0.95)
        return MeasurementSummary(count: valid.count, minimum: minimum, maximum: maximum, median: median, q25: q25, q75: q75, p95: p95, mean: valid.reduce(0) { $0 + $1 / Double(valid.count) })
    }

    static func rms(_ values: [Double]) -> Double? {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        let largest = values.map(abs).max() ?? 0
        guard largest > 0 else { return 0 }
        // Scaling avoids overflow when squaring otherwise valid input.
        return largest * sqrt(values.reduce(0) { $0 + pow($1 / largest, 2) } / Double(values.count))
    }

    static func circularMean(_ degrees: [Double]) -> Double? {
        let valid = degrees.filter(\.isFinite)
        guard !valid.isEmpty else { return nil }
        let sine = valid.reduce(0) { $0 + sin($1 * .pi / 180) } / Double(valid.count)
        let cosine = valid.reduce(0) { $0 + cos($1 * .pi / 180) } / Double(valid.count)
        guard hypot(sine, cosine) > 0.000_001 else { return nil }
        let result = atan2(sine, cosine) * 180 / .pi
        return (result + 360).truncatingRemainder(dividingBy: 360)
    }

    static func angularDifference(_ value: Double, from baseline: Double) -> Double {
        let difference = (value - baseline).truncatingRemainder(dividingBy: 360)
        return difference > 180 ? difference - 360 : difference < -180 ? difference + 360 : difference
    }

    static func normalizedHeading(_ degrees: Double) -> Double { (degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) }

    static func tiltDifference(_ point: MeasurementPoint, reference: MeasurementPoint) -> Double? {
        guard let x = point.auxiliary["gravityX"], let y = point.auxiliary["gravityY"], let z = point.auxiliary["gravityZ"],
              let rx = reference.auxiliary["gravityX"], let ry = reference.auxiliary["gravityY"], let rz = reference.auxiliary["gravityZ"] else { return nil }
        let length = sqrt(x * x + y * y + z * z) * sqrt(rx * rx + ry * ry + rz * rz)
        guard length.isFinite, length > 0 else { return nil }
        return acos(min(1, max(-1, (x * rx + y * ry + z * rz) / length))) * 180 / .pi
    }

    static func rebased(_ points: [MeasurementPoint]) -> [MeasurementPoint] {
        guard let first = points.first else { return [] }
        return points.map { MeasurementPoint(elapsed: $0.elapsed - first.elapsed, date: $0.date, value: $0.value, segment: $0.segment, auxiliary: $0.auxiliary, placement: $0.placement) }
    }

    static func plotPoints(_ points: [MeasurementPoint], kind: InstrumentKind, limit: Int) -> [MeasurementPoint] {
        guard !points.isEmpty else { return [] }
        var groups: [[MeasurementPoint]] = []
        for point in points {
            if let previous = groups.last?.last,
               previous.segment == point.segment,
               !(kind == .heading && abs(previous.value - point.value) > 180) {
                groups[groups.count - 1].append(point)
            } else { groups.append([point]) }
        }
        // Reduce each segment separately. No reduction can erase both sides of an interruption.
        let allocation = max(2, limit / groups.count)
        return groups.enumerated().flatMap { index, group in
            decimated(group, limit: allocation).map { MeasurementPoint(id: $0.id, elapsed: $0.elapsed, date: $0.date, value: $0.value, segment: index, auxiliary: $0.auxiliary, placement: $0.placement) }
        }
    }

    static func scaleLabel(_ value: Double, range: ClosedRange<Double>) -> String {
        let step = (range.upperBound - range.lowerBound) / 6
        let decimals = max(0, min(4, Int(ceil(-log10(step)))))
        return value.formatted(.number.precision(.fractionLength(decimals)))
    }

    static func delta(_ value: Double, baseline: Double, kind: InstrumentKind) -> Double {
        kind == .heading ? angularDifference(value, from: baseline) : value - baseline
    }

    static func powerLevel(rms: Double, floor: Double = -160) -> Double? {
        guard rms.isFinite, rms >= 0 else { return nil }
        return rms == 0 ? floor : max(floor, 20 * log10(rms))
    }

    static func signalThreshold(nearby: [Double], away: [Double]) -> Int? {
        let near = nearby.filter { $0.isFinite && (-126 ... -1).contains($0) }
        let far = away.filter { $0.isFinite && (-126 ... -1).contains($0) }
        guard near.count >= 3, far.count >= 3,
              let lowerNear = quantile(near, fraction: 0.25), let upperFar = quantile(far, fraction: 0.75),
              lowerNear - upperFar >= 2 else { return nil }
        let candidate = Int(((lowerNear + upperFar) / 2).rounded())
        guard (-100 ... -1).contains(candidate) else { return nil }
        return candidate
    }

    static func decimated(_ points: [MeasurementPoint], limit: Int) -> [MeasurementPoint] {
        guard limit > 1, points.count > limit else { return points }
        // Preserve extrema in each chronological bucket, so the visible trace retains spikes.
        let bucketCount = max(1, (limit - 2) / 2)
        let inner = Array(points.dropFirst().dropLast())
        var result = [points[0]]
        for bucket in 0 ..< bucketCount {
            let start = bucket * inner.count / bucketCount
            let end = (bucket + 1) * inner.count / bucketCount
            let slice = inner[start ..< end]
            if let low = slice.min(by: { $0.value < $1.value }), let high = slice.max(by: { $0.value < $1.value }) {
                result.append(contentsOf: low.id == high.id ? [low] : [low, high].sorted { $0.elapsed < $1.elapsed })
            }
        }
        result.append(points[points.count - 1])
        return result
    }

    static func spectrum(_ points: [MeasurementPoint]) -> MeasurementSpectrum? {
        // Fixed 128-sample Hann-window DFT; actual cadence must be sufficiently uniform.
        let n = 128
        guard points.count >= n else { return nil }
        let window = Array(points.suffix(n))
        guard window.allSatisfy({ $0.value.isFinite && $0.elapsed.isFinite }),
              Set(window.map(\.segment)).count == 1 else { return nil }
        let intervals = zip(window.dropFirst(), window).map { $0.elapsed - $1.elapsed }
        guard let dt = quantile(intervals, fraction: 0.5), dt > 0,
              intervals.allSatisfy({ abs($0 - dt) <= dt * 0.25 }) else { return nil }
        let mean = window.map(\.value).reduce(0, +) / Double(n)
        let weights = (0 ..< n).map { 0.5 - 0.5 * cos(2 * Double.pi * Double($0) / Double(n - 1)) }
        let values = zip(window, weights).map { ($0.value - mean) * $1 }
        let normalization = weights.reduce(0, +)
        let rate = 1 / dt
        let bins = (1 ..< n / 2).map { frequencyIndex in
            var real = 0.0, imaginary = 0.0
            for sampleIndex in 0 ..< n {
                let angle = -2 * Double.pi * Double(frequencyIndex * sampleIndex) / Double(n)
                real += values[sampleIndex] * cos(angle)
                imaginary += values[sampleIndex] * sin(angle)
            }
            return SpectrumBin(frequency: Double(frequencyIndex) * rate / Double(n), amplitude: 2 * hypot(real, imaginary) / normalization)
        }
        let peak = bins.max { $0.amplitude < $1.amplitude }
        return MeasurementSpectrum(bins: bins, sampleRate: rate, resolution: rate / Double(n), dominantFrequency: (peak?.amplitude ?? 0) > 0.000_001 ? peak?.frequency : nil)
    }
}
