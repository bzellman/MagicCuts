# MagicCuts Pro

Native iPhone and iPad instruments for measuring a setup, establishing a reference, comparing a change, and using the result in Shortcuts. Every feature requires a one-time Pro purchase, including saved Bluetooth devices and all App Intents.

Requires iOS 26 or later and Xcode 26 or later. Swift 6 with complete strict concurrency. The library works locally by default. Users can opt into private iCloud portability with their Apple Account; no MagicCuts account or owner-operated service is required.

## Instruments and evidence

Twelve instruments share Live, Inspect and Compare views: Bluetooth signal, tilt, vibration, rotation rate, magnetic field, pressure, relative altitude, heading, speed, digital sound level, endpoint response time, and battery level. Each adapter checks hardware and permission availability. Choose a source and start a measurement deliberately. Sound is dBFS, not calibrated sound pressure; RSSI is received power, not distance; endpoint response time measures an HTTP HEAD request, not ICMP ping.

Pin a chart reading, inspect time and metadata, save a named compatible baseline, or compare measurements on a shared scale. Bluetooth calibration collects nearby and away trials, proposes a threshold only when the distributions separate, then requires another measured check.

Recordings support marks, pause/resume, explicit interruptions and recovery checkpoints. Sessions export retained samples and metadata as CSV/JSON or a paginated PDF. Field reports combine protocols, notes and saved sessions. Live Activities show recording status; iOS backgrounding pauses capture and records a gap.

Workflows evaluate all/any conditions over named measurement windows. Bluetooth groups support all, any or a minimum observed count in a shared scan. Missing, stale, interrupted and unavailable results remain distinct from a failing condition. Saved workflows and groups are available through App Intents.

## Rooms and field tools

**Rooms** keeps observed LiDAR meshes, recognized room components, dimensions and immutable capture revisions. Reopen a saved room without the camera, switch between Mesh / Plan / Measurements, or use **Locate in room** to attempt restoration of its coordinate frame. While orientation is active and reliable, newly captured readings and recorded samples retain their position. Captures can also be placed manually with explicit coordinates and orientation.

**Field tools** adds NFC identity/records/capacity/diagnostics; per-request network phases, consistency and bounded transfers; reported cellular technology, route-verified performance, service forecasts and delayed history; LiDAR distance, two-point dimensions, surface fitting and depth/confidence; and participating-device benchmarks, Wi-Fi Aware reports and Nearby Interaction ranging. Hardware, permissions, provider payloads and peer availability are checked at use time.

Rooms export a native JSON archive, observed mesh OBJ, measurement CSV, and recognized-room USDZ when RoomPlan data exists. Field captures save to Sessions, can be compared, and export JSON/CSV. [The implementation and validation record](docs/ROOM_INSTRUMENT_VALIDATION.md) distinguishes software/simulator evidence from remaining physical acceptance. No sensor accuracy or complete-room geometry is inferred from a successful save.

## Setup and calibration

Open the Bluetooth source menu and choose Manage devices. Open a device to rename it, edit its threshold, test nearby and away, inspect local history, or configure a Shortcut. Simple and Technical modes share the same settings. Technical mode adds readings and radio metadata.

Threshold edits are drafts until **Apply threshold**. **Test draft** retains a labeled history record but cannot validate saved settings. The editor accepts −100 through −1 dBm; the default remains −70 dBm. Older unusable thresholds remain visible for explicit repair and produce an actionable Shortcut error.

Validation observes a full ten-second window after Bluetooth becomes ready. At least two valid readings must all meet the threshold for nearby validation, or all fall below it for away validation. Mixed, sparse, and missing readings are inconclusive. Changing the threshold or service filter invalidates previous evidence and Shortcut confirmation. Tests describe the observed window; they do not guarantee future results.

History is per device and newest first. It includes threshold, position, draft status, timestamps, readings, and errors. With optional iCloud sync, another device can inspect this history as an original setup reference. Cancelled or interrupted runs are discarded. Individual records can be deleted; clearing history or deleting a device requires confirmation.

New users can skip the welcome or proceed to discovery. Bluetooth access begins only when scanning starts. Discovery includes named and unnamed advertisements, search, signal/name sorting, last-seen and stale indicators, and identification guidance. Naming requires explicit Save; Cancel leaves no saved device. Existing saved device identities and history remain available.

## Shortcuts

Add **Check if Bluetooth Device is Nearby**, select a saved device, and use an **If** action to branch on its Boolean result. Every invocation requires a verified Pro entitlement and resolves the latest saved settings.

- `true`: at least one valid reading met the saved threshold.
- `false`: no qualifying reading was detected during the completed window. This does not confirm absence.
- Error: Bluetooth unavailable/denied/off/resetting, initialization failure, deleted device, unusable settings, or unreadable shared settings.

This preserves the original action identity and any-sample meaning, which is weaker evidence than the app's repeated validation. Opening Shortcuts does not mark setup complete; confirmation requires the user to test their actual shortcut. Background execution depends on iOS scheduling, permissions, and device advertisements. A device without saved advertised service identifiers may not be discoverable in the background. Test the intended foreground/background use on hardware.

The action returns as soon as a valid reading meets the threshold. It starts with saved service UUIDs and retries without a filter after 1.5 seconds if the target has not been observed. It also attempts a local connection to the saved peripheral for up to five sequential RSSI reads. A failed connection, read error or disconnect leaves advertisement scanning available until the 10-second observation window ends. Completion cancels scanning, pending connections and polling; late callbacks cannot affect another run. See the [Bluetooth Shortcut device validation script](docs/BLUETOOTH_SHORTCUT_VALIDATION.md).

## Optional iCloud portability

Settings → Sync with iCloud is off by default on each installation. Opting in merges saved sessions, baselines, workflows, groups, reports, room revisions, field captures, and Bluetooth setup references through the user's private CloudKit database. Edits and deletions sync. Turning sync off keeps the local and iCloud copies; local instruments remain usable when iCloud is unavailable. Switching Apple Accounts pauses sync and requires another explicit opt-in.

Bluetooth identities and calibration remain specific to their original installation. Open Bluetooth setups from iCloud, identify and save the actual peripheral on this device, explicitly connect the reference, and test the current setup. Imported sensor baselines remain viewable but need a new capture before live comparison. Permissions, Shortcut confirmations, in-progress recordings, purchase access and iCloud consent do not sync.

Apple manages CloudKit transport and scheduling. There is no MagicCuts login, backend, analytics collector, paid sync service or custom push server. Pro purchase restoration uses StoreKit independently of the iCloud library. See [iCloud architecture and acceptance](docs/ICLOUD_PORTABILITY.md) for the schema, account behavior, tested scope and production release requirements.

## Purchase configuration

`ProAccess` verifies StoreKit current entitlements and transaction updates. Purchase, restore, pending approval, cancellation and revocation retain distinct states. App Intents independently check access before measurements.

The shared scheme includes `Configuration/MagicCutsPro.storekit` for **local Xcode testing only**. Its $14.99 fixture is not approved live pricing. Configure the non-consumable product `com.bradZellman.MagicCuts.pro` in App Store Connect and verify sandbox/TestFlight purchasing before release. A missing live product leaves purchasing unavailable with retry and restore.

Debug-only `--pro-development-access` permits physical instrument QA. `--uitesting --pro-demo --room-demo` adds explicitly illustrative room fixtures; `--room-fixture-id UUID` reuses an isolated UI-test library for relaunch checks. `--uitesting --pro-demo --seed-device` uses explicitly labeled sample sessions and isolated stores. `--uitesting --pro-locked` exercises the paywall. Release builds ignore those flags.

## Architecture

- `InstrumentEngine` owns sensor sessions, timestamps, segments, bounded display history, checkpointing and Live Activity state.
- `MeasurementMath` defines robust summaries, angular calculations, level transforms, spectra and calibration suitability.
- `InstrumentArchive` coordinates local file and index mutations, preserving evidence referenced by reports and recoverable interrupted sessions.
- `CloudLibraryTransport` uses `CKSyncEngine` with the private `iCloud.com.bradZellman.MagicCuts` container only after opt-in. Library records merge by item revision, retain deletion receipts, and exclude installation-only state.
- `RoomSession` coordinates ARKit/RoomPlan capture, restoration attempts, reliable per-reading poses and recovery snapshots.
- The `Fieldwork` adapters retain source-specific NFC, network, cellular, depth and participating-device evidence.
- `WorkflowRunner` evaluates observation quality and three-state conditions; Bluetooth groups share one sampling window.
- `RadioScanning` and `ProximitySampler` retain session-scoped Bluetooth observations. In-app tests retain their full passive scan window; the original Shortcut uses targeted fallback/connection attempts and completes on threshold success. `BluetoothTransport` isolates CoreBluetooth callbacks for focused lifecycle regression tests.
- SwiftData device storage migrates existing identities/history. `DeviceRepository` saves before replacing the app-group snapshot; launch reconciliation repairs stale snapshots.
- App-group identifier: `group.com.bradzellman.magiccuts`.

## Build and test

Open `MagicCuts.xcodeproj`, choose the MagicCuts scheme and a simulator or signed device. Run tests serially because StoreKit testing shares one environment:

```sh
xcodebuild -project MagicCuts.xcodeproj -scheme MagicCuts \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -parallel-testing-enabled NO -collect-test-diagnostics never test
```

Tests cover measurement math, source compatibility, calibration quality, full windows, interruption/cancellation, shared Bluetooth groups, archive coordination, recovery, report bytes, legacy migration, StoreKit transitions and UI journeys. Simulator tests prove software behavior; physical sensors, background restrictions and real Shortcuts need device acceptance.

The local StoreKit suite is verified through the shared StoreKit scheme on an iOS 27 simulator; the validation report records the iOS 26.5 test-environment limitation.

See [Pro validation](docs/PRO_VALIDATION.md), [measurement research](docs/PRO_INSTRUMENT_RESEARCH.md) and the [capability inventory](docs/CAPABILITY_EXPANSION_PLAN.md). The inventory distinguishes current tools from future APIs that require separate hardware, participating peers or further implementation.

## Privacy

Permissions are requested when a selected instrument needs them. Audio analysis does not save raw audio. Location is used only by selected location/heading instruments. Endpoint tests reach a URL explicitly entered by the user. Stored sessions include their selected source and measurement metadata. Room captures can contain surfaces, a reference camera image, an AR world map and measurement positions. NFC captures may contain tag identifiers and user-readable/raw records. A confirmed peer connection exchanges encrypted test traffic and optional ranging tokens. Sharing with others uses the system share sheet; optional iCloud sync transfers the saved library to the user's private Apple Account database. No analytics collector, owner-operated database or hosted entitlement service is included. Support receives only information the user chooses to send. The public privacy policy must describe this opt-in behavior before release.
