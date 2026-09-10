---
name: MagicCuts
description: Native iOS calibration workbench for Bluetooth proximity setup
colors:
  canvas: "#F2F5F7"
  canvas-dark: "#0F141A"
  instrument: "#122438"
  instrument-dark: "#172B40"
  action: "#0052C7"
  action-dark: "#1F66D9"
typography:
  display:
    fontFamily: "SF Pro via SwiftUI .largeTitle"
    fontSize: "34pt Dynamic Type baseline"
    fontWeight: 700
  title:
    fontFamily: "SF Pro via SwiftUI .title2/.title3"
    fontSize: "22pt / 20pt Dynamic Type baselines"
    fontWeight: 700
  body:
    fontFamily: "SF Pro via SwiftUI .body/.callout"
    fontSize: "17pt / 16pt Dynamic Type baselines"
  label:
    fontFamily: "SF Pro via SwiftUI .caption/.subheadline"
    fontSize: "12pt / 15pt Dynamic Type baselines"
  measurement:
    fontFamily: "SF Pro Rounded for the threshold; SF Pro monospaced digits for measurements"
    fontSize: "42pt scalable threshold readout"
    fontWeight: 600
rounded:
  control: "12pt"
  surface: "16pt"
  gauge-cursor: "3pt"
spacing:
  content-inset: "20pt"
  standard-gap: "16pt"
  control-horizontal: "16pt"
  control-vertical: "14pt"
components:
  action-button:
    backgroundColor: "{colors.action}"
    textColor: "#FFFFFF"
    typography: "{typography.title}"
    rounded: "{rounded.control}"
    padding: "14pt 16pt"
    height: "52pt minimum"
  quiet-button:
    backgroundColor: "system primary at 7% opacity"
    textColor: "system primary"
    typography: "{typography.title}"
    rounded: "{rounded.control}"
    padding: "14pt 16pt"
    height: "52pt minimum"
  mode-tab:
    backgroundColor: "transparent"
    textColor: "system primary or secondary"
    typography: "{typography.body}"
    height: "44pt minimum"
  signal-gauge:
    backgroundColor: "{colors.instrument}"
    textColor: "#FFFFFF"
    rounded: "{rounded.surface}"
    padding: "20pt"
---

# Design System: MagicCuts

## Overview

**Creative North Star: "The native calibration workbench"**

MagicCuts makes a Bluetooth signal setting legible as an instrument instead of a generic form. A cool system-aware canvas recedes behind one matte-navy gauge, where a large threshold, tick scale, observed range, and restrained cyan cursor give the product its recognizable working surface. Strong cobalt is reserved for the immediate action, selection underline, and discovery emphasis.

The system stays native on purpose: navigation stacks, sheets, search, forms, SF Symbols, SwiftUI text styles, Dynamic Type, and system semantic colors do the platform work. The approved boards in `.impeccable/design-system/control-surfaces-v2.png` and `.impeccable/mocks/onboarding-discovery.png` set the product character; the real SwiftUI implementation and simulator captures are the source for the values and states recorded here.

**Key Characteristics:**

- One dark instrument surface carries measurement and adjustment context.
- Cobalt marks an action, current setting, or selected state rather than decorating every control.
- Simple and Technical are one stored configuration with different information density.
- Everyday language accompanies every measurement and test state.
- Familiar iOS navigation and accessibility semantics take priority over imitating a web design system.

## Colors

The palette pairs a cool, low-noise canvas with deep navy instrument surfaces and a limited cobalt action color; all three named colors are asset-backed and provide light and dark appearances.

### Primary

- **Calibration Cobalt** (`#0052C7` light, `#1F66D9` dark): the `Action` asset used for primary actions, the selected mode underline, and discovery emphasis.
- **Signal Cyan** (`Color.cyan`, system-supplied): used only for the gauge cursor and observed-band mark inside the dark instrument.

### Neutral

- **Cool Canvas** (`#F2F5F7` light, `#0F141A` dark): the `Canvas` asset behind scrolling content.
- **Matte Instrument** (`#122438` light, `#172B40` dark): the `Instrument` asset for the signal gauge and welcome signal panel.
- **System Ink** (`Color.primary` / `Color.secondary`): platform-adaptive labels, dividers, and quiet controls. Its exact rendered value belongs to iOS appearance and accessibility settings.

**The Signal-Only Accent Rule.** Cyan is a measurement cursor, not a general interactive color. Cobalt identifies the action or selected state that needs attention; other controls stay system ink or a low-opacity system surface.

## Typography

**Display Font:** SF Pro through SwiftUI `.largeTitle` (34pt Dynamic Type baseline, bold).

**Body Font:** SF Pro through SwiftUI semantic styles. `.headline` supplies a 17pt semibold baseline; `.body` and `.callout` supply 17pt and 16pt readable explanations; `.subheadline` and `.caption` supply 15pt and 12pt supporting labels.

**Measurement Font:** the threshold number uses a 42pt `@ScaledMetric` relative to `.largeTitle`, semibold `Font.Design.rounded`; measured values use `.monospacedDigit()` so RSSI, counts, and timing do not jump as they change.

**Character:** Text is native, direct, and scalable. A large title establishes the task, semantic styles explain it, and tabular figures make radio measurements scan as stable values rather than decorative display type.

### Hierarchy

- **Task title** (`.largeTitle.bold()`, 34pt baseline): “Proximity” and the welcome proposition.
- **Section/action title** (`.headline`, 17pt semibold baseline): setup steps, test summaries, and primary controls.
- **Supporting copy** (`.callout`, 16pt baseline): signal caveats and next-step explanations.
- **Instrument label** (`.subheadline` / `.caption`, 15pt / 12pt baselines): gauge labels, ranges, sample counts, and demo markers.
- **Measurement** (42pt scalable rounded numeral plus `.title3` unit): the active nearby threshold.

**The Semantic Type Rule.** Use SwiftUI text styles for every ordinary label. Only live data gets rounded or monospaced treatment, and those treatments never replace the explanatory sentence beside it.

## Layout

Scrolling screens use a 20pt content inset and a 16pt normal vertical rhythm. The normal reading column caps at 640pt, centered on iPad; the threshold sheet caps at 600pt. This preserves a phone-like line length inside the iPad capture instead of stretching calibration language and controls across the device.

Full-width actions sit inside that reading column. The discovery scan control is a bottom safe-area inset; the welcome, detail, discovery, threshold sheet, and Shortcuts screens all use native `NavigationStack` titles and system bars. At accessibility Dynamic Type sizes, the paired nearby/away controls switch from an HStack to a VStack so each remains legible and operable.

## Elevation & Depth

MagicCuts is flat by default. Separation comes from canvas-to-instrument contrast, system grouped backgrounds, 1pt dividers, and low-opacity fills, not custom shadows. The opaque `.bar` used for scan and warning insets is a system material decision owned by iOS.

**The Instrument-First Depth Rule.** The dark gauge earns visual weight because it contains live calibration data. Quiet buttons, discovery rows, and handoff rows do not compete through added shadow or glow.

## Shapes

The primary surface radius is 16pt; standard buttons, joined test controls, and failure messages use 12pt; gauge step buttons use 10pt. The threshold cursor has a 3pt rounded end and uses a narrow 6pt by 30pt marker. Discovery identity icons live in circles, while list rows and instrument surfaces remain softly rounded rectangles.

Joined nearby/away actions are clipped as one 12pt assembly with a 1pt internal gap. In accessibility layouts they stack within the same clipped assembly rather than becoming unrelated cards.

## Components

### Primary and quiet actions

`ControlStyle` is the reusable action treatment. Primary actions use `Action`, white text, `.headline`, 16pt horizontal and 14pt vertical padding, and a 52pt minimum height. Quiet actions use `Color.primary` at 7% opacity with system-primary text. Pressing lowers opacity to 0.75; there is no custom hover state because the shipped interaction is touch-native.

### Mode tabs

Simple and Technical are two equal-width plain buttons above a 1pt secondary baseline. Each has a 44pt minimum height. The active mode is semibold, adds the selected accessibility trait, and moves a 3pt cobalt capsule underline; Technical adds the `slider.horizontal.3` SF Symbol at normal content sizes. At accessibility Dynamic Type sizes, the tabs stack vertically and that decorative icon is omitted so the label remains clear. The setting persists in `@AppStorage`.

### Signal gauge and threshold editor

`SignalGauge` is the signature component. It uses the 16pt matte-navy surface and 20pt inset, a live -100 to 0 dBm ruler, a cyan selected cursor, and an optional cyan observed band. In the edit sheet, 48pt minus and plus controls and direct drag/tap scale adjustment change the valid -100 through -1 dBm threshold. Its visual scale is represented to accessibility as a real SwiftUI `Slider`, labeled “Nearby threshold” with a live dBm value; the displayed ruler is hidden from accessibility when it is read-only.

### Joined test controls

The detail screen pairs “Test nearby” and “Test away” in one clipped 12pt well. Nearby is cobalt and away is a quiet system surface. While a test runs, the active region shows a tinted `ProgressView` and the sibling action becomes an explicit Stop control. At accessibility sizes the well becomes vertical while preserving both actions.

### Discovery rows

Device observations use 16pt cards with a 52pt minimum row. An expanded row changes to an 8%-opacity cobalt fill with a cobalt 1pt outline, reveals an identification instruction, then exposes the appropriate saved-device or naming action. Search, sort, empty, stale, denied, and interrupted states use native controls and `ContentUnavailableView`/inline failure treatment.

### Welcome and Shortcuts handoff

The welcome sheet leads with a dark instrument explainer and three 48pt circular SF Symbol step icons, then offers a primary “Find a device” action and Skip. The handoff rows remain plain 48pt minimum text rows with an SF Symbol/arrow rather than filled calls to action. Shortcuts setup keeps numbered, plain-language guidance and a user-confirmed verification action.

### Motion and accessibility

Authored motion is deliberately limited: mode underline selection uses `.snappy(duration: 0.22)`, threshold numerals use `.easeOut(duration: 0.18)`, discovery-row expansion uses `.snappy(duration: 0.22)`, and the welcome chart symbol can use a variable-color effect. Each checks `accessibilityReduceMotion` and removes the authored animation/effect when enabled. Selection also has native selection feedback. There is no parallax, custom navigation animation, or continuous scanning decoration.

## Do's and Don'ts

### Do:

- **Do** use the Canvas, Instrument, and Action asset colors for branded surfaces; let system semantic colors adapt ordinary text and chrome.
- **Do** keep the gauge live and readable: threshold, ticks, cursor, observed values, and editing affordances must describe the current model state.
- **Do** preserve 44pt minimum targets, 48pt gauge steppers and handoff rows, and 52pt primary actions.
- **Do** use `.monospacedDigit()` for changing RSSI, count, duration, and threshold-adjacent figures.
- **Do** honor Reduce Motion and retain the Slider accessibility representation whenever the gauge is editable.
- **Do** keep the iPad content column capped at 640pt (600pt in the threshold sheet), and stack mode tabs and test actions at accessibility sizes.

### Don't:

- **Don't** turn the signal gauge into a static image, a generic slider, or a distance promise.
- **Don't** spread cyan through general navigation, buttons, or decorative effects.
- **Don't** add web hover, CSS, custom shadows, glass, gradients, or raster control plates to this native SwiftUI system.
- **Don't** remove plain-language caveats about walls, movement, advertising, and the limits of a missing Bluetooth reading.
- **Don't** label simulator sample readings as real-world Bluetooth proof; retain the demo label in UI-test contexts.
