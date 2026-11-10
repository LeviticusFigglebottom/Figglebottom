#!/usr/bin/env python3
"""The seams of the high country, shared by the generators on both sides:

    thornwold <-> shepherds_reach   the fell path out of the wood's east side
    shepherds_reach <-> coldwell    the foot of the Upwater, the pasture's NE corner
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402
import high_land as H  # noqa: E402

# (lower area, upper area, road points, leg index, fraction along the leg)
SEAMS = {
    "reach": ("thornwold", "shepherds_reach", H.REACH_PATH, 0, 0.6),
    "coldwell": ("shepherds_reach", "coldwell", H.UPWATER, 0, 0.75),
}


def r2(v):
    return round(v, 2)


def seam(which, for_area):
    lower, upper, pts, i, tt = SEAMS[which]
    (ax, az, _), (bx, bz, _) = pts[i], pts[i + 1]
    dx, dz = bx - ax, bz - az
    ln = math.hypot(dx, dz)
    ux, uz = dx / ln, dz / ln            # up the road
    x, z = ax + dx * tt, az + dz * tt
    yaw = math.degrees(math.atan2(ux, uz))
    y = L.height(x, z)
    if for_area == lower:
        sx, sz, to = x + ux * 4.0, z + uz * 4.0, upper
        face = math.degrees(math.atan2(-ux, -uz))
    else:
        sx, sz, to = x - ux * 4.0, z - uz * 4.0, lower
        face = math.degrees(math.atan2(ux, uz))
    return {"to": to, "auto": True, "at": [r2(x), r2(y - 0.3), r2(z)], "rot": r2(yaw), "zone": [16, 8, 2],
            "spawn": [r2(sx), r2(L.height(sx, sz) + 0.6), r2(sz)], "spawn_yaw": r2(face)}
