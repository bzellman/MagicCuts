# MagicCuts Pro: useful measurements, exceptional instruments

Research and product direction, September 9, 2026 (America/Chicago). This document distinguishes platform facts, design observations, proposed calculations, and work still requiring physical validation. It supersedes every earlier free-tier recommendation.

## Decision

- **One hard Pro paywall covers the entire working app**, including existing Bluetooth devices and Shortcuts actions, groups, measurements, profiles, workflows, sessions, and exports. Purchase, restore, legal information, and purchase recovery remain reachable before unlocking.
- The product advantage is a consistent instrument experience: read a measurement, understand its quality, establish a reference, compare a change, record evidence, and use the result in Shortcuts.
- Adopt Apple Watch's economy of attention and purposeful geometry. A ring is appropriate for bearing or an explicitly bounded scale; it is not the universal shape of sensor data.
- Prefer calculations that answer a real question: median and spread, delta from a named baseline, windowed vibration magnitude, orientation offset, pressure change, latency percentiles, and observed failure rate.
- Every live value retains its unit, source, sample time, measurement window, and quality state. Missing, stale, interrupted, denied, unsupported, and locked are different states.
- Perform computation, storage, entitlements, and reports on the device. The business operates no new backend, paid API, hosted data service, or remote notification infrastructure.

## Research method and evidence limits

The questions were: which transformations change a user's decision; which display forms fit those transformations; what mature native products actually show; and what iOS can provide honestly. The evidence floor was 8–12 credible sources including at least three primary sources. The twelve core sources below include primary platform documentation, original research, an engineering reference, and product documentation. Pages were opened and read, with Apple's Markdown documentation retrieved when the HTML required JavaScript. Apple Compass and Oceanic+ reference images were also downloaded and visually inspected.

The earlier [capability inventory](CAPABILITY_EXPANSION_PLAN.md) supplies the broader API and hardware research. Manufacturer documentation is evidence of available interfaces, not proof of MagicCuts runtime behavior. Product pages show advertised interaction patterns, not validated demand. Design recommendations below are our synthesis. No new physical sensor accuracy, background, battery, or buyer experiment is claimed by this report.

## What the best references actually teach

| Reference | Observed pattern | Transfer to MagicCuts | Avoid copying |
|---|---|---|---|
| Apple Watch Compass | Central bearing, orientation on a real angular scale, secondary waypoints, progressively different views | A decisive current reading; geometry that encodes the quantity; a focused way to inspect more | A compass rose around unrelated linear quantities; fake depth or distance |
| Oceanic+ | Primary depth and time information; quieter supporting measurements; explicit action guidance; marked bearings; post-session review | Separate reading from interpretation; one clear action; useful session marks and review | Dive safety claims, decorative warnings, or implying iPhone sensors have watch hardware capabilities |
| CARROT Weather | A data picker changes related charts without leaving the main screen | Keep source, selection, unit, and inspection time coherent across views | Weather hosting costs, gamification, or personality displacing measurement clarity |
| Smartwatch-face research | Compact dashboards must reconcile data type, amount, encoding, decorations, context, and coherent visual style | Define a small visual grammar and test quick reading and comparisons | Treating a survey of watch faces as an experiment proving our proposed layout wins |
| NIST + Analog Devices | Robust summaries have different meanings; vibration magnitude and frequency depend on sensor bandwidth, bias, and noise | Name calculations and windows; preserve raw samples; refuse precision unsupported by the sensor | A made-up quality percentage; industrial diagnosis from an unqualified phone |

Sources: [Apple Compass][1], [Oceanic+][2], [CARROT][3], [watch-face study][4], [NIST][5], [Analog Devices][6].

## Measurement-to-decision map

These are proposed product transformations. Availability and accuracy must be checked for the actual hardware and sampling path. Cross-platform API support does not establish suitability for a particular measurement job.

| Measurement | Useful transformation and question | Best display | Honest boundary |
|---|---|---|---|
| Bluetooth RSSI | Window median, middle 50% interval, threshold margin, distribution overlap between nearby/away trials. Does placement reliably separate my two intended states? | Labeled dBm ruler, observed band, threshold cursor; shared-scale trial plots | dBm is received power. A dB difference is not meters. Observed samples are not a probability that a device is present. |
| Bluetooth observations | Last seen, valid observation count, observed interval distribution, service identity. Did the accessory advertise during this test? | Timestamped event list, presence timeline with gaps | No observation cannot establish absence. Advertising, permissions, radio state, and suspension remain separate. |
| Bluetooth GATT | Before/after characteristic values and notification changes for supported services | Typed value, unit, timestamp, meaningful change annotation | Decode documented schemas only; bytes are not an invented sensor interpretation. Connections and supported characteristics vary. |
| Device orientation | Offset from a stored attitude, pitch/roll, shortest angular difference. Is this surface at my intended angle? | Two-axis level; zero reference; small signed angle; accessible numeric alternative | A level reference is a user baseline, not metrology certification. Reference frames and orientation changes matter. |
| User acceleration | Windowed RMS magnitude, peak, peak/RMS where defined, comparison to a stationary baseline. Is this mounting or surface more disturbed? | Quiet time trace plus magnitude and sampling window | Core Motion separates gravity and user acceleration. Avoid integrating to position or velocity without a defensible drift model. |
| Vibration spectrum | Windowed spectrum and dominant component inside the measured usable band. Which repetitive component changed? | Frequency on a linear/log axis with units, clear peak and resolution | Actual timestamps, sample rate, anti-aliasing, windowing, gaps, and sensor response govern validity. A phone is not a certified machine diagnostic. |
| Magnetic field | Vector magnitude and baseline delta; heading variation over a window. Did the local magnetic environment change? | Numeric field strength and a trace; heading on a true angular scale | Do not label a change as a specific metal, object, or hazard. Show calibration accuracy when available. |
| Heading | Circular mean and shortest bearing offset; uncertainty and freshness. Am I facing my saved direction? | Compass / bearing arrow; clearly named magnetic or true north | Ordinary arithmetic means fail at 359°/1°. True heading needs the appropriate location context. |
| Pressure | kPa to hPa; baseline pressure delta; smoothed rate over an explicit time window | Absolute reading plus delta plot with a zero line | Do not invent ambient temperature or a weather forecast from a short pressure record. |
| Relative altitude | Difference from session start, net rise, windowed rise rate | Vertical ruler and aligned height/time trace | Distinguish barometric relative change from GNSS/absolute altitude. Weather and environment can affect pressure interpretation. |
| Location / speed | Accuracy-filtered readings, age, displacement from a reference, distance along accepted samples | Coordinate/accuracy view; trace with excluded or missing segments | Stationary GNSS jitter can accumulate false distance. Negative invalid speed/accuracy values are not usable measurements. |
| Microphone | PCM RMS in dBFS, peak, clipping fraction, spectrum, change from a same-input baseline | Level strip with peak hold; spectrum only when requested | dBFS is digital full scale, not dB SPL or a certified sound-level reading. Changing input route invalidates comparisons unless explicitly handled. |
| Audio route | Current input/output, sample rate, channel count, interruptions | Compact categorical source details | The active route is not an inventory of nearby audio devices. |
| Network path | Wi-Fi/cellular/wired status, expensive/constrained state, observed transitions | Named state and timeline, not a strength dial | No general iPhone Wi-Fi scan, Wi-Fi RSSI from NWPath, or cellular dBm promise. |
| User-owned endpoint | Completed application request times, p50/p95, completion/failure counts, DNS/connect/TLS when recorded | Distribution and request timeline; explicit endpoint and test method | HTTPS request duration is not ICMP ping or packet loss. Record cold/warm connection conditions; cap retries and payloads. |
| Participating peer | Application round-trip and bytes/time with a specified local protocol | Shared endpoint labels and a real transfer graph | Both devices must participate. Estimated Wi-Fi Aware capacity is not measured download throughput. |
| UWB | Compatible peer distance, direction and quality; distance change | Directional arrow and meters with unavailable components omitted | Requires supported hardware and an actual participating peer/accessory. Not AirTag discovery or universal Bluetooth ranging. |
| NFC | Decode supported NDEF records; compare a scanned identity to a workflow's expected identity | Clear record view with confirmation and scan time | User-driven read/write sessions and tag compatibility; no continuous background scanner claim. |
| Camera / Vision | Confirmed OCR, barcode/QR identity, measured image color, timestamped annotation | Camera view with restrained target and a reviewable result | Inference confidence is not physical accuracy. Optical color varies with exposure and light; do not call it a calibrated colorimeter. |
| AR / LiDAR | Supported plane/point distances, depth confidence, local geometry comparison | Camera-relative measurement and uncertainty; a plain result record | Hardware and tracking quality gate the feature. No depth on devices without it, no survey-grade claim. |
| Battery / thermal state | Charge percentage, charging transitions, categorical thermal state | Compact status line and timestamped changes | Thermal state is not internal temperature in degrees; battery percentage is not measured power draw. |
| Supported accessories | Typed measurements from documented BLE, MIDI, or participating accessory protocols | Reuse the same unit/source/baseline/history grammar | Do not pretend every USB, MFi, HomeKit, or proprietary accessory is available through one unrestricted API. |

API boundaries are grounded in [the capability inventory](CAPABILITY_EXPANSION_PLAN.md); the directly reviewed measurement definitions include [Core Motion][7], [altitude data][8], [audio power][9], [task metrics][10], and [heading][11].

## Calculation contracts

These are implementation specifications, not assertions about measurement accuracy.

1. **Median and spread.** Filter invalid/nonfinite values first; keep the reason and count of exclusions. Define percentiles consistently using linear interpolation on sorted samples at index `(n - 1) × p`. IQR is `Q75 - Q25`; label the band “Middle 50%,” never “confidence.” Empty data returns unavailable. One sample can be a reading but cannot establish stability. NIST supports the robustness rationale, not a MagicCuts minimum sample count. [NIST][5]
2. **Window and gaps.** A result includes elapsed window, accepted count, first/last timestamps, and interruption state. For a configured regular sampler, calculate delivered-versus-expected coverage only against that explicit sampling contract. For Bluetooth, show observed samples and gaps rather than a made-up expected advertising count. Break charts across interruptions and substantial sample gaps.
3. **Signal calibration.** Keep labeled nearby and away trials separate. Fit a threshold against training trials; report held-out results independently. Show overlap and refuse a confident recommendation when the distributions do not separate. Preserve the existing action's “any valid sample reaches threshold” semantics unless a new, explicitly named rule uses median/dwell/hysteresis.
4. **Baseline identity.** A baseline stores source identity, measurement kind, unit, configuration, input route/reference frame where applicable, time, window and summary. Block or explicitly reconfirm mismatches. Compute a displayed delta in the quantity's units; a pressure delta in hPa is not an altitude delta in meters.
5. **Angles.** Compute circular mean as `atan2(sum(sin θ), sum(cos θ))`, normalized to `[0, 360)`. With a near-zero resultant, direction is indeterminate. Use the shortest signed angular difference. Use attitude/quaternion relationships for orientation references rather than subtracting unrelated Euler angles across frames.
6. **Vibration.** For vector user acceleration in g, RMS magnitude is `sqrt(mean(x² + y² + z²))`; multiply by standard gravity only when displaying m/s². Keep peak and RMS from the same window. Peak/RMS is unavailable when RMS is zero. Spectrum work must estimate actual sample cadence, reject invalid/gapped windows, remove the relevant bias, apply a documented window and normalization, and display usable bandwidth and bin resolution. Sampling Nyquist frequency alone does not prove sensor flatness. [Core Motion][7], [Analog Devices][6]
7. **Audio.** For normalized PCM, RMS level is `20 log10(RMS)` dBFS. Exact silence is a floor/−∞ state rather than an arbitrary measurable noise value. Aggregate power before taking the logarithm; do not average dB values as though they were linear amplitude. Preserve route and sample-rate metadata. Apple's recorder meter likewise reports dBFS. [Apple audio power][9]
8. **Endpoint measurements.** Define start/end boundaries and request count. Report successful response distribution and failures separately; failed requests must not disappear into an optimistic percentile. Small samples must say how many were measured. Use task transaction metrics for attributed phases where supplied. Refuse to call application failures “packet loss.” [Task metrics][10]
9. **Rules.** A measurement result is value + quality, not just a Boolean. Support pass, fail, unavailable, and interrupted. “Unknown” never silently becomes “away” or “safe.” A rule names its aggregation, threshold, dwell/window, source and maximum age; its preview explains which condition decided the result.
10. **Sessions.** Samples, notes, calibration changes, pauses and input changes share a monotonic session timeline plus a wall-clock anchor for reports. A new sensor segment is explicit. A paused or background-suspended sensor cannot remain visually live. Bound memory, downsample display separately from recorded evidence, and export the original retained data with metadata.

## A coherent native interaction system

**Instrument.** Select the source, begin a deliberate measurement, and see one leading value. Each measurement family gets a fitting visualization: angular dial, two-axis level, linear signal ruler, spectrum, time plot, categorical path state, or camera overlay. The shared typography, scale weights, source/status row, controls, and inspection behavior make these one product.

**Inspect.** Touch or drag a chart to pin an instant. The value, timestamp and related readouts follow the same selection. Haptics acknowledge selection changes at meaningful boundaries, not every sensor callback. Release returns to live only through a clear affordance, so inspection does not unexpectedly jump. VoiceOver provides equivalent value selection and a readable summary.

**Calibrate.** “Set baseline” begins a named, source-specific reference capture with duration and quality. BLE gets guided nearby/away trials and review. A saved reference carries into the instrument, comparison, workflow and report. Reset and replace are distinct actions.

**Compare.** Baseline and current data use identical units and axes. Signed delta, distribution overlap and sampling context appear before commentary. A single shared time cursor examines aligned session segments. “Door closed” or similar notes are user-authored events, not inferred explanations.

**Record.** Start, mark, pause, resume, stop and save use the same interaction pattern for every supported source. Sessions preserve notes and available measurements locally. Clear memory/storage limits and interruptions are visible. Live Activities can summarize an explicitly supported session; they do not grant every sensor unlimited background execution.

**Build a workflow.** Choose sources, add named conditions, preview the result on a real capture, then make it available to Shortcuts. Templates are concrete editable workflows, not a separate marketplace. A group can express all/any membership without hiding unavailable measurements.

**Report.** The same selected evidence becomes a locally generated PDF/CSV/JSON artifact: source, units, dates, method, baseline, plots, notes, interruptions, excluded samples and limitations. Sharing uses the system share sheet. There is no upload required.

### Visual and motion contract

The physical use scene is a person setting up equipment at a desk or checking a result in the field. The main instrument needs strong contrast and quick reading; surrounding native chrome adapts to system appearance. Prototypes explore a matte dark instrument field with warm-white numerals and a measured orange selection accent, without glow or faux materials. Light appearance must receive an equally designed, legible treatment.

Three full-fidelity compositions explore one world: **Field Dial** for immediate threshold reading; **Signal Studio** for inspecting time and variation; **Comparison Bench** for seeing a change against a reference. They can become complementary views in one product. Sample data is visibly labeled. Generated geometry is design intent: implementation must use correct numeric mapping, not reproduce an image's accidental tick or plotted-value errors.

System navigation, native tab bars, back gestures, 44-point touch targets, Dynamic Type, semantic colors, SF Symbols, Reduce Motion, and VoiceOver remain structural requirements. Custom work lives in the instrument scales and inspection controls. No web UI kit is involved. Live sampling does not animate number interpolation or create fake progress; only meaningful transitions and selected-time movement receive authored motion.

## Hard paywall and operating cost

Use one non-consumable StoreKit product, verified on-device. Check current entitlements before entering the instrument experience and independently before every App Intent or other alternate entry point performs work. Observe transaction updates, handle revocation and restore, and keep purchase-pending/cancelled/error distinct. Do not unlock from an unverified transaction or a writable preference flag. [StoreKit][12]

There is no free sensor, legacy Bluetooth, group, workflow or recording tier. No account is needed. Price is unresolved: previous $14.99–$24.99 suggestions were hypotheses, not approved live pricing. UI must obtain localized pricing from StoreKit; a missing product must say purchasing is unavailable and offer recovery. Test configurations are development-only, visibly isolated, and cannot ship an entitlement bypass.

No owner-operated server, cloud database, analytics collector, paid entitlement service, cloud inference, or hosted recipe system. Measurements and exports are local; endpoint tests reach only destinations explicitly configured by the user. Apple developer membership, store commission, hardware, and maintenance still exist as ordinary costs; “no extra infrastructure” does not mean the business has no costs.

## Verification that earns a Pro claim

- Exercise the entire locked app and every alternate entry point; verified purchase, restore, pending, cancellation, revocation, missing product and offline behavior.
- Use meaningful calculation fixtures: empty/nonfinite data, wraparound headings, baseline mismatch, percentile convention, interrupted windows, sampling gaps, all-zero RMS, known periodic signals, and request failures.
- Build and inspect actual native iPhone and iPad screens in light/dark and large Dynamic Type. Exercise all user journeys, including denied permissions and unsupported hardware; screenshot mocks are not runtime evidence.
- Validate BLE nearby/away separation and sparse advertisers, sensor timestamps/cadence, audio route changes, thermal/battery behavior, and supported background sessions on physical devices. Preserve unresolved acceptance as unresolved.
- Verify source data and report bytes, including metadata and interruptions; do not accept a successful share-sheet opening as proof of a correct report.
- Ask target users to read a value, identify its age/uncertainty, establish a baseline, explain a comparison, and finish a workflow. Compare task success and error rates; do not substitute a style preference poll for usability.

## Risks, disconfirmation, and remaining decisions

The main commercial risk is that cheap/free instruments already supply many readings, while hard gating the entire app removes hands-on evaluation before purchase. This is the chosen business constraint. The paywall should demonstrate truthful outcomes and explain device requirements before purchase. A premium appearance alone is not validated willingness to pay.

The main implementation risk is breadth: making every publicly documented API look like a shipping sensor creates misleading empty tools. Each instrument needs a real adapter, capability check, permission journey, calculation contract and physical acceptance. Advanced participating-peer, UWB, NFC, GATT, optical and LiDAR paths must retain their specific dependencies. iOS 27 channel sounding belongs to a separately gated future track, not the iOS 26 promise.

The combined Live / Inspect / Compare composition with adaptive blue and rounded segment labels is approved. Unresolved: final price/product configuration; which optional hardware is available for physical acceptance; and buyer evidence for recurring calibration/reporting jobs. The user's full hard-paywall requirement and no-owner-infrastructure constraint are settled.

## Core evidence register

All accessed September 9, 2026, America/Chicago. A live API page's availability annotation is not its publication date.

| # | Source / owner | Publication or version | What it supports |
|---|---|---|---|
| 1 | [Use Compass on Apple Watch][1] / Apple | Current user guide, undated page | Angular hierarchy, bearing, waypoint views and progressive detail; image inspected |
| 2 | [Oceanic+ on Apple Watch Ultra][2] / Apple | November 28, 2022 | Primary/secondary reading hierarchy, actionable state, session review; image inspected |
| 3 | [CARROT Weather press kit][3] / developer | Version 6.0; page does not state a year | Coupled chart selection and customization; no current price conclusion used |
| 4 | [Visualizing Information on Smartwatch Faces][4] / original research | v2, January 12, 2024 | Systematic design space; full-text introduction and related-work discussion read |
| 5 | [Measures of Scale][5] / NIST | Undated handbook page | IQR/MAD robustness, distinctions between spread summaries |
| 6 | [MEMS Vibration Monitoring][6] / Analog Devices | Undated article as retrieved | Magnitude/frequency, bias, bandwidth, sensor noise and suitability |
| 7 | [CMDeviceMotion][7] / Apple | Current API reference | Attitude, gravity/user acceleration separation, magnetic calibration data |
| 8 | [CMAltitudeData][8] / Apple | Current API reference | Relative altitude in meters and pressure in kPa |
| 9 | [averagePower(forChannel:)][9] / Apple | Current API reference | Digital full-scale audio level and recorder meter range |
| 10 | [URLSessionTaskMetrics][10] / Apple | Current API reference | Task interval and per-transaction measurement context |
| 11 | [CLHeading][11] / Apple | Current API reference | Heading metadata and validity context |
| 12 | [Transaction.currentEntitlements][12] / Apple | Current API reference | On-device purchase entitlement source |

[1]: https://support.apple.com/en-lamr/guide/watch/apd1cd7aad2c/watchos
[2]: https://www.apple.com/newsroom/2022/11/reach-new-depths-with-the-oceanic-plus-app-and-apple-watch-ultra/
[3]: https://www.meetcarrot.com/weather/presskit.html
[4]: https://arxiv.org/html/2310.16185v2
[5]: https://itl.nist.gov/div898/handbook/eda/section3/eda356.htm
[6]: https://www.analog.com/en/resources/analog-dialogue/articles/mems-vibration-monitoring-acceleration-to-velocity.html
[7]: https://developer.apple.com/documentation/coremotion/cmdevicemotion
[8]: https://developer.apple.com/documentation/coremotion/cmaltitudedata
[9]: https://developer.apple.com/documentation/avfaudio/avaudiorecorder/averagepower(forchannel:)
[10]: https://developer.apple.com/documentation/foundation/urlsessiontaskmetrics
[11]: https://developer.apple.com/documentation/corelocation/clheading
[12]: https://developer.apple.com/documentation/storekit/transaction/currententitlements
