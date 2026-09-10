# Instrument capture research assets

Created September 10, 2026, for [the research proposal](../../INSTRUMENT_CAPTURE_RESEARCH.md) and [saved-room specification](../../ROOM_CAPTURE_SPEC.md).

## Generated room compositions

- `01-room-canvas.png`: spatial overview with mesh, plan, measurements, and update action.
- `02-measurement-workbench.png`: focused plan and dimension selection.
- `03-room-journal.png`: saved room and revision review.

These were generated with ImageGen using the repository's `docs/screenshots/pro/pro-live-light.png` as the visual reference. They are design proposals with illustrative readings and invented room geometry. They do not establish implementation, sensor behavior, or measurement accuracy. The research report governs behavior wherever a composition simplifies or omits a state.

## Visualization grammar

`visualization-grammar.png` and `visualization-grammar.pdf` illustrate six data-presentation patterns using synthetic values. They are research figures, not app screenshots. No real device, NFC tag, network endpoint, or room was measured for them.

Regenerate from the repository root:

```sh
uv run docs/research/instrument-capture/render_visualization_grammar.py
```

The script declares its Python dependencies. Final outputs were rendered with Matplotlib 3.10.8 and NumPy 2.5.3 and visually inspected for labels, units, gaps, and clipping. NFC arithmetic, request interval containment, and direction geometry are defined directly in the script.

Reference videos remain linked at their original sources in the report. Their media were not downloaded or redistributed in this bundle.
