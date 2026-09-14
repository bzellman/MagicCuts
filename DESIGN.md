---
name: "MagicCuts Pro"
description: "A native field utility for deliberate, truthful measurements."
colors:
  action: "#242A2F"
  action-dark: "#E7F542"
  on-action: "#FFFFFF"
  on-action-dark: "#242A2F"
  signal: "#0052C7"
  signal-dark: "#61B8FF"
  interval: "#1F6E61"
  interval-dark: "#8FD9C7"
  secondary-label: "#59636E"
  secondary-label-dark: "#A8B3BD"
  canvas: "#F2F5F7"
  canvas-dark: "#0F141A"
  instrument: "#122438"
typography:
  measurement:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "66pt @ScaledMetric relative to Large Title"
    fontWeight: 600
    lineHeight: "native"
    fontFeature: "monospacedDigit"
  title:
    fontFamily: "SF Pro Rounded, system-ui"
    fontSize: "SwiftUI headline or subheadline"
    fontWeight: 600
    lineHeight: "native"
  body:
    fontFamily: "SF Pro, system-ui"
    fontSize: "SwiftUI body, callout, caption, and navigation styles"
    lineHeight: "native"
rounded:
  small-control: "10pt"
  quiet-control: "14pt"
  utility-control: "22pt continuous"
  baseline: "20pt"
  soft-group: "24pt continuous"
  capsule: "26pt"
  action: "28pt continuous"
spacing:
  compact: "4pt"
  regular: "8pt"
  control-gap: "10pt"
  content: "16pt"
  tablet-content: "28pt"
components:
  primary-action:
    backgroundColor: "{colors.action}"
    textColor: "{colors.on-action}; {colors.on-action-dark} in dark appearance"
    typography: "{typography.title}"
    rounded: "{rounded.action}"
    padding: "14pt 16pt"
    height: "52pt minimum"
  quiet-action:
    backgroundColor: "system primary at 5.5% opacity"
    textColor: "{colors.action}; {colors.action-dark} in dark appearance"
    typography: "{typography.title}"
    rounded: "{rounded.action}"
    padding: "14pt 16pt"
    height: "52pt minimum"
  utility-action:
    backgroundColor: "system primary at 2.5% opacity"
    textColor: "adaptive action"
    rounded: "{rounded.utility-control}"
    padding: "10pt 16pt"
    height: "44pt minimum"
  mode-segments:
    backgroundColor: "system primary at 5.5% opacity"
    textColor: "system primary and {colors.secondary-label}"
    typography: "{typography.title}"
    rounded: "{rounded.capsule}"
    padding: "3pt"
    height: "44pt minimum"
  source-group:
    backgroundColor: "secondarySystemGroupedBackground"
    textColor: "system primary"
    rounded: "{rounded.soft-group}"
    padding: "8pt 16pt"
    height: "56pt minimum per row"
  instrument-surface:
    backgroundColor: "secondarySystemGroupedBackground"
    textColor: "system primary"
    rounded: "{rounded.soft-group}"
    padding: "12pt"
---

# Design System: MagicCuts Pro

## Overview

**Creative North Star: "Native Utility / C · Soft forms"**

MagicCuts makes a measurement the center of a native working surface: select the instrument and source, read the current value, inspect evidence, set a compatible baseline, then log, record, or begin a workflow. The user-selected Native Utility world, with its approved C · Soft forms composition, lands as a cool adaptive canvas, quiet grouped materials, broad continuous corners, and rounded tabular readings. It is a utility, not a marketing plate.

The build is SwiftUI for iOS and iPadOS. Native navigation, sheets, menus, SF Symbols, safe areas, system grouped materials, Canvas, and Swift Charts carry hierarchy and interaction. Custom Canvas geometry is reserved for readings such as arcs, levels, compasses, and linear scales. Final review evidence is the native phone and tablet capture set, including light and dark Home, camera-distance, and tablet Home states.

**Key Characteristics:**

- Home uses a persistent source header containing Instrument, Room, Source, and Settings, followed by the Gauges, Info, and Compare evidence choices.
- Standard text sizes fold that header from its expanded two-row group into one stable compact navigation bar; the same four controls remain represented throughout.
- A measurement is prominent, while units, method, uncertainty, and history remain readable and subordinate.
- Charcoal actions in light appearance become industrial yellow in dark appearance; signal blue and interval teal describe observed data.
- Rounded tabular figures stabilize changing readings; surrounding language retains native SF text styles.
- Phone uses a safe-area action dock; regular-width iPad places related reading and evidence side by side.

## Colors

Adaptive color gives the light canvas a cool, quiet working temperature and preserves contrast in dark appearance.

### Primary

- **Action Charcoal / Industrial Yellow:** actions and selection use `action` (`#242A2F`), adapting to `action-dark` (`#E7F542`). Filled actions use white lettering in light appearance and charcoal lettering in dark appearance through `MC.onAction`. These pairs have 14.51:1 and 12.12:1 contrast.
- **Signal Blue:** `ProTheme.signal` uses `signal` / `signal-dark` for data lines, needles, and selected readings.

### Secondary

- **Interval Teal:** `interval` marks a qualified band, threshold, or interpretive state. It adapts to `interval-dark` in dark appearance.

### Neutral

- **Cool Canvas:** `canvas` grounds Pro pages and becomes `canvas-dark` in dark appearance.
- **Native Group:** `ProTheme.face` is iOS `secondarySystemGroupedBackground`, used for soft groups and instrument surfaces rather than a fixed cross-appearance hex.
- **Readable Secondary:** `ProTheme.secondary` uses `secondary-label` for units, interpretation, chart axes, state, and quiet evidence labels, adapting to `secondary-label-dark`.
- **Instrument Ink:** `instrument` is the existing dark calibration-surface asset; it adapts to `#172B40` in dark appearance.

**The Action and Evidence Color Rule.** Use adaptive charcoal/yellow for actions and selection. Use signal blue and interval teal to communicate measured information. Always pair a filled action with the adaptive `onAction` foreground.

**The Opaque Secondary Label Rule.** Use `ProTheme.secondary` for quiet Pro evidence instead of reducing generic secondary text until it becomes illegible.

## Typography

**Display Font:** SF Pro Rounded through SwiftUI’s rounded design.

**Body Font:** SF Pro through native SwiftUI semantic styles.

**Character:** Readings, segment labels, headings, and statistics use rounded weight and tabular figures where they change. Explanations, menus, navigation, and platform chrome retain system styles.

### Hierarchy

- **Measurement** (66pt scalable rounded semibold baseline): the principal live result. Compact comparison reduces this value to half-size while retaining the same type family.
- **Instrument title and mode label** (rounded `.headline` or `.subheadline`, semibold): names sources, modes, methods, and recorded actions.
- **Supporting explanation** (`.callout`): communicates interpretation, baseline difference, truth constraints, and recovery guidance.
- **Evidence label** (`.caption` / `.subheadline`, monospaced where numeric): communicates units, elapsed time, axes, state, method, and uncertainty.

**The Measurement Family Rule.** Apply rounded, semibold, monospaced treatment to a reading and its measurement-adjacent labels. Do not promote explanatory body copy or native chrome to display type.

## Layout

`InstrumentWorkspaceView` is a scrollable native column. Phone content uses 16pt horizontal inset, 8pt top inset, 8pt normal stack rhythm, and a 680pt maximum width; regular-width layouts use 28pt horizontal inset, a 1040pt maximum width, and place a live face plus reference controls beside a 240pt history view. The action dock has a 720pt maximum width and stays inside the bottom safe area.

Home’s source controls replace the root navigation title. One `ProTheme.face` group with 24pt continuous corners is pinned above the reading column, with an opaque canvas behind it while evidence scrolls. In its expanded state, Instrument and Room share a 56pt-minimum first row; the second row pairs Source with Settings. Scroll offset drives a single 0–1 layout progress across that extra row: Instrument and Source keep labels, while Room and Settings become equal 44pt icon targets in the same horizontal control group. The compact row is 56pt minimum and grows at the largest standard Dynamic Type sizes when intrinsic label fitting requires it. Longer labels wrap within their assigned compact cells and never create a second compact row or detached circles. The compact visual and accessibility order is Instrument, Source, Room, Settings; the expanded and accessibility-stacked order is Instrument, Room, Source, Settings. Fitting content does not fold; overflowing content restores the expanded group within 12pt of the top. Instruments using the phone show that source without adding an unnecessary chooser. At accessibility Dynamic Type sizes, Instrument, Room, Source, and Settings stack in reading order and the complete header scrolls with the content, preserving usable room for readings. The mode segment becomes an accessible menu and recording actions also move into the scroll flow. Native sheets retain their navigation bars. Never preserve a capture-specific position by shrinking native text or controls.

The source-header fold uses one layout progress for its container width and height and all four control frames. Progress tracks the finger; it does not run a separate timed layout animation, and it does not rebuild the measurement face. Fold properties only publish when their values change, and Home’s measurement column does not observe fold progress. Labels stay in the tree and fade as their cells shrink. Reduce Motion snaps between the two valid states at the 12pt and 88pt thresholds. Opening the Bluetooth device menu must not retarget that fold: the header suppresses implicit animation, the menu animates on its own presentation value only, and scroll samples are ignored while the menu is open.

The Bluetooth source control opens `EdgeDropMenu`, a full-width working list inset by the same 16pt phone / 28pt tablet edge padding as Home. It hangs under the source header, lists saved devices with threshold detail, and keeps Manage devices as the trailing action. It is not a second navigation title and it does not replace other native menus or sheets.

The compact phone Bluetooth Gauges layout is a specific first-viewport rule: when the device is compact-width, Dynamic Type is not an accessibility size, the selected mode is Gauges, and Bluetooth is selected, the main chapter stack uses 6pt spacing, history is 75pt high, and the arc receives no extra 24pt lower padding. This keeps the full arc width, the Baseline row, and the 44pt “Calibrate nearby and away” action above the safe-area Log/Record dock. Other phone live layouts use 8pt spacing, 90pt history, and the normal arc lower padding.

**The Evidence Order Rule.** Keep source selection before Gauges, Info, and Compare; present the reading before its interpretation and history; then place baseline, calibration, and recoverable actions in the native flow.

**The One Working Header Rule.** At standard text sizes, fold the expanded source group only into its single composed bar: Instrument and Source stay labeled, Room and Settings stay equal icon targets, and its compact visual and accessibility order is Instrument, Source, Room, Settings. Expanded and accessibility-stacked layouts use Instrument, Room, Source, Settings in labeled scroll flow.

## Elevation & Depth

Depth is tonal and selective. The cool canvas sits behind adaptive system groups; instrument surfaces use a flat grouped material and 24pt continuous corners. The selected mode pill alone receives a contact shadow (`black` at 10% opacity, 2pt blur, y 1pt) above its shallow 5.5%-primary track. Home’s pinned header has a restrained scroll-boundary shadow (black at 3.5% opacity, 6pt blur, y 4pt). Native sheet navigation bars remain opaque canvas with no separator shadow. The spatial camera overlay has a restrained black 60%-opacity, 2pt/y1 text shadow for legibility over live imagery.

**The Instrument-Not-Poster Rule.** Elevation may clarify a selected native control or live camera label; it must not turn a measurement surface into a floating marketing card.

## Shapes

Soft continuous groups provide the principal form language: 24pt source and instrument groups, 20pt baseline control, 14pt recovery panel, and 10pt small controls. Instrument modes use a 26pt capsule well and selected pill. Primary and quiet actions use a 28pt continuous rounded rectangle with 52pt minimum height. Supporting Calibrate and Start Flow controls use a 22pt continuous outline, 44pt minimum height, and a faint neutral fill. The marker on a data instrument receives a face-colored separation ring so it remains distinct without introducing decorative depth.

## Components

### Buttons

**Character:** native, deliberate actions with enough height for field use.

- **Primary:** `ControlStyle` uses adaptive charcoal/yellow with `MC.onAction` lettering, 16pt horizontal and 14pt vertical padding, a 28pt continuous radius, and a 52pt minimum height. Pressed or disabled state reduces opacity.
- **Quiet:** retains the same geometry, a 5.5%-primary background, and adaptive action-colored text.
- **Supporting:** `UtilityControlStyle` gives Calibrate and Start Flow a 1pt action-colored border at 22% opacity, a 2.5%-primary fill, 16pt horizontal / 10pt vertical padding, and a 44pt minimum target. Recovery controls retain native behavior.

### Source Groups

**Character:** a soft operational header that compresses without losing context. The Home source group uses `ProTheme.face`, 24pt continuous corners, 16pt horizontal inset, 8pt vertical inset, and 56pt-minimum expanded rows. Standard text folds it into one bar with a 56pt minimum height, labeled Instrument and Source cells, and equal 44pt Room and Settings icon targets; the common compact row grows when its labels need fitting room. Its rounded shape and dividers follow the same scroll progress. The compact visual and accessibility order is Instrument, Source, Room, Settings; accessibility sizes use all four full-width labeled rows in Instrument, Room, Source, Settings order in scroll flow. Reduced Motion uses the same two valid states without interpolation.

### Bluetooth device menu

**Character:** a full-width working list, not a compact system menu. `EdgeDropMenu` uses `ProTheme.face`, 24pt continuous corners, 16pt row inset, 56pt-minimum rows, and the same Home edge padding. Saved devices show name and threshold; Manage devices stays last. Reduce Motion presents and dismisses without a slide.

### Modes

**Character:** a shallow native segmented control. `InstrumentSegments` uses a 26pt track, 44pt target per mode, a face-colored selected capsule, and the small contact shadow described above. At accessibility sizes it becomes a labeled menu with the same Gauges, Info, and Compare choices.

### Instrument Surfaces

**Character:** the evidence is the face. `instrumentSurface` uses `ProTheme.face`, 24pt continuous corners, and 12pt default internal inset. `InstrumentArc`, `LevelInstrument`, `CompassInstrument`, and `LinearInstrumentScale` are Canvas views whose decorative geometry is hidden from accessibility while `MeasurementValue` and chart actions expose the reading.

### History

**Character:** a readable evidence view, not a decorative graph. `InstrumentHistoryChart` uses Swift Charts with signal-blue series and points, a dashed interval-teal threshold, and an adjustable accessibility action for retained readings. Gaps remain unobserved; they are not interpolated. Axis and chart labels use the readable secondary token.

### Spatial Capture

**Character:** live capability first. `SpatialInstrumentStage` opens the relevant camera stage when hardware support permits, identifies it as a live measurement camera, and provides a truthful unavailable/permission state. On regular-width screens it pairs camera with controls; compact or accessibility layouts keep controls in a bottom safe-area inset. Simulator screenshots may show explicitly labeled sample fixtures or an unavailable camera state; they are not physical camera, LiDAR, or accuracy proof.

## Do's and Don'ts

### Do:

- **Do** keep the persistent source header, evidence selector, reading, history, baseline/calibration, and safe-area actions in that working order when the available viewport permits.
- **Do** use the established action, signal, interval, and readable-secondary roles for their observed jobs.
- **Do** use rounded tabular figures for values, comparisons, statistics, chart-adjacent readings, and numeric evidence.
- **Do** retain 44pt minimum controls, 52pt primary actions, native safe areas, Dynamic Type adaptation, and Reduce Motion behavior.
- **Do** keep compact header labels and controls within one composed horizontal bar throughout a standard-text scroll fold.
- **Do** label fixtures as sample data and communicate unsupported hardware, unavailable permissions, missing observations, and incompatible baselines truthfully.

### Don't:

- **Don't** infer distance from Bluetooth RSSI or dB SPL from microphone dBFS.
- **Don't** interpolate chart gaps, compare an incompatible baseline, or present a sample fixture as a live sensor result.
- **Don't** use action colors, signal blue, or interval teal as unrelated decoration.
- **Don't** replace native navigation, sheets, system materials, safe-area controls, or SF Symbols with web-shaped substitutes. The Bluetooth source chooser is `EdgeDropMenu`; other menus stay native.
- **Don't** create a compact two-row fallback, detached icon circles, or a transient header frame that loses one of the four source controls.
- **Don't** claim simulator captures prove physical sensors, live LiDAR accuracy, camera frames, StoreKit price, purchase, or App Store acceptance.
