#!/usr/bin/env python3
"""Regenerate Eval/results/before_after.png — the guardrail recalibration chart.

Honest, same-set (105-query) before/after for the domain guardrail: the numbers
are two real runs of ./Eval/run_eval.sh over the identical golden set, differing
only in the recalibration (embedding floor 0.28 -> 0.38 + keyword/lexicon fixes).

This is a presentation artifact only; the eval itself needs no Python. To
regenerate:  pip install matplotlib && python3 Eval/make_chart.py
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib import font_manager

# Measured on the 105-query golden set (see Eval/results/EVAL_REPORT.md for the
# "after" run; the "before" run is the identical set at the old 0.28 floor).
metrics = ["Precision", "Recall", "F1"]
before = [1.00, 0.68, 0.81]
after = [0.94, 0.93, 0.93]

GRAY, BLUE = "#9b9a92", "#2a78d6"
INK, SUB, MUT, SURFACE, GRID = "#0b0b0b", "#52514e", "#898781", "#fcfcfb", "#e1e0d9"

fig, ax = plt.subplots(figsize=(9.6, 4.8), dpi=150)
fig.patch.set_facecolor(SURFACE)
ax.set_facecolor(SURFACE)

x = range(len(metrics))
w = 0.36
bars_b = ax.bar([i - w / 2 for i in x], before, w, color=GRAY, label="Before recalibration", zorder=3)
bars_a = ax.bar([i + w / 2 for i in x], after, w, color=BLUE, label="After", zorder=3)

for bars, vals, color in ((bars_b, before, SUB), (bars_a, after, "#185FA5")):
    for bar, v in zip(bars, vals):
        ax.text(bar.get_x() + bar.get_width() / 2, v + 0.02, f"{v:.2f}",
                ha="center", va="bottom", fontsize=11, color=color, fontweight="medium")

ax.set_ylim(0, 1.08)
ax.set_yticks([0, 0.25, 0.5, 0.75, 1.0])
ax.set_xticks(list(x))
ax.set_xticklabels(metrics, fontsize=12, color=SUB)
ax.tick_params(axis="both", length=0, colors=MUT)
ax.grid(axis="y", color=GRID, linewidth=1, zorder=0)
for s in ax.spines.values():
    s.set_visible(False)
ax.set_axisbelow(True)

fig.text(0.055, 0.93, "Guardrail recalibration — measured on the 105-query set",
         ha="left", fontsize=15, fontweight="bold", color=INK)
fig.text(0.055, 0.865, "Growing the eval set exposed real leaks; recalibration lifted recall 0.68 to 0.93.",
         ha="left", fontsize=10.5, color=SUB)
ax.legend(loc="upper right", frameon=False, fontsize=10, ncol=2,
          bbox_to_anchor=(1.0, 1.10), labelcolor=SUB)
fig.text(0.055, 0.035,
         "Higher is better (0–1). Recall rose sharply; precision dipped slightly "
         "(a few real questions over-refused) — the honest overlap tradeoff. n=105.",
         fontsize=9, color=MUT)

fig.subplots_adjust(top=0.72, bottom=0.15, left=0.075, right=0.965)
out = "Eval/results/before_after.png"
fig.savefig(out, facecolor=SURFACE)
print("wrote", out)
