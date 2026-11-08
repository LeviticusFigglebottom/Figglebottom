"""Thornwold's landform (WORLD.md 5.5), carved into the north country's
heightmap after the tarn (terrain_lowe.height calls thorn_land), so Tarnhall
and Thornwold agree on the ground they share.

The drove-road leaves the tarn's east shore through a notch in the basin
wall and climbs gently into old birch and pine: a broad forest floor with
the Collier's Clearing on the road and, at its far end, the Hedge: rings of
laid hedge round the grave under the oldest pine. Fells rise round the wood;
dense thicket holds its edges.
"""
import math

import terrain_saltfell as S
from terrain_saltfell import fbm, smooth, _lerp

# the drove-road: (x, z, height) through the notch, then (x, z) across the wood
NOTCH = [(254.0, -326.0, 24.2), (266.0, -324.5, 24.7), (280.0, -323.0, 29.2), (296.0, -321.5, 33.6), (312.0, -320.0, 35.0)]
DROVE = [(312.0, -320.0), (330.0, -317.0), (346.0, -313.0), (366.0, -316.0), (388.0, -321.0), (410.0, -324.0), (424.0, -325.0)]
ROAD_HALF = 2.6
WOOD = (300.0, -390.0, 486.0, -276.0)       # the walkable wood (x0, z0, x1, z1), rounded
WOOD_R = 22.0
CLEARING = (346.0, -306.0, 17.0)
GRAVE = (452.0, -325.0)
RINGS = [12.0, 19.0, 26.0]                   # the laid hedges round the grave


def _seg(px, pz, ax, az, bx, bz):
    ex, ez = bx - ax, bz - az
    L2 = ex * ex + ez * ez
    t = max(0.0, min(1.0, ((px - ax) * ex + (pz - az) * ez) / L2))
    return math.hypot(px - ax - t * ex, pz - az - t * ez), t


def notch_road(x, z):
    """(distance to the notch road, its height there)."""
    best = (1e9, 0.0)
    for i in range(len(NOTCH) - 1):
        ax, az, ay = NOTCH[i]
        bx, bz, by = NOTCH[i + 1]
        d, t = _seg(x, z, ax, az, bx, bz)
        if d < best[0]:
            best = (d, _lerp(ay, by, t))
    return best


def drove_d(x, z):
    """Distance to the drove-road across the wood."""
    best = 1e9
    for i in range(len(DROVE) - 1):
        d, _ = _seg(x, z, *DROVE[i], *DROVE[i + 1])
        best = min(best, d)
    return best


def wood_out(x, z):
    """How far outside the walkable wood (<= 0 inside), rounded corners."""
    x0, z0, x1, z1 = WOOD
    cx = min(max(x, x0 + WOOD_R), x1 - WOOD_R)
    cz = min(max(z, z0 + WOOD_R), z1 - WOOD_R)
    return math.hypot(x - cx, z - cz) - WOOD_R


def floor_y(x, z):
    """The forest floor: gently rolling, a little hollow at the clearing."""
    y = 35.0 + 3.2 * fbm(x * 0.018, z * 0.018, 3, 160) + 0.012 * (x - 312.0)
    cd = math.hypot(x - CLEARING[0], z - CLEARING[1])
    y -= 0.6 * (1.0 - smooth(0.0, CLEARING[2], cd))
    gd = math.hypot(x - GRAVE[0], z - GRAVE[1])
    y = _lerp(y, 35.0 + 0.012 * (GRAVE[0] - 312.0) + 1.0, 1.0 - smooth(RINGS[-1] + 2.0, RINGS[-1] + 10.0, gd))
    return y


def _rise(d, x, z, seed):
    if d <= 0.0:
        return 0.0
    return max(0.0, S.strata(d, x, z, seed) - S.strata(0.0, x, z, seed))


def thorn_land(x, z, h):
    if x < 240.0 or z > -258.0:
        return h
    rd, ry = notch_road(x, z)
    notch = None
    if x < 316.0 and rd < 40.0:
        # the notch: the drove-road out of the tarn basin, walls either side
        notch = ry + 0.08 * fbm(x * 0.4, z * 0.4, 1, 161) + _rise((rd - ROAD_HALF - 1.0) * 1.7, x, z, 162)
        h = _lerp(h, min(h, notch), smooth(244.0, 256.0, x))
    if x >= 286.0:
        # the wood: forest floor inside, the fells rising beyond its edge
        fl = floor_y(x, z)
        fell = max(h, fl + 30.0 + 20.0 * fbm(x * 0.01, z * 0.01, 2, 163))
        land = min(fell, fl + _rise(wood_out(x, z) * 2.4, x, z, 164))
        if notch is not None:
            land = min(land, notch)
        h = _lerp(h, land, smooth(286.0, 302.0, x))
    return h
