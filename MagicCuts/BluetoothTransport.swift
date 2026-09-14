import CoreBluetooth
import Foundation

/// The narrow hardware boundary for exercising real session cleanup without constructing CBPeripheral test doubles.
@MainActor
protocol BluetoothTransport: AnyObject {
    var onEvent: (@MainActor (BluetoothTransportEvent) -> Void)? { get set }
    var authorizationPending: Bool { get }
    func start()
    func scan(services: [String])
    func connect(id: UUID, services: [String])
    func readRSSI()
    func disconnect()
    func stop()
}

enum BluetoothTransportEvent {
    case ready, failure(BluetoothError), device(RadioDevice)
    case connected, connectionEnded, rssi(Int?)
}

/// A fresh transport belongs to each session. CoreBluetooth delivers delegates on the main queue.
@MainActor
final class CoreBluetoothTransport: NSObject, BluetoothTransport, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onEvent: (@MainActor (BluetoothTransportEvent) -> Void)?
    var authorizationPending: Bool { CBManager.authorization == .notDetermined }
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?

    func start() {
        central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func scan(services: [String]) {
        guard let central, central.state == .poweredOn else { return }
        if central.isScanning { central.stopScan() }
        central.scanForPeripherals(withServices: services.isEmpty ? nil : services.map(CBUUID.init(string:)), options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func connect(id: UUID, services: [String]) {
        guard let central, central.state == .poweredOn else { return }
        let known = central.retrievePeripherals(withIdentifiers: [id]).first { $0.identifier == id }
        let match = known ?? (services.isEmpty ? nil : central.retrieveConnectedPeripherals(withServices: services.map(CBUUID.init(string:))).first { $0.identifier == id })
        guard let match else { onEvent?(.connectionEnded); return }
        peripheral = match
        match.delegate = self
        // Even a peripheral connected by another app needs a local connection before readRSSI.
        central.connect(match, options: nil)
    }

    func readRSSI() {
        guard central?.state == .poweredOn, let peripheral, peripheral.state == .connected else { return }
        peripheral.readRSSI()
    }

    func disconnect() {
        guard let peripheral else { return }
        self.peripheral = nil
        peripheral.delegate = nil
        // Cancellation is nonblocking. Clear ownership first so queued callbacks cannot restart polling.
        if let central, central.state == .poweredOn, peripheral.state == .connecting || peripheral.state == .connected {
            central.cancelPeripheralConnection(peripheral)
        }
    }

    func stop() {
        onEvent = nil
        disconnect()
        if let central, central.state == .poweredOn, central.isScanning { central.stopScan() }
        central?.delegate = nil
        central = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === self.central else { return }
        switch central.state {
        case .poweredOn: onEvent?(.ready)
        case .poweredOff: onEvent?(.failure(.poweredOff))
        case .unauthorized: onEvent?(.failure(.denied))
        case .unsupported: onEvent?(.failure(.unsupported))
        case .resetting: onEvent?(.failure(.resetting))
        case .unknown: break
        @unknown default: onEvent?(.failure(.unavailable))
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard central === self.central, central.isScanning else { return }
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = (advertisedName ?? peripheral.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let services = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        onEvent?(.device(RadioDevice(id: peripheral.identifier, name: name, rssi: RSSI.intValue, services: services, lastSeen: .now)))
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard central === self.central, peripheral === self.peripheral else { return }
        onEvent?(.connected)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard central === self.central, peripheral === self.peripheral else { return }
        onEvent?(.connectionEnded)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard central === self.central, peripheral === self.peripheral else { return }
        onEvent?(.connectionEnded)
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard peripheral === self.peripheral else { return }
        onEvent?(.rssi(error == nil ? RSSI.intValue : nil))
    }
}
