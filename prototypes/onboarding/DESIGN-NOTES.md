# Onboarding motion: design notes

## Scope and evidence

This is an ordinary extension of MagicCuts Pro's approved **grounded field chronograph** system, recorded from `OnboardingPreview.swift`. It follows the surface brief: Reading → Reference → Pro → First measurement. The implementation was compiled with `bash prototypes/onboarding/build.sh /tmp/MagicCutsOnboardingPreview-documenter` on September 10, 2026. Evidence reviewed: the root `DESIGN.md`, `PRODUCT.md`, the onboarding surface brief, the prototype source, and `docs/ONBOARDING_RESEARCH.md`.

## Incumbent system carried into the prototype

- **Native instrument grammar.** `NavigationStack`, `ScrollView`, `safeAreaInset`, native toolbar buttons, `.borderedProminent` actions, `.bar` material, system sheets and alerts retain the existing SwiftUI-first interface. The dial is the only custom drawing and uses SwiftUI `Canvas` for data geometry.
- **Meaningful blue and quiet measurement support.** The adaptive palette preserves light Action/Signal blue (`#0052C7`), light canvas (`#F2F5F7`), and secondary label (`#59636E`); dark appearance uses the incumbent canvas (`#0F141A`) and high-contrast blue (`#61B8FF`). Blue marks the active signal, current difference, primary action, and first-instrument line; secondary ink carries explanatory labels.
- **Measurement typography.** The 66pt scaled rounded, semibold, monospaced reading remains the dominant visual value. Rounded semibold headline/title treatments identify measurement-adjacent labels; `.body`, `.callout`, captions, and footnotes remain native SF for explanations and recovery links.
- **Field-dial geometry.** The signal face reuses precise Canvas ticks, a blue needle, readable endpoint labels, and a fixed diamond reference. At regular sizes it is 244pt, compressing to 130pt for the offer; the value remains visible over the dial. The Level follow-on repeats this discipline with a plain circle, line, and numerical angle.

## Local layout and motion choices

- The centered reading column has 26pt side insets, 22pt top inset, 28pt bottom clearance, and a 540pt maximum width. A persistent bottom action has 24pt side padding and 14/8pt vertical padding, so instruction advances without relocating the primary control.
- The first two pages use a direct signal slider from −90 through −45 dBm. The first reading sweeps from −84 to −62 over 1.6 seconds after 350 ms; reference instruction settles from −72 to −62 over 1.2 seconds after 450 ms. Routine page changes use 350 ms ease-in-out.
- Reduce Motion presents the final reading immediately and makes routine changes 120 ms. Numerical values, the fixed reference label, and the textual difference remain available without spatial motion. At accessibility sizes, the one-time terms precede the benefits; the demo/no-payment annotation follows the scroll content; restore, Privacy, and Terms follow the device/permission limit in that content. Decorative dial geometry is hidden, the accessible reading remains, comparison content stacks, and the footer anchors only the CTA. Those controls remain at least 44pt high.
- The offer uses the same compacted dial and one-time-purchase language. It labels data as demo, states device/permission limits, supports restore, and routes only to a local preview sheet/alert. There are no sensor, StoreKit, recording, or library mutations in this artifact. `--autoplay` is a capture-only presentation path and does not affect normal interaction.

## Provenance and boundary

All visual UI is native SwiftUI: text, SF Symbols, system controls/materials, circles/rectangles, and Canvas paths. No raster or generated image is shipped or used as an instrument surface. The prototype demonstrates synthetic values only; it does not establish hardware availability, sensor accuracy, a StoreKit price, purchase success, or production onboarding behavior.

## Drift not canonized

No pre-existing incumbent-system drift was found in the reviewed extension. The onboarding shell's `MagicCuts` navigation title and local 540pt column intentionally differ from the production `Instruments` workspace; they are scoped review-artifact choices, not changes to root `DESIGN.md` or `.impeccable/design.json`.
