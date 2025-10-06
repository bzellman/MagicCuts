
import AppIntents
import CoreBluetooth

struct MagicCutsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: IsDeviceNearbyIntent(),
            phrases: [
                "Is my \(.applicationName) device nearby?",
                "Check for my \(.applicationName) device"
            ],
            shortTitle: "Check Device Proximity",
            systemImageName: "wave.3.right.circle"
        )
    }
}
