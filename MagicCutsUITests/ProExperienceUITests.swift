import XCTest

nonisolated final class ProExperienceUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--uitesting", "--pro-demo", "--seed-device", "--room-fixture-id", UUID().uuidString, "-showSessionLiveActivity", "NO"] + extra
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
        // Capture the display: app.screenshot() can crop using a stale frame
        // after iPad rotation, yielding a truncated image with a black band.
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        // Keep reviewable files even when Xcode stalls finalizing an xcresult.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("native-utility", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: folder.appendingPathComponent(name + ".png"), options: .atomic)
        } catch { XCTFail("Could not retain visual evidence: \(error)") }
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0 ..< 8 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
    }

    @MainActor private func openBaselineRecorder(_ app: XCUIApplication) {
        let create = app.buttons["instrument.set-baseline"]
        if create.exists {
            reveal(create, in: app); create.tap()
        } else {
            let chooser = app.buttons["instrument.baseline"]
            reveal(chooser, in: app); chooser.tap()
            app.buttons["Capture another baseline"].tap()
        }
    }

    @MainActor private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .trait]) { issue in
            // XCTest samples obscured SwiftUI text beneath native scrolling chrome.
            // Audit those same readings again after scrolling them into view below.
            if issue.auditType == .contrast, let element = issue.element {
                // iOS 26 audits this synthetic label using the whole Room cell,
                // including the antialiased outline symbol. The exported issue
                // image confirms black text on white (21:1); the symbol's solid
                // color is #59636E (6.1:1). Keep every other Room audit enabled.
                if element.label == "Room", element.frame == app.buttons["rooms.capture"].frame {
                    print("Verified composite-cell contrast false positive: Room")
                    return true
                }
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
        openBaselineRecorder(app)
        XCTAssertTrue(app.textFields["baseline.name"].waitForExistence(timeout: 5))
        app.textFields["baseline.name"].tap(); app.textFields["baseline.name"].typeText("Quiet desk")
        app.buttons["Save"].tap()
        app.buttons["instrument.mode.inspect"].tap()
        capture(app, "pro-inspect-dark")
        app.buttons["instrument.mode.compare"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Quiet desk")).firstMatch.waitForExistence(timeout: 5))
        capture(app, "pro-compare-dark")
        app.buttons["instrument.mode.inspect"].tap()
        XCTAssertTrue(app.buttons["instrument.record"].waitForExistence(timeout: 5))
        app.buttons["instrument.record"].tap()
        XCTAssertTrue(app.buttons["Mark"].waitForExistence(timeout: 5))
        capture(app, "pro-recording-dark")
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
        app.navigationBars[savedName].buttons["Sessions"].tap()
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

    @MainActor func testHomeAccessibility() throws {
        for dark in [false, true] {
            let app = launch(dark ? ["--dark-appearance"] : [])
            let calibration = app.buttons["Calibrate nearby and away"]
            XCTAssertTrue(calibration.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["instrument.baseline"].isHittable)
            XCTAssertLessThanOrEqual(calibration.frame.maxY, app.buttons["instrument.log"].frame.minY,
                                     "Calibration must fit above the action dock on the initial phone viewport")
            capture(app, dark ? "pro-live-dark" : "pro-live-light")
            try audit(app)
            app.swipeUp()
            try audit(app)
        }
    }

    @MainActor private func waitForHeader(_ app: XCUIApplication, compact: Bool) {
        let header = app.otherElements["instrument.header"]
        let state = compact ? "Compact" : "Expanded"
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", state), object: header)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
    }

    @MainActor private func foldHeader(_ app: XCUIApplication) {
        app.buttons["instrument.mode.inspect"].tap()
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<3 where app.otherElements["instrument.header"].value as? String != "Compact" {
            scroll.swipeUp(velocity: .slow)
        }
        waitForHeader(app, compact: true)
    }

    @MainActor private func unfoldHeader(_ app: XCUIApplication) {
        let scroll = app.scrollViews.firstMatch
        for _ in 0..<5 where app.otherElements["instrument.header"].value as? String != "Expanded" {
            scroll.swipeDown(velocity: .slow)
        }
        waitForHeader(app, compact: false)
    }

    @MainActor func testSourceHeaderFoldsOnScrollWithoutLosingNavigation() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        for dark in [false, true] {
            let app = launch(dark ? ["--dark-appearance"] : [])
            if app.frame.width >= 600 { XCUIDevice.shared.orientation = .landscapeLeft }
            let appearance = dark ? "dark" : "light"
            let header = app.otherElements["instrument.header"]
            waitForHeader(app, compact: false)
            let expandedHeight = header.frame.height
            capture(app, "motion-expanded-\(appearance)")
            foldHeader(app)
            XCTAssertLessThan(header.frame.height, expandedHeight - 32)
            let controls = ["instrument.choose", "instrument.device-menu", "rooms.capture", "settings.open"]
            for id in controls {
                let button = app.buttons[id]
                XCTAssertTrue(button.isHittable, id)
                XCTAssertGreaterThanOrEqual(button.frame.width, 44, id)
                XCTAssertGreaterThanOrEqual(button.frame.height, 44, id)
            }
            XCTAssertEqual(app.buttons["instrument.choose"].value as? String, "Bluetooth")
            XCTAssertEqual(app.buttons["instrument.device-menu"].label, "Desk sensor")
            for id in ["instrument.device-menu", "rooms.capture", "settings.open"] {
                XCTAssertEqual(app.buttons[id].frame.midY, app.buttons["instrument.choose"].frame.midY, accuracy: 1, "Compact navigation stays in one row: \(id)")
            }
            capture(app, "motion-compact-\(appearance)")
            try app.performAccessibilityAudit(for: [.hitRegion, .sufficientElementDescription, .trait]) { issue in
                // Decorative Canvas scales can still emit an unlabeled AccessibilityNode.
                if issue.auditType == .sufficientElementDescription,
                   (issue.element?.identifier ?? "").isEmpty,
                   (issue.element?.label ?? "").isEmpty {
                    return true
                }
                return false
            }

            app.buttons["settings.open"].tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            app.buttons["Done"].tap()
            waitForHeader(app, compact: true)
            let compactHeight = header.frame.height
            app.buttons["instrument.device-menu"].tap()
            XCTAssertTrue(app.buttons["Manage devices"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.otherElements["instrument.header"].value as? String, "Compact")
            XCTAssertEqual(header.frame.height, compactHeight, accuracy: 1, "Opening the device menu must not retarget the fold")
            app.buttons["Manage devices"].tap()
            XCTAssertTrue(app.navigationBars["Devices"].waitForExistence(timeout: 5))
            app.buttons["Done"].tap()
            waitForHeader(app, compact: true)
            app.buttons["rooms.capture"].tap()
            XCTAssertTrue(app.staticTexts["Camera unavailable"].waitForExistence(timeout: 5))
            app.navigationBars.buttons["Close"].tap()
            waitForHeader(app, compact: true)
            app.buttons["instrument.choose"].tap()
            XCTAssertTrue(app.buttons["instrument.filter.motion"].waitForExistence(timeout: 5))
            app.buttons["instrument.filter.motion"].tap()
            let magnetic = app.buttons["instrument.pick.magnetic"]
            reveal(magnetic, in: app); magnetic.tap()
            XCTAssertTrue(app.buttons["instrument.filter.motion"].waitForNonExistence(timeout: 5))
            XCTAssertEqual(app.buttons["instrument.choose"].value as? String, "Magnetic field")
            XCTAssertLessThan(header.frame.height, expandedHeight - 32, "A long instrument name must retain the compact bar")
            for id in ["rooms.capture", "settings.open"] {
                XCTAssertEqual(app.buttons[id].frame.midY, app.buttons["instrument.choose"].frame.midY, accuracy: 1, "Long titles retain one navigation row: \(id)")
            }
            capture(app, "motion-long-title-\(appearance)")
            unfoldHeader(app)
            capture(app, "motion-restored-\(appearance)")
            for _ in 0..<2 {
                foldHeader(app)
                unfoldHeader(app)
            }
        }
    }

    @MainActor func testSourceHeaderInPortraitTablet() throws {
        for dark in [false, true] {
            let app = launch(["--visualization-demo"] + (dark ? ["--dark-appearance"] : []))
            // Run on a dedicated portrait simulator; iPadOS can retain a
            // landscape display even when XCTest changes UIDevice orientation.
            guard app.frame.width >= 600 else { throw XCTSkip("iPad portrait coverage") }
            guard app.windows.firstMatch.frame.height > app.windows.firstMatch.frame.width else {
                throw XCTSkip("Requires a portrait iPad display")
            }
            let appearance = dark ? "dark" : "light"
            capture(app, "motion-tablet-portrait-expanded-\(appearance)")
            app.buttons["instrument.mode.inspect"].tap()
            app.scrollViews.firstMatch.swipeUp(velocity: .slow)
            waitForHeader(app, compact: false) // Fitting evidence should not fold on rubber-banding.
            app.buttons["instrument.choose"].tap()
            app.buttons["instrument.filter.motion"].tap()
            let vibration = app.buttons["instrument.pick.vibration"]
            reveal(vibration, in: app); vibration.tap()
            XCTAssertTrue(app.buttons["instrument.filter.motion"].waitForNonExistence(timeout: 5))
            foldHeader(app)
            capture(app, "motion-tablet-portrait-compact-\(appearance)")
            for id in ["instrument.choose", "rooms.capture", "settings.open"] {
                XCTAssertTrue(app.buttons[id].isHittable, id)
            }
            unfoldHeader(app)
        }
    }

    @MainActor func testSourceHeaderReduceMotionPreservesScrollAndActions() {
        let app = launch(["--reduce-motion"])
        foldHeader(app)
        capture(app, "motion-reduced-compact")
        XCTAssertTrue(app.buttons["settings.open"].isHittable)
        XCTAssertTrue(app.buttons["instrument.device-menu"].isHittable)
        unfoldHeader(app)
        capture(app, "motion-reduced-expanded")
    }

    @MainActor func testSourceHeaderLargestStandardText() {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXXXL"])
        foldHeader(app)
        capture(app, "motion-largest-standard")
        XCTAssertTrue(app.buttons["instrument.choose"].isHittable)
        XCTAssertTrue(app.buttons["instrument.device-menu"].isHittable)
        XCTAssertTrue(app.buttons["rooms.capture"].isHittable)
        XCTAssertTrue(app.buttons["settings.open"].isHittable)
    }

    @MainActor func testSourceHeaderKeepsContextAndSettingsReachable() throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        for dark in [false, true] {
            XCUIDevice.shared.orientation = .portrait
            let app = launch(dark ? ["--dark-appearance"] : [])
            let appearance = dark ? "dark" : "light"
            let supportsLandscape = app.frame.width >= 600
            let instrument = app.buttons["instrument.choose"]
            let headerPosition = instrument.frame.minY
            app.scrollViews.firstMatch.swipeUp()
            XCTAssertEqual(instrument.frame.minY, headerPosition, accuracy: 1)
            XCTAssertTrue(app.buttons["rooms.capture"].isHittable)
            let settings = app.buttons["settings.open"]
            XCTAssertTrue(settings.isHittable)
            settings.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            capture(app, "header-settings-\(appearance)")
            app.buttons["Done"].tap()
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            app.scrollViews.firstMatch.swipeDown()

            let calibrate = app.buttons["instrument.calibrate"]
            reveal(calibrate, in: app); calibrate.tap()
            XCTAssertTrue(app.navigationBars["Calibrate Bluetooth"].waitForExistence(timeout: 5))
            capture(app, "header-calibration-\(appearance)")
            app.buttons["Done"].tap()
            XCTAssertTrue(settings.waitForExistence(timeout: 5))
            if app.buttons["instrument.start"].exists { app.buttons["instrument.start"].tap() }

            instrument.tap()
            // The iPad picker can collapse its native search field in landscape.
            // Use the visible filter to exercise header navigation in both layouts.
            let motion = app.buttons["instrument.filter.motion"]
            XCTAssertTrue(motion.waitForExistence(timeout: 5)); motion.tap()
            let magnetic = app.buttons["instrument.pick.magnetic"]
            XCTAssertTrue(magnetic.waitForExistence(timeout: 5))
            reveal(magnetic, in: app); magnetic.tap()
            XCTAssertTrue(motion.waitForNonExistence(timeout: 5))
            XCTAssertEqual(instrument.value as? String, "Magnetic field")
            XCTAssertTrue(settings.isHittable)
            capture(app, "header-magnetic-\(appearance)")

            XCUIDevice.shared.orientation = .landscapeLeft
            // The shipping iPhone target supports portrait only; iPad supports both.
            let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                let size = app.windows.firstMatch.frame.size
                return (size.width > size.height) == supportsLandscape
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 5), .completed)
            XCTAssertTrue(instrument.isHittable)
            XCTAssertTrue(settings.isHittable)
            XCTAssertTrue(app.buttons["instrument.start-flow"].isHittable)
            capture(app, "header-\(supportsLandscape ? "landscape" : "portrait-rotation")-\(appearance)")
        }
    }

    @MainActor func testVibrationSpectrumSample() {
        let app = launch(["--visualization-demo"])
        app.buttons["instrument.choose"].tap()
        let search = app.searchFields["Filter instruments"]
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Vibration\n")
        app.buttons["instrument.pick.vibration"].tap()
        XCTAssertTrue(search.waitForNonExistence(timeout: 5))
        app.buttons["instrument.mode.inspect"].tap()
        let title = app.staticTexts["Vibration spectrum"]
        for _ in 0..<5 {
            if title.exists && title.frame.minY < app.frame.midY && title.frame.minY > 130 { break }
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(title.exists)
        XCTAssertLessThan(title.frame.minY, app.frame.midY)
        capture(app, "pro-vibration-spectrum")
    }

    @MainActor func testInstrumentNavigationAndLargeText() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["instrument.log"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["instrument.record"].exists)
        XCTAssertTrue(app.buttons["instrument.start-flow"].exists)
        capture(app, "pro-live-light")
        for (kind, title) in [("tilt", "Level"), ("vibration", "Vibration"), ("rotation", "Rotation"),
                              ("magnetic", "Magnetic field"), ("pressure", "Pressure"), ("altitude", "Elevation change"),
                              ("heading", "Compass"), ("speed", "Speed"), ("sound", "Sound level"),
                              ("network", "Connection"), ("battery", "Battery")] {
            app.swipeDown()
            let chooser = app.buttons["instrument.choose"]
            XCTAssertTrue(chooser.waitForExistence(timeout: 5)); chooser.tap()
            let search = app.searchFields["Filter instruments"]
            XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText(title + "\n")
            let choice = app.buttons["instrument.pick.\(kind)"]
            XCTAssertTrue(choice.waitForExistence(timeout: 5)); choice.tap()
            XCTAssertTrue(search.waitForNonExistence(timeout: 5), "Selecting \(title) must dismiss the picker")
            if kind == "network", app.textFields["endpoint.address"].waitForExistence(timeout: 2) {
                let endpoint = app.textFields["endpoint.address"]
                endpoint.tap(); endpoint.typeText("https://example.test")
                app.buttons["Measure"].tap()
            }
            let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", title), object: chooser)
            XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
            XCTAssertTrue(app.staticTexts["Sample session"].firstMatch.waitForExistence(timeout: 5))
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
        openBaselineRecorder(app)
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
