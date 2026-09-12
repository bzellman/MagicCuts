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

    static var canvasUIColor: UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 15 / 255, green: 20 / 255, blue: 26 / 255, alpha: 1)
                : UIColor(red: 242 / 255, green: 245 / 255, blue: 247 / 255, alpha: 1)
        }
    }

    static func applyOpaqueNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = canvasUIColor
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear
        let bar = UINavigationBar.appearance()
        bar.isTranslucent = false
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
    }
}

struct OpaqueNavigationBar: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Host { Host() }
    func updateUIViewController(_ host: Host, context: Context) { host.apply() }

    final class Host: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            apply()
        }
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            apply()
        }
        func apply() {
            guard let bar = navigationController?.navigationBar else { return }
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = ProTheme.canvasUIColor
            appearance.backgroundEffect = nil
            appearance.shadowColor = .clear
            bar.isTranslucent = false
            bar.standardAppearance = appearance
            bar.scrollEdgeAppearance = appearance
            bar.compactAppearance = appearance
            bar.compactScrollEdgeAppearance = appearance
        }
    }
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
                }.padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 46)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .accessibilityLabel("View mode")
            .accessibilityValue(selection.title)
            .accessibilityIdentifier("instrument.mode-menu")
        } else {
            HStack(spacing: 3) {
                ForEach(InstrumentViewMode.allCases) { mode in
                    Button { selection = mode } label: {
                        Text(mode.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .contentShape(Rectangle())
                            .foregroundStyle(selection == mode ? Color.white : ProTheme.secondary)
                            .background {
                                if selection == mode {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous).fill(MC.action)
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
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .largeTitle) private var size = 66
    private var unit: String { signed ? kind.deltaUnit : kind.unit }
    var body: some View {
        let figure = Text(value.map { kind.formatted($0, signed: signed) } ?? "—")
            .font(.system(size: compact ? size * 0.5 : size, weight: .semibold, design: .rounded))
            .monospacedDigit().lineLimit(1).minimumScaleFactor(0.45)
        let unitText = Text(unit)
            .font(.system(compact ? .caption : .callout, design: .rounded).weight(.medium))
            .foregroundStyle(ProTheme.secondary)
            .monospacedDigit()
        Group {
            if dynamicType.isAccessibilitySize {
                VStack(spacing: 2) {
                    figure
                    unitText
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    figure
                    unitText
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.map { "\(kind.formatted($0, signed: signed)) \(unit)" } ?? "No reading")
    }
}

struct ChapterLine: View {
    let parts: [String]
    var tint: Color = ProTheme.secondary
    var body: some View {
        Text(parts.filter { !$0.isEmpty }.joined(separator: "  ·  "))
            .font(.system(.caption, design: .rounded).weight(.medium))
            .foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .monospacedDigit()
    }
}

struct InstrumentArc: View {
    let value: Double?
    let range: ClosedRange<Double>
    var band: ClosedRange<Double>?
    var threshold: Double?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .caption2) private var tickSize = 10

    var body: some View {
        Canvas { context, size in
            let radius = min(size.width / 2 - 32, size.height * 0.46)
            let center = CGPoint(x: size.width / 2, y: radius + 22)
            func angle(_ value: Double) -> Double {
                150 + min(1, max(0, (value - range.lowerBound) / (range.upperBound - range.lowerBound))) * 240
            }
            func point(_ degrees: Double, radius: Double) -> CGPoint {
                CGPoint(x: center.x + cos(degrees * .pi / 180) * radius, y: center.y + sin(degrees * .pi / 180) * radius)
            }
            let tickColor = scheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.34)
            var rail = Path()
            rail.addArc(center: center, radius: radius, startAngle: .degrees(150), endAngle: .degrees(390), clockwise: false)
            context.stroke(rail, with: .color(tickColor.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            for index in 0 ... 48 {
                let degrees = 150 + Double(index) / 48 * 240
                let major = index % 8 == 0
                var path = Path()
                path.move(to: point(degrees, radius: radius - (major ? 11 : 5)))
                path.addLine(to: point(degrees, radius: radius))
                context.stroke(path, with: .color(tickColor), lineWidth: major ? 1.25 : 0.6)
                if major {
                    let label = range.lowerBound + Double(index) / 48 * (range.upperBound - range.lowerBound)
                    context.draw(
                        Text(MeasurementMath.scaleLabel(label, range: range))
                            .font(.system(size: min(tickSize, 13), design: .rounded).weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(ProTheme.secondary),
                        at: point(degrees, radius: radius + 13)
                    )
                }
            }
            if let band {
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .degrees(angle(band.lowerBound)), endAngle: .degrees(angle(band.upperBound)), clockwise: false)
                context.stroke(arc, with: .color(ProTheme.band), style: StrokeStyle(lineWidth: 3, lineCap: .butt))
            }
            if let threshold, range.contains(threshold) {
                var marker = Path()
                marker.move(to: point(angle(threshold), radius: radius - 16))
                marker.addLine(to: point(angle(threshold), radius: radius + 3))
                context.stroke(marker, with: .color(scheme == .dark ? .white : .black), lineWidth: 1.25)
            }
            if let value {
                let degrees = angle(value)
                var needle = Path()
                needle.move(to: point(degrees, radius: radius - 4))
                needle.addLine(to: point(degrees + 92, radius: 3.2))
                needle.addLine(to: point(degrees + 180, radius: 10))
                needle.addLine(to: point(degrees - 92, radius: 3.2))
                needle.closeSubpath()
                context.fill(needle, with: .color(ProTheme.signal))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(ProTheme.signal))
                context.fill(Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)), with: .color(MC.canvas))
            }
        }
        .frame(height: sizeClass == .regular ? 280 : 236)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LinearInstrumentScale: View {
    let range: ClosedRange<Double>
    var value: Double?
    var band: ClosedRange<Double>?
    var threshold: Double?
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption2) private var labelSize = 11

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 20
            let width = size.width
            let usable = max(width - inset * 2, 1)
            let railY = size.height * 0.42
            let span = range.upperBound - range.lowerBound
            guard span > 0 else { return }
            let xAt: (Double) -> CGFloat = { inset + CGFloat(min(1, max(0, ($0 - range.lowerBound) / span))) * usable }
            let tickColor = scheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.34)
            var rail = Path()
            rail.move(to: CGPoint(x: inset, y: railY))
            rail.addLine(to: CGPoint(x: width - inset, y: railY))
            context.stroke(rail, with: .color(tickColor.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            for index in 0 ... 48 {
                let x = inset + CGFloat(index) / 48 * usable
                let major = index % 8 == 0
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: railY - (major ? 11 : 5)))
                tick.addLine(to: CGPoint(x: x, y: railY + (major ? 11 : 5)))
                context.stroke(tick, with: .color(tickColor), lineWidth: major ? 1.25 : 0.6)
                if major {
                    let label = range.lowerBound + Double(index) / 48 * span
                    let anchor: UnitPoint = index == 0 ? .leading : index == 48 ? .trailing : .center
                    context.draw(
                        Text(MeasurementMath.scaleLabel(label, range: range))
                            .font(.system(size: min(labelSize, 13), design: .rounded).weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(ProTheme.secondary),
                        at: CGPoint(x: x, y: railY + 22),
                        anchor: anchor
                    )
                }
            }
            if let band {
                var interval = Path()
                interval.move(to: CGPoint(x: xAt(band.lowerBound), y: railY))
                interval.addLine(to: CGPoint(x: xAt(band.upperBound), y: railY))
                context.stroke(interval, with: .color(ProTheme.band), style: StrokeStyle(lineWidth: 3, lineCap: .butt))
            }
            if let threshold, range.contains(threshold) {
                let x = xAt(threshold)
                var marker = Path()
                marker.move(to: CGPoint(x: x, y: railY - 16))
                marker.addLine(to: CGPoint(x: x, y: railY + 16))
                context.stroke(marker, with: .color(scheme == .dark ? .white : .black), lineWidth: 1.25)
            }
            if let value {
                let x = xAt(value)
                var mark = Path()
                mark.move(to: CGPoint(x: x, y: railY - 16))
                mark.addLine(to: CGPoint(x: x, y: railY + 16))
                context.stroke(mark, with: .color(ProTheme.signal), style: StrokeStyle(lineWidth: 3, lineCap: .butt))
            }
        }
        .frame(height: 56)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct LevelInstrument: View {
    let point: MeasurementPoint?
    var reference: MeasurementPoint?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .caption2) private var tickSize = 10
    var body: some View {
        let pitch = (point?.auxiliary["pitch"] ?? 0) - (reference?.auxiliary["pitch"] ?? 0)
        let roll = (point?.auxiliary["roll"] ?? 0) - (reference?.auxiliary["roll"] ?? 0)
        let leveled = abs(pitch) < 0.5 && abs(roll) < 0.5
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.46)
            let radius = min(size.width / 2 - 28, size.height * 0.38)
            let tickColor = scheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.34)
            func point(at degrees: Double, radius: Double) -> CGPoint {
                CGPoint(x: center.x + cos(degrees * .pi / 180) * radius, y: center.y + sin(degrees * .pi / 180) * radius)
            }
            var rail = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.stroke(rail, with: .color(tickColor.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            var inner = Path(ellipseIn: CGRect(x: center.x - radius * 0.5, y: center.y - radius * 0.5, width: radius, height: radius))
            context.stroke(inner, with: .color(leveled ? ProTheme.band : tickColor.opacity(0.28)), lineWidth: leveled ? 1.5 : 0.8)
            var axes = Path()
            axes.move(to: point(at: 180, radius: radius + 6)); axes.addLine(to: point(at: 0, radius: radius + 6))
            axes.move(to: point(at: 270, radius: radius + 6)); axes.addLine(to: point(at: 90, radius: radius + 6))
            context.stroke(axes, with: .color(tickColor.opacity(0.35)), lineWidth: 0.8)
            for index in 0 ..< 48 {
                let degrees = Double(index) / 48 * 360
                let major = index % 8 == 0
                var tick = Path()
                tick.move(to: point(at: degrees, radius: radius - (major ? 11 : 5)))
                tick.addLine(to: point(at: degrees, radius: radius))
                context.stroke(tick, with: .color(tickColor), lineWidth: major ? 1.25 : 0.6)
            }
            for (degrees, label) in [(270.0, "P"), (0.0, "R"), (180.0, "R")] {
                context.draw(
                    Text(label)
                        .font(.system(size: min(tickSize, 13), design: .rounded).weight(.medium))
                        .foregroundStyle(ProTheme.secondary),
                    at: point(at: degrees, radius: radius + 14)
                )
            }
            if point != nil {
                let x = center.x + min(1, max(-1, roll / 10)) * (radius - 8)
                let y = center.y - min(1, max(-1, pitch / 10)) * (radius - 8)
                let degrees = atan2(y - center.y, x - center.x) * 180 / .pi
                if !leveled {
                    var needle = Path()
                    needle.move(to: point(at: degrees, radius: radius - 4))
                    needle.addLine(to: point(at: degrees + 92, radius: 3.2))
                    needle.addLine(to: point(at: degrees + 180, radius: 10))
                    needle.addLine(to: point(at: degrees - 92, radius: 3.2))
                    needle.closeSubpath()
                    context.fill(needle, with: .color(ProTheme.signal))
                }
                context.stroke(Path(ellipseIn: CGRect(x: x - 14, y: y - 14, width: 28, height: 28)), with: .color(ProTheme.signal), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                context.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)), with: .color(ProTheme.signal))
                context.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(MC.canvas))
            }
        }
        .frame(height: sizeClass == .regular ? 280 : 236)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level")
        .accessibilityValue("Roll \(roll.formatted()) degrees, pitch \(pitch.formatted()) degrees")
    }
}

struct CompassInstrument: View {
    let heading: Double?
    var baseline: Double?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @ScaledMetric(relativeTo: .caption2) private var cardSize = 11
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width / 2 - 28, size.height * 0.38)
            let tickColor = scheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.34)
            func point(at degrees: Double, radius: Double) -> CGPoint {
                CGPoint(x: center.x + cos(degrees * .pi / 180) * radius, y: center.y + sin(degrees * .pi / 180) * radius)
            }
            var rail = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            context.stroke(rail, with: .color(tickColor.opacity(0.35)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            let rotation = -(heading ?? 0) - 90
            for tick in 0 ..< 72 {
                let degrees = Double(tick) * 5 + rotation
                let major = tick % 6 == 0
                var path = Path()
                path.move(to: point(at: degrees, radius: radius - (major ? 11 : 5)))
                path.addLine(to: point(at: degrees, radius: radius))
                context.stroke(path, with: .color(tickColor), lineWidth: major ? 1.25 : 0.6)
                if tick % 18 == 0 {
                    context.draw(
                        Text(["N", "E", "S", "W"][tick / 18])
                            .font(.system(size: min(cardSize, 13), design: .rounded).weight(.medium))
                            .foregroundStyle(ProTheme.secondary),
                        at: point(at: degrees, radius: radius + 14)
                    )
                }
            }
            if let baseline, let heading {
                let degrees = baseline - heading - 90
                var mark = Path()
                mark.move(to: point(at: degrees, radius: radius - 16))
                mark.addLine(to: point(at: degrees, radius: radius + 3))
                context.stroke(mark, with: .color(ProTheme.band), style: StrokeStyle(lineWidth: 3, lineCap: .butt))
            }
            var lubber = Path()
            lubber.move(to: CGPoint(x: center.x, y: center.y - radius + 4))
            lubber.addLine(to: CGPoint(x: center.x, y: center.y - radius - 6))
            context.stroke(lubber, with: .color(ProTheme.signal), style: StrokeStyle(lineWidth: 3, lineCap: .butt))
            var needle = Path()
            needle.move(to: CGPoint(x: center.x, y: center.y - radius + 8))
            needle.addLine(to: CGPoint(x: center.x + 3.2, y: center.y - 4))
            needle.addLine(to: CGPoint(x: center.x, y: center.y + 10))
            needle.addLine(to: CGPoint(x: center.x - 3.2, y: center.y - 4))
            needle.closeSubpath()
            context.fill(needle, with: .color(ProTheme.signal))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(ProTheme.signal))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)), with: .color(MC.canvas))
        }
        .frame(height: sizeClass == .regular ? 280 : 236)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
    @ScaledMetric(relativeTo: .caption2) private var axisSize = 11

    private var selected: MeasurementPoint? {
        guard let selectedElapsed else { return nil }
        return points.min { abs($0.elapsed - selectedElapsed) < abs($1.elapsed - selectedElapsed) }
    }
    var body: some View {
        plotted
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

    private var yMarkValues: [Double] {
        let steps = dynamicType.isAccessibilitySize ? 2 : 3
        return (0 ... steps).map { step in
            range.lowerBound + Double(step) / Double(steps) * (range.upperBound - range.lowerBound)
        }
    }

    private var plotted: some View {
        Chart {
            ForEach(MeasurementMath.plotPoints(baseline, kind: kind, limit: 160)) { point in
                LineMark(x: .value("Seconds", point.elapsed), y: .value(kind.unit, point.value), series: .value("Segment", "baseline-\(point.segment)"))
                    .foregroundStyle(.secondary.opacity(0.55)).lineStyle(StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
            }
            ForEach(MeasurementMath.plotPoints(points, kind: kind, limit: 220)) { point in
                LineMark(x: .value("Seconds", point.elapsed), y: .value(kind.unit, point.value), series: .value("Segment", "current-\(point.segment)"))
                    .foregroundStyle(ProTheme.signal).lineStyle(StrokeStyle(lineWidth: 1.6))
            }
            if points.count == 1, let point = points.first {
                PointMark(x: .value("Seconds", point.elapsed), y: .value(kind.unit, point.value)).foregroundStyle(ProTheme.signal)
            }
            if let threshold, range.contains(threshold) {
                RuleMark(y: .value("Threshold", threshold)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(ProTheme.secondary)
            }
            if let selected {
                RuleMark(x: .value("Selected time", selected.elapsed)).foregroundStyle(ProTheme.signal.opacity(0.45))
                PointMark(x: .value("Seconds", selected.elapsed), y: .value(kind.unit, selected.value)).foregroundStyle(ProTheme.signal).symbolSize(28)
            }
            ForEach(events.suffix(8)) { event in
                RuleMark(x: .value("Mark", event.elapsed)).foregroundStyle(.secondary.opacity(0.2)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
            }
        }
        .chartYScale(domain: range)
        .chartXAxis { xMarks }
        .chartYAxis { yMarks }
        .chartXSelection(value: Binding(get: { selectedElapsed }, set: { if let value = $0 { selectedElapsed = value } }))
    }

    @AxisContentBuilder private var xMarks: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: dynamicType.isAccessibilitySize ? 3 : 4)) { value in
            AxisGridLine().foregroundStyle(.secondary.opacity(0.1))
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text("\(number.formatted(.number.precision(.fractionLength(0))))s")
                        .font(.system(size: min(axisSize, 22), design: .rounded))
                        .foregroundStyle(ProTheme.secondary)
                }
            }
        }
    }

    @AxisContentBuilder private var yMarks: some AxisContent {
        AxisMarks(preset: .inset, position: .leading, values: yMarkValues) { value in
            AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
            AxisValueLabel {
                if let number = value.as(Double.self) {
                    Text(MeasurementMath.scaleLabel(number, range: range))
                        .font(.system(size: min(axisSize, 22), design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(ProTheme.secondary)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }
}

struct SpectrumChart: View {
    let spectrum: MeasurementSpectrum
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Vibration spectrum").font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer()
                Text("\(spectrum.resolution.formatted(.number.precision(.fractionLength(1)))) Hz")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(ProTheme.secondary)
            }
            Chart(spectrum.bins) { bin in
                BarMark(x: .value("Frequency", bin.frequency), y: .value("Amplitude (g)", bin.amplitude)).foregroundStyle(ProTheme.signal)
            }.frame(height: 140)
            Text("Dominant axis · Hann window · \(spectrum.sampleRate.formatted(.number.precision(.fractionLength(1)))) samples/s. The phone's usable sensor bandwidth may be lower.")
                .font(.caption).foregroundStyle(ProTheme.secondary)
        }
    }
}
