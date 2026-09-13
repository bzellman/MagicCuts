---
version: 1
slug: "magiccuts-pro-proexperience-swift"
primary_target: "MagicCuts/Pro/ProExperience.swift"
related_targets: ["MagicCuts/Pro/InstrumentHeaderLayout.swift","MagicCuts/Pro/InstrumentComponents.swift","MagicCuts/DesignSystem.swift","MagicCuts/Fieldwork/FieldToolsView.swift"]
---

# Native Utility implementation
Mode: Operate. Scope: Home, all instrument visualization families, shared field evidence and camera-first spatial tools. Preserve the accepted Home/Settings journey, truthful units, compatible baselines, Log/Record/Start Flow, and native accessibility.
Approved comp: .impeccable/mocks/native-utility/home-trace.png. User approval: "lets go with it", September 12, 2026. The subsequent marked native screenshots and explicit charcoal/yellow/header request amend that comp: no Home title, enlarged source header with Settings, and styled Calibrate/Start Flow. Those user instructions are the authority for this refinement.

## Direction contract
THESIS: The measurement leads within a carefully made native utility. Every surrounding control has a clear relationship to it.
OWN-WORLD: Cool pale canvas, white adaptive groups, continuous soft corners, shallow selected pills, capsule actions, charcoal/yellow adaptive actions and measured interval teal; SF Rounded tabular readings with SF system labels.
STORY: Select the tool and source, understand its reading and evidence, then log, record or start a workflow. Relevant physical tools reveal the camera immediately.
FIRST VIEWPORT: One enlarged, persistent two-row source header with integrated Settings, Gauges/Info/Compare, a semicircular reading panel, separate history, baseline and outlined calibration, then the Log/Record pair and outlined Start Flow. Native safe areas and large text preserve reachability; at accessibility text sizes the header joins the scroll flow so it cannot consume the reading viewport. Tablets arrange related reading and evidence side by side.
FORM: Native Utility, the user's standing category-standard choice; C · Soft forms is the approved composition. Seed 4de84d38. Tempo is the shape/depth craft reference.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Scroll mutation amendment
User: “dope and graceful animated nav mutations (still useful but compressed on scroll).”
Focal moment: the expanded source group folds from two rows into one compact control bar while reading evidence; it unfolds near the top. The initial expanded header and charcoal/yellow world stay authoritative.
Continuity: retain the same Instrument, Room, Source, and Settings control identities while their layout changes. Instrument and Source remain labeled; Room and Settings become native icon controls. No new menu layer or extra tap.
Feedback: preserve existing pressed, disabled, selection and native sheet states. Use a brief, interruptible, settling transition and spaced scroll thresholds to prevent flicker.
Budget: native SwiftUI layout and opacity only, no dependency or continuous renderer. Observe scroll regions rather than rebuilding measurement charts on every pixel. Compact labels keep native sizing and omit redundant instrument symbols; longer labels wrap inside their own cells within one navigation row. Large accessibility text keeps the existing scrolling stacked header; Reduce Motion removes spatial interpolation.

September 13 correction authority: the user authorized one more pass, then rejected the narrow two-row Magnetic field compact header with “This is a no go.” The rejection is preserved at `.impeccable/review/header-motion/request/rejected-compact.png`. Compact navigation must be a composed bar with labeled Instrument and Source and equal Room/Settings icon targets, without detached circles. The enlarged two-row expanded group remains the accepted starting state.
