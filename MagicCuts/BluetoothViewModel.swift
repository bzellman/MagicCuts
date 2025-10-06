
import Foundation
import CoreBluetooth
import Combine

// A simple wrapper to make CBPeripheral identifiable and hold its RSSI
struct DiscoveredPeripheral: Identifiable, Equatable {
    let id: UUID
    let peripheral: CBPeripheral
    let rssi: Int
    let serviceUUIDs: [CBUUID]
    var name: String {
        peripheral.name ?? "Unknown Device"
    }
    
    static func == (lhs: DiscoveredPeripheral, rhs: DiscoveredPeripheral) -> Bool {
        // We only need to check stable attributes for equality to limit UI refreshes.
        lhs.id == rhs.id && lhs.rssi == rhs.rssi && lhs.serviceUUIDs == rhs.serviceUUIDs
    }
}

struct BluetoothAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

class BluetoothViewModel: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var discoveredPeripherals: [DiscoveredPeripheral] = []
    @Published var isScanning = false
    @Published var authorizationStatus: CBManagerAuthorization = {
        if #available(iOS 13.0, *) {
            return CBManager.authorization
        } else {
            return .allowedAlways
        }
    }()
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var activeAlert: BluetoothAlert?
    
    private var centralManager: CBCentralManager!
    private var discoveredPeripheralsDict: [UUID: DiscoveredPeripheral] = [:]
    private var pendingUpdates: [UUID: DiscoveredPeripheral] = [:]
    private var updateTimer: Timer?

    override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard authorizationAllowsScanning else {
            presentAlert(
                title: "Bluetooth Access Needed",
                message: "Grant Bluetooth permissions in Settings to scan for devices."
            )
            return
        }
        guard centralManager.state == .poweredOn else {
            presentAlert(
                title: "Turn On Bluetooth",
                message: "Enable Bluetooth to discover nearby devices."
            )
            return
        }
        isScanning = true
        discoveredPeripheralsDict.removeAll()
        pendingUpdates.removeAll()
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        print("Started scanning.")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        updateTimer?.invalidate()
        updateTimer = nil
        isScanning = false
        print("Stopped scanning.")
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if #available(iOS 13.0, *) {
            authorizationStatus = CBManager.authorization
        }
        switch central.state {
        case .poweredOn:
            print("Bluetooth is On")
        case .poweredOff:
            print("Bluetooth is Off")
            isScanning = false
            presentAlert(
                title: "Bluetooth Off",
                message: "Turn Bluetooth on to continue scanning for devices."
            )
        case .unsupported:
            print("Bluetooth is not supported on this device")
            presentAlert(
                title: "Unsupported",
                message: "This device does not support Bluetooth LE scanning."
            )
        case .unauthorized:
            print("Bluetooth is not authorized")
            presentAlert(
                title: "Permission Needed",
                message: "Grant Bluetooth access in Settings to discover devices."
            )
        case .resetting:
            print("Bluetooth is resetting")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            fatalError("A new CBCentralManager.State case has been added")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let rssiInt = RSSI.intValue
        
        guard let name = peripheral.name, !name.isEmpty, rssiInt != 127, rssiInt < 0 else {
            return
        }

        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]) ?? []

        pendingUpdates[peripheral.identifier] = DiscoveredPeripheral(
            id: peripheral.identifier,
            peripheral: peripheral,
            rssi: rssiInt,
            serviceUUIDs: serviceUUIDs
        )
        
        // If a timer isn't already running, start one.
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { [weak self] _ in
                self?.publishUpdates()
            }
        }
    }
    
    private func publishUpdates() {
        // Merge pending updates into the main dictionary
        discoveredPeripheralsDict.merge(pendingUpdates) { (_, new) in new }
        pendingUpdates.removeAll()
        
        // Update the published array
        self.discoveredPeripherals = Array(discoveredPeripheralsDict.values)
        
        updateTimer = nil // Timer has fired, so nil it out.
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
    
    private func presentAlert(title: String, message: String) {
        DispatchQueue.main.async {
            self.activeAlert = BluetoothAlert(title: title, message: message)
        }
    }
}

