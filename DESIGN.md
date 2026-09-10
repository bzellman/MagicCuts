---
name: "MagicCuts Pro"
description: "A native field chronograph for deliberate, truthful measurements."
colors:
  action: "#0052C7"
  signal: "#0052C7"
  signal-contrast: "#61B8FF"
  interval: "#1F6E61"
  secondary-label: "#59636E"
  canvas: "#F2F5F7"
  instrument: "#122438"
typography:
  display:
    fontFamily: "SF Pro Rounded, SF Pro, system-ui"
    fontSize: "@ScaledMetric 66pt relative to Large Title"
    fontWeight: 600
    lineHeight: "native"
    fontFeature: "monospacedDigit"
  title:
    fontFamily: "SF Pro Rounded, SF Pro, system-ui"
    fontSize: "SwiftUI headline"
    fontWeight: 600
    lineHeight: "native"
  body:
    fontFamily: "SF Pro, system-ui"
    fontSize: "SwiftUI body and callout"
    lineHeight: "native"
  label:
    fontFamily: "SF Pro, system-ui"
    fontSize: "SwiftUI caption and subheadline"
    lineHeight: "native"
rounded:
  tick-marker: "3pt"
  control: "10pt"
  action-control: "12pt"
  segment-well: "14pt"
  surface: "16pt"
spacing:
  compact: "8pt"
  control: "10pt"
  normal: "16pt"
  content: "22pt"
components:
  action-button:
    backgroundColor: "{colors.action}"
    textColor: "#FFFFFF"
    typography: "{typography.title}"
    rounded: "{rounded.action-control}"
    padding: "14pt 16pt"
    height: "52pt minimum"
  quiet-action:
    backgroundColor: "system primary at 7% opacity"
    textColor: "system primary"
    typography: "{typography.title}"
    rounded: "{rounded.action-control}"
    padding: "14pt 16pt"
    height: "52pt minimum"
  mode-segments:
    backgroundColor: "system primary at 5.5% opacity"
    textColor: "system primary"
    typography: "{typography.title}"
    rounded: "{rounded.segment-well}"
    padding: "4pt"
    height: "46pt minimum"
  instrument-face:
    backgroundColor: "system secondary grouped background"
    textColor: "system primary"
    rounded: "{rounded.surface}"
    padding: "native layout"
---

# Design System: MagicCuts Pro

## Overview

**Creative North Star: "The grounded field chronograph"**

MagicCuts Pro turns a live reading into an instrument page: choose a source, make a measurement, inspect the evidence, set a baseline, record a session, and use it in a report or workflow. Matte ink fields, precise rulers, quiet history, and rounded measurement values establish the working character. A pin in the chart changes the related reading; returning to live is explicit.

The implementation is native SwiftUI for iOS and iPadOS. Native navigation, sheets, safe areas, `TabView` chrome, SF Symbols, Swift Charts, and semantic system materials carry structure and interaction. The Pro pages use custom Canvas instruments only for data geometry. They do not use generated image plates or web controls.

**Key Characteristics:**

- A dominant live instrument is followed by a quieter evidence chart and recoverable recording actions.
- Existing Action blue signals selection and action; cyan and teal are measurement inks with constrained jobs.
- SF Rounded, tabular measurement figures make numbers stable and legible; body copy remains native SF.
- Live, Inspect, and Compare are related evidence views, never three unrelated dashboards.
- Large text changes the native layout rather than shrinking essential controls or chart content.

## Colors

The palette uses adaptive asset colors and semantic iOS colors so both light and dark appearance remain intentional.

### Primary

- **Action Blue:** the `Action` asset drives primary actions and the selected Live, Inspect, or Compare segment. Its light appearance is the normative `action` frontmatter token; its dark appearance is `#1F66D9`.
- **Signal Blue:** `ProTheme.signal` follows Action blue in light appearance and becomes the higher-contrast `signal-contrast` token in dark appearance. It marks a live needle, selected chart series, source affordance, or selected reading.

### Secondary

- **Interval Teal:** `ProTheme.band` identifies an interquartile band and qualified interpretive state. It adapts to a lighter teal in dark appearance.

### Neutral

- **Canvas:** the `Canvas` asset provides the page ground and becomes `#0F141A` in dark appearance.
- **Matte Instrument:** the `Instrument` asset is retained for the existing calibration surface; Pro live instrument faces use system secondary grouped background so they follow the platform appearance.
- **Pro Secondary Label:** `ProTheme.secondary` is opaque `#59636E` in light appearance and `#A8B3BD` in dark appearance. It owns Pro units, state, interpretation, chart axes, and quiet evidence labels where generic `Color.secondary` did not provide the required contrast.
- **System Ink:** `Color.primary` and native grouped/background materials own ordinary platform text, grids, dividers, bars, and quiet controls. Individual data geometry may use its observed system-secondary stroke values.

**The Blue Has Meaning Rule.** Action blue indicates a current action, selected instrument state, or observed reading. Cyan signal ink and interval teal identify data only; neither becomes general decoration.

**The Opaque Secondary Label Rule.** In Pro instrument pages, use `ProTheme.secondary` for quiet readable text rather than reducing generic secondary text until it fails contrast.

## Typography

**Display Font:** SF Rounded through SwiftUI's rounded design, with `@ScaledMetric` relative to `.largeTitle` for the 66pt live measurement baseline.

**Body Font:** SF Pro through native SwiftUI semantic styles.

**Character:** Values, segment labels, headings, and statistics use SF Rounded with semibold emphasis where the hierarchy needs a reading-like character. Body, callouts, captions, menus, labels, and navigation stay on the system face. Changing figures use `.monospacedDigit()`.

### Hierarchy

- **Navigation title** (`.inline` Instruments): restores the native context before source and mode controls.
- **Live measurement** (66pt scalable rounded semibold baseline): the primary result; it may compact for comparison while retaining tabular digits.
- **Instrument title and segment label** (`.headline`, rounded, semibold): sources, modes, method headings, and recording labels.
- **Supporting explanation** (`.callout`): interpretation, truth constraints, baseline difference, and recovery guidance.
- **Evidence label** (`.caption` / `.subheadline`, monospaced where numeric): elapsed time, chart axes, units, state, and method detail.

**The Measurement Family Rule.** Apply rounded, semibold, monospaced treatment to readings and measurement-adjacent labels. Do not turn explanatory body copy or platform chrome into display typography.

## Layout

`InstrumentWorkspaceView` is a scrollable, centered reading column with 22pt horizontal inset, 16pt vertical rhythm, an 8pt top inset, and 28pt bottom clearance. The column caps at 680pt; the bottom recording bar caps at 720pt. The native navigation title is “Instruments,” then source control, mode control, status, instrument, history, statistics, baseline, and recording actions follow the measurement story.

On ordinary text sizes, recording controls sit in a bottom safe-area inset above the native three-section tab bar. At accessibility text sizes they move into the scroll view, use vertical action layout, and remain reachable. Source controls and comparison rows switch from horizontal to vertical layouts. The mode selector becomes a compact native `Menu` offering Live, Inspect, and Compare; it does not squeeze three segment labels into an accessibility width.

Live places the arc, level, or compass above its dominant reading, then a short interpretation and history. Inspect leads with a reading, ruler, and 260pt chart. Compare aligns two ruler readings to the same range and supplies a dashed-versus-solid explanation. Charts are 120pt live, 190pt compare, and 260pt Inspect at regular sizes; at accessibility sizes, a chart is at least 240pt high and both axes scale up to 22pt.

**The Evidence Order Rule.** Keep source and view controls directly under Instruments, then show the measurement before its interpretation, history, summary, and recording action. Let safe areas and Dynamic Type supersede any capture-specific geometry.

## Elevation & Depth

MagicCuts Pro is flat and material-led. The instrument face earns attention through ruler geometry, signal ink, and system surface contrast. Native `.bar` material separates recording controls from scroll content. There are no authored shadows, gradients, glow, faux glass, or decorative raster surfaces.

**The Instrument-Not-Poster Rule.** Depth may clarify an active native surface; it must not make a measurement page resemble a marketing card or an image plate.

## Shapes

Live measurement faces use circles, arcs, ticks, needles, and rulers that describe their data. Standard mode wells use a 14pt rounded rectangle with 10pt selected segments. Existing instrument surfaces retain the 16pt radius. Step buttons use 10pt corners; a selected ruler marker uses a 3pt rounded end.

The mode segments are full-width, equal-width native buttons at least 46pt tall. Other tappable source, return-to-live, menu, and recording controls keep at least 44pt height; `ControlStyle` primary and quiet actions are at least 52pt.

## Components

The component previews in `.impeccable/design.json` are self-contained HTML/CSS documentation approximations for the Impeccable panel. They demonstrate observed tokens and states but are never MagicCuts app code or a web implementation requirement; the native SwiftUI symbols named alongside each preview remain authoritative.

### Instrument source controls

The source row sits below the Instruments title. The selected instrument has its SF Symbol, rounded headline, chevron, and a 44pt target. Bluetooth sources use a native menu; network sources use a native button. At accessibility sizes the source row stacks.

### Live, Inspect, and Compare selector

At regular Dynamic Type sizes, `InstrumentSegments` renders three 46pt minimum rounded segments. Selection fills the current segment with Action blue, uses white rounded semibold text, supplies the selected accessibility trait, selection haptics, and a `.snappy(duration: 0.2)` movement unless Reduce Motion is enabled. At accessibility sizes it becomes the compact native mode menu with all three choices and the current selection checkmark.

### Measurement face and value

The signature face is a Canvas arc, a level target, a compass, or a linear ruler according to the instrument's data type. Major/minor tick weights and readable labels communicate scale. The live value is an accessible `MeasurementValue`; its visual Canvas geometry is hidden from assistive technology. The reading uses the instrument's truthful unit and uses an em dash when no reading exists.

### History chart

`InstrumentHistoryChart` uses Swift Charts: Action/signal blue for current readings, dashed secondary ink for a baseline, and a selected rule and point for the pinned sample. The selected time is shared with the value above; “Return to live” clears it. It labels elapsed seconds and states that gaps are unobserved. It supports accessibility adjustment through actual retained readings. Its Dynamic Type layout retains scrollable recording controls, vertical statistics, and enlarged chart axes.

### Baseline and recording controls

The baseline selector is a 44pt native menu that only lists compatible profiles. Record session, finish recording, Set baseline, Mark, Pause or Resume, and Start measuring retain native controls and their explicit state. Recording is a recoverable local session flow; controls are scrollable at accessibility sizes rather than fixed over the content.

### Native navigation

The app uses the native Instruments, Sessions, and Workflows `TabView`, navigation titles, toolbars, sheets, and safe areas. The iOS/iPadOS 26 system tab presentation supplies the floating chrome; the Pro design does not replace it with a custom tab bar.

### Optional iCloud settings

The existing native Settings list adds a “Your library, across devices” section. A system toggle defaults off, followed by readable status, progress/error recovery, manual sync when enabled and Bluetooth setup references. The footer explains what moves, that edits and deletions sync, and that disabling keeps both copies. Purchase restoration remains a separate StoreKit action.

Other-device Bluetooth references use a native list, navigation, picker and history disclosure. A reference never looks connected until the user chooses a locally identified saved device. Original evidence and the next local test remain clearly distinguished. Text wraps at accessibility sizes; the section reuses Action blue, rounded headings and existing quiet text tokens without new motion or custom chrome.

## Do's and Don'ts

### Do:

- **Do** use existing Action blue for selection and primary action, reserve signal and interval inks for measured information, and use opaque `ProTheme.secondary` labels for quiet Pro evidence.
- **Do** show truthful unit labels and retain “Sample session” for demonstration data.
- **Do** keep rounded tabular figures for live values, comparisons, statistics, segment labels, and chart-adjacent readings.
- **Do** keep Instruments visible as the native navigation title and place source controls immediately beneath it.
- **Do** provide Live, Inspect, and Compare in the native segment control or the accessibility menu, with the same three choices.
- **Do** preserve the 44pt control floor, 46pt segments, 52pt action controls, system safe areas, Reduce Motion behavior, and accessibility-adjustable history.
- **Do** use a 240pt minimum chart height and axis text that can scale to 22pt at accessibility sizes.

### Don't:

- **Don't** promise measurements that the selected instrument cannot truthfully produce, including distance from Bluetooth signal or dB SPL from dBFS.
- **Don't** treat gaps in the chart as interpolated measurements, or compare incompatible baselines.
- **Don't** use blue, cyan, or teal as unconnected decoration.
- **Don't** replace native navigation, sheets, menus, tabs, materials, or touch controls with web-shaped components.
- **Don't** ship generated raster control plates or use a generated image as an instrument surface.
- **Don't** claim simulator captures establish physical sensor, background, StoreKit price, purchase, or hardware acceptance.
