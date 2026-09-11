# MagicCuts

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Automation enthusiasts and people setting up or troubleshooting equipment who want useful measurements, repeatable comparisons, and reliable inputs to Apple Shortcuts.

## Product Purpose
Turn locally available sensor and connectivity data into understandable readings, calibrated references, comparisons, recorded evidence, and Shortcuts workflows.

## Operating Context
Native SwiftUI app using CoreBluetooth, SwiftData, and AppIntents. Actual Bluetooth scanning requires physical hardware; simulator visuals cannot establish radio reliability.

## Capabilities and Constraints
The Pro implementation includes twelve instruments: Bluetooth signal, level, vibration, rotation, magnetic field, pressure, relative elevation, magnetic heading, speed, microphone dBFS, HTTP response time, and battery state. A shared native Live / Inspect / Compare system connects named baselines, calibration, recordings, field reports, groups, and Shortcuts workflows. See docs/PRO_INSTRUMENT_RESEARCH.md for calculation contracts and docs/CAPABILITY_EXPANSION_PLAN.md for the broader research inventory; that inventory includes future hardware-dependent adapters and is not a list of shipped features.

The selected Room canvas and 18 field-capability paths are implemented in the development branch: saved room meshes/revisions, localization attempts and manual/tracked measurement placement; NFC inspection; network transaction/consistency tools; cellular context/verified tests/forecasts/history; LiDAR point/surface/depth tools; and participating-device network, Wi-Fi Aware and Nearby Interaction tools. See docs/ROOM_INSTRUMENT_VALIDATION.md for the implementation/evidence matrix. Physical capture, revisit accuracy, provider delivery and compatible-device acceptance remain separate release gates.

Existing code discovers Bluetooth LE advertisements, saves named devices and RSSI thresholds, tests proximity, and exposes a proximity-check intent to Shortcuts.
The Bluetooth setup flow retains Simple and Technical modes. Both explain signal variation and reliability in everyday language. Technical mode exposes useful measurements without replacing explanations with jargon.
Signal strength is evidence of proximity, not a precise distance measurement. A missing advertisement must not imply confirmed absence. Shortcuts configuration improvements are requested; direct installation and background-trigger behavior must be verified before promised.

## Brand Commitments
MagicCuts name. Native iOS interactions remain familiar. Apple Watch face level of polish, thought, and utility is the minimum: consistent typography, meaningful data geometry, precise interaction, and carefully composed states. No web UI framework or generic component-library visual system.

## Commercial and Infrastructure Commitments
One hard Pro paywall covers all working functionality, including existing Bluetooth and Shortcuts actions, Device Groups, and every additional instrument. There is no free legacy or basic sensor tier. Purchase, restore, legal information and purchase recovery remain accessible before unlocking. Use a verified StoreKit entitlement across every entry point; no writable local-flag unlock in production. Final pricing has not been chosen.

No additional owner-operated infrastructure. Computation and purchase verification stay on device; storage is local by default. Users may opt into private Apple CloudKit sync for their saved library using their existing Apple Account. Opt-in is separate on each installation, and iCloud failure must not prevent local work. No MagicCuts account, backend, owner-operated database, paid API, cloud inference, managed entitlement service or custom push provider. Apple handles cloud transport; the developer maintains the app, Apple container/schema and user support.

Portability preserves source provenance. Imported Bluetooth references require explicit connection to locally identified hardware; historical calibration and Shortcut confirmation must not become current validation on another device. Pro restoration remains independent through StoreKit. See docs/ICLOUD_PORTABILITY.md for the implemented contract and acceptance evidence.

## Evidence on Hand
README.md and Swift sources describe the incumbent implementation. All sample devices and readings in mockups must be labeled as demo data.

## Product Principles
- Make device identification easy before asking for signal tuning.
- Keep Simple and Technical modes on the same underlying configuration.
- Pair measurements with a plain-language explanation and next step.
- Treat testing and validation as part of setup.

## Open Decisions
Live StoreKit product/price and physical acceptance of each supported sensor. The combined native composition was approved with the existing blue palette and rounded segment labels. The local StoreKit configuration's price is test data. Sessions pause in the background; the Live Activity reports this state and does not claim unrestricted background sensing. Mockups and explicitly labeled sample sessions demonstrate design intent and do not prove sensor availability or accuracy.
