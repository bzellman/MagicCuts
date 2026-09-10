# Instrument visualization and capture research

Research date: September 10, 2026. Status: research and design proposal complete; implementation and physical validation remain. Scope: all 18 selected NFC, cellular, networking, ranging, and LiDAR capabilities, including persistent room capture. Native iOS/iPadOS 26 is the baseline. Device capabilities are checked independently of OS version.

Companion: [Saved-room capture and revision specification](ROOM_CAPTURE_SPEC.md). [Visualization examples](research/instrument-capture/visualization-grammar.png) use synthetic data and are also available as an [exportable PDF](research/instrument-capture/visualization-grammar.pdf). The three room compositions below are generated design proposals, not running software or captured room geometry.

Implementation follow-up: the Room canvas direction was selected. See [Rooms and field instrument implementation / validation](ROOM_INSTRUMENT_VALIDATION.md) for delivered behavior and the separate physical acceptance status. The research claims and generated proposals below remain historical research evidence.

## Recommendation

- Make **Rooms** a saved workspace: capture a room, measure it, reopen it, and save later scans as revisions. Keep the original revision available throughout an update.
- Use **three distinct visual representations**: the detailed surface mesh for inspection, the recognized room model for structural dimensions, and the floor plan for precise selection. A polished room model must retain visible evidence of incomplete capture.
- Use a **record inspector for NFC**, a **waterfall and time series for networking**, **separate observation, forecast, and history views for cellular**, and **spatial overlays for LiDAR and nearby-device ranging**.
- Give every capture the same lifecycle: prepare, acquire, inspect, save, compare. The live instrument remains specific to its source. A scan attempt, a network test, and a room pass are different kinds of records.
- Treat later mesh updating as the first engineering investigation. Apple supports saving spatial maps and relocalizing; that does not establish automatic reconciliation of arbitrary saved dense meshes. [World-map restoration](https://developer.apple.com/documentation/arkit/saving-and-loading-world-data), [mesh-anchor behavior](https://developer.apple.com/documentation/arkit/armeshanchor).
- Prototype **Room canvas** first, with the **Measurement workbench** as its measurement mode and the **Room journal** informing revision review. These are recommendations awaiting a visual choice, not approved implementation decisions.

## Research brief

Extend MagicCuts' existing rounded readings, meaningful blue instrument geometry, and Live / Inspect / Compare pattern. Make capture, saved review, and later updates coherent with the live instruments. A room is a saved, revisitable measurement space with a detailed mesh, a simplified room representation, and version history.

Assumptions: local-first work, optional private iCloud portability, no owner-operated backend or paid data provider, one Pro unlock, supported hardware and source-specific permissions. Updating a room means preserving the prior revision, aligning a new capture when possible, reviewing its relationship to the original, and saving a new revision.

## Research plan

1. Verify each public API's actual data, timing, and availability; distinguish measurements, derived values, estimates, forecasts, and delayed aggregates.
2. Investigate mesh capture, durable storage, relocalization, later captures, revision comparison, and recoverable update behavior. Seek evidence against treating an exported USDZ or a RoomPlan model as a resumable dense scan.
3. Study Apple chart/AR guidance and observed capture, alignment, and review interactions. Target at least twelve primary references and four inspected moving examples; mark still-only references and vendor claims separately.
4. Specify the live instrument, capture flow, saved review, motion, accessibility, and failure states for every selected capability.
5. Produce a reviewable design proposal with an evidence ledger, clear implementation order, and physical acceptance gates.

Important evidence standard: Apple is the authority for its API contracts; multiple Apple pages are not independent runtime proof. Vendor documentation and interface recordings inform product comparison but do not establish MagicCuts implementation or accuracy.

All five research stages are complete. The source ledger covers more than twelve primary references, competing-product documentation, four moving references inspected in playback, disconfirming evidence, the complete selected capability matrix, and implementation acceptance gates. Research included the existing PRODUCT.md, DESIGN.md, capability plan, and instrument screenshots to preserve the app's established visual language.

## What the visuals must communicate

Use the existing SF Pro Rounded readings, monospaced digits, blue instrument geometry, restrained gray surfaces, and Live / Inspect / Compare behavior. Preserve the same unit, color meaning, selection, and baseline as an instrument expands. On compact screens, keep one dominant reading and one primary action; reveal details through selection or a sheet. On iPad, keep the visualization beside its inspector.

The following are proposed product rules, informed by Apple's guidance to choose chart forms around the question and support accessible exploration. [Design an effective chart](https://developer.apple.com/videos/play/wwdc2022/110340/), [Design app experiences with charts](https://developer.apple.com/videos/play/wwdc2022/110342/).

| Data meaning | Visual treatment | Required context |
| --- | --- | --- |
| Observed value | Solid line, point, or surface | Source, unit, timestamp, and validity |
| Derived measurement | Solid geometry with named method | Inputs, baseline/revision, computation method |
| Estimate | Explicit estimate label | Available quality evidence; no invented error bounds |
| Forecast | Separate future region, dashed boundary | Issued time, predicted interval, impact, confidence |
| Delayed aggregate | Histogram or interval summary | Collection interval and report arrival time |
| Missing or invalid | Gap, hatch, or unavailable text | Reason; never substitute zero |
| Previous observation | Muted geometry or comparison trace | Revision/date and whether it was observed again |

Live charts scroll only while following the latest data. Scrubbing enters Inspect and pins the selection; a visible Live action resumes tracking. Keep comparison axes fixed while comparing, disclose clipped ranges, and break lines across missing samples. Large value changes should not animate through fabricated intermediate readings. Render smoothing may stabilize motion, while saved measurements retain the original timestamps and values.

## NFC: inspect a record, then save the read

Apple exposes NDEF status and messages through NFCNDEFTag; identity fields vary by tag protocol. Maximum NDEF message capacity is different from a promise to read all physical memory. [NDEF tag API](https://developer.apple.com/documentation/corenfc/nfcndeftag), [ISO 15693 identity](https://developer.apple.com/documentation/corenfc/nfciso15693tag).

| Selected capability | Live/capture presentation | Saved inspection and comparison |
| --- | --- | --- |
| Tag identity | Protocol/type and identifier after detection; manufacturer only when exposed or explicitly derived from a documented code | Identity summary with the original exposed fields; label absent fields as unavailable |
| Contents | Readable text/URL/record rows; select a record to see type, identifier, payload bytes, and decoding status | Readable/raw toggle preserves selection; compare record additions, removals, and byte changes |
| Storage status | A compact segmented bar for encoded NDEF message size versus reported maximum; read-only/read-write/unsupported state in text | Save capacity, message size, and status at read time; absent capacity suppresses the bar |
| Scan diagnostics | Named steps: detected, connected, status queried, read completed; elapsed time for commands and whole attempt | Timeline of attempts with success, failure, timeout, and user cancellation separated |

**Capture experience.** The user chooses Scan tag; the system reader sheet supplies the acquisition surface. Coaching says to hold the top of the phone near the tag. After a completed read, transition once into the result inspector with Save read and Scan another. A failed read retains a diagnostic result and offers retry; cancelling is not counted as tag failure. Avoid a custom radar animation because the session supplies no proximity-strength stream. Apple's NFC guidance emphasizes the system scanning sheet and concise positioning instructions. [NFC HIG](https://developer.apple.com/design/human-interface-guidelines/nfc).

**Details that improve quality.** An unknown record remains inspectable as bytes. A malformed text encoding receives a local explanation without discarding the record. Opening a tag URL is a separate deliberate action. Identifier matching is a convenience for finding earlier reads, not proof of authenticity. NFC Tools is a useful reference for the breadth of identity, records, and export information; its advertised raw-memory abilities must not be generalized to every tag. [NFC Tools for iOS](https://www.wakdev.com/en/apps/nfc-tools-ios.html).

Measure command duration with a monotonic clock from issuing the app command to receiving its completion. Label it app-observed duration; it includes software/session effects and is not isolated radio airtime.

## Cellular: distinguish performance from radio context

Reported radio technology can describe service registration; it does not prove which interface carried a request. A request qualifies for the cellular test only when its actual transaction metrics establish cellular use. Setting URLSession's cellular permission alone does not force that route. [Reported radio technology](https://developer.apple.com/documentation/coretelephony/cttelephonynetworkinfo/servicecurrentradioaccesstechnology), [transaction metrics](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics), [required interface type](https://developer.apple.com/documentation/network/nwparameters/requiredinterfacetype).

| Selected capability | Instrument visualization | Capture and saved review |
| --- | --- | --- |
| Reported network technology | A labeled LTE/5G step track, per service when available; unavailable is an explicit state | Preserve technology changes as context events; do not invent signal bars from the technology name |
| Actual connection performance | Response-time trace with median, p95, maximum, timing variation, and a separate failure track; throughput gets its own unit/axis | Save endpoint, actual route, test interval, bytes, configuration, and sample count; split or flag route changes |
| Upcoming service degradation | A future interval band with expected impact and confidence, separated from measured history | Retain forecast issue time and predicted window; show entitlement/device unavailability clearly |
| Historical reception quality | Duration histogram by reported signal level, with collection dates above the plot | Show report interval and arrival date; compare equivalent coverage periods, not individual moments |

WirelessInsights offers forecasts on supported devices with the required entitlement; underlying live radio measurements are not exposed as a general signal meter. A missing forecast is not an assurance of healthy service. [WirelessInsights](https://developer.apple.com/documentation/wirelessinsights). MetricKit's cellular metric is a distribution of connectivity time, not a live sample stream. Current documentation marks the legacy MX API through the iOS 27 transition; implementation should use the project's iOS 26 API and assess the newer API separately when adopting a newer SDK. [Cellular condition metric](https://developer.apple.com/documentation/metrickit/mxcellularconditionmetric). Apple DTS also confirms the lack of a general-purpose public iOS cellular signal-strength API. [Apple developer response](https://developer.apple.com/forums/thread/721067).

**Capture experience.** Choose response test or data-transfer test, endpoint, and duration/data budget. Establish and verify the route, then show progress as actual samples or bytes. If Wi-Fi carries a request, report that fact and offer to retry after changing connectivity; never silently relabel it. Show the completed sample set immediately, even when some requests failed. History and forecasts remain secondary views so delayed information cannot look live.

## Networking: explain where time went and whether it repeats

| Selected capability | Instrument visualization | Capture and saved review |
| --- | --- | --- |
| DNS, connection, TLS, response timing | A request waterfall with aligned timestamps; TLS nested inside connection establishment | Inspect each transaction in redirects; show protocol, cache/reuse status, and absent timing fields |
| Connection consistency | Time series plus median/p95/maximum, sample count, variation, failure rate, and observed route/session events | Scrub a failure to its reason; compare equal windows and equivalent endpoints/test settings |
| Local-network performance | Round-trip trace plus separate upload/download throughput traces to an identified participating peer | Save peer, direction, payload bytes, duration, transport, and whether throughput measures application payload |
| Paired-device radio quality | Separate rows for observed throughput, estimated capacity, transmit latency, and optional signal strength | Preserve each report's timestamp and available fields; hardware ceiling and estimated capacity are different from measured transfer speed |
| Nearby-device distance and direction | Large distance plus a phone-relative direction arrow when available; range-only layout otherwise | Save peer session and measurement timestamps; show gaps when range or direction is unavailable |

For the waterfall, connection time can contain the TLS interval; adding both as consecutive blocks double-counts elapsed time. Request-end to response-start is waiting for the first response byte, including network and server effects, not isolated server processing. Reused or cached transactions may have absent phase timestamps. Label transport as reported because connection setup is not always TCP. [URLSessionTaskTransactionMetrics](https://developer.apple.com/documentation/foundation/urlsessiontasktransactionmetrics).

Repeated HTTP failures are **request failures**, not measured IP packet loss. A timeout belongs in the failure track, not as a zero-millisecond latency sample. Keep successful-sample percentiles separate from the failure denominator. An app suspension produces an observation gap; it does not establish a network disconnect. PingPlotter's selectable timeline is a useful inspection reference, while its packet-loss semantics apply to its own probing method. [PingPlotter timeline graphs](https://www.pingplotter.com/fix-your-network/getting-started/timeline-graphs/).

For the first implementation, define response-time variation as p95 minus median over successful probes in the selected window. Show sample count, median, p95, observed maximum, and failed/attempted counts together. This is a proposed display convention, not an IP packet-jitter metric or a claim that the observed maximum bounds future latency.

Wi-Fi Aware reports optional peer-link observations and estimates. Estimated current capacity, ideal hardware throughput ceiling, and measured application throughput must be individually named. [WAPerformanceReport](https://developer.apple.com/documentation/wifiaware/waperformancereport). Nearby Interaction requires compatible participating hardware; do not imply generic ranging to any nearby device or AirTag. [Nearby Interaction](https://developer.apple.com/nearby-interaction/).

**Capture experience.** Configure target and test bounds, connect the peer when needed, begin the test, then inspect a result. Peer pairing should show both participants' names and readiness before traffic starts. Keep Stop visible and enforce the selected byte/time budget. In range mode, use a clear search state before valid direction appears, remove a stale arrow promptly, and retain the last reading only with its age and an inactive appearance.

## LiDAR instruments: show both the measurement and its basis

| Selected capability | Instrument visualization | Capture and saved review |
| --- | --- | --- |
| Distance and clearance | Surface reticle, camera-to-hit distance, stable-point indicator, and change from the chosen baseline | Save the hit position, camera position, timestamp, method, and quality evidence; label the distance origin |
| Width, height, separation | Two visible endpoints with a dimension line and large reading; optional clearly indicated snapping | Pick A, pick B, adjust/Undo, save; preserve endpoint coordinates and owning room revision |
| Surface orientation and shape | Selected patch with fitted plane, normal/slope indicator, and residual-height plot | Save patch extent, fit method, orientation reference, sample count, and residual summary |
| Depth distribution and confidence | Fixed-scale sequential depth colors with a meter legend; switch to a categorical confidence overlay | Freeze a frame, inspect pixels/region, save selected depth evidence and capture settings |
| Room geometry | Detailed mesh, simplified structure, and orthographic plan as distinct views | Inspect wall/opening dimensions, closed footprint area, and explicitly qualified volume; save as a revisitable room |

Apple's reconstructed-scene sample explicitly notes that plane detection can flatten slightly uneven mesh surfaces. Therefore a broad-unevenness instrument must use a validated raw-depth or appropriate non-flattened geometry path; a flattened mesh cannot support that claim. [Reconstructed-scene sample](https://developer.apple.com/documentation/arkit/visualizing-and-interacting-with-a-reconstructed-scene).

ARDepthData's confidence map classifies individual depth pixels. It is optional and affected by difficult surfaces. It is not a calibrated probability or a per-face mesh accuracy certificate. Use categorical labels and patterns rather than converting its levels into percentages or claimed centimeter error. [Depth confidence map](https://developer.apple.com/documentation/arkit/ardepthdata/confidencemap).

**Capture experience.** Enter the chosen measurement mode, acquire valid tracking/depth, then invite one physical action at a time. Point tools use a central reticle and one prominent capture button. After the second point, freeze a review that permits endpoint correction. If the surface cannot be measured, keep the camera view and offer specific coaching rather than placing a plausible-looking point. Show estimated precision conservatively until physical measurements justify a display policy.

For depth inspection, use a perceptually ordered palette such as cividis; provide near/far ticks and a separate clipped-range indication. Invalid pixels are transparent or hatched. Confidence mode uses discrete categories and a legend. Keep exposure/visual texture separate from measurement quality. A photorealistic texture may make a scan attractive without making it more accurate.

Area requires a valid closed floor outline with holes handled explicitly. For a first implementation, volume may be an estimated footprint-times-height result only when that model fits the captured room; label the method and missing ceiling/height information. Do not silently close an incomplete room or turn unknown area/volume into zero. RoomPlan provides recognized components and dimensions; derived area/volume still needs our geometry validation. [RoomPlan overview](https://developer.apple.com/augmented-reality/roomplan/).

## Rooms: capture, save, reopen, update

The core product should behave like this:

1. **Capture.** Choose New room, scan the visible space, and see actual observed coverage accumulate. Guidance names the next useful action: move slowly, look toward a missed wall, or revisit a reference view.
2. **Review.** Orbit the mesh, switch to plan, inspect dimensions, and identify incomplete regions. Review exists before naming/saving so the user can continue the scan when useful.
3. **Save.** Create Room → Revision 1 with the mesh, semantic model, measurements, metadata, and any resumable alignment assets. A successful local save is immediately usable.
4. **Reopen.** View and measure the saved room without starting the camera. Clearly distinguish available viewing, measurement, and update capabilities.
5. **Update.** Show the previous reference photo and help the user return to a recognizable view. Only overlay geometry in the camera after successful alignment.
6. **Review the new pass.** Show prior geometry, observed geometry from this pass, and areas not observed this time. Permit side-by-side comparison with linked camera views. Preserve uncertain changes as uncertain.
7. **Save a new revision.** Keep Revision 1. Save Revision 2 with parentage and alignment evidence, or discard the new pass. Failed alignment offers retry or a separately positioned revision with spatial comparison unavailable.

Apple's RoomPlan demonstration shows semantic multiroom assembly and model preview. Its API requires input rooms in compatible coordinate systems, supplied by a continuous session or successful map restoration. That is useful for spatial continuity, but is a different problem from fusing every surface in an old dense mesh with a newly changed scene. [WWDC23 RoomPlan enhancements](https://developer.apple.com/videos/play/wwdc2023/10192/), [StructureBuilder coordinate requirements](https://developer.apple.com/documentation/roomplan/structurebuilder/capturedstructure(from:)).

Polycam's Extend workflow independently demonstrates the consumer value of returning to an earlier scan: start in overlapping surroundings, relocalize, capture more, review alignment. Its current documentation requires retained raw data and the original device, and warns that changing surroundings and repeated extensions can affect results. This supports the workflow direction, not an assumption about MagicCuts' underlying implementation. [Polycam Extend documentation](https://learn.poly.cam/hc/en-us/articles/36635635851924-How-to-Use-the-Extend-Tool-in-Space-Mode).

The [companion room specification](ROOM_CAPTURE_SPEC.md) defines data retention, revisions, alignment failures, rendering, and physical acceptance in detail.

## Three room compositions

These generated compositions use the existing app screenshot as visual grounding. All sample readings are illustrative. Their mesh detail and measurements have no physical evidentiary value.

| Option | Composition | Best use and tradeoff |
| --- | --- | --- |
| [1. Room canvas](research/instrument-capture/01-room-canvas.png) | The saved mesh dominates; Mesh / Plan / Measurements stays directly below it, with Update room prominent | Recommended room home. Makes the stored space tangible; detailed editing moves into a focused mode |
| [2. Measurement workbench](research/instrument-capture/02-measurement-workbench.png) | Orthographic plan, selected opening, and large dimension with endpoint tools | Strongest measurement mode. Supports precise selection but conveys less of the scanned surface detail |
| [3. Room journal](research/instrument-capture/03-room-journal.png) | Model above revision history with current-pass coverage and comparison access | Strongest return-visit review. Adds history density to the first view |

The three options change hierarchy, not measurement semantics. All need visible missing-data states, immutable revisions, and a deliberate Update room action. The illustrated area marked not observed is a prior/unknown region; implementation must never fill it with invented current-pass geometry.

## Moving references and what to adopt

The following four references were opened, played/scrubbed, and inspected at multiple states on September 10, 2026. They are recorded examples, not hands-on tests of the current installed apps. Only the behavior actually inspected informs the observations below.

| Moving reference | Inspected behavior | Proposed transfer to MagicCuts |
| --- | --- | --- |
| [Apple RoomPlan, WWDC23](https://developer.apple.com/videos/play/wwdc2023/10192/?time=624), demo around 10:24–10:53 | Export/share sequence and assembled dollhouse preview after capture | Separate acquisition, save/export, and calm spatial review; make the model itself the review surface |
| [Watch camera pairing, 60fps shot 1647](https://60fps.design/shots/watch-setup-apple-watch-camera-scan-interaction) | Yellow acquisition outline, green detected outline, then software-update handoff | Give alignment a visible state change before showing the next decision; use the app's own palette and accompanying text |
| [Find My ranging, 60fps shot 0393](https://60fps.design/shots/apple-find-my-finding-key-gyroscope) | Large direction arrow and numeric range transition into a proximity circle, followed by the item graphic | Reduce competing detail as the user approaches; keep sensor validity responsible for transitions |
| [Scaniverse capture tutorial](https://dev.scaniverse.com/support), embedded “How To Scan,” especially 0:35–0:51 | Moving around the scene while a live capture inset changes; coverage improves through different views | Coach physical movement and useful coverage; this is a Gaussian-splat tutorial, so its visual sharpening is not mesh-confidence evidence |

Additional still/text references: NFC Tools' information hierarchy, PingPlotter's focused timeline, and Polycam Extend's re-entry sequence. They were read as product documentation; no hands-on verification of their apps is claimed.

## Motion, accessibility, and rendering specification

These are proposed tuning targets to validate in a native prototype, not measured timings from the reference recordings.

| Interaction | Proposed behavior | Reduced-motion/accessibility equivalent |
| --- | --- | --- |
| Valid point acquired | A short reticle settle and optional single haptic; value stays legible | Shape and text change; spoken availability on transition |
| Point saved | Endpoint remains fixed while its label resolves; brief confirmation | Immediate endpoint and confirmation; no required motion |
| Room coverage added | Fade in only newly observed patches over roughly 150–250 ms | Immediate patch appearance with pattern/legend |
| Mesh → Plan | Brief camera reorientation around the current selection, roughly 250–350 ms | Immediate orthographic view retaining selection |
| Relocalization succeeds | Reference cue resolves, aligned outline appears, capture becomes available | Text/status announcement and enabled action |
| Live → Inspect | Pin the chosen sample; keep the selected timestamp and reading stable | Accessible adjustable selection and equivalent value list |
| Revision comparison | Matched framing and linked cameras; deliberate swipe or side-by-side control | Previous/next revision controls plus dimension-change list |

Use large targets, Dynamic Type, and a textual alternative for every chart or mesh-dependent result. VoiceOver should encounter the mode, selected value, its unit and quality, then available actions. Do not announce every live sample. Provide a component/measurement list for room review so orbit gestures are not required to understand dimensions. Apple demonstrates built-in accessible coaching in its RoomPlan session; custom coaching must preserve equivalent guidance. [RoomPlan enhancements](https://developer.apple.com/videos/play/wwdc2023/10192/).

Render room geometry with neutral surfaces, restrained edge contrast, and one selected accent. Remove occluding walls only as a visible viewing mode, leaving the source geometry intact. Avoid constant automatic orbiting, decorative scan beams, or a progress percentage without a defensible denominator. On large scenes, simplify display geometry separately from the retained measurement data. Keep geometry processing off the main/render-critical path and profile on the oldest supported LiDAR device before setting a performance promise.

An optional later combination is to attach network samples to room locations. Show discrete, timestamped observations tied to a room revision. An interpolated, fully colored Wi-Fi heatmap would suggest RF measurements and coverage we did not collect; it needs its own sampling and modeling validation before becoming a feature.

## Implementation order and acceptance

Priority is based on dependency and uncertainty, not on assumed engineering duration. Each phase should produce a usable capture-to-review path.

| Phase | Deliverable | Evidence needed before calling it complete |
| --- | --- | --- |
| 1: feasibility and source capture | Room save/relaunch/relocalize investigation; NFC read; request transaction capture | Real device outputs, retained artifacts, unavailable/error behavior; no mocked success |
| 2: first useful experiences | NFC inspector; request waterfall/consistency; LiDAR distance/two-point capture; Room Revision 1 | End-to-end acquisition, save, reopen, inspect, and export; physical dimensional references |
| 3: return visits | Room revision update/review; surface/depth inspection; cellular route-verified tests | Changed-room and failed-alignment matrix; raw/processed geometry distinction; mixed-route handling |
| 4: participating devices | Local-peer benchmark, Wi-Fi Aware details, UWB range/bearing | Two actual compatible participants; disconnect/reconnect and optional-field behavior |
| 5: supported supplemental signals | WirelessInsights and delayed MetricKit history | Entitlement/device proof and real delivered payloads; no-data and unsupported states |

| Area | Required cases |
| --- | --- |
| NFC | Text, URL, multiple records, malformed/unknown payload, read-only, unsupported NDEF, lost tag, cancellation, timeout, variable identity fields |
| Network | Fresh and reused connection, redirect, cache, timeout, HTTP error, no connectivity, route change, zero successful probes, interrupted app, bounded bytes/time |
| Cellular | Wi-Fi enabled during test, verified cellular transaction, technology unavailable, dual service, route change, forecast unavailable, delayed/empty history |
| LiDAR measurements | Valid/invalid depth, glass/dark/reflective surfaces, different ranges and angles, point adjustment, baseline replay, plane-flattening effects, external tape/level comparisons |
| Room persistence | Save/relaunch offline, interrupted write, low storage, missing optional map, older revision restore, cloud conflict, view on another device |
| Room updates | Same room next day, changed light, moved chair, newly visible area, unseen old area, alignment failure, tracking loss mid-pass, save/discard after failure |
| Peer instruments | Unsupported hardware, pairing failure, peer disappears, missing optional reports, range-only, stale direction, foreground/background transitions |
| Visual experience | Light/dark mode, large text, VoiceOver, Reduce Motion, color-vision differences, empty/partial/large captures, responsive interaction under capture load |

No implementation, sensor accuracy, runtime performance, entitlement approval, or physical acceptance test is claimed by this research delivery. The immediately reviewable result is the design/data contract, source evidence, generated compositions, and illustrative plots.

## Evidence ledger and unresolved questions

All links in this document and its companion were consulted September 10, 2026. Apple documentation was read through page text, its published Markdown form, or session transcripts where required. The ledger below identifies authority and limits; inline citations locate the specific claims.

| Source group | Publication context | Authority and limit |
| --- | --- | --- |
| Apple Core NFC and NFC HIG | Current documentation | Primary API/UI requirements; individual tag behavior still needs hardware testing |
| Apple Core Telephony, URLSession metrics, Network interface requirements | Current documentation | Primary field and route contracts; do not prove a particular completed test's route |
| Apple WirelessInsights, MetricKit, DTS signal-strength response | Current docs; DTS response checked June 2026 date | Primary availability/data constraints; actual entitlement and received reports unverified |
| Apple Wi-Fi Aware and Nearby Interaction | Current documentation | Primary peer capabilities; device-pair availability unverified |
| Apple ARKit mesh/depth/world-map and RoomPlan export/StructureBuilder docs | Current documentation | Primary representation/restoration contracts; no arbitrary dense-mesh merge guarantee |
| Apple RoomPlan enhancements session | WWDC 2023 | Primary sample architecture and demonstrated interaction; recorded demonstration |
| Apple chart design sessions | WWDC 2022 | Primary design guidance; proposed timings and exact MagicCuts layouts are our design decisions |
| Polycam Extend | Current vendor help page, undated | Independent product workflow reference; vendor-stated restrictions, no independent accuracy test |
| Scaniverse support/tutorial | Current vendor page; video publication date not asserted | Independent capture-coaching reference, specifically splat-oriented material |
| NFC Tools and PingPlotter | Current vendor product/help pages, undated | Information-hierarchy and inspection references; their measurements do not transfer automatically |
| 60fps Watch and Find My recordings | Publication dates not asserted | Observed UI behavior; secondary recordings, no new physical API evidence |

The main unresolved engineering question is how reliably a new pass can align to and reconcile the old detailed mesh under real room changes. Secondary questions are display precision after physical characterization, file-size/retention costs, cross-device update support, and actual WirelessInsights/peer capability availability. The proposed room bundle preserves enough provenance to investigate these without overwriting the user's earlier capture.
