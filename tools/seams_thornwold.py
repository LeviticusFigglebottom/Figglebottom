#!/usr/bin/env python3
"""The seam between Tarnhall and Thornwold: on the drove-road in the notch
out of the tarn basin, where the wood begins.
Shared by gen_tarnhall.py and gen_thornwold.py so both sides agree."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402
import thorn_land as T  # noqa: E402

A, B = T.NOTCH[1], T.NOTCH[2]
TT = 0.45


def r2(v):
    return round(v, 2)


def seam(for_area):
    dx, dz = B[0] - A[0], B[1] - A[1]
    ln = math.hypot(dx, dz)
    ux, uz = dx / ln, dz / ln          # east along the road, into the wood
    x, z = A[0] + dx * TT, A[1] + dz * TT
    yaw = math.degrees(math.atan2(ux, uz))
    y = L.height(x, z)
    if for_area == "tarnhall":
        sx, sz = x + ux * 4.0, z + uz * 4.0
        to = "thornwold"
    else:
        sx, sz = x - ux * 4.0, z - uz * 4.0
        to = "tarnhall"
    # spawn_yaw faces on along the road, away from the seam
    face = math.degrees(math.atan2(-ux, -uz)) if for_area == "tarnhall" else math.degrees(math.atan2(ux, uz))
    return {"to": to, "auto": True, "at": [r2(x), r2(y - 0.3), r2(z)], "rot": r2(yaw), "zone": [18, 8, 2],
            "spawn": [r2(sx), r2(L.height(sx, sz) + 0.6), r2(sz)], "spawn_yaw": r2(face)}
