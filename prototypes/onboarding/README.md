# MagicCuts onboarding cards revision

[Design notes](DESIGN-NOTES.md) · [Surface direction](../../.impeccable/surfaces/onboarding-motion.md) · [Onboarding research](../../docs/ONBOARDING_RESEARCH.md)

This standalone native SwiftUI review prototype introduces a five-card instrument mosaic. Level and Signal share the first row, Vibration spans the second, and Heading and Elevation share the third. The cards stay in place while one active card and its explanation above it change together.

It uses synthetic readings and simulated purchase and restore outcomes. It has no sensors, StoreKit integration, recording, library changes, or production-onboarding changes. The final Pro price remains undecided; a production offer must present the localized StoreKit price.

## Run the preview

Xcode with an iOS 26 simulator SDK and an Apple Silicon Mac are required. The build treats warnings as errors:

```sh
bash prototypes/onboarding/build.sh
```

Install `/tmp/MagicCutsOnboardingPreview/OnboardingPreview.app` on a simulator, then launch `com.magiccuts.onboarding-preview`. The preview uses its own bundle identifier.

On the first page, the tour starts with Level and advances through Signal, Vibration, Heading, and Elevation every 3.7 seconds. It runs once and stays on the final showcase. Tap a card to select it and take over, or use Pause tour / Play tour. Explore Pro remains available throughout. The offer contracts the same mosaic, and simulated success or restore proceeds to the Level example.

## Capture and QA arguments

- `--page=0` opens the ordinary first-page tour; `--page=1` and `--page=2` open paused offer and first-reading stages.
- `--card=0` through `--card=4` opens a paused Level, Signal, Vibration, Heading, or Elevation selection on the mosaic.
- `--autoplay` records the deterministic presentation: five 3.7-second cards, a 5-second offer, then the first Level reading. It never opens a purchase sheet.
- `--landscape` requests the native scene's landscape-right orientation for QA. In compact height, narration and the unchanged mosaic sit side by side, cards contract, and the footer becomes horizontal.

Reduce Motion shows each selected reading immediately and disables automatic spotlighting. Accessibility Dynamic Type and VoiceOver disable only automatic sequencing; use Next instrument to advance manually while the normal selected-reading interpolation remains. Each card exposes its demo reading and context to VoiceOver, and decorative instrument drawings are hidden from the accessibility tree.

## Review artifacts

- [Native cards tour](../../docs/screenshots/onboarding-cards/magiccuts-onboarding-cards.mp4): actual native iPhone Simulator frames of the ordinary five-card tour followed by a manual Explore Pro tap; resampled to 60 fps with an explicit FPS filter and time base. It shows the five-card showcase and offer.
- [Reduce Motion sample](../../docs/screenshots/onboarding-cards/magiccuts-onboarding-cards-reduced-motion.mp4): native frames showing immediate readings and manual progression.
- [Capture and verification receipt](../../docs/screenshots/onboarding-cards/README.md): complete decode passed without warnings or errors; it records build, source/binary hashes, interaction checks, limits, and the compact-height phone landscape verification: the compact five-card mosaic is beside narration with a horizontal footer.
- [Evidence manifest](../../docs/screenshots/onboarding-cards/evidence.json) and [finish review](../../docs/screenshots/onboarding-cards/finish-review.md): the three scored fixes resolved with no regressions and a ship disposition. [Interaction receipt](../../docs/screenshots/onboarding-cards/interaction-check.txt) includes the verified first Level reading.

The files under [`docs/screenshots/onboarding/`](../../docs/screenshots/onboarding/) are historical v1 motion-prototype evidence. They document the former Reading → Reference → Pro → First measurement dial flow and must not be used as proof of this cards revision.
