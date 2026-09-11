import SwiftUI
import SwiftData

struct CloudSettingsSection: View {
    @Bindable var library: ProLibrary

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: { library.sync.snapshot.enabled }, set: { value in
                Task { await library.sync.setEnabled(value) }
            })) {
                Label("Sync with iCloud", systemImage: "icloud")
            }
            .disabled(library.sync.changingPreference)
            .accessibilityIdentifier("icloud.toggle")
            HStack(alignment: .top, spacing: 10) {
                if library.sync.snapshot.busy || library.sync.changingPreference { ProgressView().accessibilityLabel("iCloud sync in progress") }
                else { Image(systemName: library.sync.snapshot.failure ? "exclamationmark.icloud" : library.sync.snapshot.enabled ? "checkmark.icloud" : "internaldrive").foregroundStyle(ProTheme.secondary).accessibilityHidden(true) }
                VStack(alignment: .leading, spacing: 4) {
                    Text(library.sync.localFailure ?? library.sync.snapshot.message).font(.callout).accessibilityIdentifier("icloud.status")
                    if let date = library.sync.snapshot.lastSync {
                        Text("Last synced \(date.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                }
            }.padding(.vertical, 4)
            if library.sync.snapshot.enabled {
                Button("Sync now") { Task { await library.sync.transport.retry() } }
                    .disabled(library.sync.snapshot.busy || library.sync.changingPreference)
                    .accessibilityIdentifier("icloud.sync-now")
            }
            NavigationLink {
                PortableSetupsView(library: library)
            } label: { Label("Bluetooth setups from iCloud", systemImage: "wave.3.right") }
                .accessibilityIdentifier("icloud.setups")
            Text("Your Pro purchase restores through the App Store account used to buy it. iCloud stores your library separately.")
                .font(.caption).foregroundStyle(ProTheme.secondary)
        } header: {
            Text("Your library, across devices")
        } footer: {
            Text("Optional on each device. Turning this on merges your saved sessions, baselines, workflows, groups, reports and Bluetooth setup references with your private iCloud library. Edits and deletions sync. Turning it off keeps both copies. No MagicCuts account or servers.")
        }
    }
}

struct PortableSetupsView: View {
    @Bindable var library: ProLibrary
    private var otherSetups: [PortableDeviceSetup] {
        library.index.deviceSetups.filter { $0.installationID != library.sync.snapshot.installationID }
            .sorted { $0.device.name.localizedStandardCompare($1.device.name) == .orderedAscending }
    }

    var body: some View {
        List {
            Section {
                if otherSetups.isEmpty {
                    ContentUnavailableView("No other setups yet", systemImage: "icloud", description: Text("Turn on iCloud sync in MagicCuts on both devices using the same Apple Account."))
                }
                ForEach(otherSetups) { setup in
                    NavigationLink {
                        PortableSetupDetailView(setup: setup, installationID: library.sync.snapshot.installationID)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(setup.device.name).font(.system(.headline, design: .rounded))
                            Text("\(setup.device.requiredSignalStrength) dBm · \(setup.tests.count) saved tests")
                                .font(.caption).foregroundStyle(ProTheme.secondary)
                        }.padding(.vertical, 4)
                    }
                }
            } footer: {
                Text("Bluetooth identities and signal calibration belong to the device that measured them. Reconnect a saved setup here and test it again. Existing measurements remain available as evidence from their original device.")
            }
        }
        .navigationTitle("Bluetooth setups")
    }
}

struct PortableSetupDetailView: View {
    let setup: PortableDeviceSetup
    let installationID: String
    @Query(sort: \MonitoredDevice.name) private var devices: [MonitoredDevice]
    @State private var selected = ""
    @State private var linkedID: String?
    @State private var failure: String?

    private var linked: MonitoredDevice? { devices.first { $0.persistentIdentifier == linkedID } }
    private var radio: any RadioScanning { AppRuntime.isUITesting ? DemoRadio() : BluetoothRadio() }

    var body: some View {
        List {
            Section {
                LabeledContent("Saved threshold", value: "\(setup.device.requiredSignalStrength) dBm")
                Text("A reference from another device. Your current device needs its own Bluetooth connection and calibration.")
                    .font(.callout).foregroundStyle(ProTheme.secondary)
            }
            Section {
                if let linked {
                    Label("Connected to \(linked.name)", systemImage: "checkmark.circle")
                    NavigationLink("Test this device") { DeviceDetailView(device: linked, radio: radio) }
                    Button("Disconnect this reference") { saveLink(nil) }
                } else {
                    Picker("Device you identified here", selection: $selected) {
                        Text("Choose a saved device").tag("")
                        ForEach(devices) { Text($0.name).tag($0.persistentIdentifier) }
                    }
                    .accessibilityIdentifier("icloud.device-picker")
                    Button("Connect this setup") { saveLink(selected) }.disabled(selected.isEmpty || installationID.isEmpty)
                        .accessibilityIdentifier("icloud.connect-setup")
                    NavigationLink("Find a device") { DeviceDiscoveryView(bluetoothViewModel: BluetoothViewModel(radio: radio)) }
                }
                if let failure { InlineFailure(message: failure) }
            } header: { Text("On this device") } footer: {
                Text("Saved workflows and groups will use the device you choose here. Groups use its current threshold; workflow conditions stay as saved. Review those conditions and test nearby and away before relying on a result.")
            }
            Section("Original test history") {
                if setup.tests.isEmpty { Text("No saved tests.").foregroundStyle(ProTheme.secondary) }
                ForEach(setup.tests.sorted { $0.date > $1.date }) { record in
                    if let evidence = record.evidence {
                        DisclosureGroup {
                            Text("\(evidence.threshold) dBm · \(evidence.samples.count) readings · \(evidence.range)").font(.callout)
                            if evidence.isDraft { Text("Draft settings").font(.caption) }
                            ForEach(Array(evidence.samples.enumerated()), id: \.offset) { _, sample in
                                LabeledContent(sample.date.formatted(date: .omitted, time: .standard), value: "\(sample.rssi) dBm").font(.caption).monospacedDigit()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(evidence.position.title) · \(evidence.summary)").font(.headline)
                                Text(record.date, format: .dateTime).font(.caption).foregroundStyle(ProTheme.secondary)
                            }
                        }
                    } else { Text("This original test record couldn't be read.") }
                }
            }
        }
        .navigationTitle(setup.device.name)
        .task {
            do { linkedID = try CloudDeviceLinks.load(installationID: installationID).first { $0.sourceID == setup.device.id }?.localDeviceID }
            catch { failure = error.localizedDescription }
        }
    }

    private func saveLink(_ id: String?) {
        do {
            try CloudDeviceLinks.save(sourceID: setup.device.id, localDeviceID: id, installationID: installationID)
            linkedID = id; failure = nil
        } catch { failure = error.localizedDescription }
    }
}
