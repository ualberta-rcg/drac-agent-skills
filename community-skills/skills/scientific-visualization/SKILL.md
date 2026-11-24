---
name: scientific-visualization
description: "Creates and audits truthful, colorblind-accessible, publication-ready scientific figures with Matplotlib, Seaborn, or Plotly. Covers multi-panel layouts, honest baselines and uncertainty intervals, Okabe-Ito/Paul Tol palettes, vector/font embedding, and journal export checks."
license: MIT
compatibility: Requires Python 3.10+ with matplotlib, seaborn, or plotly. Works headlessly on HPC nodes via Matplotlib's Agg/PDF/SVG backends.
metadata:
  version: "1.4"
  last-reviewed: "2026-10-01"
  skill-author: K-Dense Inc.
  upstream: https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/scientific-visualization
---

# Scientific Visualization (Publication-Ready Figures)

Preserve scientific meaning before styling: never clip baselines on bar/area plots, explicitly state uncertainty definitions and independent replication units (`n`), encode categories redundantly (color + marker/linestyle/direct label), and inspect exported PDF/PNG/TIFF artifacts at target column width.

## Non-Negotiable Integrity & Accessibility Rules

1. **Honest scales & uncertainty**:
   - Bar and area plots **must include `0`**; point/line plots may zoom with clear axis labels.
   - Always label what error bars/bands represent (`mean ± SD`, `95% bootstrap CI`, `IQR`, posterior interval) and state **`n` of independent biological/experimental units** (for repeated measures in Seaborn, compute subject-level intervals rather than letting row-wise `errorbar=("ci", 95)` treat correlated rows as independent!).
   - Do not silently bridge missing timepoints (Seaborn drops `NaN` rows before connecting lines — plot contiguous segments or explicit gaps in Matplotlib).
2. **Colorblind-safe & redundant encoding**:
   - Use **Okabe–Ito** qualitative colors (`#0072B2`, `#D55E00`, `#009E73`, `#CC79A7`, `#E69F00`, `#56B4E9`, `#000000`) or perceptually uniform sequential/diverging colormaps (`viridis`, `cividis`, `RdBu_r` with `TwoSlopeNorm(vcenter=0)`), never rainbow/`jet` or unassisted red-vs-green.
   - Pair color with distinct `marker` shapes, `linestyle`, or direct text annotations so figures survive grayscale printing and CVD.
3. **Exact physical journal dimensions & editable vector text**:
   - Typical journal column widths: **85–89 mm** (single column, `3.5 in`) or **180–183 mm** (double column, `7.2 in`), with 6–8 pt sans-serif labels at **100% print scale**.
   - Set `pdf.fonttype = 42` and `ps.fonttype = 42` (TrueType embedding, editable in Illustrator/Inkscape instead of Type 3 bitmaps) and `svg.fonttype = "none"`.
   - Use `layout="constrained"` (supports `subplot_mosaic`, `subfigures`, and colorbars cleanly — never call `tight_layout()` after `layout="constrained"`, and avoid `bbox_inches="tight"` when exact mm page dimensions are required).

## Clean Multi-Panel Publication Template (Matplotlib OO API)

```python
import matplotlib as mpl
import matplotlib.pyplot as plt

OKABE_ITO = ["#0072B2", "#D55E00", "#009E73", "#CC79A7", "#E69F00", "#56B4E9", "#000000"]

RC_PUB = {
    "font.family": "sans-serif",
    "font.size": 8,
    "axes.titlesize": 8.5,
    "axes.labelsize": 8,
    "xtick.labelsize": 7,
    "ytick.labelsize": 7,
    "legend.fontsize": 7,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.prop_cycle": mpl.cycler(color=OKABE_ITO),
    "pdf.fonttype": 42,
    "ps.fonttype": 42,
    "svg.fonttype": "none",
    "savefig.facecolor": "white",
}

MM = 1 / 25.4
with mpl.rc_context(RC_PUB):
    fig, axes = plt.subplot_mosaic(
        [["A", "B"]],
        figsize=(180 * MM, 70 * MM),
        layout="constrained",
    )
    axes["A"].plot(time_h, ctrl_mean, marker="o", linestyle="-", label="Control (n = 6)")
    axes["A"].plot(time_h, trt_mean, marker="s", linestyle="--", label="Treated (n = 6)")
    axes["A"].set(xlabel="Time (h)", ylabel="Response (a.u.)")
    axes["A"].legend(frameon=False)

    for label, ax in axes.items():
        ax.text(-0.12, 1.06, label, transform=ax.transAxes, fontweight="bold", fontsize=9)

    fig.savefig("figure1.pdf")
    fig.savefig("figure1.png", dpi=600)
    plt.close(fig)
```

## Final Export Checklist

- [ ] Raw data, filtering rules, seeds, and figure script preserved together.
- [ ] Units on every quantitative axis & colorbar; uncertainty metric and independent `n` stated.
- [ ] Color paired with shape/linestyle/direct labels; no clipped bars or unmotivated dual axes.
- [ ] Exported PDF/PNG inspected at actual 89 mm / 180 mm width (no overlapping ticks, clipped labels, or rasterized WebGL surprises).
- [ ] Live author instructions checked for the exact target journal and submission stage.

## Upstream References & Citation

- Extended palette audits, journal profiles & style presets: <https://github.com/K-Dense-AI/claude-scientific-skills/tree/main/skills/scientific-visualization>
- Adapted from Scientific Agent Skills by K-Dense Inc. (MIT): Kassis et al. (2026), *Scientific Agent Skills: A Library of Procedural Knowledge for Research Agents*, <https://doi.org/10.48550/arXiv.2609.00065>.
