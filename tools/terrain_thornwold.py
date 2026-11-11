#!/usr/bin/env python3
"""Thornwold (WORLD.md 5.5): the wood east of the tarn, on the shared
landform (thorn_land.py, called from terrain_lowe.height, so Tarnhall sees
the same notch from its side of the seam). This module frames the grid,
paints the splat and writes the committed heightmap.

Run: python3 tools/terrain_thornwold.py   (gen_thornwold.py runs it too)"""
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402
import thorn_land as T  # noqa: E402
import terrain_saltfell as S  # noqa: E402
from terrain_saltfell import fbm, smooth, _seg_dist  # noqa: E402

OUT_DIR = S.OUT_DIR
X0, Z0, CELL, NX, NZ = 246.0, -410.0, 1.0, 257, 145
FAR_X0, FAR_Z0, FAR_CELL, FAR_N = -650.0, -1300.0, 8.0, 257


def height(x, z):
    return L.height(x, z)


def path_weight(x, z):
    rd, _ = T.notch_road(x, z)
    d = min(rd if x < 314 else 1e9, T.drove_d(x, z))
    best = 1.0 - smooth(1.4, 2.8, d)
    # the clearing: trodden, ash-dark
    cd = math.hypot(x - T.CLEARING[0], z - T.CLEARING[1])
    best = max(best, 0.45 * (1.0 - smooth(T.CLEARING[2] * 0.4, T.CLEARING[2], cd)))
    # --- progression gates (ADR 0015): the way on, round the outer ring to the fell path
    gd = math.hypot(x - T.GRAVE[0], z - T.GRAVE[1])
    ga = math.degrees(math.atan2(z - T.GRAVE[1], x - T.GRAVE[0]))
    if -14.0 <= ga <= 180.0:             # the south side: west gap -> the Outer Ring hearth -> east
        best = max(best, 0.85 * (1.0 - smooth(1.0, 2.4, abs(gd - (T.RINGS[2] + 3.5)))))
    if x > 478.0:
        fd, _ = T._seg(x, z, 479.0, -331.0, 500.0, -331.6)
        best = max(best, 1.0 - smooth(1.3, 2.7, fd))
    # --- end progression gates
    return best


def splat(x, z, h):
    # no shingle in the wood; moss-damp hollows
    shingle = 0.0
    wet = 0.25 * (1.0 - smooth(0.0, 0.6, fbm(x * 0.05, z * 0.05, 2, 170)))
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
    terrain_patch.apply("thornwold", hs, X0, Z0, NX, NZ)
    with open(os.path.join(OUT_DIR, "thornwold_h.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
    with open(os.path.join(OUT_DIR, "thornwold_splat.bin"), "wb") as f:
        f.write(bytes(sp))
    far = []
    for j in range(FAR_N):
        z = FAR_Z0 + j * FAR_CELL
        for i in range(FAR_N):
            x = FAR_X0 + i * FAR_CELL
            inner = X0 + 8 <= x <= X0 + (NX - 1) * CELL - 8 and Z0 + 8 <= z <= Z0 + (NZ - 1) * CELL - 8
            hh = height(x, z)
            far.append(hh - (4.0 if inner else 0.0))
    with open(os.path.join(OUT_DIR, "thornwold_far.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(far), *far))
    print("terrain (thornwold): %dx%d fine -> %s" % (NX, NZ, OUT_DIR))


_cache = None


def load_grid():
    global _cache
    if _cache is None:
        with open(os.path.join(OUT_DIR, "thornwold_h.bin"), "rb") as f:
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
        "source": "res://data/terrain/thornwold_h.bin",
        "splat": "res://data/terrain/thornwold_splat.bin",
        "far": "res://data/terrain/thornwold_far.bin",
        "origin": [X0, Z0], "cell": CELL, "size": [NX, NZ],
        "far_origin": [FAR_X0, FAR_Z0], "far_cell": FAR_CELL, "far_size": FAR_N,
        "chunk": 32, "generator": "tools/terrain_thornwold.py", "seed": S.SEED,
        # forest floor: moss and needle-litter, grey-brown fell rock
        "palette": {"turf_a": [0.15, 0.19, 0.10], "turf_b": [0.24, 0.20, 0.13], "rock_col": [0.30, 0.29, 0.28]},
    }


if __name__ == "__main__":
    write()
