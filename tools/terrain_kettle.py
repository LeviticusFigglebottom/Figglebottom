#!/usr/bin/env python3
"""Kettle Fjord (WORLD.md 5.3): the fjord north of the Lowe, on the shared
landform (terrain_lowe carves the fjord and the Kettle Road, so the Lowe sees
the same water from its side of the seam). This module only frames the grid,
paints the splat, and writes the committed heightmap.

Run: python3 tools/terrain_kettle.py   (gen_kettle.py runs it too)"""
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402
import terrain_saltfell as S  # noqa: E402
from terrain_saltfell import fbm, smooth, _seg_dist  # noqa: E402

OUT_DIR = S.OUT_DIR
X0, Z0, CELL, NX, NZ = -200.0, -400.0, 1.0, 257, 185
FAR_X0, FAR_Z0, FAR_CELL, FAR_N = -1100.0, -1300.0, 8.0, 257


def height(x, z):
    return L.height(x, z)


def shelf_z(x):
    """The middle of the south shelf at x (walk line along the shore)."""
    return L.fjord_z(x) + L.fjord_half(x) - 3.0


def path_weight(x, z):
    best = 0.0
    pts = L.KETTLE_ROAD
    for i in range(len(pts) - 1):
        d = _seg_dist(x, z, *pts[i], *pts[i + 1])
        if d < 3.5:
            best = max(best, 1.0 - smooth(1.0, 3.0, d))
    return best


def splat(x, z, h):
    shingle = 1.0 - smooth(2.6, 4.0, h) if h > -0.5 else 0.6
    wet = 1.0 - smooth(0.3, 2.2, h)
    var = 0.5 + 0.5 * fbm(x * 0.07, z * 0.07, 2, 21)
    return (shingle, path_weight(x, z), wet, var)


def write():
    os.makedirs(OUT_DIR, exist_ok=True)
    hs, sp = [], bytearray()
    for j in range(NZ):
        z = Z0 + j * CELL
        for i in range(NX):
            x = X0 + i * CELL
            h = height(x, z)
            hs.append(h)
            sp += bytes(int(max(0, min(1, c)) * 255 + 0.5) for c in splat(x, z, h))
    import terrain_patch                  # ramps out of terrain traps (tools/fix_traps.py)
    terrain_patch.apply("kettle_fjord", hs, X0, Z0, NX, NZ)
    with open(os.path.join(OUT_DIR, "kettle_h.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
    with open(os.path.join(OUT_DIR, "kettle_splat.bin"), "wb") as f:
        f.write(bytes(sp))
    far = []
    for j in range(FAR_N):
        z = FAR_Z0 + j * FAR_CELL
        for i in range(FAR_N):
            x = FAR_X0 + i * FAR_CELL
            inner = X0 + 8 <= x <= X0 + (NX - 1) * CELL - 8 and Z0 + 8 <= z <= Z0 + (NZ - 1) * CELL - 8
            hh = height(x, z)
            # beyond the grid the fjord runs on to the sea and the fells rise
            if z < -380:
                hh += 20.0 * fbm(x * 0.004, z * 0.004, 3, 41) * smooth(-380, -460, z)
            far.append(hh - (4.0 if inner else 0.0))
    with open(os.path.join(OUT_DIR, "kettle_far.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(far), *far))
    print("terrain (kettle): %dx%d fine -> %s" % (NX, NZ, OUT_DIR))


_cache = None


def load_grid():
    global _cache
    if _cache is None:
        with open(os.path.join(OUT_DIR, "kettle_h.bin"), "rb") as f:
            data = f.read()
        _cache = list(struct.unpack("<%df" % (len(data) // 4), data))
    return _cache


def sample(x, z):
    g = load_grid()
    fx = (x - X0) / CELL
    fz = (z - Z0) / CELL
    i = max(0, min(NX - 2, int(math.floor(fx))))
    j = max(0, min(NZ - 2, int(math.floor(fz))))
    tx, tz = fx - i, fz - j
    a = g[j * NX + i]; b = g[j * NX + i + 1]
    c = g[(j + 1) * NX + i]; d = g[(j + 1) * NX + i + 1]
    return (a + (b - a) * tx) * (1 - tz) + (c + (d - c) * tx) * tz


def terrain_block():
    return {
        "source": "res://data/terrain/kettle_h.bin",
        "splat": "res://data/terrain/kettle_splat.bin",
        "far": "res://data/terrain/kettle_far.bin",
        "origin": [X0, Z0], "cell": CELL, "size": [NX, NZ],
        "far_origin": [FAR_X0, FAR_Z0], "far_cell": FAR_CELL, "far_size": FAR_N,
        "chunk": 32, "generator": "tools/terrain_kettle.py", "seed": S.SEED,
        # dark fjord rock, thin grass on the ledges
        "palette": {"turf_a": [0.16, 0.20, 0.10], "turf_b": [0.24, 0.24, 0.12], "rock_col": [0.24, 0.25, 0.27]},
    }


if __name__ == "__main__":
    write()
