#!/usr/bin/env python3
"""The Lowe: barrow hills behind Saltfell, north across the ravine (WORLD.md 5.2).

Same world coordinates and the same landform as Saltfell (terrain_saltfell),
so the seam at the ravine is continuous: what you see across the ravine from
the yard is what you walk on here. North of the ravine the Lowe adds:

  the Barrow Road  from the cliff-top pass (west) past standing stones
  the Kin-Mounds   long stone-fronted barrows facing the road, round mounds
  the peat bog     cuttings full of black water; an island of cut peat
  the Open Barrow  the Turfwright's arena: a hollow walled with stacked sods
                   round his daughters' twin barrow
  the bounds       sea cliffs west, the scree fell east, a fell wall north,
                   the ravine south (bridged at BRIDGE_X once lowered)

Pure Python. Run: python3 tools/terrain_lowe.py   (gen_lowe.py runs it too)
"""
import math
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_saltfell as S  # noqa: E402
from terrain_saltfell import fbm, smooth, vnoise, _lerp, _seg_dist, _pad_weight  # noqa: E402

OUT_DIR = S.OUT_DIR
X0, Z0, CELL, NX, NZ = -128.0, -336.0, 1.0, 257, 281
FAR_X0, FAR_Z0, FAR_CELL, FAR_N = -1024.0, -1300.0, 8.0, 257

NORTH_WALL_Z = -248.0

# the Barrow Road: the pass -> the hearth -> the kin-mounds -> the Open Barrow
ROAD = [(-89, -88), (-76, -100), (-58, -114), (-38, -124), (-16, -132), (6, -142),
        (24, -156), (36, -170), (44, -178)]
BRIDGE_PATH = [(-8, -86), (-14, -100), (-26, -116), (-38, -124)]
BOG_PATH = [(-58, -114), (-62, -140), (-56, -160)]          # to the cuttings' edge

# long barrows: (id, x, z, w, l) — they face the road (yaw computed below)
LONG_BARROWS = [("kin_a", -62, -127, 6, 14), ("kin_b", -24, -112, 6, 13),
                ("kin_c", -2, -153, 7, 15), ("kin_d", 22, -132, 6, 12)]
ARENA = (46.0, -198.0, 21.0)          # cx, cz, radius
TWIN = ("twin", 46.0, -222.0, 10, 16)  # the twin barrow, door facing the arena

BOG = (-40.0, -190.0, 19.0)           # cx, cz, radius
ISLAND = (-40.0, -190.0, 4.5)
BOG_RIM = 30.0                        # the level water / ice disc never passes this


def _road_nearest(x, z):
    best, bp = 1e9, (0, 0)
    for i in range(len(ROAD) - 1):
        ax, az = ROAD[i]
        bx, bz = ROAD[i + 1]
        ex, ez = bx - ax, bz - az
        L = ex * ex + ez * ez
        t = max(0.0, min(1.0, ((x - ax) * ex + (z - az) * ez) / L))
        px, pz = ax + t * ex, az + t * ez
        d = math.hypot(x - px, z - pz)
        if d < best:
            best, bp = d, (px, pz)
    return bp


def barrow_yaw(x, z, toward=None):
    """Yaw so the barrow's door (local +z) looks at the road (or a point)."""
    px, pz = toward if toward else _road_nearest(x, z)
    return math.degrees(math.atan2(px - x, pz - z))


def _barrow_pads():
    out = []
    for (bid, x, z, w, l) in LONG_BARROWS:
        out.append((x, z, w * 0.5 + 2.5, l * 0.5 + 3.5, barrow_yaw(x, z)))
    tid, tx, tz, tw, tl = TWIN
    out.append((tx, tz, tw * 0.5 + 3, tl * 0.5 + 3, barrow_yaw(tx, tz, (ARENA[0], ARENA[1]))))
    return out


_PADS = None
_BASE_CACHE = {}


def _base_at(x, z):
    k = (round(x, 1), round(z, 1))
    if k not in _BASE_CACHE:
        _BASE_CACHE[k] = S.height(x, z)
    return _BASE_CACHE[k]


def bog_level():
    return _base_at(BOG[0], BOG[1]) - 1.2


def arena_level():
    return _base_at(ARENA[0], ARENA[1]) - 1.5


def bog_radius(x, z):
    th = math.atan2(z - BOG[1], x - BOG[0])
    return BOG[2] * (1.0 + 0.16 * math.sin(3 * th + 0.4) + 0.1 * math.sin(5 * th + 1.9)
                     + 0.12 * fbm(x * 0.08, z * 0.08, 2, 81))


def height(x, z):
    global _PADS
    if _PADS is None:
        _PADS = _barrow_pads()
    h = S.height(x, z)
    if z > -86:
        return h
    lowe = smooth(-86, -100, z)
    # heather moor: broader swells than the coast turf
    h += lowe * (1.8 * fbm(x * 0.025, z * 0.025, 3, 80) + 0.4 * fbm(x * 0.12, z * 0.12, 2, 79))
    # the fell wall to the north: too steep to climb, the Lowe's back
    wz = NORTH_WALL_Z + 6.0 * fbm(x * 0.03, 0.2, 2, 82)
    if z < wz:
        h += min(70.0, (wz - z) * 1.75) + 2.0 * fbm(x * 0.1, z * 0.1, 2, 83)
    # the Open Barrow: a hollow, levelled where the Turfwright cut it
    d = math.hypot(x - ARENA[0], z - ARENA[1])
    if d < ARENA[2] + 10:
        w = 1.0 - smooth(ARENA[2] - 2, ARENA[2] + 8, d)
        h = _lerp(h, arena_level() + 0.25 * fbm(x * 0.2, z * 0.2, 1, 84), w)
    # long barrow pads
    for (px, pz, hx, hz, yaw) in _PADS:
        wpad = _pad_weight(x, z, (px, pz, hx, hz, yaw, 0, 4.0))
        if wpad > 0:
            h = _lerp(h, _base_at(px, pz), wpad)
    # the peat bog: black water in the cuttings, a shore of wet moss
    d = math.hypot(x - BOG[0], z - BOG[1])
    if d < BOG_RIM + 30:
        R = bog_radius(x, z)
        W = bog_level()
        floor = W - 1.5 + 0.3 * fbm(x * 0.3, z * 0.3, 1, 85)
        shore = floor + max(0.0, d - R) * 0.3
        # the moor slopes: build a low bank on the downhill side so the black
        # water lies level inside BOG_RIM and nowhere else
        bund = W + 0.3 - max(0.0, d - BOG_RIM) * 0.45
        h = min(max(h, bund), shore)
        # cut faces: straight-ish peat banks inside the bog
        if d < R and math.sin(x * 0.45 + z * 0.12) > 0.85:
            h = W - 0.4
        # the island of stacked cut peat
        di = math.hypot(x - ISLAND[0], z - ISLAND[1])
        if di < ISLAND[2] + 2:
            h = max(h, W + 0.5 - max(0.0, di - ISLAND[2]) * 0.6)
    return h


def path_weight(x, z):
    best = 0.0
    for pts, w in ((ROAD, 2.4), (BRIDGE_PATH, 1.6), (BOG_PATH, 1.4)):
        for i in range(len(pts) - 1):
            dd = _seg_dist(x, z, *pts[i], *pts[i + 1])
            if dd < w + 1.5:
                best = max(best, 1.0 - smooth(w * 0.4, w + 1.0, dd + 0.6 * fbm(x * 0.4, z * 0.4, 1, 30)))
    return best


def splat(x, z, h):
    if z > -86:
        return S.splat(x, z, h)
    d = math.hypot(x - BOG[0], z - BOG[1])
    wet = 1.0 - smooth(0.0, 6.0, d - bog_radius(x, z)) if d < BOG[2] * 2 else 0.0
    var = 0.5 + 0.5 * fbm(x * 0.07, z * 0.07, 2, 21)
    return (0.0, path_weight(x, z), wet, var)


def write():
    os.makedirs(OUT_DIR, exist_ok=True)
    hs = []
    sp = bytearray()
    for j in range(NZ):
        z = Z0 + j * CELL
        for i in range(NX):
            x = X0 + i * CELL
            h = height(x, z)
            hs.append(h)
            sp += bytes(int(max(0, min(1, c)) * 255 + 0.5) for c in splat(x, z, h))
    with open(os.path.join(OUT_DIR, "lowe_h.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
    with open(os.path.join(OUT_DIR, "lowe_splat.bin"), "wb") as f:
        f.write(bytes(sp))
    far = []
    for j in range(FAR_N):
        z = FAR_Z0 + j * FAR_CELL
        for i in range(FAR_N):
            x = FAR_X0 + i * FAR_CELL
            inner = X0 + 8 <= x <= X0 + (NX - 1) * CELL - 8 and Z0 + 8 <= z <= Z0 + (NZ - 1) * CELL - 8
            hh = height(x, z) if (X0 - 40 <= x <= X0 + NX + 40 and Z0 - 40 <= z <= Z0 + NZ + 40) else S.height(x, z)
            if z < NORTH_WALL_Z - 40:
                hh += 14.0 * fbm(x * 0.004, z * 0.004, 3, 40) * smooth(NORTH_WALL_Z - 40, NORTH_WALL_Z - 120, z)
            far.append(hh - (4.0 if inner else 0.0))
    with open(os.path.join(OUT_DIR, "lowe_far.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(far), *far))
    print("terrain (lowe): %dx%d fine -> %s" % (NX, NZ, OUT_DIR))


_cache = None


def load_grid():
    global _cache
    if _cache is None:
        with open(os.path.join(OUT_DIR, "lowe_h.bin"), "rb") as f:
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
        "source": "res://data/terrain/lowe_h.bin",
        "splat": "res://data/terrain/lowe_splat.bin",
        "far": "res://data/terrain/lowe_far.bin",
        "origin": [X0, Z0], "cell": CELL, "size": [NX, NZ],
        "far_origin": [FAR_X0, FAR_Z0], "far_cell": FAR_CELL, "far_size": FAR_N,
        "chunk": 32, "generator": "tools/terrain_lowe.py", "seed": S.SEED,
    }


if __name__ == "__main__":
    write()
