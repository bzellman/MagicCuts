import SwiftUI

enum MC {
    static let action = Color("Action")
    static let canvas = Color("Canvas")
    static let instrument = Color("Instrument")
    static let ink = Color.primary
    static let gap: CGFloat = 16
    static let inset: CGFloat = 20
    static let radius: CGFloat = 16
}

struct ControlStyle: ButtonStyle {
    var primary = true
    var radius: CGFloat = 12
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 16).padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(primary ? Color.white : MC.ink)
            .background(primary ? MC.action : Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: radius))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

struct ModeTabs: View {
    @AppStorage("technicalMode") private var technical = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 0))
            : AnyLayout(HStackLayout(spacing: 0))
        layout {
            tab("Simple", value: false)
            tab("Technical", value: true)
        }.overlay(alignment: .bottom) { Rectangle().fill(.secondary.opacity(0.15)).frame(height: 1) }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: technical)
        .sensoryFeedback(.selection, trigger: technical)
    }
    private func tab(_ title: String, value: Bool) -> some View {
        Button { technical = value } label: {
            HStack {
                Text(title)
                if value && !dynamicTypeSize.isAccessibilitySize { Image(systemName: "slider.horizontal.3").accessibilityHidden(true) }
            }.fontWeight(technical == value ? .semibold : .regular)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(technical == value ? Color.primary : .secondary)
                .overlay(alignment: .bottom) { if technical == value { Capsule().fill(MC.action).frame(height: 3).matchedGeometryEffect(id: "mode-underline", in: selection) } }
        }.buttonStyle(.plain)
            .accessibilityAddTraits(technical == value ? .isSelected : [])
            .accessibilityIdentifier(value ? "mode.technical" : "mode.simple")
    }
}

struct SignalGauge: View {
    let threshold: Int
    var samples: [SignalSample] = []
    var onChange: ((Int) -> Void)?
    var showMeasurements = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize = 42
    private func fraction(_ value: Int) -> CGFloat { CGFloat(min(0, max(-100, value)) + 100) / 100 }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Nearby threshold").font(.subheadline).foregroundStyle(.white.opacity(0.8))
            HStack(spacing: 12) {
                if let onChange { step("minus", label: "Decrease threshold") { onChange(max(-100, threshold - 1)) } }
                Text("\(Text(threshold.formatted()).font(.system(size: numberSize, weight: .semibold, design: .rounded)))\(Text(" dBm").font(.title3))")
                    .contentTransition(.numericText()).animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: threshold)
                    .monospacedDigit().frame(maxWidth: .infinity, alignment: onChange == nil ? .leading : .center)
                    .accessibilityLabel("Threshold \(threshold) decibel milliwatts")
                if let onChange { step("plus", label: "Increase threshold") { onChange(min(-1, threshold + 1)) } }
            }
            if let onChange {
                scale
                    .contentShape(Rectangle())
                    .overlay {
                        GeometryReader { geometry in
                            Color.clear.contentShape(Rectangle())
                                .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { value in
                                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                                    let fraction = value.location.x / max(1, geometry.size.width)
                                    onChange(min(-1, max(-100, Int((fraction * 100 - 100).rounded()))))
                                })
                                .gesture(SpatialTapGesture().onEnded { value in
                                    let fraction = value.location.x / max(1, geometry.size.width)
                                    onChange(min(-1, max(-100, Int((fraction * 100 - 100).rounded()))))
                                })
                        }
                    }
                    .accessibilityRepresentation {
                        Slider(value: Binding(get: { Double(threshold) }, set: { onChange(Int($0)) }), in: -100 ... -1, step: 1)
                            .accessibilityLabel("Nearby threshold")
                            .accessibilityValue("\(threshold) dBm")
                            .accessibilityIdentifier("threshold.slider")
                    }
            } else { scale.accessibilityHidden(true) }
            HStack { Text("−100"); Spacer(); Text("−50"); Spacer(); Text("0 dBm") }
                .font(.caption).monospacedDigit().foregroundStyle(.white.opacity(0.8))
            if showMeasurements && !samples.isEmpty {
                Divider().overlay(.white.opacity(0.2))
                HStack(alignment: .top) {
                    VStack(alignment: .leading) { Text("Observed").font(.caption); Text("\(samples.map(\.rssi).min()!) to \(samples.map(\.rssi).max()!) dBm").monospacedDigit() }
                    Spacer()
                    VStack(alignment: .trailing) { Text("Samples").font(.caption); Text("\(samples.count)").monospacedDigit() }
                }
            }
        }.foregroundStyle(.white).padding(MC.inset)
            .background(MC.instrument, in: RoundedRectangle(cornerRadius: MC.radius))
    }
    private var scale: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            Path { path in
                for tick in 0...50 {
                    let x = width * CGFloat(tick) / 50
                    path.move(to: CGPoint(x: x, y: 14))
                    path.addLine(to: CGPoint(x: x, y: tick % 5 == 0 ? 30 : 22))
                }
            }.stroke(.white.opacity(0.5), lineWidth: 1)
            RoundedRectangle(cornerRadius: 3).fill(Color.cyan).frame(width: 6, height: 30)
                .offset(x: fraction(threshold) * width - 3, y: 7)
            if let low = samples.map(\.rssi).min(), let high = samples.map(\.rssi).max() {
                Capsule().fill(.cyan.opacity(0.7))
                    .frame(width: max(3, (fraction(high) - fraction(low)) * width), height: 5)
                    .offset(x: fraction(low) * width, y: 46)
            }
        }.frame(height: 56)
    }

    private func step(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).font(.title2).frame(minWidth: 48, minHeight: 48).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10)) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct HandoffRow: View {
    let title: String
    var symbol = "arrow.up.right"
    var body: some View {
        HStack { Text(title); Spacer(); Image(systemName: symbol).accessibilityHidden(true) }
            .foregroundStyle(.primary).padding(.vertical, 14).frame(minHeight: 48)
    }
}

struct InlineFailure: View {
    let message: String
    var body: some View { Label(message, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.primary).padding().frame(maxWidth: .infinity, alignment: .leading).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)).accessibilityIdentifier("error.message") }
}
