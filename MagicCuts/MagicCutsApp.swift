import SwiftUI
import SwiftData
import TipKit

@main
struct MagicCutsApp: App {
    @State private var container: ModelContainer?
    @State private var failure: String?
    private let radio: any RadioScanning
    @State private var guidanceWarning: String?
    private static let configureTips = Result { try Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)]) }
    init() {
        if AppRuntime.isUITesting {
            let demo = DemoRadio()
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--radio-denied") { demo.failure = .denied }
            if arguments.contains("--radio-off") { demo.failure = .poweredOff }
            if arguments.contains("--radio-empty") { demo.readings = [] }
            if arguments.contains("--radio-interrupted") { demo.interruptAfterReadings = true }
            if arguments.contains("--radio-stale") { demo.timestampOffset = -30 }
            radio = demo
        } else { radio = BluetoothRadio() }
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if AppRuntime.isUnitTesting { Color.clear }
                else if let container { ProRootView(radio: radio, guidanceWarning: guidanceWarning).modelContainer(container) }
                else if let failure {
                    VStack(spacing: 20) {
                        ContentUnavailableView("Could not open your devices", systemImage: "externaldrive.badge.exclamationmark", description: Text(failure))
                        Button("Try again", action: load).buttonStyle(ControlStyle()).padding()
                    }
                } else { ProgressView("Opening devices…") }
            }
            #if DEBUG
            .preferredColorScheme(AppRuntime.isUITesting ? (ProcessInfo.processInfo.arguments.contains("--dark-appearance") ? .dark : .light) : nil)
            #endif
            .task { if container == nil { load() } }
        }
    }
    private func load() {
        do {
            let schema = Schema([MonitoredDevice.self, TestRecord.self])
            let testing = AppRuntime.isUITesting || AppRuntime.isUnitTesting
            let arguments = ProcessInfo.processInfo.arguments
            if !testing && FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.bradzellman.magiccuts") == nil {
                throw BluetoothError.storage
            }
            let persistentTest = AppRuntime.isUITesting && arguments.contains("--persistent-test-store")
            let config = testing
                ? ModelConfiguration("MagicCutsUITests", schema: schema, isStoredInMemoryOnly: !persistentTest, groupContainer: .none, cloudKitDatabase: .none)
                : ModelConfiguration(schema: schema, groupContainer: .identifier("group.com.bradzellman.magiccuts"), cloudKitDatabase: .none)
            let store = try ModelContainer(for: schema, configurations: [config])
            if AppRuntime.isUITesting && arguments.contains("--reset-test-store") {
                try store.mainContext.delete(model: TestRecord.self)
                try store.mainContext.delete(model: MonitoredDevice.self)
                try store.mainContext.save()
            }
            if testing && ProcessInfo.processInfo.arguments.contains("--seed-device") {
                store.mainContext.insert(MonitoredDevice(persistentIdentifier: DemoRadio.deviceID, name: "Desk sensor", requiredSignalStrength: -70, serviceUUIDs: ["180F"]))
                try store.mainContext.save()
            }
            if case .failure = Self.configureTips { guidanceWarning = "Tips couldn’t load. You can still find every setup step in Help." }
            container = store
            failure = nil
        } catch { failure = error.localizedDescription }
    }
}
