# Source header and adaptive action refinement

Validated September 12, 2026 on the native SwiftUI app. This follows the user’s marked Home screenshot and source-group crop. The source group now replaces the Home navigation title, with larger 56pt rows and integrated Settings. Calibrate and Start Flow have defined outlined controls. Actions use charcoal in light appearance and industrial yellow in dark appearance, with adaptive lettering on filled actions.

## Runtime verification

The focused iPhone and iPad cases pass for light/dark Home accessibility, largest Dynamic Type and reachable lower controls, Start Flow navigation, and the new source-header navigation case. The latter opens Settings and calibration, switches to Magnetic field through the native picker, preserves header position during scrolling, and verifies orientation-appropriate access to Settings and Start Flow. iPhone remains portrait under its existing configuration; iPad supports landscape. The iPad camera-entry case also passes for the existing direct-to-camera tool and room flows.

The initial header test incorrectly assumed iPhone landscape support, then assumed the iPad native search field was expanded. The final case follows each platform’s supported orientation and uses the visible instrument filter. Earlier result bundles retain their original failures; the final header reruns pass on both devices. There were no app compiler warnings in the final build. UI source did not change while correcting these test assumptions.

Simulator screenshots establish layout, controls and navigation. They do not establish live camera frames, LiDAR/spatial accuracy, or physical sensor behavior. Those existing physical acceptance boundaries remain unchanged. Measurement, persistence and commerce code were not changed or revalidated by this refinement.

## Visual and documentation review

- Independent full finish review: **ship**, with no material fixes. A fresh default agent followed the Impeccable fallback reviewer contract because the named role was unavailable.
- Independent documentation handoff checked `DESIGN.md` and `.impeccable/design.json` against the native implementation. YAML/JSON and source pointers validate.
- Primary action contrast: 14.51:1 in light appearance and 12.12:1 in dark appearance. Runtime Home accessibility audits also pass.
- Phone/tablet light and dark captures, large text, native sheets, instrument switching and camera availability states are retained under `.impeccable/review/header-actions/`. All 27 images carry origin metadata. No HTML/CSS detector applies to SwiftUI.
- The earlier comp’s Home-title and blue-action details are superseded by this explicit user amendment. Prior evidence remains historical and was not rewritten as current proof.

The portable receipt is `docs/validation/header-actions-evidence.json`. It records source hashes, per-case results, screenshot provenance and the original local result-bundle paths. The earlier dirty `.impeccable/review/native-utility/phone/pro-live-light.png` is outside this change.
