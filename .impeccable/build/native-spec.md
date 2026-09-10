# Native implementation contract

Approved references: `../design-system/control-surfaces-v2.png` (user: “I dig it”) and `../mocks/onboarding-discovery.png` (user: “Approved”). Both are component/comparison boards with drawn device frames, not single-device screenshot goldens. Review the corresponding native regions and interactions. Do not claim a whole-board pixel-diff score against one simulator screenshot.

## Semantic and spatial mapping

| Reference region | Native component | Required evidence |
| --- | --- | --- |
| Quiet back/device navigation | NavigationStack, inline native title, Rename | Native navigation, escape paths, no invented top-level tabs |
| Underlined Simple/Technical | ModeTabs | Same settings; remembered mode, selected accessibility trait |
| Navy threshold instrument | SignalGauge | Real text, ticks, chosen threshold; directly adjustable scale and 48pt steppers in contained sheet |
| Joined Test nearby/Test away | DeviceDetailView controls | Separate actions in one outer well; running state exposes Stop; no stuck controls after interruption |
| Plain Configure Shortcut handoff | HandoffRow | Supported ShortcutsLink and explicit user confirmation; no auto-trigger or template promise |
| Welcome board left | WelcomeView | Short, skippable, no Bluetooth initialization until scan starts |
| Discovery board right | DeviceDiscoveryView | Native search, sort, expandable identity observation, unnamed support, stale state, explicit naming/save |

## Native adaptations

- Text is SF through SwiftUI text styles and Dynamic Type. The web font catalog/CSS-ranking step would change the user-approved native typography; it is replaced by native text-style and large-content-size inspection.
- Every interface element is live SwiftUI. There are no generated raster plates inside the app; the user explicitly required real controls. The existing icon is the only pictorial product asset.
- Gauge span is −100 to 0 for a truthful linear display of supported settings; editable maximum is −1 because 0 is not a valid Bluetooth RSSI. The board’s narrower example range is not used to exclude existing supported thresholds.
- iOS 26 owns navigation bars, sheets, keyboard, search, focus, and accessibility behavior. No web CSS detector runs on this SwiftUI app.
- Normal phone content uses 20pt insets and a 640pt maximum reading column on iPad (600pt in the threshold sheet). Controls are at least 44pt; steppers 48pt and primary actions at least 52pt.
- Motion is limited to mode selection, threshold numeric changes, discovery expansion, and a native welcome symbol. Every authored animation reads Reduce Motion; no parallax, custom navigation, or continuous scan decoration.

## Review matrix

Phone and iPad: light/dark home, detail, threshold sheet, Shortcuts guide. Phone: welcome, discovery identity, naming. Both: largest Dynamic Type and accessibility audit. Functional tests cover persistence/migration, full sample window, boundary classification, errors, cancellation, stale/empty/denied discovery, explicit draft save/cancel, history, resumed setup and Shortcut confirmation.

Physical radio and actual Shortcuts execution must be reported separately from simulator evidence. Native finish review and post-simplification verification remain required; this document does not certify them.
