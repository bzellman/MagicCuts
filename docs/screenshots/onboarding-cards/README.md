# Native instrument-card motion evidence

[Watch the card tour](magiccuts-onboarding-cards.mp4) · [Reduce Motion](magiccuts-onboarding-cards-reduced-motion.mp4) · [Source and device receipt](evidence.json)

This revision follows the user-selected 0951 direction: stable widget-like cards, one active instrument, and synchronized narration. The card tour is a native iPhone Simulator recording of ordinary tour behavior followed by a manual Explore Pro tap. Its native presentation timestamps were resampled to 60fps, repeating held frames; only the launch prefix was removed. Both final films passed a complete decode check without warnings or errors. It uses synthetic readings; the offer and purchase recovery are review simulations with no App Store calls or price claim.

## Capture set

- Phone light: all five active instruments, compact offer and first Level.
- Phone dark: compact offer; largest accessibility type on showcase and offer, plus the scrolled restore/terms area.
- Phone landscape: compact five-card mosaic beside narration and a horizontal footer.
- iPad dark: signal showcase, accessibility showcase and offer. The wide-window capture shows an actual landscape-shaped app window in a portrait display.
- Rapid re-selection: start/end captures accompany the exact frozen-value check.

The largest-type surfaces are native scrolling views; top and scrolled captures are deliberately separate. Normal text uses the visual mosaic; accessibility sizes use semantic reading cards and manual progression.

## Verification

`bash prototypes/onboarding/build.sh` completed with Swift warnings treated as errors. Source and binary hashes are in `evidence.json`. Native accessibility queries and taps verified the five card explanations and readings, preserved prior samples, pause/resume, a complete one-pass tour that stays on the showcase, simulated purchase cancellation/retry/success, first Level, replay and restore. See `interaction-check.txt`, `rapid-tap-check.txt` and `reduced-motion-check.txt`.

Reduce Motion was enabled through the dedicated simulator's Accessibility preference and confirmed by the app's immediate readings, manual Next instrument action and lack of automatic progression. It was reset after recording. VoiceOver labels and selected traits are present; a full spoken VoiceOver walkthrough was not performed.

Only the standalone preview was built and exercised. This is not production signing, physical sensor, entitlement or App Store acceptance. The historical v1 recordings remain under `../onboarding/` and do not validate this revision.

A fresh substitute Impeccable finish reviewer and documenter were used because the specialized roles were unavailable. The review and fix disposition are recorded in `finish-review.md`.
