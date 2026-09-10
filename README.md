# MagicCuts

MagicCuts reads Bluetooth LE advertisements and supplies a Boolean proximity check to Apple Shortcuts. It does not continuously monitor presence or create automatic arrival/departure triggers. RSSI measures received signal strength, not an exact distance.

Requires iOS 26 or later and Xcode 26 or later. All targets use Swift 6 with complete strict concurrency. iPhone and iPad are supported. Real Bluetooth and Shortcuts acceptance testing requires physical hardware.

## Setup and calibration

Saved devices are the home screen. Open a device to rename it, edit its threshold, test nearby and away, inspect local history, or configure a Shortcut. Simple and Technical modes share the same settings. Technical mode adds readings and radio metadata.

Threshold edits are drafts until **Apply threshold**. **Test draft** retains a labeled history record but cannot validate saved settings. The editor accepts −100 through −1 dBm; the default remains −70 dBm. Older unusable thresholds remain visible for explicit repair and produce an actionable Shortcut error.

Validation observes a full ten-second window after Bluetooth becomes ready. At least two valid readings must all meet the threshold for nearby validation, or all fall below it for away validation. Mixed, sparse, and missing readings are inconclusive. Changing the threshold or service filter invalidates previous evidence and Shortcut confirmation. Tests describe the observed window; they do not guarantee future results.

History is local, per device, and newest first. It includes threshold, position, draft status, timestamps, readings, and errors. Cancelled or interrupted runs are discarded. Individual records can be deleted; clearing history or deleting a device requires confirmation.

New users can skip the welcome or proceed to discovery. Bluetooth access begins only when scanning starts. Discovery includes named and unnamed advertisements, search, signal/name sorting, last-seen and stale indicators, and identification guidance. Naming requires explicit Save; Cancel leaves no saved device. Existing users resume their saved devices.

**Implementation status:** the approved journey is implemented. Final review, accessibility verification, and physical Bluetooth/Shortcuts acceptance are in progress.

## Shortcuts

Add **Check if Bluetooth Device is Nearby**, select a saved device, and use an **If** action to branch on its Boolean result. Every invocation resolves the latest saved settings.

- `true`: at least one valid reading met the saved threshold.
- `false`: no qualifying reading was detected during the completed window. This does not confirm absence.
- Error: Bluetooth unavailable/denied/off/resetting, initialization failure, deleted device, unusable settings, or unreadable shared settings.

This preserves the original action identity and any-sample meaning, which is weaker evidence than the app's repeated validation. Opening Shortcuts does not mark setup complete; confirmation requires the user to test their actual shortcut. Background execution depends on iOS scheduling, permissions, and device advertisements. A device without saved advertised service identifiers may not be discoverable in the background. Test the intended foreground/background use on hardware.

## Architecture

- `RadioScanning` provides injectable, session-scoped observations; CoreBluetooth starts lazily after discovery/test begins.
- `ProximitySampler` separates observation from evaluation and bounds the ready scan window.
- SwiftData retains `MonitoredDevice` identities and adds immutable-in-use `TestRecord` snapshots. Legacy migration has an automated on-disk fixture.
- `DeviceRepository` commits SwiftData before replacing the app-group Shortcuts snapshot in one write. Launch reconciliation repairs stale snapshots. Synchronization failures remain visible with retry.
- App-group identifier: `group.com.bradzellman.magiccuts`.
- TipKit supplements essential on-screen guidance; it does not hide required instructions.

## Build and test

Open `MagicCuts.xcodeproj`, select the MagicCuts scheme and a simulator or signed device destination. To run automated tests:

```sh
xcodebuild -project MagicCuts.xcodeproj -scheme MagicCuts \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' test
```

Unit tests cover classification, valid RSSI boundaries, full windows, cancellation, replacement sessions, early termination, legacy store migration, history retention, snapshot replacement, and intent errors. UI tests use an injected radio and in-memory devices. They provide flow and rendering evidence only. Debug UI-test arguments are `--uitesting --seed-device`; those runs use an isolated shared-settings suite.

See [VALIDATION.md](VALIDATION.md) for current evidence and unfinished acceptance work.

## Privacy

No account, server, device connection, or continuous presence state is introduced. The app reads broadcast identifiers, names, advertised service identifiers, and signal strength; saved devices and test history stay local. Delete a device to delete its associated history.
