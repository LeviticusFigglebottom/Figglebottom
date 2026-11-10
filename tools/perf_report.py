#!/usr/bin/env python3
"""Summarise tools/perf_tour.sh output into markdown tables.

Usage: python3 tools/perf_report.py build/perf/<tag> [--worst N]
Prints: the machine line, one table per quality tier, and the N worst views
(by 1%-low FPS at quality 1)."""
import glob
import json
import os
import sys


def load(d):
    meta, rows = None, []
    for f in sorted(glob.glob(os.path.join(d, "*.json"))):
        j = json.load(open(f, encoding="utf-8"))
        meta = meta or j
        rows += j["results"]
    return meta, rows


def table(rows):
    out = ["| area | state | view | avg FPS | 1% low | GPU ms | CPU ms | draws | prims (k) | VRAM MB | hitches |",
           "|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"]
    for r in rows:
        out.append("| %s | %s | %s | %.0f | %.0f | %.2f | %.2f | %.0f | %.0f | %.0f | %d |" % (
            r["area"], r["state"], r["view"], r["avg_fps"], r["low1_fps"], r["gpu_ms"],
            r["cpu_ms"], r["draws"], r["prims"] / 1000, r["vram_mb"], r["hitches_33ms"]))
    return "\n".join(out)


def main():
    sys.stdout.reconfigure(encoding="utf-8")   # Windows consoles default to cp1252
    d = sys.argv[1]
    worst = int(sys.argv[sys.argv.index("--worst") + 1]) if "--worst" in sys.argv else 5
    meta, rows = load(d)
    if not rows:
        sys.exit("no results in " + d)
    print("**%s** (%s) · %s · %s · %dx%d · cap %d, %gs per view\n" % (
        meta["adapter"], meta["driver"], meta["cpu"], meta["os"],
        meta["resolution"][0], meta["resolution"][1], meta["cap"], meta["secs"]))
    for q in sorted({r["quality"] for r in rows}):
        sub = [r for r in rows if r["quality"] == q]
        print("### Quality %d\n" % q)
        print(table(sub) + "\n")
    q1 = [r for r in rows if r["quality"] == 1] or rows
    print("### Worst %d views (quality %d, by 1%% low)\n" % (worst, q1[0]["quality"]))
    print(table(sorted(q1, key=lambda r: r["low1_fps"])[:worst]))


if __name__ == "__main__":
    main()
