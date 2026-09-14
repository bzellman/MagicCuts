import SwiftUI
import SwiftData
import TipKit

struct DeviceDiscoveryView: View {
    @StateObject var bluetoothViewModel: BluetoothViewModel
    var onDone: (() -> Void)? = nil
    var claimsDoneBar: Binding<Bool>? = nil
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Query private var savedDevices: [MonitoredDevice]
    @Environment(\.modelContext) private var context
    @State private var search = ""
    @State private var sort: DiscoverySort = .found
    @State private var order: [UUID] = []
    @State private var selected: UUID?
    @State private var naming: RadioDevice?
    @State private var namingText = ""
    @State private var namingError: String?
    @State private var namingCommitted: MonitoredDevice?
    @State private var added: MonitoredDevice?
    @State private var interrupted = false

    private var results: [RadioDevice] {
        DiscoveryList.displayed(bluetoothViewModel.devices, search: search, order: order)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 12) {
                    DiscoverySortControl(selection: $sort).frame(maxWidth: .infinity)
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
        .safeAreaInset(edge: .bottom, content: actionBar)
        .onAppear { if onDone != nil { claimsDoneBar?.wrappedValue = true } }
        .navigationDestination(item: $added) { device in DeviceDetailView(device: device, radio: bluetoothViewModel.radio) }
        .onDisappear {
            bluetoothViewModel.stopScanning()
            claimsDoneBar?.wrappedValue = false
        }
        .onChange(of: bluetoothViewModel.devices.map(\.id)) { _, ids in
            if order.isEmpty {
                order = DiscoveryList.ranked(bluetoothViewModel.devices, by: sort)
            } else {
                order = DiscoveryList.tracking(order, ids: ids)
            }
        }
        .onChange(of: sort) { _, value in
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                order = DiscoveryList.ranked(bluetoothViewModel.devices, by: value)
            }
        }
        .onChange(of: selected) { _, value in
            if value != naming?.id { cancelNaming() }
        }
        .onChange(of: phase) { _, value in
            if value == .background && bluetoothViewModel.isScanning {
                bluetoothViewModel.stopScanning()
                interrupted = true
            }
        }
    }

    private func actionBar() -> some View {
        let stacked = dynamicType.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return VStack(spacing: 12) {
            if bluetoothViewModel.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                    Text(bluetoothViewModel.status)
                }
                .font(.callout)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
            }
            layout {
                scanButton.frame(maxWidth: .infinity)
                if let onDone {
                    Button("Done", action: onDone)
                        .buttonStyle(ControlStyle(primary: false))
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("discovery.done")
                }
            }
        }
        .padding(MC.inset)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    @ViewBuilder private var scanButton: some View {
        if bluetoothViewModel.isScanning {
            Button("Stop") { bluetoothViewModel.stopScanning() }
                .buttonStyle(ControlStyle(primary: false))
                .accessibilityIdentifier("discovery.stop")
        } else {
            Button("Start scanning") { interrupted = false; bluetoothViewModel.startScanning() }
                .buttonStyle(ControlStyle())
                .accessibilityIdentifier("discovery.start")
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
                } else if naming?.id == device.id {
                    namingForm(device)
                } else {
                    Button("Name this device", systemImage: "pencil") {
                        bluetoothViewModel.stopScanning()
                        naming = device
                        namingText = device.name
                        namingError = nil
                        namingCommitted = nil
                    }.buttonStyle(ControlStyle(primary: false)).accessibilityIdentifier("device.nameSelected")
                }
            }
        }.padding(16).background(expanded ? MC.action.opacity(0.08) : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: MC.radius))
            .overlay { RoundedRectangle(cornerRadius: MC.radius).strokeBorder(expanded ? MC.action : Color.primary.opacity(0.07), lineWidth: 1) }
    }

    private func namingForm(_ observation: RadioDevice) -> some View {
        let stacked = dynamicType.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 12)) : AnyLayout(HStackLayout(spacing: 12))
        return VStack(alignment: .leading, spacing: 12) {
            TextField("For example, Desk sensor", text: $namingText).textFieldStyle(.roundedBorder).accessibilityIdentifier("device.name")
            Text("Choose a name you’ll recognize in Shortcuts.").font(.callout).foregroundStyle(.secondary)
            Text("Starting threshold −70 dBm. You can tune this after saving.").font(.caption).foregroundStyle(.secondary)
            if let namingError { InlineFailure(message: namingError) }
            layout {
                Button(namingCommitted == nil ? "Cancel" : "Close") { cancelNaming() }
                    .buttonStyle(ControlStyle(primary: false))
                    .frame(maxWidth: .infinity)
                Button(namingCommitted == nil ? "Save device" : "Retry sync") { saveNamed(observation) }
                    .buttonStyle(ControlStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(namingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("device.save")
            }
        }
    }

    private func cancelNaming() {
        naming = nil
        namingText = ""
        namingError = nil
        namingCommitted = nil
    }

    private func saveNamed(_ observation: RadioDevice) {
        do {
            try DeviceRepository(context: context).save(namingCommitted, id: observation.id, name: namingText, threshold: -70, services: observation.services)
            guard let device = try context.fetch(FetchDescriptor<MonitoredDevice>()).first(where: { $0.uuid == observation.id }) else { throw BluetoothError.storage }
            cancelNaming()
            added = device
        } catch {
            namingError = error.localizedDescription
            if case DeviceRepository.ValidationError.sync = error {
                namingCommitted = try? context.fetch(FetchDescriptor<MonitoredDevice>()).first(where: { $0.uuid == observation.id })
            }
        }
    }
}

struct DiscoverySortControl: View {
    @Binding var selection: DiscoverySort
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var highlight
    var body: some View {
        if dynamicType.isAccessibilitySize {
            Menu {
                ForEach(DiscoverySort.allCases) { option in
                    Button { selection = option } label: {
                        if selection == option { Label(option.title, systemImage: "checkmark") }
                        else { Text(option.title) }
                    }.accessibilityIdentifier("discovery.sort.\(option.id)")
                }
            } label: {
                HStack {
                    Text(selection.title).font(.system(.headline, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.body)
                }.padding(14).frame(maxWidth: .infinity, minHeight: 46)
                    .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
            }
            .accessibilityLabel("Sort devices")
            .accessibilityValue(selection.accessibilityTitle)
            .accessibilityHint("List order stays put while signals change.")
            .accessibilityIdentifier("discovery.sort-menu")
        } else {
            HStack(spacing: 4) {
                ForEach(DiscoverySort.allCases) { option in
                    Button { selection = option } label: {
                        Text(option.title)
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .contentShape(Rectangle())
                            .foregroundStyle(selection == option ? .white : .primary)
                            .background {
                                if selection == option {
                                    RoundedRectangle(cornerRadius: 10).fill(MC.action)
                                        .matchedGeometryEffect(id: "selection", in: highlight)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.accessibilityTitle)
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                    .accessibilityIdentifier("discovery.sort.\(option.id)")
                }
            }
            .padding(4)
            .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Sort devices")
            .accessibilityHint("List order stays put while signals change.")
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: selection)
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}
