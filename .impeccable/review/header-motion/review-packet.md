> Historical initial review packet. The current user-authorized correction is documented in `rejection-verdict-packet.md`, with the final bounded verdict in `rejection-verdict.md`. Current PNG paths contain correction-three captures; earlier review findings describe their earlier exports.

# Header motion finish-review packet

> Original full-review packet retained below. Current correction-2 evidence supersedes the original run names and video timestamps: all 39 PNGs have been refreshed, nine selected UI executions passed, and the bounded second verdict remains **fix**. The portable receipt is `docs/validation/header-motion-evidence.json`. Current test exports are in `tests/`; the current preview is raw phone video seconds 32–42. In-flight frames sample phone seconds 33.95, 34.10, 36.25, 36.30 and tablet seconds 84.55, 84.65, 84.75, 84.85. See `finish-verdict-2.md` for the open transition and Room-symbol findings. Final documentation is pending the user choice required after two correction rounds.

## Request and scope
The user requested a premium native redesign with Impeccable, referenced Tempo on Mobbin, approved C · Soft forms, and then explicitly replaced the Home navigation title with the enlarged source group. They requested charcoal CTAs in light appearance and industrial yellow in dark appearance, styled Calibrate and Start Flow, and camera-first relevant physical tools with fewer taps. These changes are already the incumbent system.

The current authorized extension is: “We shoud have a dope and graceful animated nav mutations (still useful but compressed on scroll).” Review the source header and its scroll transition, readability, retained controls, native safe-area behavior and relevant rendering consequences. This is a full finish review of this extension, not a new whole-app release verdict.

## Authority and native adaptation
Open the required captures and reference images before source or builder descriptions. Current direction contract: `.impeccable/surfaces/magiccuts-pro-proexperience-swift.md`, including the scroll amendment and all six blocks. FORM seed 4de84d38 is corroborated in `.impeccable/mocks/decision/premium-session/native-utility.json`.

Original approved comp: `.impeccable/mocks/native-utility/home-trace.png`. User amendment images: `.impeccable/review/header-actions/request/marked-home.png` and `source-header.png`. Their explicit source-header and charcoal/yellow instructions supersede that comp's old Home title and blue actions. Native build state `.impeccable/build/native-utility-state.json` records this authority; the generic old fixed-region web diff remains failed/open and no passing automated web fidelity gate is claimed. This motion extension is implemented in native code, with no new raster comp or artwork owed.

No separate QUALITY BAR card was produced for the earlier category-standard Native Utility selection. The chosen direction card `.impeccable/mocks/decision/premium-session/native-utility.png` is supplied as critique context. Tempo supplied the earlier shape/depth reference. Do not substitute a web material metaphor for native SwiftUI conventions.

No HTML/CSS detector ran: it does not apply to SwiftUI. Read `/Users/bradzellman/.agents/skills/impeccable/reference/craft-floor.md` and `/Users/bradzellman/.agents/skills/impeccable/reference/ios.md`. Reviewer contract: `/Users/bradzellman/.agents/skills/impeccable/reference/degraded/finish-reviewer.md`; this is a fresh independent default-agent substitution because the named reviewer role is unavailable. Do not run a browser, build, simulator or new detector.

## Required native evidence
Phone is iPhone 17 Pro, 402×874pt portrait. Tablet is iPad Air 11-inch M3, 1180×820pt landscape and 820×1180pt portrait. All captures have full-display pixels; some tablet PNGs retain an orientation metadata tag. Inspect their rendered orientation, not just IHDR dimensions. In-flight images are intentionally actual animation frames, not alleged settled states. Captures show explicit sample data, not physical sensor proof.

- `.impeccable/review/header-motion/phone/motion-expanded-light.png`
- `.impeccable/review/header-motion/phone/motion-compact-light.png`
- `.impeccable/review/header-motion/phone/motion-expanded-dark.png`
- `.impeccable/review/header-motion/phone/motion-compact-dark.png`
- `.impeccable/review/header-motion/phone/motion-long-title-light.png`
- `.impeccable/review/header-motion/phone/motion-largest-standard.png`
- `.impeccable/review/header-motion/phone/motion-reduced-compact.png`
- `.impeccable/review/header-motion/phone/pro-largest-text.png`
- `.impeccable/review/header-motion/phone/motion-in-flight-01.png`
- `.impeccable/review/header-motion/phone/motion-in-flight-02.png`
- `.impeccable/review/header-motion/phone/motion-in-flight-03.png`
- `.impeccable/review/header-motion/phone/motion-in-flight-04.png`
- `.impeccable/review/header-motion/tablet/motion-expanded-light.png`
- `.impeccable/review/header-motion/tablet/motion-compact-light.png`
- `.impeccable/review/header-motion/tablet/motion-expanded-dark.png`
- `.impeccable/review/header-motion/tablet/motion-compact-dark.png`
- `.impeccable/review/header-motion/tablet/motion-long-title-dark.png`
- `.impeccable/review/header-motion/tablet/motion-tablet-portrait-expanded-light.png`
- `.impeccable/review/header-motion/tablet/motion-tablet-portrait-compact-light.png`
- `.impeccable/review/header-motion/tablet/motion-tablet-portrait-expanded-dark.png`
- `.impeccable/review/header-motion/tablet/motion-tablet-portrait-compact-dark.png`
- `.impeccable/review/header-motion/tablet/pro-largest-text.png`

Additional restored, light/dark, reduced-motion and at-rest/accessibility-state captures are in the same phone/tablet folders. All captures are native. Motion preview: `.impeccable/review/header-motion/phone/header-motion.mp4` (real native recording, 21–30 seconds from `/tmp/magiccuts-header-motion-final-phone.mp4`). In-flight frames sample raw video 27.3–27.7 seconds. PNG origins are embedded; no raster ships in the app.

## Source and runtime evidence
Primary source: `MagicCuts/Pro/ProExperience.swift` (InstrumentWorkspaceView, header controls and observations), `MagicCuts/Pro/InstrumentHeaderLayout.swift` (stable four-subview Layout and quantized scroll regions). Relevant supporting diff: `MagicCuts/Pro/InstrumentComponents.swift` (chart transaction), `MagicCuts/AppRuntime.swift` (DEBUG reduced-motion test fixture), `MagicCutsUITests/ProExperienceUITests.swift` (functional navigation, cycles, type, portrait fitting vs overflowing content).

PRODUCT.md exists. DESIGN.md and .impeccable/design.json contain the incumbent world; approved motion tokens and adaptation will be reconciled by the required documenter after this review. Review their palette and native world as incumbent; documentation handoff is still pending.

Passing current functional cases: phone-confirmed xcresult (three cases: both-appearance all-four-control navigation and repeated folds, largest standard type, forced reduced-motion path); tablet-landscape xcresult (same all-control navigation and cycles); tablet-portrait-confirmed xcresult (both appearances, fitting Bluetooth content retains the expanded header and overflowing vibration evidence folds). Result summaries and trees are `.review/header-motion/*-summary.json` and `*-tests.json`. Initial Home accessibility and largest AX cases also passed on both classes; those unchanged at-rest/AX captures are reused and identified as such. No device frame-rate or physical sensor claim is made. The iPad display retained landscape despite UIDevice orientation changes; a dedicated fresh simulator supplied actual portrait proof.

## Return
Return `disposition: ship`, `fix`, `rebuild`, or `recapture` and the five exact reviewer sections (persistence, fidelity, ceiling, material_fixes, keep); a recapture uses its single required section. Write the same report to `.impeccable/review/header-motion/finish-review.md`. You own only that report and must not edit application source, tests, documentation or existing review files. You are not alone in the codebase; preserve all other work.
