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
  home-selector:
    backgroundColor: "system primary at 6% opacity"
    textColor: "system primary"
    typography: "{typography.title}"
    rounded: "{rounded.segment-well}"
    padding: "14pt"
    height: "52pt minimum"
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

The implementation is native SwiftUI for iOS and iPadOS. Native navigation, sheets, grouped lists, safe areas, SF Symbols, Swift Charts, and semantic system materials carry structure and interaction. The Pro pages use custom Canvas instruments only for data geometry. They do not use generated image plates, web controls, or a custom tab bar.

**Key Characteristics:**

- Home is the instrument face. A dominant live instrument is followed by quieter evidence and recoverable recording actions.
- Existing Action blue signals selection and action; cyan and teal are measurement inks with constrained jobs.
- SF Rounded, tabular measurement figures make numbers stable and legible; body copy remains native SF.
- Gauges, Info, and Compare are related evidence views, never three unrelated dashboards.
- Large text changes the native layout rather than shrinking essential controls or chart content.

## Colors

The palette uses adaptive asset colors and semantic iOS colors so both light and dark appearance remain intentional.

### Primary

- **Action Blue:** the `Action` asset drives primary actions and the selected Gauges, Info, or Compare segment. Its light appearance is the normative `action` frontmatter token; its dark appearance is `#1F66D9`.
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

- **Navigation title** (`.inline` Home): restores native context before the instrument selector and evidence modes.
- **Live measurement** (66pt scalable rounded semibold baseline): the primary result; it may compact for comparison while retaining tabular digits.
- **Instrument title and segment label** (`.headline`, rounded, semibold): sources, modes, method headings, and recording labels.
- **Supporting explanation** (`.callout`): interpretation, truth constraints, baseline difference, and recovery guidance.
- **Evidence label** (`.caption` / `.subheadline`, monospaced where numeric): elapsed time, chart axes, units, state, method, and uncertainty.

**The Measurement Family Rule.** Apply rounded, semibold, monospaced treatment to readings and measurement-adjacent labels. Do not turn explanatory body copy or platform chrome into display typography.

## Layout

`InstrumentWorkspaceView` is a scrollable, centered reading column with 22pt horizontal inset, 16pt vertical rhythm, an 8pt top inset, and 28pt bottom clearance. The column caps at 680pt; the bottom action bar caps at 720pt. The native navigation title is “Home,” with trailing Settings. Directly beneath the bar, a two-column selector gives the current instrument about two thirds of the width and New room one third. Source accessories, then Gauges / Info / Compare, then status, instrument, history, statistics, baseline, and recording actions follow the measurement story.

On ordinary text sizes, Log, Record, and Start Flow sit in a bottom safe-area inset. While a session is recording, that inset shows pause, mark, and finish instead, so Start Flow is not competing with an in-flight capture. At accessibility text sizes those controls move into the scroll view, use vertical action layout, and remain reachable. Source controls and comparison rows switch from horizontal to vertical layouts. The mode selector becomes a compact native `Menu` offering Gauges, Info, and Compare; it does not squeeze three segment labels into an accessibility width.

Gauges places the arc, level, or compass above its dominant reading, then a short interpretation and history. Info leads with a reading, ruler, method, and 260pt chart. Compare aligns two ruler readings to the same range and supplies a dashed-versus-solid explanation. Charts are 120pt live, 190pt compare, and 260pt Info at regular sizes; at accessibility sizes, a chart is at least 240pt high and both axes scale up to 22pt.

Workflow management lives in Settings. Start Flow on Home starts or creates a workflow; it does not replace the Settings library.

**The Evidence Order Rule.** Keep instrument and room controls directly under Home, then Gauges / Info / Compare, then the measurement before its interpretation, history, summary, and recording action. Let safe areas and Dynamic Type supersede any capture-specific geometry.

## Elevation & Depth

MagicCuts Pro is flat and material-led. The instrument face earns attention through ruler geometry, signal ink, and system surface contrast. Native `.bar` material separates recording and logging controls from scroll content. There are no authored shadows, gradients, glow, faux glass, or decorative raster surfaces.

**The Instrument-Not-Poster Rule.** Depth may clarify an active native surface; it must not make a measurement page resemble a marketing card or an image plate.

## Shapes

Live measurement faces use circles, arcs, ticks, needles, and rulers that describe their data. Standard mode wells use a 14pt rounded rectangle with 10pt selected segments. Existing instrument surfaces retain the 16pt radius. Step buttons use 10pt corners; a selected ruler marker uses a 3pt rounded end.

The mode segments are full-width, equal-width native buttons at least 46pt tall. Home selector, Log, Record, Start Flow, and other tappable source, return-to-live, menu, and recording controls keep at least 44pt height; `ControlStyle` primary and quiet actions are at least 52pt.

## Components

The component previews in `.impeccable/design.json` are self-contained HTML/CSS documentation approximations for the Impeccable panel. They demonstrate observed tokens and states but are never MagicCuts app code or a web implementation requirement; the native SwiftUI symbols named alongside each preview remain authoritative.

### Home selector

The row sits below the Home title. The selected instrument occupies about two thirds of the width, with its SF Symbol, rounded headline, chevron, and a 52pt target. New room occupies the remaining third and starts room capture. Bluetooth sources still expose a native device menu; network sources use a native button. At accessibility sizes the selector stacks.

### Gauges, Info, and Compare selector

At regular Dynamic Type sizes, `InstrumentSegments` renders three 46pt minimum rounded segments labeled Gauges, Info, and Compare. Selection fills the current segment with Action blue, uses white rounded semibold text, supplies the selected accessibility trait, selection haptics, and a `.snappy(duration: 0.2)` movement unless Reduce Motion is enabled. At accessibility sizes it becomes the compact native mode menu with all three choices and the current selection checkmark.

### Measurement face and value

The signature face is a Canvas arc, a level target, a compass, or a linear ruler according to the instrument's data type. Major/minor tick weights and readable labels communicate scale. The live value is an accessible `MeasurementValue`; its visual Canvas geometry is hidden from assistive technology. The reading uses the instrument's truthful unit and uses an em dash when no reading exists. Units, method, and uncertainty sit under the value, not inside it.

### History chart

`InstrumentHistoryChart` uses Swift Charts: Action/signal blue for current readings, dashed secondary ink for a baseline, and a selected rule and point for the pinned sample. The selected time is shared with the value above; “Return to live” clears it. It labels elapsed seconds and states that gaps are unobserved. It supports accessibility adjustment through actual retained readings. Its Dynamic Type layout retains scrollable recording controls, vertical statistics, and enlarged chart axes.

### Home actions and recording

Idle measurement uses a split Log and Record pair (52pt `ControlStyle`) above a full-width Start Flow control. Recording replaces Start Flow with pause, mark, and finish so an in-flight session stays unambiguous. The baseline selector remains a 44pt native menu that only lists compatible profiles. Set baseline, Mark, Pause or Resume, and Start measuring retain native controls and their explicit state. Controls are scrollable at accessibility sizes rather than fixed over the content.

### Native navigation

The app does not use a tab bar. Home is the instrument face. Settings is a trailing toolbar item that opens a native sheet holding Workflows, Sessions, Rooms, Field tools, baselines, and iCloud. Instrument picking, Start Flow, room capture, and workflow editing use native sheets with Cancel/Done, not web-shaped cards.

### Optional iCloud settings

The existing native Settings list adds a “Your library, across devices” section. A system toggle defaults off, followed by readable status, progress/error recovery, manual sync when enabled and Bluetooth setup references. The footer explains what moves, that edits and deletions sync, and that disabling keeps both copies. Purchase restoration remains a separate StoreKit action.

Other-device Bluetooth references use a native list, navigation, picker and history disclosure. A reference never looks connected until the user chooses a locally identified saved device. Original evidence and the next local test remain clearly distinguished. Text wraps at accessibility sizes; the section reuses Action blue, rounded headings and existing quiet text tokens without new motion or custom chrome.

## Do's and Don'ts

### Do:

- **Do** use existing Action blue for selection and primary action, reserve signal and interval inks for measured information, and use opaque `ProTheme.secondary` labels for quiet Pro evidence.
- **Do** show truthful unit labels and retain “Sample session” for demonstration data.
- **Do** keep rounded tabular figures for live values, comparisons, statistics, segment labels, and chart-adjacent readings.
- **Do** keep Home as the native navigation title, place the instrument and New room selector immediately beneath it, and keep Settings in the trailing toolbar.
- **Do** provide Gauges, Info, and Compare in the native segment control or the accessibility menu, with the same three choices.
- **Do** preserve the 44pt control floor, 46pt segments, 52pt action controls, system safe areas, Reduce Motion behavior, and accessibility-adjustable history.
- **Do** use a 240pt minimum chart height and axis text that can scale to 22pt at accessibility sizes.

### Don't:

- **Don't** promise measurements that the selected instrument cannot truthfully produce, including distance from Bluetooth signal or dB SPL from dBFS.
- **Don't** treat gaps in the chart as interpolated measurements, or compare incompatible baselines.
- **Don't** use blue, cyan, or teal as unconnected decoration.
- **Don't** replace native navigation, sheets, menus, materials, or touch controls with web-shaped components or a fake tab bar.
- **Don't** ship generated raster control plates or use a generated image as an instrument surface.
- **Don't** claim simulator captures establish physical sensor, background, StoreKit price, purchase, or hardware acceptance.
