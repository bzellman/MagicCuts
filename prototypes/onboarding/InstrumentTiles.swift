import SwiftUI

enum TourInstrument: Int, CaseIterable, Identifiable {
    case level, signal, vibration, heading, elevation
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .level: "Level"
        case .signal: "Signal"
        case .vibration: "Vibration"
        case .heading: "Heading"
        case .elevation: "Elevation"
        }
    }
    var symbol: String {
        switch self {
        case .level: "level"
        case .signal: "antenna.radiowaves.left.and.right"
        case .vibration: "waveform.path"
        case .heading: "location.north"
        case .elevation: "arrow.up.and.down"
        }
    }
    var heading: String {
        switch self {
        case .level: "Get it\njust right."
        case .signal: "Find a stronger\nconnection."
        case .vibration: "See what\nfeels different."
        case .heading: "Keep your\nbearings."
        case .elevation: "Notice every\nchange."
        }
    }
    var explanation: String {
        switch self {
        case .level: "Level a surface. Find the angle that works."
        case .signal: "Watch the signal change as you move."
        case .vibration: "Turn vibration into a trace you can compare."
        case .heading: "Read a magnetic direction. Keep a reference."
        case .elevation: "Track elevation from where you started."
        }
    }
    func reading(at progress: Double) -> String {
        switch self {
        case .level: (8 * (1 - progress)).formatted(.number.precision(.fractionLength(1)))
        case .signal: (Double(-84) + 26 * progress).formatted(.number.precision(.fractionLength(0)))
        case .vibration: (0.082 - 0.068 * progress).formatted(.number.precision(.fractionLength(3)))
        case .heading: (325 + 35 * progress).truncatingRemainder(dividingBy: 360).formatted(.number.precision(.fractionLength(0)))
        case .elevation: "+" + (4.2 * progress).formatted(.number.precision(.fractionLength(1)))
        }
    }
    var unit: String {
        switch self {
        case .level, .heading: "°"
        case .signal: "dBm"
        case .vibration: "g RMS"
        case .elevation: "m"
        }
    }
    var context: String {
        switch self {
        case .level: "Surface angle"
        case .signal: "Bluetooth"
        case .vibration: "Motion over time"
        case .heading: "Magnetic"
        case .elevation: "From start"
        }
    }
}

struct InstrumentTile: View {
    let kind: TourInstrument
    let active: Bool
    let compact: Bool
    let progress: Double
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    title
                    value
                    Text(kind.context).font(.callout).foregroundStyle(PreviewPalette.secondary)
                }
            } else if compact {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) { title; value }
                    Spacer(minLength: 0)
                    InstrumentGraphic(kind: kind, progress: progress, active: active)
                        .frame(width: 44, height: 36)
                }
            } else if kind == .vibration {
                VStack(alignment: .leading, spacing: 8) {
                    HStack { title; Spacer(); value }
                    InstrumentGraphic(kind: kind, progress: progress, active: active)
                        .frame(height: 32)
                    Text(kind.context).font(.caption2).foregroundStyle(PreviewPalette.secondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    title
                    HStack(spacing: 8) {
                        InstrumentGraphic(kind: kind, progress: progress, active: active)
                            .frame(maxWidth: .infinity).frame(height: 52)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        value
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(typeSize.isAccessibilitySize ? 18 : compact ? 10 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: typeSize.isAccessibilitySize ? nil : compact ? (kind == .vibration ? 52 : 60) : (kind == .vibration ? 116 : 132))
        .background(active ? PreviewPalette.activeCard : PreviewPalette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(active ? PreviewPalette.blue.opacity(0.7) : .clear, lineWidth: 1.25)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title), demo \(kind.reading(at: progress)) \(kind.unit). \(kind.context)")
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private var title: some View {
        HStack(spacing: 5) {
            if !compact && !typeSize.isAccessibilitySize {
                Image(systemName: kind.symbol).font(.caption2)
                    .foregroundStyle(active ? PreviewPalette.blue : PreviewPalette.secondary)
            }
            Text(kind.title).font(.system(.caption, design: .rounded).weight(.semibold))
            if active && !compact {
                Spacer(minLength: 0)
                Circle().fill(PreviewPalette.blue).frame(width: 5, height: 5).accessibilityHidden(true)
            }
        }
        .foregroundStyle(active ? Color.primary : PreviewPalette.secondary)
    }

    private var value: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(kind.reading(at: progress))
                .font(typeSize.isAccessibilitySize ? .system(.largeTitle, design: .rounded).weight(.semibold) : .system(size: compact ? 19 : kind == .vibration ? 23 : 26, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(kind.unit).font(compact ? .caption2 : .caption)
                .foregroundStyle(PreviewPalette.secondary)
        }
        .foregroundStyle(active ? Color.primary : PreviewPalette.secondary)
    }
}

struct InstrumentGraphic: View {
    let kind: TourInstrument
    let progress: Double
    let active: Bool

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width * 0.4, size.height * 0.42)
            let ink = active ? PreviewPalette.blue : PreviewPalette.secondary
            let structure = PreviewPalette.secondary.opacity(active ? 0.35 : 0.22)
            func line(_ from: CGPoint, _ to: CGPoint, _ color: Color, _ width: Double = 1) {
                var path = Path(); path.move(to: from); path.addLine(to: to)
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            func ring(_ at: CGPoint, _ radius: Double, _ color: Color, _ width: Double = 1) {
                context.stroke(Path(ellipseIn: CGRect(x: at.x - radius, y: at.y - radius, width: 2 * radius, height: 2 * radius)), with: .color(color), lineWidth: width)
            }
            func point(_ degrees: Double, _ radius: Double) -> CGPoint {
                CGPoint(x: center.x + sin(degrees * .pi / 180) * radius, y: center.y - cos(degrees * .pi / 180) * radius)
            }
            switch kind {
            case .level:
                ring(center, radius, structure)
                ring(center, radius * 0.26, structure)
                line(CGPoint(x: center.x - radius - 6, y: center.y), CGPoint(x: center.x + radius + 6, y: center.y), structure)
                line(CGPoint(x: center.x, y: center.y - radius - 4), CGPoint(x: center.x, y: center.y + radius + 4), structure)
                let bubble = CGPoint(x: center.x + radius * 0.58 * (1 - progress), y: center.y - radius * 0.35 * (1 - progress))
                ring(bubble, radius * 0.26, ink, 2)
                context.fill(Path(ellipseIn: CGRect(x: bubble.x - 2, y: bubble.y - 2, width: 4, height: 4)), with: .color(ink))
            case .signal:
                let value = -84 + 26 * progress
                let angle = -125 + (value + 100) / 60 * 250
                for index in 0 ... 30 {
                    let degrees = -125 + Double(index) / 30 * 250
                    line(point(degrees, radius * (index.isMultiple(of: 5) ? 0.75 : 0.88)), point(degrees, radius), degrees <= angle ? ink : structure, index.isMultiple(of: 5) ? 1.5 : 0.8)
                }
                line(point(angle, radius * 0.2), point(angle, radius * 0.7), ink, 2.5)
                ring(center, 2, ink, 1.5)
            case .vibration:
                let amplitude = size.height * (0.43 - progress * 0.35)
                line(CGPoint(x: 0, y: center.y), CGPoint(x: size.width, y: center.y), structure)
                var path = Path()
                for i in 0 ... 120 {
                    let x = size.width * Double(i) / 120
                    let y = center.y - amplitude * (sin(Double(i) * 0.39 - progress * 8) * 0.74 + sin(Double(i) * 0.91 - progress * 3) * 0.22)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(path, with: .color(ink), style: StrokeStyle(lineWidth: active ? 1.8 : 1.2, lineCap: .round, lineJoin: .round))
            case .heading:
                let heading = 325 + 35 * progress
                ring(center, radius, structure)
                for index in 0 ..< 24 {
                    let degrees = Double(index) * 15 - heading
                    line(point(degrees, radius * (index.isMultiple(of: 6) ? 0.7 : 0.85)), point(degrees, radius), index == 0 ? ink : structure, index.isMultiple(of: 6) ? 1.8 : 0.8)
                }
                let north = point(-heading, radius * 0.43)
                if size.height > 45 { context.draw(Text("N").font(.system(size: 10, weight: .semibold)).foregroundStyle(ink), at: north) }
                line(CGPoint(x: center.x, y: center.y - radius - 3), CGPoint(x: center.x, y: center.y - radius + 7), ink, 2.5)
                ring(center, 2, ink)
            case .elevation:
                let value = 4.2 * progress
                let x = center.x - 6
                line(CGPoint(x: x, y: 3), CGPoint(x: x, y: size.height - 3), structure)
                for index in -3 ... 8 {
                    let y = center.y + (value - Double(index)) * 12
                    guard y >= 8, y <= size.height - 8 else { continue }
                    line(CGPoint(x: x, y: y), CGPoint(x: x + (index.isMultiple(of: 2) ? 10 : 6), y: y), structure)
                    if size.height > 45 && index.isMultiple(of: 2) {
                        context.draw(Text("\(index)").font(.system(size: 10)).foregroundStyle(PreviewPalette.secondary), at: CGPoint(x: x - 12, y: y))
                    }
                }
                var pointer = Path()
                pointer.move(to: CGPoint(x: x + 15, y: center.y))
                pointer.addLine(to: CGPoint(x: x + 22, y: center.y - 4))
                pointer.addLine(to: CGPoint(x: x + 22, y: center.y + 4))
                pointer.closeSubpath()
                context.fill(pointer, with: .color(ink))
            }
        }
        .accessibilityHidden(true)
    }
}
