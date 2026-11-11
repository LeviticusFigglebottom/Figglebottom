#!/usr/bin/env python3
"""Cell patches over a generated heightmap: data/terrain/patches/<area>.json.

A patch raises single grid cells to a stated height (never lowers them). They
are written by tools/fix_traps.py (ramps out of terrain traps) and applied by
every terrain generator as it writes its fine grid, so the land can be
regenerated without losing them. Format: {"cells": [[x, z, height], ...]} in
world metres on the 1 m grid.
"""
import json
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR = os.path.join(ROOT, "data", "terrain", "patches")


def _path(area):
    return os.path.join(DIR, area + ".json")


def load(area):
    try:
        with open(_path(area)) as f:
            return {(c[0], c[1]): c[2] for c in json.load(f)["cells"]}
    except FileNotFoundError:
        return {}


def add(area, cells):
    cur = load(area)
    for k, v in cells.items():
        cur[k] = max(v, cur.get(k, -1e9))
    os.makedirs(DIR, exist_ok=True)
    with open(_path(area), "w") as f:
        json.dump({"cells": [[k[0], k[1], round(v, 3)] for k, v in sorted(cur.items())]}, f, separators=(",", ":"))
        f.write("\n")


def apply(area, hs, X0, Z0, NX, NZ, cell=1.0):
    """Raise the patched cells of a fine grid (a flat list, row-major)."""
    for (x, z), v in load(area).items():
        i = int(round((x - X0) / cell))
        j = int(round((z - Z0) / cell))
        if 0 <= i < NX and 0 <= j < NZ and hs[j * NX + i] < v:
            hs[j * NX + i] = v
    return hs


def rewrite_grid(area):
    """Apply the patches to the committed fine grid in place (same result as
    regenerating: generators call apply() on the same heights)."""
    with open(os.path.join(ROOT, "data", "areas", area + ".json")) as f:
        tb = json.load(f)["terrain"]
    p = os.path.join(ROOT, tb["source"].replace("res://", ""))
    with open(p, "rb") as f:
        data = f.read()
    hs = list(struct.unpack("<%df" % (len(data) // 4), data))
    apply(area, hs, tb["origin"][0], tb["origin"][1], tb["size"][0], tb["size"][1], tb.get("cell", 1.0))
    with open(p, "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
