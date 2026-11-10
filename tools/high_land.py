"""The high country (WORLD.md 5.6, 5.7), carved into the north country's
heightmap after the wood (terrain_lowe.height calls high_land), so Thornwold,
Shepherd's Reach and the Coldwell agree on the ground they share.

Shepherd's Reach: a fell path climbs out of Thornwold's east side to a broad
high pasture under the glacier. A beck from the ice cuts the pasture in two:
the sheilings on its south side, the High Fold on a shoulder north of it.

The Coldwell: from the Reach's north-east corner the Upwater climbs a long
shoulder of the mountain beside the frozen river, up through ice-falls, to the
wellhead stones under the glacier's lip. The land falls away west the whole
way: every region lies below it.
"""
import math

import terrain_saltfell as S
from terrain_saltfell import fbm, smooth, _lerp

# --- Shepherd's Reach ----------------------------------------------------------
REACH_PATH = [(476.0, -331.0, 38.4), (494.0, -331.5, 41.2), (512.0, -329.0, 47.0), (530.0, -326.0, 54.0),
              (548.0, -322.0, 60.4), (566.0, -318.0, 64.6)]
PASTURE = (556.0, -398.0, 704.0, -270.0)     # the walkable pasture (rounded)
PASTURE_R = 26.0
# the fells' flanks round the pasture: metres of rise per metre out. At 1.3 the
# bedding eased the north-west flank to a walkable 41-45 degrees, and the fell
# top it led to runs off the north of the grid (ADR 0003: no open edge)
RIM_STEEP = 1.5
SHEILINGS = [(600.0, -296.0, 12.0), (618.0, -287.0, -8.0), (586.0, -284.0, 20.0)]
HIGH_FOLD = (660.0, -372.0)
FOLD_R = 13.0
BRIDGE_X = 618.0
BECK_HALF = 2.4
BECK_DEPTH = 2.6


def beck_z(x):
    return -334.0 + 7.0 * math.sin(x * 0.03 + 0.6)


# --- the Coldwell ---------------------------------------------------------------
UPWATER = [(686.0, -382.0, 75.0), (712.0, -392.0, 82.0), (738.0, -402.0, 90.0), (764.0, -418.0, 100.0),
           (788.0, -438.0, 110.0), (810.0, -456.0, 120.0), (834.0, -468.0, 131.0), (860.0, -474.0, 142.0),
           (884.0, -476.0, 151.0), (902.0, -477.0, 156.0)]
WELLHEAD = (922.0, -478.0)
RING_R = 10.0
WELL_Y = 157.0
RIVER_OFF = 7.5            # the frozen river runs this far out from the path, on the downhill side
PATH_HALF = 3.0


def _seg(px, pz, ax, az, bx, bz):
    ex, ez = bx - ax, bz - az
    L2 = ex * ex + ez * ez
    t = max(0.0, min(1.0, ((px - ax) * ex + (pz - az) * ez) / L2))
    return math.hypot(px - ax - t * ex, pz - az - t * ez), t


def poly_road(pts, x, z):
    """(distance, height, side: +1 north (z smaller) / -1 south) to a polyline road."""
    best = (1e9, 0.0, 1.0)
    for i in range(len(pts) - 1):
        ax, az, ay = pts[i]
        bx, bz, by = pts[i + 1]
        d, t = _seg(x, z, ax, az, bx, bz)
        if d < best[0]:
            side = (bx - ax) * (z - az) - (bz - az) * (x - ax)
            best = (d, _lerp(ay, by, t), -1.0 if side > 0 else 1.0)
    return best


def _rise(d, x, z, seed):
    if d <= 0.0:
        return 0.0
    return max(0.0, S.strata(d, x, z, seed) - S.strata(0.0, x, z, seed))


def pasture_out(x, z):
    x0, z0, x1, z1 = PASTURE
    cx = min(max(x, x0 + PASTURE_R), x1 - PASTURE_R)
    cz = min(max(z, z0 + PASTURE_R), z1 - PASTURE_R)
    return math.hypot(x - cx, z - cz) - PASTURE_R


def pasture_y(x, z):
    """The high grass: rising gently east toward the ice, a shoulder for the High Fold."""
    y = 64.5 + 0.075 * (x - 566.0) + 2.5 * fbm(x * 0.02, z * 0.02, 3, 180)
    fd = math.hypot(x - HIGH_FOLD[0], z - HIGH_FOLD[1])
    y += 4.0 * (1.0 - smooth(FOLD_R + 2.0, FOLD_R + 22.0, fd))          # the fold's shoulder
    y = _lerp(y, 64.5 + 0.075 * (HIGH_FOLD[0] - 566.0) + 5.2, 1.0 - smooth(FOLD_R + 1.0, FOLD_R + 5.0, fd))
    return y


def reach_land(x, z, h):
    if x < 470.0 or x > 720.0 or z > -200.0:
        return h
    h0 = h
    rd, ry, _ = poly_road(REACH_PATH, x, z)
    path = None
    if x < 572.0 and rd < 40.0:
        path = ry + 0.08 * fbm(x * 0.4, z * 0.4, 1, 181) + _rise((rd - PATH_HALF - 0.8) * 1.6, x, z, 182)
        # a cutting: banks rise either side whatever the fell does beyond
        cut = path if rd < 22.0 else _lerp(path, min(h, path), smooth(22.0, 34.0, rd))
        h = _lerp(h, cut, smooth(483.0, 490.0, x))
    if x >= 486.0:
        fl = pasture_y(x, z)
        # round green fells either side (the concept: a valley, not a gorge)
        fell = max(min(h, fl + 34.0), fl + 22.0 + 14.0 * fbm(x * 0.01, z * 0.01, 2, 183))
        land = min(fell, fl + _rise(pasture_out(x, z) * RIM_STEEP, x, z, 184))
        # the beck from the ice: a deep cut across the pasture
        bd = abs(z - beck_z(x))
        if bd < BECK_HALF + 2.5 and pasture_out(x, z) < 6.0:
            bed = fl - BECK_DEPTH
            land = min(land, _lerp(bed, land, smooth(BECK_HALF, BECK_HALF + 2.5, bd)))
        if path is not None:
            land = min(land, path)
        h = _lerp(h, land, smooth(486.0, 500.0, x))
    # the fells fall away south to the low country (no sheer edge)
    return _lerp(h, h0, smooth(-250.0, -205.0, z))


def cold_land(x, z, h):
    """The Upwater runs along the crest of the mountain's west shoulder: the
    frozen river on its north side, and beyond the river the land drops
    away to the valleys below (the way back over every region); the
    mountain rises in walls on its south side; the wellhead sits on a level
    of turf at the top, the glacier's lip rising behind it."""
    if x < 676.0 or z > -330.0:
        return h
    rd, ry, side = poly_road(UPWATER, x, z)
    low = 52.0 + 0.16 * max(0.0, x - 690.0) + 6.0 * fbm(x * 0.01, z * 0.01, 2, 196)     # the valleys below
    if side < 0:
        # the downhill side (toward the regions below): the river bed, then the drop
        land = ry + 0.1 * fbm(x * 0.4, z * 0.4, 1, 192)
        land = _lerp(land, ry - 1.2, smooth(PATH_HALF, PATH_HALF + 1.5, rd))
        if rd > RIVER_OFF + 2.5:
            land = max(low, ry - 1.2 - (rd - RIVER_OFF - 2.5) * 1.6 - 0.02 * (rd - RIVER_OFF) ** 2)
    else:
        # south: the mountain in ledged walls
        land = ry + 0.1 * fbm(x * 0.4, z * 0.4, 1, 192) + _rise((rd - PATH_HALF - 0.8) * 1.5, x, z, 194)
        # ledges up to the snowline, then the mountain's rounded shoulder
        cap = ry + 26.0 + 0.35 * max(0.0, rd - 40.0) + 8.0 * fbm(x * 0.012, z * 0.012, 2, 197)
        land = min(land, cap)
    # the wellhead: a level of turf round the spring, the glacier's lip behind
    wd = math.hypot(x - WELLHEAD[0], z - WELLHEAD[1])
    if wd < 34.0:
        flat = WELL_Y + 0.15 * fbm(x * 0.3, z * 0.3, 1, 195)
        land = _lerp(flat, land, smooth(RING_R + 9.0, 30.0, wd))
    if x > WELLHEAD[0] + 14.0 or (wd > 22.0 and x > WELLHEAD[0] - 6.0):
        lip = _rise((max(x - WELLHEAD[0] - 14.0, wd - 22.0)) * 1.8, x, z, 191)
        lip = min(lip, 34.0 + 0.25 * max(0.0, wd - 40.0) + 6.0 * fbm(x * 0.02, z * 0.02, 2, 198))
        # (the lip is the wellhead's backdrop, not a wall across the country)
        land = max(land, _lerp(land, WELL_Y + lip, 1.0 - smooth(50.0, 85.0, wd)))
    k = smooth(678.0, 700.0, x)
    po = pasture_out(x, z)
    if po < 10.0 and rd > PATH_HALF + 6.0:
        k *= smooth(-2.0, 10.0, po)          # the pasture stays the pasture
    return _lerp(h, land, k)


def high_land(x, z, h):
    h = reach_land(x, z, h)
    h = cold_land(x, z, h)
    return h
