
import Foundation
import SwiftData

@Model
final class MonitoredDevice {
    @Attribute(.unique) var persistentIdentifier: String
    var name: String
    var requiredSignalStrength: Int
    var serviceUUIDs: [String]
    var validationResetAt: Date = Date(timeIntervalSince1970: 0)
    
    var confirmationKey: String { "\(requiredSignalStrength):\(validationResetAt.timeIntervalSince1970)" }

    // Computed property to work with UUIDs in the app
    var uuid: UUID? {
        UUID(uuidString: persistentIdentifier)
    }
    
    init(persistentIdentifier: UUID, name: String, requiredSignalStrength: Int, serviceUUIDs: [String] = []) {
        self.persistentIdentifier = persistentIdentifier.uuidString
        self.name = name
        self.requiredSignalStrength = requiredSignalStrength
        self.serviceUUIDs = serviceUUIDs
        self.validationResetAt = Date()
    }
}
