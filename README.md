# MagicCuts

**Bluetooth Device Proximity Detection for iOS Shortcuts**

MagicCuts is an iOS app that monitors Bluetooth device proximity and integrates with Apple Shortcuts and Siri. Detect when your devices are nearby and trigger powerful iOS automations based on signal strength.

## Features

- 📡 **Bluetooth LE Device Discovery** - Scan and discover nearby Bluetooth Low Energy devices
- 📊 **RSSI Monitoring** - Track signal strength (RSSI) in real-time to detect proximity
- 💾 **Device Persistence** - Save devices with custom names and signal thresholds
- ⚡ **Shortcuts Integration** - Run proximity checks directly from Shortcuts app
- 🎙️ **Siri Support** - Ask Siri "Is my device nearby?"
- 🔄 **Background Operation** - Shortcuts run without opening the app
- ⚙️ **Configurable Thresholds** - Set custom RSSI values for each device

## How It Works

1. **Discover** - Scan for Bluetooth devices in range
2. **Monitor** - Save devices with custom signal strength thresholds
3. **Automate** - Create Shortcuts that check device proximity
4. **Trigger** - Run automations when devices are near or far

## Use Cases

- Trigger smart home scenes when you arrive home (detect car Bluetooth)
- Send notifications when you leave devices behind
- Log presence for time tracking
- Create location-based reminders using device proximity
- Automate tasks based on nearby wearables or accessories

## Requirements

- iOS 16.0+
- Bluetooth-enabled iOS device
- Physical device (Bluetooth scanning not available in simulator)

## Installation

1. Clone this repository
2. Open `MagicCuts.xcodeproj` in Xcode
3. Select your development team in project settings
4. Build and run on your iOS device

## Usage

### Setting Up Device Monitoring

1. Open MagicCuts app
2. Tap "Discover Devices"
3. Grant Bluetooth permissions when prompted
4. Wait for nearby devices to appear
5. Tap a device to monitor it
6. Set a custom name and RSSI threshold
7. Save the device

### Creating a Shortcut

1. Open the Shortcuts app
2. Create a new shortcut
3. Add the "Check if Bluetooth Device is Nearby" action
4. Select your monitored device
5. Use the boolean result in automation logic

### RSSI Guidelines

RSSI (Received Signal Strength Indicator) values are negative:
- **-30 to -50**: Very close (< 1 meter)
- **-50 to -70**: Close (1-5 meters)
- **-70 to -90**: Far (5-15 meters)
- **< -90**: Very far or unreliable

Lower numbers (more negative) = weaker signal = farther away

## Technical Details

### Architecture

- **SwiftUI** - Modern declarative UI
- **SwiftData** - Device persistence with shared app group
- **CoreBluetooth** - Bluetooth LE scanning and RSSI tracking
- **AppIntents** - Shortcuts and Siri integration
- **UserDefaults** - Cross-process data sharing with app group

### Key Components

- `BluetoothViewModel` - Manages BLE scanning and device discovery
- `MonitoredDevice` - SwiftData model for saved devices
- `IsDeviceNearbyIntent` - AppIntent for Shortcuts integration
- `DeviceStorage` - Shared storage using app group container

### App Group

The app uses the shared container `group.com.bradzellman.magiccuts` to enable data access from Shortcuts extension context.

### Permissions

- **Bluetooth Always Usage** - Required for background proximity checks
- **Siri Integration** - Required for voice commands

## Building

```bash
# Build for simulator (Debug)
xcodebuild -project MagicCuts.xcodeproj -scheme MagicCuts -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 15' build

# Build for device (Release)
xcodebuild -project MagicCuts.xcodeproj -scheme MagicCuts -configuration Release -destination generic/platform=iOS build
```

## Known Limitations

- Bluetooth scanning requires physical iOS device (doesn't work in simulator)
- Background scanning may be limited by iOS power management
- Some Bluetooth devices may not advertise consistently
- RSSI values can fluctuate based on interference and device orientation

## Privacy

MagicCuts only scans for Bluetooth devices - it does not connect to them or access any device data beyond their broadcast UUID, name, and signal strength.

## License

[Add your license here]

## Contributing

Contributions welcome! Please open an issue or submit a pull request.

## Author

Bradley Zellman

## Support

For issues or questions, please open an issue on GitHub.
