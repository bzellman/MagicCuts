# MagicCuts validation

Updated September 9, 2026. Implementation and review are complete; the hardware acceptance items listed below remain open. No App Store release is claimed.

## Build and review

- All three targets use Swift 6 and complete strict concurrency in Debug and Release. Release device-target compilation passed with zero warnings (`/tmp/MagicCuts-b54f-release-final.log`).
- The requested bounded code-simplifier pass extracted identical persistence save/rollback/rethrow handling. Independent fresh-context logic review approved the resulting Swift surface with no actionable defects. See `.impeccable/review/simplification.md` and `fresh-logic-review.md`.
- Native visual review found two issues: largest-phone mode-label overlap and missing native phase records. Both were resolved; the verdict pass returned **ship** for those fixes. See `.impeccable/review/native-finish-review.md`.
- `DESIGN.md` and `.impeccable/design.json` describe the actual SwiftUI tokens and controls. Native-equivalent evidence is in `.impeccable/build/native-state.json`; web CSS, raster, and pixel-diff gates are not claimed as passed.

Curated review screenshots are committed under `docs/screenshots`. Raw logs, result bundles, and capture manifests referenced below are local development evidence.

## Automated evidence

| Scope | Result |
| --- | --- |
| 13 unit tests | Passed after simplification: classifications/bounds, full observation window, cancellation and session replacement, migration, persistence/history/sync failures, latest intent settings and errors. |
| Six normal UI journeys | Passed: light/dark captures; permission/off/empty/stale recovery; persistent resume and invalidation; interrupted tests; modes/drafts/history; welcome/unnamed/cancel/save/Shortcut confirmation. |
| Largest phone text | Passed after native Cancel presentation and stacked-mode fixes. Contrast, hit-region, description, and trait audits remain enabled. Apply is verified by reopening the editor and reading the saved value. |
| iPad light/dark and largest text | Passed; captures in `.impeccable/review/ipad-final/manifest.json`. The subsequent stacked-mode change was captured and reviewed on phone. |
| Shipping raster provenance | 0 shipping rasters, 0 missing metadata; interface uses SwiftUI and SF Symbols. |

Logs: `/tmp/MagicCuts-b54f-post-simplification.log`, `/tmp/MagicCuts-b54f-mode-ax-fixed.log`, and `/tmp/MagicCuts-b54f-ipad-final.log`. Current phone evidence: `.impeccable/review/phone-current/manifest.json` and `.impeccable/review/phone-ax-final/manifest.json`. The latter supersedes earlier largest-text captures.

UI tests use an injected radio and a 600 ms observation window only with the Debug `--uitesting` flag. Production uses ten seconds after radio readiness. The simulator cannot establish physical proximity reliability. The UI confirmation button proves saved UI state, not actual execution in Shortcuts.

## Physical evidence

- Signed build installed and launched on the paired iPhone.
- Read-only before/after SQLite comparison verified both existing saved devices and all seven original stored columns were preserved; the validation timestamp column and history table were added.
- Production-radio discovery test passed without `--uitesting`: received a real advertisement, stopped scanning, and verified the Start control returned. It did not save or rename any device. Result: `/tmp/MagicCuts-b54f-signed/Logs/Test/Test-MagicCuts-2026.09.09_19-57-34--0500.xcresult`.

## Open acceptance

- Actual user Shortcut execution nearby and away, including foreground/background conditions. The source and injected tests verify Bool/error semantics; host execution remains unverified.
- Physical VoiceOver navigation and announcements. Automated accessibility audits provide partial evidence only.
OS-enabled Reduce Motion journey passed on the iPad simulator: UIKit confirmed Reduce Motion was enabled, then the modes/threshold draft/history journey completed. Evidence: `/tmp/MagicCuts-b54f-reduced-motion.log`. Source guards all custom animations with the system Reduce Motion environment.

Historical intermediate failures and fixes are retained in `.impeccable/review/validation-history.md`.

PR preparation caught identical light/dark captures caused by an ignored launch preference. The Debug UI-test fixture now explicitly selects the requested SwiftUI color scheme; the capture test passed and the corrected images were verified to differ, with the dark rendering visually inspected. Evidence: `/tmp/MagicCuts-pr-capture.log`. Production appearance still follows the system.
