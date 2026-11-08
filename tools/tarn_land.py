"""Tarnhall's landform (WORLD.md 5.4), carved into the north country's
heightmap (terrain_lowe.height calls tarn_land for the ground east of Kettle
Fjord), so the Lowe, Kettle Fjord and Tarnhall all agree on the land they
share.

The fjord's valley runs on east above its head: a gorge climbs from the
shelf at the fjord head (the Tarn Steps), beside the stream that falls out of
the tarn into the fjord, to a mountain tarn in a basin of fells. The great
hall stands on an island in the tarn, reached by a stone causeway with a
plank bridge over its channel (the Tarn Causeway); the byres stand at the
hall's east end.
"""
import math

import terrain_saltfell as S
from terrain_saltfell import fbm, smooth, _lerp

# the Tarn Steps: (x, z, road height). From the Kettle shelf to the tarn shore.
STEPS = [(29.0, -295.5, 1.9), (43.0, -299.5, 3.4), (58.0, -305.5, 7.0), (73.0, -313.5, 11.6),
         (89.0, -322.0, 16.4), (105.0, -330.0, 20.8), (119.0, -334.0, 23.4), (131.0, -334.5, 24.1)]
ROAD_HALF = 2.8
STREAM_OFF = 6.0          # the stream runs this far north of the road
TARN_C = (194.0, -326.0)
TARN_R = (58.0, 36.0)
TARN_Y = 22.0              # water level
ISLAND_C = (205.0, -330.0)
ISLAND_R = (36.0, 18.0)
ISLAND_Y = 24.3
SHORE_Y = 24.1
CAUSEWAY = [(131.0, -334.5), (171.5, -331.0)]   # shore to island
CAUSEWAY_HALF = 2.6
CAUSEWAY_Y = 24.2
CHANNEL = (150.0, 155.5)  # x span of the gap the plank bridge crosses


def _seg(px, pz, ax, az, bx, bz):
    ex, ez = bx - ax, bz - az
    L2 = ex * ex + ez * ez
    t = max(0.0, min(1.0, ((px - ax) * ex + (pz - az) * ez) / L2))
    return math.hypot(px - ax - t * ex, pz - az - t * ez), t


def _rise(d, x, z, seed):
    """Ledged rock rising d metres out from where a wall starts (0 at d <= 0)."""
    if d <= 0.0:
        return 0.0
    return max(0.0, S.strata(d, x, z, seed) - S.strata(0.0, x, z, seed))


def road(x, z):
    """(distance to the Tarn Steps, road height there, signed side: + north)."""
    best = (1e9, 0.0, 0.0)
    for i in range(len(STEPS) - 1):
        ax, az, ay = STEPS[i]
        bx, bz, by = STEPS[i + 1]
        d, t = _seg(x, z, ax, az, bx, bz)
        if d < best[0]:
            # which side: cross product of the leg with the offset
            side = (bx - ax) * (z - az) - (bz - az) * (x - ax)
            best = (d, _lerp(ay, by, t), -1.0 if side > 0 else 1.0)
    return best


def tarn_e(x, z):
    """Elliptic radius in the tarn (1 at the shore), the shore wandering."""
    a = math.atan2(z - TARN_C[1], x - TARN_C[0])
    wob = 1.0 + 0.10 * math.sin(3.0 * a + 0.7) + 0.06 * math.sin(7.0 * a + 2.1)
    return math.hypot((x - TARN_C[0]) / TARN_R[0], (z - TARN_C[1]) / TARN_R[1]) / wob


def island_e(x, z):
    return math.hypot((x - ISLAND_C[0]) / ISLAND_R[0], (z - ISLAND_C[1]) / ISLAND_R[1])


def causeway_d(x, z):
    (ax, az), (bx, bz) = CAUSEWAY
    return _seg(x, z, ax, az, bx, bz)


def tarn_land(x, z, h):
    """Carve the gorge and the tarn basin into the fells (h is the fell)."""
    if x < 26.0 or z > -268.0:
        return h
    w_in = smooth(26.0, 34.0, x) * smooth(-268.0, -284.0, z)
    fell = max(h, 44.0 + 22.0 * fbm(x * 0.012, z * 0.012, 3, 140))
    rd, ry, side = road(x, z)
    # the gorge: road, the stream beside it, sheer broken walls
    g = ry + 0.1 * fbm(x * 0.4, z * 0.4, 1, 141)
    if side > 0:
        # north of the road: down to the stream bed, then the wall
        sd = abs(rd - STREAM_OFF)
        bed = ry - 1.4 + 0.6 * smooth(0.0, 1.6, sd)
        g = _lerp(g, bed, smooth(ROAD_HALF, ROAD_HALF + 1.2, rd)) if rd < STREAM_OFF else bed
        wall_from = STREAM_OFF + 1.8
    else:
        wall_from = ROAD_HALF + 0.6
    g += _rise((rd - wall_from) * 2.4, x, z, 142)
    gorge = min(fell, g)
    # the tarn basin: shore flats, the water, the island, the causeway
    e = tarn_e(x, z)
    basin = SHORE_Y + 0.1 * fbm(x * 0.2, z * 0.2, 1, 143) + max(0.0, e - 1.04) ** 1.6 * 30.0
    if e < 1.0:
        basin = _lerp(TARN_Y - 7.0, SHORE_Y, smooth(0.72, 1.02, e))
        ie = island_e(x, z)
        if ie < 1.25:
            basin = max(basin, _lerp(TARN_Y - 1.0, ISLAND_Y, smooth(1.25, 0.95, ie)))
        cd, ct = causeway_d(x, z)
        if cd < CAUSEWAY_HALF + 1.5 and not (CHANNEL[0] - 1.0 < x < CHANNEL[1] + 1.0):
            basin = max(basin, _lerp(TARN_Y - 1.0, CAUSEWAY_Y, smooth(CAUSEWAY_HALF + 1.5, CAUSEWAY_HALF, cd)))
    basin = min(fell, basin + _rise((e - 1.12) * 70.0, x, z, 144))
    if rd < 14.0 and x < 140.0:
        # the Tarn Steps top out onto the shore: no basin wall across the road
        basin = min(basin, _lerp(max(ry, SHORE_Y - 0.1) if x > 125 else ry, basin, smooth(4.0, 14.0, rd)))
    # gorge below, basin above: the gorge opens out as the road tops out
    k = smooth(112.0, 132.0, x)
    land = _lerp(gorge, min(gorge if rd < 14 else fell, basin) if k < 1.0 else basin, k)
    if k >= 1.0:
        land = basin
    elif rd < 14:
        land = _lerp(gorge, basin, k)
    return _lerp(h, land, w_in)


def stream(height_fn, step=1.5):
    """The tarn's outflow: down the gorge north of the Tarn Steps and over
    the lip into the fjord head. Points (top first) for an area's "falls"."""
    pts = []
    for i in range(len(STEPS) - 1, 0, -1):
        bx, bz, _ = STEPS[i]
        ax, az, _ = STEPS[i - 1]
        L = math.hypot(ax - bx, az - bz)
        ux, uz = (ax - bx) / L, (az - bz) / L
        nx, nz = uz, -ux                       # left of downhill = north
        if nz > 0:
            nx, nz = -nx, -nz
        t = 0.0
        while t < L - 0.01:
            x = bx + ux * t + nx * STREAM_OFF
            z = bz + uz * t + nz * STREAM_OFF
            pts.append([round(x, 2), round(height_fn(x, z) + 0.12, 2), round(z, 2)])
            t += step
    # over the lip and down into the fjord
    x, y, z = pts[-1]
    pts.append([x - 2.0, max(0.05, y - 1.0), z + 0.5])
    pts.append([x - 3.0, 0.05, z + 0.8])
    return pts
