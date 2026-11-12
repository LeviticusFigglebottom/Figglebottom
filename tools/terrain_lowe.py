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
import tarn_land as T  # noqa: E402
import thorn_land as TH  # noqa: E402
import high_land as HL  # noqa: E402
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

# the Cutter's Bothy (POI.md 3.4): a level pad 6 x 5 m cut into the slope
# below the Drying Stacks hearth (cx, cz, half x, half z, yaw)
BOTHY = (25.0, -171.0, 3.0, 2.5, 0.0)
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


_BOTHY_Y = None


def bothy_level():
    """The pad stands at the moor's own height on its downhill edge."""
    global _BOTHY_Y
    if _BOTHY_Y is None:
        _BOTHY_Y = height_no_road(BOTHY[0], BOTHY[1] + 1.5)
    return _BOTHY_Y


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
    # broken by buttresses and hollows, it tops out into rolling fell
    wz = NORTH_WALL_Z + 14.0 * fbm(x * 0.02, 0.2, 2, 82) + 5.0 * fbm(x * 0.07, 0.9, 1, 86)
    # gullies and buttresses: the wall advances and retreats every few metres
    rib = 1.0 - abs(2.0 * vnoise(x * 0.07, 0.4, 88) - 1.0)
    wz += 6.0 * (rib - 0.5)
    if z < wz:
        rise = (wz - z) * (1.15 + 0.5 * rib)
        h += min(30.0 + 10.0 * fbm(x * 0.015, z * 0.015, 2, 87), rise) + min(rise, 4.0) * fbm(x * 0.12, z * 0.12, 2, 83)
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
    # the Cutter's Bothy: cut level into the slope, the bank battered back
    wb = _pad_weight(x, z, (BOTHY[0], BOTHY[1], BOTHY[2], BOTHY[3], BOTHY[4], 0, 2.2))
    if wb > 0:
        h = _lerp(h, bothy_level(), wb)
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
    if z < -224:
        h = _kettle_carve(x, z, h)
        h = T.tarn_land(x, z, h)
        h = TH.thorn_land(x, z, h)
        h = HL.high_land(x, z, h)
    return h


# ------------------------------------------------------------------ Kettle Fjord
# The fjord lies north of the Lowe's fell wall (WORLD.md 5.3): sheer walls,
# sea-level water (ice in RIME), a broken shelf along its south shore. The
# Kettle Road comes down to it from the Lowe through a cleft in the wall.

def fjord_z(x):
    return -322.0 + 6.0 * math.sin(x * 0.025) + 2.0 * fbm(x * 0.03, 5.5, 1, 91)


def fjord_half(x):
    return 24.0 + 5.0 * math.sin(x * 0.04 + 0.7)


FJORD_HEAD_X = 42.0
SHELF_Y = 1.8
# where the south shelf is cut by rock running into the water (THAW: go round
# on the jetties; RIME: walk the ice)
SHELF_SPURS = [(-72.0, 7.0), (-18.0, 6.0)]
KETTLE_ROAD = [(-70, -232), (-62, -250), (-74, -262), (-96, -270), (-110, -283), (-113, -300)]
KETTLE_ROAD_END_Y = SHELF_Y + 0.3

# --- ground widened for the fjord's points of interest (docs/lore/POI.md 4, 9)
# the Dog Lines: a shingle spit built out from the south shelf, x0..x1, this
# far beyond the shelf's own level ground
DOG_SPIT = (-64.0, -54.0, 6.0)
# the Far Landing: level shingle on the north shore, x0..x1; 12 x 7 m, of
# which the back RECESS metres are cut into the wall foot and the rest stands
# out into the fjord (the fjord is at its narrowest here: see POI.md 4.5)
FAR_LANDING = (-59.0, -47.0)
FAR_LANDING_OUT, FAR_LANDING_RECESS = 4.0, 3.0
SPIT_LIP = 5.0                  # every spit shelves into the water like the shelf's own lip
# the Net-Cleft: a notch through the east spur at shelf height, on whole
# grid rows so its floor is level from wall to wall (z0..z1, 3 m between the
# rock faces), about 9 m long between cheeks of rock CLEFT_WALL high
CLEFT_SPUR = 1                  # index into SHELF_SPURS
CLEFT_Z = (-307.0, -304.0)
CLEFT_WALL = 4.0
CLEFT_CHEEK = 3.0               # how thick the seaward cheek stands before it drops to the water
# the Turn in the Road: a bay on the outside of the Kettle Road's last bend
ROAD_BAY_AT = 4                 # index of the bend in KETTLE_ROAD
ROAD_BAY = (5.0, 4.0)           # along the road, and out from its edge
ROAD_HALF = 2.4


def _road_t(x, z):
    """Distance to the Kettle Road and how far along it (0..1)."""
    total = sum(math.hypot(KETTLE_ROAD[i + 1][0] - KETTLE_ROAD[i][0], KETTLE_ROAD[i + 1][1] - KETTLE_ROAD[i][1])
                for i in range(len(KETTLE_ROAD) - 1))
    best, bt, run = 1e9, 0.0, 0.0
    for i in range(len(KETTLE_ROAD) - 1):
        ax, az = KETTLE_ROAD[i]
        bx, bz = KETTLE_ROAD[i + 1]
        ex, ez = bx - ax, bz - az
        L = math.hypot(ex, ez)
        t = max(0.0, min(1.0, ((x - ax) * ex + (z - az) * ez) / (L * L)))
        d = math.hypot(x - ax - t * ex, z - az - t * ez)
        if d < best:
            best, bt = d, (run + t * L) / total
        run += L
    return best, bt


_ROAD_Y0 = None


def wall_rib(x, south):
    """Along each fjord wall: 1 on a buttress crest, 0 in a gully between."""
    return 1.0 - abs(2.0 * vnoise(x * 0.045 + (0.0 if south else 17.0), 0.3, 120) - 1.0)


# gullies on the north wall that carry a fall into the fjord (THAW running,
# RIME frozen); gen_kettle hangs the water down them
FALLS_X = [-118.0, -64.0, -6.0]


def fjord_wall(x, z, wd, south):
    """The fjord's walls: sheer buttresses, gullies recessed between them with
    scree fanned at their foot, the rock in ledged beds (turf grows on the
    ledges: the terrain shader greens anything flat enough)."""
    r = wall_rib(x, south)
    for fx in ([] if south else FALLS_X):
        r = min(r, 0.15 + 0.85 * smooth(2.0, 7.0, abs(x - fx)))
    recess = 4.5 * (1.0 - r) ** 2                     # gullies cut back into the wall
    wd2 = max(0.0, wd - recess)
    steep = 2.6 * (0.65 + 0.75 * r)                   # buttresses sheer, gullies broken
    wall = SHELF_Y + 0.5 + max(0.0, S.strata(wd2 * steep, x, z, 95))
    # a scree fan spilling out of each gully's foot
    fan = (1.0 - r) ** 2 * max(0.0, 1.0 - wd2 / 5.0) * (1.6 + 0.8 * fbm(x * 0.3, z * 0.3, 1, 121))
    return wall + fan * smooth(0.0, 1.5, wd)


def shelf_width(x):
    """How far the shingle shelf runs out from the south wall (to the waterline)."""
    return 12.0 + 2.0 * fbm(x * 0.05, 1.3, 1, 92)


def _kettle_carve(x, z, h):
    global _ROAD_Y0
    fz = fjord_z(x)
    hw = fjord_half(x)
    d = abs(z - fz)
    head = smooth(FJORD_HEAD_X - 10.0, FJORD_HEAD_X + 6.0, x)     # the fjord's inland end
    hw *= 1.0 - head
    if d < hw + 60:
        south = z > fz
        if d < hw and hw > 2.0:
            # water: deep in the middle, shoaling to the walls
            floor = -14.0 * (1.0 - smooth(hw * 0.4, hw, d))
            if south:
                sp = 0.0
                for spx, spw in SHELF_SPURS:
                    sp = max(sp, 1.0 - smooth(spw * 0.4, spw, abs(x - spx)))
                shelf_w = shelf_width(x)
                if d > hw - shelf_w and sp < 0.4 and x > -128:
                    # a shingle lip shelving down into the water
                    lip = smooth(hw - shelf_w, hw - shelf_w + 5.0, d)
                    floor = max(floor, _lerp(-0.6, SHELF_Y + 0.08 * fbm(x * 0.3, z * 0.3, 1, 93), lip))
                # rock ribs run down from the wall into the water, cutting the shelf
                floor = max(floor, 10.0 * sp - (hw - d) * 2.2)
                floor = _dog_spit(x, d, hw, shelf_w, floor)
                floor = _net_cleft(x, z, floor)
            else:
                floor = _far_landing(x, hw - d, floor)
            h = min(h, floor)
        else:
            h = min(h, fjord_wall(x, z, d - hw, south))
            if south and z > CLEFT_Z[1] and d - hw < 6.0:
                h = max(h, _lerp(min(h, SHELF_Y), SHELF_Y + CLEFT_WALL, cleft_env(x)))   # the landward cheek runs into the wall
            if not south and FAR_LANDING[0] <= x <= FAR_LANDING[1] and d - hw <= FAR_LANDING_RECESS:
                h = min(h, _shingle(x, z))       # the landing's back, cut into the wall foot
    # the Kettle Road: down through a cleft in the wall to the shelf
    rd, rt = _road_t(x, z)
    if rd < 14:
        if _ROAD_Y0 is None:
            _ROAD_Y0 = height_no_road(KETTLE_ROAD[0][0], KETTLE_ROAD[0][1])
        ry = _lerp(_ROAD_Y0, KETTLE_ROAD_END_Y, smooth(0.0, 1.0, rt) * 0.3 + rt * 0.7)
        cut = ry + max(0.0, S.strata(max(0.0, rd - 2.4) * 2.2, x, z, 97))
        h = min(h, cut) if rt > 0.02 else h
        if rd < 2.4:
            h = ry + 0.1 * fbm(x * 0.4, z * 0.4, 1, 98)
        h = _road_bay(x, z, h)
    return h


def _shingle(x, z):
    return SHELF_Y + 0.08 * fbm(x * 0.3, z * 0.3, 1, 93)


def _spit(x, z, ex, ez, floor):
    """Level shingle that shelves into the water over SPIT_LIP metres; ex, ez
    are how far (x, z) lies outside the spit's level ground."""
    e = math.hypot(ex, ez)
    if e >= SPIT_LIP:
        return floor
    return max(floor, _lerp(_shingle(x, z), -0.6, smooth(0.0, SPIT_LIP, e)))


def dog_spit_lip(x):
    """How far north of the shelf's own waterline the Dog Lines' level ground
    reaches at x (0 off the spit)."""
    x0, x1, out = DOG_SPIT
    return out - 5.0 if x0 <= x <= x1 else 0.0


def _dog_spit(x, d, hw, shelf_w, floor):
    x0, x1, out = DOG_SPIT
    if x < x0 - SPIT_LIP or x > x1 + SPIT_LIP:
        return floor
    flat_to = hw - shelf_w + 5.0 - out          # (the shelf is level from 5 m inside its waterline)
    return _spit(x, fjord_z(x) + d, max(0.0, x0 - x, x - x1), max(0.0, flat_to - d), floor)


def _far_landing(x, from_wall, floor):
    x0, x1 = FAR_LANDING
    if x < x0 - SPIT_LIP or x > x1 + SPIT_LIP:
        return floor
    return _spit(x, fjord_z(x) - fjord_half(x) + from_wall, max(0.0, x0 - x, x - x1),
                 max(0.0, from_wall - FAR_LANDING_OUT), floor)


def cleft_env(x):
    """1 where the Net-Cleft's rock stands at full height, 0 clear of it."""
    spx, _spw = SHELF_SPURS[CLEFT_SPUR]
    return 1.0 - smooth(3.6, 5.2, abs(x - spx))


def _net_cleft(x, z, floor):
    env = cleft_env(x)
    if env <= 0.0:
        return floor
    z0, z1 = CLEFT_Z
    if z0 - 0.01 <= z <= z1 + 0.01:
        return _shingle(x, z)                    # the way through, at shelf height
    # the rock grows out of whatever lies there (shelf, lip or water), so its
    # ends do not leave a step across the shelf's own lip
    top = _lerp(min(floor, SHELF_Y), SHELF_Y + CLEFT_WALL, env)
    if z > z1:
        return max(floor, top)                   # solid to the wall: no pocket behind the cleft
    return max(floor, top - max(0.0, (z0 - CLEFT_CHEEK) - z) * 7.0)   # sheer into the water: no ledge round it


def road_bay():
    """The Turn in the Road: (centre x, centre z, along (x, z), out (x, z), y)."""
    global _ROAD_Y0
    i = ROAD_BAY_AT
    (ax, az), (bx, bz), (cx, cz) = KETTLE_ROAD[i - 1], KETTLE_ROAD[i], KETTLE_ROAD[i + 1]
    d1 = (bx - ax, bz - az)
    d2 = (cx - bx, cz - bz)
    n1, n2 = math.hypot(*d1), math.hypot(*d2)
    d1, d2 = (d1[0] / n1, d1[1] / n1), (d2[0] / n2, d2[1] / n2)
    out = (d1[0] - d2[0], d1[1] - d2[1])          # away from the inside of the bend
    no = math.hypot(*out)
    out = (out[0] / no, out[1] / no)
    along = (-out[1], out[0])
    if _ROAD_Y0 is None:
        _ROAD_Y0 = height_no_road(KETTLE_ROAD[0][0], KETTLE_ROAD[0][1])
    _rd, rt = _road_t(bx, bz)
    y = _lerp(_ROAD_Y0, KETTLE_ROAD_END_Y, smooth(0.0, 1.0, rt) * 0.3 + rt * 0.7)
    mid = ROAD_HALF + ROAD_BAY[1] * 0.5
    return bx + out[0] * mid, bz + out[1] * mid, along, out, y


_BAY = None


def _road_bay(x, z, h):
    global _BAY
    if _BAY is None:
        _BAY = road_bay()
    cx, cz, along, out, y = _BAY
    u = (x - cx) * along[0] + (z - cz) * along[1]
    v = (x - cx) * out[0] + (z - cz) * out[1]
    hu, hv = ROAD_BAY[0] * 0.5, ROAD_BAY[1] * 0.5
    if abs(u) > hu + 1.0 or v > hv + 1.0 or v < -hv - 1.5:
        return h
    # level over the bay, eased into the road's own fall along its mouth
    w = (1.0 - smooth(hu, hu + 1.0, abs(u))) * (1.0 - smooth(hv, hv + 1.0, v)) * smooth(-hv - 1.5, -hv + 0.5, v)
    return _lerp(h, y + 0.06 * fbm(x * 0.4, z * 0.4, 1, 98), w)


def height_no_road(x, z):
    """The moor height where the Kettle Road leaves it (no carving)."""
    global _ROAD_Y0
    saved = _ROAD_Y0
    _ROAD_Y0 = 0.0
    h = S.height(x, z)
    _ROAD_Y0 = saved
    return h + 1.8 * fbm(x * 0.025, z * 0.025, 3, 80) + 0.4 * fbm(x * 0.12, z * 0.12, 2, 79)


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
    import terrain_patch                  # ramps out of terrain traps (tools/fix_traps.py)
    terrain_patch.apply("lowe_barrows", hs, X0, Z0, NX, NZ)
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
        # heather moor: rust and brown under the green
        "palette": {"turf_a": [0.20, 0.17, 0.08], "turf_b": [0.30, 0.20, 0.10], "path_col": [0.36, 0.30, 0.22]},
    }


if __name__ == "__main__":
    write()
