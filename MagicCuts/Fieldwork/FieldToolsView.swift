import SwiftUI
import Charts

struct FieldToolsView: View {
    @Bindable var library: ProLibrary
    var body: some View {
        List {
            Section {
                NavigationLink { NFCInstrumentView(library: library) } label: { tool("NFC inspector", symbol: "wave.3.right.circle", detail: "Identity, records, capacity, and read diagnostics") }
                NavigationLink { NetworkInstrumentView(library: library) } label: { tool("Network tests", symbol: "network", detail: "Request phases, consistency, and bounded transfers") }
                NavigationLink { CellularInstrumentView(library: library) } label: { tool("Cellular", symbol: "antenna.radiowaves.left.and.right", detail: "Reported technology, verified tests, forecasts, and history") }
                NavigationLink { DepthInstrumentView(library: library) } label: { tool("LiDAR measurements", symbol: "viewfinder", detail: "Distance, dimensions, surface fit, and depth confidence") }
                NavigationLink { PeerInstrumentView(library: library) } label: { tool("Peer instruments", symbol: "point.3.connected.trianglepath.dotted", detail: "Local benchmarks, Wi-Fi Aware links, and UWB ranging") }
                NavigationLink { RoomsView(library: library) } label: { tool("Rooms", symbol: "square.3.layers.3d", detail: "Saved meshes, return visits, and measurement locations") }
            } footer: { Text("Measurements stay on this device unless you share them or enable iCloud in Settings. Hardware availability varies by device.") }
        }.navigationTitle("Field tools")
    }
    private func tool(_ title: String, symbol: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(ProTheme.signal).frame(width: 30)
            VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(.headline, design: .rounded)); Text(detail).font(.callout).foregroundStyle(ProTheme.secondary) }
        }.padding(.vertical, 12)
    }
}

struct NFCInstrumentView: View {
    @Bindable var library: ProLibrary
    @State private var instrument = NFCInstrument()
    @State private var saving: FieldCapture?
    @Environment(RoomSession.self) private var room
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoomOrientationBanner()
                Label(instrument.status, systemImage: "wave.3.right.circle").font(.system(.title2, design: .rounded).weight(.semibold))
                Text("Read one nearby tag. Inspect supported NDEF records, then keep the useful read.").font(.callout).foregroundStyle(ProTheme.secondary)
                Button(instrument.active ? "Stop reading" : "Read a tag") { if instrument.active { instrument.stop() } else { instrument.start() } }
                    .buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44).accessibilityIdentifier("nfc.read")
                if let failure = instrument.failure { InlineFailure(message: failure) }
                if let capture = instrument.result {
                    FieldCaptureEvidence(capture: capture)
                    Button(capture.nfc == nil ? "Save scan diagnostics" : "Save tag read") { saving = capture }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44)
                } else {
                    ForEach(instrument.diagnostics) { step in LabeledContent(step.step, value: step.outcome).font(.callout) }
                }
                Text("Supports accessible ISO 14443 and ISO 15693 tags, including the declared ISO 7816 NDEF application. Protected content and unsupported protocols remain unavailable.").font(.caption).foregroundStyle(ProTheme.secondary)
            }.padding(22).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(MC.canvas).scrollEdgeEffectStyle(.hard, for: .all).navigationTitle("NFC inspector").navigationBarTitleDisplayMode(.inline)
        .onAppear { instrument.positionProvider = { [weak room] date in room?.placement(at: date) } }
        .onDisappear { instrument.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { instrument.stop() } }
        .sheet(item: $saving) { FieldCaptureSaveView(capture: $0, library: library) }
    }
}

struct NetworkInstrumentView: View {
    @Bindable var library: ProLibrary
    var cellularOnly = false
    @State private var instrument = NetworkInstrument()
    @State private var endpoint = ""
    @State private var mode: NetworkTestMode = .latency
    @State private var saving: FieldCapture?
    @Environment(RoomSession.self) private var room
    @Environment(CellularInstrument.self) private var cellular
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                RoomOrientationBanner()
                if cellularOnly { CellularTechnologyView(instrument: cellular) }
                TextField("https://your-test-endpoint", text: $endpoint).textFieldStyle(.roundedBorder).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .disabled(instrument.running).accessibilityLabel("Test endpoint").accessibilityIdentifier("network.endpoint")
                Picker("Test type", selection: $mode) { ForEach(NetworkTestMode.allCases) { Text($0.title).tag($0) } }.disabled(instrument.running)
                Text(mode.explanation).font(.callout).foregroundStyle(ProTheme.secondary)
                if cellularOnly { Text("To test cellular, turn off Wi-Fi in system settings. Results count as cellular only when every transaction confirms that route. MagicCuts does not switch your connectivity.").font(.callout) }
                Button(instrument.running ? "Stop test" : "Start \(mode.title.lowercased()) test") {
                    if instrument.running { instrument.stop() }
                    else { instrument.start(endpoint: endpoint, mode: mode, cellularOnly: cellularOnly) }
                }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).disabled(!instrument.running && EndpointPolicy.url(endpoint) == nil).frame(minHeight: 44).accessibilityIdentifier("network.start")
                LabeledContent("Test", value: instrument.status)
                LabeledContent("System path context", value: instrument.path).font(.caption)
                if let failure = instrument.failure { InlineFailure(message: failure) }
                if let capture = instrument.capture {
                    FieldCaptureEvidence(capture: capture)
                    Button("Save test") {
                        var capture = capture
                        if cellularOnly { capture.metadata["reportedTechnologyAtSave"] = cellular.technologies.map { $0.name }.joined(separator: ", ") }
                        saving = capture
                    }.buttonStyle(.bordered).controlSize(.large).frame(minHeight: 44).disabled(instrument.running)
                }
            }.padding(22).frame(maxWidth: 750).frame(maxWidth: .infinity)
        }.background(MC.canvas).scrollEdgeEffectStyle(.hard, for: .all).navigationTitle(cellularOnly ? "Cellular test" : "Network tests").navigationBarTitleDisplayMode(.inline)
        .onAppear { instrument.positionProvider = { [weak room] date in room?.placement(at: date) }; cellular.refreshTechnology() }
        .onDisappear { instrument.stop() }
        .onChange(of: scenePhase) { _, phase in if phase == .background { instrument.stop() } }
        .sheet(item: $saving) { FieldCaptureSaveView(capture: $0, library: library) }
    }
}

struct CellularTechnologyView: View {
    @Bindable var instrument: CellularInstrument
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reported radio technology").font(.headline)
            if instrument.technologies.isEmpty { Text("Technology unavailable").foregroundStyle(ProTheme.secondary) }
            ForEach(instrument.technologies) { technology in
                LabeledContent("Service \(technology.id)\(technology.dataService ? " · Data service" : "")", value: technology.name)
            }
            Text("Registration context from iOS. This is not signal strength or proof that a test used cellular.").font(.caption).foregroundStyle(ProTheme.secondary)
            Button("Refresh technology") { instrument.refreshTechnology() }.frame(minHeight: 44)
        }
    }
}

struct CellularInstrumentView: View {
    @Bindable var library: ProLibrary
    @Environment(CellularInstrument.self) private var instrument
    @State private var saving: FieldCapture?
    var body: some View {
        List {
            Section {
                CellularTechnologyView(instrument: instrument)
                if !instrument.technologyEvents.isEmpty {
                    DisclosureGroup("Observed technology changes") {
                        ForEach(instrument.technologyEvents.suffix(30)) { event in
                            VStack(alignment: .leading) { Text(event.detail); Text(event.date.formatted(date: .omitted, time: .standard)).font(.caption).foregroundStyle(ProTheme.secondary) }
                        }
                    }
                    Button("Save technology observations") { saving = instrument.technologyCapture }.frame(minHeight: 44)
                }
            }
            Section {
                NavigationLink("Measure cellular performance") { NetworkInstrumentView(library: library, cellularOnly: true) }
            }
            Section {
                Text(instrument.forecastStatus).font(.callout)
                Button(instrument.forecasting ? "Stop prediction updates" : "Request service predictions") {
                    if instrument.forecasting { instrument.stopForecasts() } else { instrument.startForecasts() }
                }.frame(minHeight: 44)
                if let date = instrument.forecastDate {
                    CellularForecastView(forecasts: instrument.forecasts, receivedAt: date)
                    Button("Save forecast snapshot") { saving = instrument.forecastCapture }.frame(minHeight: 44)
                }
                Text("Predictions are future possibilities. No prediction does not mean service is healthy.").font(.caption).foregroundStyle(ProTheme.secondary)
            } header: { Text("Service forecasts").foregroundStyle(ProTheme.secondary) }
            Section {
                let histories = library.index.fieldCaptures.filter { $0.source == "MetricKit · this installation" }
                if histories.isEmpty { Text("No cellular history has been delivered. iOS reports aggregated app activity later; a fresh install or short session may have none.").font(.callout).foregroundStyle(ProTheme.secondary) }
                ForEach(histories) { capture in
                    NavigationLink(capture.date.formatted(date: .abbreviated, time: .shortened)) { FieldCaptureDetailView(id: capture.id, library: library) }
                }
                if let failure = instrument.historyFailure { InlineFailure(message: failure) }
            } header: { Text("Delayed cellular history").foregroundStyle(ProTheme.secondary) }
        }.scrollEdgeEffectStyle(.hard, for: .all).navigationTitle("Cellular").onAppear { instrument.refreshTechnology() }.onDisappear { instrument.stopForecasts() }
        .sheet(item: $saving) { FieldCaptureSaveView(capture: $0, library: library) }
    }
}

struct CellularForecastView: View {
    let forecasts: [CellularForecast]
    let receivedAt: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Received \(receivedAt.formatted(date: .abbreviated, time: .standard))").font(.caption).foregroundStyle(ProTheme.secondary)
            if !forecasts.isEmpty {
                Chart(forecasts) { forecast in
                    BarMark(xStart: .value("Predicted start", forecast.startsAt), xEnd: .value("Predicted end", forecast.endsAt), y: .value("Impact", forecast.impact))
                        .foregroundStyle(ProTheme.signal.opacity(0.35))
                }.frame(height: 150).chartXAxisLabel("Predicted interval")
                ForEach(forecasts) { forecast in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(forecast.impact) impact · \(forecast.startsAt.formatted(date: .abbreviated, time: .shortened))–\(forecast.endsAt.formatted(date: .omitted, time: .shortened))").font(.callout.bold())
                        Text("Confidence: prediction \(forecast.predictionConfidence.lowercased()), start \(forecast.startConfidence.lowercased()), duration \(forecast.durationConfidence.lowercased())").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                }
            } else { Text("No predicted degradation in this response").font(.callout) }
        }
    }
}

struct CellularHistoryView: View {
    let history: CellularHistory
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delayed cellular condition distribution").font(.headline)
            Text("\(history.beginsAt.formatted(date: .abbreviated, time: .shortened))–\(history.endsAt.formatted(date: .abbreviated, time: .shortened))").font(.caption)
            if history.totalCount > 0 {
                Chart(history.buckets) { bucket in
                    BarMark(x: .value("Reported bars interval", "\(bucket.lowerBars.formatted())–\(bucket.upperBars.formatted())"),
                            y: .value("Share percent", Double(bucket.count) / Double(history.totalCount) * 100)).foregroundStyle(ProTheme.signal)
                }.frame(height: 180).chartYAxisLabel("Share (%)")
                ForEach(history.buckets) { bucket in LabeledContent("\(bucket.lowerBars.formatted())–\(bucket.upperBars.formatted()) bars interval", value: "\(bucket.count) samples") }
            } else { Text("The delivered histogram was empty.").foregroundStyle(ProTheme.secondary) }
        }
    }
}

struct DepthInstrumentView: View {
    @Bindable var library: ProLibrary
    @Environment(RoomSession.self) private var session
    @State private var ownSession = false
    @State private var baselineID: UUID?
    @State private var mode = 0
    @State private var saving: FieldCapture?
    private var canCapture: Bool {
        guard session.tracked, session.depth != nil else { return false }
        switch mode {
        case 0: return session.distance != nil && (session.confidence ?? 0) >= 1
        case 1: return !session.dimensions.isEmpty
        case 2: return session.surfaceFit?.isValid == true
        default: return true
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if session.canPin { RoomOrientationBanner() }
                if session.cameraActive {
                    ZStack {
                        RoomCameraView(session: session).frame(height: 300).clipShape(RoundedRectangle(cornerRadius: 16))
                        Image(systemName: "plus").font(.title).foregroundStyle(.white).shadow(radius: 2).accessibilityHidden(true)
                    }
                }
                Picker("LiDAR instrument", selection: $mode) { Text("Distance").tag(0); Text("Two points").tag(1); Text("Surface").tag(2); Text("Depth").tag(3) }.pickerStyle(.menu)
                Text(session.instruction).font(.callout).foregroundStyle(ProTheme.secondary)
                if let failure = session.failure { InlineFailure(message: failure) }
                if !session.cameraActive {
                    Button("Start LiDAR") { Task { ownSession = true; await session.start(.measurement, archive: library.archive) } }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44)
                }
                if mode == 0, let distance = session.distance {
                    Text("\(distance.formatted(.number.precision(.fractionLength(2)))) m").font(.system(size: 56, weight: .semibold, design: .rounded)).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
                    Text("Camera to reticle surface · \(session.confidence == 2 ? "high" : "limited") depth confidence").font(.callout).foregroundStyle(ProTheme.secondary)
                    Picker("Distance baseline", selection: $baselineID) {
                        Text("No baseline").tag(Optional<UUID>.none)
                        ForEach(library.index.fieldCaptures.filter { $0.metrics.contains(where: { $0.id == "distance" && $0.unit == "m" }) && $0.kind == .depth }) { capture in
                            Text(capture.title).tag(Optional(capture.id))
                        }
                    }
                    if let baseline = library.index.fieldCaptures.first(where: { $0.id == baselineID }), let previous = baseline.metrics.first(where: { $0.id == "distance" && $0.unit == "m" }) {
                        LabeledContent("Change from \(baseline.title)", value: "\((distance - previous.value).formatted(.number.precision(.fractionLength(2)).sign(strategy: .always()))) m")
                        Text("Keep the distance origin and target surface consistent with the baseline.").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                }
                if mode == 1 {
                    Button(session.firstPoint == nil ? "Set first point" : "Set second point") { session.selectPoint() }
                        .buttonStyle(.bordered).controlSize(.large).disabled(!session.tracked || (session.confidence ?? 0) < 1).frame(minHeight: 44)
                    if session.firstPoint != nil || !session.dimensions.isEmpty { Button("Undo last point") { session.undoPoint() }.frame(minHeight: 44) }
                    ForEach(session.dimensions) { dimension in LabeledContent(dimension.title, value: "\(dimension.meters.formatted(.number.precision(.fractionLength(2)))) m") }
                }
                if mode == 2 {
                    if let fit = session.surfaceFit {
                        ForEach(fit.metrics) { metric in LabeledContent(metric.title, value: "\(metric.formatted) \(metric.unit)") }
                        SurfaceEvidenceView(surface: fit)
                    } else { Text("Point at a broad surface with usable depth. The central patch needs at least 30 well-spread samples.").font(.callout) }
                    Text("Local best-fit plane from raw depth. Residuals include sensor noise; this is a broad unevenness estimate, not precision flatness metrology.").font(.caption).foregroundStyle(ProTheme.secondary)
                }
                if mode == 3, let depth = session.depth { DepthEvidenceView(depth: depth) }
                if session.cameraActive {
                    Button("Capture measurement") { saving = makeCapture() }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44).disabled(!canCapture)
                    Text("Glass, reflective or dark surfaces, motion, range, and shallow angles can reduce depth quality. Review confidence and check critical dimensions with a physical reference.").font(.caption).foregroundStyle(ProTheme.secondary)
                }
            }.padding(22).frame(maxWidth: 750).frame(maxWidth: .infinity)
        }.background(MC.canvas).scrollEdgeEffectStyle(.hard, for: .all).navigationTitle("LiDAR measurements").navigationBarTitleDisplayMode(.inline)
        .onDisappear { if ownSession { session.end() } }
        .sheet(item: $saving) { FieldCaptureSaveView(capture: $0, library: library) }
    }
    private func makeCapture() -> FieldCapture? {
        guard canCapture, let depth = session.depth else { return nil }
        var metrics: [FieldMetric] = []
        if mode == 0, let distance = session.distance { metrics = [.init(id: "distance", title: "Surface distance", value: distance, unit: "m", qualifier: "Camera to reticle surface estimate")] }
        if mode == 1 { metrics = session.dimensions.map { .init(id: $0.id.uuidString, title: $0.title, value: $0.meters, unit: "m", qualifier: "Two selected surface points") } }
        if mode == 2 { metrics = session.surfaceFit?.metrics ?? [] }
        let date = session.currentPoseDate ?? .now
        let titles = ["Surface distance", "Two-point dimensions", "Surface fit", "Depth and confidence"]
        return FieldCapture(title: titles[mode], kind: mode == 2 ? .surface : .depth, date: date, source: "LiDAR · raw scene depth",
            method: "ARKit sceneDepth with categorical depth confidence. Surface fitting uses a central raw-depth patch without plane-flattened mesh geometry. Dimensional precision is not an accuracy guarantee.",
            metrics: metrics, metadata: ["confidenceAtReticle": session.confidence.map { ["Low", "Medium", "High"][Int(min(2, $0))] } ?? "Unavailable"], depth: depth,
            surface: mode == 2 ? session.surfaceFit : nil,
            dimensions: mode == 1 ? session.dimensions : nil, placement: session.placement(at: date))
    }
}
