# MagicCuts Pro validation

Validated September 10, 2026 in the isolated `codex/magiccuts-pro-instruments` worktree. This is an implementation and review build. It has not been submitted or released to the App Store.

Machine-readable local results and source fingerprints: [pro-evidence.json](validation/pro-evidence.json).

## Results

| Area | Result | Evidence and scope |
|---|---|---|
| Release app and Live Activity extension | Pass | Generic iOS Release build, Swift 6 strict concurrency; no app warnings or errors. Signing and store submission are separate. |
| Measurements, storage, reports, original proximity logic | 32 tests pass | iOS 27 simulator. Includes real loopback HTTP requests, 20-request stop, redirect refusal, robust/circular math, sampled spectra, source compatibility, full Bluetooth windows, cancellation, group unknown states, coordinated archive writes, recovery and report bytes. |
| StoreKit entitlement lifecycle | 1 test passes | Apple's local StoreKit environment on iOS 27, launched through Xcode. Product load, locked action, purchase, restore, refund relock, pending approval and transaction-listener unlock all passed without development access. |
| Pro UI | 4 journeys pass | iOS 26.5 simulator: locked root, baseline/inspect/compare/record/mark/save/export/report, workflow create/run, all instrument navigation and largest text. |
| Retained Bluetooth setup UI | 7 journeys pass | iOS 26.5 for regular flows and iOS 27 for the final largest-text visible-content audit. Welcome, explicit naming/save/cancel, permission/off/empty/stale cases, persistence, interruption, threshold modes/history and accessible setup remain usable. |
| Reduce Motion | Pass | iPadOS 26.5 with the OS preference enabled: Live/Inspect/Compare selection and retained threshold/history journey pass. The test verifies the OS flag before running. |
| Native visual review | Ship for the scored findings | The independent verdict resolved large-text reflow, Instruments identity and native evidence-state sequencing. This was a bounded verdict over the original findings, not a new whole-app audit. |
| Real Bluetooth discovery | Pass | Signed app on an iPhone 17 Pro Max received actual advertisements and stopped scanning successfully. |
| Physical motion instruments | Partial | Level, vibration and rotation each reached Live with actual sensor data and no sample-session flag. The wider UI run lost device automation authorization while switching to magnetic field. |
| Remaining physical instruments | Open | Magnetic field, pressure, relative altitude, heading, speed, microphone and battery still need uninterrupted hardware acceptance. Simulator fixture navigation does not prove sensor readings. |
| ActivityKit runtime | Pass in simulator | Real ActivityKit creation, reading publication, paused state and termination passed on iOS 27 without a mock activity service. |
| Physical Lock Screen and real Shortcuts invocation | Open | Lock-screen presentation and ordinary device Shortcuts execution remain release acceptance tasks. |
| Live App Store purchase | Open | Product and final price have not been configured/approved. Local StoreKit tests do not prove sandbox/TestFlight commerce. |

The eleven regular UI journeys passed across focused runs after their failures were corrected. This report does not describe the earlier failing aggregate run as green. The latest report wording change only corrects singular/plural copy; the report export tests and incremental Release build both passed afterward.

## What is implemented

| Instrument | Value and interpretation | Derived evidence |
|---|---|---|
| Bluetooth | Advertised RSSI in dBm, source and freshness | Median, middle 50%, threshold delta, paired nearby/away calibration; never distance |
| Level | Gravity-based tilt in degrees | Vector reference comparison and a two-axis level face |
| Vibration | Acceleration magnitude in g | RMS, measured-cadence Hann spectrum and dominant frequency; gaps reject spectra |
| Rotation | Angular velocity | Magnitude, summaries and shared-scale reference comparison |
| Magnetic field | Magnetic flux density | Magnitude and source metadata; interference remains visible |
| Pressure | Device barometer pressure | Robust summary and compatible baseline delta |
| Relative elevation | Change from the session's barometer reference | Relative values and session-reference metadata; not absolute terrain height |
| Heading | Magnetic heading in degrees | Circular differences and summaries; north wraps without a spurious chart connection |
| Speed | Location-derived speed | Timestamp and accuracy metadata, missing/invalid readings excluded |
| Sound | Microphone digital level in dBFS | RMS-to-log level, audio-input compatibility; raw audio is not recorded and this is not calibrated SPL |
| Connection | Uncached HTTP HEAD response time in ms | Up to 20 sequential requests, p95, separate failures, path context and no redirects; not ICMP or packet loss |
| Battery | Device battery percentage | Charge state and device metadata; no invented temperature sensor |

Named baselines are matched to the instrument, source and relevant input settings. Sessions retain marks, interruptions and sample gaps, with CSV/JSON/PDF exports. Field reports combine saved sessions, operator notes and explicit protocol confirmations. Bluetooth groups use one observation window and preserve unknown members. Workflows apply all/any conditions over real sampling windows and have App Intent entry points. Every usable entry point requires Pro, including the original Bluetooth intent.

## Visual and accessibility evidence

The reference system is the user's approved Live / Inspect / Compare combination, with the requested blue replacing orange and SF Rounded segment labels. Native iOS/iPadOS 26 `TabView`, navigation bars and sheets supply platform chrome. The image-comparison helper reports pixel drift from the approved rendered mockups; that score is not represented as a pass or used as a substitute for native review.

At accessibility sizes, the three modes move into one native menu, controls and statistics reflow, recording actions scroll with the content, and chart axes scale within an increased plot height. Readings and explanations remain Dynamic Type text. VoiceOver can adjust the history through individual samples. Reduced-motion selection avoids the matched-geometry transition.

XCTest's contrast image includes some text already scrolled beneath translucent native bars. The audit handler defers only elements crossing the measured top/bottom chrome boundary, then audits them after scrolling into view. Contrast, target, description and trait checks remain enabled for visible content. Captures include the reading, chart/statistics and recording-control scroll positions. This is a scoped workaround for obscured screenshot samples, not a blanket contrast exclusion.

Screenshots in `docs/screenshots/pro/` are explicitly labeled sample sessions. PDF and field-report exports were also opened visually; tests checked multi-page content, final marks, CSV row counts, combined report pages and query redaction.

## Reproducible test setup

Use the shared MagicCuts scheme for ordinary software/UI tests and the MagicCuts StoreKit Tests scheme for commerce. Run serially. The local product identifier is `com.bradZellman.MagicCuts.pro`; its $14.99 value is a fixture, not an approved live price.

On this machine, iOS 26.5 StoreKit Test control calls failed to save local configuration. The complete commerce test passed on the dedicated iOS 27 simulator after running the StoreKit scheme in Xcode and then testing from Xcode. Do not substitute an Apple Account/password prompt for the local test environment or classify a missing product as a successful purchase.

Local evidence is retained under `.review/pro/` (ignored build artifacts): `unit-delivery.log`, `storekit-final-summary.json`, `storekit-final-tests.json`, `fix-validation.log`, `a11y-final.log`, `device-a11y-final.log`, `reduced-motion-final.log`, `activity-report-final.log`, `release-final.log`, `physical-validation.log`, and `physical-final.log`. Exact Xcode result bundles are referenced in those logs. Xcode prunes older bundles; portable receipts retain summary/test details or identify when evidence comes from the retained log. No live credentials or physical-device identifiers are required in shared documentation.

## Before release

1. Choose the final price, configure the non-consumable product in App Store Connect, and validate purchase, restore and revocation in sandbox/TestFlight.
2. Complete the remaining physical instrument/permission, background-pause, Live Activity and ordinary Shortcuts checks. Validate both supported and unavailable hardware states; use known reference setups when making accuracy claims.
3. Review the capabilities inventory as future research, not current shipping functionality. NFC, UWB, camera/depth, participating accessories and other deferred adapters are not included as placeholders.
4. Complete the normal signing, privacy, store metadata and release process for the chosen target. This branch does not authorize a release or merge.
