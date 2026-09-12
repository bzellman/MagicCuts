import XCTest

nonisolated final class ProExperienceUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--pro-demo", "--seed-device", "-showSessionLiveActivity", "NO"] + extra
        app.launch()
        // Xcode can prelaunch the target without fixture arguments on the first test.
        // Require the explicit demo marker before any test interacts with account settings.
        if !app.staticTexts["Sample session"].firstMatch.waitForExistence(timeout: 5) {
            app.terminate()
            app.launch()
        }
        XCTAssertTrue(app.staticTexts["Sample session"].firstMatch.waitForExistence(timeout: 10))
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

    @MainActor func testICloudIsOptionalAndAnUnavailableAccountDoesNotBlockInstruments() {
        let app = launch()
        app.buttons["Settings"].tap()
        let toggle = app.switches["icloud.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        capture(app, "icloud-default-off")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let status = app.staticTexts["icloud.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let unavailable = NSPredicate(format: "label CONTAINS %@", "iCloud is unavailable")
        expectation(for: unavailable, evaluatedWith: status)
        waitForExpectations(timeout: 10)
        XCTAssertEqual(toggle.value as? String, "0")
        capture(app, "icloud-unavailable")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["instrument.mode.inspect"].waitForExistence(timeout: 5))
        app.buttons["instrument.mode.inspect"].tap()
        XCTAssertTrue(app.buttons["instrument.record"].waitForExistence(timeout: 5))
        app.buttons["instrument.record"].tap()
        XCTAssertTrue(app.buttons["Mark"].waitForExistence(timeout: 5))
    }

    @MainActor func testICloudBluetoothSetupRequiresAConnectionBeforeTheGroupCanRun() {
        let app = launch(["--cloud-setup-demo", "--dark-appearance"])
        app.buttons["Settings"].tap()
        let setups = app.buttons["icloud.setups"]
        reveal(setups, in: app); setups.tap()
        let setup = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Studio sensor · sample")).firstMatch
        XCTAssertTrue(setup.waitForExistence(timeout: 5)); setup.tap()
        capture(app, "icloud-setup-reference")
        let picker = app.buttons["icloud.device-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5)); picker.tap()
        let choice = app.buttons.matching(NSPredicate(format: "label == %@", "Desk sensor")).allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(choice); choice?.tap()
        app.buttons["icloud.connect-setup"].tap()
        XCTAssertTrue(app.staticTexts["Connected to Desk sensor"].waitForExistence(timeout: 5))
        capture(app, "icloud-setup-connected")
        app.navigationBars.buttons["Bluetooth setups"].tap()
        app.navigationBars["Bluetooth setups"].buttons["Settings"].tap()
        app.buttons["Done"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.workflows"].waitForExistence(timeout: 5))
        app.buttons["settings.workflows"].tap()
        let run = app.buttons["Check group"]
        reveal(run, in: app); run.tap()
        XCTAssertTrue(app.staticTexts["Conditions met"].waitForExistence(timeout: 8))
        capture(app, "icloud-connected-group-result")
    }

    @MainActor func testICloudSettingsRemainReachableAtLargestText() throws {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.buttons["Settings"].tap()
        let toggle = app.switches["icloud.toggle"]
        reveal(toggle, in: app)
        XCTAssertEqual(toggle.value as? String, "0")
        capture(app, "icloud-largest-text")
        try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .trait])
        let setups = app.buttons["icloud.setups"]
        reveal(setups, in: app); setups.tap()
        XCTAssertTrue(app.staticTexts["No other setups yet"].waitForExistence(timeout: 5))
        capture(app, "icloud-largest-empty")
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
        app.buttons["instrument.mode.inspect"].tap()
        XCTAssertTrue(app.buttons["instrument.record"].waitForExistence(timeout: 5))
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
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.sessions"].waitForExistence(timeout: 5))
        app.buttons["settings.sessions"].tap()
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
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.workflows"].waitForExistence(timeout: 5))
        app.buttons["settings.workflows"].tap()
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

    @MainActor func testStartFlowPromptOpensChooser() {
        let app = launch()
        XCTAssertTrue(app.buttons["instrument.log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["instrument.record"].exists)
        let start = app.buttons["instrument.start-flow"]
        reveal(start, in: app); start.tap()
        XCTAssertTrue(app.buttons["flow.choose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["flow.new"].exists)
        capture(app, "pro-start-flow")
        app.buttons["flow.choose"].tap()
        XCTAssertTrue(app.navigationBars["Choose Workflow"].waitForExistence(timeout: 5))
    }

    @MainActor func testInstrumentPickerFilterAndSearch() {
        let app = launch()
        app.buttons["instrument.choose"].tap()
        XCTAssertTrue(app.buttons["instrument.filter.motion"].waitForExistence(timeout: 5))
        app.buttons["instrument.filter.motion"].tap()
        XCTAssertTrue(app.buttons["instrument.pick.tilt"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["instrument.pick.battery"].exists)
        app.buttons["instrument.filter.all"].tap()
        let battery = app.buttons["instrument.pick.battery"]
        for _ in 0 ..< 6 where !battery.exists { app.swipeUp() }
        XCTAssertTrue(battery.waitForExistence(timeout: 5))
        capture(app, "pro-instrument-picker")
        app.buttons["Cancel"].tap()
    }

    @MainActor func testLargestTextAndControlsReflow() throws {
        let large = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(large.buttons["instrument.mode-menu"].waitForExistence(timeout: 5))
        capture(large, "pro-largest-text")
        let log = large.buttons["instrument.log"]
        let start = large.buttons["instrument.start-flow"]
        let scroll = large.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0 ..< 14 {
            scroll.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(log.waitForExistence(timeout: 5))
        XCTAssertTrue(large.buttons["instrument.record"].exists)
        XCTAssertTrue(start.exists)
        capture(large, "pro-largest-controls")
    }

    @MainActor func testInstrumentNavigationAndLargeText() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["instrument.log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["instrument.record"].exists)
        XCTAssertTrue(app.buttons["instrument.start-flow"].exists)
        capture(app, "pro-live-light")
        try audit(app)
        app.swipeUp()
        try audit(app)
        app.swipeDown()
        for kind in ["tilt", "vibration", "rotation", "magnetic", "pressure", "altitude", "heading", "speed", "sound", "battery"] {
            if !app.buttons["Cancel"].exists {
                let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.32))
                let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.78))
                from.press(forDuration: 0.05, thenDragTo: to)
                let chooser = app.buttons["instrument.choose"]
                XCTAssertTrue(chooser.waitForExistence(timeout: 5))
                if chooser.isHittable { chooser.tap() }
                else { chooser.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            }
            let choice = app.buttons["instrument.pick.\(kind)"]
            reveal(choice, in: app)
            if choice.isHittable { choice.tap() }
            else { choice.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
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

    @MainActor func testManufactureGaugeAndCompareEvidence() {
        let app = launch()
        app.buttons["instrument.choose"].tap()
        XCTAssertTrue(app.buttons["instrument.filter.motion"].waitForExistence(timeout: 5))
        app.buttons["instrument.filter.motion"].tap()
        app.buttons["instrument.pick.tilt"].tap()
        XCTAssertTrue(app.staticTexts["Sample session"].firstMatch.waitForExistence(timeout: 8))
        capture(app, "manufacture-level")
        app.buttons["instrument.choose"].tap()
        XCTAssertTrue(app.buttons["instrument.filter.environment"].waitForExistence(timeout: 5))
        app.buttons["instrument.filter.environment"].tap()
        let compass = app.buttons["instrument.pick.heading"]
        reveal(compass, in: app)
        compass.tap()
        XCTAssertTrue(app.staticTexts["Sample session"].firstMatch.waitForExistence(timeout: 8))
        capture(app, "manufacture-compass")
        app.buttons["instrument.choose"].tap()
        app.buttons["instrument.filter.all"].tap()
        let bluetooth = app.buttons["instrument.pick.bluetooth"]
        for _ in 0 ..< 4 where !bluetooth.isHittable { app.swipeDown() }
        XCTAssertTrue(bluetooth.waitForExistence(timeout: 5))
        bluetooth.tap()
        XCTAssertTrue(app.staticTexts["Sample session"].firstMatch.waitForExistence(timeout: 8))
        let setBaseline = app.buttons["instrument.set-baseline"]
        let dock = app.buttons["instrument.record"]
        for _ in 0 ..< 10 {
            if setBaseline.exists, setBaseline.isHittable, !dock.exists || setBaseline.frame.maxY < dock.frame.minY - 8 { break }
            app.swipeUp()
        }
        XCTAssertTrue(setBaseline.waitForExistence(timeout: 5))
        setBaseline.tap()
        let name = app.textFields["baseline.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Quiet desk")
        app.buttons["Save"].tap()
        for _ in 0 ..< 4 { app.swipeDown() }
        XCTAssertTrue(app.buttons["instrument.mode.compare"].waitForExistence(timeout: 5))
        app.buttons["instrument.mode.compare"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Change in median")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "manufacture-compare-filled")
        app.buttons["instrument.mode.inspect"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Middle 50%")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "manufacture-info-ruler")
    }
}
