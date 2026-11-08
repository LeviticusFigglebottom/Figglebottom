#!/usr/bin/env python3
"""Authoring script for data/areas/coldwell.json: the Coldwell (WORLD.md 5.7),
the last area.

    the Upwater    from the High Fold's corner of the Reach (seam), a long,
                   quiet climb along the crest of the mountain's shoulder
                   beside the river, up through its ice-falls; the land
                   falls away on the river's far side and every region lies
                   below, back the way the Bearer came
    the Wellhead   a level of turf at the top, two old houses, a ring of
                   standing stones round the spring under the glacier's lip

THAW (the last Melt before the sickness): the river loud and brown with
flowers in it; Maren holding Wren's hand at the edge. RIME: the river frozen,
every unsung dead of Rimeholt standing in it facing up the water; the
Leadvoice at the wellhead, behind the veil in the ring's gap. After her
release, the `ending_choice` hook at the spring offers the two endings
(SPEC §2 / WORLD.md §6).

Run: python3 tools/gen_coldwell.py [--keep-terrain]"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_coldwell as K  # noqa: E402
import terrain_lowe as L  # noqa: E402
import high_land as H  # noqa: E402
from seams_high import seam  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--keep-terrain" not in sys.argv:
    K.write()


def r2(v):
    return round(v, 2)


def g(x, z):
    return r2(K.sample(x, z))


def at(x, z, dy=0.0):
    return [r2(x), r2(g(x, z) + dy), r2(z)]


PROPS, BOXES, LANDMARKS, HOUSES, BUILDINGS = [], [], [], [], []
WX, WZ = H.WELLHEAD


# --- the river beside the Upwater (on its downhill side) -----------------------------
def river_pts(step=2.0):
    pts = []
    for (ax, az, _), (bx, bz, _) in zip(H.UPWATER, H.UPWATER[1:]):
        L2 = math.hypot(bx - ax, bz - az)
        ux, uz = (bx - ax) / L2, (bz - az) / L2
        nx, nz = -uz, ux
        if nz < 0:
            nx, nz = -nx, -nz                 # the downhill side: toward the regions (z larger)
        t = 0.0
        while t < L2:
            x, z = ax + ux * t + nx * H.RIVER_OFF, az + uz * t + nz * H.RIVER_OFF
            pts.append([r2(x), r2(L.height(x, z) + 0.15), r2(z)])
            t += step
    return pts


RIVER = river_pts()
# the river comes out of the spring: carry it on up to the ring
RIVER = RIVER + [[r2(WX - H.RING_R - 2.0), r2(g(WX - H.RING_R - 2.0, WZ + 4.0) + 0.15), r2(WZ + 4.0)]]
FALLS = [{"pts": RIVER[::-1], "width": 5.0, "tag": "thaw"},
         {"pts": [[p[0], p[1] + 0.12, p[2]] for p in RIVER[::-1]], "width": 5.4, "tag": "rime"}]

# RIME: the unsung dead standing in the frozen river, facing up the water
for k in range(8, len(RIVER) - 4, 6):
    x, y, z = RIVER[k]
    nx_, ny_, nz_ = RIVER[k + 1]
    face = math.degrees(math.atan2(nx_ - x, nz_ - z))
    scene = "res://assets/models/enemies/unsung.glb" if k % 12 == 2 else "res://assets/models/enemies/upwalker.glb"
    LANDMARKS.append({"scene": scene, "at": [x + 0.8 * math.sin(k), r2(y - 0.25), z], "rot": r2(face), "tag": "rime"})

# --- the Wellhead ---------------------------------------------------------------------
LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_wellhead.glb", "at": at(WX, WZ, -0.05), "rot": 90, "scale": 1.0,
                  "blocker": [6.4, 2.6, 5.8]})
GAP_A = 180.0                      # the ring opens toward the Upwater (west)
STONES = []
for k in range(14):
    a = GAP_A + 22.0 + k * (360.0 - 44.0) / 13.0
    x, z = WX + H.RING_R * math.cos(math.radians(a)), WZ + H.RING_R * math.sin(math.radians(a))
    STONES.append((x, z))
    LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_standing_stone.glb", "at": at(x, z, -0.15), "rot": r2(a * 1.3 % 360),
                      "scale": 0.85, "blocker": [1.6, 3.0, 1.6]})
GAP = (WX + H.RING_R * math.cos(math.radians(GAP_A)), WZ + H.RING_R * math.sin(math.radians(GAP_A)))
# two old houses on the level, flanking the way in (BuildingGen turf houses)
for i, (hx, hz) in enumerate(((WX - 22.0, WZ - 17.0), (WX - 22.0, WZ + 17.0))):
    hy = g(hx, hz)
    HOUSES.append({"id": "wellhouse_%d" % i, "center": [hx, hz], "size": [6, 8], "yaw": 90, "y": hy,
                   "doors": [["W", 0 if i == 0 else 1]], "gate_doors": [], "open": [], "wall_h": 2.8})
    BUILDINGS.append({"id": "wellhouse_%d" % i, "center": [hx, hz], "size": [6, 8], "yaw": 90, "y": hy, "doors": [], "open": []})

# --- people and the frost-taken ----------------------------------------------------------


def on_path(i, f, off=0.0, dy=0.0):
    ax, az, _ = H.UPWATER[i]
    bx, bz, _ = H.UPWATER[i + 1]
    x, z = ax + (bx - ax) * f, az + (bz - az) * f
    L2 = math.hypot(bx - ax, bz - az)
    x += (bz - az) / L2 * off
    z += -(bx - ax) / L2 * off
    return at(x, z, dy)


hearths = [
    {"id": "hs_upwater", "name": "the Upwater", "at": on_path(1, 0.5, 2.2), "rot": 250},
    {"id": "hs_ice_falls", "name": "the Ice-Falls", "at": on_path(4, 0.6, 2.2), "rot": 230},
    {"id": "hs_wellhead_steps", "name": "the Wellhead Steps", "at": on_path(8, 0.3, 2.2), "rot": 270},
]
spawners = [
    # the climb is long and quiet: few of them, and slow
    {"enemy": "upwalker", "stand_in": "rimewalker", "id": "upwalker_low", "at": on_path(2, 0.6, 0.0, 0.1), "face": 240},
    {"enemy": "upwalker", "stand_in": "rimewalker", "id": "upwalker_falls", "at": on_path(5, 0.4, 0.0, 0.1), "face": 230},
    {"enemy": "upwalker", "stand_in": "rimewalker", "id": "upwalker_high", "at": on_path(7, 0.5, 0.0, 0.1), "face": 250},
    {"enemy": "unsung", "stand_in": "keener", "id": "unsung_level_a", "at": at(WX - 16.0, WZ - 6.0, 0.1), "face": 270},
    {"enemy": "unsung", "stand_in": "keener", "id": "unsung_level_b", "at": at(WX - 16.0, WZ + 6.0, 0.1), "face": 270},
    {"enemy": "leadvoice", "stand_in": "netmender", "id": "leadvoice", "at": at(WX + 4.5, WZ, 0.1), "face": 270, "pose": "sit",
     "dead_once": True, "frost_veil_id": "wellhead_veil"},
]
VEIL = at(GAP[0], GAP[1])
npcs = [{"id": "maren", "at": at(WX - 14.0, WZ + 9.0), "rot": 200, "tag": "thaw"},
        {"id": "wren", "at": at(WX - 13.2, WZ + 9.6), "rot": 200, "tag": "thaw"}]
pickups = [{"id": "upwater_cache", "at": on_path(6, 0.5, 2.6, 0.05), "item": "bog_iron", "count": 2, "tag": "rime",
            "label": "Pry up what the ice holds"}]

portals = [seam("coldwell", "coldwell")]
arrive = seam("coldwell", "shepherds_reach")
START = arrive["spawn"]

edges = {
    "doc": "tools/audit_edges.py: the Upwater along the shoulder; the drop beyond the river is guarded by the fall volume.",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [676, -556, 964, -364],
    "buildings": BUILDINGS, "thickets": [],
    "state_floors": [],
    "gates": [],
}

D = {
    "id": "coldwell",
    "name": "The Coldwell",
    "start": {"pos": START, "yaw": arrive["spawn_yaw"]},
    # THAW is the last Melt, a spring morning, not the midsummer evening
    "env": {"thaw": {"sun_rot": [-34, -100], "sun_energy": 2.4, "sun_color": [1.0, 0.95, 0.86], "fog_density": 0.0008, "vol_density": 0.004,
                     "ambient": [0.36, 0.38, 0.42], "ambient_energy": 0.72, "exposure": 1.04, "saturation": 1.0,
                     "bg_top": [0.22, 0.36, 0.58], "bg_horizon": [0.86, 0.82, 0.74], "fog_color": [0.74, 0.76, 0.78]},
            "rime": {"sun_rot": [-20, -100], "fog_density": 0.004, "vol_density": 0.01}},
    "terrain": K.terrain_block(),
    "nav_bounds": [676, 40, -556, 964, 220, -364],
    "weather": {"gulls": False, "spindrift": 16},
    "water": [{"at": [r2(WX), r2(g(WX, WZ) + 0.6), r2(WZ)], "radius": 2.6, "tag": "thaw"}],
    "falls": FALLS,
    "hazards": [{"kind": "fall", "min": [676, -2, -556], "max": [964, 400, -364]}],
    "zones": [
        {"name": "THE UPWATER", "min": [676, -556], "max": [r2(WX - 30.0), -364]},
        {"name": "THE WELLHEAD", "min": [r2(WX - 30.0), -556], "max": [964, -364]},
    ],
    "houses": HOUSES,
    "boxes": BOXES,
    "props": PROPS,
    "landmarks": LANDMARKS,
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "wellhead_veil", "at": VEIL, "rot": -90, "tag": "rime"}],
    "npcs": npcs,
    "scripted": [{"script": "res://src/world/ending_choice.gd", "at": at(WX - 5.5, WZ, 0.0), "rot": -90, "tag": "base",
                  "params": {"release_flag": "ks_leadvoice_released"}}],
    "plaques": [{"at": on_path(0, 0.9, 3.4), "rot": 240, "text": "THE COLDWELL\n\nThe river's source, under the glacier's lip."}],
    "pickups": pickups,
    "portals": portals,
    "scatter": {
        "seed": 7071,
        "clear": [[WX, WZ, H.RING_R + 4.0]],
        "rules": [
            {"kind": "rock", "count": 140, "region": [676, -556, 964, -364], "slope": [0.75, 1.0], "scale": [0.3, 0.9], "path_max": 0.3},
            {"kind": "boulder", "count": 80, "region": [676, -556, 964, -364], "slope": [0.4, 0.85], "scale": [1.0, 2.6]},
            {"kind": "ice_floe", "count": 30, "region": [r2(WX + 14.0), -556, 964, -364], "slope": [0.0, 0.8], "scale": [3.0, 6.0]},
        ],
        "veg": [
            {"kind": "grass", "region": [676, -556, 964, -364], "density": 0.9, "range": 40},
            {"kind": "sedge", "region": [676, -556, 964, -364], "density": 0.4, "range": 35},
        ],
    },
    "edges": edges,
}

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "coldwell.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
