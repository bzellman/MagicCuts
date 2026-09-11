# Room mesh validation

September 11, 2026. Local worktree implementation; no device installation, App Store submission or release is claimed.

## Build and geometry

- Release device-target build passed with no compiler warnings or errors: `/tmp/MagicCuts-8f8b-room-release-final.log`.
- 16 existing room/archive tests and 8 new Swift Testing tests passed (the keep/remove test runs both options). Geometry evidence: `/tmp/MagicCuts-8f8b-room-final-tests.log`, result bundle `/tmp/MagicCuts-8f8b-room/Logs/Test/Test-MagicCuts-2026.09.11_02-44-05--0500.xcresult`.
- The 233,928-triangle full-resolution fixture passed its cut-boundary, retained-area and geometry-validity assertions in 1.623 seconds in a Debug simulator run. This is synthetic on-Mac timing, not a physical iPhone performance measurement.
- Tests cover exact triangle intersections, transformed patches, face classifications, immutable originals, archive/export round trips, crossing dimensions, stale semantic estimates, no-op/empty/invalid trims and selections merely touching a boundary.
- Camera tests verify that looking and zooming in Inside mode do not move the camera outside the room and that selecting a new position updates the viewpoint.

## UI and rendering

UI evidence uses the iPhone 17 Pro simulator on iOS 26.5. The enclosed room and hallway are explicitly labeled illustrative fixtures. All three UI journeys passed with zero failures or skips. The final rendering run is recorded in `/tmp/MagicCuts-8f8b-room-render-tests2.log`, result bundle `/tmp/MagicCuts-8f8b-room/Logs/Test/Test-MagicCuts-2026.09.11_02-48-12--0500.xcresult`. The final wording/action-layout adjustment also passed its separate largest-text run: `/tmp/MagicCuts-8f8b-room-largest-final.log`, result bundle `/tmp/MagicCuts-8f8b-room/Logs/Test/Test-MagicCuts-2026.09.11_02-54-02--0500.xcresult`.

The regression journey covers Outside → Inside → move viewpoint → trim hallway → preview → adjust/undo → cancel → trim/save → relaunch/reopen → export. A screenshot-based assertion checks for visible mesh surfaces after geometry loading; a renderer that reports ready but displays a blank rectangle fails the test.

The largest Dynamic Type journey uses native menus and edge steppers, then prepares the preview. Contrast, hit-region, element-description and trait audits run on the relevant visible states. The pre-existing plan, dimension, revision-comparison and archive-export journey is also included.

During verification, screenshot inspection caught a blank mesh when a second viewer was presented. Obscured mesh views now release their camera/renderer, and teardown removes only the owning anchor. Edge controls were changed to vertically stacked labels/values after the largest-text check exposed cramped columns. Test scrolling uses the page margin so it doesn't rotate the mesh or redraw a crop selection.

## Screenshots

- [Outside view](screenshots/mesh-enclosed-outside.png)
- [Inside view](screenshots/mesh-enclosed-inside.png)
- [Trim preview](screenshots/mesh-trim-hallway-preview.png)
- [Saved trimmed revision](screenshots/mesh-trim-saved-revision.png)
- [Largest-text edge controls](screenshots/mesh-trim-largest-text-controls.png)

These are unmodified simulator captures. The screenshot manifest records their test, device, capture time and checksum.

## Limits

- The original mesh behind the supplied screenshot was not available as a scan archive. The actual room and physical-device navigation still need acceptance on the user's iPhone.
- The crop is a full-height rectangle in the saved room coordinate frame. Polygon/rotated-box selection and height-limited trimming are not implemented.
- No physical VoiceOver session or iPad-specific run is claimed. Automated accessibility checks and native controls provide partial evidence.
- The first unit-test build emitted an Apple SDK warning from `StoreKitTest/SKTestTransaction.h` about its own deprecated `SKPaymentTransactionState` declaration. The app's Release build is clean. The purchase-test API was not replaced or its diagnostics suppressed.
- Simulator RealityKit logs contain built-in-material fallback messages and an unsupported shadow-pipeline diagnostic, including during visibly successful rendering. Visual assertions and screenshots verify the actual non-AR viewer output; simulator diagnostics do not establish device rendering behavior.
