#!/usr/bin/env python3
"""Spectrogram contact sheets for the built sound effects and beds, one
PNG per family in docs/audio/ (sfx_sheet_<family>.png). Each cell is one
file: log-frequency spectrogram, 60 dB range, with the waveform under it.
Run after build_sfx.py; it reads docs/audio/sfx_report.json.

    python3 tools/audio/sfx_sheet.py
"""
import json
import math
import os

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy import signal

import build_sfx as B


def cell(ax, ax2, path, title):
    x = B.decode(path)
    nper = 512 if len(x) < 4 * B.SR else 2048
    f, t, S = signal.spectrogram(x, B.SR, nperseg=min(nper, max(len(x) // 2, 64)), noverlap=None)
    db = 10 * np.log10(S + 1e-12)
    ax.pcolormesh(t, f[1:], db[1:], vmin=db.max() - 60, vmax=db.max(), cmap="magma", shading="auto", rasterized=True)
    ax.set_yscale("log")
    ax.set_ylim(60, 20000)
    ax.set_title(title, fontsize=6, pad=2)
    ax.tick_params(labelsize=4, length=1, pad=1)
    ax.set_xticks([])
    ax2.plot(np.arange(len(x)) / B.SR, x, lw=0.3, color="#333")
    ax2.set_ylim(-1, 1)
    ax2.set_xlim(0, len(x) / B.SR)
    ax2.tick_params(labelsize=4, length=1, pad=1)
    ax2.set_yticks([])


def sheet(name, items):
    cols = 6
    rows = math.ceil(len(items) / cols)
    fig = plt.figure(figsize=(cols * 2.0, rows * 1.7))
    gs = fig.add_gridspec(rows * 2, cols, height_ratios=[3, 1] * rows, hspace=0.55, wspace=0.25)
    for i, (path, title) in enumerate(items):
        cell(fig.add_subplot(gs[(i // cols) * 2, i % cols]), fig.add_subplot(gs[(i // cols) * 2 + 1, i % cols]), path, title)
    out = os.path.join(B.DOCS, f"sfx_sheet_{name}.png")
    fig.savefig(out, dpi=85, bbox_inches="tight")
    plt.close(fig)
    print("[sheet]", out)


def main():
    rep = json.load(open(os.path.join(B.DOCS, "sfx_report.json")))
    fams = {}
    for key in sorted(rep["sounds"]):
        r = rep["sounds"][key]
        # first and last variant: enough to see that a set really varies
        for v in sorted({1, r["n"]}):
            fams.setdefault(r["family"], []).append(
                (os.path.join(B.OUT_SFX, f"{key}_{v}.{r['ext']}"), f"{key}_{v}  {r['rows'][v - 1]['lufs']:.0f} LUFS"))
    for fam, items in fams.items():
        sheet(fam, items)
    sheet("beds", [(os.path.join(B.OUT_AMB, n + ".ogg"), f"{n}  {r['row']['lufs']:.0f} LUFS")
                   for n, r in sorted(rep["beds"].items())])


if __name__ == "__main__":
    main()
