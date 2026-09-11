---
version: 2
slug: onboarding-motion
primary_target: prototypes/onboarding
related_targets: []
---

# Onboarding instrument-card revision

September 10, 2026. User-selected refinement of the native onboarding prototype: take the instrument visuals into widget-like cards, vary their size for their purpose, and light one active card at a time while the explanation above changes smoothly. Reference: 60fps shot 0951, ShutEye Patent Award Graph Animation. This remains a review prototype with synthetic data and simulated purchase. Final price remains undecided.

## Direction contract

THESIS: A stable collection of instruments makes the app's breadth tangible; one highlighted instrument and one short explanation at a time make the collection understandable.

OWN-WORLD: Preserve the approved MagicCuts field chronograph: adaptive Action blue, quiet canvas, native SF and rounded tabular readings, precise ticks and native navigation. Widget-like instrument cards are explicitly requested for this onboarding surface. They do not redefine the production instrument workspace or its design system.

STORY: Level centers; Bluetooth signal strengthens; vibration settles; a magnetic heading approaches north; elevation rises from its starting reference. The active card changes with the text above. Tap any instrument to take over. Continue to the one-time offer when ready. Simulated purchase leads into the first Level measurement.

FIRST VIEWPORT: Native MagicCuts bar, two-line explanatory heading and short sentence, then a stable five-card mosaic. Level and signal share the first row; vibration spans the full middle row; heading and elevation share the last row. Cards retain their positions. A persistent Explore Pro action remains usable while the tour runs.

FORM: Local extension of the approved field dial, seed 28110c47. A 16pt continuous instrument surface encloses each real data geometry. Color and a thin focus edge identify the active card. Compact dials suit angle and signal; the time trace gets the wide card; the elevation tape stays vertical. The same collection contracts on the Pro offer. In compact phone landscape, compact cards sit beside the narration with a horizontal footer so all five remain visible.

SIGNATURE: Focus passes through the collection, then the data within that one card animates. A cancellable cubic ease-out updates numbers and graphics from the same sampled progress. A new tap freezes the prior reading immediately. The old reading remains in inactive cards; they do not run decorative loops. Narration and focus update together. The tour runs once, can pause or be interrupted by tapping, and never automatically opens a purchase sheet.

FINISH: fresh finish review and documentation comparison complete the revision. Preserve incumbent DESIGN.md and sidecar. All UI is native; no raster instrument plates.

## Motion plan

- Focal moment: a single 18–20 second spotlight tour through five instruments, with stable widget geometry and a reading-specific motion in the active card.
- Continuity: preserve card placement and values; contract the collection into the offer. Text crossfades in a fixed reading region. Standard navigation and sheets remain native.
- Feedback: selected card has a clear label/selected state; pause, replay, skip, cancellation, restore and first-reading actions remain immediate.
- Budget: one short Canvas interpolation at a time, no continuous waveform timer, no blur, particles, or zero-offset glow. Pause on background/disappearance. Reduce Motion presents final values and uses short crossfades; auto spotlighting is disabled in that mode, and manual card selection remains available.
- Verification: one batched inspection round across phone/tablet, light/dark, portrait/landscape, large text, interactive purchase recovery and motion; one bounded fix batch and confirmation; then fresh finish reviewer and documenter.
