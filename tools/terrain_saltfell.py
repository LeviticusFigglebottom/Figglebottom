#!/usr/bin/env python3
"""The Saltfell landform: one continuous sea-cliff landscape (ADR 0003, 0005).

Pure Python (no numpy). Importable: gen_steading.py places everything on it,
audit_edges.py / audit_areas.py sample it. Run directly to (re)write the
committed heightmap + splat:

    python3 tools/terrain_saltfell.py

Axes: +x east, +z south (toward the sea), +y up; sea level y = 0.

  south  the sea, a sea stack off the Strand, a tidal channel to it
         the Strand: a shingle cove between two headlands
         the cliff: sheer, ~19 m; a switchback path cut into its west part,
         and a gully down to the boat-shed's back door in its east part
  middle the turf shelf at ~22 m: Saltfell yard, the Longhouse at its north
  north  a ravine (lethal) and beyond it the Lowe barrow hills (vista only)
  east   a scree fell too steep to climb
"""
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "data", "terrain")

# fine playable grid (1 m) and the coarse horizon ring (8 m)
X0, Z0, CELL, NX, NZ = -128.0, -176.0, 1.0, 257, 321
FAR_X0, FAR_Z0, FAR_CELL, FAR_N = -1024.0, -1024.0, 8.0, 257
SEED = 7331

SHELF_Y = 22.0
CLIFF_K = 2.2            # cliff face slope (rise per metre): ~66 degrees
BEACH_FOOT = 3.2

# the plateau outline (x, z), clockwise from the north-west. The notch at
# x -68..-8 is the terraced switchback face (see _terrace).
PLATEAU = [
    (-260, -400), (-96, -220), (-100, -60), (-97, 30), (-91, 70), (-87, 100),
    (-77, 106), (-73, 82), (-70, 52), (-69, 46),
    (-68, 31), (-8, 31),
    (-7, 44), (6, 44.5), (16, 42.5), (25, 40.0), (34, 41.5), (44, 44), (51, 47),
    (55, 70), (57, 96), (68, 101), (82, 82), (100, 40), (120, -40),
    (260, -400),
]

# building pads (flattened): name -> (cx, cz, half_x, half_z, yaw_deg, y, margin)
PADS = {
    "yard": (-5.0, 0.0, 36.0, 24.0, 0.0, SHELF_Y, 6.0),
    "longhouse": (0.0, -36.0, 8.5, 18.0, 0.0, SHELF_Y, 4.0),
    "byre": (-27.0, -14.0, 7.0, 8.0, -9.0, SHELF_Y, 3.0),
    "store": (22.0, -14.0, 6.0, 6.0, 13.0, SHELF_Y, 3.0),
    "boatshed": (25.0, 54.0, 6.4, 6.6, 0.0, BEACH_FOOT, 0.0),
}

# the gully: a cleft from the yard down to the boat-shed back door
GULLY_X, GULLY_Z0, GULLY_Z1 = 25.0, 8.0, 47.6
GULLY_HALF = 2.3

# the sea stack and its tide shelf; the tidal channel runs to it
STACK = (-30.0, 113.0)
CHANNEL = {"x0": -33.0, "x1": -27.0, "z0": 76.0, "z1": 104.5, "y": 0.06}

# ravine (lethal) between the shelf and the barrow hills
def ravine_z(x):
    """The ravine meanders: two bends and a wander, kept clear of the Longhouse."""
    return -78.0 + 6.0 * math.sin(x * 0.03 + 0.5) + 3.0 * math.sin(x * 0.09 + 1.0) + 2.0 * fbm(x * 0.02, 3.3, 2, 31)


def ravine_floor_half(x):
    """Half-width of the ravine floor: pinches to a slot, opens to a pool."""
    return 2.6 + 1.8 * (0.5 + 0.5 * math.sin(x * 0.05 + 2.0)) + 0.8 * fbm(x * 0.07, 1.1, 2, 32)


# rock spurs jutting into the ravine: (x, side +1 south wall / -1 north, reach m)
RAVINE_SPURS = [(-62, 1, 6.0), (-40, -1, 5.0), (-28, -1, 4.5), (-8, -1, 6.0), (-8, 1, 6.0), (14, 1, 7.0),
                (30, 1, 4.0), (38, -1, 5.0), (56, 1, 6.0), (-84, -1, 5.0)]


def gully_x(z):
    """The gully bends twice on its way down, so no slot shows from the beach;
    it straightens only for the last metres to the boat-shed's back door."""
    taper = 1.0 - smooth(38.0, 45.0, z)
    return GULLY_X + taper * (2.6 * math.sin(z * 0.11 + 0.4) + 1.1 * math.sin(z * 0.27))


def strata(depth, x, z, seed=40):
    """Layered rock: turn a smooth fall of `depth` metres into risers and
    ledges. Bed thickness, dip and ledge width change from one stretch of
    coast to the next; in slumps the beds have slid and lost their order."""
    seg = vnoise(x * 0.018, z * 0.018, seed + 3)                 # which stretch of coast
    step = 2.4 + 3.4 * seg + 0.8 * fbm(x * 0.03, z * 0.03, 1, seed)
    dip = 0.08 * (vnoise(x * 0.012, z * 0.012, seed + 4) - 0.5)
    q = (depth + dip * x + 0.9 * fbm(x * 0.05, z * 0.05, 2, seed + 1)) / step
    fq = q - math.floor(q)
    ledge = 0.22 + 0.3 * vnoise(x * 0.04, z * 0.04, seed + 5)     # wider ledges grow turf
    stepped = (math.floor(q) + smooth(ledge, 1.0, fq)) * step
    k = 0.45 + 0.55 * vnoise(x * 0.03, z * 0.03, seed + 2)
    slump = smooth(0.62, 0.8, vnoise(x * 0.025, z * 0.025, seed + 6))
    k *= 1.0 - slump
    return depth + (stepped - depth) * k + slump * 1.2 * fbm(x * 0.2, z * 0.2, 2, seed + 7)


RAVINE_FLOOR = 3.0
RAVINE_HEAD_X = -80.0      # the ravine's west end
BRIDGE_X = -8.0            # the Lowe drawbridge spans here

# round kin-mounds on the Lowe (the long barrows are houses: terrain_lowe.py)
BARROWS = [(-82, -150, 9, 4.5), (14, -110, 9, 4.5), (-30, -162, 10, 5.0),
           (8, -182, 11, 5.0), (-70, -172, 9, 4.0), (36, -120, 8, 4.0)]


# ------------------------------------------------------------------ noise

def _hash(ix, iz, s):
    h = (ix * 374761393 + iz * 668265263 + s * 2147483647) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((h ^ (h >> 16)) & 0xFFFF) / 65535.0


def vnoise(x, z, s=0):
    ix, iz = math.floor(x), math.floor(z)
    fx, fz = x - ix, z - iz
    fx = fx * fx * (3 - 2 * fx)
    fz = fz * fz * (3 - 2 * fz)
    a = _hash(ix, iz, s); b = _hash(ix + 1, iz, s)
    c = _hash(ix, iz + 1, s); d = _hash(ix + 1, iz + 1, s)
    return (a + (b - a) * fx) * (1 - fz) + (c + (d - c) * fx) * fz


def fbm(x, z, octaves=4, s=0):
    amp, f, tot, norm = 1.0, 1.0, 0.0, 0.0
    for o in range(octaves):
        tot += amp * (vnoise(x * f, z * f, s + o * 17) * 2 - 1)
        norm += amp
        amp *= 0.5
        f *= 2.03
    return tot / norm


def smooth(e0, e1, x):
    t = max(0.0, min(1.0, (x - e0) / (e1 - e0)))
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ shapes

def _poly_sdf(x, z, poly):
    """Signed distance to the polygon: + inside, - outside."""
    inside = False
    dmin = 1e18
    n = len(poly)
    for i in range(n):
        ax, az = poly[i]
        bx, bz = poly[(i + 1) % n]
        if (az > z) != (bz > z):
            t = (z - az) / (bz - az)
            if x < ax + t * (bx - ax):
                inside = not inside
        ex, ez = bx - ax, bz - az
        L = ex * ex + ez * ez
        t = 0.0 if L == 0 else max(0.0, min(1.0, ((x - ax) * ex + (z - az) * ez) / L))
        dx, dz = x - (ax + t * ex), z - (az + t * ez)
        dmin = min(dmin, dx * dx + dz * dz)
    d = math.sqrt(dmin)
    return d if inside else -d


def beach_y(x, z):
    """Shingle and sea floor: a function of how far south you are."""
    w = 0.6 * fbm(x * 0.05, z * 0.05, 2, 3)
    # only the cove holds shingle; every other cliff foot is open sea
    cove = smooth(-82, -72, x) * (1 - smooth(54, 62, x))
    if cove <= 0.0:
        return -8.0
    if cove < 1.0:
        return _lerp(-8.0, beach_y_cove(x, z, w), cove)
    return beach_y_cove(x, z, w)


def beach_y_cove(x, z, w):
    z = z + 4.0 * fbm(x * 0.03, 0.5, 2, 16)      # the waterline wanders
    if z < 55:
        return BEACH_FOOT + 0.4
    if z < 80:
        return BEACH_FOOT * (1 - smooth(55, 80, z) ** 0.9) + 0.25 * w
    if z < 86:
        return -1.6 * (z - 80) / 6.0
    return -1.6 - 6.4 * smooth(86, 100, z)


# switchback rows (south -> north): (kind, z_south, z_north)
_ROWS = [("wall0", 54.5, 51.5), ("leg1", 51.5, 48.0), ("wall1", 48.0, 45.0),
         ("leg2", 45.0, 41.5), ("wall2", 41.5, 38.5), ("leg3", 38.5, 35.0),
         ("wall3", 35.0, 31.0)]
TER_X0, TER_X1 = -68.0, -8.0


def _lerp(a, b, t):
    return a + (b - a) * t


def leg_y(leg, x):
    """Path height along each switchback leg (rises ~0.14 m per metre)."""
    if leg == 1:   # low end on the Strand at the east, climbs west
        return _leg1(x)
    if leg == 2:   # climbs east
        return _lerp(10.4, 16.4, (x + 60) / 44.0) if -60 <= x <= -16 else (10.4 if x < -60 else 16.4)
    if leg == 3:   # climbs west to the shelf
        return _lerp(17.4, SHELF_Y, (-16 - x) / 34.0) if -50 <= x <= -16 else (SHELF_Y if x < -50 else 17.4)
    return SHELF_Y


def _leg1(x):
    if x >= -16:
        return BEACH_FOOT
    return _lerp(BEACH_FOOT, 9.4, min(1.0, (-16 - x) / 44.0))


def _terrace(x, z):
    """The switchback face: three legs stacked on a terraced cliff, joined by
    two turning landings. Walls between legs are steep (>45 deg) except near
    the turns, where cutting the corner saves nothing."""
    xw = x + 2.5 * fbm(0.4, z * 0.08, 2, 24)
    if not (TER_X0 <= xw <= TER_X1 and 31.0 <= z <= 54.5):
        return None
    wob = 1.3 * fbm(x * 0.08, 0.0, 2, 9)
    zz = z + wob
    l1, l2, l3 = _leg1(x), leg_y(2, x), leg_y(3, x)
    # turning landings span two legs and the wall between
    if x < -60 and 38.5 <= zz <= 51.5 and zz >= 41.5:
        return _lerp(l1, l2, smooth(51.5, 41.5, zz))     # west turn: leg1 <-> leg2
    if x > -16 and 35.0 <= zz <= 45.0:
        return _lerp(16.4, 17.4, smooth(45.0, 35.0, zz))  # east turn: leg2 <-> leg3
    if zz >= 51.5:
        return _lerp(l1, beach_y(x, 54.5), smooth(51.5, 54.5, zz))
    if zz >= 48.0:
        return l1
    if zz >= 45.0:
        return _lerp(l2, l1, smooth(45.0, 48.0, zz)) if x >= -60 else l1
    if zz >= 41.5:
        return l2
    if zz >= 38.5:
        return _lerp(l3, l2, smooth(38.5, 41.5, zz)) if x <= -16 else l2
    if zz >= 35.0:
        return l3
    return _lerp(SHELF_Y + 0.2, l3, smooth(31.0, 35.0, zz))


def _pad_weight(x, z, pad):
    cx, cz, hx, hz, yaw, y, margin = pad
    a = math.radians(yaw)
    dx, dz = x - cx, z - cz
    lx = dx * math.cos(a) - dz * math.sin(a)
    lz = dx * math.sin(a) + dz * math.cos(a)
    ex = max(0.0, abs(lx) - hx)
    ez = max(0.0, abs(lz) - hz)
    d = math.hypot(ex, ez)
    if margin <= 0:
        return 1.0 if d <= 0 else 0.0
    return 1.0 - smooth(0.0, margin, d)


def height(x, z):
    # plateau top: rolling turf, rising inland to the barrow hills and east
    top = SHELF_Y + 1.4 * fbm(x * 0.018, z * 0.018, 3, 1) + 0.35 * fbm(x * 0.09, z * 0.09, 2, 2)
    if z < -84:
        top += min(26.0, (-84 - z) * 0.22)
        for bx, bz, br, bh in BARROWS:
            r = math.hypot(x - bx, z - bz) / br
            if r < 1.0:
                top += bh * (1 - r * r) ** 1.5
    # the east fell: scree too steep to climb
    fx = x - 62 - 7.0 * fbm(z * 0.03, 0.3, 2, 17) - 4.0 * fbm(z * 0.09, 1.7, 2, 38)
    if fx > 0:
        # broken scree: buttresses and runnels, never less than ~48 degrees
        top += min(34.0 + 6.0 * fbm(x * 0.02, z * 0.02, 2, 18), fx * 1.6) \
            + min(fx, 4.0) * (0.6 * fbm(x * 0.09, z * 0.09, 3, 4) + 0.25 * math.sin(z * 0.45 + 2.0 * fbm(x * 0.1, z * 0.1, 1, 19)))
    # warp the outline so no edge runs straight: bays, buttresses, slumps
    sdf = _poly_sdf(x, z, PLATEAU) + 4.5 * fbm(x * 0.035, z * 0.035, 3, 13) + 1.6 * fbm(x * 0.14, z * 0.14, 2, 14)
    rough = 2.0 * fbm(x * 0.13, z * 0.13, 3, 5)
    k = CLIFF_K * (0.95 + 0.4 * vnoise(x * 0.05, z * 0.05, 15))
    # erosion: buttresses and runnels down the face (ridged noise)
    ridge = 1.0 - abs(2.0 * vnoise(x * 0.09 + z * 0.02, z * 0.09, 33) - 1.0)
    fall = -k * min(sdf - 1.4 * ridge, 0.0)
    cliff = top - strata(fall, x, z) + (rough * 0.6 if sdf < 0 else 0.0)
    h = max(beach_y(x, z), cliff) if sdf < 0 else top
    t = _terrace(x, z)
    if t is not None:
        # legs keep a gentle tread; the walls between them are broken rock
        on_leg = path_weight_terrace(x, z)
        h = t + 0.15 * fbm(x * 0.3, z * 0.3, 2, 6) + (1.0 - on_leg) * (1.0 * fbm(x * 0.35, z * 0.35, 2, 25) + 1.4 * fbm(x * 0.12, z * 0.5, 2, 26))
    # flatten the pads people built on
    for name, pad in PADS.items():
        w = _pad_weight(x, z, pad)
        if w > 0:
            if name == "yard":
                h = _lerp(h, pad[5] + 0.45 * fbm(x * 0.05, z * 0.05, 2, 8), w * 0.85)
            else:
                h = _lerp(h, pad[5], w)
    # the gully down to the boat-shed back door
    if GULLY_Z0 - 4 <= z <= 49.0:
        t = max(0.0, min(1.0, (z - GULLY_Z0) / (GULLY_Z1 - GULLY_Z0)))
        floor = _lerp(SHELF_Y, BEACH_FOOT, t)
        gx = gully_x(z)
        half = GULLY_HALF + 0.5 * fbm(z * 0.15, 0.7, 1, 34)
        wall = floor + strata(max(0.0, abs(x - gx) - half) * 2.8, x, z, 50)
        if z < GULLY_Z0:
            wall += (GULLY_Z0 - z) * 4.0
        h = min(h, wall)
    # the ravine
    rz = ravine_z(x)
    dz = abs(z - rz)
    if dz < 26:
        side = 1 if z > rz else -1
        for sx_, sside, reach in RAVINE_SPURS:
            if sside == side:
                dz += reach * math.exp(-((x - sx_) / 5.0) ** 2)
        # a ragged lip: slumps and bites along the top of each wall
        dz += 2.2 * fbm(x * 0.12, z * 0.12, 2, 36) + 1.2 * fbm(x * 0.35, z * 0.35, 1, 37)
        d = max(0.0, dz - ravine_floor_half(x))
        kw = 2.4 + 1.2 * vnoise(x * 0.04, z * 0.04, 35)
        # a talus apron at the foot, then the layered wall
        talus = min(d, 3.0) * 0.6
        wallh = strata(max(0.0, d - 3.0) * kw, x, z, 60)
        rav = RAVINE_FLOOR + talus + wallh + 0.5 * fbm(x * 0.3, z * 0.3, 2, 7)
        # the ravine heads out short of the west sea cliffs: a strip of cliff
        # top is the road inland to the Lowe
        head = smooth(RAVINE_HEAD_X - 6.0, RAVINE_HEAD_X + 4.0, x)
        if rav < h:
            h = h - (h - rav) * head
    # the sea stack and its tide shelf
    sx, sz = STACK
    r = math.hypot(x - sx, z - sz)
    if r < 18:
        th = math.atan2(z - sz, x - sx)
        lobe = 1.0 + 0.18 * math.sin(3 * th + 0.7) + 0.1 * math.sin(5 * th + 2.1) + 0.12 * fbm(x * 0.3, z * 0.3, 2, 12)
        shelf = 0.8 - 1.1 * smooth(8.0, 12.5, r / (0.9 + 0.2 * lobe)) + 0.15 * fbm(x * 0.4, z * 0.4, 1, 11)
        crown = 15.0 + 4.0 * fbm(x * 0.25, z * 0.25, 2, 27) + 2.0 * math.sin(th * 2 + 1.0)
        fall = (crown + 1.0) * smooth(3.6, 6.4, r / lobe)
        pillar = crown - strata(fall, x, z, 70)
        h = max(h, shelf, pillar)
    return h


def splat(x, z, h):
    """Painted layers (RGBA8): r = shingle, g = worn path, b = wet shore,
    a = turf variation. Rock and snow are derived from slope in the shader."""
    shingle = 0.0
    if h < 5.0 and z > 50:
        shingle = 1.0 - smooth(4.0, 5.5, h)
    if math.hypot(x - STACK[0], z - STACK[1]) < 13:
        shingle = max(shingle, 0.6)
    wet = 1.0 - smooth(-0.2, 0.6, h) if z > 70 else 0.0
    path = path_weight(x, z)
    var = 0.5 + 0.5 * fbm(x * 0.07, z * 0.07, 2, 21)
    return (shingle, path, wet, var)


# worn paths painted into the splat: polylines (x, z), width
PATHS = [
    ([(-14, 56), (-26, 60), (-10, 70), (8, 66), (22, 63), (25, 58)], 2.2),   # strand: foot of the path -> boat-shed
    ([(-48, 33), (-38, 26), (-24, 18), (-8, 10), (0, 2), (2, -10), (0, -19)], 2.4),  # path top -> yard -> longhouse door
    ([(2, -6), (14, -8), (17, -12)], 1.6),     # to the store-house
    ([(-8, -4), (-18, -10), (-21, -13)], 1.6),  # to the byre
    ([(4, 6), (16, 6), (24, 8), (25, 12)], 1.8),  # yard -> gully head
    ([(-24, 18), (-30, 26)], 1.6),             # to the salt-house hearth
]


def _seg_dist(px, pz, ax, az, bx, bz):
    ex, ez = bx - ax, bz - az
    L = ex * ex + ez * ez
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((px - ax) * ex + (pz - az) * ez) / L))
    return math.hypot(px - (ax + t * ex), pz - (az + t * ez))


def path_weight_terrace(x, z):
    """1 on a switchback leg's tread, 0 on the walls between."""
    for (kind, zs, zn) in _ROWS:
        if kind.startswith("leg") and zn + 0.3 <= z <= zs - 0.3:
            return 1.0
    if x < -60 or x > -16:     # the turning landings
        return 1.0 if 35.0 <= z <= 51.5 else 0.0
    return 0.0


def path_weight(x, z):
    best = 0.0
    for pts, w in PATHS:
        for i in range(len(pts) - 1):
            d = _seg_dist(x, z, *pts[i], *pts[i + 1])
            if d < w + 1.5:
                best = max(best, 1.0 - smooth(w * 0.4, w + 1.0, d + 0.6 * fbm(x * 0.4, z * 0.4, 1, 30)))
    # the switchback legs are the path itself
    if _terrace(x, z) is not None:
        for (kind, zs, zn) in _ROWS:
            if kind.startswith("leg") and zn + 0.7 <= z <= zs - 0.7:
                best = max(best, 0.85)
    if GULLY_Z0 <= z <= GULLY_Z1 and abs(x - gully_x(z)) < 1.2:
        best = max(best, 0.8)
    return best


# ------------------------------------------------------------------ I/O

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
            s = splat(x, z, h)
            sp += bytes(int(max(0, min(1, c)) * 255 + 0.5) for c in s)
    with open(os.path.join(OUT_DIR, "saltfell_h.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(hs), *hs))
    with open(os.path.join(OUT_DIR, "saltfell_splat.bin"), "wb") as f:
        f.write(bytes(sp))
    # the horizon: the same landform, coarse, sunk under the fine grid
    far = []
    for j in range(FAR_N):
        z = FAR_Z0 + j * FAR_CELL
        for i in range(FAR_N):
            x = FAR_X0 + i * FAR_CELL
            inner = X0 + 8 <= x <= X0 + (NX - 1) * CELL - 8 and Z0 + 8 <= z <= Z0 + (NZ - 1) * CELL - 8
            # beyond the play grid the hills keep rising into fells
            h = height(x, z)
            if z < -180:
                h += min(40.0, (-180 - z) * 0.08) + 14.0 * fbm(x * 0.004, z * 0.004, 3, 40) * smooth(-180, -260, z)
            far.append(h - (4.0 if inner else 0.0))
    with open(os.path.join(OUT_DIR, "saltfell_far.bin"), "wb") as f:
        f.write(struct.pack("<%df" % len(far), *far))
    print("terrain: %dx%d fine, %dx%d far -> %s" % (NX, NZ, FAR_N, FAR_N, OUT_DIR))


_cache = None


def load_grid():
    """The committed heightmap, as written (so audits read what ships)."""
    global _cache
    if _cache is None:
        with open(os.path.join(OUT_DIR, "saltfell_h.bin"), "rb") as f:
            data = f.read()
        _cache = list(struct.unpack("<%df" % (len(data) // 4), data))
    return _cache


def sample(x, z):
    """Bilinear height of the committed grid at (x, z) — matches the collider."""
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
        "source": "res://data/terrain/saltfell_h.bin",
        "splat": "res://data/terrain/saltfell_splat.bin",
        "far": "res://data/terrain/saltfell_far.bin",
        "origin": [X0, Z0], "cell": CELL, "size": [NX, NZ],
        "far_origin": [FAR_X0, FAR_Z0], "far_cell": FAR_CELL, "far_size": FAR_N,
        "chunk": 32, "generator": "tools/terrain_saltfell.py", "seed": SEED,
    }


if __name__ == "__main__":
    write()
