import XCTest

nonisolated final class RoomFieldworkUITests: XCTestCase {
    @MainActor private func launch(_ extra: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication(); app.terminate()
        app.launchArguments = ["--uitesting", "--pro-demo", "--room-demo", "-showSessionLiveActivity", "NO"] + extra
        app.launch()
        if !app.staticTexts["Sample session"].firstMatch.waitForExistence(timeout: 5) { app.terminate(); app.launch() }
        XCTAssertTrue(app.buttons["instrument.choose"].waitForExistence(timeout: 10)); return app
    }
    @MainActor private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            let scroll = app.scrollViews.firstMatch
            if scroll.exists {
                let above = element.exists && element.frame.midY < scroll.frame.minY + 60
                scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: above ? 0.25 : 0.8))
                    .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: above ? 0.8 : 0.25)))
            } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable, element.debugDescription)
    }
    @MainActor private func screenshot(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot()); image.name = name; image.lifetime = .keepAlways; add(image)
    }
    @MainActor private func selectTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        if tab.exists { tab.tap(); return }
        let symbols = ["Rooms": "square.3.layers.3d", "Sessions": "doc.text", "Instruments": "waveform.path"]
        let topTab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND identifier == %@", title, symbols[title] ?? "")).firstMatch
        XCTAssertTrue(topTab.waitForExistence(timeout: 5)); topTab.tap()
    }
    @MainActor private func openRoom(_ app: XCUIApplication) {
        selectTab("Rooms", in: app)
        let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Studio · sample")).firstMatch
        if !room.waitForExistence(timeout: 2) { reveal(room, app) }
        XCTAssertTrue(room.exists); room.tap()
        XCTAssertTrue(app.buttons["Update room"].waitForExistence(timeout: 10))
    }
    @MainActor private func auditVisible(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion, .sufficientElementDescription, .trait]) { issue in
            if issue.auditType == .contrast, let element = issue.element {
                if !element.isEnabled { return true }
                let tabs = app.tabBars.firstMatch
                let bottom = tabs.exists && tabs.frame.minY > app.frame.midY ? tabs.frame.minY : app.frame.maxY
                let top = app.navigationBars.firstMatch.exists ? app.navigationBars.firstMatch.frame.maxY : app.frame.minY
                if element.frame.minY < top || element.frame.maxY > bottom { return true }
            }
            print("Room accessibility issue: \(issue.compactDescription); \(issue.element?.debugDescription ?? "unknown")")
            return false
        }
    }
    @MainActor private func waitForMesh(_ app: XCUIApplication) {
        let mesh = app.descendants(matching: .any)["room.mesh.scene"].firstMatch
        XCTAssertTrue(mesh.waitForExistence(timeout: 10))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Ready"), object: mesh)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
        let rendered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { Self.hasRenderedMesh(mesh) }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 10), .completed, "The mesh must render visible surfaces, not just finish building entities.")
    }
    @MainActor private static func hasRenderedMesh(_ element: XCUIElement) -> Bool {
        guard let image = element.screenshot().image.cgImage else { return false }
        let side = 40
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let sampled = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard sampled else { return false }
        var surfacePixels = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let red = Int(pixels[i]), green = Int(pixels[i + 1]), blue = Int(pixels[i + 2])
            if blue - red > 15 && green - red > 10 { surfacePixels += 1 }
        }
        return surfacePixels > side * side / 20
    }
    @MainActor func testInsideOutsideAndReversibleHallwayTrim() throws {
        let fixture = UUID().uuidString
        let app = launch(["--room-fixture-id", fixture, "--room-enclosed-demo", "--dark-appearance"])
        openRoom(app); waitForMesh(app)
        screenshot(app, "mesh-enclosed-outside")
        app.segmentedControls.buttons["Inside"].tap()
        XCTAssertTrue(app.buttons["Look up"].waitForExistence(timeout: 5))
        app.buttons["Rotate right"].tap(); app.buttons["Look down"].tap()
        app.buttons["Reset view"].tap()
        screenshot(app, "mesh-enclosed-inside")
        try auditVisible(app)
        app.buttons["Move viewpoint"].tap()
        let position = app.steppers.matching(NSPredicate(format: "label CONTAINS %@", "Left / right")).firstMatch
        reveal(position.buttons["Increment"], app)
        position.buttons["Increment"].tap()
        screenshot(app, "mesh-interior-position")
        app.navigationBars.buttons["Room actions"].tap(); app.buttons["room.trim.menu"].tap()
        let canvas = app.descendants(matching: .any)["room.trim.canvas"].firstMatch
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        // The fixture's hallway sits to the right in the top-down projection. Drag
        // within the identified canvas, as a user would select the unwanted section.
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.675, dy: 0.05))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.95)))
        screenshot(app, "mesh-trim-hallway-selection")
        try auditVisible(app)
        app.buttons["room.trim.preview"].tap()
        XCTAssertTrue(app.buttons["room.trim.save"].waitForExistence(timeout: 20))
        waitForMesh(app); screenshot(app, "mesh-trim-hallway-preview")
        app.buttons["room.trim.adjust"].tap()
        app.buttons["Undo selection"].tap()
        XCTAssertFalse(app.buttons["Undo selection"].isEnabled)
        // Cancel must leave the saved revision alone.
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Room actions"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Room actions"].tap(); app.buttons["room.trim.menu"].tap()
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.675, dy: 0.05))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.95)))
        app.buttons["room.trim.preview"].tap()
        XCTAssertTrue(app.buttons["room.trim.save"].waitForExistence(timeout: 20))
        app.buttons["room.trim.save"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Room actions"].waitForExistence(timeout: 10))
        let count = app.staticTexts["room.mesh.triangles"]
        reveal(count, app)
        let savedCount = count.label
        screenshot(app, "mesh-trim-saved-revision")
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["instrument.choose"].waitForExistence(timeout: 15))
        openRoom(app); reveal(count, app)
        XCTAssertEqual(count.label, savedCount)
        app.navigationBars.buttons["Room actions"].tap(); app.buttons["Export room"].tap()
        app.buttons["room.export.prepare"].tap()
        XCTAssertTrue(app.buttons["room.export.share"].waitForExistence(timeout: 10))
        screenshot(app, "mesh-trim-reopened-export")
    }
    @MainActor func testTrimControlsAtLargestText() throws {
        let app = launch(["--room-fixture-id", UUID().uuidString, "--room-enclosed-demo", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openRoom(app)
        app.buttons["room.mesh.viewpoint"].tap(); app.buttons["Inside"].tap()
        screenshot(app, "mesh-inside-largest-text")
        try auditVisible(app)
        app.navigationBars.buttons["Room actions"].tap(); app.buttons["room.trim.menu"].tap()
        XCTAssertTrue(app.buttons["room.trim.operation"].waitForExistence(timeout: 10))
        app.buttons["room.trim.operation"].tap(); app.buttons["Keep selection"].tap()
        let controls = app.buttons["room.trim.edges"]
        reveal(controls, app); controls.tap()
        let edge = app.steppers.matching(NSPredicate(format: "label CONTAINS %@", "Left edge")).firstMatch
        let increment = edge.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Increment")).firstMatch
        reveal(increment, app); increment.tap()
        app.scrollViews.firstMatch.swipeUp(velocity: .slow)
        screenshot(app, "mesh-trim-largest-text-controls")
        try auditVisible(app)
        app.buttons["room.trim.preview"].tap()
        XCTAssertTrue(app.buttons["room.trim.save"].waitForExistence(timeout: 20))
        screenshot(app, "mesh-trim-largest-text-preview")
    }
    @MainActor func testRoomViewsRevisionComparisonAndArchiveExport() throws {
        let app = launch(); openRoom(app)
        screenshot(app, "room-mesh-light"); try auditVisible(app)
        app.segmentedControls.buttons["Plan"].tap(); screenshot(app, "room-plan-light")
        let dimension = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Desk width")).firstMatch
        reveal(dimension, app); dimension.tap()
        let compare = app.buttons["Compare"].firstMatch; reveal(compare, app); compare.tap()
        let comparison = app.staticTexts["Compare observed coverage"]
        reveal(comparison, app); screenshot(app, "room-revision-comparison")
        app.navigationBars.buttons["Room actions"].tap(); app.buttons["Export room"].tap()
        let prepare = app.buttons["room.export.prepare"]; XCTAssertTrue(prepare.waitForExistence(timeout: 5)); prepare.tap()
        XCTAssertTrue(app.buttons["room.export.share"].waitForExistence(timeout: 10)); screenshot(app, "room-export-archive")
        app.navigationBars.buttons["Done"].tap()
    }
    @MainActor func testManualReadingPositionSurvivesAppRelaunch() throws {
        let id = UUID().uuidString
        let app = launch(["--room-fixture-id", id])
        let capture = app.buttons["Capture this reading"]; reveal(capture, app); capture.tap()
        let title = app.textFields["capture.title"]; XCTAssertTrue(title.waitForExistence(timeout: 5)); title.tap()
        let old = title.value as? String ?? ""
        title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + "Desk position test")
        app.buttons["Place in a room"].tap()
        let place = app.buttons["placement.save"]; XCTAssertTrue(place.waitForExistence(timeout: 5))
        let x = app.textFields["X position (m)"]; reveal(x, app); x.tap()
        x.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (x.value as? String ?? "").count) + "1.25")
        place.tap()
        XCTAssertTrue(app.staticTexts["Placed manually"].waitForExistence(timeout: 5))
        app.buttons["capture.save"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Sessions"].waitForExistence(timeout: 10)); selectTab("Sessions", in: app)
        let saved = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Desk position test")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10)); saved.tap()
        XCTAssertTrue(app.buttons["View location in room"].waitForExistence(timeout: 5))
        screenshot(app, "reading-position-reopened")
        app.buttons["View location in room"].tap()
        XCTAssertTrue(app.buttons["Update room"].waitForExistence(timeout: 5))
        app.segmentedControls.buttons["Plan"].tap(); screenshot(app, "room-with-new-reading")
    }
    @MainActor func testUnavailableCaptureAndNFCLeaveSavedRoomsAvailable() throws {
        #if !targetEnvironment(simulator)
        throw XCTSkip("This test checks simulator unsupported-hardware recovery")
        #else
        let app = launch(); openRoom(app)
        let update = app.buttons["Update room"]; reveal(update, app); update.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "needs a LiDAR-equipped device")).firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "room-unsupported-device")
        app.navigationBars.buttons["Close"].tap()
        XCTAssertTrue(app.buttons["Update room"].exists)
        selectTab("Instruments", in: app); app.buttons["instruments.field-tools"].tap()
        let nfc = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "NFC inspector")).firstMatch
        XCTAssertTrue(nfc.waitForExistence(timeout: 5)); nfc.tap(); app.buttons["nfc.read"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "unavailable")).firstMatch.waitForExistence(timeout: 5))
        screenshot(app, "nfc-unsupported-device")
        app.buttons["Save scan diagnostics"].tap(); app.buttons["capture.save"].tap()
        selectTab("Sessions", in: app)
        let attempt = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "NFC scan attempt")).firstMatch
        XCTAssertTrue(attempt.waitForExistence(timeout: 5)); attempt.tap()
        let diagnostics = app.buttons["Capture diagnostics"]; reveal(diagnostics, app); diagnostics.tap()
        XCTAssertTrue(app.staticTexts["Core NFC reader unavailable"].waitForExistence(timeout: 5))
        #endif
    }
    @MainActor func testPhysicalRoomCaptureAndOfflineReopen() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Requires a physical LiDAR device pointed at visible surfaces")
        #else
        continueAfterFailure = false
        let app = XCUIApplication(); app.terminate()
        app.launchArguments = ["--uitesting", "--room-fixture-id", UUID().uuidString, "-showSessionLiveActivity", "NO"]
        app.launch()
        defer { app.terminate() }
        XCTAssertTrue(app.tabBars.buttons["Rooms"].waitForExistence(timeout: 15)); selectTab("Rooms", in: app)
        app.buttons["rooms.capture"].tap()
        let cameraAlert = app.alerts.firstMatch
        if cameraAlert.waitForExistence(timeout: 3) {
            let allow = cameraAlert.buttons.matching(NSPredicate(format: "label IN %@", ["Allow", "OK"])).firstMatch
            if allow.exists { allow.tap() }
        }
        let finish = app.buttons["Finish scan"]
        XCTAssertTrue(finish.waitForExistence(timeout: 35), "The physical camera must observe enough surfaces to form a mesh")
        screenshot(app, "physical-room-observed-surfaces")
        reveal(finish, app); finish.tap()
        let review = app.buttons["Review and save room"]
        XCTAssertTrue(review.waitForExistence(timeout: 35)); reveal(review, app); review.tap()
        let name = app.textFields["room.name"]; XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: (name.value as? String ?? "").count) + "Physical acceptance room")
        app.buttons["room.save"].tap(); app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["Rooms"].waitForExistence(timeout: 15)); selectTab("Rooms", in: app)
        let room = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Physical acceptance room")).firstMatch
        XCTAssertTrue(room.waitForExistence(timeout: 10)); room.tap()
        XCTAssertTrue(app.buttons["Update room"].waitForExistence(timeout: 10)); screenshot(app, "physical-room-reopened-mesh")
        #endif
    }
    @MainActor func testFieldToolsReadyStatesAndNativeControls() throws {
        let app = launch()
        app.buttons["instruments.field-tools"].tap()
        for title in ["NFC inspector", "Network tests", "Cellular", "LiDAR measurements", "Peer instruments"] {
            let tool = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            reveal(tool, app); tool.tap()
            screenshot(app, "field-tool-" + title); try auditVisible(app)
            app.navigationBars.buttons["Field tools"].tap()
        }
    }
    @MainActor func testRoomDarkAppearance() throws {
        let app = launch(["--dark-appearance"]); openRoom(app)
        screenshot(app, "room-mesh-dark"); try auditVisible(app)
        app.segmentedControls.buttons["Plan"].tap(); screenshot(app, "room-plan-dark")
    }
    @MainActor func testLargestRoomTextAndNativeControls() throws {
        let app = launch(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        openRoom(app); screenshot(app, "room-largest-text")
        try auditVisible(app)
        app.buttons["room.display"].tap(); app.buttons["Measurements"].tap()
        screenshot(app, "room-measurements-largest-text")
        app.swipeUp(); try auditVisible(app)
    }
}
