# MagicCuts

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Automation enthusiasts who want to identify Bluetooth devices easily, set proximity thresholds, configure Apple Shortcuts, and test and validate the outcome.

## Product Purpose
Make Bluetooth proximity useful in personal automations through a clear discover, identify, configure, test, and Shortcuts workflow.

## Operating Context
Native SwiftUI app using CoreBluetooth, SwiftData, and AppIntents. Actual Bluetooth scanning requires physical hardware; simulator visuals cannot establish radio reliability.

## Capabilities and Constraints
Existing code discovers Bluetooth LE advertisements, saves named devices and RSSI thresholds, tests proximity, and exposes a proximity-check intent to Shortcuts.
Requested design adds Simple and Technical modes. Both explain signal variation and reliability in everyday language. Technical mode exposes useful measurements without replacing explanations with jargon.
Signal strength is evidence of proximity, not a precise distance measurement. A missing advertisement must not imply confirmed absence. Shortcuts configuration improvements are requested; direct installation and background-trigger behavior must be verified before promised.

## Brand Commitments
MagicCuts name. Native iOS interactions remain familiar. No other visual identity is pinned.

## Evidence on Hand
README.md and Swift sources describe the incumbent implementation. All sample devices and readings in mockups must be labeled as demo data.

## Product Principles
- Make device identification easy before asking for signal tuning.
- Keep Simple and Technical modes on the same underlying configuration.
- Pair measurements with a plain-language explanation and next step.
- Treat testing and validation as part of setup.

## Open Decisions
Exact device-identification assistance, Shortcuts handoff capabilities, and validation sampling behavior require implementation investigation. Mockups may propose these interactions but do not prove they exist.
