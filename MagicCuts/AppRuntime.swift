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
    static var testDuration: Duration { isUITesting ? .milliseconds(600) : .seconds(10) }
}
