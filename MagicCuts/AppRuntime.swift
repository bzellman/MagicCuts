import Foundation

enum AppRuntime {
    static var isUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitesting")
        #else
        false
        #endif
    }
    static var isUnitTesting: Bool { NSClassFromString("XCTestCase") != nil }
    static var forcesLockedProForUITesting: Bool {
        #if DEBUG
        isUITesting && ProcessInfo.processInfo.arguments.contains("--pro-locked")
        #else
        false
        #endif
    }
    static var hasDevelopmentProAccess: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--pro-development-access") || (isUITesting && !arguments.contains("--pro-locked"))
        #else
        false
        #endif
    }
    static var isInstrumentDemo: Bool {
        #if DEBUG
        return isUITesting && ProcessInfo.processInfo.arguments.contains("--pro-demo")
        #else
        return false
        #endif
    }
    static var roomUITestLibrary: URL? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard isUITesting, let index = args.firstIndex(of: "--room-fixture-id"), args.indices.contains(index + 1),
              let id = UUID(uuidString: args[index + 1]) else { return nil }
        return FileManager.default.temporaryDirectory.appendingPathComponent("MagicCuts-RoomFixture-\(id.uuidString)", isDirectory: true)
        #else
        return nil
        #endif
    }
    static var testDuration: Duration { isUITesting ? .milliseconds(600) : .seconds(10) }
}
