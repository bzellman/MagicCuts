//
//  BluetoothScanner.swift
//  MagicCuts
//
//  Async Bluetooth scanner for proximity detection in AppIntents context.
//

import Foundation
import CoreBluetooth

enum BluetoothError: Error {
    case unavailable
    case timeout
}

/// Async Bluetooth scanner that searches for a specific device and checks if its RSSI meets a threshold.
/// This class is intentionally not @MainActor as it runs on a background queue for Bluetooth operations.
final class BluetoothScanner: NSObject, CBCentralManagerDelegate, @unchecked Sendable {
    private var centralManager: CBCentralManager?
    private var continuation: CheckedContinuation<Bool, Error>?
    private var strongestRSSI: Int = -127
    private let targetUUID: UUID
    private let requiredRSSI: Int
    private let serviceFilters: [CBUUID]
    private let queue = DispatchQueue(label: "com.bradzellman.MagicCuts.bt", qos: .userInitiated)
    private let finishLock = NSLock()
    private var hasFinished = false
    private let scanTimeout: TimeInterval

    /// Initialize the scanner with target device parameters.
    /// - Parameters:
    ///   - targetUUID: The UUID of the device to find
    ///   - requiredRSSI: The minimum RSSI value to consider "nearby"
    ///   - serviceFilters: Optional service UUIDs to filter the scan
    ///   - timeout: How long to scan before giving up (default 10 seconds)
    init(targetUUID: UUID, requiredRSSI: Int, serviceFilters: [CBUUID] = [], timeout: TimeInterval = 10) {
        self.targetUUID = targetUUID
        self.requiredRSSI = requiredRSSI
        self.serviceFilters = serviceFilters
        self.scanTimeout = timeout
        super.init()
    }

    /// Perform an async scan for the target device.
    /// - Returns: `true` if the device was found with RSSI >= requiredRSSI, `false` otherwise
    func scan() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            print("📡 [BT] Creating CBCentralManager...")
            self.centralManager = CBCentralManager(
                delegate: self,
                queue: queue,
                options: [CBCentralManagerOptionShowPowerAlertKey: false]
            )

            // Timeout after scanTimeout seconds
            queue.asyncAfter(deadline: .now() + scanTimeout) { [weak self] in
                guard let self = self else { return }
                print("📡 [BT] ⏰ Timeout - finishing scan")
                self.finish()
            }
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("📡 [BT] State: \(central.state.rawValue)")
        print("📡 [BT] Authorization: \(CBManager.authorization.rawValue)")

        switch central.state {
        case .poweredOn:
            let filtersDescription = serviceFilters.map { $0.uuidString }
            print("📡 [BT] ✅ Starting scan for \(targetUUID) with filters: \(filtersDescription)")
            central.scanForPeripherals(
                withServices: serviceFilters.isEmpty ? nil : serviceFilters,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )

        case .poweredOff, .unauthorized, .unsupported:
            print("📡 [BT] ❌ Bluetooth unavailable: \(central.state)")
            continuation?.resume(throwing: BluetoothError.unavailable)
            continuation = nil

        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue

        if peripheral.identifier == targetUUID {
            print("📡 [BT] 🎯 Found target! RSSI: \(rssi)")
            if rssi > strongestRSSI {
                strongestRSSI = rssi
                print("📡 [BT] 📶 New strongest: \(strongestRSSI)")
            }

            // If we've already met the threshold, finish early
            if strongestRSSI >= requiredRSSI {
                print("📡 [BT] 🟢 Threshold met, finishing scan early")
                finish()
            }
        }
    }

    // MARK: - Private

    private func finish() {
        finishLock.lock()
        let shouldFinish = !hasFinished
        if shouldFinish {
            hasFinished = true
        }
        finishLock.unlock()

        guard shouldFinish else { return }

        centralManager?.stopScan()

        let isNearby = strongestRSSI >= requiredRSSI
        print("📡 [BT] Result: \(isNearby) (strongest: \(strongestRSSI), required: \(requiredRSSI))")

        continuation?.resume(returning: isNearby)
        continuation = nil
    }
}
