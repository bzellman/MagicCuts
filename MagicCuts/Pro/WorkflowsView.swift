import SwiftUI
import SwiftData
import AppIntents

struct WorkflowsView: View {
    @Bindable var library: ProLibrary
    let radio: any RadioScanning
    @Query(sort: \MonitoredDevice.name) private var devices: [MonitoredDevice]
    @State private var workflowEditor = false
    @State private var groupEditor = false
    @State private var editingWorkflow: WorkflowRecipe?
    @State private var editingGroup: DeviceGroup?
    @State private var runner = WorkflowRunner()
    @State private var showResult = false
    @State private var deletingWorkflow: WorkflowRecipe?
    @State private var deletingGroup: DeviceGroup?
    var body: some View {
        List {
            Section {
                Text("Turn measured conditions into a result your Shortcuts can use.").font(.system(.title2, design: .rounded).weight(.semibold)).listRowBackground(Color.clear)
            }
            Section {
                if library.index.workflows.isEmpty {
                    Text("Combine up to eight measurements. For example, check battery charge and response time before starting work.").font(.callout).foregroundStyle(ProTheme.secondary)
                }
                ForEach(library.index.workflows) { recipe in
                    VStack(alignment: .leading, spacing: 12) {
                        Button { editingWorkflow = recipe; workflowEditor = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(recipe.name).font(.system(.headline, design: .rounded)).foregroundStyle(.primary)
                                    Text("\(recipe.requiresAll ? "All" : "Any") of \(recipe.conditions.count) conditions · measured in order").font(.caption).foregroundStyle(ProTheme.secondary)
                                }
                                Spacer(); Image(systemName: "slider.horizontal.3").foregroundStyle(ProTheme.signal)
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                        Button { showResult = true; runner.run(recipe, radio: radio) } label: { Label("Run workflow", systemImage: "play.fill").frame(minHeight: 44) }.disabled(runner.running)
                    }.padding(.vertical, 6)
                    .swipeActions { Button("Delete", role: .destructive) { deletingWorkflow = recipe } }
                }
                Button { editingWorkflow = nil; workflowEditor = true } label: { Label("New workflow", systemImage: "plus").frame(minHeight: 44) }.accessibilityIdentifier("workflow.new")
            } header: { Text("Workflows") }
            Section {
                if library.index.groups.isEmpty { Text("Observe a set of saved Bluetooth devices together, using each device's saved threshold.").font(.callout).foregroundStyle(ProTheme.secondary) }
                ForEach(library.index.groups) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        Button { editingGroup = group; groupEditor = true } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(group.name).font(.system(.headline, design: .rounded)).foregroundStyle(.primary)
                                    Text("\(group.minimumMatches.map { "At least \($0)" } ?? (group.requiresAll ? "All" : "Any")) of \(group.deviceIDs.count) devices nearby").font(.caption).foregroundStyle(ProTheme.secondary)
                                }
                                Spacer(); Image(systemName: "slider.horizontal.3").foregroundStyle(ProTheme.signal)
                            }.frame(minHeight: 44)
                        }.buttonStyle(.plain)
                        Button {
                            showResult = true
                            runner.run(group, devices: devices.map { DeviceInfo(id: $0.persistentIdentifier, name: $0.name, rssi: $0.requiredSignalStrength, serviceUUIDs: $0.serviceUUIDs) }, radio: radio)
                        } label: { Label("Check group", systemImage: "wave.3.right").frame(minHeight: 44) }.disabled(runner.running)
                    }.padding(.vertical, 6)
                    .swipeActions { Button("Delete", role: .destructive) { deletingGroup = group } }
                }
                Button { editingGroup = nil; groupEditor = true } label: { Label("New device group", systemImage: "plus").frame(minHeight: 44) }.accessibilityIdentifier("group.new")
            } header: { Text("Device groups") }
            Section {
                NavigationLink("Use a result in Shortcuts") { WorkflowShortcutsHelp() }
                Text("A missing measurement is unknown. In an All rule, one known failure is enough to return false. In an Any rule, one known match is enough to return true. Otherwise unknown readings prevent a result.")
                    .font(.caption).foregroundStyle(ProTheme.secondary)
            }
            if let error = library.error { InlineFailure(message: error) }
        }
        .navigationTitle("Workflows")
        .sheet(isPresented: $workflowEditor) { WorkflowEditorView(library: library, recipe: editingWorkflow) }
        .sheet(isPresented: $groupEditor) { GroupEditorView(library: library, group: editingGroup) }
        .sheet(isPresented: $showResult, onDismiss: { runner.cancel() }) { WorkflowResultView(runner: runner) }
        .confirmationDialog("Delete this workflow?", isPresented: Binding(get: { deletingWorkflow != nil }, set: { if !$0 { deletingWorkflow = nil } }), titleVisibility: .visible) {
            Button("Delete workflow", role: .destructive) {
                guard let recipe = deletingWorkflow else { return }; deletingWorkflow = nil
                Task { do { _ = try await library.archive.deleteWorkflow(recipe.id); await library.reload() } catch { library.error = error.localizedDescription } }
            }
        } message: { Text("Shortcuts using it will ask you to select another workflow.") }
        .confirmationDialog("Delete this device group?", isPresented: Binding(get: { deletingGroup != nil }, set: { if !$0 { deletingGroup = nil } }), titleVisibility: .visible) {
            Button("Delete group", role: .destructive) {
                guard let group = deletingGroup else { return }; deletingGroup = nil
                Task { do { _ = try await library.archive.deleteGroup(group.id); await library.reload() } catch { library.error = error.localizedDescription } }
            }
        } message: { Text("Your saved devices stay in MagicCuts. Shortcuts using this group will need another selection.") }
    }
}

struct WorkflowEditorView: View {
    @Bindable var library: ProLibrary
    let recipe: WorkflowRecipe?
    @State private var name = ""
    @State private var requiresAll = true
    @State private var conditions: [WorkflowCondition] = []
    @State private var adding = false
    @State private var failure: String?
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Workflow name") { TextField("For example, Ready to work", text: $name).accessibilityIdentifier("workflow.name") }
                Section {
                    Picker("Return true when", selection: $requiresAll) { Text("All conditions match").tag(true); Text("Any condition matches").tag(false) }
                }
                Section {
                    ForEach(conditions) { condition in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(condition.kind.title) · \(condition.source.reportName)").font(.system(.headline, design: .rounded))
                            Text("\(condition.comparison.title) \(condition.kind.formatted(condition.threshold)) \(condition.kind.unit)").font(.callout)
                            Text("Median of a \(condition.window.formatted()) second measurement").font(.caption).foregroundStyle(ProTheme.secondary)
                        }.padding(.vertical, 4)
                    }.onDelete { conditions.remove(atOffsets: $0) }.onMove { conditions.move(fromOffsets: $0, toOffset: $1) }
                    Button { adding = true } label: { Label("Add condition", systemImage: "plus").frame(minHeight: 44) }.disabled(conditions.count >= 8).accessibilityIdentifier("workflow.add-condition")
                } header: { Text("Conditions") } footer: { Text("Measurements run in order while MagicCuts is open. They describe successive windows, not a simultaneous state or a continuous automation.") }
                if let failure { InlineFailure(message: failure) }
            }
            .navigationTitle(recipe == nil ? "New workflow" : "Edit workflow").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conditions.isEmpty || saving).accessibilityIdentifier("workflow.save") }
            }
            .onAppear { if let recipe { name = recipe.name; requiresAll = recipe.requiresAll; conditions = recipe.conditions } }
            .sheet(isPresented: $adding) { WorkflowConditionEditor { conditions.append($0); adding = false } }
            .interactiveDismissDisabled(saving)
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        var value = recipe ?? WorkflowRecipe(name: name, conditions: conditions)
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines); value.requiresAll = requiresAll; value.conditions = conditions
        do { try await library.save(value); MagicCutsShortcuts.updateAppShortcutParameters(); dismiss() }
        catch { failure = error.localizedDescription }
    }
}

struct WorkflowConditionEditor: View {
    let add: (WorkflowCondition) -> Void
    @Query(sort: \MonitoredDevice.name) private var devices: [MonitoredDevice]
    @State private var kind: InstrumentKind = .battery
    @State private var deviceID = ""
    @State private var endpoint = ""
    @State private var threshold = "50"
    @State private var comparison: RuleComparison = .atLeast
    @State private var window = 5.0
    @Environment(\.dismiss) private var dismiss
    private var source: MeasurementSource? {
        if kind == .bluetooth {
            guard let device = devices.first(where: { $0.persistentIdentifier == deviceID }) else { return nil }
            return .bluetooth(DeviceInfo(id: device.persistentIdentifier, name: device.name, rssi: device.requiredSignalStrength, serviceUUIDs: device.serviceUUIDs))
        }
        if kind == .network {
            guard let url = EndpointPolicy.url(endpoint) else { return nil }
            return MeasurementSource(id: url.absoluteString, name: url.host ?? "Endpoint", endpoint: url.absoluteString)
        }
        return .phone
    }
    private var number: Double? { Double(threshold.replacingOccurrences(of: ",", with: ".")).flatMap { $0.isFinite ? $0 : nil } }
    var body: some View {
        NavigationStack {
            Form {
                instrumentSection
                conditionSection
            }
            .navigationTitle("Add condition").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add") {
                    guard let source, let number else { return }
                    add(WorkflowCondition(kind: kind, source: source, comparison: comparison, threshold: number, window: window))
                }.disabled(source == nil || number == nil).accessibilityIdentifier("condition.add") }
            }
            .onChange(of: kind) { _, value in setDefaultThreshold(for: value) }
        }
    }
    private var instrumentSection: some View {
        Section {
                    Picker("Instrument", selection: $kind) {
                        // A compass bearing wraps at north; ordinal at-least rules would be misleading.
                        ForEach(InstrumentKind.allCases.filter { $0 != .heading && $0 != .altitude }) { kind in Text(kind.title).tag(kind) }
                    }
                    if kind == .bluetooth {
                        Picker("Device", selection: $deviceID) {
                            Text("Choose a device").tag("")
                            ForEach(devices) { Text($0.name).tag($0.persistentIdentifier) }
                        }
                        if devices.isEmpty { Text("Save a Bluetooth device from Instruments first.").foregroundStyle(ProTheme.secondary) }
                    }
                    if kind == .network {
                        TextField("https://your-server.example/health", text: $endpoint).keyboardType(.URL).autocorrectionDisabled().textInputAutocapitalization(.never)
                        Text("Use an endpoint you own or have permission to test.").font(.caption).foregroundStyle(ProTheme.secondary)
                    }
                }
    }
    private var conditionSection: some View {
        Section("Condition") {
                    Picker("Comparison", selection: $comparison) { ForEach(RuleComparison.allCases, id: \.self) { Text($0.title).tag($0) } }
                    HStack { TextField("Threshold", text: $threshold).keyboardType(.numbersAndPunctuation).accessibilityIdentifier("condition.threshold"); Text(kind.unit).foregroundStyle(ProTheme.secondary) }
                    Stepper("Measure for \(Int(window)) seconds", value: $window, in: 1 ... 10)
                    Text(kind.method).font(.caption).foregroundStyle(ProTheme.secondary)
                }
    }
    private func setDefaultThreshold(for kind: InstrumentKind) {
        switch kind {
        case .bluetooth: threshold = "-70"
        case .pressure: threshold = "1013"
        case .sound: threshold = "-30"
        case .network: threshold = "100"
        default: threshold = "0"
        }
    }
}

struct GroupEditorView: View {
    @Bindable var library: ProLibrary
    let group: DeviceGroup?
    @Query(sort: \MonitoredDevice.name) private var devices: [MonitoredDevice]
    @State private var name = ""
    @State private var requiresAll = true
    @State private var useMinimum = false
    @State private var minimum = 1
    @State private var selection = Set<UUID>()
    @State private var failure: String?
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Group name") { TextField("For example, Desk setup", text: $name).accessibilityIdentifier("group.name") }
                Section {
                    Toggle("Require a minimum count", isOn: $useMinimum)
                    if useMinimum { Stepper("At least \(minimum) devices nearby", value: $minimum, in: 1 ... max(1, selection.count)) }
                    else { Picker("Nearby when", selection: $requiresAll) { Text("All devices match").tag(true); Text("Any device matches").tag(false) } }
                }
                Section {
                    if devices.isEmpty { Text("Save Bluetooth devices from Instruments to add them here.").foregroundStyle(ProTheme.secondary) }
                    ForEach(devices) { device in
                        if let id = device.uuid {
                            Toggle(isOn: Binding(get: { selection.contains(id) }, set: { if $0 { selection.insert(id) } else { selection.remove(id) } })) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(device.name).font(.system(.headline, design: .rounded))
                                    Text("Saved threshold · \(device.requiredSignalStrength) dBm").font(.caption).foregroundStyle(ProTheme.secondary)
                                }.padding(.vertical, 4)
                            }
                        }
                    }
                } header: { Text("Devices") } footer: { Text("A single ten-second scan collects readings for the group. Each median is compared with the latest saved threshold. A missing device is unknown.") }
                if let failure { InlineFailure(message: failure) }
            }
            .navigationTitle(group == nil ? "New device group" : "Edit device group").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selection.isEmpty || saving) }
            }
            .onAppear {
                if let group {
                    name = group.name; requiresAll = group.requiresAll
                    selection = Set(group.deviceIDs.filter { id in devices.contains { $0.uuid == id } })
                    useMinimum = group.minimumMatches != nil; minimum = min(group.minimumMatches ?? 1, max(1, selection.count))
                }
            }
            .onChange(of: selection) { _, selected in minimum = min(minimum, max(1, selected.count)) }
            .interactiveDismissDisabled(saving)
        }
    }
    private func save() async {
        saving = true; defer { saving = false }
        var value = group ?? DeviceGroup(name: name, deviceIDs: [])
        value.name = name.trimmingCharacters(in: .whitespacesAndNewlines); value.deviceIDs = selection.sorted { $0.uuidString < $1.uuidString }; value.requiresAll = requiresAll
        value.minimumMatches = useMinimum ? minimum : nil
        do { try await library.save(value); MagicCutsShortcuts.updateAppShortcutParameters(); dismiss() }
        catch { failure = error.localizedDescription }
    }
}

struct WorkflowResultView: View {
    @Bindable var runner: WorkflowRunner
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if runner.running { ProgressView(runner.progress).frame(maxWidth: .infinity).padding(.vertical, 30) }
                    if let outcome = runner.outcome {
                        Text(outcome.passed.map { $0 ? "Conditions met" : "Conditions not met" } ?? "Couldn't determine a result")
                            .font(.system(.largeTitle, design: .rounded).bold())
                        Text(outcome.passed.map { "Shortcuts result: \($0 ? "true" : "false")" } ?? "Shortcuts reports an error when missing readings prevent a result.").font(.callout).foregroundStyle(ProTheme.secondary)
                        ForEach(outcome.readings) { reading in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: reading.passed.map { $0 ? "checkmark.circle" : "minus.circle" } ?? "questionmark.circle").foregroundStyle(reading.passed == true ? ProTheme.band : .secondary)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(reading.title).font(.system(.headline, design: .rounded))
                                    if let value = reading.value { Text("\(value.formatted(.number.precision(.fractionLength(0 ... 3)))) \(reading.unit)").font(.system(.title2, design: .rounded)).monospacedDigit() }
                                    Text(reading.detail).font(.callout).foregroundStyle(ProTheme.secondary)
                                }
                            }
                        }
                    }
                    if let failure = runner.failure { InlineFailure(message: failure) }
                }.padding(24).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }.background(MC.canvas)
            .navigationTitle("Run result").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(runner.running ? "Cancel" : "Done") { runner.cancel(); dismiss() } } }
            .onChange(of: scenePhase) { _, phase in if phase == .background { runner.cancel() } }
        }
    }
}

struct WorkflowShortcutsHelp: View {
    var body: some View {
        List {
            Section("1 · Add the action") { Text("In Shortcuts, create or edit a shortcut. Add Run MagicCuts Workflow or Check MagicCuts Device Group, then select the item you saved here.") }
            Section("2 · Use the result") { Text("Add an If action using the result. True means your rule matched. False means it did not. An unknown result stops with an error, so it cannot silently choose the wrong branch.") }
            Section("3 · Run and verify") {
                Text("Run the shortcut with your real devices. Workflows and sensor readings open MagicCuts because those measurements need the app in the foreground. Bluetooth groups use the same platform limits as individual Bluetooth checks.")
                ShortcutsLink().shortcutsLinkStyle(.automaticOutline).frame(minHeight: 44)
            }
            Section("Individual readings") { Text("Read MagicCuts Instrument returns a number and lets you choose a measurement window. Its units match the instrument. For Bluetooth, the existing Is Device Nearby action keeps its original any-sample threshold behavior.") }
        }
        .navigationTitle("Use in Shortcuts").navigationBarTitleDisplayMode(.inline)
    }
}
