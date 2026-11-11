#!/usr/bin/env python3
"""Shepherd's Reach (WORLD.md 5.6): the high pasture under the glacier, on
the shared landform (high_land.py, called from terrain_lowe.height). This
module frames the grid, paints the splat and writes the committed heightmap.

Run: python3 tools/terrain_reach.py   (gen_reach.py runs it too)"""
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402
import high_land as T  # noqa: E402
import terrain_saltfell as S  # noqa: E402
from terrain_saltfell import fbm, smooth, _seg_dist  # noqa: E402

OUT_DIR = S.OUT_DIR
X0, Z0, CELL, NX, NZ = 466.0, -420.0, 1.0, 257, 169
FAR_X0, FAR_Z0, FAR_CELL, FAR_N = -400.0, -1300.0, 8.0, 257


def height(x, z):
    return L.height(x, z)


def path_weight(x, z):
    rd, _, _ = T.poly_road(T.REACH_PATH, x, z)
    best = 1.0 - smooth(1.6, 3.2, rd)
    # sheep-trods: the walk from the sheilings over the bridge to the High Fold
    for (ax, az, bx, bz) in ((566.0, -318.0, 604.0, -300.0), (604.0, -300.0, T.BRIDGE_X, T.beck_z(T.BRIDGE_X) + 6.0),
                             (T.BRIDGE_X, T.beck_z(T.BRIDGE_X) - 6.0, T.HIGH_FOLD[0] - 10.0, T.HIGH_FOLD[1] + 10.0)):
        d, _ = T._seg(x, z, ax, az, bx, bz)
        best = max(best, 0.8 * (1.0 - smooth(0.8, 2.2, d)))
    return best

def splat(x, z, h):
    bd = abs(z - T.beck_z(x))
    shingle = 1.0 - smooth(T.BECK_HALF, T.BECK_HALF + 1.5, bd) if x > 550 else 0.0
    wet = 0.7 * (1.0 - smooth(T.BECK_HALF + 0.5, T.BECK_HALF + 3.0, bd)) if x > 550 else 0.0
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
    terrain_patch.apply("shepherds_reach", hs, X0, Z0, NX, NZ)
    with open(os.path.join(OUT_DIR, "reach_h.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
    with open(os.path.join(OUT_DIR, "reach_splat.bin"), "wb") as f:
        f.write(bytes(sp))
    far = []
    for j in range(FAR_N):
        z = FAR_Z0 + j * FAR_CELL
        for i in range(FAR_N):
            x = FAR_X0 + i * FAR_CELL
            inner = X0 + 8 <= x <= X0 + (NX - 1) * CELL - 8 and Z0 + 8 <= z <= Z0 + (NZ - 1) * CELL - 8
            hh = height(x, z)
            far.append(hh - (4.0 if inner else 0.0))
    with open(os.path.join(OUT_DIR, "reach_far.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(far), *far))
    print("terrain (reach): %dx%d fine -> %s" % (NX, NZ, OUT_DIR))


_cache = None


def load_grid():
    global _cache
    if _cache is None:
        with open(os.path.join(OUT_DIR, "reach_h.bin"), "rb") as f:
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
        "source": "res://data/terrain/reach_h.bin",
        "splat": "res://data/terrain/reach_splat.bin",
        "far": "res://data/terrain/reach_far.bin",
        "origin": [X0, Z0], "cell": CELL, "size": [NX, NZ],
        "far_origin": [FAR_X0, FAR_Z0], "far_cell": FAR_CELL, "far_size": FAR_N,
        "chunk": 32, "generator": "tools/terrain_reach.py", "seed": S.SEED,
        # forest floor: moss and needle-litter, grey-brown fell rock
        "palette": {"turf_a": [0.18, 0.22, 0.11], "turf_b": [0.26, 0.26, 0.14], "rock_col": [0.33, 0.33, 0.34]},
    }


if __name__ == "__main__":
    write()
