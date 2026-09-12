import SwiftUI
import Charts

enum ProTheme {
    static let signal = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.72, blue: 1, alpha: 1)
            : UIColor(red: 0, green: 0.32, blue: 0.78, alpha: 1)
    })
    static let band = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.85, blue: 0.78, alpha: 1)
            : UIColor(red: 0.12, green: 0.43, blue: 0.38, alpha: 1)
    })
    static let secondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.66, green: 0.70, blue: 0.74, alpha: 1)
            : UIColor(red: 0.35, green: 0.39, blue: 0.43, alpha: 1)
    })
    static let face = Color(uiColor: .secondarySystemGroupedBackground)
}

enum InstrumentViewMode: String, CaseIterable, Identifiable {
    case live, inspect, compare
    var id: String { rawValue }
    var title: String {
        switch self {
        case .live: "Gauges"
        case .inspect: "Info"
        case .compare: "Compare"
        }
    }
}

struct InstrumentSegments: View {
    @Binding var selection: InstrumentViewMode
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight
    var body: some View {
        if dynamicType.isAccessibilitySize {
            Menu {
                ForEach(InstrumentViewMode.allCases) { mode in
                    Button { selection = mode } label: {
                        if selection == mode { Label(mode.title, systemImage: "checkmark") }
                        else { Text(mode.title) }
                    }.accessibilityIdentifier("instrument.mode.\(mode.id.lowercased())")
                }
            } label: {
                HStack {
                    Text(selection.title).font(.system(.headline, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.body)
                }.padding(14).frame(maxWidth: .infinity, minHeight: 46)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("View mode")
            .accessibilityValue(selection.title)
            .accessibilityIdentifier("instrument.mode-menu")
        } else {
            HStack(spacing: 4) {
                ForEach(InstrumentViewMode.allCases) { mode in
                    Button { selection = mode } label: {
                        Text(mode.title)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .contentShape(Rectangle())
                            .foregroundStyle(selection == mode ? .white : .primary)
                            .background {
                                if selection == mode {
                                    RoundedRectangle(cornerRadius: 10).fill(MC.action)
                                        .matchedGeometryEffect(id: "selection", in: highlight)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == mode ? .isSelected : [])
                    .accessibilityIdentifier("instrument.mode.\(mode.id.lowercased())")
                }
            }
            .padding(4)
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selection)
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}

struct MeasurementValue: View {
    let value: Double?
    let kind: InstrumentKind
    var signed = false
    var compact = false
    @ScaledMetric(relativeTo: .largeTitle) private var size = 66
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value.map { kind.formatted($0, signed: signed) } ?? "—")
                .font(.system(size: compact ? size * 0.56 : size, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
            Text(signed ? kind.deltaUnit : kind.unit)
                .font(compact ? .callout : .title3).foregroundStyle(ProTheme.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\(kind.formatted($0, signed: signed)) \(signed ? kind.deltaUnit : kind.unit)" } ?? "No reading")
    }
}

struct InstrumentArc: View {
    let value: Double?
    let range: ClosedRange<Double>
    var band: ClosedRange<Double>?
    var threshold: Double?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width / 2 - 30, (size.height - 44) / 1.65)
            let center = CGPoint(x: size.width / 2, y: radius + 26)
            func angle(_ value: Double) -> Double {
                140 + min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound))) * 260
            }
            func point(_ degrees: Double, radius: Double) -> CGPoint {
                CGPoint(x: center.x + cos(degrees * .pi / 180) * radius, y: center.y + sin(degrees * .pi / 180) * radius)
            }
            let tickColor = scheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.4)
            for index in 0 ... 60 {
                let degrees = 140 + Double(index) / 60 * 260
                let major = index % 10 == 0
                var path = Path()
                path.move(to: point(degrees, radius: radius - (major ? 13 : 7)))
                path.addLine(to: point(degrees, radius: radius))
                context.stroke(path, with: .color(tickColor), lineWidth: major ? 1.5 : 0.8)
                if major {
                    let label = range.lowerBound + Double(index) / 60 * (range.upperBound - range.lowerBound)
                    context.draw(Text(MeasurementMath.scaleLabel(label, range: range)).font(.system(size: 11, design: .rounded)).monospacedDigit().foregroundStyle(ProTheme.secondary), at: point(degrees, radius: radius + 17))
                }
            }
            if let band {
                var arc = Path()
                arc.addArc(center: center, radius: radius - 4, startAngle: .degrees(angle(band.lowerBound)), endAngle: .degrees(angle(band.upperBound)), clockwise: false)
                context.stroke(arc, with: .color(ProTheme.band), style: StrokeStyle(lineWidth: 7, lineCap: .butt))
            }
            if let threshold, range.contains(threshold) {
                var marker = Path()
                marker.move(to: point(angle(threshold), radius: radius - 19))
                marker.addLine(to: point(angle(threshold), radius: radius + 4))
                context.stroke(marker, with: .color(scheme == .dark ? .white : .black), lineWidth: 2)
            }
            if let value {
                let degrees = angle(value)
                var needle = Path()
                needle.move(to: point(degrees + 90, radius: 2.5))
                needle.addLine(to: point(degrees, radius: radius - 23))
                needle.addLine(to: point(degrees - 90, radius: 2.5))
                needle.closeSubpath()
                context.fill(needle, with: .color(ProTheme.signal))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)), with: .color(ProTheme.signal))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)), with: .color(ProTheme.face))
            }
        }
        .frame(height: 220)
        .accessibilityHidden(true)
    }
}

struct LinearInstrumentScale: View {
    let range: ClosedRange<Double>
    var value: Double?
    var band: ClosedRange<Double>?
    var threshold: Double?

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                let width = geometry.size.width
                let span = range.upperBound - range.lowerBound
                let fraction: (Double) -> CGFloat = { CGFloat(min(1, max(0, ($0 - range.lowerBound) / span))) }
                Path { path in
                    for index in 0 ... 60 {
                        let x = Double(index) / 60 * width
                        path.move(to: CGPoint(x: x, y: 11))
                        path.addLine(to: CGPoint(x: x, y: index % 10 == 0 ? 33 : 24))
                    }
                }.stroke(.secondary.opacity(0.6), lineWidth: 1)
                if let band {
                    Rectangle().fill(ProTheme.band.opacity(0.3))
                        .frame(width: max(2, (fraction(band.upperBound) - fraction(band.lowerBound)) * width), height: 25)
                        .offset(x: fraction(band.lowerBound) * width, y: 8)
                }
                if let threshold, range.contains(threshold) {
                    Rectangle().fill(.primary).frame(width: 2, height: 36).offset(x: fraction(threshold) * width - 1)
                }
                if let value {
                    Rectangle().fill(ProTheme.signal).frame(width: 3, height: 38).offset(x: fraction(value) * width - 1.5)
                }
            }.frame(height: 40)
            HStack {
                Text(MeasurementMath.scaleLabel(range.lowerBound, range: range))
                Spacer()
                Text(MeasurementMath.scaleLabel((range.lowerBound + range.upperBound) / 2, range: range))
                Spacer()
                Text(MeasurementMath.scaleLabel(range.upperBound, range: range))
            }.font(.caption).monospacedDigit().foregroundStyle(ProTheme.secondary)
        }.accessibilityHidden(true)
    }
}

struct LevelInstrument: View {
    let point: MeasurementPoint?
    var reference: MeasurementPoint?
    var body: some View {
        let pitch = (point?.auxiliary["pitch"] ?? 0) - (reference?.auxiliary["pitch"] ?? 0)
        let roll = (point?.auxiliary["roll"] ?? 0) - (reference?.auxiliary["roll"] ?? 0)
        ZStack {
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.42
                for step in 1 ... 3 {
                    let r = radius * Double(step) / 3
                    let circle = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                    context.stroke(circle, with: .color(.secondary.opacity(step == 3 ? 0.6 : 0.25)), lineWidth: 1)
                }
                var axes = Path()
                axes.move(to: CGPoint(x: center.x - radius - 12, y: center.y)); axes.addLine(to: CGPoint(x: center.x + radius + 12, y: center.y))
                axes.move(to: CGPoint(x: center.x, y: center.y - radius - 12)); axes.addLine(to: CGPoint(x: center.x, y: center.y + radius + 12))
                context.stroke(axes, with: .color(.secondary.opacity(0.4)), lineWidth: 1)
                if point != nil {
                    let x = center.x + min(1, max(-1, roll / 10)) * radius
                    let y = center.y - min(1, max(-1, pitch / 10)) * radius
                    context.fill(Path(ellipseIn: CGRect(x: x - 13, y: y - 13, width: 26, height: 26)), with: .color(ProTheme.signal.opacity(0.18)))
                    context.stroke(Path(ellipseIn: CGRect(x: x - 13, y: y - 13, width: 26, height: 26)), with: .color(ProTheme.signal), lineWidth: 2)
                    context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(ProTheme.signal))
                }
            }.frame(height: 220)
            VStack {
                Text("10°").font(.caption).foregroundStyle(ProTheme.secondary)
                Spacer()
                HStack { Text("Roll \(roll.formatted(.number.precision(.fractionLength(1))))°"); Spacer(); Text("Pitch \(pitch.formatted(.number.precision(.fractionLength(1))))°") }
                    .font(.caption).monospacedDigit().foregroundStyle(ProTheme.secondary)
            }.padding(.vertical, 3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level")
        .accessibilityValue("Roll \(roll.formatted()) degrees, pitch \(pitch.formatted()) degrees")
    }
}

struct CompassInstrument: View {
    let heading: Double?
    var baseline: Double?
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.4
            for tick in 0 ..< 72 {
                let degrees = Double(tick) * 5 - (heading ?? 0) - 90
                let angle = degrees * .pi / 180
                let major = tick % 6 == 0
                var path = Path()
                path.move(to: CGPoint(x: center.x + cos(angle) * (radius - (major ? 13 : 6)), y: center.y + sin(angle) * (radius - (major ? 13 : 6))))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
                context.stroke(path, with: .color(tick == 0 ? ProTheme.signal : .secondary.opacity(0.65)), lineWidth: major ? 2 : 1)
                if tick % 18 == 0 {
                    context.draw(Text(["N", "E", "S", "W"][tick / 18]).font(.system(.title3, design: .rounded).bold()).foregroundStyle(tick == 0 ? ProTheme.signal : .primary), at: CGPoint(x: center.x + cos(angle) * (radius + 18), y: center.y + sin(angle) * (radius + 18)))
                }
            }
            var pointer = Path()
            pointer.move(to: CGPoint(x: center.x, y: center.y - 46)); pointer.addLine(to: CGPoint(x: center.x - 15, y: center.y + 18)); pointer.addLine(to: CGPoint(x: center.x, y: center.y + 9)); pointer.addLine(to: CGPoint(x: center.x + 15, y: center.y + 18)); pointer.closeSubpath()
            context.fill(pointer, with: .color(ProTheme.signal))
            if let baseline, let heading {
                let angle = (baseline - heading - 90) * .pi / 180
                let p = CGPoint(x: center.x + cos(angle) * (radius - 27), y: center.y + sin(angle) * (radius - 27))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(ProTheme.band))
            }
        }.frame(height: 230).accessibilityHidden(true)
    }
}

struct InstrumentHistoryChart: View {
    let points: [MeasurementPoint]
    let kind: InstrumentKind
    let range: ClosedRange<Double>
    var baseline: [MeasurementPoint] = []
    var threshold: Double?
    var events: [CaptureEvent] = []
    @Binding var selectedElapsed: Double?
    var height: CGFloat = 150
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .caption) private var axisSize = 12

    private var selected: MeasurementPoint? {
        guard let selectedElapsed else { return nil }
        return points.min { abs($0.elapsed - selectedElapsed) < abs($1.elapsed - selectedElapsed) }
    }
    var body: some View {
        Chart {
            ForEach(MeasurementMath.plotPoints(baseline, kind: kind, limit: 160)) { point in
                LineMark(x: .value("Seconds", point.elapsed), y: .value(kind.unit, point.value), series: .value("Segment", "baseline-\(point.segment)"))
                    .foregroundStyle(.secondary.opacity(0.65)).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
            ForEach(MeasurementMath.plotPoints(points, kind: kind, limit: 220)) { point in
                LineMark(x: .value("Seconds", point.elapsed), y: .value(kind.unit, point.value), series: .value("Segment", "current-\(point.segment)"))
                    .foregroundStyle(ProTheme.signal).lineStyle(StrokeStyle(lineWidth: 2))
            }
            if points.count == 1, let point = points.first {
                PointMark(x: .value("Seconds", point.elapsed), y: .value(kind.unit, point.value)).foregroundStyle(ProTheme.signal)
            }
            if let threshold, range.contains(threshold) {
                RuleMark(y: .value("Threshold", threshold)).lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4])).foregroundStyle(ProTheme.secondary)
            }
            if let selected {
                RuleMark(x: .value("Selected time", selected.elapsed)).foregroundStyle(ProTheme.signal.opacity(0.55))
                PointMark(x: .value("Seconds", selected.elapsed), y: .value(kind.unit, selected.value)).foregroundStyle(ProTheme.signal).symbolSize(35)
            }
            ForEach(events.suffix(8)) { event in
                RuleMark(x: .value("Mark", event.elapsed)).foregroundStyle(.secondary.opacity(0.25)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }
        }
        .chartYScale(domain: range)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: dynamicType.isAccessibilitySize ? 3 : 4)) { value in AxisGridLine().foregroundStyle(.secondary.opacity(0.12)); AxisValueLabel { if let number = value.as(Double.self) { Text("\(number.formatted(.number.precision(.fractionLength(0))))s").font(.system(size: min(axisSize, 22))).foregroundStyle(ProTheme.secondary) } } } }
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: dynamicType.isAccessibilitySize ? 3 : 4)) { value in AxisGridLine().foregroundStyle(.secondary.opacity(0.15)); AxisValueLabel { if let number = value.as(Double.self) { Text(MeasurementMath.scaleLabel(number, range: range)).font(.system(size: min(axisSize, 22))).foregroundStyle(ProTheme.secondary) } } } }
        .chartXSelection(value: Binding(get: { selectedElapsed }, set: { if let value = $0 { selectedElapsed = value } }))
        .frame(height: dynamicType.isAccessibilitySize ? max(height, 240) : height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title) history")
        .accessibilityValue(selected.map { "\(kind.formatted($0.value)) \(kind.unit), \($0.elapsed.formatted(.number.precision(.fractionLength(1)))) seconds" } ?? "\(points.count) readings. Adjust to inspect a reading.")
        .accessibilityAdjustableAction { direction in
            guard !points.isEmpty else { return }
            let current = selected.flatMap { point in points.firstIndex { $0.id == point.id } } ?? points.count - 1
            let next = direction == .increment ? min(points.count - 1, current + 1) : max(0, current - 1)
            selectedElapsed = points[next].elapsed
        }
        .accessibilityIdentifier("instrument.history")
    }
}

struct SpectrumChart: View {
    let spectrum: MeasurementSpectrum
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Vibration spectrum").font(.headline); Spacer(); Text("\(spectrum.resolution.formatted(.number.precision(.fractionLength(1)))) Hz resolution").font(.caption).foregroundStyle(ProTheme.secondary) }
            Chart(spectrum.bins) { bin in
                BarMark(x: .value("Frequency", bin.frequency), y: .value("Amplitude (g)", bin.amplitude)).foregroundStyle(ProTheme.signal)
            }.frame(height: 150)
            Text("Dominant axis · Hann window · \(spectrum.sampleRate.formatted(.number.precision(.fractionLength(1)))) samples/s. The phone's usable sensor bandwidth may be lower.")
                .font(.caption).foregroundStyle(ProTheme.secondary)
        }
    }
}
