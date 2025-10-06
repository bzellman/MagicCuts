
import Foundation
import SwiftData

@Model
final class MonitoredDevice {
    @Attribute(.unique) var persistentIdentifier: String
    var name: String
    var requiredSignalStrength: Int
    var serviceUUIDs: [String]
    
    // Computed property to work with UUIDs in the app
    var uuid: UUID? {
        UUID(uuidString: persistentIdentifier)
    }
    
    init(persistentIdentifier: UUID, name: String, requiredSignalStrength: Int, serviceUUIDs: [String] = []) {
        self.persistentIdentifier = persistentIdentifier.uuidString
        self.name = name
        self.requiredSignalStrength = requiredSignalStrength
        self.serviceUUIDs = serviceUUIDs
    }
}
