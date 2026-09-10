# Onboarding cards: local design notes

## Scope and ground truth

This is a local extension of MagicCuts' approved **grounded field chronograph** system. Ground truth is `OnboardingPreview.swift`, `InstrumentTiles.swift`, and `build.sh`, read with the onboarding surface direction and `PRODUCT.md`. The artifact is a native SwiftUI review prototype with synthetic readings and simulated purchase/restore outcomes; it does not prove hardware behavior, entitlement behavior, a final price, or production onboarding.

## Five-line system summary

1. **Palette:** adaptive Action/Signal blue directs the active instrument and primary action; quiet canvas, card, and secondary-ink values support measurement in light and dark appearance.
2. **Type ramp:** rounded bold title narration leads; native body explains; rounded semibold, monospaced-digit readings make each value scannable; captions identify units and context.
3. **Layout rule:** the stable mosaic is Level + Signal, full-width Vibration, Heading + Elevation; its geometry does not rearrange while focus moves.
4. **Focus rule:** one card receives active fill, thin blue edge, selected accessibility trait, synchronized narration, and a reading animation; inactive cards retain their last reading without decorative loops.
5. **Motion and access rule:** regular motion waits 350 ms, then samples the selected value every 16 ms over 1.6 s with cubic ease-out; Reduce Motion is immediate, while accessibility type sizes and VoiceOver make sequencing manual.

## Local composition and behavior

The narration sits in a fixed-height reading region above the mosaic and crossfades with a small vertical offset unless Reduce Motion is enabled. Regular cards use 16pt continuous corners, 12pt internal padding and 12pt mosaic gaps; the offer uses the same order with 8pt gaps and compact cards. Vibration earns the wide card because its trace needs a horizontal reading space. Level, Signal, and Heading keep compact radial geometry; Elevation keeps a vertical tape. In compact-height phone landscape, the same mosaic contracts and moves beside the 210pt narration column while the footer becomes horizontal; it does not become a new layout system.

The tour begins at Level, moves through all five cards once at 3.7-second intervals, and ends on Elevation. Tap selection halts it and cancels the in-flight sample loop, leaving the previous card's current value frozen. The active card's numeric reading and graphic share the same 16 ms `ContinuousClock` progress samples after a 350 ms delay: cubic ease-out `1 - (1 - t)^3` reaches the final reading over 1.6 seconds. Pause, replay, the persistent Explore Pro action, Restore, View Pro, cancellation, and the first Level reading all remain explicit. `--autoplay` is capture-only: it plays the 18.5-second tour, holds the offer for five seconds, then shows the Level reading. `--page=0` starts the normal tour, `--page=1...2` are paused stages, `--card=0...4` pauses an instrument selection, and `--landscape` requests orientation QA.

Accessibility-sized type replaces the visual grid with a vertical readable sequence, makes the tour manual through Next instrument, and keeps controls at least 44pt high. VoiceOver also stops automatic spotlighting and uses manual sequencing, while preserving the normal selected-reading interpolation. Reduce Motion presents the current reading immediately and removes the narration offset. Instrument graphics are decorative; the enclosing card supplies the spoken demo value and context.

## Incumbent system retained

The prototype remains SwiftUI-first: `NavigationStack`, `ScrollView`, system toolbar buttons, `safeAreaInset`, `.bar` material, sheets, alerts, and `.borderedProminent` controls. Canvas draws only real measurement geometry: a bubble level, signal dial, vibration trace, compass, and elevation tape. There are no raster plates, generated imagery, web components, sensor APIs, StoreKit calls, recordings, or library mutations.

## Drift not canonized

The widget-like cards, their 16pt local surface, and the onboarding-only mosaic are an explicitly selected review-surface extension. They are not a product-wide card system, do not amend root `DESIGN.md` or the design sidecar, and do not redefine the production Instruments workspace. The delivered [native cards tour](../../docs/screenshots/onboarding-cards/magiccuts-onboarding-cards.mp4), [Reduce Motion sample](../../docs/screenshots/onboarding-cards/magiccuts-onboarding-cards-reduced-motion.mp4), [receipt](../../docs/screenshots/onboarding-cards/README.md), [evidence manifest](../../docs/screenshots/onboarding-cards/evidence.json), and [ship review](../../docs/screenshots/onboarding-cards/finish-review.md) verify this bounded prototype. Historical v1 recordings under `docs/screenshots/onboarding/` remain prior-flow evidence and do not validate this revision.
