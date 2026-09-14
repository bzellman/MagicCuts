# User-authorized correction after compact-header rejection

The user authorized one more pass, then rejected the narrow Magnetic field compact header with “This is a no go.” The authority is recorded in the surface contract and `request/rejected-compact.png`. The fresh full review is `rejection-review.md`; this packet requests only its bounded four-finding verdict.

One correction batch now keeps the compact Instrument and Source labels plus equal Room and Settings icon targets in one row at every standard text size. The compact two-row fallback and detached icon circles are gone. Container width and height now follow the same animatable layout progress as its four stable control frames; labels retain compact metrics until expansion completes, and the competing child animation overrides are removed. Expanded and stacked Room icons use their intrinsic scaled size so the largest accessibility text no longer collides.

All 39 current native UI PNGs were replaced with evidence from this correction and opened for capture validity: 15 phone XCTest captures, 12 iPad landscape captures, four iPad portrait captures, and eight native recording frames. Native full-display pixels are unchanged. The additional user rejection image is reference evidence, not a current UI capture. Provenance is embedded in all 40 PNGs.

Review the same paths as before, especially:

- `phone/motion-compact-light.png`, `phone/motion-compact-dark.png`, `phone/motion-long-title-light.png`, `phone/motion-long-title-dark.png`, and `phone/motion-largest-standard.png`.
- The corresponding tablet compact and long-title images, plus all four `tablet/motion-tablet-portrait-*.png` images.
- `phone/pro-largest-text.png` and `tablet/pro-largest-text.png` for Room spacing, and their largest-controls companions for retained accessibility reflow.
- `phone/motion-in-flight-01.png` through `04.png`: native phone recording input-seek offsets 107.15, 107.30, 109.60 and 109.80, covering expansion and folding.
- `tablet/motion-in-flight-01.png` through `04.png`: native tablet recording input-seek offsets 94.50, 94.60, 96.70 and 96.80, covering expansion and folding.
- Expanded/restored light and dark states on both device classes for regressions introduced by this batch.

`phone/header-motion.mp4` is a 7.62-second, 142-frame native-speed trim selected from seconds 106–114 of `/tmp/magiccuts-header-motion-phone-verdict3.mp4`. The tablet raw recording is `/tmp/magiccuts-header-motion-tablet-verdict3.mp4`. The selected frames document intermediate header control bounds; ordinary content scrolls below the fixed safe-area header and can be partially outside the viewport.

Nine selected native UI test executions passed, with no failures or skips: five phone, three iPad landscape, one iPad portrait. The test now asserts all compact controls share a row, including the rejected Magnetic field case. Navigation, fitting-content resistance, repeated fold/restore, largest standard and accessibility text, and the Reduce Motion branch are covered. Current test exports are `tests/{phone,tablet,portrait}-verdict3-{summary,tests,attachments}.json`.

The portable receipt, validation prose and scroll-motion state are being reconciled after the verdict; their correction-two status is historical, not evidence about these fresh screenshots. No further source correction has been made after this batch. Score only the four requested fixes as resolved, partial or unresolved, plus regressions introduced by this batch. Save the verdict to `rejection-verdict.md`. This is simulator design/navigation evidence; it is not physical camera, LiDAR, sensor or device frame-rate proof.
