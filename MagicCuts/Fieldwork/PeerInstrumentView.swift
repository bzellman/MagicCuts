import SwiftUI
import Charts

struct PeerInstrumentView: View {
    @Bindable var library: ProLibrary
    @State private var instrument = PeerInstrument()
    @State private var transport = 0
    @State private var host = true
    @State private var mode = 0
    @State private var saving: FieldCapture?
    @Environment(RoomSession.self) private var room
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoomOrientationBanner()
                if instrument.connected {
                    Label(instrument.status, systemImage: "checkmark.shield").font(.headline)
                    Text("\(instrument.transportTitle) · \(instrument.pathDescription)").font(.caption).foregroundStyle(ProTheme.secondary)
                    Picker("Peer instrument", selection: $mode) { Text("Benchmark").tag(0); Text("Range").tag(1); Text("Link report").tag(2) }.pickerStyle(.segmented)
                    if mode == 0 { benchmark }
                    else if mode == 1 { ranging }
                    else { linkReport }
                    Button("Disconnect") { instrument.stop() }.frame(minHeight: 44)
                } else if let code = instrument.verificationCode {
                    Text("Confirm this connection").font(.system(.title2, design: .rounded).weight(.semibold))
                    Text(code).font(.system(size: 44, weight: .semibold, design: .monospaced)).accessibilityLabel("Connection code \(code.map(String.init).joined(separator: " "))")
                        .accessibilityIdentifier("peer.code")
                    Text("Compare the code shown on the other device, then confirm on both devices.").font(.callout).foregroundStyle(ProTheme.secondary)
                    Button(instrument.locallyConfirmed ? "Waiting for other device" : "Codes match") { instrument.confirm() }
                        .buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).disabled(instrument.locallyConfirmed).frame(minHeight: 44).accessibilityIdentifier("peer.confirm")
                    Button("Cancel connection") { instrument.stop() }.frame(minHeight: 44)
                } else {
                    Text("Two devices. One local test.").font(.system(.title2, design: .rounded).weight(.semibold))
                    Text("Open Field tools → Peer instruments on another device. Host on one, then find and connect from the other.").font(.callout).foregroundStyle(ProTheme.secondary)
                    Picker("Connection transport", selection: $transport) { Text("Local network").tag(0); Text("Wi-Fi Aware").tag(1) }.pickerStyle(.segmented)
                        .disabled(instrument.hosting || instrument.browsing || instrument.aware.running)
                    if transport == 0 {
                        Button("Host a local test") { instrument.host() }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44).accessibilityIdentifier("peer.host")
                        Button("Find a host") { instrument.browse() }.buttonStyle(.bordered).controlSize(.large).frame(minHeight: 44).accessibilityIdentifier("peer.browse")
                        Text(instrument.status).font(.callout)
                        ForEach(instrument.peers) { peer in
                            Button { instrument.connect(peer) } label: { Label(peer.name, systemImage: "iphone.gen3.radiowaves.left.and.right").frame(minHeight: 44) }
                        }
                    } else {
                        Picker("Device role", selection: $host) { Text("Host").tag(true); Text("Join").tag(false) }.pickerStyle(.segmented).disabled(instrument.aware.running)
                        WiFiAwarePairingControls(host: host)
                        Text("Open pairing on both devices first. Then advertise on the host and discover it from the other device.").font(.callout).foregroundStyle(ProTheme.secondary)
                        ForEach(instrument.aware.paired) { peer in Label(peer.name, systemImage: "checkmark.shield").font(.callout) }
                        Button(host ? "Advertise to paired devices" : "Discover paired hosts") { instrument.startAware(host: host) }
                            .buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44).disabled(!instrument.aware.supported)
                        Text(instrument.aware.status).font(.callout)
                        ForEach(instrument.aware.discovered) { peer in Button(peer.name) { instrument.aware.connect(peer.id) }.frame(minHeight: 44) }
                        if let failure = instrument.aware.failure { InlineFailure(message: failure) }
                    }
                    if instrument.hosting || instrument.browsing || instrument.aware.running { Button("Stop discovery") { instrument.stop() }.frame(minHeight: 44) }
                }
                if let failure = instrument.failure { InlineFailure(message: failure) }
                if !instrument.connected, let capture = instrument.capture {
                    FieldCaptureEvidence(capture: capture)
                    Button("Save completed observations") { saving = capture }.frame(minHeight: 44)
                }
            }.padding(22).frame(maxWidth: 750).frame(maxWidth: .infinity)
        }.background(MC.canvas).scrollEdgeEffectStyle(.hard, for: .all).navigationTitle("Peer instruments").navigationBarTitleDisplayMode(.inline)
        .onAppear {
            instrument.positionProvider = { [weak room] date in room?.placement(at: date) }
            instrument.aware.watchDevices()
        }
        .onDisappear { instrument.stop(); UIApplication.shared.isIdleTimerDisabled = room.cameraActive }
        .onChange(of: instrument.connected) { _, connected in UIApplication.shared.isIdleTimerDisabled = connected || room.cameraActive }
        .onChange(of: scenePhase) { _, phase in if phase == .background { instrument.stop() } }
        .sheet(item: $saving) { FieldCaptureSaveView(capture: $0, library: library) }
    }
    private var benchmark: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("20 echo requests, then 2 MiB in each direction. The result measures encrypted application traffic between these devices.").font(.callout).foregroundStyle(ProTheme.secondary)
            Button(instrument.testing ? "Stop benchmark" : "Run benchmark") {
                if instrument.testing { instrument.stopBenchmark() } else { instrument.benchmark() }
            }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44).accessibilityIdentifier("peer.benchmark")
            Text(instrument.testStatus).font(.callout)
            if let capture = instrument.capture {
                FieldCaptureEvidence(capture: capture)
                Button("Save benchmark") { saving = capture }.frame(minHeight: 44).disabled(instrument.testing)
            }
        }
    }
    private var ranging: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            VStack(alignment: .leading, spacing: 16) {
                Text(instrument.nearby.status).font(.callout)
                if instrument.nearby.fresh {
                    if let distance = instrument.nearby.distance {
                        Text("\(distance.formatted(.number.precision(.fractionLength(2)))) m").font(.system(size: 56, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                    }
                    if let azimuth = instrument.nearby.azimuth {
                        Image(systemName: "arrow.up").font(.system(size: 80, weight: .medium)).foregroundStyle(ProTheme.signal).rotationEffect(.radians(azimuth))
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .accessibilityLabel("\(abs(Int(azimuth * 180 / .pi))) degrees \(azimuth < 0 ? "left" : "right") relative to phone")
                    } else { Text("Direction unavailable. Distance only.").font(.callout).foregroundStyle(ProTheme.secondary) }
                    Button("Capture this range") { saving = instrument.nearby.capture(peerName: instrument.peerName) }.frame(minHeight: 44)
                } else if instrument.nearby.active { Text("Waiting for a fresh measurement").foregroundStyle(ProTheme.secondary) }
                Button(instrument.nearby.active ? "Stop ranging" : "Start ranging") {
                    if instrument.nearby.active { instrument.stopNearby() }
                    else { Task { await instrument.nearby.start() } }
                }.buttonStyle(.borderedProminent).controlSize(.large).tint(MC.action).frame(minHeight: 44)
                Text("Start ranging on both devices. Hold the phones upright and point their back cameras toward each other. Distance and direction may be unavailable outside the supported range or line of sight.").font(.caption).foregroundStyle(ProTheme.secondary)
                if let failure = instrument.nearby.failure { InlineFailure(message: failure) }
            }
        }
    }
    private var linkReport: some View {
        VStack(alignment: .leading, spacing: 14) {
            if instrument.transportTitle != "Wi-Fi Aware" { Text("This is a local network connection. Connect with Wi-Fi Aware to inspect its optional link reports.").font(.callout).foregroundStyle(ProTheme.secondary) }
            else if let capture = instrument.aware.capture {
                FieldCaptureEvidence(capture: capture)
                Text("Report age is shown by its timestamp. Unavailable optional fields remain blank.").font(.caption).foregroundStyle(ProTheme.secondary)
                Button("Save link report") {
                    saving = capture
                }.frame(minHeight: 44)
            } else { Text("No Wi-Fi Aware performance fields have been returned yet.").font(.callout).foregroundStyle(ProTheme.secondary) }
            if let failure = instrument.aware.failure { InlineFailure(message: failure) }
        }
    }
}

struct FieldSampleChart: View {
    let capture: FieldCapture
    private var key: String { capture.kind == .nearby ? "distance" : "rttMS" }
    var body: some View {
        if capture.samples.contains(where: { $0.values[key] != nil }) {
            VStack(alignment: .leading, spacing: 8) {
                Chart(capture.samples) { sample in
                    if let value = sample.values[key] { PointMark(x: .value("Elapsed seconds", sample.elapsed), y: .value(key == "distance" ? "Meters" : "Milliseconds", value)).foregroundStyle(ProTheme.signal) }
                }.frame(height: 160).chartXAxisLabel("Elapsed seconds").chartYAxisLabel(key == "distance" ? "m" : "ms")
                Text("Discrete observations. Missing or failed samples are not interpolated.").font(.caption).foregroundStyle(ProTheme.secondary)
            }
        }
    }
}
