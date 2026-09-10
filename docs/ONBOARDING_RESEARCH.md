# iOS onboarding and hard paywalls

Research date: September 10, 2026. Decision: how MagicCuts can explain its instruments, earn a one-time purchase, and start useful work with minimal setup. This research informs one native motion prototype; it does not approve a production redesign or establish a final price.

## Executive findings

- Demonstrate one useful relationship before the offer: a signal changes relative to a reference. Let the person manipulate it.
- Keep the introduction skippable into the Pro offer. The purchase boundary remains hard; skipping instruction does not unlock instruments.
- Treat the offer as part of the instrument experience, with clear total price, one-time terms, restore and recovery.
- After purchase, move straight to an instrument. Ask for permissions when that instrument needs them; defer iCloud, calibration, naming and Shortcuts setup until relevant.
- Subscription benchmarks support testing an early offer, but cannot forecast a one-time utility’s conversion or prove that a longer onboarding converts better.
- Use one continuous piece of data geometry. Animation should explain what changed; it must not imply that demonstration data came from the phone.

## Recommendation

Build **Reading → Reference → Pro → First measurement**. The first two moments are optional instruction; Pro is the commercial boundary. Use the existing rounded readings and blue instrument language. A persistent primary action keeps people in control. Returning purchasers can restore immediately.

The proposed first two moments take approximately 10–20 seconds at a comfortable pace. This is a design hypothesis, not an evidence-based optimum. There is no compulsory timer, quiz, account creation, personalization calculation, notification request or video download. A person who already understands the app can go directly to the offer.

Before purchase, synthetic data is labeled **Demo data**. After a confirmed transaction, show a first-instrument choice with Level suggested and Bluetooth available. Production must evaluate hardware support before selecting a default. A canceled or pending purchase leaves the person at the offer without losing their place.

## iOS onboarding: what the evidence supports

Apple recommends brief, optional introductions, safe interaction and contextual tips. It also advises postponing nonessential configuration and asking for private-resource access when needed. These principles favor teaching one relationship now and explaining calibration or Shortcuts during those tasks. [Apple: Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding)

Apple’s *Discoverable design* demonstrates how a changing camera guide can teach the right action at the moment of use. Its emphasis is on recognizable controls and contextual visual cues. **Inference:** a moving signal marker and stationary reference teach MagicCuts more directly than three illustrations describing its features. [WWDC21: Discoverable design](https://developer.apple.com/videos/play/wwdc2021/10126/)

Motion should support the task, remain brief and allow interruption. Important meaning must survive without animation. For our revision, the reference label and numerical difference remain visible even when spatial motion is disabled. Support large text and avoid using color as the only distinction between current and reference values. [Apple: Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Apple: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)

**Confidence: high** for these platform principles; **medium** for their specific translation into this proposed flow. The Apple sources form one guidance family, not independent experimental confirmation.

## Hard paywalls: evidence and limits

RevenueCat’s 2026 report analyzes over 115,000 apps using its platform, primarily 2025 performance. It reports median day-35 download-to-paid conversion of 10.7% for hard-paywall apps and 2.1% for freemium apps. These are different cohorts, not a randomized test. Apps must meet activity thresholds and have subscription revenue to enter the dataset. **This is not a predicted MagicCuts conversion rate.** [RevenueCat: State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps)

Adapty’s separate 2026 dataset covers 16,000 apps and $3B in subscription revenue. It reports 89.4% of trial starts on install day. That reinforces the importance of the first session, but trial starts are not purchases, and install day is not necessarily one uninterrupted session. Vendor incentives and customer selection affect both datasets. [Adapty: 2026 findings](https://adapty.io/blog/mobile-app-monetization-2026/)

The evidence does **not** justify a long questionnaire, manufactured loading screen, price countdown, fabricated social proof, or switching MagicCuts to subscriptions. Those would add friction or claims without demonstrating this product’s value. No reviewed source establishes an optimal onboarding length for a one-time sensor utility.

There is a real tension: Apple prefers people to experience value before purchase; hard-paywall cohorts monetize early. An honest, manipulable demonstration is our proposed compromise. It is not equivalent to trying the actual hardware, and the offer must explain that instrument availability depends on hardware and permissions. [Apple: In-app purchase](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase)

Non-consumable purchases do not expire. Present a clear total billing amount and use Apple’s purchase confirmation, preserving restore support for restorable purchases. The prototype deliberately omits a numerical price because pricing remains undecided; the shipping offer must use the available StoreKit product’s localized price. [Apple: In-app purchase](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase), [App Review Guidelines §3.1.1](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)

**Confidence: medium** that an early offer is the right test within the already chosen hard-paywall model. **Low** for any claimed conversion lift until MagicCuts is evaluated directly.

## Animated examples worth studying

These are recordings of app interfaces hosted by 60fps, not our recordings of the latest installed versions. Their recording dates and account states are not established. Clips were opened, played and visually inspected; selected frame sequences were inspected locally. Their appeal is a design judgment, not conversion evidence. Links open the original moving examples; third-party media is not bundled into the app or redistributed in this repository.

| Example | What to watch | What we take | What we leave behind |
|---|---|---|---|
| [Halide: page-flip onboarding](https://60fps.design/shots/halide-page-flip-onboarding) | In the approximately 12-second clip, the cover resolves, pages turn, and gesture diagrams demonstrate camera operations. Around 3–10 seconds, the tutorial advances through the illustrated pages. | An authored material language and a concrete action per moment. | A page curl is specific to Halide’s manual metaphor; it would be costume in MagicCuts. The clip itself does not establish the paywall location. |
| [Bevel: onboarding Continue transition](https://60fps.design/shots/bevel-onboarding-continue-page-transition) | The short clip moves between food, glucose, score and connection previews while Continue stays anchored. | Stable action placement and continuity between a diagram and its explanation. | The full health-setup flow and spring overshoot are unnecessary for a small instrument lesson. This is a feature tutorial, not evidence of a hard paywall. |
| [Flighty: pricing](https://60fps.design/shots/flighty-pricing) | Animated feature previews above a separate, swipeable purchase-plan area. Watch how the product remains visible while evaluating the offer. | Show the instrument’s behavior on the purchase surface and preserve visual identity. | Multiple pricing carousels add choice and discoverability costs we do not need for one product. This is a purchase-screen reference, not a claim that Flighty is hard-paywalled. |
| [Gentler Streak: steps fill pulse](https://60fps.design/shots/gentler-streak-steps-fill-pulse-animation) | A restrained pulse in the step visualization while the reported count remains readable. | Restraint: the displayed measurement stays legible while the geometry carries a small amount of life. | A decorative breathing loop could be mistaken for changing measured data. Our real readings should move only with actual samples; the onboarding animation is explicitly synthetic. |

Halide is the closest commercial comparator: its current developer-authored App Store description offers an annual membership with a seven-day trial or a one-time purchase. The older motion clip and current listing represent different versions; neither should be used to infer an exact current purchase sequence. [Halide’s App Store listing](https://apps.apple.com/us/app/halide-mark-ii-pro-camera/id885697368)

Flighty’s design team describes preserving the most useful information and drawing on established airport-signage conventions. That is the relevant analogy for our dial: familiar measurement notation can do explanatory work. [Apple: Behind the Design — Flighty, June 5, 2023](https://developer.apple.com/news/?id=970ncww4)

## Motion specification for this revision

| Moment | Meaning and interaction | Motion | Reduced motion |
|---|---|---|---|
| Reading | Drag the demo signal; a less negative value is stronger. | Short initial movement, followed by direct slider response. | Show the final sample immediately; slider changes remain immediate. |
| Reference | Compare the current signal with a fixed −72 dBm reference. | A reference marker appears; the current marker and delta stay linked. | Immediate marker appearance with a brief crossfade. |
| Offer | All twelve instruments, saved comparisons, sessions and Shortcuts; one Pro purchase. | The existing dial compacts into the offer rather than starting a new decorative scene. | Static compact arrangement. |
| First measurement | Following simulated success, try the suggested Level instrument; no permission barrage. | Short transition into the next task. | Crossfade. |

Routine transitions use 350 ms; the initial reading sweep uses 1.6 seconds and the reference demonstration 1.2 seconds. Reduced Motion removes those sweeps and limits page crossfades to 120 ms. These are chosen interaction timings, not benchmark findings. No action waits for motion. No looping animation continues offscreen. The standalone preview cannot purchase, scan, record or change the user’s library.

## Evidence ledger

All links were accessed September 10, 2026. “Undated” means the page exposes no reliable publication date; it does not mean the interface is current.

| Source / publisher | Date | Supported claim / limitation |
|---|---|---|
| [Onboarding — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/onboarding) | Changelog June 10, 2024 | Optional, brief, interactive teaching; contextual permission requests. Normative guidance. |
| [Discoverable design — Apple WWDC](https://developer.apple.com/videos/play/wwdc2021/10126/) | 2021 | Teach unfamiliar actions with in-context animation and cues. Demonstrated guidance. |
| [Motion — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/motion) | Changelog September 9, 2025 | Purposeful, interruptible motion; avoid conveying meaning only through movement. |
| [Accessibility — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility) | Current page, accessed 2026 | Larger type and multiple ways to perceive information. |
| [In-app purchase — Apple HIG](https://developer.apple.com/design/human-interface-guidelines/in-app-purchase) | Current page, accessed 2026 | Non-consumables, integrated purchase UI, total billing price and system confirmation. |
| [App Review Guidelines — Apple](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase) | Current page, accessed 2026 | Restorable purchases need a restore mechanism; see §3.1.1. |
| [State of Subscription Apps — RevenueCat](https://www.revenuecat.com/state-of-subscription-apps) | 2026; mainly 2025 observations | Hard-paywall versus freemium cohort benchmark; not one-time utility evidence. |
| [2026 findings — Adapty / Victoria Kharlan](https://adapty.io/blog/mobile-app-monetization-2026/) | March 13, 2026 | Concentration of trial starts on install day; different metric and customer sample. |
| [Halide listing — Lux Optics / App Store](https://apps.apple.com/us/app/halide-mark-ii-pro-camera/id885697368) | Current listing, accessed 2026 | Developer-described trial and outright-purchase options. |
| [Behind the Design: Flighty — Apple](https://developer.apple.com/news/?id=970ncww4) | June 5, 2023 | Product-specific design philosophy and familiar information conventions. |
| [Halide](https://60fps.design/shots/halide-page-flip-onboarding), [Bevel](https://60fps.design/shots/bevel-onboarding-continue-page-transition), [Flighty](https://60fps.design/shots/flighty-pricing), [Gentler Streak](https://60fps.design/shots/gentler-streak-steps-fill-pulse-animation) — 60fps | Undated recordings | Observed motion references only; no causality, current-version or paywall-model proof. |

Apple HIG pages require JavaScript in the text reader; their official documentation JSON was read from `developer.apple.com/tutorials/data/design/human-interface-guidelines/`. Apple sources are primary guidance, benchmark vendors are primary publishers of their own datasets, and app recordings are secondary observational evidence.

## Contradictions, risks and what would change the recommendation

Subscription datasets overrepresent businesses built for recurring revenue. Cohort differences, acquisition channels, product value and price can explain outcomes. Neither benchmark is independent evidence for our exact design. Apple’s preference for experiencing real value before buying remains a meaningful counterweight.

A gauge demonstration can overpromise accuracy or device support. Keep the values synthetic, avoid translating RSSI into exact distance, and show capability limits before payment. The microphone instrument is dBFS, not calibrated sound-pressure level; it should not lead this introduction.

Validate with five people who have not seen MagicCuts: can they explain what the reference means, identify that the purchase is one-time, find restore, skip instruction, and reach a suitable instrument? Treat this as formative qualitative testing, not a conversion experiment. A high rate of confusion about negative RSSI would favor a Level demonstration instead.

For later quantitative evaluation, define denominators and windows before comparing: eligible first launches → offer views → confirmed purchases; confirmed purchasers → first valid supported reading; canceled purchases → successful recovery. Track refunds and support confusion alongside conversion. Use existing consent and privacy commitments; this research does not authorize adding telemetry or a backend.

Open decisions: final localized price; Bluetooth versus Level as the leading demonstration after comprehension testing; exact source choice on unsupported hardware; returning-purchaser and interrupted-purchase runtime verification. Production implementation follows review of the motion revision.
