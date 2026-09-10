# MagicCuts: expanded measurements and one Pro unlock

Research checked September 9, 2026, America/Chicago. Research inventory and staged implementation plan. The first native Pro implementation now covers the twelve instruments and four packages listed in PRODUCT.md; validation and hardware-specific follow-ups remain separate. Baseline: the existing iOS 26 app. Newer iOS 27 features are identified separately.

> Current commercial direction: one hard Pro paywall covers every existing and new tool. The earlier free/paid split recorded later in this research is superseded. Follow [Pro instrument research](PRO_INSTRUMENT_RESEARCH.md) and PRODUCT.md for implementation authority.

## Decision

Expand MagicCuts into a local measurement toolkit whose readings can be used in Shortcuts. Put basic measurements, individual actions, Device Groups, all existing functionality, and these four selected packages behind one Pro purchase:

- **1. Calibration & Profiles:** repeatable setup, named baselines, threshold recommendations, and comparisons.
- **3. Workflow Builder:** combine measurements into reusable, explainable conditions.
- **4. Field Reports:** projects, test protocols, annotations, and structured exports.
- **5. Live Sessions:** deliberately started recordings, timelines, and supported Live Activities.

Preserve the behavior of manual thresholds, validation, history, Technical mode, and the Boolean action, and require Pro to use them. Device Groups is also paid, including all/any/minimum-count behavior. No free legacy functionality remains.

The promise should be **“Measure your surroundings. Put the results to work in Shortcuts.”** Confidence is high in many underlying public APIs, medium in integration effort and product fit, and low in willingness to pay until real users test the expanded product. No extra owner-paid infrastructure is required by the architecture below.

## Research scope and approach

The question is what an ordinary App Store app can read or interact with on an iPhone, what requires a participating accessory or another device, and what is unavailable or restricted. This is a broad inventory of relevant capability families, not a claim to enumerate every iPhone API. iPad support must be checked independently.

The investigation covered connectivity, physical sensors, camera/audio, device state, accessory inputs, background behavior, free/cheap alternatives, and the four selected Pro packages. Primary Apple documentation was read directly, including linked Markdown versions where the HTML required JavaScript. Competitor pages were used for advertised features and prices, not evidence of demand or quality. Major constraints were checked against both overview and specific API documentation where possible. Apple remains the single platform authority; multiple Apple pages are not independent runtime verification. No new hardware experiments were performed for this report.

Disconfirmation sought: special entitlements mistaken for normal access; an API type mistaken for a usable hardware feed; beta features mistaken for the current baseline; a Live Activity mistaken for unrestricted background execution; free tooling that already solves the proposed paid job; and network tests that secretly require hosting bills.

## Connectivity capability map

“Available” means a documented implementation path exists, subject to permission, hardware, and testing. It does not mean MagicCuts already implements it.

| Capability | What we can expose | Product use and boundary |
|---|---|---|
| **Bluetooth LE advertisements** | RSSI, names, advertised services/data, observation times | Existing foundation. Add sample-quality summaries and supported advertisement decoders. Signal strength is not distance or proof of identity. [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) |
| **Connected BLE sensors** | Read/subscribe to supported GATT characteristics; timestamp incoming values | Add readings from compatible thermometers, humidity sensors, buttons, and other documented accessories. Requires protocol support; not every BLE device exposes understandable measurements. Start with a small tested compatibility list. [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth) |
| **Bluetooth Classic** | GATT communication over BR/EDR for compatible devices | A conditional adapter, not discovery of every headset or arbitrary serial access. Apple’s session explains GATT-over-BR/EDR and service matching after system connection. [WWDC19](https://developer.apple.com/videos/play/wwdc2019/901/) |
| **Current Wi-Fi identity** | SSID, BSSID, security type when eligible | Useful context for a recipe. Requires the Wi-Fi information entitlement and an eligible condition such as precise-location authorization. `fetchCurrent` does not populate signal strength. Ask for location only when the user enables this feature. [fetchCurrent](https://developer.apple.com/documentation/networkextension/nehotspotnetwork/fetchcurrent(completionhandler:)) |
| **Network path and local connectivity** | Available interface/path, constrained/expensive state, IPv4/IPv6/DNS capability; measured requests to a chosen endpoint | Distinguish Wi-Fi, cellular, and wired connectivity where reported. A path being available does not prove internet service. Add bounded TCP/HTTP/DNS tests to a user-chosen local service or permitted endpoint. [NWPath](https://developer.apple.com/documentation/network/nwpath), [networking APIs](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api) |
| **Network link quality** | Apple’s categorical link-quality assessment | Show as context, separate from measured request latency. Apple explicitly says not to use it to gate connection attempts. It is not RSSI, signal bars, or a speed test. [linkQuality](https://developer.apple.com/documentation/network/nwpath/linkquality-swift.property) |
| **Local discovery / peer tests** | Bonjour services and connections between participating apps | A second user-owned phone/iPad can act as a test peer. Measure application round trips and transfer throughput; label these as peer-path results, not internet speed. Local Network permission applies. [TN3151](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api), [TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) |
| **Wi-Fi Aware** | Direct paired connections; peer signal strength, transmit-latency and capacity reports | Strong second-stage opportunity: infrastructure-free peer diagnostics on supported hardware. iOS 26; Apple lists iPhone 12 and later. Pairing, service declarations, and entitlement required. Signal strength is optional and normalized 0–1, not dBm. Does not scan surrounding access points. [Wi-Fi Aware](https://developer.apple.com/documentation/wifiaware), [performance report](https://developer.apple.com/documentation/wifiaware/waperformancereport), [signalStrength](https://developer.apple.com/documentation/wifiaware/waperformancereport/signalstrength) |
| **Ultra Wideband** | Distance and, when supported/available, direction to a participating peer or compatible accessory | Valuable for setup and measurement. Requires session/token exchange and capable hardware on both sides. Not an arbitrary AirTag/Find My reader. Local token exchange avoids a backend. Check feature capability at runtime, not just model age. [Nearby Interaction](https://developer.apple.com/documentation/nearbyinteraction) |
| **NFC** | Read supported tags; write supported writable tags | Use physical tags to identify test locations or recipe profiles. In-app scanning avoids hosted links. Background tag delivery is a system notification/tap flow, not a continuous sensor stream. A separate Apple Shortcuts NFC trigger is a different integration to test. [Core NFC](https://developer.apple.com/documentation/corenfc), [background reading](https://developer.apple.com/documentation/corenfc/adding-support-for-background-tag-reading) |
| **iBeacon / location events** | Monitor configured beacon identities, range supported beacons, use authorized geographic events | Potential low-power context source, distinct from generic BLE scanning. Needs the appropriate location permissions/configuration and known beacon identifiers. No guaranteed precise arrival/departure timing. [iBeacon proximity](https://developer.apple.com/documentation/corelocation/determining-the-proximity-to-an-ibeacon-device) |
| **Cellular condition forecasts** | WirelessInsights predictions of possible service degradation | Later diagnostic context, not measured tower strength or guaranteed predictions. Requires its entitlement and supported device. Keep “prediction” and confidence visible. [WirelessInsights](https://developer.apple.com/documentation/wirelessinsights) |
| **HomeKit / Matter / Thread** | Authorized readings and state from configured/commissioned accessories | Optional future adapter for existing home sensors. Start with reading existing HomeKit accessories instead of building a commissioning platform. ThreadNetwork is chiefly router/network configuration; it is not an unrestricted radio analyzer. Additional user hardware may be necessary. [HomeKit](https://developer.apple.com/documentation/homekit), [Matter](https://developer.apple.com/documentation/matter), [ThreadNetwork](https://developer.apple.com/documentation/threadnetwork) |
| **Wired / specialist accessories** | Supported audio routes, MIDI, and manufacturer-approved External Accessory protocols | USB-C is not a universal serial-device API. USBDriverKit supports macOS and M-series iPads, not iPhone. Offer individual supported integrations, not “read any USB sensor.” [External Accessory](https://developer.apple.com/documentation/externalaccessory), [USBDriverKit](https://developer.apple.com/documentation/usbdriverkit), [Core MIDI](https://developer.apple.com/documentation/coremidi) |
| **Carrier satellite networking** | Detect ultra-constrained paths and adapt permitted networking | Useful for suppressing large tests/transfers. This does not establish access to satellite antenna measurements or an independent satellite messaging service. [Ultra-constrained networks](https://developer.apple.com/documentation/bundleresources/configuring-your-app-for-ultra-constrained-networks) |

**Wi-Fi boundary:** Apple states there is no general-purpose iOS Wi-Fi scanning API. A general channel scanner, surrounding-access-point heatmap, or live cellular dBm display should not be promised. Wi-Fi Aware metrics and the special-purpose Hotspot Helper APIs do not change that. [TN3111](https://developer.apple.com/documentation/technotes/tn3111-ios-wifi-api-overview), [Apple DTS clarification, updated June 18, 2026](https://developer.apple.com/forums/thread/721067).

## Physical measurements and device context

| Input family | Useful measurements/features | Limits and implementation priority |
|---|---|---|
| **Accelerometer and gyroscope** | Acceleration, rotation, device attitude; derived tilt, movement and vibration summaries | First wave. Record actual sample timestamps and rates. Do not claim certified vibration analysis or unlimited frequency response. [Core Motion](https://developer.apple.com/documentation/coremotion) |
| **Magnetometer / heading** | Magnetic-field vector and device heading | First wave. Useful for orientation and repeatable setup; not a general RF spectrum, wiring, or metal-identification instrument. [Core Motion](https://developer.apple.com/documentation/coremotion) |
| **Barometer / altitude** | Pressure and relative elevation change; absolute altitude where supported | First wave. Show units and origin of the reading. Pressure and elevation changes do not by themselves identify a building floor. Query hardware availability. [CMAltimeter](https://developer.apple.com/documentation/coremotion/cmaltimeter) |
| **Location and motion context** | Coordinates, speed, course, accuracy and age; supported step/activity data | First wave for on-demand readings; background recording separately gated. Core Location is a fused result, not proof of a raw GPS fix. [CLLocation](https://developer.apple.com/documentation/corelocation/cllocation), [Core Motion](https://developer.apple.com/documentation/coremotion) |
| **Microphone** | Audio level, frequency spectrum, peaks; optional local sound classifications | Second wave. Apple’s basic meter reports dBFS, not calibrated dB SPL. Keep raw audio ephemeral by default; saving recordings is a distinct user choice. External reference calibration would need validation before any absolute sound-level claim. [Audio metering](https://developer.apple.com/documentation/avfaudio/avaudiorecorder/averagepower(forchannel:)), [Sound Analysis](https://developer.apple.com/documentation/soundanalysis) |
| **Camera / computer vision** | QR/barcode labels, OCR, color samples, document evidence | Second wave. Process locally, request camera access when used. Text or object recognition is inferred and can be wrong. This can label equipment or read a visible instrument display for user confirmation. [Vision](https://developer.apple.com/documentation/vision) |
| **LiDAR / depth / room geometry** | Scene depth, confidence, room dimensions and optional annotated room model | Later wave, supported devices only. Room/depth values are estimates. A spatial test report can attach observed readings to positions; it must not invent an accurate RF coverage surface from sparse samples. [Scene depth](https://developer.apple.com/documentation/arkit/arconfiguration/framesemantics-swift.struct/scenedepth), [RoomPlan](https://developer.apple.com/documentation/roomplan) |
| **Camera lighting estimates** | Relative changes in scene lighting and color temperature | Optional later input. ARKit’s lighting estimate is based on camera exposure and scaled for rendering; do not present it as calibrated lux. [ambientIntensity](https://developer.apple.com/documentation/arkit/arlightestimate/ambientintensity) |
| **Battery / thermal / device state** | Charge level/state, orientation, coarse thermal state, face-proximity state | Useful context and session annotations within Pro. Thermal state is not temperature in degrees; face proximity is not distance to a remote object. [UIDevice](https://developer.apple.com/documentation/uikit/uidevice), [thermalState](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.property) |
| **Audio routes / headphone motion** | Current audio input/output route; motion from supported connected headphones | Optional adapter. Treat an observed route as audio-session state, not a list of all paired or nearby Bluetooth devices. [currentRoute](https://developer.apple.com/documentation/avfaudio/avaudiosession/currentroute), [headphone motion](https://developer.apple.com/documentation/coremotion/cmheadphonemotionmanager) |
| **External environmental measurements** | Temperature, humidity, light, CO₂ or other values from a supported sensor | An accessory feature, not a promise that the iPhone directly measures those quantities. Validate the accessory protocol, units and manufacturer accuracy. No proprietary hardware manufacturing required. |
| **Health / Watch data** | Authorized stored health measurements and watch-sourced observations | Deliberately defer. HealthKit requires a clear health/fitness purpose and permissions; this is not a generic route to every bodily sensor. [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) |

Front-facing TrueDepth is another hardware-dependent camera input worth a later prototype; its availability is separate from rear LiDAR. Biometric authentication is different: Local Authentication returns an authentication result and does not expose underlying biometric data. Haptics and speaker output can provide measurement feedback or deliberate test signals; they are outputs, not additional environmental sensors. [Camera device types](https://developer.apple.com/documentation/avfoundation/avcapturedevice/devicetype-swift.struct), [Local Authentication](https://developer.apple.com/documentation/localauthentication), [Core Haptics](https://developer.apple.com/documentation/corehaptics).

Ambient-light hardware exists, but ordinary utility apps do not gain general access by adding SensorKit. Apple restricts SensorKit entitlements to approved research studies. The independent phyphox project reports the same practical restriction for its iPhone light-sensor feature. [Apple SensorKit setup](https://developer.apple.com/documentation/sensorkit/configuring-your-project-for-sensor-reading), [phyphox FAQ](https://phyphox.org/faq/).

Similarly, a framework containing a temperature data type does not prove that an ordinary iPhone app can obtain useful ambient temperature from the phone. No such input is committed here. Raw GNSS satellite diagnostics, arbitrary RF/spectrum capture, universal accessory battery status, and system-wide sensor access are also not established by this research and are excluded from the feature promise.

## A future capability worth tracking

**Bluetooth Channel Sounding** is a separate iOS 27 investigation. Apple’s sample requires Channel Sounding-capable iPhone hardware, a compatible Bluetooth 6.3 accessory, and AccessorySetupKit pairing. The WWDC26 session describes distance via Core Bluetooth and camera-assisted direction through Nearby Interaction; it explicitly says the session pauses in the background. This could strengthen calibration, field measurements, and foreground sessions, but it does not turn the current advertisement-only BLE action into a precision range finder. Do not bundle a promise to deliver it before testing real compatible hardware. [Apple sample](https://developer.apple.com/documentation/corebluetooth/measuring-distance-between-devices-using-channel-sounding), [WWDC26 session](https://developer.apple.com/videos/play/wwdc2026/369/).

## The exact paywall

One non-consumable **MagicCuts Pro** entitlement covers all four selected packages. No per-sensor charges or separate Field Reports purchase. Price remains a hypothesis: validate the previously proposed $14.99 entry price against $24.99 for the expanded shipped bundle; do not assume the extra sensor count alone supports a higher price.

| User job | Access and current implementation |
|---|---|
| Use any instrument or existing Bluetooth action | Verified Pro purchase required. No free legacy tools. |
| Calibrate and reuse setups | Guided nearby/away trials, named references, source compatibility, aligned comparisons. |
| Build reusable workflows | Named all/any recipes with up to eight sequential median-window conditions; explainable trial result and App Intent. |
| Check a device group | One shared BLE scan; all/any/minimum-count rules. Missing observations remain unknown. |
| Produce a field report | Named project/visit, user-confirmed protocol, notes, attached recordings and PDF/JSON exports. Each session also exports CSV. |
| Record a measurement session | One selected instrument, deliberate recording, event marks, interruption gaps, recovery copies and local Live Activity state. |
| Purchase and recovery | StoreKit purchase, restore, legal links and retry remain available when locked. |

The paywall is separate from hardware and permission states. Buying Pro cannot make unsupported hardware available. All working features require Pro; research ideas listed below remain proposals until implemented and verified. Multi-input recordings, hold rules, recipe import/export, specialist sensor adapters and broader background sensing remain future work rather than hidden controls or placeholder tools.

### 1. Calibration & Profiles

Start with repeatable BLE nearby/away trials and sensor-specific named baselines. Expand to a stable tilt reference, a stationary vibration baseline, and before/after local-network measurements. Calibration here means guided setup and reference comparison, not certification of the hardware. Profiles belong to a source/device/context and record when they were created. Do not apply a Bluetooth threshold to UWB meters or a microphone calibration to a different audio input.

**First acceptance gate:** users finish calibration faster than with current controls, and recommendations survive a separate set of test observations. Overlapping data must produce “cannot distinguish reliably.” Error handling and quality indicators are included throughout Pro.

### 3. Workflow Builder

Use a small visual condition editor, not a second general-purpose automation language. Start with compare, all/any, observed-within, and held-for-a-window operations. Each recipe has a “Test now” explanation and an App Intent returning a typed result plus reason. A rule cannot treat an unknown/stale measurement as false or silently reuse an old success.

Examples: a desk check combining BLE presence, current Wi-Fi identity when authorized, and a successful local-service request; a repeatable setup check combining tilt and an accessory value; an optional pre-recording audio baseline with user-initiated microphone sampling. Shortcuts performs the user-configured downstream work. Sensor access that requires UI opens the app instead of pretending to execute invisibly.

**First acceptance gate:** beginners build and understand one useful workflow unaided. Compare against bundled written recipes. If the editor does not outperform good instructions, simplify it before expanding.

### 4. Field Reports

A report captures a real test job: “desk A versus desk B,” “before versus after moving this accessory,” or “three labeled locations in this room.” It includes source, units, device/OS, sample timestamps, actual sampling cadence, permissions, gaps, selected thresholds and user notes. Start with a small PDF and machine-readable observations. Add room geometry only after the ordinary report proves useful.

**First acceptance gate:** three target users employ reports for real installation or troubleshooting decisions and identify time saved over screenshots or a free logger. Do not equate a pretty PDF with professional demand.

### 5. Live Sessions

Begin with foreground recordings across a selected set of compatible inputs. Add a bounded BLE Live Activity session only after it passes runtime testing. UWB sessions are a later extension. The session UI shows which inputs are currently observing, paused or stale; a single “recording” indicator must not imply every source continues in the background.

**First acceptance gate:** interruption/lock/permission/battery tests establish per-input behavior on physical devices. Preserve partial recordings with marked gaps, stop unused sensors, and show an explicit end state. Keep original short validation-test cancellation behavior unchanged.

## Background behavior is a per-input contract

| Source | Session behavior to plan for |
|---|---|
| BLE on iOS 26 | Apple documents broader scanning privileges when a CBManager exists and a Live Activity starts before backgrounding. Implement and verify this specific path. |
| UWB | Nearby Interaction documents a Live Activity background path on supported versions, with its background capability. Still requires compatible peers and an active valid session. |
| Wi-Fi Aware | Connections can operate when the app has runtime; the connection itself does not grant unlimited runtime. |
| Location / iBeacon | Has source-specific authorized background mechanisms. Do not use location merely to keep unrelated tools alive. |
| Camera / LiDAR / general sensor combinations | Foreground-first. A Live Activity does not grant every sensor access; background behavior is uncommitted until specifically proven. |
| Audio | Recording behavior requires the appropriate audio session and legitimate user-visible use. Do not add silent audio as a keepalive. |
| Channel Sounding | Apple's iOS 27 session says ranging pauses in the background. |

ActivityKit supports local app updates and an eight-hour maximum active lifetime. Design shorter, deliberate sessions and stale dates; no remote push infrastructure is necessary. [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth), [Nearby Interaction](https://developer.apple.com/documentation/nearbyinteraction), [Wi-Fi Aware](https://developer.apple.com/documentation/wifiaware), [ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).

## Implementation shape with no added infrastructure bill

Use a small source-adapter layer, local observation storage, local rules/statistics, native report rendering, App Intents, and StoreKit 2. Avoid a service platform, cloud automation runner, or paid sensor/AI SDK.

Every observation should retain its source, value, units, observation time, receipt time, validity, and available quality metadata. Distinguish `unsupported`, `permissionRequired`, `unavailable`, `stale`, and `measured`. Preserve per-source clocks and record alignment assumptions for multi-input reports. “Connected,” “observed,” “nearby estimate,” and “measured distance” are different results.

Do not store unlimited high-frequency samples in ordinary preference snapshots. Share only compact, timestamped latest results or configuration with App Intents; use a bounded local store/file for recordings. Existing Boolean actions retain their identities and semantics; add richer actions separately.

No owner-operated cloud databases, analytics collectors, managed entitlement service, hosted recipe marketplace, custom remote push provider or paid AI calls. Reports and recipes use Files/share sheets. The September 10 follow-up adds [optional private iCloud portability](ICLOUD_PORTABILITY.md) through Apple CloudKit, off by default on every installation. Peer diagnostics use user-owned devices with an explicitly implemented local protocol. Any future receiver/helper mode must follow the chosen hard-paywall policy; its purchase semantics have not been implemented.

Internet speed tests are excluded from the default design: a public test endpoint is somebody’s infrastructure, and free access is not a durable permission or cost model. Local tests identify their target and path. Any optional user-supplied external target needs clear data limits and permission to use it. Carrier data/accessory purchases may cost users money even when your hosting cost remains zero.

StoreKit 2 can supply verified transactions and entitlements directly to the app. Test restore, offline access, purchase cancellation/pending states, second-device use and revocation. Apple fees, development, maintenance, support and test hardware remain real costs. [StoreKit 2](https://developer.apple.com/storekit/).

## Build order and validation

1. **Finish the current release's physical acceptance.** Do not make the unresolved existing Bluetooth/Shortcuts behavior part of the premium sales promise.
2. **First useful expansion:** motion/tilt, pressure/altitude, on-demand location, battery/thermal context, basic network-path and local-service checks; preserve BLE and add Pro Device Groups. Add capability gating and typed results once for all sources.
3. **First Pro package:** calibration profiles plus a small workflow builder, a foreground recording session and one clear report format. All four paid categories are represented; advertise only shipped behavior.
4. **Second expansion:** microphone/frequency tools, QR/OCR labeling, selected connected BLE sensor protocols, and hardware-tested BLE Live Activities.
5. **Hardware-dependent expansion:** Wi-Fi Aware peer tests and UWB. Add LiDAR/RoomPlan only if field-report users need spatial annotation. Track Channel Sounding as a separate iOS 27 prototype.
6. **Later adapters only with demonstrated jobs:** HomeKit/Matter, headphone motion, MIDI and specialist accessories. HealthKit stays outside the general utility scope.

Verification must include real hardware, denied/revoked permissions, missing hardware, foreground/lock transitions, source interruption, clock alignment, stale observations, app termination, accessibility and data deletion. Tests should demonstrate the actual measured quantity rather than only the UI. For connectivity, report the tested endpoint/protocol and outcomes; for sensors, check units and compare against suitable references before making accuracy claims.

## Market evidence and open questions

Breadth alone is weak paid differentiation. RWTH Aachen’s **phyphox is free** and already offers sensor experiments, exports and local remote control. **SensorLog lists $2.99 in the US plus optional purchases**, and advertises multi-sensor logging, peer streaming and Siri/Shortcuts control. Those are two independent products overlapping this idea. Their presence supports feasibility and competitive pressure, not MagicCuts demand. [phyphox](https://phyphox.org/), [SensorLog](https://apps.apple.com/us/app/sensorlog/id388014573).

The product inference is that MagicCuts should win on understandable measurement-to-Shortcut workflows, setup guidance, and useful handoff reports. Generic logging and graphs are insufficient differentiation. A broad tool shelf can improve discovery, but it should not become a sprawling set of weakly connected mini-apps.

The next decision is which real job leads the first release: personal automation setup, accessory troubleshooting, or repeatable field measurements. Test three concrete prototypes against existing tools before implementing the full inventory. Demand for repeated setup/reporting supports the proposed Pro bundle; demand only for free sensor readouts would weaken it.

## Evidence register

All linked API/competitor pages were opened and read September 9, 2026 local time. Most API pages have no publication date. The table groups related sources; inline links above identify the exact page for each claim. Public documentation establishes an API contract, not App Review acceptance or MagicCuts runtime proof.

| Evidence | Date / status | Why it matters |
|---|---|---|
| Apple TN3111, specific Wi-Fi APIs, TN3151/TN3179 | TN3111 revision August 29, 2025; other pages live | General Wi-Fi restrictions, allowed networking and permissions |
| Apple DTS network-signal clarification | Revision June 18, 2026 | Addresses link quality, WirelessInsights and Wi-Fi Aware exceptions explicitly |
| Core Bluetooth + WWDC19 Classic session | Current docs + 2019 session | BLE/GATT and the actual scope of Classic support |
| Wi-Fi Aware + performance-report APIs | iOS 26/current docs | Direct peers without cloud infrastructure; normalized signal measurement |
| Nearby Interaction + ActivityKit | Current docs | Participating UWB peers, conditional background behavior and lifecycle limits |
| Core NFC + background tag reading | Current docs | Supported tag workflows and user interaction requirements |
| Core Motion, CMAltimeter, CLLocation | Current docs | Motion, pressure, position, units and availability gates |
| AVFAudio, Sound Analysis, Vision | Current docs | Audio and camera processing; dBFS versus absolute sound measurement |
| ARKit sceneDepth/light estimate + RoomPlan | Current docs | Hardware-dependent depth and approximate lighting/geometry |
| UIDevice, ProcessInfo, headphone motion | Current docs | Accessible device context and the limits of those readings |
| HomeKit/Matter/Thread, External Accessory, USBDriverKit, MIDI | Current docs | Supported accessory paths and non-universal access |
| HealthKit and SensorKit setup | Current docs | Purpose/entitlement restrictions; prevents inappropriate roadmap promises |
| Carrier ultra-constrained networking | Current docs | Satellite-path context rather than raw radio diagnostics |
| Channel Sounding sample + WWDC26 | iOS 27 roadmap evidence | Compatible hardware/pairing and foreground-only ranging |
| phyphox homepage/FAQ | Live product pages | Independent free competitor and iPhone sensor restrictions |
| SensorLog US App Store listing | Live price/feature snapshot | Low-price competitor already combines logging and Shortcuts |
| StoreKit 2 | Current docs | Direct purchase/entitlement architecture without an owner-operated server |
