# Bluetooth Shortcut validation

The service-filter fallback and direct RSSI behavior were recovered from the local stashed implementation and integrated into the current actor-isolated radio sessions. The stash remains unchanged. The existing Shortcut identity, latest-settings lookup, Pro gate and distinction between `false` and radio errors are preserved. In-app discovery, calibration and measurement windows remain passive.

## Physical-device script

Use a signed build with working Pro access, an iPhone with Bluetooth permission granted, and a programmable BLE peripheral with a stable identity. Save that peripheral in MagicCuts. Make a Shortcut with **Check if Bluetooth Device is Nearby → Show Result**. For foreground trials, prepend **Open App → MagicCuts**. Record the build, iOS version, peripheral firmware, result and elapsed time for each case.

For path attribution, attach Xcode to MagicCuts and use auto-continuing log breakpoints in `CoreBluetoothTransport.scan(services:)`, `connect(id:services:)`, `peripheral(_:didReadRSSI:error:)`, `disconnect()` and `BluetoothRadio.finish(_:)`. Check peripheral-side connection logs too. A `true` result alone does not prove which path supplied the reading.

1. **Threshold success:** advertise normally with a passing saved threshold. Run the Shortcut. Expect one `true` result before the 10-second window expires and immediate local cleanup. Lower the signal or raise the threshold and rerun; expect `false` after the full window if no reading qualifies.
2. **Service fallback:** save the peripheral while it advertises service A, then omit A from its advertisements without changing its identity. Reject connections for this case. Run with MagicCuts foregrounded. Verify the filtered scan changes to an unfiltered scan at about 1.5 seconds, then a matching advertisement can return `true`. Another device advertising A must never satisfy the check.
3. **Direct RSSI:** first make the peripheral known to iOS, then suppress advertising while retaining a system connection if the peripheral supports it. Verify MagicCuts establishes its own local connection, receives `didReadRSSI`, and returns `true` on a passing read. With a failing threshold, verify at most five sequential read requests, local disconnection after the final response, and `false` at the window deadline. No reads should occur before connection succeeds.
4. **Failure, disconnect and silence:** separately reject a connection, disconnect after a weak RSSI response, and make the peripheral unreachable during a pending connection/read. Expect no further direct reads after failure/disconnect. Advertisements may still produce `true`; otherwise expect one `false` after the window. Timeout must cancel a still-pending connection. Immediately rerun with the peripheral restored; the new run must work.
5. **Interruption and late callbacks:** stop a running Shortcut, and separately turn Bluetooth off in Settings during a check. Expect cancellation or a Bluetooth error, no Boolean success from an incomplete run, and no continuing scan/polling. Restore Bluetooth and immediately rerun. Repeat threshold success/cancel/rerun several times; delayed callbacks must not restart work or end the next run.
6. **Ordinary execution:** remove the Open App action. Repeat the passing, failing and interruption cases from Shortcuts with MagicCuts backgrounded, then from the intended locked-device automation, with the debugger detached. Record actual outcomes and timing; permission prompts and iOS suspension can extend or prevent execution. A missing observation means only “not detected above threshold.”

Apple requires a local connection even for peripherals already connected by another app. Connection cancellation is nonblocking and does not guarantee the shared physical link disconnects, so verify MagicCuts stops issuing work rather than requiring another app's link to drop. See [retrieving connected peripherals](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/retrieveconnectedperipherals(withservices:)), [reading RSSI](https://developer.apple.com/documentation/corebluetooth/cbperipheral/readrssi()), and [canceling a connection](https://developer.apple.com/documentation/corebluetooth/cbcentralmanager/cancelperipheralconnection(_:)).

## Automated scope

`BluetoothShortcutLifecycleTests` drives the production session and Shortcut through one injected hardware transport. It covers filtered fallback, valid target observation, invalid RSSI and read errors, bounded sequential polling, timeout while connecting/reading/polling, connection failure/disconnect, threshold success, cancellation, radio errors, stale callbacks, replacement sessions, deallocation, full passive sampling windows and linked local radio identity. CoreBluetooth peripheral retrieval, real callback delivery and background Shortcuts execution still require the hardware checks above.

Verified September 11, 2026 with Xcode 26.6 (17F113):

| Check | Result |
| --- | --- |
| Unit suite and focused Bluetooth UI, iOS 26.5 | 83 test methods passed: 80 unit + 3 UI; 96 executions including parameter cases; no failures or skips. UI covered permission/off/empty discovery, interruption recovery, and saved-device threshold/history. |
| StoreKit entitlement lifecycle, separate shared scheme on iOS 27 | 1 test passed; excluded from the iOS 26.5 run and verified separately. |
| Address Sanitizer, iOS 27 | All 25 proximity/lifecycle test methods passed, 38 executions; no findings. |
| Thread Sanitizer, iOS 27 | All 25 proximity/lifecycle test methods passed, 38 executions; no findings. |
| Generic iOS Release build and static analysis | Passed with Swift and Clang warnings treated as errors, signing disabled; no compiler/linker warnings. |
| Diff whitespace check | Passed. |

Durable local bundles and logs are in `/tmp/MagicCuts-d955-validation/`: `regression.xcresult`, `storekit26.xcresult`, `address-sanitizer.xcresult`, `thread-sanitizer-final.xcresult`, and `release.log`. The earlier tool-managed aggregate run exceeded the tool's five-minute response limit and lost its temporary bundle; it is not counted in these results.

The test commands set `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` and `OTHER_SWIFT_FLAGS='$(inherited) -Xcc -Wno-deprecated-declarations'` because Apple's StoreKitTest Objective-C header itself references deprecated `SKPaymentTransactionState`. Swift source diagnostics remain errors. Sanitizer commands also use `ENABLE_DEBUG_DYLIB=NO` to avoid Xcode's duplicate sanitizer/preview runtime search-path warning. These are command-local settings; project warning settings are unchanged. The Release check needs neither workaround.

An additional Xcode 27 beta 6 compiler probe stopped on existing `ImplicitStrongCapture` diagnostics in `FieldToolsView`, `PeerInstrumentView`, and `ProExperience`. The successful iOS 27 runtime tests above used Xcode 26.6-built binaries; they do not establish beta compiler compatibility.

To rerun just the focused software checks on an available simulator:

```sh
xcodebuild -project MagicCuts.xcodeproj -scheme MagicCuts \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -only-testing:MagicCutsTests/ProximityTests \
  -only-testing:MagicCutsTests/BluetoothShortcutLifecycleTests \
  -parallel-testing-enabled NO -collect-test-diagnostics never \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xcc -Wno-deprecated-declarations' test
```

For sanitizer runs, use the desired simulator destination, add `ENABLE_DEBUG_DYLIB=NO`, and enable one of `-enableAddressSanitizer YES` or `-enableThreadSanitizer YES` at a time.
