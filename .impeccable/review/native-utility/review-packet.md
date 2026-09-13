# Independent finish review packet

Review MagicCuts native iOS/iPadOS implementation of the user-approved C · Soft forms. Worktree: /Users/bradzellman/.codex/worktrees/559c/MagicCuts (physical /Volumes/External Use/DeveloperResources/usr/.codex/worktrees/559c/MagicCuts).

User requirements: preserve the cleaned-up Home/Settings journey; deliver a premium native finish; investigate element shapes, depth and design language using Tempo in Mobbin; cover every measurement visualization family; physical/LiDAR tools open into camera by default where appropriate, without an extra Start LiDAR tap. Latest user approval: lets go with it.

Visual authority: .impeccable/mocks/native-utility/home-trace.png and its approved JSON sidecar; it is C · Soft forms, despite the old file slug. Camera language study: camera-soft.png. Family study: visualization-families-v2.png (concept, not physical evidence). Original screenshot plus Tempo observations and direct Mobbin links are in docs/design/2026-09-12-native-utility.md.

Direction contract: .impeccable/surfaces/magiccuts-pro-proexperience-swift.md. Product truth: PRODUCT.md. The existing DESIGN.md describes the superseded calibre styling and will be replaced after review; do not grade against that old visual world.

Source: MagicCuts/DesignSystem.swift, Pro/ProExperience.swift, Pro/InstrumentComponents.swift, Fieldwork/SpatialInstrumentStage.swift, Fieldwork/FieldToolsView.swift, Fieldwork/RoomsView.swift, Fieldwork/FieldCaptureViews.swift and Fieldwork/PeerInstrumentView.swift. FieldDemo.swift extends explicitly labeled DEBUG UI-test fixtures, never live sensor results.

Build evidence: .impeccable/build/native-spec.md, native-fidelity-spec.json and native-utility-state.json, plus generic state.json and spec.json. The generic grid helper overlaps the phase crop with the number and ranks only Google Fonts; the implementation keeps the user-pinned SF/SF Rounded. Exact region rectangles are provided in native-fidelity-spec.json. No web gate or Google font match is claimed as native proof. No HTML/CSS detector ran: it has no verdict on SwiftUI. Judge in native conventions.

Read /Users/bradzellman/.agents/skills/impeccable/reference/craft-floor.md and reference/ios.md. The user-pinned soft panels, rounded reading typography and native utility hierarchy override generic category bans. Honor native safe areas, 44pt touch targets, Dynamic Type, dark appearance, Reduce Motion, units and missing observations. Physical LiDAR accuracy/camera frames are not proven by simulator captures.



## Required screenshot manifest

All paths are relative to `.impeccable/review/native-utility/`. Phone captures are native XCTest app captures at 1206x2622, iPhone 17 Pro on iOS 26.5; tablet captures are native simulator screen captures at 1640x2360, iPad Air 11-inch M3 on iPadOS 26.5. Each file below was opened for capture validity. Scrolled captures are intentionally named reading/chart/controls/detail and supplement the top viewport. Test fixtures are visibly labeled; camera unavailable is the genuine simulator capability result.

- `phone/pro-live-light.png`
- `phone/pro-live-dark.png`
- `phone/pro-inspect-dark.png`
- `phone/pro-compare-dark.png`
- `phone/pro-tilt.png`
- `phone/pro-vibration.png`
- `phone/pro-rotation.png`
- `phone/pro-magnetic.png`
- `phone/pro-pressure.png`
- `phone/pro-altitude.png`
- `phone/pro-heading.png`
- `phone/pro-speed.png`
- `phone/pro-sound.png`
- `phone/pro-network.png`
- `phone/pro-battery.png`
- `phone/pro-largest-text.png`
- `phone/pro-largest-reading.png`
- `phone/pro-largest-chart.png`
- `phone/pro-largest-controls.png`
- `phone/native-camera-distance.png`
- `phone/native-room-camera.png`
- `phone/room-mesh-dark.png`
- `phone/room-plan-dark.png`
- `phone/family-Depth patch.png`
- `phone/family-depth-confidence.png`
- `phone/family-Surface patch.png`
- `phone/family-Cellular outlook.png`
- `phone/family-Cellular history.png`
- `phone/family-Peer range.png`
- `phone/family-At the window.png`
- `phone/family-At the window-detail.png`
- `phone/family-Desk tag.png`
- `tablet/home-light.png`
- `tablet/home-dark.png`
- `tablet/home-largest.png`

## Final supplementary manifest

The following captures are now final inputs for the full review. Each was opened and matches its named state. Spectrum is intentionally a scrolled detail with the full plot and its axis/source labels, produced by the real spectrum function from a DEBUG-only illustrative waveform. iPad sheets are their actual native floating presentation; underlying Home is dimmed.

- `phone/pro-vibration-spectrum.png`
- `phone/pro-recording-dark.png`
- `phone/pro-export.png`
- `phone/pro-field-reports.png`
- `phone/pro-start-flow.png`
- `tablet/pro-largest-text.png`
- `tablet/pro-largest-controls.png`
- `tablet/native-camera-distance.png`
- `tablet/native-room-camera.png`
- `tablet/room-largest-text.png`
- `tablet/field-tool-NFC inspector.png`
- `tablet/field-tool-Network tests.png`
- `tablet/field-tool-Cellular.png`

This completes the visual input manifest. The tablet largest Home and automatic camera navigation tests pass. Two tablet accessibility runs exposed XCTest sampling content below the floating sheet's bottom edge (Cellular explanatory text and offscreen Reset view); the test viewport calculation is corrected, and those focused reruns are pending. The underlying text uses the existing readable secondary token. These are test/evidence changes, not product UI corrections. The baseline/export/report, Start Flow and spectrum completion run passed 3/3.

## Native execution evidence

`phone-reviewed.xcresult` completed with 5 passing journeys: Home accessibility (with one narrowly verified Room composite sampling false positive), all 12 actual instrument selections plus largest-text audits, automatic camera entry/mode switching/reentry, room mesh and plan dark appearance, and seven saved visualization families. One baseline/export/report journey reached and captured Compare, recording, saved mark and export but failed because an unscoped test tapped the obscured Home Settings button as Back; its scoped navigation rerun is underway. The earlier field-tool ready-state accessibility journey passed. No failed aggregate is reported green.

Native implementation state is `.impeccable/build/native-utility-state.json`, supported by source and these captures. Generic `state.json` intentionally still has its web-oriented hero gate open; no fabricated pass and no native CSS detector. Exact comp rectangles and final native captures feed `.impeccable/review/diff/final/`: 76% overall, with safe-area/position drift and specific missing/contradicted crop labels that require native visual judgement, not a blanket pass. The build thread opened the side-by-side and worst region pairs. The authoritative full native implementation remains the approved comp translated into native safe areas, SF text, 44pt controls, truthful durations, and camera states. Your actual verdict will be recorded in the native ledger.

Local StoreKit 26.5 configuration failed before purchase (same environment limitation documented in the existing PRO_VALIDATION.md); no commerce source changed. This visual delivery makes no new physical-device, live LiDAR, App Store or purchase acceptance claim.
