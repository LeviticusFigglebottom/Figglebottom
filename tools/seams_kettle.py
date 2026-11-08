#!/usr/bin/env python3
"""The seam between the Lowe and Kettle Fjord: a cleft on the Kettle Road
where it leaves the moor and drops through the fell wall to the fjord.
Shared by gen_lowe.py and gen_kettle.py so both sides agree."""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402

# the seam sits on the road's second leg, high in the cleft
A, B = L.KETTLE_ROAD[1], L.KETTLE_ROAD[2]
T = 0.45


def r2(v):
    return round(v, 2)


def seam(for_area):
    dx, dz = B[0] - A[0], B[1] - A[1]
    ln = math.hypot(dx, dz)
    ux, uz = dx / ln, dz / ln          # down the road, toward the fjord
    x, z = A[0] + dx * T, A[1] + dz * T
    yaw = math.degrees(math.atan2(ux, uz))
    y = L.height(x, z)
    if for_area == "lowe_barrows":
        sx, sz = x + ux * 4.0, z + uz * 4.0
        to = "kettle_fjord"
    else:
        sx, sz = x - ux * 4.0, z - uz * 4.0
        to = "lowe_barrows"
    return {"to": to, "auto": True, "at": [r2(x), r2(y - 0.3), r2(z)], "rot": r2(yaw), "zone": [10, 6, 2],
            "spawn": [r2(sx), r2(L.height(sx, sz) + 0.6), r2(sz)], "spawn_yaw": r2(yaw + (180 if for_area == "lowe_barrows" else 0))}
