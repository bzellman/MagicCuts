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
    static var testDuration: Duration { isUITesting ? .milliseconds(600) : .seconds(10) }
}
