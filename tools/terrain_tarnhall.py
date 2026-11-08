#!/usr/bin/env python3
"""Tarnhall (WORLD.md 5.4): the gorge above Kettle Fjord's head and the
mountain tarn with the great hall on its island, on the shared landform
(tarn_land.py, called from terrain_lowe.height, so Kettle Fjord sees the same
gorge from its side of the seam). This module frames the grid, paints the
splat and writes the committed heightmap.

Run: python3 tools/terrain_tarnhall.py   (gen_tarnhall.py runs it too)"""
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402
import tarn_land as T  # noqa: E402
import terrain_saltfell as S  # noqa: E402
from terrain_saltfell import fbm, smooth, _seg_dist  # noqa: E402

OUT_DIR = S.OUT_DIR
X0, Z0, CELL, NX, NZ = 24.0, -400.0, 1.0, 257, 145
FAR_X0, FAR_Z0, FAR_CELL, FAR_N = -870.0, -1300.0, 8.0, 257


def height(x, z):
    return L.height(x, z)


def path_weight(x, z):
    rd, _, _ = T.road(x, z)
    best = 1.0 - smooth(1.2, 3.0, rd) if x < 133 else 0.0
    cd, _ = T.causeway_d(x, z)
    if T.tarn_e(x, z) < 1.0:
        best = max(best, 1.0 - smooth(1.5, 2.8, cd))
    return best


def splat(x, z, h):
    # shingle round the tarn and in the stream bed; wet at the water
    e = T.tarn_e(x, z)
    shingle = (1.0 - smooth(0.95, 1.12, e)) * smooth(T.TARN_Y + 2.6, T.TARN_Y + 1.0, h)
    rd, ry, side = T.road(x, z)
    if side > 0 and abs(rd - T.STREAM_OFF) < 2.2 and x < 132:
        shingle = max(shingle, 0.8)
    wet = 1.0 - smooth(T.TARN_Y + 0.3, T.TARN_Y + 2.0, h) if e < 1.3 else (0.7 if shingle > 0.7 else 0.0)
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
    with open(os.path.join(OUT_DIR, "tarnhall_h.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
    with open(os.path.join(OUT_DIR, "tarnhall_splat.bin"), "wb") as f:
        f.write(bytes(sp))
    far = []
    for j in range(FAR_N):
        z = FAR_Z0 + j * FAR_CELL
        for i in range(FAR_N):
            x = FAR_X0 + i * FAR_CELL
            inner = X0 + 8 <= x <= X0 + (NX - 1) * CELL - 8 and Z0 + 8 <= z <= Z0 + (NZ - 1) * CELL - 8
            hh = height(x, z)
            far.append(hh - (4.0 if inner else 0.0))
    with open(os.path.join(OUT_DIR, "tarnhall_far.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(far), *far))
    print("terrain (tarnhall): %dx%d fine -> %s" % (NX, NZ, OUT_DIR))


_cache = None


def load_grid():
    global _cache
    if _cache is None:
        with open(os.path.join(OUT_DIR, "tarnhall_h.bin"), "rb") as f:
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
        "source": "res://data/terrain/tarnhall_h.bin",
        "splat": "res://data/terrain/tarnhall_splat.bin",
        "far": "res://data/terrain/tarnhall_far.bin",
        "origin": [X0, Z0], "cell": CELL, "size": [NX, NZ],
        "far_origin": [FAR_X0, FAR_Z0], "far_cell": FAR_CELL, "far_size": FAR_N,
        "chunk": 32, "generator": "tools/terrain_tarnhall.py", "seed": S.SEED,
        # high grazing round the tarn, grey fell rock
        "palette": {"turf_a": [0.20, 0.25, 0.11], "turf_b": [0.30, 0.29, 0.14], "rock_col": [0.30, 0.30, 0.31]},
    }


if __name__ == "__main__":
    write()
