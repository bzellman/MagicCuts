---
kind: impeccable-documentation-handoff
scope: header-motion
disposition: ship
generatedAt: "2026-09-13T00:46:52-05:00"
authoringRole: default-agent-substitution-for-impeccable-documenter
---

# Header-motion design-system handoff

## Evidence checked

- `MagicCuts/Pro/InstrumentHeaderLayout.swift:3-94`: `InstrumentHeaderLayout` interpolates the expanded and compact frames with one `collapseProgress`; its compact frames use a 56pt minimum and intrinsic common-row height, render Instrument, Source, Room, Settings from left to right, and its scroll regions restore at 12pt and fold at 88pt.
- `MagicCuts/Pro/ProExperience.swift:392-465`: `homeSelector` applies the controls in expanded/accessibility order Instrument, Room, Source, Settings and gives compact accessibility priorities in Instrument, Source, Room, Settings order. `setHeaderCollapsed` uses smooth 0.32s collapse and 0.38s expansion without extra bounce, holds compact labels through expansion, hides dividers during label staging, and makes Reduce Motion immediate. Accessibility Dynamic Type keeps the stacked header in scroll flow.
- `.impeccable/surfaces/magiccuts-pro-proexperience-swift.md:12-27`: the approved Native Utility / C Soft forms contract, FORM seed `4de84d38`, and the correction authority require one composed compact bar and prohibit the rejected two-row/detached-circle fallback.
- `.impeccable/review/header-motion/rejection-verdict.md:3-12` and `rejection-verdict-packet.md`: all four correction findings are resolved, 39 native simulator PNGs were refreshed, and nine selected native UI test executions passed. This evidence does not prove physical camera, LiDAR, sensor, or device frame-rate behavior.

## Durable merge

`DESIGN.md` and `.impeccable/design.json` now preserve the incumbent Native Utility palette, SF/SF Rounded typography, soft grouped material, camera-first policy, source-header identity, and compact Bluetooth Gauges 6pt/75pt/no-arc-padding rule. The update adds only the reused header behavior: expanded two rows fold to one compact bar with a 56pt minimum and intrinsic common-row height; Instrument and Source remain labeled; Room and Settings remain equal icon targets; compact visual/accessibility order is Instrument, Source, Room, Settings; expanded and accessibility-stacked order is Instrument, Room, Source, Settings; thresholds are quantized at 12pt/88pt; and width, height, and four frames share one progress.

The sidecar records the two smooth durations, zero extra bounce, immediate Reduce Motion behavior, and a compact-state source-header preview tied to `homeSelector` and `InstrumentHeaderLayout`. Its shape follows the layout progress; dividers hide during compact-label staging and fade back after expansion. Dark preview utility icons use incumbent industrial yellow. No rejected compact topology, detached icon treatment, physical-camera claim, or temporary review artifact was canonized.

## Validation

- Parsed the `DESIGN.md` YAML frontmatter and `.impeccable/design.json`.
- Confirmed the sidecar remains schema version 2 and its narrative mirrors the merged durable rules.
