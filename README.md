# MagicCuts Pro

Native iPhone and iPad instruments for measuring a setup, establishing a reference, comparing a change, and using the result in Shortcuts. Every feature requires a one-time Pro purchase, including saved Bluetooth devices and all App Intents.

Requires iOS 26 or later and Xcode 26 or later. Swift 6 with complete strict concurrency. Measurements, baselines, workflows, recordings and reports stay on the device; no account or owner-operated service is required.

## Instruments and evidence

Twelve instruments share Live, Inspect and Compare views: Bluetooth signal, tilt, vibration, rotation rate, magnetic field, pressure, relative altitude, heading, speed, digital sound level, endpoint response time, and battery level. Each adapter checks hardware and permission availability. Choose a source and start a measurement deliberately. Sound is dBFS, not calibrated sound pressure; RSSI is received power, not distance; endpoint response time measures an HTTP HEAD request, not ICMP ping.

Pin a chart reading, inspect time and metadata, save a named compatible baseline, or compare measurements on a shared scale. Bluetooth calibration collects nearby and away trials, proposes a threshold only when the distributions separate, then requires another measured check.

Recordings support marks, pause/resume, explicit interruptions and recovery checkpoints. Sessions export retained samples and metadata as CSV/JSON or a paginated PDF. Field reports combine protocols, notes and saved sessions. Live Activities show recording status; iOS backgrounding pauses capture and records a gap.

Workflows evaluate all/any conditions over named measurement windows. Bluetooth groups support all, any or a minimum observed count in a shared scan. Missing, stale, interrupted and unavailable results remain distinct from a failing condition. Saved workflows and groups are available through App Intents.

## Setup and calibration

Open the Bluetooth source menu and choose Manage devices. Open a device to rename it, edit its threshold, test nearby and away, inspect local history, or configure a Shortcut. Simple and Technical modes share the same settings. Technical mode adds readings and radio metadata.

Threshold edits are drafts until **Apply threshold**. **Test draft** retains a labeled history record but cannot validate saved settings. The editor accepts −100 through −1 dBm; the default remains −70 dBm. Older unusable thresholds remain visible for explicit repair and produce an actionable Shortcut error.

Validation observes a full ten-second window after Bluetooth becomes ready. At least two valid readings must all meet the threshold for nearby validation, or all fall below it for away validation. Mixed, sparse, and missing readings are inconclusive. Changing the threshold or service filter invalidates previous evidence and Shortcut confirmation. Tests describe the observed window; they do not guarantee future results.

History is local, per device, and newest first. It includes threshold, position, draft status, timestamps, readings, and errors. Cancelled or interrupted runs are discarded. Individual records can be deleted; clearing history or deleting a device requires confirmation.

New users can skip the welcome or proceed to discovery. Bluetooth access begins only when scanning starts. Discovery includes named and unnamed advertisements, search, signal/name sorting, last-seen and stale indicators, and identification guidance. Naming requires explicit Save; Cancel leaves no saved device. Existing saved device identities and history remain available.

## Shortcuts

Add **Check if Bluetooth Device is Nearby**, select a saved device, and use an **If** action to branch on its Boolean result. Every invocation requires a verified Pro entitlement and resolves the latest saved settings.

- `true`: at least one valid reading met the saved threshold.
- `false`: no qualifying reading was detected during the completed window. This does not confirm absence.
- Error: Bluetooth unavailable/denied/off/resetting, initialization failure, deleted device, unusable settings, or unreadable shared settings.

This preserves the original action identity and any-sample meaning, which is weaker evidence than the app's repeated validation. Opening Shortcuts does not mark setup complete; confirmation requires the user to test their actual shortcut. Background execution depends on iOS scheduling, permissions, and device advertisements. A device without saved advertised service identifiers may not be discoverable in the background. Test the intended foreground/background use on hardware.

## Purchase configuration

`ProAccess` verifies StoreKit current entitlements and transaction updates. Purchase, restore, pending approval, cancellation and revocation retain distinct states. App Intents independently check access before measurements.

The shared scheme includes `Configuration/MagicCutsPro.storekit` for **local Xcode testing only**. Its $14.99 fixture is not approved live pricing. Configure the non-consumable product `com.bradZellman.MagicCuts.pro` in App Store Connect and verify sandbox/TestFlight purchasing before release. A missing live product leaves purchasing unavailable with retry and restore.

Debug-only `--pro-development-access` permits physical instrument QA. `--uitesting --pro-demo --seed-device` uses explicitly labeled sample sessions and isolated stores. `--uitesting --pro-locked` exercises the paywall. Release builds ignore those flags.

## Architecture

- `InstrumentEngine` owns sensor sessions, timestamps, segments, bounded display history, checkpointing and Live Activity state.
- `MeasurementMath` defines robust summaries, angular calculations, level transforms, spectra and calibration suitability.
- `InstrumentArchive` coordinates local file and index mutations, preserving evidence referenced by reports and recoverable interrupted sessions.
- `WorkflowRunner` evaluates observation quality and three-state conditions; Bluetooth groups share one sampling window.
- `RadioScanning` and `ProximitySampler` retain session-scoped Bluetooth observations and the original action's full window.
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

Permissions are requested when a selected instrument needs them. Audio analysis does not save raw audio. Location is used only by selected location/heading instruments. Endpoint tests reach a URL explicitly entered by the user. Stored sessions include their selected source and measurement metadata; sharing occurs only through the system share sheet. No analytics collector, cloud database or hosted entitlement service is included.
