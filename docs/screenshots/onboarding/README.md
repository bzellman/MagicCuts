# Onboarding motion evidence

[Watch the native revision](magiccuts-onboarding-motion.mp4) · [Reduced Motion](magiccuts-onboarding-reduced-motion.mp4) · [Research](../../ONBOARDING_RESEARCH.md) · [Run the prototype](../../../prototypes/onboarding/README.md)

Captured September 10, 2026 on dedicated iPhone 17 Pro and iPad Air 11-inch M3 simulators running iOS/iPadOS 26.5. Normal text and Accessibility XXXL were inspected. The largest-text captures include a scrolled state: only the primary action stays fixed, while purchase terms and recovery details remain in the scroll content.

The film consists entirely of native simulator frames. The export trims the home/launch prefix, preserves held frames at constant 60 fps, and holds the actual final frame for 2.5 seconds; no app elements, fake sensor readings, or purchase confirmation were composited into the footage. Values are synthetic and labeled in the native UI. The reduced-motion sample trims only the simulator home/launch prefix. All screenshot PNGs are review evidence, not raster assets used by the application.

Build: standalone SwiftUI compilation with warnings treated as errors passed. Native interaction checks passed for slider comparison, simulated cancellation/retry/success, first Level reading, replay, skip and restore. See [interaction receipt](interaction-check.txt), [build receipt](build.log), and [machine-readable provenance](evidence.json).

The fresh finish reviewer scored the compact-dial label and largest-text footer corrections resolved, with a final `ship` disposition at this local extension's scope. Specialized Impeccable roles were unavailable, so fresh substitute reviewer and documenter agents performed those handoffs. The documenter checked the final accessibility change and preserved the incumbent design system.

Limitations: no StoreKit transaction, actual sensor sample, iCloud operation, or full VoiceOver traversal was validated by this prototype. The normal interactive flow uses a labeled simulated purchase sheet; the film's capture-only autoplay advances directly to Level. Pricing is undecided and no amount is invented. Production onboarding remains a separate implementation decision.
