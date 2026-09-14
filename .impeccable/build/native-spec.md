# Native Utility implementation specification

Approved on September 12, 2026: C · Soft forms (`home-trace.png`). Preserve the real Home/Settings journey from `v1-home-instrument-sheet`, plus Bluetooth and mesh fixes merged from current main.

The 852×1846 concept represents a 393×852-point phone. Native system chrome, safe areas and 44-point touch regions determine final layout. `native-exact-regions.json` records the measured concept rectangles. The generic grid helper includes overlapping crops (notably phase overlaps the numeral), so its font measurements and generated CSS are advisory; its Google Fonts ranking cannot supply the user-pinned San Francisco. The SwiftUI implementation uses SF body styles and SF Rounded scaled tabular readings. No CSS or Google font is shipped.

- Canvas: existing adaptive cool pale canvas. Content: secondary system grouped background, continuous 24pt corners, 12pt Home reading/history insets and 18pt field evidence insets. White selected capsule uses a black 10% contact shadow, radius 2, y=1.
- Source: compound two-row group, two equal actions followed by source. 44pt minimum rows. Large type stacks the actions.
- Modes: 44pt interactive segments, 3pt selected-shape inset; neutral track and white selected capsule. At accessibility sizes, native menu. Native sheet transitions and Reduce Motion-aware selection are the authored motion.
- Scalar: 140-degree open upper arc, 7pt track, seven ticks, 14pt reading marker plus 2pt separation. Threshold region or observed middle interval has a defined data meaning. No decorative needle.
- Level: true two-axis gravity bubble; Compass: circular magnetic bearing; elevation: signed ruler around session zero; battery: charge and categorical system state. Runtime charts retain unavailable gaps, circular segmentation, genuine units, baselines and source provenance.
- Reading: 66pt SF Rounded semibold, ScaledMetric, tabular; unit uses callout. Phase and interpretation are separate callout lines.
- History: separate white evidence group, true elapsed time and reading units. The title is Recent readings instead of the concept's Last 20 seconds because retained session duration varies. Compact phone Bluetooth Gauges use a 75pt chart and 6pt chapter spacing; its reading shares the arc's lower interior so Baseline and the full 44pt calibration action fit above the dock. Other phone instruments use 90pt history; accessibility sizes retain scrolling reflow.
- Baseline: single 50pt grouped row. Log and Record use matched 52pt capsules; Start Flow is a 44pt quiet action.
- iPad: reading and evidence side by side, maximum content width 1040pt; actions cap at 720pt. Accessibility sizes restore a vertical scrolling composition.
- Spatial tools: camera immediately on entry, native navigation, 28pt top-corner light tray; tablet side panel 360pt. Modes do not restart the camera. Owned sessions stop on dismissal; already-located room sessions are reused. Normal camera permission, denial, unsupported hardware and interruption stay explicit. A simulator fallback is not live-camera acceptance.
- Assets: native SwiftUI, Charts, Canvas and SF Symbols only. Zero raster plates ship. The camera concept is illustrative; production uses RoomCameraView.

Verification: native simulator captures, behavior tests, accessibility audits, independent Impeccable finish review. Generic HTML/CSS detection does not judge SwiftUI. Evidence and final disposition are recorded in the native build state and review report.
