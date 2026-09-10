import SwiftUI
import SwiftData

struct ContentView: View {
    let radio: any RadioScanning
    var guidanceWarning: String?
    @State private var warningDismissed = false
    @Query private var devices: [MonitoredDevice]
    @AppStorage("welcomeComplete") private var welcomeComplete = false
    @State private var welcome = false
    @State private var discovery = false

    var body: some View {
        NavigationStack {
            MonitoredDevicesView(radio: radio)
                .navigationDestination(isPresented: $discovery) {
                    DeviceDiscoveryView(bluetoothViewModel: BluetoothViewModel(radio: radio))
                }
        }
        .tint(MC.action)
        .safeAreaInset(edge: .top) {
            if let guidanceWarning, !warningDismissed {
                HStack {
                    Text(guidanceWarning).font(.callout)
                    Button("Dismiss") { warningDismissed = true }.frame(minWidth: 44, minHeight: 44)
                }.padding().background(.bar)
            }
        }
        .task {
            if !devices.isEmpty { welcomeComplete = true }
            welcome = !welcomeComplete && devices.isEmpty
        }
        .sheet(isPresented: $welcome) {
            WelcomeView {
                welcomeComplete = true
                welcome = false
            } find: {
                welcomeComplete = true
                welcome = false
                discovery = true
            }
        }
        .onChange(of: welcome) { _, presented in
            if !presented { welcomeComplete = true }
        }
    }
}

struct WelcomeView: View {
    let skip: () -> Void
    let find: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Make nearby useful.").font(.largeTitle.bold())
                        Text("Use Bluetooth signal in your Shortcuts.").font(.title3).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 20) {
                        HStack { Text("Your device"); Spacer(); Text("Signal, not distance").foregroundStyle(.white.opacity(0.8)) }
                            .font(.callout)
                        HStack(spacing: 24) {
                            Image(systemName: "iphone").font(.system(size: 44))
                            Image(systemName: "chart.bar.xaxis").font(.system(size: 64))
                                .foregroundStyle(.cyan)
                                .symbolEffect(.variableColor, isActive: !reduceMotion)
                        }.frame(maxWidth: .infinity).accessibilityHidden(true)
                        Text("Walls, movement, and advertising affect the result.").font(.callout)
                    }.foregroundStyle(.white).padding(20).frame(maxWidth: .infinity)
                        .background(MC.instrument, in: RoundedRectangle(cornerRadius: MC.radius))
                    VStack(spacing: 0) {
                        step("Find your device", detail: "See nearby Bluetooth devices.", symbol: "magnifyingglass")
                        Divider()
                        step("Test nearby and away", detail: "Watch the signal change.", symbol: "chart.bar.fill")
                        Divider()
                        step("Use it in Shortcuts", detail: "Build automations with signal.", symbol: "square.stack.3d.up")
                    }.padding(.horizontal, 16).background(.background, in: RoundedRectangle(cornerRadius: MC.radius))
                    Button("Find a device", action: find).buttonStyle(ControlStyle()).accessibilityIdentifier("welcome.find")
                    Text("Bluetooth access is requested when you scan.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }.padding(MC.inset).frame(maxWidth: 600).frame(maxWidth: .infinity)
            }.background(MC.canvas).navigationTitle("MagicCuts").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Skip", action: skip).accessibilityIdentifier("welcome.skip") } }
        }
    }

    private func step(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(MC.action)
                .frame(width: 48, height: 48).background(MC.action.opacity(0.1), in: Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.padding(.vertical, 16)
    }
}
