#!/usr/bin/env python3
"""Render a review spectrogram (log-frequency, with a loudness strip) of
each music/ambience .ogg into docs/audio/. Decodes with ffmpeg.

    python3 tools/audio/spectrogram.py [assets/audio/music/x.ogg ...]
"""
import glob
import os
import subprocess
import sys

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from scipy import signal

import dsp

DOCS = os.path.join(dsp.ROOT, "docs", "audio")


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "quiet", "-i", path, "-f", "s16le", "-ac", "1",
                          "-ar", str(dsp.SR), "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, np.int16).astype(np.float64) / 32768


def render(path, out):
    x = decode(path)
    f, t, S = signal.spectrogram(x, dsp.SR, nperseg=4096, noverlap=3072, window="hann")
    S_db = 10 * np.log10(S + 1e-12)
    fig, (ax, ax2) = plt.subplots(2, 1, figsize=(14, 6), sharex=True,
                                  gridspec_kw={"height_ratios": [4, 1]})
    fig.patch.set_facecolor("#14161a")
    for a in (ax, ax2):
        a.set_facecolor("#14161a")
        a.tick_params(colors="#c8c2b4")
        for s in a.spines.values():
            s.set_color("#3a3d44")
    keep = (f >= 30) & (f <= 12000)
    vmax = np.percentile(S_db[keep], 99.7)
    ax.pcolormesh(t, f[keep], S_db[keep], shading="auto", cmap="magma", vmin=vmax - 75, vmax=vmax)
    ax.set_yscale("log")
    ax.set_yticks([50, 100, 200, 440, 1000, 2000, 5000, 10000])
    ax.set_yticklabels(["50", "100", "200", "440", "1k", "2k", "5k", "10k"])
    ax.set_ylabel("Hz", color="#c8c2b4")
    name = os.path.splitext(os.path.basename(path))[0]
    ax.set_title(f"{name}  ({len(x)/dsp.SR:.1f} s)", color="#efe9dc", loc="left")
    hop = dsp.SR // 10
    rms = [np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)]
    rt = np.arange(len(rms)) * 0.1
    ax2.plot(rt, 20 * np.log10(np.array(rms) + 1e-9), color="#e08a3c", lw=1)
    ax2.set_ylim(-60, 0)
    ax2.set_ylabel("dBFS", color="#c8c2b4")
    ax2.set_xlabel("seconds", color="#c8c2b4")
    fig.tight_layout()
    os.makedirs(os.path.dirname(out), exist_ok=True)
    fig.savefig(out, dpi=80, facecolor=fig.get_facecolor())
    plt.close(fig)
    print(f"[spectrogram] {os.path.relpath(out, dsp.ROOT)}")


if __name__ == "__main__":
    paths = sys.argv[1:] or sorted(glob.glob(os.path.join(dsp.AUDIO, "music", "*.ogg"))
                                   + glob.glob(os.path.join(dsp.AUDIO, "ambience", "*.ogg")))
    for p in paths:
        render(p, os.path.join(DOCS, os.path.splitext(os.path.basename(p))[0] + ".png"))
