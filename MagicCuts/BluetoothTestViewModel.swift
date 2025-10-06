import Foundation
import CoreBluetooth
import Combine

final class BluetoothTestViewModel: NSObject, ObservableObject, CBCentralManagerDelegate {
    @Published var isTesting = false
    @Published var lastResult: Bool?
    @Published var strongestRSSI: Int?
    @Published var activeAlert: BluetoothAlert?

    private var centralManager: CBCentralManager?
    private var targetUUID: UUID?
    private var requiredRSSI: Int = -70
    private var serviceFilters: [CBUUID] = []
    private let queue = DispatchQueue(label: "com.bradzellman.MagicCuts.bt-test", qos: .userInitiated)
    private var timeoutWorkItem: DispatchWorkItem?
    private var strongestInternalRSSI: Int = -127

    func testDevice(id: UUID, requiredRSSI: Int, serviceUUIDs: [String]) {
        guard !isTesting else { return }

        guard authorizationAllowsScanning else {
            presentAlert(
                title: "Bluetooth Access Needed",
                message: "Grant Bluetooth permissions in Settings to run a proximity test."
            )
            return
        }

        DispatchQueue.main.async {
            self.isTesting = true
            self.lastResult = nil
            self.strongestRSSI = nil
        }

        targetUUID = id
        self.requiredRSSI = requiredRSSI
        serviceFilters = serviceUUIDs.compactMap { CBUUID(string: $0) }
        strongestInternalRSSI = -127

        centralManager = CBCentralManager(delegate: self, queue: queue, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    func cancelTest() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        centralManager?.stopScan()
        centralManager = nil

        DispatchQueue.main.async {
            self.isTesting = false
            self.lastResult = nil
            self.strongestRSSI = nil
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            guard let targetUUID else {
                finishTest(forceResult: nil)
                return
            }
            let filterDescription = serviceFilters.map { $0.uuidString }
            print("📡 [Test] Starting scan for \(targetUUID) with filters: \(filterDescription)")
            central.scanForPeripherals(
                withServices: serviceFilters.isEmpty ? nil : serviceFilters,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )

            let workItem = DispatchWorkItem { [weak self] in
                guard let self else { return }
                print("📡 [Test] Timeout elapsed")
                self.finishTest(forceResult: nil)
            }
            timeoutWorkItem?.cancel()
            timeoutWorkItem = workItem
            queue.asyncAfter(deadline: .now() + 8, execute: workItem)

        case .poweredOff:
            presentAlert(
                title: "Bluetooth Off",
                message: "Turn Bluetooth on to run the test."
            )
            finishTest(forceResult: nil, recordOutcome: false)

        case .unauthorized:
            presentAlert(
                title: "Permission Needed",
                message: "Grant Bluetooth access in Settings to run the test."
            )
            finishTest(forceResult: nil, recordOutcome: false)

        case .unsupported:
            presentAlert(
                title: "Unsupported",
                message: "This device does not support Bluetooth LE testing."
            )
            finishTest(forceResult: nil, recordOutcome: false)

        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard let targetUUID else { return }

        let rssiValue = RSSI.intValue
        if peripheral.identifier == targetUUID {
            if rssiValue > strongestInternalRSSI {
                strongestInternalRSSI = rssiValue
                DispatchQueue.main.async {
                    self.strongestRSSI = rssiValue
                }
            }

            if strongestInternalRSSI >= requiredRSSI {
                print("📡 [Test] Threshold met (\(strongestInternalRSSI) >= \(requiredRSSI))")
                finishTest(forceResult: true)
            }
        }
    }

    // MARK: - Helpers

    private var authorizationAllowsScanning: Bool {
        guard #available(iOS 13.0, *) else { return true }
        switch CBManager.authorization {
        case .restricted, .denied:
            return false
        default:
            return true
        }
    }

    private func finalizeResult() -> Bool {
        strongestInternalRSSI >= requiredRSSI
    }

    private func finishTest(forceResult: Bool?, recordOutcome: Bool = true) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        centralManager?.stopScan()
        centralManager = nil

        let resolvedResult = forceResult ?? finalizeResult()
        let strongest = strongestInternalRSSI == -127 ? nil : strongestInternalRSSI

        DispatchQueue.main.async {
            self.isTesting = false
            if recordOutcome {
                self.lastResult = resolvedResult
                self.strongestRSSI = strongest
            } else {
                self.lastResult = nil
                self.strongestRSSI = nil
            }
        }
    }

    private func presentAlert(title: String, message: String) {
        DispatchQueue.main.async {
            self.activeAlert = BluetoothAlert(title: title, message: message)
        }
    }
}
