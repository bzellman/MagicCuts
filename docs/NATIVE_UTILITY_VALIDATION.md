# Native Utility validation

September 12, 2026. User-approved **C · Soft forms**, implemented on `codex/native-utility-redesign` from the cleaned-up journey plus main's Bluetooth and mesh fixes (`2547937`). This is a local native UI delivery; no release or production promotion is claimed.

## Delivered behavior

Home uses a compound source group, softly rounded content surfaces, a recessed mode track, SF Rounded readings and matching capsule actions. Blue denotes interaction; teal denotes a defined measurement interval. Baseline and the full calibration target fit above Log/Record on the tested phone's initial Bluetooth Gauges viewport. Home and Settings retain the existing journey.

The twelve instruments retain their appropriate scales, units and missing-data rules. Inspection and saved evidence cover traces, spectrum, baseline comparison, request phases, depth/confidence grids, fitted surfaces, cellular forecast/history, peer ranging, NFC records, room mesh and plan. DEBUG sample fixtures are visibly labeled and remain separate from live observations. The spectrum fixture passes an illustrative waveform through the actual spectrum transform.

LiDAR measurements open into the camera stage automatically, subject to the system permission and device support. Mode changes keep the session; leaving stops a session owned by the tool while retaining an existing room-location session. Room capture and revisit use the same stage. Saved room geometry remains directly inspectable.

## Native screenshots

These are native simulator captures, with illustrative data where labeled. The camera fallback shows the simulator's actual lack of LiDAR support.

| Surface | Capture |
| --- | --- |
| Final phone Home | [Light](../.impeccable/review/native-utility/phone/pro-live-light.png), [dark](../.impeccable/review/native-utility/phone/pro-live-dark.png) |
| Tablet Home | [Light](../.impeccable/review/native-utility/tablet/home-light.png), [dark](../.impeccable/review/native-utility/tablet/home-dark.png) |
| Large text | [Phone reading](../.impeccable/review/native-utility/phone/pro-largest-reading.png), [tablet controls](../.impeccable/review/native-utility/tablet/pro-largest-controls.png) |
| Physical tools | [Phone camera fallback](../.impeccable/review/native-utility/phone/native-camera-distance.png), [tablet camera fallback](../.impeccable/review/native-utility/tablet/native-camera-distance.png) |
| Inspection and comparison | [Info](../.impeccable/review/native-utility/phone/pro-inspect-dark.png), [Compare](../.impeccable/review/native-utility/phone/pro-compare-dark.png), [spectrum detail](../.impeccable/review/native-utility/phone/pro-vibration-spectrum.png) |
| Room geometry | [Mesh](../.impeccable/review/native-utility/phone/room-mesh-dark.png), [plan](../.impeccable/review/native-utility/phone/room-plan-dark.png) |
| Saved field evidence | [Depth](<../.impeccable/review/native-utility/phone/family-Depth patch.png>), [surface](<../.impeccable/review/native-utility/phone/family-Surface patch.png>), [forecast](<../.impeccable/review/native-utility/phone/family-Cellular outlook.png>), [history](<../.impeccable/review/native-utility/phone/family-Cellular history.png>), [peer range](<../.impeccable/review/native-utility/phone/family-Peer range.png>), [NFC](<../.impeccable/review/native-utility/phone/family-Desk tag.png>) |

The [review packet](../.impeccable/review/native-utility/review-packet.md) lists the wider capture set. [Portable evidence](validation/native-utility-evidence.json) records test results, source hashes and screenshot hashes. Workflow and family captures precede the final compact Bluetooth first-viewport adjustment; the light/dark Home pair and focused accessibility test were recaptured after that correction.

## Verification

Dedicated iPhone 17 Pro / iOS 26.5 and iPad Air 11-inch M3 / iPadOS 26.5 simulators were used. Tests ran serially with durable xcresult bundles under `/tmp/magiccuts-native-utility/`; compact results are retained in the portable evidence record.

| Result bundle | Result and scope |
| --- | --- |
| `phone-finish.xcresult` | **89 passed, 0 failed**: 88 core tests plus the Home accessibility journey in both light and dark, including the calibration-above-dock assertion. The separate StoreKit purchase class was excluded after its environment failure. Parameterized invocations are not counted as extra test cases. |
| `phone-completion.xcresult` | **3 passed**: baseline → comparison → record → mark → save → export → field report; Start Flow; sample spectrum. |
| `phone-reviewed.xcresult` | **5 passed, 1 subsequently resolved**: actual selection of all twelve instruments and large text; Home accessibility; automatic camera entry/mode changes/reentry; dark room mesh/plan; seven saved visualization families. Baseline journey's test navigation failure was resolved in `phone-completion`. |
| `tablet-reviewed.xcresult` | Home at largest text passed. Three test navigation failures were resolved by scrolling the presented native List instead of Home behind the floating sheet. |
| `tablet-completion.xcresult` | Automatic camera navigation passed. Two offscreen accessibility-sampling failures were resolved in the next run. |
| `tablet-a11y-completion.xcresult` | **2 passed**: five field-tool ready states and largest-text room controls. Cellular explanatory text was scrolled into view and audited there. |

Accessibility audits cover contrast, hit regions, descriptions and traits. XCTest samples text beneath native chrome and beyond floating sheet edges; the test helper restricts those samples to the visible viewport and audits relevant content after scrolling. One Room composite contrast false positive was narrowed to the exact duplicated label/frame and checked against actual image colors; other contrast checks remain active. No application compiler warnings remain in the final build.

The independent Impeccable [finish review](../.impeccable/review/native-utility/finish-review.md) required one correction: make Baseline/calibration visible in the initial phone viewport. The [verdict pass](../.impeccable/review/native-utility/finish-verdict.md) scored it resolved, found no regressions and returned **ship** for the scored correction. The registered reviewer role was unavailable, so a fresh independent default agent followed the shipped fallback contract.

The measured comp diff is **77%**, with position-sensitive missing/contradicted crops caused by native chrome and layout adaptation; it is **not a passed automated fidelity gate**. Its complete images and region pairs were inspected, and the native adaptations were judged in the independent review. The generic web phase stays open; the [native ledger](../.impeccable/build/native-utility-state.json) records the applicable result. No HTML/CSS detector ran on SwiftUI. The app ships native text, symbols, charts and geometry, with no generated UI raster plates.

## Remaining acceptance limits

Live LiDAR/camera frames, physical distance accuracy, interruption on a real LiDAR device, peer radio hardware, background Shortcut execution and storefront acceptance require their existing physical/external gates. Simulator samples cannot establish those outcomes.

The local StoreKit 26.5 scheme failed before purchase because `SKTestSession` could not configure its environment (`SKInternalErrorDomain` code 3), consistent with the existing [Pro validation record](PRO_VALIDATION.md). Commerce implementation and configuration were not changed. No purchase or release acceptance is inferred from this UI delivery.
