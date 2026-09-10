import SwiftUI

@main
struct OnboardingPreviewApp: App {
    var body: some Scene { WindowGroup { OnboardingPreview() } }
}

enum PreviewPalette {
    static let action = adaptive(light: (0, 0.322, 0.78), dark: (0.122, 0.4, 0.851))
    static let blue = adaptive(light: (0, 0.322, 0.78), dark: (0.38, 0.72, 1))
    static let canvas = adaptive(light: (0.949, 0.961, 0.969), dark: (0.059, 0.078, 0.102))
    static let secondary = adaptive(light: (0.349, 0.388, 0.431), dark: (0.659, 0.702, 0.741))
    static let card = adaptive(light: (0.906, 0.925, 0.945), dark: (0.078, 0.11, 0.145))
    static let activeCard = adaptive(light: (0.976, 0.988, 1), dark: (0.082, 0.157, 0.247))

    private static func adaptive(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

struct OnboardingPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var page = 0
    @State private var selected: TourInstrument = .level
    @State private var readings = Array(repeating: 0.0, count: TourInstrument.allCases.count)
    @State private var tourRunning = true
    @State private var tourRun = UUID()
    @State private var cardRun = UUID()
    @State private var showPurchasePreview = false
    @State private var showRestore = false
    @State private var firstReading = false
    @State private var presentation = false
    @State private var configured = false

    private var compactHeight: Bool { verticalSizeClass == .compact && !typeSize.isAccessibilitySize }
    private var compactCards: Bool { page == 1 || compactHeight }

    private var transition: Animation { .easeInOut(duration: reduceMotion ? 0.12 : 0.42) }
    private var heading: String {
        switch page {
        case 0: selected.heading
        case 1: "Your instruments.\nOne purchase."
        default: firstReading ? "Ready when\nyou are." : "Make your first\nmeasurement."
        }
    }
    private var explanation: String {
        switch page {
        case 0: selected.explanation
        case 1: "A whole toolkit, ready when you need it."
        default: "Start with Level. See the angle of a surface."
        }
    }
    private var textKey: String { "\(page)-\(page == 0 ? selected.rawValue : -1)-\(firstReading)" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if page == 0 && compactHeight {
                        HStack(alignment: .center, spacing: 24) {
                            narration.frame(width: 210)
                            instrumentMosaic
                        }
                    } else {
                        narration
                        if page == 0 && typeSize.isAccessibilitySize { tourControls }
                        if page < 2 {
                            instrumentMosaic
                            if page == 1 { purchaseDetails }
                        } else { firstInstrument }
                    }
                    if typeSize.isAccessibilitySize || compactHeight { previewAnnotation }
                }
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .padding(.bottom, 18)
                .frame(maxWidth: compactHeight ? 800 : 560)
                .frame(maxWidth: .infinity)
            }
            .background(PreviewPalette.canvas)
            .navigationTitle("MagicCuts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if page == 0 { Button("Restore") { stopTour(); showRestore = true } }
                    else { Button("Back", systemImage: "chevron.left") { navigate(to: page - 1) } }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if page == 0 { Button("View Pro") { navigate(to: 1) } }
                    else { Button("Replay", systemImage: "arrow.counterclockwise") { replay() } }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
            .sheet(isPresented: $showPurchasePreview) { purchasePreview }
            .alert("Restore purchases", isPresented: $showRestore) {
                Button("Preview restored purchase") { navigate(to: 2) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This standalone preview does not contact the App Store. In the app, this restores a verified Pro purchase.")
            }
        }
        .tint(PreviewPalette.blue)
        .task {
            configure()
            if ProcessInfo.processInfo.arguments.contains("--landscape") {
                try? await Task.sleep(for: .milliseconds(250))
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscapeRight))
                }
            }
        }
        .task(id: tourRun) { await runTour() }
        .task(id: cardRun) { await animateSelectedCard() }
        .task(id: presentation) { if presentation { await playPresentation() } }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                if readings[selected.rawValue] == 0 { cardRun = UUID() }
            } else { stopTour(); presentation = false }
        }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { stopTour(); readings[selected.rawValue] = 1 }
        }
        .onChange(of: typeSize) { _, size in
            if size.isAccessibilitySize { stopTour() }
        }
        .onChange(of: voiceOver) { _, enabled in
            if enabled { stopTour() }
        }
        .onDisappear { stopTour(); presentation = false }
    }

    private var narration: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading)
                .font(.system(.title, design: .rounded).bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(explanation)
                .font(.body).foregroundStyle(PreviewPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? nil : 124, alignment: .topLeading)
        .id(textKey)
        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 5)))
    }

    private var instrumentMosaic: some View {
        VStack(spacing: compactCards ? 8 : 12) {
            if typeSize.isAccessibilitySize {
                ForEach(TourInstrument.allCases) { tile($0) }
            } else {
                HStack(spacing: compactCards ? 8 : 12) { tile(.level); tile(.signal) }
                tile(.vibration)
                HStack(spacing: compactCards ? 8 : 12) { tile(.heading); tile(.elevation) }
            }
        }
    }

    @ViewBuilder
    private func tile(_ kind: TourInstrument) -> some View {
        if page == 0 {
            Button {
                stopTour()
                spotlight(kind)
            } label: {
                InstrumentTile(kind: kind, active: selected == kind, compact: compactCards, progress: readings[kind.rawValue])
            }
            .buttonStyle(.plain)
            .accessibilityHint("Show the \(kind.title.lowercased()) explanation and replay its demonstration")
        } else {
            InstrumentTile(kind: kind, active: true, compact: true, progress: readings[kind.rawValue])
        }
    }

    private var purchaseDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("12 instruments. One toolkit.").font(.system(.headline, design: .rounded))
            Text("Save references. Record sessions. Run Shortcuts.")
                .font(.callout).foregroundStyle(PreviewPalette.secondary)
            Text("Measurements depend on your device, permissions and connected equipment.")
                .font(.footnote).foregroundStyle(PreviewPalette.secondary)
                .padding(.top, 4)
            if typeSize.isAccessibilitySize || compactHeight {
                Text("One-time purchase. No subscription.").font(.footnote)
                purchaseLinks
            }
        }
    }

    private var firstInstrument: some View {
        VStack(alignment: .leading, spacing: 24) {
            ZStack {
                Circle().stroke(PreviewPalette.secondary.opacity(0.3), lineWidth: 1)
                Rectangle().fill(PreviewPalette.blue).frame(height: 2)
                    .rotationEffect(.degrees(firstReading ? 0 : 8))
                Circle().fill(PreviewPalette.canvas).frame(width: 140, height: 140)
                VStack(spacing: 6) {
                    Text(firstReading ? "0.0°" : "8.0°")
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("Level · Demo").font(.caption).foregroundStyle(PreviewPalette.secondary)
                }
            }
            .frame(width: 240, height: 240).frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(firstReading ? "Demo level, zero degrees" : "Demo level, eight degrees")
            Text(firstReading ? "That’s your first reading." : "A simple place to start.")
                .font(.system(.title3, design: .rounded).weight(.semibold))
            Text(firstReading ? "Set a reference or record a session when you need one." : "Place your phone on a surface to check its angle. Permissions appear when an instrument needs them.")
                .font(.body).foregroundStyle(PreviewPalette.secondary)
        }
        .padding(.vertical, 16)
    }

    private var tourControls: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            if !compactHeight { Text("Demo instruments").font(.footnote).foregroundStyle(PreviewPalette.secondary) }
            if !typeSize.isAccessibilitySize && !compactHeight { Spacer() }
            Button {
                if reduceMotion || typeSize.isAccessibilitySize || voiceOver {
                    spotlight(TourInstrument.allCases[(selected.rawValue + 1) % TourInstrument.allCases.count])
                } else if tourRunning { stopTour() }
                else {
                    if selected == .elevation { spotlight(.level) }
                    tourRunning = true; tourRun = UUID()
                }
            } label: {
                let manual = reduceMotion || typeSize.isAccessibilitySize || voiceOver
                Label(manual ? "Next instrument" : tourRunning ? "Pause tour" : "Play tour",
                      systemImage: manual ? "forward.end" : tourRunning ? "pause.circle" : "play.circle")
                    .font(.footnote).frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(PreviewPalette.blue)
        }
    }

    private var footer: some View {
        let layout = compactHeight
            ? AnyLayout(HStackLayout(alignment: .center, spacing: 24))
            : AnyLayout(VStackLayout(spacing: 6))
        return layout {
            if page == 0 && !typeSize.isAccessibilitySize { tourControls }
            Button {
                if page == 0 { navigate(to: 1) }
                else if page == 1 { showPurchasePreview = true }
                else if firstReading { replay() }
                else { withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) { firstReading = true } }
            } label: {
                Text(page == 0 ? "Explore Pro" : page == 1 ? "Unlock Pro" : firstReading ? "Replay introduction" : "Try Level")
                    .font(.system(.headline, design: .rounded))
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(.borderedProminent).tint(PreviewPalette.action).controlSize(.large)
            if page == 1 && !typeSize.isAccessibilitySize && !compactHeight {
                Text("One-time purchase. No subscription.").font(.footnote).foregroundStyle(PreviewPalette.secondary)
                purchaseLinks
            }
            if page > 0 && !typeSize.isAccessibilitySize && !compactHeight { previewAnnotation }
        }
        .padding(.horizontal, 22).padding(.top, page == 0 ? 0 : 14).padding(.bottom, 8)
        .frame(maxWidth: compactHeight ? 800 : 560).frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var previewAnnotation: some View {
        Text("Motion preview · Demo data · No payment")
            .font(.caption2).foregroundStyle(PreviewPalette.secondary)
    }

    private var purchaseLinks: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 16))
        return layout {
            Button("Restore purchases") { showRestore = true }.frame(minHeight: 44)
            if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
            Link("Privacy", destination: URL(string: "https://bradzellman.com/magiccuts-policies.html#privacy")!).frame(minHeight: 44)
            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!).frame(minHeight: 44)
        }.font(.footnote)
    }

    private var purchasePreview: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Purchase preview").font(.system(.largeTitle, design: .rounded).bold())
                    Text("No payment will be made. In the app, Apple confirms the localized price and completes the purchase.")
                    Button("Preview successful purchase") { showPurchasePreview = false; navigate(to: 2) }
                        .buttonStyle(.borderedProminent).tint(PreviewPalette.action).controlSize(.large)
                    Button("Preview cancellation") { showPurchasePreview = false }.frame(minHeight: 44)
                }.padding(24)
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showPurchasePreview = false } } }
        }
        .presentationDetents([.medium, .large])
    }

    private func configure() {
        guard !configured else { return }
        configured = true
        let args = ProcessInfo.processInfo.arguments
        if let arg = args.first(where: { $0.hasPrefix("--page=") }), let value = Int(arg.dropFirst(7)), (0 ... 2).contains(value) {
            page = value
        }
        if let arg = args.first(where: { $0.hasPrefix("--card=") }), let value = Int(arg.dropFirst(7)), let instrument = TourInstrument(rawValue: value) {
            selected = instrument; tourRunning = false
        }
        if reduceMotion || typeSize.isAccessibilitySize || voiceOver { tourRunning = false }
        if page != 0 { tourRunning = false; readings = Array(repeating: 1, count: readings.count) }
        if args.contains("--autoplay") { tourRunning = false; presentation = true }
        tourRun = UUID(); cardRun = UUID()
    }

    private func stopTour() { tourRunning = false; tourRun = UUID() }

    private func spotlight(_ instrument: TourInstrument) {
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { readings[instrument.rawValue] = reduceMotion ? 1 : 0 }
        withAnimation(transition) { selected = instrument }
        cardRun = UUID()
    }

    private func navigate(to destination: Int) {
        stopTour(); presentation = false
        withAnimation(transition) {
            page = destination; firstReading = false
            if destination == 1 { readings = Array(repeating: 1, count: readings.count) }
        }
        cardRun = UUID()
    }

    private func replay() {
        navigate(to: 0)
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { readings = Array(repeating: 0, count: readings.count) }
        spotlight(.level)
        tourRunning = !reduceMotion && !typeSize.isAccessibilitySize && !voiceOver; tourRun = UUID()
    }

    private func animateSelectedCard() async {
        guard page == 0, scenePhase == .active else { return }
        if reduceMotion { readings[selected.rawValue] = 1; return }
        let instrument = selected
        do {
            try await Task.sleep(for: .milliseconds(350))
            let started = ContinuousClock.now
            while !Task.isCancelled, page == 0, selected == instrument, scenePhase == .active {
                let elapsed = started.duration(to: .now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                let fraction = min(seconds / 1.6, 1)
                let eased = 1 - pow(1 - fraction, 3)
                var transaction = Transaction(); transaction.disablesAnimations = true
                withTransaction(transaction) { readings[instrument.rawValue] = eased }
                if fraction == 1 { return }
                try await Task.sleep(for: .milliseconds(16))
            }
        } catch { return }
    }

    private func runTour() async {
        guard configured, page == 0, tourRunning, !reduceMotion, !typeSize.isAccessibilitySize, !voiceOver, !presentation else { return }
        do {
            while tourRunning {
                try await Task.sleep(for: .seconds(3.7))
                guard page == 0, tourRunning else { return }
                guard let next = TourInstrument(rawValue: selected.rawValue + 1) else { tourRunning = false; return }
                spotlight(next)
            }
        } catch { return }
    }

    private func playPresentation() async {
        do {
            for instrument in TourInstrument.allCases {
                spotlight(instrument)
                try await Task.sleep(for: .seconds(3.7))
            }
            withAnimation(transition) { page = 1; readings = Array(repeating: 1, count: readings.count) }
            try await Task.sleep(for: .seconds(5))
            withAnimation(transition) { page = 2 }
            try await Task.sleep(for: .seconds(2))
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.65)) { firstReading = true }
        } catch { return }
    }
}
