import XCTest
import UIKit
import AppIntents

nonisolated final class MagicCutsUITests: XCTestCase {
    @MainActor func testReducedMotionJourneyWhenEnabled() throws {
        guard UIAccessibility.isReduceMotionEnabled else {
            throw XCTSkip("Enable Reduce Motion in the test device settings for this acceptance check")
        }
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--pro-demo", "--seed-device"]
        app.launch()
        for mode in ["inspect", "compare", "live"] {
            let button = app.buttons["instrument.mode.\(mode)"]
            XCTAssertTrue(button.waitForExistence(timeout: 10))
            button.tap()
            XCTAssertTrue(button.isSelected)
        }
        capture(app, "pro-reduced-motion")
        app.terminate()
        testSavedDeviceModesThresholdAndHistory()
    }

    @MainActor func testPhysicalDiscoveryReceivesAdvertisements() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Real Bluetooth acceptance requires a physical device")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["--pro-development-access"]
        app.launch()
        openSavedDevices(app)
        XCTAssertTrue(app.buttons["saved-devices.find"].waitForExistence(timeout: 10))
        app.buttons["saved-devices.find"].tap()
        let permission = addUIInterruptionMonitor(withDescription: "Bluetooth permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
            if alert.buttons["OK"].exists { alert.buttons["OK"].tap(); return true }
            return false
        }
        defer { removeUIInterruptionMonitor(permission) }
        app.buttons["discovery.start"].tap()
        app.tap()
        let advertisement = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "device.")).firstMatch
        XCTAssertTrue(advertisement.waitForExistence(timeout: 20), "A real Bluetooth advertisement must reach discovery")
        app.buttons["Stop"].tap()
        XCTAssertTrue(app.buttons["discovery.start"].exists)
        #endif
    }

    @MainActor func testWelcomeUnnamedIdentificationAndExplicitSave() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "-welcomeComplete", "NO"]
        app.launch()
        openSavedDevices(app)
        XCTAssertTrue(app.buttons["welcome.find"].waitForExistence(timeout: 10))
        capture(app, "welcome")
        app.buttons["welcome.find"].tap()
        app.buttons["discovery.start"].tap()
        let unnamed = app.buttons["device.BBBBBBBB-1111-2222-3333-444444444444"]
        XCTAssertTrue(unnamed.waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Scan paused. Tap Start scanning when you’re ready."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["discovery.start"].isEnabled)
        app.buttons["discovery.start"].tap()
        XCTAssertTrue(unnamed.waitForExistence(timeout: 5))
        unnamed.tap()
        capture(app, "discovery-identify")
        app.buttons["device.nameSelected"].tap()
        let field = app.textFields["device.name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        capture(app, "name-device")
        XCTAssertFalse(app.buttons["device.save"].isEnabled)
        field.tap()
        field.typeText("My tracker")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(unnamed.waitForExistence(timeout: 5))
        app.buttons["device.nameSelected"].tap()
        XCTAssertEqual(app.textFields["device.name"].value as? String, "For example, Desk sensor")
        app.textFields["device.name"].tap()
        app.textFields["device.name"].typeText("My tracker")
        app.buttons["device.save"].tap()
        XCTAssertTrue(app.navigationBars["My tracker"].waitForExistence(timeout: 5))
        app.buttons["test.away"].tap()
        XCTAssertTrue(app.staticTexts["All samples below threshold"].waitForExistence(timeout: 5))
        reveal(app.buttons["Configure Shortcut"], in: app)
        app.buttons["Configure Shortcut"].tap()
        reveal(app.buttons["shortcut.verify"], in: app)
        XCTAssertEqual(app.buttons["shortcut.verify"].label, "I tested my Shortcut")
        app.buttons["shortcut.verify"].tap()
        XCTAssertEqual(app.buttons["shortcut.verify"].label, "Verified by you")
    }

    @MainActor func testExistingUserSkipsWelcomeAndResumesEvidence() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--persistent-test-store", "--reset-test-store", "--seed-device", "-welcomeComplete", "NO"]
        app.launch()
        openSavedDevices(app)
        XCTAssertTrue(app.staticTexts["Desk sensor"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["welcome.find"].exists)
        openFirstSavedDevice(app)
        app.buttons["test.nearby"].tap()
        XCTAssertTrue(app.staticTexts["All samples above threshold"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["--uitesting", "--persistent-test-store"]
        app.launch()
        openSavedDevices(app)
        XCTAssertTrue(app.staticTexts["Desk sensor"].waitForExistence(timeout: 10))
        openFirstSavedDevice(app)
        XCTAssertTrue(app.staticTexts["All samples above threshold"].waitForExistence(timeout: 5))
        app.buttons["threshold.edit"].tap()
        app.buttons["Increase threshold"].tap()
        app.buttons["threshold.apply"].tap()
        XCTAssertTrue(app.staticTexts["Threshold changed. Test again."].waitForExistence(timeout: 5))
    }

    @MainActor func testDiscoveryPermissionFailureAndEmptyScan() {
        let app = XCUIApplication()
        for scenario in ["--radio-denied", "--radio-off", "--radio-empty", "--radio-stale"] {
            app.launchArguments = ["--uitesting", scenario, "-welcomeComplete", "YES"]
            app.launch()
            openSavedDevices(app)
            XCTAssertTrue(app.buttons["saved-devices.find"].waitForExistence(timeout: 10))
            app.buttons["saved-devices.find"].tap()
            app.buttons["discovery.start"].tap()
            if scenario == "--radio-denied" {
                XCTAssertTrue(app.buttons["Open Settings"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.buttons["discovery.start"].isEnabled)
            } else if scenario == "--radio-off" {
                XCTAssertTrue(app.otherElements["error.message"].waitForExistence(timeout: 5) || app.staticTexts["error.message"].exists)
            } else if scenario == "--radio-empty" {
                XCTAssertTrue(app.staticTexts["Listening for devices"].waitForExistence(timeout: 5))
                XCTAssertFalse(app.buttons["device.AAAAAAAA-1111-2222-3333-444444444444"].exists)
            } else {
                XCTAssertTrue(app.buttons["device.AAAAAAAA-1111-2222-3333-444444444444"].waitForExistence(timeout: 5))
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "stale")).firstMatch.exists)
            }
            app.terminate()
        }
    }

    @MainActor private func auditVisibleDeviceContent(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .trait]) { issue in
            // Native modal chrome obscures offscreen List children in XCTest's contrast image.
            // The test repeats the audit after scrolling those controls into view.
            if issue.auditType == .contrast, let element = issue.element {
                let done = app.buttons["Done"]
                let bar = app.navigationBars.firstMatch
                if (done.exists && element.frame.maxY > done.frame.minY) || (bar.exists && element.frame.minY < bar.frame.maxY) {
                    print("Deferred clipped device contrast sample: \(element.label), \(element.frame)")
                    return true
                }
            }
            print("Device accessibility issue: \(issue.compactDescription), \(issue.element?.debugDescription ?? "unavailable")")
            return false
        }
    }

    @MainActor private func openFirstSavedDevice(_ app: XCUIApplication) {
        let savedDevice = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "saved-device.")).firstMatch
        reveal(savedDevice, in: app)
        savedDevice.tap()
    }

    @MainActor private func openSavedDevices(_ app: XCUIApplication) {
        let menu = app.buttons["instrument.device-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        app.buttons["Manage devices"].tap()
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 {
            if element.isHittable { return }
            app.swipeUp()
        }
        // XCUI can report a visible, multiline SwiftUI button as not hittable at
        // accessibility sizes. The caller's native tap scrolls it into view and
        // verifies the resulting state; existence alone is not the outcome check.
        XCTAssertTrue(element.exists)
    }

    @MainActor func testInterruptedTestRecoversControls() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--seed-device", "--radio-interrupted"]
        app.launch()
        openSavedDevices(app)
        XCTAssertTrue(app.staticTexts["Desk sensor"].waitForExistence(timeout: 10))
        openFirstSavedDevice(app)
        app.buttons["test.nearby"].tap()
        XCTAssertTrue(app.staticTexts["Test interrupted by another Bluetooth operation. Try again."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["test.nearby"].isEnabled)
        app.buttons["threshold.edit"].tap()
        app.buttons["draft.test"].tap()
        XCTAssertTrue(app.staticTexts["Test interrupted by another Bluetooth operation. Try again."].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["threshold.apply"].isEnabled)
    }

    @MainActor func testLargeTextAndAccessibility() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--seed-device", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openSavedDevices(app)
        XCTAssertTrue(app.staticTexts["Desk sensor"].waitForExistence(timeout: 10))
        capture(app, "home-largest-text")
        try auditVisibleDeviceContent(app)
        app.swipeUp(velocity: .slow)
        capture(app, "home-largest-actions")
        try auditVisibleDeviceContent(app)
        openFirstSavedDevice(app)
        XCTAssertTrue(app.buttons["threshold.edit"].waitForExistence(timeout: 5))
        capture(app, "detail-largest-text")
        reveal(app.buttons["threshold.edit"], in: app)
        app.buttons["threshold.edit"].tap()
        XCTAssertTrue(app.sliders["threshold.slider"].waitForExistence(timeout: 5))
        capture(app, "threshold-largest-text")
        try auditVisibleDeviceContent(app)
        app.buttons["Increase threshold"].tap()
        XCTAssertEqual(app.sliders["threshold.slider"].value as? String, "-69 dBm")
        reveal(app.buttons["threshold.apply"], in: app)
        XCTAssertEqual(app.sliders["threshold.slider"].value as? String, "-69 dBm", "Scrolling must not change the threshold")
        app.buttons["threshold.apply"].tap()
        reveal(app.buttons["threshold.edit"], in: app)
        app.buttons["threshold.edit"].tap()
        XCTAssertEqual(app.sliders["threshold.slider"].value as? String, "-69 dBm", "Apply must persist the edited threshold")
        app.buttons["Cancel"].tap()
        reveal(app.buttons["Configure Shortcut"], in: app)
        app.buttons["Configure Shortcut"].tap()
        capture(app, "shortcuts-largest-text")
        reveal(app.buttons["shortcut.verify"], in: app)
        app.buttons["shortcut.verify"].tap()
        XCTAssertEqual(app.buttons["shortcut.verify"].label, "Verified by you")
    }

    @MainActor func testCaptureApprovedScreens() {
        for appearance in ["Light", "Dark"] {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "--seed-device", "-AppleInterfaceStyle", appearance, "-technicalMode", "NO"]
            if appearance == "Dark" { app.launchArguments.append("--dark-appearance") }
            app.launch()
            openSavedDevices(app)
            XCTAssertTrue(app.staticTexts["Desk sensor"].waitForExistence(timeout: 10))
            capture(app, "home-\(appearance)")
            openFirstSavedDevice(app)
            XCTAssertTrue(app.buttons["threshold.edit"].waitForExistence(timeout: 5))
            capture(app, "detail-\(appearance)")
            app.buttons["threshold.edit"].tap()
            XCTAssertTrue(app.sliders["threshold.slider"].waitForExistence(timeout: 5))
            capture(app, "threshold-\(appearance)")
            app.buttons["Cancel"].tap()
            app.swipeUp()
            app.buttons["Configure Shortcut"].tap()
            XCTAssertTrue(app.buttons["shortcut.verify"].waitForExistence(timeout: 5))
            capture(app, "shortcuts-\(appearance)")
            app.terminate()
        }
    }
    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor func testSavedDeviceModesThresholdAndHistory() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--seed-device"]
        app.launch()
        openSavedDevices(app)
        XCTAssertTrue(app.staticTexts["Desk sensor"].waitForExistence(timeout: 10))
        openFirstSavedDevice(app)
        XCTAssertTrue(app.buttons["mode.technical"].waitForExistence(timeout: 5))
        app.buttons["mode.technical"].tap()
        app.buttons["threshold.edit"].tap()
        app.buttons["Increase threshold"].tap()
        app.buttons["Cancel"].tap()
        app.buttons["threshold.edit"].tap()
        XCTAssertEqual(app.sliders["threshold.slider"].value as? String, "-70 dBm")
        app.buttons["draft.test"].tap()
        XCTAssertTrue(app.staticTexts["All samples above threshold"].waitForExistence(timeout: 5))
        app.buttons["Increase threshold"].tap()
        app.buttons["threshold.apply"].tap()
        app.buttons["test.nearby"].tap()
        XCTAssertTrue(app.staticTexts["All samples above threshold"].waitForExistence(timeout: 5))
        app.swipeUp()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Test history")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Test history"].exists)
    }
}
