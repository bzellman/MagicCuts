# MagicCuts onboarding motion revision

[Watch the native motion film](../../docs/screenshots/onboarding/magiccuts-onboarding-motion.mp4) · [Read the research](../../docs/ONBOARDING_RESEARCH.md) · [Design notes](DESIGN-NOTES.md)

One continuous lesson: **Reading → Reference → Pro → First measurement**. Move a demonstrated Bluetooth signal, compare it with a fixed reference, understand the one-time Pro offer, then try a Level reading after simulated success. The dial carries the motion and the primary action stays anchored.

This is a standalone native SwiftUI prototype for review. It uses synthetic values and simulated purchase/restore outcomes. The final price remains open; a production offer must show the localized StoreKit price. The app target and production onboarding are unchanged.

## Run the interactive preview

Requires Xcode with an iOS 26 simulator SDK and an Apple Silicon Mac. Build with warnings treated as errors:

```sh
bash prototypes/onboarding/build.sh
```

Install the resulting `/tmp/MagicCutsOnboardingPreview/OnboardingPreview.app` on an available simulator using Xcode or `xcrun simctl install <simulator-udid> <app-path>`, then launch `com.magiccuts.onboarding-preview`. The preview uses its own bundle identifier.

Drag the signal slider. Use See the difference and Explore Pro, or View Pro to skip instruction. Unlock Pro opens a clearly labeled simulation sheet with success and cancellation actions. Restore purchases has a separate simulated success action. Try Level moves the example from eight degrees to zero. Replay starts over.

Optional launch arguments: `--page=0` through `--page=3`; `--autoplay` performs the film sequence only. Autoplay simulates the purchase-to-instrument transition without an Apple purchase sheet. Ordinary interaction never auto-advances.

## Review artifacts

- [Motion film](../../docs/screenshots/onboarding/magiccuts-onboarding-motion.mp4): actual iPhone simulator frames, normalized to 60 fps; no music or third-party artwork.
- [Reduced Motion sample](../../docs/screenshots/onboarding/magiccuts-onboarding-reduced-motion.mp4): immediate readings with short page crossfades.
- [Capture and verification receipt](../../docs/screenshots/onboarding/README.md): device, text-size, interaction and source evidence with limitations.
- [Research](../../docs/ONBOARDING_RESEARCH.md): Apple guidance, two benchmark datasets, four inspected animated references, contradictions and a bounded validation plan.

The existing DESIGN.md and design sidecar remain the visual authority. The documenter checked this as an ordinary extension, not a replacement identity. Fresh substitute finish-review and documenter agents were used because the specialized Impeccable roles were unavailable.
