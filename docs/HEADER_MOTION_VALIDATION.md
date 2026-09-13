# Source header scroll motion

The enlarged source group folds into one bar while reading overflowing content and restores near the top. Instrument and Source remain labeled, with Room and Settings in equal icon targets beside them. The rejected compact two-row fallback and detached circles are removed. Fitting content does not trigger a fold when rubber-banded.

The four native controls retain identity while a single animatable layout coordinates their frames and the enclosing width and height. Compact label metrics remain in use until expansion completes; interrupted animations invalidate the pending label reveal. Quantized scroll regions avoid per-pixel measurement-view updates, and separated thresholds prevent the changing inset from toggling the state repeatedly. Chart transactions exclude header animation so navigation does not interpolate observations or units.

Ordinary compact navigation occupies one 56pt row. Longer labels can wrap within their own cells; at larger standard text sizes the common row can grow to fit the scaled content. Accessibility text uses the expanded, stacked header in the scroll flow. The Room symbol retains its intrinsic scaled size to separate it from the label. Reduce Motion changes the layout immediately.

## Verification

The user-authorized third correction builds successfully. Nine selected UI test executions passed with no failures or skips: five phone cases, three iPad landscape cases, and one iPad portrait case. They cover Home accessibility in both appearances, largest accessibility text and controls, repeated fold/restore, direct Instrument/Source/Room/Settings navigation, the rejected Magnetic field case, largest standard text, the Reduce Motion branch, and fitting versus overflowing portrait-tablet content. Compact controls are asserted to share a common row.

All 39 current UI PNGs were refreshed after this correction and opened for capture validity. The 31 XCTest screenshots match their native attachment exports pixel for pixel; the eight intermediate frames match their native recording-frame exports. A separate user-supplied rejection image is retained as reference. All 40 PNGs carry origin metadata; the provenance scan reports none missing. No app compiler warnings or errors appear in the three current test logs.

The independent bounded verdict is **ship**: all four requested fixes are resolved, with no regressions introduced by the correction. It covers the compact composition, transition bounds, largest-accessibility Room spacing, and refreshed evidence. It is a verdict on this correction, not a new whole-app release review. See `.impeccable/review/header-motion/rejection-verdict.md`.

## Evidence and limits

The portable receipt is `docs/validation/header-motion-evidence.json`; native captures, current test exports and review reports are under `.impeccable/review/header-motion/`. Current result bundles use the `verdict3` suffix. The phone preview is a 7.62-second, 142-frame native-speed trim selected from seconds 106–114, of `/tmp/magiccuts-header-motion-phone-verdict3.mp4`. Its origin sidecar records both file hashes. Four phone and four iPad frames sample actual expansion and folding. Their recorded FFmpeg seek offsets are extraction locators; they are not independently verified presentation timestamps.

The captures and recordings use the native simulator app with explicit sample data. They establish layout, scroll behavior and reachable navigation. Physical camera frames, LiDAR accuracy, sensor performance and physical-device frame rate are not established. The existing camera-first tool entry remains in place. Scrolled content can be partially outside the viewport beneath the fixed safe-area header; the header does not pin the measurement reading.

The automated Reduce Motion case forces the same no-animation branch with a DEBUG-only launch argument. It does not claim the OS setting was toggled. Only the selected UI cases were rerun; broader application and commerce evidence remains historical.

## Review history

Two initial correction/verdict rounds retained transition clipping and a Room-symbol regression. The user then authorized one more pass and rejected the compact Magnetic field screenshot with “This is a no go.” A fresh independent review identified four bounded corrections: a cohesive compact row, synchronized transition bounds, largest-text Room spacing, and fresh evidence. Those corrections were applied in one batch and the same reviewer received the resulting captures for a bounded verdict.

The reviewer initially reported compact-height growth and phone label clipping. Reopening the exact current images established a 56pt bar and complete labels inset approximately 26.7pt from the screen edge; the reviewer corrected both factual errors in its final report. No source changes or replacement captures occurred during that reconciliation.

The named Impeccable reviewer and documenter roles were unavailable; fresh independent default agents followed their shipped fallback contracts. Final motion documentation is recorded in `.impeccable/review/header-motion/documentation.md`, with the incumbent Native Utility design retained. Earlier unsuccessful build/test assumptions remain in their original result bundles. Dedicated iPad portrait evidence resolves the earlier orientation assumption. The preexisting dirty `.impeccable/review/native-utility/phone/pro-live-light.png` remains outside this change.
