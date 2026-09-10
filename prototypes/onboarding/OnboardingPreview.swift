import SwiftUI

@main
struct OnboardingPreviewApp: App {
    var body: some Scene {
        WindowGroup { OnboardingPreview() }
    }
}

private enum PreviewPalette {
    static let action = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.122, green: 0.4, blue: 0.851, alpha: 1)
            : UIColor(red: 0, green: 0.322, blue: 0.78, alpha: 1)
    })
    static let blue = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.72, blue: 1, alpha: 1)
            : UIColor(red: 0, green: 0.322, blue: 0.78, alpha: 1)
    })
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.059, green: 0.078, blue: 0.102, alpha: 1)
            : UIColor(red: 0.949, green: 0.961, blue: 0.969, alpha: 1)
    })
    static let secondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.659, green: 0.702, blue: 0.741, alpha: 1)
            : UIColor(red: 0.349, green: 0.388, blue: 0.431, alpha: 1)
    })
}

struct OnboardingPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var step = 0
    @State private var signal = -62.0
    @State private var referenceVisible = false
    @State private var showPurchasePreview = false
    @State private var showHelp = false
    @State private var started = false
    @ScaledMetric(relativeTo: .largeTitle) private var readingSize = 66

    private let reference = -72.0
    private var motion: Animation { .easeInOut(duration: reduceMotion ? 0.12 : 0.35) }
    private var adaptiveLayout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
    }
    private var heading: String {
        switch step {
        case 0: "Turn readings\ninto answers."
        case 1: "Know what\nchanged."
        case 2: "Your instruments.\nOne purchase."
        default: started ? "Ready when\nyou are." : "Make your first\nmeasurement."
        }
    }
    private var explanation: String {
        switch step {
        case 0: "Find a stronger signal. See it respond."
        case 1: "Keep a reference. See the difference."
        case 2: "Measure, compare and put your results to work."
        default: "Start with Level. See the angle of a surface."
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(heading)
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .contentTransition(.opacity)
                        Text(explanation)
                            .font(.body)
                            .foregroundStyle(PreviewPalette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if step < 3 {
                        signalInstrument
                        if step < 2 { signalControl }
                        else { purchaseDetails }
                    } else {
                        firstInstrument
                    }
                    if typeSize.isAccessibilitySize { previewAnnotation }
                }
                .padding(.horizontal, 26)
                .padding(.top, 22)
                .padding(.bottom, 28)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
            }
            .background(PreviewPalette.canvas)
            .navigationTitle("MagicCuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if step > 0 {
                        Button("Back", systemImage: "chevron.left") { advance(to: step - 1) }
                    } else { Button("Restore") { showHelp = true } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if step < 2 { Button("View Pro") { advance(to: 2) } }
                    else { Button("Replay", systemImage: "arrow.counterclockwise") { advance(to: 0) } }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .sheet(isPresented: $showPurchasePreview) {
                NavigationStack {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Purchase preview").font(.system(.largeTitle, design: .rounded).bold())
                        Text("No payment will be made. In the app, Apple confirms the localized price and completes the purchase.")
                        Button("Preview successful purchase") {
                            showPurchasePreview = false
                            advance(to: 3)
                        }.buttonStyle(.borderedProminent).tint(PreviewPalette.action).controlSize(.large)
                        Button("Preview cancellation") { showPurchasePreview = false }
                            .frame(minHeight: 44)
                        Spacer()
                    }
                    .padding(24)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPurchasePreview = false } } }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Restore purchases", isPresented: $showHelp) {
                Button("Preview restored purchase") { advance(to: 3) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This standalone preview does not contact the App Store. In the app, this restores a verified Pro purchase.")
            }
            .task(id: step) { await animateStep() }
            .task {
                let arguments = ProcessInfo.processInfo.arguments
                if let argument = arguments.first(where: { $0.hasPrefix("--page=") }),
                   let page = Int(argument.dropFirst(7)), (0...3).contains(page) { advance(to: page) }
                if arguments.contains("--autoplay") { await playPresentation() }
            }
        }
        .tint(PreviewPalette.blue)
    }

    private var signalInstrument: some View {
        VStack(spacing: 10) {
            adaptiveLayout {
                Label("Bluetooth signal", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.subheadline.weight(.medium))
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Text("Demo data").font(.caption).foregroundStyle(PreviewPalette.secondary)
            }
            .accessibilityElement(children: .combine)
            SignalDial(value: signal, reference: referenceVisible ? reference : nil)
                .opacity(typeSize.isAccessibilitySize ? 0 : 1)
                .frame(height: typeSize.isAccessibilitySize ? 100 : step == 2 ? 130 : 244)
                .accessibilityHidden(true)
                .overlay(alignment: .bottom) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(signal, format: .number.precision(.fractionLength(0)))
                            .font(typeSize.isAccessibilitySize ? .system(.largeTitle, design: .rounded).weight(.semibold) : .system(size: step == 2 ? 44 : readingSize, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: signal))
                        Text("dBm").font(.callout).foregroundStyle(PreviewPalette.secondary)
                    }
                    .padding(.bottom, 9)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Demo signal")
                    .accessibilityValue("\(Int(signal)) decibel milliwatts")
                }
            if step == 1 {
                adaptiveLayout {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Reference", systemImage: "diamond")
                            .font(.caption).foregroundStyle(PreviewPalette.secondary)
                        Text("−72 dBm").font(.system(.headline, design: .rounded)).monospacedDigit()
                    }
                    if !typeSize.isAccessibilitySize { Spacer() }
                    VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 4) {
                        Text("Difference").font(.caption).foregroundStyle(PreviewPalette.secondary)
                        Text("\((signal - reference).formatted(.number.sign(strategy: .always()).precision(.fractionLength(0)))) dB")
                    }
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(PreviewPalette.blue)
                    .contentTransition(.numericText(value: signal - reference))
                }
                .padding(.top, 8)
                .transition(.opacity)
            } else if step == 0 {
                Text("Less negative means stronger.")
                    .font(.callout).foregroundStyle(PreviewPalette.secondary)
            }
        }
    }

    private var signalControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Slider(value: $signal, in: -90 ... -45, step: 1) {
                Text("Demo signal strength")
            }
            .accessibilityValue("\(Int(signal)) decibel milliwatts")
            HStack {
                Text("Weaker")
                Spacer()
                Text("Stronger")
            }.font(.caption).foregroundStyle(PreviewPalette.secondary)
            Text(step == 0 ? "Slide to explore the signal." : signal == reference ? "Matches your reference." : signal > reference ? "Stronger than your reference." : "Weaker than your reference.")
                .font(.callout).padding(.top, 7)
                .contentTransition(.opacity)
        }
    }

    private var purchaseDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            if typeSize.isAccessibilitySize {
                Text("One-time purchase. No subscription.")
                    .font(.footnote).foregroundStyle(PreviewPalette.secondary)
            }
            benefit("12 instruments", detail: "Signal, motion, pressure and more.", symbol: "gauge.with.dots.needle.50percent")
            benefit("Save. Compare. Automate.", detail: "References, sessions, reports and Shortcuts.", symbol: "slider.horizontal.3")
            Text("Available measurements depend on your device, permissions and connected equipment.")
                .font(.footnote).foregroundStyle(PreviewPalette.secondary)
            if typeSize.isAccessibilitySize { purchaseLinks }
        }
    }

    private func benefit(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            if !typeSize.isAccessibilitySize {
                Image(systemName: symbol).font(.title3).foregroundStyle(PreviewPalette.blue).frame(width: 26)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(.headline, design: .rounded))
                Text(detail).font(.callout).foregroundStyle(PreviewPalette.secondary)
            }
        }
    }

    private var firstInstrument: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle().stroke(PreviewPalette.secondary.opacity(0.22), lineWidth: 1)
                Rectangle().fill(PreviewPalette.blue).frame(height: 2)
                    .rotationEffect(.degrees(started ? 0 : 8))
                Circle().fill(PreviewPalette.canvas).frame(width: 120, height: 120)
                VStack(spacing: 4) {
                    Text(started ? "0.0°" : "8.0°")
                        .font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("Level · Demo").font(.caption).foregroundStyle(PreviewPalette.secondary)
                }
            }
            .frame(width: 230, height: 230)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(started ? "Demo level, zero degrees" : "Demo level, eight degrees")
            VStack(alignment: .leading, spacing: 8) {
                Text(started ? "That’s your first reading." : "A simple place to start.")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                Text(started ? "From here, set a reference or record a session when you need one." : "Place your phone on a surface to check its angle. Permission requests appear when an instrument needs them.")
                    .font(.body).foregroundStyle(PreviewPalette.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button {
                if step < 2 { advance(to: step + 1) }
                else if step == 2 { showPurchasePreview = true }
                else if started { advance(to: 0) }
                else { withAnimation(reduceMotion ? nil : .smooth(duration: 0.6)) { started = true } }
            } label: {
                Text(step == 0 ? "See the difference" : step == 1 ? "Explore Pro" : step == 2 ? "Unlock Pro" : started ? "Replay introduction" : "Try Level")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(PreviewPalette.action)
            .controlSize(.large)
            if step == 2 && !typeSize.isAccessibilitySize {
                Text("One-time purchase. No subscription.")
                    .font(.footnote).foregroundStyle(PreviewPalette.secondary)
                purchaseLinks
            }
            if !typeSize.isAccessibilitySize { previewAnnotation }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .frame(maxWidth: 540)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var previewAnnotation: some View {
        Text("Motion preview · Demo data · No payment")
            .font(.caption2).foregroundStyle(PreviewPalette.secondary)
    }

    private var purchaseLinks: some View {
        adaptiveLayout {
            Button("Restore purchases") { showHelp = true }.frame(minHeight: 44)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Link("Privacy", destination: URL(string: "https://bradzellman.com/magiccuts-policies.html#privacy")!).frame(minHeight: 44)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!).frame(minHeight: 44)
        }.font(.footnote)
    }

    private func advance(to next: Int) {
        withAnimation(motion) {
            step = next
            referenceVisible = next == 1
            started = false
        }
    }

    private func animateStep() async {
        if step == 0 {
            signal = reduceMotion ? -62 : -84
            guard !reduceMotion else { return }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            withAnimation(.easeInOut(duration: 1.6)) { signal = -62 }
        } else if step == 1 {
            signal = reduceMotion ? -62 : reference
            guard !reduceMotion else { return }
            do { try await Task.sleep(for: .milliseconds(450)) } catch { return }
            withAnimation(.easeInOut(duration: 1.2)) { signal = -62 }
        }
    }

    private func playPresentation() async {
        do {
            try await Task.sleep(for: .seconds(5))
            advance(to: 1)
            try await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.3)) { signal = -80 }
            try await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 1.3)) { signal = -58 }
            try await Task.sleep(for: .seconds(3))
            advance(to: 2)
            try await Task.sleep(for: .seconds(7))
            advance(to: 3)
            try await Task.sleep(for: .seconds(3))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.7)) { started = true }
        } catch { return }
    }
}

private struct SignalDial: View, Animatable {
    var value: Double
    let reference: Double?
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height * 0.64)
            let radius = min(size.width * 0.42, size.height * 0.55, center.y - 24)
            func point(_ value: Double, radius: Double) -> CGPoint {
                let angle = (-210 + (value + 100) / 60 * 240) * .pi / 180
                return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }
            for tick in 0...60 {
                let sample = -100.0 + Double(tick)
                let major = tick.isMultiple(of: 10)
                let active = sample <= value
                var path = Path()
                path.move(to: point(sample, radius: radius - (major ? 16 : 8)))
                path.addLine(to: point(sample, radius: radius))
                context.stroke(path, with: .color(active ? PreviewPalette.blue : PreviewPalette.secondary.opacity(0.3)), style: StrokeStyle(lineWidth: major ? 2.5 : 1, lineCap: .round))
            }
            for sample in [-100.0, -70.0, -40.0] {
                let label = Text("\(Int(sample))").font(.caption2).foregroundStyle(PreviewPalette.secondary)
                context.draw(label, at: point(sample, radius: radius + 14))
            }
            if let reference {
                let marker = point(reference, radius: radius - 26)
                var diamond = Path()
                diamond.move(to: CGPoint(x: marker.x, y: marker.y - 5))
                diamond.addLine(to: CGPoint(x: marker.x + 5, y: marker.y))
                diamond.addLine(to: CGPoint(x: marker.x, y: marker.y + 5))
                diamond.addLine(to: CGPoint(x: marker.x - 5, y: marker.y))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(.primary))
            }
            var needle = Path()
            needle.move(to: point(value, radius: radius - 29))
            needle.addLine(to: point(value, radius: radius + 5))
            context.stroke(needle, with: .color(PreviewPalette.blue), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }
    }
}
