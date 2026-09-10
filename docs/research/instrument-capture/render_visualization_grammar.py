# /// script
# requires-python = ">=3.11"
# dependencies = ["matplotlib==3.10.8", "numpy==2.5.3"]
# ///
"""Render research figures with synthetic data; these are not app screenshots.

Run: uv run docs/research/instrument-capture/render_visualization_grammar.py
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import numpy as np

OUT = Path(__file__).resolve().parent
BLUE, TEAL, INK, GRAY = "#0052C7", "#1F6E61", "#15202B", "#59636E"
plt.rcParams.update({
    "font.family": "DejaVu Sans", "font.size": 10, "text.color": INK,
    "axes.labelcolor": GRAY, "xtick.color": GRAY, "ytick.color": GRAY,
    "axes.spines.top": False, "axes.spines.right": False,
    "axes.edgecolor": "#C4CCD2", "figure.facecolor": "#F2F5F7",
    "savefig.facecolor": "#F2F5F7",
})
fig, axes = plt.subplots(3, 2, figsize=(15, 15.4))
fig.subplots_adjust(left=.09, right=.96, bottom=.12, top=.86, hspace=.73, wspace=.35)
fig.suptitle("Choose the visual form around the evidence", x=.09, y=.965,
             ha="left", fontsize=24, weight="bold")
fig.text(.09, .929, "SYNTHETIC EXAMPLES  /  MagicCuts instrument research  /  September 2026",
         fontsize=11, color=GRAY)

def title(ax, heading, subtitle):
    ax.set_title(heading, loc="left", fontsize=15, weight="bold", pad=29)
    ax.text(0, 1.05, subtitle, transform=ax.transAxes, fontsize=10, color=GRAY)

ax = axes[0, 0]
title(ax, "01  NFC capacity", "A known amount inside a reported capacity")
ax.barh([0], [144], color="#E5EBF0", height=.4)
ax.barh([0], [96], color=BLUE, height=.4)
ax.text(48, 0, "96 bytes used", ha="center", va="center", color="white", weight="bold")
ax.text(120, 0, "48 free", ha="center", va="center", fontsize=9)
ax.set(xlim=(0, 144), ylim=(-.8, .8), yticks=[], xticks=[0, 48, 96, 144],
       xlabel="Encoded NDEF message bytes / 144-byte example maximum")
ax.spines["left"].set_visible(False)
ax.text(0, -.32, "Reported read-only state belongs beside the bar.\nUnknown capacity suppresses the bar.",
        transform=ax.transAxes, color=GRAY, fontsize=10)

ax = axes[0, 1]
title(ax, "02  Request waterfall", "Intervals share one clock; TLS is inside connection time")
phases = [("DNS", 0, 18), ("Connection", 18, 70), ("TLS", 35, 70),
          ("Send request", 70, 73), ("Wait for response", 73, 141), ("Receive body", 141, 168)]
for row, (_, start, end) in enumerate(phases):
    ax.barh(row, end-start, left=start, height=.52, color=TEAL if row == 2 else BLUE)
    ax.text(end+3, row, f"{end-start} ms", va="center", fontsize=9)
ax.set(yticks=range(6), yticklabels=[p[0] for p in phases], xlim=(0, 205), xlabel="Milliseconds since request began")
ax.invert_yaxis()
ax.grid(axis="x", color="#E5EBF0", zorder=0)
ax.set_axisbelow(True)
ax.text(.99, -.32, "Elapsed: 168 ms; summing the phase rows would double-count TLS.",
        transform=ax.transAxes, color=GRAY, ha="right", fontsize=9)

ax = axes[1, 0]
title(ax, "03  Cellular observation and forecast", "A future interval never masquerades as a measured trace")
t = np.arange(0, 41, 2)
latency = np.array([51, 55, 49, 54, 57, 53, 52, 61, 55, 58, 60, 66, 63, 68, 76, 69, 73, 79, 82, 77, 84.])
latency[8] = np.nan
ax.plot(t, latency, color=BLUE, marker="o", markersize=3, linewidth=1.7)
ax.axvline(40, color=GRAY, linestyle="--", linewidth=1)
ax.axvspan(46, 56, color=TEAL, alpha=.10)
ax.axvline(46, color=TEAL, linestyle="--", linewidth=1)
ax.axvline(56, color=TEAL, linestyle="--", linewidth=1)
ax.text(51, 112, "Forecast\nwindow", ha="center", color=TEAL, fontsize=9)
ax.annotate("No sample", xy=(16, 56), xytext=(10, 106), fontsize=9, color=GRAY,
            arrowprops={"arrowstyle": "-", "color": GRAY})
ax.text(40, 26, "Now", ha="center", fontsize=9, color=GRAY)
ax.set(xlim=(0, 60), ylim=(20, 133), xlabel="Seconds relative to test start", ylabel="Observed response time (ms)")
ax.text(0, -.32, "Reported LTE/5G and delayed reception histograms get separate tracks.",
        transform=ax.transAxes, fontsize=9, color=GRAY)

ax = axes[1, 1]
title(ax, "04  Depth and uncertainty", "Ordered distance colors; invalid samples remain visibly absent")
y, x = np.mgrid[0:36, 0:60]
depth = 1 + x/30 + .2*np.sin(y/8)
depth[(x > 24) & (x < 34) & (y > 8) & (y < 26)] = np.nan
cmap = plt.get_cmap("cividis").copy()
cmap.set_bad("#F2F5F7")
im = ax.imshow(depth, cmap=cmap, vmin=1, vmax=3.2, origin="lower", aspect="auto")
ax.add_patch(Rectangle((24.5, 8.5), 9, 17, fill=False, hatch="///", edgecolor="#7D8790", linewidth=0))
ax.text(29, 17, "Invalid", rotation=90, ha="center", va="center", fontsize=9)
ax.set(xticks=[], yticks=[], xlabel="A separate confidence mode shows categorical levels")
cb = fig.colorbar(im, ax=ax, fraction=.045, pad=.035, extend="min")
cb.set_label("Depth (m)")
ax.text(0, -.32, "Pixel confidence is not a calibrated percentage or a mesh error bound.",
        transform=ax.transAxes, fontsize=9, color=GRAY)

ax = axes[2, 0]
title(ax, "05  Nearby-device direction", "Direction and distance are distinct available measurements")
angle = np.deg2rad(28)
distance = 2.2
right, ahead = distance*np.sin(angle), distance*np.cos(angle)
ax.annotate("", xy=(right, ahead), xytext=(0, 0),
            arrowprops={"arrowstyle": "-|>", "color": BLUE, "linewidth": 4, "mutation_scale": 23})
ax.scatter([0], [0], c=INK, s=40, zorder=4)
ax.scatter([right], [ahead], facecolors="white", edgecolors=BLUE, s=180, linewidths=2, zorder=5)
ax.text(right+.2, ahead, "2.2 m\n28° right", color=BLUE, fontsize=13, weight="bold", va="center")
ax.set(xlim=(-.7, 2.6), ylim=(-.2, 2.5), aspect="equal", xlabel="Right of phone (m)", ylabel="Ahead of phone (m)")
ax.grid(color="#E5EBF0")
ax.text(-.04, -.32, "Without valid direction: keep range, remove the arrow.",
        transform=ax.transAxes, fontsize=9, color=GRAY)

ax = axes[2, 1]
title(ax, "06  Room coverage between passes", "Not observed this time does not mean physically removed")
ax.add_patch(Rectangle((0, 0), 4.2, 3, facecolor="#E5EBF0", edgecolor=INK, linewidth=2))
ax.add_patch(Rectangle((0, 0), 2.7, 3, facecolor=BLUE, alpha=.16, edgecolor="none"))
ax.add_patch(Rectangle((2.7, 0), 1.5, 3, fill=False, hatch="///", edgecolor="#8E99A2", linewidth=0))
ax.text(1.35, 1.5, "Observed in\nthis pass", ha="center", va="center", color=BLUE, fontsize=12, weight="bold")
ax.text(3.45, 1.5, "Prior data\nNot observed\nthis time", ha="center", va="center", color=INK,
        fontsize=10, bbox={"facecolor": "#F2F5F7", "edgecolor": "none", "pad": 5})
ax.set(xlim=(-.2, 4.4), ylim=(-.1, 3.2), aspect="equal", xlabel="Room coordinates (m)", ylabel="Room coordinates (m)")
ax.text(0, -.32, "Coverage is illustrative; no real room or scan is represented.",
        transform=ax.transAxes, fontsize=9, color=GRAY)

fig.savefig(OUT / "visualization-grammar.png", dpi=170)
fig.savefig(OUT / "visualization-grammar.pdf")
plt.close(fig)
print(f"Rendered visualization-grammar.png and visualization-grammar.pdf; Matplotlib {matplotlib.__version__}, NumPy {np.__version__}")
