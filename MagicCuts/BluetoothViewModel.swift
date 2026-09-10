import Foundation
import Combine

@MainActor
final class BluetoothViewModel: ObservableObject {
    @Published var devices: [RadioDevice] = []
    @Published var isScanning = false
    @Published var status = "Ready to scan"
    @Published var error: String?
    @Published var bluetoothError: BluetoothError?
    let radio: any RadioScanning
    private var task: Task<Void, Never>?
    init(radio: (any RadioScanning)? = nil) { self.radio = radio ?? BluetoothRadio() }
    func startScanning() {
        stopScanning()
        devices = []
        error = nil
        bluetoothError = nil
        status = "Preparing Bluetooth…"
        isScanning = true
        task = Task {
            do {
                try Task.checkCancellation()
                let session = radio.session(services: [])
                defer { session.cancel() }
                for try await event in session.events {
                    try Task.checkCancellation()
                    switch event {
                    case .ready: status = "Scanning…"
                    case .device(let device):
                        if let index = devices.firstIndex(where: { $0.id == device.id }) { devices[index] = device }
                        else { devices.append(device) }
                    }
                }
            } catch is CancellationError {
                if !Task.isCancelled { error = "Scan interrupted by another Bluetooth operation. Tap Start scanning to resume." }
            } catch { self.error = error.localizedDescription; bluetoothError = error as? BluetoothError }
            if !Task.isCancelled { isScanning = false; status = "Scan stopped" }
        }
    }
    func stopScanning() { task?.cancel(); task = nil; isScanning = false; status = "Scan stopped" }
}
