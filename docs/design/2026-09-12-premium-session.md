# MagicCuts premium redesign session

Status: C · Soft forms approved and implemented on September 12, 2026. The research and workshop notes below record the design session; the delivered native behavior and evidence are in [Native Utility validation](../NATIVE_UTILITY_VALIDATION.md).

The session initially found this checkout at `1d04bb1` and the newer journey on `v1-home-instrument-sheet` at `447e20978cea6e8a9784be40baf8fed459c6e557`. The implementation branch `codex/native-utility-redesign` was based on that journey and merged main's Bluetooth and room mesh fixes at `ad5b51d`, producing baseline `2547937`. Unrelated work in the journey worktree was preserved.

## Scope

Operate mode. Make Home feel like a premium native measuring instrument. Preserve Home and Settings, the instrument and room sheets, Gauges / Info / Compare, source selection, baseline and calibration functions, and Log / Record / Start Flow. Preserve product truth, native interaction, Action blue, rounded reading typography, Dynamic Type, dark appearance and truthful measurement limitations. All concept values are sample data. This session changes native presentation and entry into camera tools; it establishes no production release or hardware acceptance.

User clarification: the newer journey is a solid baseline. Cover every visualization type. For physical measurements and LiDAR, show the camera by default wherever it supports the task, avoiding extra taps. The user then reposted the Native Utility concept, supplied Tempo on Mobbin as the craft reference, and specifically asked to study element shapes, depth and design language. Those instructions guide the current composition round.

## Camera exploration and interaction requirements

Selecting a camera-relevant tool opens its camera canvas directly, subject to the normal first-use system permission. There is no intermediate Start LiDAR or Show camera button. Switching Distance / Two points / Surface / Depth preserves the active camera session and framing. The primary action operates on the measurement: capture a distance, set a point, or save a surface. The camera view itself is not a separate action.

Distance and two-point dimensions put reticles, endpoints, dimension lines and readable value labels on the scene. Surface fit keeps the target patch visible, with fit orientation and quality beside it. Depth opens with the scene visible; a directly accessible overlay blends the depth representation over it, with a separate confidence legend. Room capture and revisit open into the camera; plan, inside/outside mesh and revisions are evidence views. Saved geometry opens as saved geometry, with a clearly named revisit action.

Camera-assisted alignment was explored as a possible extension. The delivered level and heading instruments retain their existing sensor canvas; LiDAR and room capture/revisit use the camera stage. Bluetooth, sound and network testing retain their appropriate instrument canvas. Peer direction is phone-relative unless actual world registration exists; the camera must not imply that the other device has been visually detected. Missing permission, unsupported hardware and tracking loss replace active overlays with recovery or fallback states. Opening a camera tool prepares its view; saving data remains deliberate. Leaving the tool releases the camera when no other active task owns it.

## Visualization coverage

All twelve `InstrumentKind` cases and all eighteen implemented field capability paths were read from the newer branch's source and validation matrix. This table groups them by the geometry the user needs; it does not reduce scope to one generic gauge.

| Family | Capabilities covered | Primary visualization | Interaction |
| --- | --- | --- | --- |
| Scaled readings | Bluetooth dBm, magnetic field µT, pressure hPa, speed m/s | Calibrated dial or rail with stable value, unit and meaningful range | Select a source; log or record; hold a chart point |
| Alignment | Level and rotation | Bubble/crosshair for level; angular-rate scale and trace for rotation | Physical alignment can use a camera backdrop; retain phone-flat use |
| Bearing and direction | Magnetic heading, optional Nearby Interaction direction | Compass rose or phone-relative direction vector with explicit reference frame | Turn to align; distinguish unavailable direction from distance-only |
| Signed change | Relative elevation and baseline deltas | Zero-centered ruler with sign and named origin | Reset or choose a compatible reference deliberately |
| Time traces | Vibration g RMS, sound dBFS, readings over time | A legible waveform/history and value, with gaps and time scale | Scrub actual samples; pin and return to live together |
| Comparison | Compatible baselines and recordings | Same-scale paired values and traces; difference first | Switch references without losing source and time context |
| Discrete device state | Battery charge/power/thermal state, cellular registration | Readable value and categorical state rows with observation time | Do not draw a temperature gauge for thermal state or fake cellular signal |
| NFC inspection | Identity, contents, storage and read diagnostics | Structured records, supported fields, measured capacity and a diagnostic sequence | One deliberate read, then inspect/save; preserve raw/malformed records |
| Request and transfer evidence | Network request phases, consistency, cellular route-verified performance, local peer benchmarks | Phase waterfall, latency distribution/trace and failure timeline; verified route | User-selected endpoint/test; honest successes/failures and stopped state |
| Forecasts and delayed history | Cellular service forecasts and MetricKit reception history | Forecast interval timeline with confidence; historical histogram with collection dates | Predictions and delayed observations remain distinct from current evidence |
| Paired radio and ranging | Wi-Fi Aware optional reports, Nearby Interaction distance/direction | Timestamped named metrics; distance plus optional relative bearing | Preserve pairing/verification; stale readings expire and absent fields stay absent |
| Camera distance and dimensions | Clearance/distance, width/height/separation | Full camera canvas, target reticle or retained endpoints, on-scene dimension label | Opens directly; set point, undo, capture; no extra camera-start tap |
| Surface and depth | Plane orientation/fit/residuals, depth grid and categorical confidence | Camera target patch, residual plot; measured depth color scale plus separate confidence | Switch spatial mode in place; retain framing and current session |
| Room geometry | Observed mesh, RoomPlan components, dimensions, room revisions and placed observations | Camera during capture/revisit; inside/outside mesh and plan for inspection | Enter capture directly; preserve reversible trim and revision provenance |

Shared craft must also cover preparing, denied/unavailable, measuring, paused, held sample, recording, interrupted, saved and empty comparison states. Native Dynamic Type, light/dark and tablet composition are requirements for implementation, not claims established by concept images.

## Incumbent critique

- The selector, room control, mode selector, baseline button and action dock carry too much similar visual weight. The user has to look past controls to reach the measurement.
- The dial's geometry, large value and interpretation do not yet feel like one carefully composed instrument.
- History, baseline selection and calibration lack a clear supporting hierarchy.
- Tablet layout mostly stretches a centered phone composition. A later native build should compose the dial and evidence together at tablet scale.
- Premium craft should come from exact type, meaningful geometry, control hierarchy, data-linked motion and composed empty/error states.

## Mobbin references inspected through Aside

| Reference | Useful quality | Application to MagicCuts |
| --- | --- | --- |
| [Ultrahuman](https://mobbin.com/screens/5326ce88-bcbf-484c-b0fd-56b88a8b2871) | The reading and its curved time scale form a single focal unit. | Integrate value, unit, state and instrument geometry. Keep gradients and card framing specific to that product. |
| [Tide Guide](https://mobbin.com/screens/16f36ef3-02a7-4502-869a-838ffc657f92) | A central dial and a wide trace give different data different amounts of space. | Give the dial authority and the trace a quieter but readable supporting role. |
| [Oura](https://mobbin.com/screens/03958157-6ab8-4046-9a49-ebf639baa348) | One reading, one interpretation and clear semantic status lead the page. | Keep the meaning adjacent to the measurement. Preserve MagicCuts' system typography and plain canvas. |

These are observed design references, not claims about those products' performance. No Mobbin collection or account state was changed.

The user's primary craft reference is now [Tempo on Mobbin](https://mobbin.com/apps/tempo-ios-d925fdfc-328a-4359-89ea-c4a585cc1c50/a9edc931-0169-4b59-948e-19fb936c5ffa/screens). Its [plan-progress screen](https://mobbin.com/screens/a0f3e344-7fef-4a70-89f7-05fe6183e6fd) and [body-composition report](https://mobbin.com/flows/2f28f2af-28e3-4886-8191-e790cf55b911?tab=screens&scrollToScreenIndex=4) were inspected through Aside, along with the scan-flow overview. The useful design qualities are softly rounded groups, capsule actions and tracks, restrained tonal depth, meaningful diagrams and related value/interpretation/plot regions. The body report's selected blue wash is Mobbin's screen-selection overlay, not Tempo's surface color. The camera flow did not expose a live camera feed; MagicCuts' camera-default rule comes directly from the user.

## Direction workshop

Mechanism: MagicCuts turns locally available sensor signals into understandable readings, repeatable evidence and Shortcuts inputs. The user is holding a phone while setting up or testing equipment. The cultural home spans precision instruments, camera metering, field records and measurement graphics.

Avoid the two obvious ruts: a generic dashboard of sensor cards and a decorative science-fiction control panel. Seven grounded systems, ordered before presenting the hand:

1. Field chronometer: fine chapter rings and one authoritative reading; the most immediate match to the watch-level craft commitment.
2. Survey notebook: readings become concise observations with clear provenance.
3. Studio monitor: a live trace and stable level scale support repeated adjustment.
4. Camera metering display: one reading in a stable optical field, with a calibrated rail and instant state changes.
5. Transit timetable: a disciplined grid for comparisons and timed observations.
6. Orienteering atlas: scale-aware geometry and sparse meaningful annotations.
7. Service manual: measurements link to concise method and uncertainty explanations.

Impeccable direction seed `4de84d38` assigned candidate 4. Focus presents that assignment; Calibre presents the top grounded candidate. Six catalog alternatives were translated to the same native/product constraints and judged on audience identification and product clarity. Each was declined on both axes; its useful discipline is explicitly carried into Focus. Full verdicts, risks and adopted disciplines are in the decision payload.

Focus: a camera-meter structure, horizontal scale, stable reading field and compact supporting trace. Selecting a historical point holds the value and indicator together; Return to live releases them. Risk: less of a watch-face identity.

Calibre: a large open dial with precise chapter-ring typography, controlled tick hierarchy, a slender data needle, and a quieter evidence trace. Source and state belong to the reading; controls frame the instrument. This was the initial recommendation before the user's Native Utility selection. Risk: familiar metaphor whose distinction relies on craft.

Native Utility: the user's selected direction, with compact system controls and grouped content. Its premium character will come from deliberate shape relationships, surface depth and careful measurement graphics.

## Approved artifacts and outcome

The session used an interactive composition board in Aside, with seed `4de84d38`. After selecting Native Utility, the user compared the selected reference, a unified reading composition, and C · Soft forms. They approved C with “lets go with it.” The approved flag and exact prompt are preserved in its JSON sidecar.

- [Selected Native Utility reference](../../.impeccable/mocks/native-utility/selected-reference.png)
- [C · Soft forms, approved Home](../../.impeccable/mocks/native-utility/home-trace.png)
- [Camera study](../../.impeccable/mocks/native-utility/camera-soft.png)
- [Visualization family study](../../.impeccable/mocks/native-utility/visualization-families-v2.png)

The camera study carries the selected geometry into a light control tray while leaving the camera immediately visible. The family study applies the same surface language to representative measurement forms. These are concept images with illustrative data, carrying their embedded generation prompt or source origin; the application renders native controls, geometry and real camera content instead of these rasters.

The [Native Utility brief](2026-09-12-native-utility.md) describes shape and depth decisions. The [direction contract](../../.impeccable/surfaces/magiccuts-pro-proexperience-swift.md) binds the approved composition to the real Home journey. Earlier build-helper state remains in the local session archive; it is not evidence for this redesign.

The native implementation covers phone/tablet, light/dark, large text, every visualization family, and automatic entry into appropriate camera tools. The finish reviewer required the phone calibration action to fit above the dock; the correction passed the reviewer's verdict. [Native validation](../NATIVE_UTILITY_VALIDATION.md) records the actual screenshots, tests, tool limitations and remaining physical-device acceptance.
