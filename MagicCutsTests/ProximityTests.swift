import XCTest
import SwiftData
@testable import MagicCuts

nonisolated final class ProximityTests: XCTestCase {
    @MainActor private func evidence(_ values: [Int], position: TestPosition = .nearby, draft: Bool = false, failure: String? = nil) -> TestEvidence {
        TestEvidence(startedAt: .now, endedAt: .now, threshold: -70, position: position, isDraft: draft, samples: values.map { SignalSample(date: .now, rssi: $0) }, failure: failure)
    }
    @MainActor func testClassificationAndBoundary() {
        XCTAssertEqual(evidence([]).classification, .notObserved)
        XCTAssertEqual(evidence([-60]).classification, .sparse)
        XCTAssertEqual(evidence([-70, -65]).classification, .above)
        XCTAssertEqual(evidence([-71, -80]).classification, .below)
        XCTAssertEqual(evidence([-71, -70]).classification, .mixed)
        XCTAssertTrue(evidence([-70, -70]).validated)
        XCTAssertTrue(evidence([-71, -80], position: .away).validated)
        XCTAssertFalse(evidence([-60, -65], draft: true).validated)
        XCTAssertFalse(evidence([-60, -65], failure: "Radio failed").validated)
        XCTAssertFalse(evidence([], position: .away).validated)
        XCTAssertFalse(SignalSample.isValid(127))
        XCTAssertFalse(SignalSample.isValid(0))
        XCTAssertFalse(SignalSample.isValid(-127))
        XCTAssertTrue(SignalSample.isValid(-126))
    }
    @MainActor func testFullWindowFiltersInvalidAndOtherDevices() async throws {
        let radio = ScriptRadio()
        let task = Task { try await ProximitySampler(radio: radio).collect(id: DemoRadio.deviceID, services: [], duration: .milliseconds(100)) }
        await Task.yield()
        radio.send(-50) // ignored before readiness
        radio.ready()
        radio.send(127); radio.send(0); radio.send(-70); radio.send(-65)
        radio.send(-30, id: UUID())
        try await Task.sleep(for: .milliseconds(20))
        XCTAssertFalse(radio.stopped)
        let samples = try await task.value
        XCTAssertEqual(samples.map(\.rssi), [-70, -65])
        XCTAssertTrue(radio.stopped)
    }
    @MainActor func testCancellationDiscardsRunAndStopsSession() async throws {
        let radio = ScriptRadio()
        let task = Task { try await ProximitySampler(radio: radio).collect(id: DemoRadio.deviceID, services: [], duration: .seconds(10)) }
        await Task.yield(); radio.ready(); radio.send(-65); task.cancel()
        do { _ = try await task.value; XCTFail("Cancellation must throw") } catch is CancellationError {} catch { XCTFail("\(error)") }
        XCTAssertTrue(radio.stopped)
    }
    @MainActor func testOldSessionCleanupCannotStopReplacement() async throws {
        let radio = DemoRadio()
        let old = radio.session(services: [])
        let replacement = radio.session(services: [])
        old.cancel()
        var iterator = replacement.events.makeAsyncIterator()
        guard case .ready = try await iterator.next() else { return XCTFail("Replacement was stopped by old cleanup") }
        replacement.cancel()
    }
    @MainActor func testPrematureEndThrows() async {
        let radio = ScriptRadio()
        let task = Task { try await ProximitySampler(radio: radio).collect(id: DemoRadio.deviceID, services: []) }
        await Task.yield(); radio.continuation?.finish()
        do { _ = try await task.value; XCTFail("Incomplete window must not succeed") } catch { XCTAssertEqual(error as? BluetoothError, .unavailable) }
    }
    @MainActor func testCorruptServiceFilterFailsBeforeRadioStarts() async {
        XCTAssertTrue(ServiceIdentifier.isValid("180F"))
        XCTAssertTrue(ServiceIdentifier.isValid("12345678"))
        XCTAssertTrue(ServiceIdentifier.isValid(UUID().uuidString))
        XCTAssertFalse(ServiceIdentifier.isValid("not-a-service"))
        let session = BluetoothRadio().session(services: ["not-a-service"])
        do {
            for try await _ in session.events { XCTFail("Invalid filter must not emit events") }
            XCTFail("Invalid filter must throw")
        } catch { XCTAssertEqual(error as? BluetoothError, .storage) }
    }

    @MainActor func testCancelledBeforeStartDoesNotOpenSession() async {
        let radio = ScriptRadio()
        let task = Task { try await ProximitySampler(radio: radio).collect(id: DemoRadio.deviceID, services: []) }
        task.cancel()
        do { _ = try await task.value; XCTFail("Expected cancellation") } catch is CancellationError {} catch { XCTFail("\(error)") }
        XCTAssertNil(radio.continuation)
    }

    @MainActor func testDiscoveryStopDoesNotStopReplacementSession() async throws {
        let radio = DemoRadio()
        let discovery = BluetoothViewModel(radio: radio)
        discovery.startScanning()
        await Task.yield()
        let replacement = radio.session(services: [])
        discovery.stopScanning()
        var iterator = replacement.events.makeAsyncIterator()
        guard case .ready = try await iterator.next() else { return XCTFail("Old discovery stopped its replacement") }
        replacement.cancel()
    }

    @MainActor func testDeletedDeviceCannotReceiveLateHistory() throws {
        let store = try ModelContainer(for: MonitoredDevice.self, TestRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = store.mainContext
        let repository = DeviceRepository(context: context, shared: SharedDeviceStorage(defaults: UserDefaults(suiteName: "MagicCutsTests.\(UUID())")), refreshShortcuts: {})
        try repository.save(nil, id: DemoRadio.deviceID, name: "Old", threshold: -70, services: [])
        let oldDevice = try XCTUnwrap(context.fetch(FetchDescriptor<MonitoredDevice>()).first)
        let inFlightIdentity = TestDeviceIdentity(oldDevice)
        let oldConfirmation = oldDevice.confirmationKey
        try repository.delete(oldDevice)
        XCTAssertThrowsError(try repository.record(evidence([-65, -66]), identity: inFlightIdentity)) { error in
            XCTAssertEqual(error as? BluetoothError, .deletedDevice)
        }
        try repository.save(nil, id: DemoRadio.deviceID, name: "Readded", threshold: -70, services: [])
        let readded = try XCTUnwrap(context.fetch(FetchDescriptor<MonitoredDevice>()).first)
        XCTAssertNotEqual(readded.confirmationKey, oldConfirmation)
        XCTAssertThrowsError(try repository.record(evidence([-65, -66]), identity: inFlightIdentity))
        XCTAssertTrue(try context.fetch(FetchDescriptor<TestRecord>()).isEmpty)
    }

    @MainActor func testSnapshotReplacementAndLegacyDecoding() throws {
        let defaults = UserDefaults(suiteName: "MagicCutsTests.\(UUID())")!
        let storage = SharedDeviceStorage(defaults: defaults)
        defaults.set(Data("[{\"id\":\"old\",\"name\":\"Old device\",\"requiredSignalStrength\":-70}]".utf8), forKey: "monitored_devices")
        XCTAssertEqual(try storage.getAllDevices().first?.serviceUUIDs, [])
        try storage.replace([DeviceInfo(id: "new", name: "New", rssi: -65)])
        XCTAssertNil(try storage.getDevice(id: "old"))
        XCTAssertEqual(try storage.getDevice(id: "new")?.requiredSignalStrength, -65)
        defaults.set(Data("broken".utf8), forKey: "monitored_devices")
        XCTAssertThrowsError(try storage.getAllDevices())
        XCTAssertThrowsError(try SharedDeviceStorage(defaults: nil).replace([]))
    }
    @MainActor func testPersistenceHistoryAndSyncFailure() throws {
        let store = try ModelContainer(for: MonitoredDevice.self, TestRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = store.mainContext
        let shared = SharedDeviceStorage(defaults: UserDefaults(suiteName: "MagicCutsTests.\(UUID())"))
        let repo = DeviceRepository(context: context, shared: shared, refreshShortcuts: {})
        XCTAssertThrowsError(try repo.save(nil, id: DemoRadio.deviceID, name: "Sensor", threshold: 0, services: []))
        XCTAssertTrue(try context.fetch(FetchDescriptor<MonitoredDevice>()).isEmpty)
        try repo.save(nil, id: DemoRadio.deviceID, name: " Sensor ", threshold: -70, services: ["180F"])
        let device = try XCTUnwrap(context.fetch(FetchDescriptor<MonitoredDevice>()).first)
        try repo.record(evidence([-65, -66]), device: device)
        try repo.record(evidence([-60, -65], draft: true), device: device)
        try repo.save(device, id: DemoRadio.deviceID, name: "Renamed", threshold: -60, services: [])
        let records = try context.fetch(FetchDescriptor<TestRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.allSatisfy { $0.evidence?.threshold == -70 && $0.deviceName == "Sensor" })
        XCTAssertEqual(try shared.getDevice(id: DemoRadio.deviceID.uuidString)?.name, "Renamed")
        let broken = DeviceRepository(context: context, shared: SharedDeviceStorage(defaults: nil), refreshShortcuts: {})
        XCTAssertThrowsError(try broken.save(device, id: DemoRadio.deviceID, name: "Committed", threshold: -60, services: []))
        XCTAssertEqual(device.name, "Committed", "Snapshot failure must not undo committed data")
        try repo.reconcile()
        XCTAssertEqual(try shared.getDevice(id: DemoRadio.deviceID.uuidString)?.name, "Committed")
        try repo.delete(device)
        XCTAssertTrue(try context.fetch(FetchDescriptor<TestRecord>()).isEmpty)
        XCTAssertTrue(try shared.getAllDevices().isEmpty)
    }
    @MainActor func testAdditiveStoreMigrationRetainsIdentifier() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("legacy.store")
        @MainActor func createLegacy() throws {
            let old = try ModelContainer(for: Legacy.MonitoredDevice.self, configurations: ModelConfiguration(url: url))
            old.mainContext.insert(Legacy.MonitoredDevice(persistentIdentifier: DemoRadio.deviceID, name: "Existing", requiredSignalStrength: -72))
            try old.mainContext.save()
        }
        try createLegacy()
        let migrated = try ModelContainer(for: MonitoredDevice.self, TestRecord.self, configurations: ModelConfiguration(url: url))
        let device = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<MonitoredDevice>()).first)
        XCTAssertEqual(device.uuid, DemoRadio.deviceID)
        XCTAssertEqual(device.requiredSignalStrength, -72)
        XCTAssertTrue(try migrated.mainContext.fetch(FetchDescriptor<TestRecord>()).isEmpty)
    }
    @MainActor func testIntentUsesLatestThresholdAndPropagatesFailures() async throws {
        let storage = SharedDeviceStorage(defaults: UserDefaults(suiteName: "MagicCutsTests.\(UUID())"))
        try storage.replace([DeviceInfo(id: DemoRadio.deviceID.uuidString, name: "Sensor", rssi: -70)])
        let radio = DemoRadio(); radio.readings = [-70]
        let pass = try await IsDeviceNearbyIntent.check(id: DemoRadio.deviceID, storage: storage, radio: radio, duration: .milliseconds(20))
        XCTAssertTrue(pass, "Intent retains any-sample boundary semantics")
        try storage.replace([DeviceInfo(id: DemoRadio.deviceID.uuidString, name: "Sensor", rssi: -60)])
        let fail = try await IsDeviceNearbyIntent.check(id: DemoRadio.deviceID, storage: storage, radio: radio, duration: .milliseconds(20))
        XCTAssertFalse(fail)
        for error in [BluetoothError.denied, .poweredOff, .initialization, .resetting, .unsupported] {
            radio.failure = error
            do { _ = try await IsDeviceNearbyIntent.check(id: DemoRadio.deviceID, storage: storage, radio: radio); XCTFail("Must throw") }
            catch let caught { XCTAssertEqual(caught as? BluetoothError, error) }
        }
        try storage.replace([DeviceInfo(id: DemoRadio.deviceID.uuidString, name: "Legacy", rssi: 0)])
        do { _ = try await IsDeviceNearbyIntent.check(id: DemoRadio.deviceID, storage: storage, radio: radio); XCTFail("Legacy zero must require repair") }
        catch { XCTAssertEqual(error as? BluetoothError, .invalidThreshold) }
        try storage.replace([])
        do { _ = try await IsDeviceNearbyIntent.check(id: DemoRadio.deviceID, storage: storage, radio: radio); XCTFail("Deleted must throw") }
        catch { XCTAssertEqual(error as? BluetoothError, .deletedDevice) }
    }
}

@MainActor
private final class ScriptRadio: RadioScanning {
    var continuation: AsyncThrowingStream<RadioEvent, Error>.Continuation?
    var stopped = false
    func session(services: [String]) -> RadioSession {
        stopped = false
        let stream = AsyncThrowingStream<RadioEvent, Error> { continuation = $0 }
        return RadioSession(events: stream, cancel: { self.stop() })
    }
    func ready() { continuation?.yield(.ready(.now)) }
    func send(_ value: Int, id: UUID? = nil) { continuation?.yield(.device(RadioDevice(id: id ?? DemoRadio.deviceID, name: "", rssi: value, services: [], lastSeen: .now))) }
    func stop() { stopped = true; continuation?.finish(throwing: CancellationError()) }
}

private enum Legacy {
    @Model final class MonitoredDevice {
        @Attribute(.unique) var persistentIdentifier: String
        var name: String
        var requiredSignalStrength: Int
        var serviceUUIDs: [String]
        init(persistentIdentifier: UUID, name: String, requiredSignalStrength: Int) {
            self.persistentIdentifier = persistentIdentifier.uuidString
            self.name = name
            self.requiredSignalStrength = requiredSignalStrength
            self.serviceUUIDs = []
        }
    }
}
