import AppIntents
import Foundation

struct SavedWorkflowEntity: AppEntity {
    var id: UUID
    var name: String
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "MagicCuts Workflow"
    static let defaultQuery = SavedWorkflowQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct SavedWorkflowQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SavedWorkflowEntity] { try await suggestedEntities().filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [SavedWorkflowEntity] {
        try await InstrumentArchive().loadIndex().workflows.map { SavedWorkflowEntity(id: $0.id, name: $0.name) }
    }
}
struct SavedDeviceGroupEntity: AppEntity {
    var id: UUID
    var name: String
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "MagicCuts Device Group"
    static let defaultQuery = SavedDeviceGroupQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}
struct SavedDeviceGroupQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SavedDeviceGroupEntity] { try await suggestedEntities().filter { identifiers.contains($0.id) } }
    func suggestedEntities() async throws -> [SavedDeviceGroupEntity] {
        try await InstrumentArchive().loadIndex().groups.map { SavedDeviceGroupEntity(id: $0.id, name: $0.name) }
    }
}

struct RunMagicCutsWorkflowIntent: AppIntent {
    static let title: LocalizedStringResource = "Run MagicCuts Workflow"
    static let description = IntentDescription("Measures a saved workflow in the foreground and returns its combined Boolean result. Missing readings throw an error when they prevent a result. Requires MagicCuts Pro.")
    static let openAppWhenRun = true
    @Parameter(title: "Workflow") var workflow: SavedWorkflowEntity
    static var parameterSummary: some ParameterSummary { Summary("Run \(\.$workflow)") }
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        try await ProAccess.require()
        guard let recipe = try await InstrumentArchive().loadIndex().workflows.first(where: { $0.id == workflow.id }) else {
            throw InstrumentError.unavailable("This workflow is no longer saved. Choose another workflow in Shortcuts.")
        }
        let outcome = try await WorkflowRunner.evaluate(recipe, radio: BluetoothRadio())
        guard let value = outcome.passed else { throw InstrumentError.unavailable("Missing readings prevented a workflow result. Open MagicCuts and run the workflow to inspect each condition.") }
        return .result(value: value)
    }
}

struct CheckMagicCutsGroupIntent: AppIntent {
    static let title: LocalizedStringResource = "Check MagicCuts Device Group"
    static let description = IntentDescription("Checks the medians of saved Bluetooth devices during one ten-second scan. Missing readings are unknown. Requires MagicCuts Pro.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed
    @Parameter(title: "Device Group") var group: SavedDeviceGroupEntity
    static var parameterSummary: some ParameterSummary { Summary("Check \(\.$group)") }
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        try await ProAccess.require()
        guard let saved = try await InstrumentArchive().loadIndex().groups.first(where: { $0.id == group.id }) else {
            throw InstrumentError.unavailable("This group is no longer saved. Choose another device group in Shortcuts.")
        }
        let installation = try await InstrumentArchive().installationID()
        let devices = try CloudDeviceLinks.expand(SharedDeviceStorage.shared.getAllDevices(), installationID: installation)
        let outcome = try await WorkflowRunner.evaluate(saved, devices: devices, radio: BluetoothRadio())
        guard let value = outcome.passed else { throw InstrumentError.unavailable("Not enough Bluetooth readings were received to determine this group's result. Open MagicCuts and check the group.") }
        return .result(value: value)
    }
}

enum ShortcutInstrument: String, AppEnum {
    case tilt, vibration, rotation, magnetic, pressure, altitude, heading, speed, sound, battery
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Instrument"
    static let caseDisplayRepresentations: [ShortcutInstrument: DisplayRepresentation] = [
        .tilt: "Level (degrees)", .vibration: "Vibration (g RMS)", .rotation: "Rotation (degrees per second)",
        .magnetic: "Magnetic Field (microteslas)", .pressure: "Pressure (hPa)", .altitude: "Elevation Change (meters)",
        .heading: "Compass (magnetic degrees)", .speed: "Speed (meters per second)", .sound: "Sound Level (dBFS)", .battery: "Battery (percent)"
    ]
    var kind: InstrumentKind { InstrumentKind(rawValue: rawValue) ?? .battery }
}

struct ReadMagicCutsInstrumentIntent: AppIntent {
    static let title: LocalizedStringResource = "Read MagicCuts Instrument"
    static let description = IntentDescription("Returns the median of a current measurement window in the instrument's stated units. Opens MagicCuts for sensor access. Requires Pro; unavailable or stale measurements throw an error.")
    static let openAppWhenRun = true
    @Parameter(title: "Instrument", default: .battery) var instrument: ShortcutInstrument
    @Parameter(title: "Measurement Seconds", default: 5, inclusiveRange: (1, 10)) var seconds: Int
    static var parameterSummary: some ParameterSummary { Summary("Read \(\.$instrument) for \(\.$seconds) seconds") }
    @MainActor func perform() async throws -> some IntentResult & ReturnsValue<Double> {
        try await ProAccess.require()
        let value = try await WorkflowRunner.measure(instrument.kind, source: .phone, seconds: Double(seconds), radio: BluetoothRadio())
        return .result(value: value)
    }
}
