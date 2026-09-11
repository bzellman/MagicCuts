import SwiftUI
import SwiftData
import TipKit

struct DeviceDiscoveryView: View {
    @StateObject var bluetoothViewModel: BluetoothViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var savedDevices: [MonitoredDevice]
    @State private var search = ""
    @State private var strongestFirst = true
    @State private var selected: UUID?
    @State private var naming: RadioDevice?
    @State private var added: MonitoredDevice?
    @State private var interrupted = false

    private var results: [RadioDevice] {
        bluetoothViewModel.devices.filter {
            search.isEmpty || $0.displayName.localizedCaseInsensitiveContains(search) || $0.id.uuidString.localizedCaseInsensitiveContains(search)
        }.sorted { left, right in
            if strongestFirst {
                let leftStale = Date().timeIntervalSince(left.lastSeen) >= 15
                let rightStale = Date().timeIntervalSince(right.lastSeen) >= 15
                if leftStale != rightStale { return !leftStale }
                if left.rssi != right.rssi { return left.rssi > right.rssi }
            } else if left.displayName != right.displayName {
                return left.displayName.localizedStandardCompare(right.displayName) == .orderedAscending
            }
            return left.id.uuidString < right.id.uuidString
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Picker("Sort", selection: $strongestFirst) {
                        Text("Strongest signal").tag(true)
                        Text("Name").tag(false)
                    }.pickerStyle(.menu)
                    Spacer()
                    if AppRuntime.isUITesting { Text("Demo").font(.caption).foregroundStyle(MC.action) }
                }
                if let error = bluetoothViewModel.error { InlineFailure(message: error) }
                if bluetoothViewModel.bluetoothError == .denied {
                    Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                        .buttonStyle(ControlStyle(primary: false))
                }
                if interrupted { InlineFailure(message: "Scan paused. Tap Start scanning when you’re ready.") }
                if bluetoothViewModel.devices.isEmpty {
                    ContentUnavailableView(bluetoothViewModel.isScanning ? "Listening for devices" : "Ready to find your device", systemImage: "wave.3.right", description: Text("Wake your device and keep it close. Some Bluetooth devices do not advertise."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    LazyVStack(spacing: 12) {
                        ForEach(results) { device in row(device, now: timeline.date) }
                    }
                }
                if selected == nil && bluetoothViewModel.devices.contains(where: { $0.name.isEmpty }) { TipView(IdentifyTip()) }
            }.padding(MC.inset).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }
        .background(MC.canvas).navigationTitle("Find a device").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name or identifier")
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                if bluetoothViewModel.isScanning {
                    HStack { ProgressView(); Text(bluetoothViewModel.status) }.frame(maxWidth: .infinity).padding().accessibilityElement(children: .combine)
                    Button("Stop") { bluetoothViewModel.stopScanning() }.buttonStyle(ControlStyle(primary: false))
                } else {
                    Button("Start scanning") { interrupted = false; bluetoothViewModel.startScanning() }
                        .buttonStyle(ControlStyle()).accessibilityIdentifier("discovery.start")
                }
            }.padding(MC.inset).frame(maxWidth: 640).frame(maxWidth: .infinity).background(.bar)
        }
        .sheet(item: $naming) { device in
            SaveDeviceView(observation: device) { saved in
                naming = nil
                added = saved
            }
        }
        .navigationDestination(item: $added) { device in DeviceDetailView(device: device, radio: bluetoothViewModel.radio) }
        .onDisappear { bluetoothViewModel.stopScanning() }
        .onChange(of: phase) { _, value in
            if value == .background && bluetoothViewModel.isScanning {
                bluetoothViewModel.stopScanning()
                interrupted = true
            }
        }
    }

    private func row(_ device: RadioDevice, now: Date) -> some View {
        let expanded = selected == device.id
        let age = max(0, Int(now.timeIntervalSince(device.lastSeen)))
        return VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { selected = expanded ? nil : device.id }
                IdentifyTip().invalidate(reason: .actionPerformed)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "wave.3.right").foregroundStyle(MC.action).frame(width: 44, height: 44)
                        .background(MC.action.opacity(0.1), in: Circle()).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(device.displayName).font(.headline)
                        Text(age < 5 ? "Seen just now" : age < 15 ? "Seen \(age)s ago" : "Last seen \(age)s ago · stale")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text("\(device.rssi) dBm").font(.callout).monospacedDigit()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.caption).accessibilityHidden(true)
                }.foregroundStyle(.primary).frame(minHeight: 52)
            }.buttonStyle(.plain).accessibilityIdentifier("device.\(device.id.uuidString)")
            if expanded {
                Divider()
                Text("Move one device closer. Watch its signal change. A name alone does not identify it.").font(.callout).foregroundStyle(.secondary)
                if let saved = savedDevices.first(where: { $0.uuid == device.id }) {
                    Button("Open saved device") { bluetoothViewModel.stopScanning(); added = saved }.buttonStyle(ControlStyle(primary: false))
                } else {
                    Button("Name this device", systemImage: "pencil") {
                        bluetoothViewModel.stopScanning()
                        naming = device
                    }.buttonStyle(ControlStyle(primary: false)).accessibilityIdentifier("device.nameSelected")
                }
            }
        }.padding(16).background(expanded ? MC.action.opacity(0.08) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: MC.radius))
            .overlay { RoundedRectangle(cornerRadius: MC.radius).strokeBorder(expanded ? MC.action : Color.primary.opacity(0.07), lineWidth: 1) }
    }
}

struct SaveDeviceView: View {
    let observation: RadioDevice
    let onSave: (MonitoredDevice) -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var error: String?
    @State private var committed: MonitoredDevice?

    init(observation: RadioDevice, onSave: @escaping (MonitoredDevice) -> Void) {
        self.observation = observation
        self.onSave = onSave
        _name = State(initialValue: observation.name)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Name your device") {
                    TextField("For example, Desk sensor", text: $name).accessibilityIdentifier("device.name")
                    Text("Choose a name you’ll recognize in Shortcuts.").font(.callout).foregroundStyle(.secondary)
                }
                Section("Starting threshold") { Text("−70 dBm"); Text("You can tune this after saving.").foregroundStyle(.secondary) }
                if let error { Section { InlineFailure(message: error) } }
                Section { Button(committed == nil ? "Save device" : "Retry sync") { save() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty).accessibilityIdentifier("device.save") }
            }.navigationTitle("Name this device").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button(committed == nil ? "Cancel" : "Close") { dismiss() }.foregroundStyle(.primary) } }
        }
    }
    private func save() {
        do {
            try DeviceRepository(context: context).save(committed, id: observation.id, name: name, threshold: -70, services: observation.services)
            guard let device = try context.fetch(FetchDescriptor<MonitoredDevice>()).first(where: { $0.uuid == observation.id }) else { throw BluetoothError.storage }
            onSave(device)
        } catch {
            self.error = error.localizedDescription
            if case DeviceRepository.ValidationError.sync = error {
                committed = try? context.fetch(FetchDescriptor<MonitoredDevice>()).first(where: { $0.uuid == observation.id })
            }
        }
    }
}
