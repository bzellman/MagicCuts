# MagicCuts: five monetization plans without new infrastructure bills

> Superseded commercial proposals: the current user direction is one hard Pro paywall covering all existing and new functionality, including Device Groups. There is no free legacy tier. The original options, prices, and free-tier recommendations below remain research history only. See [Pro instrument research and approved constraints](PRO_INSTRUMENT_RESEARCH.md) and [capability inventory](CAPABILITY_EXPANSION_PLAN.md).

Research date: September 9, 2026, America/Chicago. Decision brief, not an implementation commitment. Prices below are proposed US-dollar experiments, not proven willingness to pay.

## Executive summary

- Start with **Calibration Pro**, then **Device Groups**, sold together through a **$14.99 one-time Pro unlock**. This is a product judgment with medium confidence, not a revenue forecast.
- Preserve existing free functionality. Charge for additional decisions, configuration reuse, and guided workflows; ordinary correctness and error explanations stay free.
- Raw scanning, charts, exports, and generic Shortcut actions face substantial free competition. Differentiate around completing a working proximity automation.
- A fifth option, **Live Sessions**, has a documented iOS 26 technical path through Core Bluetooth plus Live Activities. Its actual reliability and battery cost remain unproven in MagicCuts.
- All five can use local computation and storage, bundled content, and Apple-managed purchases. No owner-operated server, paid API, push service, account database, or usage-based SaaS is required.
- Confidence is high in the no-new-hosting architecture, medium in relative product fit, and low in demand and prices until tested with buyers.

## Objective, assumptions, and method

Find five concrete additional feature packages that could monetize the current iOS/iPadOS MagicCuts app while adding zero owner-paid infrastructure costs. Assume US consumer pricing, an existing Apple developer membership, and buyers interested in Shortcuts and compatible BLE accessories. Development, support, devices, commissions, and taxes still cost money or time.

Research covered paid automation utilities, free substitutes, Apple purchase and execution rules, and primary RSSI research. Disconfirming questions: can a free app do this already; does the feature depend on unreliable background execution; would a subscription promise more value than we deliver; and does the idea simply repackage current free functionality? The evidence target was 8–12 credible sources including at least three primary sources. Twelve sources were opened and read below. Apple JavaScript documentation was read through its linked Markdown representation when the web renderer returned a shell.

The local README establishes the baseline: saved devices, manual thresholds, nearby/away validation, local history, Technical mode, and a Boolean Shortcut action already exist. None counts as a new paid feature here. Actual hardware Shortcuts acceptance remains unfinished; monetization should follow that acceptance, not disguise it.

## The five plans

### 1. Calibration Pro: turn trial and error into a guided setup

**Buyer and job:** a Shortcuts user whose automation behaves differently with a phone on the desk versus in a pocket. “Help me choose settings that work in my actual setup.”

**New paid features:** guided repeated nearby/away trials; separate desk, pocket, and bag profiles; distribution comparison; a proposed threshold with an explicit overlap warning; and a new advanced action that can return nearby, below-threshold, inconclusive, or unavailable with sample evidence. Preserve the original Boolean action and its semantics. Describe any scores as observed sample quality, not a probability of physical presence.

**MVP:** one guided calibration workflow, two saved context profiles, comparison of trial distributions, and explicit user acceptance before applying a recommendation. Refuse a confident recommendation when the distributions overlap. Retest on observations that were not used to pick the threshold.

**Why pay:** less setup effort and fewer unexplained decisions. The differentiation is the guided decision, not the graph. Researchers observed material effects from handset orientation, bodies, and surroundings; the study is an older handset experiment, not a MagicCuts performance benchmark. [Leith and Farrell, 2020](https://arxiv.org/abs/2006.06822).

**Commercial plan:** anchor a $14.99 one-time Pro unlock here. Keep manual calibration and essential recovery free. Show the upgrade after a user has obtained a working basic reading and wants context profiles or assisted tuning.

**No-infra implementation:** statistics and profiles on-device; reuse the current sampler and local persistence. No AI service is needed.

**Validation gate:** in a proposed 10-person pilot, at least seven should finish setup without assistance and prefer the result to manual tuning. Measure setup time and held-out misclassification; stop if improvement disappears outside the training trials. Commercial demand still requires actual purchases after a compliant launch. **Effort:** medium. **Product confidence:** medium.

### 2. Device Groups: check a whole setup in one action

**Buyer and job:** a user with several compatible advertising accessories. “Before I start this workflow, check my whole setup.” Examples include a desk setup or a portable kit, using only hardware proven discoverable.

**New paid features:** named groups; one bounded scan shared across group members; all/any/minimum-count policies; a structured result with each member’s reading age and state; and an action returning devices that did not meet the check. Say “not observed,” never “left behind.”

**MVP:** group editor, one shared observation window, and one App Intent that returns aggregate plus per-device evidence. Errors and insufficient observations must remain visible instead of silently becoming absence. Keep individual-device checks free.

**Why pay:** replace repetitive Shortcut wiring with a reusable, inspectable check. Generic logic alone is weak differentiation: Actions already provides logical operations and Bluetooth-related actions for free, although its listing does not establish identical advertising-proximity semantics on every platform. [Actions](https://sindresorhus.com/actions).

**Commercial plan:** include in the same $14.99 Pro unlock; it makes the purchase useful after initial calibration. Avoid a separate charge for every saved device.

**No-infra implementation:** local group definitions and one radio session; no account, inventory server, or fleet database.

**Validation gate:** users should successfully replace a multi-action Shortcut and repeat the check on at least three supported accessory combinations. Test sparse advertisers, one unavailable member, mixed thresholds, cancellation, and runtime limits. Abandon “kit check” positioning if target accessories commonly stop advertising. **Effort:** medium. **Product confidence:** medium.

### 3. Workflow Builder: reusable proximity recipes with explanations

**Buyer and job:** a less technical automation user. “I know what I want to happen, but I do not want to build a complicated Shortcut.”

**New paid features:** a small visual builder for named proximity conditions; profile selection; a dry-run explanation of which condition passed or failed; local export/import of recipes; and bundled, maintained setup guides for desk, exercise, and travel workflows. A recipe is evaluated when invoked; it is not a continuously running trigger.

**MVP:** three thoroughly tested recipes and one “Evaluate MagicCuts Recipe” action. Users add the downstream actions in Shortcuts; do not promise programmatic installation or execution of arbitrary Shortcuts. Start with BLE conditions and already available local settings to avoid expanding permissions.

**Why pay:** understandable setup and reuse. Competition is substantial: Toolbox Pro advertises 130 actions and Actions offers a broad free library. More actions alone is not a persuasive advantage. [Toolbox Pro](https://toolboxpro.app/), [Actions](https://sindresorhus.com/actions).

**Commercial plan:** include the builder in Pro if user testing shows it improves activation. If pursued as the main product direction instead, test $9.99 one-time. These are alternative positioning tests, not five simultaneous paywalls. Keep basic examples and troubleshooting free.

**No-infra implementation:** bundled recipes, local rule evaluation, and Files/share-sheet transfer. Ship content updates with the app; no marketplace or hosted template catalog.

**Validation gate:** at least seven of ten target beginners should build one useful real workflow unaided; compare against an ordinary written setup guide. If the guide performs equally well, do not build a paid visual editor. **Effort:** medium to high. **Product confidence:** low to medium.

### 4. Field Reports: repeatable installation and troubleshooting evidence

**Buyer and job:** an automation consultant or BLE hobbyist checking several installations. “Give me a repeatable test and a report I can hand over.” This buyer segment is a hypothesis, not validated market demand.

**New paid features:** named projects and test locations; repeatable test protocols; before/after comparisons; annotated results; and local PDF/CSV report generation with settings, observed outcomes, dates, and limitations. Include identifier redaction and retention controls.

**MVP:** a project with two labeled positions, a repeated test checklist, and a clear local PDF report. Avoid a generic BLE inspector expansion.

**Why pay:** structured handoff, not raw data. Both LightBlue and nRF Connect provide sophisticated free BLE tooling; nRF Connect includes charts and CSV/text logging. These two independent vendors strongly disconfirm a paid “scanner plus CSV” strategy. [LightBlue](https://apps.apple.com/us/app/lightblue/id557428110), [nRF Connect](https://apps.apple.com/us/app/nrf-connect-for-mobile/id1054362403).

**Commercial plan:** test a $29.99 one-time professional package only after three prospective professionals demonstrate a real recurring reporting job. Initially it could be an alternative focus for the product rather than another upgrade stacked on Pro.

**No-infra implementation:** on-device report rendering and local files, shared by the user. No team accounts, cloud archive, report hosting, or email delivery service.

**Validation gate:** three professionals should each use a report on a real project, identify time saved, and prefer it to exporting free-tool logs. Stop if a screenshot is sufficient. **Effort:** medium. **Product confidence:** low pending buyer discovery.

### 5. Live Sessions: monitor a deliberately started activity

**Buyer and job:** someone testing beacon placement or watching a compatible setup during a bounded activity. “Keep this check visible while I use another app.”

**New paid features:** explicit Start/Stop; a visible Live Activity with observation age and session status; bounded duration presets; a local session timeline; and a final summary. Notification behavior can be considered after runtime proof; do not promise arbitrary unattended Shortcut execution.

**MVP:** a 30-minute user-started observation session with a Lock Screen display, local timeline, stale-data state, and immediate stop control. Use a foreground-only fallback when Live Activities are disabled.

**Technical opening:** Apple explicitly documents iOS 26 foreground-like Bluetooth scanning privileges when a CBManager exists and the app starts a Live Activity before backgrounding. ActivityKit supports updates from the app, so remote push is unnecessary. This is official, single-authority feasibility evidence, not a tested MagicCuts capability. [Core Bluetooth](https://developer.apple.com/documentation/corebluetooth), [ActivityKit](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).

**Commercial plan:** prototype first, then test a $19.99 one-time Pro price for new buyers if this materially strengthens the bundle. Honor earlier Pro purchases. Never market it as an always-on tracker or guaranteed departure alarm.

**No-infra implementation:** local Core Bluetooth observations and local ActivityKit updates. No APNs provider, server, or remote session coordination.

**Validation gate:** physical iPhone/iPad tests with locked screen, other apps active, low power mode, sparse advertisements, disabled/dismissed Live Activities, app termination, Bluetooth interruption, and sustained battery measurement. ActivityKit documents an eight-hour maximum active duration; shorter product sessions remain preferable. Loss of observation must visibly stale/end the state. If background behavior cannot be made honest and predictable, do not monetize it. **Effort:** high relative to the others. **Product confidence:** low to medium until the prototype passes.

## Purchase architecture and economics

Use a non-consumable StoreKit 2 purchase. Apple supplies signed transactions and entitlement APIs; an owner-operated entitlement server is unnecessary for this design. Implement verified entitlement handling, transaction updates, restore, refunds/revocations, reinstall, a second device, pending/cancelled purchases, and offline behavior. Never turn purchase failure into a false proximity result. [StoreKit 2](https://developer.apple.com/storekit/).

Apple’s rules support in-app feature purchases and require ongoing value for auto-renewing subscriptions. A subscription is not prohibited for local software, but these proposed finite utility packages do not yet justify an ongoing promise. One-time payment is my recommendation, not an Apple requirement. [App Review Guidelines, 3.1.1–3.1.2](https://developer.apple.com/app-store/review/guidelines/).

At $14.99, 100 purchases produce $1,499 gross; at a hypothetical 15% commission, $1,274.15 remains before taxes, refunds, and costs. A 30% sensitivity assumption yields $1,049.30. Neither is profit or a sales forecast. The 15% program requires enrollment and eligibility across associated developer accounts; eligibility has not been checked here. [Apple Small Business Program](https://developer.apple.com/app-store/small-business-program/).

No infrastructure cost does not mean no ongoing operating cost. Budget developer/support time, test hardware, Apple membership, and maintenance across OS releases. At the illustrative 15% rate, recovering $5,000 of development cost requires at least 393 purchases before other costs. Avoid acquiring an SDK or free-tier dependency that later introduces a per-user bill. Purchases/restores still communicate with Apple; ordinary local scans do not require a new backend.

## Evidence table

All sources accessed September 9, 2026 local time. Undated live pages are snapshots, not publication dates. Vendor descriptions establish advertised features and prices, not sales, quality, or demand.

| Source / publisher | Date | Claims supported and limits |
|---|---|---|
| [Actions / Sindre Sorhus](https://sindresorhus.com/actions) | Undated live page | Free broad action library; strong substitute pressure; not proof of identical MagicCuts semantics. |
| [Pushcut pricing / Snailed It](https://www.pushcut.io/) | Undated live page | $1.99 monthly, $17.99 annual, $39.99 lifetime Pro benchmark; broader service than MagicCuts. |
| [Pushcut Automation Server / Snailed It](https://www.pushcut.io/support/automation-server) | Undated live page | Dedicated visible foreground iOS device requirement; qualifies its background automation marketing. |
| [LightBlue / Punch Through, App Store](https://apps.apple.com/us/app/lightblue/id557428110) | Live US listing | Free scanning, inspection and logging; publisher claims, not independent product testing. |
| [nRF Connect / Nordic, App Store](https://apps.apple.com/us/app/nrf-connect-for-mobile/id1054362403) | Live US listing | Free BLE scanner with RSSI charts and CSV/text logs; independent competitor to LightBlue. |
| [Toolbox Pro / official site](https://toolboxpro.app/) | Undated live page | Broad Shortcuts utility competitor; no paid price relied on. |
| [StoreKit 2 / Apple](https://developer.apple.com/storekit/) | Live documentation | Signed transactions and app-side entitlement information; platform authority. |
| [App Review Guidelines / Apple](https://developer.apple.com/app-store/review/guidelines/) | Live rules | Purchase and subscription rules; jurisdiction exceptions mean this is not a universal external-payments analysis. |
| [Small Business Program / Apple](https://developer.apple.com/app-store/small-business-program/) | Live program | 15% qualifying commission and associated-account eligibility. |
| [Core Bluetooth / Apple](https://developer.apple.com/documentation/corebluetooth) | Current docs, iOS 26 behavior | Live Activity scanning exception; runtime validation still needed. |
| [ActivityKit / Apple](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities) | Current documentation | Local updates, lifecycle, eight-hour active maximum. |
| [Leith and Farrell / arXiv](https://arxiv.org/abs/2006.06822) | May 19, 2020 | Primary reported handset RSSI experiments; abstract read; preprint and older hardware, no performance extrapolation. |

## Contradictions, uncertainties, and what changes the recommendation

Paid automation products establish that this purchase category exists, but Pushcut's richer service and advertised prices do not establish MagicCuts willingness to pay. Free products from Sindre Sorhus, Punch Through, and Nordic independently establish meaningful substitute pressure. The recommended positioning is an inference from that contrast.

Older Apple guidance describes coalesced background discoveries and longer scan intervals. Current iOS 26 documentation adds a specific Live Activity path. Both can be true; do not apply the older limitations universally or treat the new exception as indefinite execution. [Archived Bluetooth background guide](https://developer.apple.com/library/archive/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/CoreBluetoothBackgroundProcessingForIOSApps/PerformingTasksWhileYourAppIsInTheBackground.html). This supplemental historical source is additional to the twelve-source core table.

RSSI improvements cannot establish identity, exact distance, or definitive absence. Advertising availability is a prerequisite. No plans assume universal AirTag, AirPods, or Find My compatibility. Physical acceptance of the existing Shortcut action comes before charging for advanced variants.

The biggest open question is who already uses MagicCuts successfully and repeatedly. Run a small pilot before building all five. Start with calibration and group-check prototypes, compare against the existing free experience, and use voluntary local diagnostic exports plus interviews for product feedback. Aggregate App Store sales can measure monetization without adding a hosted analytics service; connecting individual feature exposure to purchase conversion would need a separate measurement design.

If users do not experience calibration friction, promote Device Groups to first priority. If most target hardware does not advertise reliably, narrow the supported accessory use cases before monetization. If professionals repeatedly need paid handoff reports, reconsider Field Reports as the primary product. If buyers reject one-time Pro at the proposed price, test the value proposition and lower price before inventing a subscription.

Recommended sequence: finish physical acceptance; validate Calibration Pro and Device Groups with real workflows; launch one clear Pro purchase; add the builder only if it improves unaided setup; prototype Live Sessions separately; pursue Field Reports only with demonstrated professional demand.
