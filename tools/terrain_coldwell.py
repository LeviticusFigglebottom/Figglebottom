#!/usr/bin/env python3
"""The Coldwell (WORLD.md 5.7): the Upwater climbing the mountain's shoulder
beside the frozen river to the wellhead under the glacier's lip, on the
shared landform (high_land.py). The far terrain spans the whole country, so
the view from the top goes back over every region.

Run: python3 tools/terrain_coldwell.py   (gen_coldwell.py runs it too)"""
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
X0, Z0, CELL, NX, NZ = 676.0, -556.0, 1.0, 289, 193
FAR_X0, FAR_Z0, FAR_CELL, FAR_N = -560.0, -1400.0, 8.0, 289


def height(x, z):
    return L.height(x, z)


def path_weight(x, z):
    rd, _, _ = T.poly_road(T.UPWATER, x, z)
    best = 1.0 - smooth(1.8, 3.4, rd)
    wd = math.hypot(x - T.WELLHEAD[0], z - T.WELLHEAD[1])
    best = max(best, 0.5 * (1.0 - smooth(T.RING_R - 2.0, T.RING_R + 2.0, wd)))
    return best

def splat(x, z, h):
    rd, _, side = T.poly_road(T.UPWATER, x, z)
    river = side < 0 and abs(rd - T.RIVER_OFF) < 3.2
    shingle = 0.85 if river else 0.0
    wet = 0.8 if river else 0.0
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
    with open(os.path.join(OUT_DIR, "coldwell_h.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
    with open(os.path.join(OUT_DIR, "coldwell_splat.bin"), "wb") as f:
        f.write(bytes(sp))
    far = []
    for j in range(FAR_N):
        z = FAR_Z0 + j * FAR_CELL
        for i in range(FAR_N):
            x = FAR_X0 + i * FAR_CELL
            inner = X0 + 8 <= x <= X0 + (NX - 1) * CELL - 8 and Z0 + 8 <= z <= Z0 + (NZ - 1) * CELL - 8
            hh = height(x, z)
            far.append(hh - (4.0 if inner else 0.0))
    with open(os.path.join(OUT_DIR, "coldwell_far.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(far), *far))
    print("terrain (coldwell): %dx%d fine -> %s" % (NX, NZ, OUT_DIR))


_cache = None


def load_grid():
    global _cache
    if _cache is None:
        with open(os.path.join(OUT_DIR, "coldwell_h.bin"), "rb") as f:
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
        "source": "res://data/terrain/coldwell_h.bin",
        "splat": "res://data/terrain/coldwell_splat.bin",
        "far": "res://data/terrain/coldwell_far.bin",
        "origin": [X0, Z0], "cell": CELL, "size": [NX, NZ],
        "far_origin": [FAR_X0, FAR_Z0], "far_cell": FAR_CELL, "far_size": FAR_N,
        "chunk": 32, "generator": "tools/terrain_coldwell.py", "seed": S.SEED,
        # forest floor: moss and needle-litter, grey-brown fell rock
        "palette": {"turf_a": [0.17, 0.2, 0.12], "turf_b": [0.24, 0.24, 0.16], "rock_col": [0.34, 0.34, 0.36]},
    }


if __name__ == "__main__":
    write()
