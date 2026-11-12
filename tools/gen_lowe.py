#!/usr/bin/env python3
"""Authoring script for data/areas/lowe_barrows.json: the Lowe (WORLD.md 5.2).

    the pass      a strip of cliff top where the ravine heads out short of the
                  sea: the main road inland from Saltfell (a seam, no door)
    the Barrow Road   standing stones, the Barrow Road hearth
    the Kin-Mounds    long barrows facing the road; in RIME every door is open
    the peat bog      THAW: black water that drags and drowns; RIME: frozen,
                      walk it to the island of cut peat (bog-iron)
    the Open Barrow   the Turfwright's arena behind a frost veil: a hollow
                      walled with stacked sods round his daughters' barrow
    the bridge    a plank drawbridge over the ravine, lowered from this side:
                  the shortcut back to Saltfell yard

Run: python3 tools/gen_lowe.py [--keep-terrain]"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_lowe as L  # noqa: E402
import terrain_saltfell as S  # noqa: E402
from seams_lowe import PASS, seams  # noqa: E402
from seams_kettle import seam as kettle_seam  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--keep-terrain" not in sys.argv:
    L.write()


def r2(v):
    return round(v, 2)


def g(x, z):
    return r2(L.sample(x, z))


def at(x, z, dy=0.0):
    return [r2(x), r2(g(x, z) + dy), r2(z)]


def rot_off(cx, cz, yaw, ox, oz):
    a = math.radians(yaw)
    return (cx + ox * math.cos(a) + oz * math.sin(a), cz - ox * math.sin(a) + oz * math.cos(a))


# ----------------------------------------------------------------- the Lowe
HOUSES, BUILDINGS, PROPS, BOXES, BLOCKERS = [], [], [], [], []


def barrow(bid, x, z, w, l, door="thaw_shut", toward=None):
    yaw = r2(L.barrow_yaw(x, z, toward))
    y = g(x, z)
    HOUSES.append({"id": bid, "kind": "barrow", "center": [x, z], "size": [w, l], "yaw": yaw, "y": y, "door": door})
    fx, fz = rot_off(x, z, yaw, 0, l * 0.5)
    BUILDINGS.append({"id": bid, "center": [x, z], "size": [w + 3.2, l], "yaw": yaw, "y": y,
                      "doors": [[r2(fx), r2(fz)]], "open": []})
    return yaw, (fx, fz)


DOORS = {}
for (bid, x, z, w, l) in L.LONG_BARROWS:
    # one barrow on the road stays shut in every winter (WORLD.md 4.2)
    DOORS[bid] = barrow(bid, x, z, w, l, door="shut" if bid == "kin_c" else "thaw_shut")
tid, tx, tz, tw, tl = L.TWIN
DOORS[tid] = barrow(tid, tx, tz, tw, tl, door="open", toward=(L.ARENA[0], L.ARENA[1]))

A = L.arena_level()
W = L.bog_level()
CX, CZ, CR = L.ARENA

# the sod wall: stacked cut turf all round the hollow, a gap to the road
place = []
n = int(2 * math.pi * (CR - 0.5) / 1.45)
for k in range(n):
    th = 2 * math.pi * k / n
    deg = math.degrees(th) % 360
    if abs(deg - 90) < 7.5 or abs(deg - 270) < 20:
        continue      # the entrance (south) and the twin barrow (north)
    x = CX + (CR - 0.5) * math.cos(th)
    z = CZ + (CR - 0.5) * math.sin(th)
    place.append({"kind": "peat_stack", "at": [r2(x), r2(z)], "rot": r2(-(deg + 90))})
# stacks of sods waiting, inside the ring: enough to close every barrow
for k in range(14):
    th = 2 * math.pi * k / 14 + 0.2
    x = CX + 13 * math.cos(th)
    z = CZ + 13 * math.sin(th)
    if math.hypot(x - tx, z - tz) > 10 and abs(math.degrees(th) % 360 - 90) > 25:
        place.append({"kind": "peat_stack", "at": [r2(x), r2(z)], "rot": r2(k * 37)})
# standing stones along the Barrow Road
for i in range(len(L.ROAD) - 1):
    ax, az = L.ROAD[i]
    bx, bz = L.ROAD[i + 1]
    dx, dz = bx - ax, bz - az
    ln = math.hypot(dx, dz)
    nx, nz = -dz / ln, dx / ln
    for t in (0.3, 0.75):
        side = 1 if (i + int(t * 2)) % 2 == 0 else -1
        x = ax + dx * t + nx * side * 4.2
        z = az + dz * t + nz * side * 4.2
        place.append({"kind": "standing_stone", "at": [r2(x), r2(z)], "scale": 1.3, "rot": r2((i * 53 + t * 90) % 360)})
# cut peat stacked to dry at the bog's edge
for (x, z, r) in [(-60, -170, 20), (-63, -175, 75), (-22, -176, -30), (-20, -200, 10), (-58, -205, 44)]:
    place.append({"kind": "peat_stack", "at": [x, z], "rot": r})
# the island of cut peat in the bog
for k in range(4):
    th = 3.5 + k * 0.62      # stacked on the island's north side
    place.append({"kind": "peat_stack", "at": [r2(L.ISLAND[0] + 2.2 * math.cos(th)), r2(L.ISLAND[1] + 2.2 * math.sin(th))], "rot": k * 50})

# frost veil across the gap in the sod wall
VEIL = [r2(CX), r2(A), r2(CZ + CR - 0.5)]

# the frozen bog (RIME): an invisible sheet carries you; ice shows where
# THAW: the AI must not path through the black water (nothing collides)
# (three boxes make an octagon out to the bog hazard's rim, 27 m: one square
# box left navmesh over drowning water north and south of it, and at
# W + 2.5 its own top was baked as walkable ground level with the moor, a
# bridge straight over the pool that the walks and the AI took. It stands
# well above the moor now, so nothing can step onto it.)
_BR = 28.0
for _hx, _hz in ((_BR, _BR * 0.414), (_BR * 0.414, _BR), (_BR * 0.707, _BR * 0.707)):
    BLOCKERS.append({"min": [r2(L.BOG[0] - _hx), r2(W - 3), r2(L.BOG[1] - _hz)],
                     "max": [r2(L.BOG[0] + _hx), r2(W + 16.0), r2(L.BOG[1] + _hz)],
                     "tag": "thaw", "nav_only": True})
BLOCKERS.append({"radius": L.BOG_RIM, "at": [L.BOG[0], r2(W - 0.3), L.BOG[1]], "height": 0.6, "tag": "rime"})


def door_front(bid, out=2.2):
    yaw = DOORS[bid][0]
    fx, fz = DOORS[bid][1]
    return rot_off(fx, fz, yaw, 0, out)


spawners = []
# the barrow dead sit up in the barrow mouths facing the road (LOWE.md 2);
# a character faces -z, so the door's own yaw is turned round
for bid, _x, _z, _w, _l in L.LONG_BARROWS:
    if bid == "kin_c":
        continue
    fx, fz = door_front(bid)
    spawners.append({"enemy": "barrow_sleeper", "stand_in": "rimewalker", "id": "sleeper_" + bid,
                     "at": at(fx, fz, 0.1), "face": r2(DOORS[bid][0] + 180), "pose": "sit_up"})
# the closed barrow: one keener kneels at its door, its back to the road
cfx, cfz = door_front("kin_c", 1.6)
spawners += [
    {"enemy": "keener", "stand_in": "oarsman", "id": "keener_road", "at": at(-30, -128, 0.1), "face": 200},
    {"enemy": "keener", "stand_in": "oarsman", "id": "keener_closed", "at": at(cfx, cfz, 0.1),
     "face": r2(DOORS["kin_c"][0]), "pose": "kneel"},
    {"enemy": "keener", "stand_in": "oarsman", "id": "keener_mounds", "at": at(14, -147, 0.1), "face": 160},
    {"enemy": "cairn_carrier", "stand_in": "rimewalker", "id": "carrier_bog", "at": at(-60, -160, 0.1), "face": 30},
    {"enemy": "cairn_carrier", "stand_in": "rimewalker", "id": "carrier_road", "at": at(22, -158, 0.1), "face": 150},
    {"enemy": "barrow_sleeper", "stand_in": "rimewalker", "id": "sleeper_bridge", "at": at(-12, -95, 0.1), "face": 180},
    {"enemy": "turfwright", "stand_in": "netmender", "id": "turfwright", "at": [r2(CX), r2(A + 0.1), r2(CZ - 7)],
     "face": 0, "dead_once": True, "frost_veil_id": "open_barrow_veil"},
]

kin_a = [b for b in L.LONG_BARROWS if b[0] == "kin_a"][0]
pa = rot_off(kin_a[1], kin_a[2], DOORS["kin_a"][0], 0, kin_a[4] * 0.5 - 5.0)
ca = door_front("kin_a", -0.6)       # just inside the door, where the sleeper sat
sa = door_front("kin_d", 0.4)        # the spade propping the door
wa = door_front("kin_c", 0.5)        # on the turf before the closed door
ta = door_front("twin", 5.6)         # the threshold stone, below the twins' door
ts = door_front("twin", 8.0)         # out on the turf before the threshold
# after the release, THAW (LOWE.md 8): Arne sits outside the twins' barrow
# with Liv and Asta on a summer evening, facing out from the door (clear of
# the sods stacked at its mouth), the girls
# half turned to him
TY = DOORS["twin"][0]
RELEASE_SCENE = []
for (nid, ox, oz, turn) in [("arne", 0.0, 6.2, 0), ("liv", -1.35, 6.7, 28), ("asta", 1.35, 6.7, -28)]:
    sx, sz = rot_off(DOORS["twin"][1][0], DOORS["twin"][1][1], TY, ox, oz)
    RELEASE_SCENE.append({"id": nid, "at": at(sx, sz), "rot": r2((TY + 180 + turn) % 360), "tag": "thaw",
                          "require_flag": "ks_turfwright_released"})
M = "res://assets/models/"
pickups = [
    {"id": "peat_island_iron", "at": [r2(L.ISLAND[0] + 0.5), r2(W + 0.5), r2(L.ISLAND[1] + 0.8)], "item": "bog_iron",
     "count": 2, "tag": "rime", "label": "Pry up the bog-iron"},
    {"id": "kin_a_grave_goods", "at": [r2(pa[0]), g(pa[0], pa[1]), r2(pa[1])], "warmth": 60, "tag": "rime",
     "label": "Take what was left for the road"},
    # LOWE.md 2, 3, 8: the Keepsakes threads and the region's finds
    {"id": "orm_cord", "at": at(ca[0], ca[1]), "item": "item_orm_cord", "tag": "rime",
     "label": "Take the knot-cord", "set_flag": "ks_aud_cord_found"},
    {"id": "hesk_tongs", "at": at(-43.15, -185.8), "item": "item_hesk_tongs", "tag": "rime",
     "label": "Chip the tongs out of the ice", "set_flag": "ks_hesk_tongs_found"},
    {"id": "turf_spade", "at": at(sa[0], sa[1]), "item": "turf_spade", "tag": "rime",
     "label": "Work the spade loose", "scene": M + "weapons/turf_spade.glb"},
    {"id": "woad_thread", "at": at(wa[0], wa[1]), "item": "ks_woad_thread", "tag": "rime",
     "label": "Untie the thread"},
    {"id": "twin_spindles", "at": at(ta[0], ta[1]), "item": "item_twin_spindles", "tag": "rime",
     "label": "Take the spindles", "require_flag": "ks_turfwright_released"},
    # Arne's tally-stick (LOWE.md 8). The release sets one down at once, in
    # front of where he knelt (Game._release_leavings, same id); this entry
    # keeps it on the Lowe if the Bearer leaves, or the journey is saved and
    # resumed, before it is taken.
    {"id": "tally_stick", "at": at(ts[0], ts[1]), "item": "item_tally_stick", "tag": "base",
     "scene": M + "props/tally_stick.tscn", "label": "Take the tally-stick",
     "require_flag": "ks_turfwright_released"},
]

portals, bridge = seams("lowe_barrows")
START = [PASS["x"], r2(L.sample(PASS["x"], PASS["z"] - 5.0) + 0.2), PASS["z"] - 5.0]

edges = {
    "doc": "tools/audit_edges.py classes every walkable boundary; seams to Saltfell are their own class.",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [-124, -266, 70, -80],
    "buildings": BUILDINGS, "thickets": [],
    "state_floors": [{"tag": "rime", "center": [L.BOG[0], L.BOG[1]], "radius": L.BOG_RIM, "y": r2(W)}],
    "gates": [],
}

D = {
    "id": "lowe_barrows",
    "name": "The Lowe",
    "start": {"pos": START, "yaw": 0},
    "env": {"thaw": {"sun_rot": [-10, -60], "sun_energy": 2.3, "fog_density": 0.0010, "vol_density": 0.004},
            "rime": {"sun_rot": [-30, -40], "fog_density": 0.006, "vol_density": 0.016}},
    "terrain": L.terrain_block(),
    "nav_bounds": [-124, 10, -266, 70, 90, -80],
    "weather": {"gulls": False, "spindrift": 10},
    "water": [
        {"at": [0, 0.0, -200], "size": [4000, 4000]},
        {"at": [25, S.RAVINE_FLOOR + 0.6, -76], "size": [210, 44]},
        {"at": [L.BOG[0], r2(W), L.BOG[1]], "radius": L.BOG_RIM, "tag": "thaw"},
        {"at": [L.BOG[0], r2(W + 0.02), L.BOG[1]], "radius": L.BOG_RIM, "tag": "rime", "mat": "M_ice"},
    ],
    "hazards": [
        {"kind": "drown", "min": [-1200, -40, -1200], "max": [1200, -1.15, 1200]},
        {"kind": "kill", "min": [S.RAVINE_HEAD_X + 2, -10, -112], "max": [130, S.RAVINE_FLOOR + 4.0, -50]},
        {"kind": "bog", "tag": "thaw", "min": [L.BOG[0] - 27, r2(W - 4), L.BOG[1] - 27], "max": [L.BOG[0] + 27, r2(W - 0.45), L.BOG[1] + 27],
         "radius": 27.0},   # the pool is round: its box's corners are dry heather
        {"kind": "fall", "min": [-100, 0, -112], "max": [70, 60, -78]},
        {"kind": "fall", "min": [-135, -2, -262], "max": [-88, 60, -78]},
    ],
    "zones": [
        {"name": "THE BARROW ROAD", "min": [-100, -112], "max": [-40, -80]},
        {"name": "THE KIN-MOUNDS", "min": [-40, -170], "max": [40, -100]},
        {"name": "THE OPEN BARROW", "min": [24, -240], "max": [70, -176]},
    ],
    "houses": HOUSES,
    "boxes": BOXES,
    "blockers": BLOCKERS,
    "hearths": [
        {"id": "hs_barrow_road", "name": "the Barrow Road", "at": at(-82, -104), "rot": 140},
        # the road's end, in the lee of a drying stack (LOWE.md 1)
        {"id": "hs_drying_stacks", "name": "the Drying Stacks", "at": at(32, -166), "rot": 210},
        # wakes when the Turfwright is released (enemies.json release_hearth)
        {"id": "hs_open_barrow", "name": "the Open Barrow", "at": at(39.5, -203.5), "rot": 160,
         "require_flag": "ks_turfwright_released"},
    ],
    "spawners": spawners,
    "frost_veils": [{"id": "open_barrow_veil", "at": VEIL, "rot": 0, "tag": "rime"}],
    "npcs": [
        {"id": "aud", "at": at(-34, -121), "rot": 200, "tag": "thaw"},
        # faces the bog path, with his back to the cutting (its floor is black water)
        {"id": "hesk", "at": at(-58, -166), "rot": 238, "tag": "thaw"},
    ] + RELEASE_SCENE,
    "plaques": [
        {"at": at(-84, -95), "rot": 20, "text": "THE LOWE\n\nThe barrow hills. Each neighbourhood has its kin-mounds.\nThe turf goes back the same day."},
    ],
    "pickups": pickups,
    "portals": portals + [kettle_seam("lowe_barrows")],
    "scripted": [bridge],
    "scatter": {
        "seed": 5150,
        "clear": [[b["center"][0], b["center"][1], r2(math.hypot(*b["size"]) * 0.5 + 1)] for b in BUILDINGS]
                 + [[CX, CZ, CR + 1.0], [L.BOG[0], L.BOG[1], L.BOG[2] + 3]],
        "rules": [
            {"kind": "rock", "count": 160, "region": [-98, -250, 62, -88], "slope": [0.8, 1.0], "scale": [0.3, 0.9], "path_max": 0.2},
            {"kind": "boulder", "count": 40, "region": [-98, -250, 62, -88], "slope": [0.8, 1.0], "scale": [0.9, 1.7], "path_max": 0.1},
            {"kind": "boulder", "count": 60, "region": [56, -260, 128, -60], "slope": [0.3, 0.75], "scale": [1.0, 2.0]},
            {"kind": "boulder", "count": 50, "region": [-100, -280, 128, -240], "slope": [0.3, 0.8], "scale": [1.0, 2.2]},
            {"kind": "hummock", "count": 200, "region": [-98, -250, 62, -88], "slope": [0.85, 1.0], "scale": [0.5, 1.2], "path_max": 0.25},
            {"kind": "boulder", "count": 40, "region": [-90, -100, 110, -55], "slope": [0.5, 0.95], "h": [2.5, 8], "scale": [0.8, 1.8]},
        ],
        "place": place,
        "veg": [
            {"kind": "heather", "region": [-98, -252, 64, -86], "density": 2.6, "range": 60},
            {"kind": "grass", "region": [-98, -252, 64, -86], "density": 1.4, "range": 50},
            {"kind": "sedge", "region": [L.BOG[0] - 34, L.BOG[1] - 34, L.BOG[0] + 34, L.BOG[1] + 34], "density": 2.0, "range": 50},
            {"kind": "grass", "region": [-98, -76, 64, 30], "density": 1.5, "h": [16, 40], "range": 50},
        ],
    },
    "edges": edges,
}

# --- progression gates (ADR 0015) ---------------------------------------------
# The Kettle Road leaves the moor by a cutting two strides wide. Arne's sods
# are stacked across it, two courses, until he is released (WORLD.md 5.2:
# "enough to close every barrow on the Lowe"). Pulled down from the Kettle
# side at any time. The tracks to it are in terrain_lowe (KETTLE_TRACK_*).
import progress_gates as PG  # noqa: E402
_ka, _kb = L.KETTLE_ROAD[0], L.KETTLE_ROAD[1]
_kf = 0.5
SOD_GATE = PG.gate(
    "lowe_barrows", "kettle_sods", L.sample,
    at=(_ka[0] + (_kb[0] - _ka[0]) * _kf, _ka[1] + (_kb[1] - _ka[1]) * _kf), toward=(_kb[0] - _ka[0], _kb[1] - _ka[1]),
    flag="ks_turfwright_released", name="the Kettle Road", to="kettle_fjord", seam_at=kettle_seam("lowe_barrows")["at"],
    width=2.8, height=2.4, depth=1.2, flank="peat_stack", ext=1.0,
    dressing=[{"scatter": "peat_stack", "fit": [1.5, 1.2, 1.15], "along": -0.72, "rot": 4},
              {"scatter": "peat_stack", "fit": [1.5, 1.2, 1.15], "along": 0.72, "rot": -5},
              {"scatter": "peat_stack", "fit": [1.45, 1.15, 1.05], "along": -0.3, "lift": 1.12, "rot": 9},
              {"scatter": "peat_stack", "fit": [1.3, 1.0, 1.0], "along": 0.95, "lift": 1.12, "rot": -12},
              {"scatter": "peat_stack", "fit": [1.4, 0.3, 1.0], "along": -0.9, "out": 1.6, "rot": 40, "when": "open"}],
    locked_prompt="Stacked from the other side", unbar_prompt="Pull the sods down", open_toast="The stack comes down.")
PG.install(D, SOD_GATE)
# two stones where the track turns into the cutting
for _sgn in (-1, 1):
    _mx = _ka[0] + (_kb[0] - _ka[0]) * 0.08 + SOD_GATE["line"][0] * _sgn * 3.4
    _mz = _ka[1] + (_kb[1] - _ka[1]) * 0.08 + SOD_GATE["line"][1] * _sgn * 3.4
    D["scatter"]["place"].append({"kind": "standing_stone", "at": [r2(_mx), r2(_mz)], "scale": 1.3, "rot": r2(SOD_GATE["rot"] + 90 + _sgn * 11)})
# --- end progression gates

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "lowe_barrows.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
