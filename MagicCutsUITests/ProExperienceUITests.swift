import XCTest

nonisolated final class ProExperienceUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--pro-demo", "--seed-device", "-showSessionLiveActivity", "NO"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["instrument.choose"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }

    @MainActor private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .trait]) { issue in
            // XCTest samples obscured SwiftUI text beneath native scrolling chrome.
            // Audit those same readings again after scrolling them into view below.
            if issue.auditType == .contrast, let element = issue.element {
                let tabBar = app.tabBars.firstMatch
                let record = app.buttons["instrument.record"]
                let visibleBottom = min(tabBar.exists ? tabBar.frame.minY : app.frame.maxY,
                                        record.exists ? record.frame.minY - 12 : app.frame.maxY)
                let visibleTop = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY
                if element.frame.maxY > visibleBottom || element.frame.minY < visibleTop {
                    print("Deferred clipped contrast sample: \(element.label), \(element.frame)")
                    return true
                }
            }
            print("Accessibility issue: \(issue.compactDescription). Element: \(issue.element?.debugDescription ?? "unavailable")")
            return false
        }
    }

    @MainActor func testPhysicalInstrumentReadingsAndForegroundRecovery() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Sensor acceptance requires physical hardware")
        #else
        let app = XCUIApplication()
        app.launchArguments = ["--pro-development-access", "-showSessionLiveActivity", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["instrument.choose"].waitForExistence(timeout: 10))
        let permission = addUIInterruptionMonitor(withDescription: "Instrument permissions") { alert in
            for title in ["Allow While Using App", "Allow Once", "Allow", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap(); return true
            }
            return false
        }
        defer { removeUIInterruptionMonitor(permission) }
        for kind in ["tilt", "vibration", "rotation", "magnetic", "pressure", "altitude", "heading", "speed", "sound", "battery"] {
            app.buttons["instrument.choose"].tap()
            let choice = app.buttons["instrument.pick.\(kind)"]
            reveal(choice, in: app); choice.tap()
            app.tap()
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            for host in [springboard, app] {
                let alert = host.alerts.firstMatch
                if alert.waitForExistence(timeout: 2) {
                    capture(host, "physical-permission-\(kind)")
                    for title in ["Allow While Using App", "Allow Once", "Allow", "OK"] where alert.buttons[title].exists {
                        alert.buttons[title].tap(); break
                    }
                }
            }
            let live = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "instrument.phase", "Live")).firstMatch
            XCTAssertTrue(live.waitForExistence(timeout: 20), "\(kind) must receive an actual sensor reading")
            XCTAssertFalse(app.staticTexts["Sample session"].exists)
            capture(app, "physical-pro-\(kind)")
        }
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@", "instrument.phase", "Paused")).firstMatch.waitForExistence(timeout: 10))
        capture(app, "physical-pro-background-paused")
        #endif
    }

    @MainActor func testLockedAppHasNoInstrumentEntryPoints() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--pro-locked"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Make every reading useful."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["instrument.choose"].exists)
        XCTAssertFalse(app.tabBars.buttons["Sessions"].exists)
        reveal(app.buttons["Restore purchases"], in: app)
        XCTAssertTrue(app.buttons["Restore purchases"].exists)
        XCTAssertTrue(app.buttons["pro.purchase"].exists)
        capture(app, "pro-paywall")
    }

    @MainActor func testBaselineInspectRecordExportAndFieldReport() {
        let app = launch(["--dark-appearance"])
        capture(app, "pro-live-dark")
        app.buttons["instrument.set-baseline"].tap()
        XCTAssertTrue(app.textFields["baseline.name"].waitForExistence(timeout: 5))
        app.textFields["baseline.name"].tap(); app.textFields["baseline.name"].typeText("Quiet desk")
        app.buttons["Save"].tap()
        app.buttons["instrument.mode.inspect"].tap()
        capture(app, "pro-inspect-dark")
        app.buttons["instrument.mode.compare"].tap()
        XCTAssertTrue(app.staticTexts["Quiet desk"].firstMatch.waitForExistence(timeout: 5))
        capture(app, "pro-compare-dark")
        app.buttons["instrument.record"].tap()
        XCTAssertTrue(app.buttons["Mark"].waitForExistence(timeout: 5))
        app.buttons["Mark"].tap()
        let mark = app.textFields["For example, Door closed"]
        XCTAssertTrue(mark.waitForExistence(timeout: 5))
        mark.tap(); mark.typeText("Window opened")
        app.buttons["Add mark"].tap()
        app.buttons["instrument.record"].tap()
        XCTAssertTrue(app.buttons["session.save"].waitForExistence(timeout: 5))
        let title = app.textFields["session.name"]
        title.tap()
        if let current = title.value as? String { title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)) }
        title.typeText("Window comparison")
        let savedName = title.value as? String ?? ""
        XCTAssertTrue(savedName.contains("Window comparison"))
        app.buttons["session.save"].tap()
        app.buttons["Sessions"].firstMatch.tap()
        let saved = app.staticTexts[savedName].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); saved.tap()
        XCTAssertTrue(app.staticTexts["Window opened"].firstMatch.waitForExistence(timeout: 5))
        reveal(app.buttons["session.export"], in: app)
        app.buttons["session.export"].tap()
        XCTAssertTrue(app.navigationBars["Export session"].waitForExistence(timeout: 5))
        capture(app, "pro-export")
        app.buttons["Done"].tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["reports.open"].tap()
        app.buttons["report.new"].tap()
        app.textFields["report.title"].tap(); app.textFields["report.title"].typeText("Office check")
        app.buttons["report.save"].tap()
        XCTAssertTrue(app.staticTexts["Office check"].waitForExistence(timeout: 5))
        capture(app, "pro-field-reports")
    }

    @MainActor func testWorkflowCreationAndMeasuredResult() {
        let app = launch()
        app.buttons["Workflows"].firstMatch.tap()
        app.buttons["workflow.new"].tap()
        app.textFields["workflow.name"].tap(); app.textFields["workflow.name"].typeText("Ready to work")
        app.buttons["workflow.add-condition"].tap()
        XCTAssertTrue(app.buttons["condition.add"].waitForExistence(timeout: 5))
        app.buttons["condition.add"].tap()
        app.buttons["workflow.save"].tap()
        XCTAssertTrue(app.buttons["Run workflow"].waitForExistence(timeout: 5))
        app.buttons["Run workflow"].tap()
        XCTAssertTrue(app.staticTexts["Conditions met"].waitForExistence(timeout: 8))
        capture(app, "pro-workflow-result")
    }

    @MainActor func testInstrumentNavigationAndLargeText() throws {
        let app = launch()
        capture(app, "pro-live-light")
        try audit(app)
        app.swipeUp()
        try audit(app)
        app.swipeDown()
        for kind in ["tilt", "vibration", "rotation", "magnetic", "pressure", "altitude", "heading", "speed", "sound", "battery"] {
            app.buttons["instrument.choose"].tap()
            let choice = app.buttons["instrument.pick.\(kind)"]
            reveal(choice, in: app); choice.tap()
            XCTAssertTrue(app.buttons["instrument.mode.live"].waitForExistence(timeout: 5))
            capture(app, "pro-\(kind)")
        }
        app.terminate()
        let large = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        capture(large, "pro-largest-text")
        try audit(large)
        large.swipeUp(velocity: .slow)
        capture(large, "pro-largest-reading")
        try audit(large)
        large.swipeUp(velocity: .slow)
        capture(large, "pro-largest-chart")
        try audit(large)
        large.swipeUp(velocity: .slow)
        capture(large, "pro-largest-controls")
        try audit(large)
        for _ in 0 ..< 4 { large.swipeDown(velocity: .fast) }
        large.buttons["instrument.mode-menu"].tap()
        large.buttons["instrument.mode.inspect"].tap()
        capture(large, "pro-inspect-largest-text")
    }
}
