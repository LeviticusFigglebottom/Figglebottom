#!/usr/bin/env python3
"""Authoring script for data/areas/tarnhall.json: Tarnhall (WORLD.md 5.4).

    the Tarn Steps     up the gorge from Kettle Fjord's head beside the falls
                       (seam at the foot), to the shore of the tarn
    the Tarn Causeway  a stone causeway over the tarn's west arm to the hall's
                       island, a plank bridge over its channel
    the Byres          the cattle end, under the hall's east gable
    the Long Table     the great hall: the feast laid down its length

THAW: the feast at full roar, the doors propped open; walk in off the porch.
The tarn is deep and cold: the causeway is the only way over.
RIME: the doors are barred from inside. The tarn is frozen (walk it; mind
the cracks by the island). The way in is round by the byres, through the
cattle end and into the hall at the high seat's end, where the Host waits.

Run: python3 tools/gen_tarnhall.py [--keep-terrain]"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_tarnhall as K  # noqa: E402
import terrain_lowe as L  # noqa: E402
import tarn_land as T  # noqa: E402
from seams_tarnhall import seam  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--keep-terrain" not in sys.argv:
    K.write()


def r2(v):
    return round(v, 2)


def g(x, z):
    return r2(K.sample(x, z))


def at(x, z, dy=0.0):
    return [r2(x), r2(g(x, z) + dy), r2(z)]


HOUSES, BUILDINGS, PROPS, BOXES, BLOCKERS, FLOORS, LANDMARKS = [], [], [], [], [], [], []
FY = T.ISLAND_Y            # the island (and the hall's floor)

# --- the hall and the byres -------------------------------------------------
# yaw 90: the hall's length runs east-west. Local N gable = world west (the
# front, toward the causeway), local S gable = world east (into the byres).
HALL_C, HALL_W, HALL_L = (198.0, -330.0), 14.0, 36.0
HALL_X0, HALL_X1 = HALL_C[0] - HALL_L / 2, HALL_C[0] + HALL_L / 2      # 180 .. 216
DOOR_Z = HALL_C[1] + 1.0                                               # bay 1 of a 14 m gable
HOUSES.append({"id": "hall", "center": list(HALL_C), "size": [HALL_W, HALL_L], "yaw": 90, "y": FY,
               "doors": [["N", 1], ["S", 1]], "gate_doors": [], "open": [], "wall_h": 4.6})
BUILDINGS.append({"id": "hall", "center": list(HALL_C), "size": [HALL_W, HALL_L], "yaw": 90, "y": FY,
                  "doors": [[HALL_X0, DOOR_Z], [HALL_X1, DOOR_Z]], "open": []})
BYRE_C, BYRE_W, BYRE_L = (HALL_X1 + 7.6, -330.0), 10.0, 14.0
BYRE_X0 = BYRE_C[0] - BYRE_L / 2
BYRE_DOOR = (BYRE_C[0] - 1.0, BYRE_C[1] + BYRE_W / 2)                  # the cattle door, south wall
HOUSES.append({"id": "byres", "center": list(BYRE_C), "size": [BYRE_W, BYRE_L], "yaw": 90, "y": FY,
               "doors": [["N", 1], ["W", 1]], "gate_doors": [], "open": [], "wall_h": 3.4})
BUILDINGS.append({"id": "byres", "center": list(BYRE_C), "size": [BYRE_W, BYRE_L], "yaw": 90, "y": FY,
                  "doors": [[BYRE_X0, DOOR_Z], list(BYRE_DOOR)], "open": []})


def floor(x0, z0, x1, z1, y, mat="M_wood", tag="base", collide=True):
    BOXES.append({"min": [r2(min(x0, x1)), r2(y - 0.22), r2(min(z0, z1))], "max": [r2(max(x0, x1)), r2(y), r2(max(z0, z1))],
                  "mat": mat, "tag": tag, "collide": collide})
    FLOORS.append({"tag": tag, "min": [r2(min(x0, x1)), r2(min(z0, z1))], "max": [r2(max(x0, x1)), r2(max(z0, z1))], "y": r2(y)})


# the porch before the doors: plank floor a step up, posts, a turf lean-to
PORCH_Y = FY + 0.2
floor(HALL_X0 - 6.0, HALL_C[1] - 7.0, HALL_X0 - 0.25, HALL_C[1] + 7.0, PORCH_Y)
for pz in (-6.4, -2.2, 2.2, 6.4):
    BOXES.append({"min": [HALL_X0 - 5.9, PORCH_Y, r2(HALL_C[1] + pz - 0.2)], "max": [HALL_X0 - 5.5, PORCH_Y + 3.3, r2(HALL_C[1] + pz + 0.2)],
                  "mat": "M_wood", "tag": "base"})
BOXES.append({"min": [HALL_X0 - 6.4, PORCH_Y + 3.3, HALL_C[1] - 7.4], "max": [HALL_X0, PORCH_Y + 3.6, HALL_C[1] + 7.4],
              "mat": "M_wood", "tag": "base", "collide": False})
BOXES.append({"min": [HALL_X0 - 6.6, PORCH_Y + 3.6, HALL_C[1] - 7.6], "max": [HALL_X0 + 0.2, PORCH_Y + 4.1, HALL_C[1] + 7.6],
              "mat": "M_turf", "tag": "base", "collide": False})
# the plinth wall under the porch edge (dry-stone, like the concept)
BOXES.append({"min": [HALL_X0 - 6.3, FY - 1.2, HALL_C[1] - 7.3], "max": [HALL_X0 - 5.9, PORCH_Y - 0.2, HALL_C[1] + 7.3],
              "mat": "M_drystone", "tag": "base"})

# the doors. THAW: propped open, leaves back against the porch. RIME: barred
# from inside; the Tripo doors stand shut in the gap, and only the inside face
# lifts the bar (a shortcut once you are in by the byres).
DOORS_AT = [HALL_X0, FY, DOOR_Z]
PROPS.append({"kit": "door_leaf", "at": [HALL_X0 - 0.55, FY, r2(DOOR_Z - 1.4)], "rot": 0, "tag": "thaw", "collide": False})
PROPS.append({"kit": "door_leaf", "at": [HALL_X0 - 0.55, FY, r2(DOOR_Z + 1.4)], "rot": 0, "tag": "thaw", "collide": False})
GATES = [{"id": "hall_doors", "at": [HALL_X0 - 0.3, FY, DOOR_Z], "rot": -90, "width": 1.9, "tag": "rime",
          "locked_prompt": "Barred from the inside",
          "dressing": {"scene": "res://assets/models/landmarks/lm_hall_doors.glb", "offset": [0, 0, 0.45], "rot": 0, "scale": 0.4}}]
STATE_WALLS = [{"tag": "rime", "min": [HALL_X0 - 0.6, DOOR_Z - 1.3], "max": [HALL_X0 + 0.6, DOOR_Z + 1.3]}]
# the guest-post just inside the door (the guest-tally hangs on it)
LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_guest_post.glb", "at": [HALL_X0 + 1.0, FY, r2(DOOR_Z + 2.0)], "rot": 90})
# the high seat at the east end, facing down the hall
LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_high_seat.glb", "at": [HALL_X1 - 2.0, FY, r2(HALL_C[1] - 3.5)], "rot": -90})

# --- the Long Table ---------------------------------------------------------
TABLE_Z = HALL_C[1] - 3.6
TX0, TX1 = HALL_X0 + 5.0, HALL_X1 - 6.0
BOXES.append({"min": [TX0, FY + 0.72, r2(TABLE_Z - 0.7)], "max": [TX1, FY + 0.82, r2(TABLE_Z + 0.7)], "mat": "M_wood", "tag": "base"})
for lx in (TX0 + 0.4, (TX0 + TX1) / 2, TX1 - 0.4):
    BOXES.append({"min": [r2(lx - 0.15), FY, r2(TABLE_Z - 0.5)], "max": [r2(lx + 0.15), FY + 0.72, r2(TABLE_Z + 0.5)], "mat": "M_wood_dark", "tag": "base"})
for bz in (TABLE_Z - 1.45, TABLE_Z + 1.45):
    BOXES.append({"min": [TX0, FY, r2(bz - 0.22)], "max": [TX1, FY + 0.45, r2(bz + 0.22)], "mat": "M_wood_dark", "tag": "base"})
# the feast on it: horns, bowls, loaves. RIME: every horn full and frozen over.
k = 0
x = TX0 + 0.8
while x < TX1 - 0.6:
    for side in (-1, 1):
        hz = TABLE_Z + side * 0.42
        BOXES.append({"min": [r2(x - 0.06), FY + 0.82, r2(hz - 0.06)], "max": [r2(x + 0.06), FY + 1.12, r2(hz + 0.06)],
                      "mat": "M_bone", "tag": "thaw", "collide": False})
        BOXES.append({"min": [r2(x - 0.07), FY + 0.82, r2(hz - 0.07)], "max": [r2(x + 0.07), FY + 1.16, r2(hz + 0.07)],
                      "mat": "M_ice", "tag": "rime", "collide": False})
    if k % 2 == 0:
        BOXES.append({"min": [r2(x + 0.3), FY + 0.82, r2(TABLE_Z - 0.18)], "max": [r2(x + 0.75), FY + 0.95, r2(TABLE_Z + 0.18)],
                      "mat": "M_drift", "tag": "base", "collide": False})
    k += 1
    x += 1.6
# the guests. THAW: the benches packed. RIME: the same guests, white, in
# their seats (the Tripo feast-guest as a still); some stand when you come in.
for i in range(8):
    gx = TX0 + 1.5 + i * (TX1 - TX0 - 3.0) / 7.0
    for side in (-1, 1):
        gz = TABLE_Z + side * 1.95
        if (i + (side > 0)) % 2 == 0:
            PROPS.append({"kit": "mannequin_thaw", "at": [r2(gx), FY, r2(gz)], "rot": 0 if side > 0 else 180, "tag": "thaw", "collide": False})
        elif i % 3 != 1:
            LANDMARKS.append({"scene": "res://assets/models/enemies/feast_guest.glb", "at": [r2(gx), FY, r2(gz)],
                              "rot": 180 if side > 0 else 0, "tag": "rime"})
# the hall's light: the fire along the middle of the floor (THAW), dead in RIME
PROPS.append({"kit": "fish_kettle", "at": [r2(HALL_C[0] - 4), FY, r2(HALL_C[1] + 2.4)], "rot": 0, "tag": "thaw", "glow": [2.0, 2.4, 14.0]})
PROPS.append({"kit": "fish_kettle", "at": [r2(HALL_C[0] + 8), FY, r2(HALL_C[1] + 2.4)], "rot": 40, "tag": "thaw", "glow": [2.0, 2.0, 12.0]})

# --- the byres --------------------------------------------------------------
for i in range(3):
    sx = BYRE_X0 + 3.0 + i * 4.0
    BOXES.append({"min": [r2(sx - 0.1), FY, r2(BYRE_C[1] - 4.6)], "max": [r2(sx + 0.1), FY + 1.3, r2(BYRE_C[1] - 1.6)],
                  "mat": "M_wood", "tag": "base"})                    # stall partitions (north side)
    BOXES.append({"min": [r2(sx - 1.6), FY, r2(BYRE_C[1] - 4.7)], "max": [r2(sx + 1.6), FY + 0.6, r2(BYRE_C[1] - 4.2)],
                  "mat": "M_wood_dark", "tag": "base", "collide": False})  # mangers
PROPS.append({"kit": "creel_stack", "at": [r2(BYRE_C[0] + 4.5), FY, r2(BYRE_C[1] + 3.0)], "rot": 20, "collide": False})

# --- the causeway: dry-stone kerbs along its sides, the plank bridge --------
(cax, caz), (cbx, cbz) = T.CAUSEWAY
CL = math.hypot(cbx - cax, cbz - caz)
cux, cuz = (cbx - cax) / CL, (cbz - caz) / CL
BRIDGE_Z = caz + (cuz / cux) * ((T.CHANNEL[0] + T.CHANNEL[1]) / 2 - cax)
floor(T.CHANNEL[0] - 1.4, BRIDGE_Z - 2.1, T.CHANNEL[1] + 1.4, BRIDGE_Z + 2.1, T.CAUSEWAY_Y + 0.05)
for zz in (BRIDGE_Z - 2.25, BRIDGE_Z + 2.25):
    BOXES.append({"min": [T.CHANNEL[0] - 1.4, T.CAUSEWAY_Y + 0.05, r2(zz - 0.07)], "max": [T.CHANNEL[1] + 1.4, T.CAUSEWAY_Y + 1.0, r2(zz + 0.07)],
                  "mat": "M_wood", "tag": "base"})                     # hand-rails
for px in (T.CHANNEL[0] + 0.3, (T.CHANNEL[0] + T.CHANNEL[1]) / 2, T.CHANNEL[1] - 0.3):
    for zz in (BRIDGE_Z - 1.9, BRIDGE_Z + 1.9):
        BOXES.append({"min": [r2(px - 0.15), T.TARN_Y - 4.0, r2(zz - 0.15)], "max": [r2(px + 0.15), T.CAUSEWAY_Y - 0.2, r2(zz + 0.15)],
                      "mat": "M_wood_dark", "tag": "base", "collide": False})
t = 0.0
while t < CL:
    px, pz = cax + cux * t, caz + cuz * t
    if not (T.CHANNEL[0] - 2.0 < px < T.CHANNEL[1] + 2.0) and t > 3.0 and t < CL - 2.0:
        for side in (-1, 1):
            kx, kz = px - cuz * side * (T.CAUSEWAY_HALF + 0.25), pz + cux * side * (T.CAUSEWAY_HALF + 0.25)
            BOXES.append({"min": [r2(kx - 0.9), T.CAUSEWAY_Y - 0.6, r2(kz - 0.25)], "max": [r2(kx + 0.9), T.CAUSEWAY_Y + 0.5, r2(kz + 0.25)],
                          "mat": "M_drystone", "tag": "base"})
    t += 1.8

# --- water and ice ----------------------------------------------------------
ICE = {"min": [134.0, T.TARN_Y - 0.6, -362.0], "max": [263.0, T.TARN_Y + 0.05, -290.0]}
FJORD_ICE = {"min": [24.0, -0.6, -330.0], "max": [46.0, 0.05, -292.0]}
water = [{"at": [0, 0.0, -320], "size": [3000, 3000], "tag": "thaw"},
         {"at": [list(T.TARN_C)[0], T.TARN_Y, T.TARN_C[1]], "radius": 66.0, "tag": "thaw"},
         {"at": [list(T.TARN_C)[0], T.TARN_Y - 3.0, T.TARN_C[1]], "radius": 66.0, "tag": "rime"},
         {"at": [35.0, -3.0, -311.0], "size": [24, 40], "tag": "rime"}]
for ice in (ICE, FJORD_ICE):
    BLOCKERS.append({"min": ice["min"], "max": ice["max"], "tag": "rime"})
    BOXES.append({"min": [ice["min"][0], ice["max"][1] - 0.05, ice["min"][2]], "max": [ice["max"][0], ice["max"][1] + 0.02, ice["max"][2]],
                  "mat": "M_ice_sheet", "tag": "rime", "collide": False})

# cracks in the tarn ice round the island (RIME): stand on one and it gives
THIN = []
for (cx, cz, lx, lz) in [(156.0, -344.0, 7.0, 1.2), (192.0, -304.0, 1.2, 6.0), (184.0, -359.0, 7.0, 1.2), (230.0, -305.0, 1.2, 6.0)]:
    THIN.append({"min": [r2(cx - lx / 2), T.TARN_Y - 1.0, r2(cz - lz / 2)], "max": [r2(cx + lx / 2), T.TARN_Y + 0.8, r2(cz + lz / 2)]})
for t_ in THIN:
    BLOCKERS.append({"min": [t_["min"][0] - 0.3, T.TARN_Y - 1.0, t_["min"][2] - 0.3], "max": [t_["max"][0] + 0.3, T.TARN_Y + 8.0, t_["max"][2] + 0.3],
                     "tag": "rime", "nav_only": True})
    water.append({"at": [r2((t_["min"][0] + t_["max"][0]) / 2), T.TARN_Y + 0.08, r2((t_["min"][2] + t_["max"][2]) / 2)],
                  "size": [r2(t_["max"][0] - t_["min"][0]), r2(t_["max"][2] - t_["min"][2])], "tag": "rime"})

hazards = [
    {"kind": "drown", "min": [-1200, -40, -1200], "max": [1200, -1.15, 1200]},
    {"kind": "drown", "min": [128, -40, -366], "max": [268, T.TARN_Y - 1.15, -286], "tag": "thaw"},
    {"kind": "fall", "min": [24, -2, -400], "max": [280, 140, -256]},
] + [dict(t_, kind="thin", tag="rime") for t_ in THIN]


def thaw_water_blockers():
    """THAW: tall nav-only walls over the tarn in strips, stopping at the
    island, the causeway and the bridge (no flat top for the navmesh)."""
    x = 134.0
    while x < 262.0:
        xm = x + 1.0
        zs = []
        z = -362.0
        while z <= -290.0:
            water_here = T.tarn_e(xm, z) < 0.98 and T.island_e(xm, z) > 1.12
            cd, _ = T.causeway_d(xm, z)
            if cd < T.CAUSEWAY_HALF + 1.6:
                water_here = False
            zs.append((z, water_here))
            z += 1.0
        run = None
        for z, wet in zs + [(0.0, False)]:
            if wet and run is None:
                run = z
            elif not wet and run is not None:
                if z - run >= 2.0:
                    BLOCKERS.append({"min": [r2(x), T.TARN_Y - 9.0, r2(run)], "max": [r2(x + 2.0), T.TARN_Y + 8.0, r2(z - 1.0)],
                                     "tag": "thaw", "nav_only": True})
                run = None
        x += 2.0


thaw_water_blockers()

# --- the falls: the tarn's outflow down the Tarn Steps into the fjord -------
_st = T.stream(L.height)
FALLS = [{"pts": _st, "width": 2.4, "tag": "thaw"},
         {"pts": [[p[0], p[1] + 0.12, p[2]] for p in _st], "width": 2.8, "tag": "rime"}]

# --- people and the frost-taken ---------------------------------------------
ROAD = T.STEPS


def on_road(i, f, dy=0.0, off=0.0):
    ax, az, _ = ROAD[i]
    bx, bz, _ = ROAD[i + 1]
    x, z = ax + (bx - ax) * f, az + (bz - az) * f
    L2 = math.hypot(bx - ax, bz - az)
    x += -(bz - az) / L2 * off
    z += (bx - ax) / L2 * off
    return at(x, z, dy)


hearths = [
    {"id": "hs_tarn_steps", "name": "the Tarn Steps", "at": on_road(3, 0.5, 0.0, 2.0), "rot": 200},
    {"id": "hs_tarn_causeway", "name": "the Tarn Causeway", "at": at(124.0, -331.0), "rot": 250},
]
spawners = [
    {"enemy": "feast_guest", "stand_in": "rimewalker", "id": "guest_steps", "at": on_road(4, 0.6, 0.1), "face": 240},
    {"enemy": "feast_guest", "stand_in": "rimewalker", "id": "guest_porch", "at": [HALL_X0 - 3.0, PORCH_Y + 0.1, r2(HALL_C[1] - 4.5)], "face": 270},
    {"enemy": "feast_guest", "stand_in": "rimewalker", "id": "guest_island", "at": at(HALL_C[0] + 4.0, HALL_C[1] + 10.0, 0.1), "face": 270},
    {"enemy": "feast_guest", "stand_in": "rimewalker", "id": "guest_byre_yard", "at": at(BYRE_C[0] + 3.0, BYRE_C[1] + 9.0, 0.1), "face": 0,
     "pose": "sit"},
    {"enemy": "cupbearer", "stand_in": "keener", "id": "cupbearer_byre_a", "at": [r2(BYRE_X0 + 3.5), FY + 0.1, r2(BYRE_C[1] + 1.5)], "face": 90},
    {"enemy": "cupbearer", "stand_in": "keener", "id": "cupbearer_byre_b", "at": [r2(BYRE_X0 + 10.5), FY + 0.1, r2(BYRE_C[1] + 1.0)], "face": 270},
    {"enemy": "hall_champion", "stand_in": "cairn_carrier", "id": "champion_bridge", "at": at(T.CHANNEL[1] + 6.0, BRIDGE_Z + 0.6, 0.1), "face": 90,
     "dead_once": True},
    {"enemy": "host", "stand_in": "netmender", "id": "host", "at": [r2(HALL_C[0] + 2.0), FY + 0.1, r2(HALL_C[1] + 3.0)], "face": 90,
     "dead_once": True, "frost_veil_id": "long_table_veil"},
]
VEIL = [r2(BYRE_X0 + 1.4), FY, DOOR_Z]
pickups = [
    {"id": "byre_cache", "at": [r2(BYRE_C[0] + 4.6), FY, r2(BYRE_C[1] - 3.2)], "item": "bog_iron", "count": 2, "tag": "rime",
     "label": "Pry up what the byre floor holds"},
    {"id": "tarn_horn", "at": [r2(HALL_X0 - 4.6), PORCH_Y, r2(HALL_C[1] + 5.8)], "warmth": 45, "tag": "base", "label": "Take the guest's horn"},
]
npcs = [{"id": "lusse", "at": [r2(HALL_C[0] + 1.0), FY, r2(HALL_C[1] + 2.0)], "rot": 200, "tag": "thaw"}]

portal = seam("tarnhall")
arrive = seam("kettle_fjord")       # Kettle's side of the seam sets you down here
START = arrive["spawn"]

# --- scatter ----------------------------------------------------------------
place = []
for k2 in range(14):
    a = k2 * 0.61
    x = T.TARN_C[0] + math.cos(a) * T.TARN_R[0] * 1.03
    z = T.TARN_C[1] + math.sin(a) * T.TARN_R[1] * 1.03
    place.append({"kind": "boulder", "at": [r2(x), r2(z)], "rot": k2 * 37 % 360, "scale": [1.2, 0.9, 1.1]})

edges = {
    "doc": "tools/audit_edges.py: the porch and the bridge are floors; the RIME ice is a floor over the tarn and the fjord head; "
           "the hall's front doors are a wall in RIME (barred).",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [24, -400, 280, -256],
    "buildings": BUILDINGS, "thickets": [],
    "state_floors": FLOORS + [{"tag": "rime", "min": [ICE["min"][0], ICE["min"][2]], "max": [ICE["max"][0], ICE["max"][2]], "y": ICE["max"][1]},
                              {"tag": "rime", "min": [FJORD_ICE["min"][0], FJORD_ICE["min"][2]], "max": [FJORD_ICE["max"][0], FJORD_ICE["max"][2]], "y": 0.05}],
    "state_walls": STATE_WALLS,
    "gates": [],
}

D = {
    "id": "tarnhall",
    "name": "Tarnhall",
    "start": {"pos": START, "yaw": arrive["spawn_yaw"]},
    "env": {"thaw": {"sun_rot": [-16, -110], "sun_energy": 2.6, "fog_density": 0.001, "vol_density": 0.005,
                     "ambient_energy": 0.58, "exposure": 1.04,
                     "fill_color": [1.0, 0.74, 0.48], "fill_energy": 0.5, "fill_rot": [24, 70]},
            "rime": {"sun_rot": [-26, -70], "fog_density": 0.006, "vol_density": 0.016}},
    "terrain": K.terrain_block(),
    "nav_bounds": [24, -16, -400, 280, 90, -256],
    "weather": {"gulls": False, "spindrift": 10},
    "water": water,
    "falls": FALLS,
    "hazards": hazards,
    "zones": [
        {"name": "THE TARN CAUSEWAY", "min": [24, -400], "max": [HALL_X0 - 0.5, -256]},
        {"name": "THE LONG TABLE", "min": [HALL_X0 - 0.5, -337], "max": [HALL_X1 + 0.3, -323]},
        {"name": "THE BYRES", "min": [HALL_X1 + 0.3, -400], "max": [280, -256]},
    ],
    "houses": HOUSES,
    "boxes": BOXES,
    "blockers": BLOCKERS,
    "props": PROPS,
    "landmarks": LANDMARKS,
    "gates": GATES,
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "long_table_veil", "at": VEIL, "rot": 90, "tag": "rime"}],
    "npcs": npcs,
    "plaques": [{"at": at(127.0, -337.5, 0.0), "rot": 230,
                 "text": "TARNHALL\n\nSeven neighbourhoods came up the water every Long Light to feast here."}],
    "pickups": pickups,
    "portals": [portal],
    "scatter": {
        "seed": 9090,
        "clear": [[HALL_C[0], HALL_C[1], 24.0], [BYRE_C[0], BYRE_C[1], 9.0], [124.0, -331.0, 4.0]],
        "rules": [
            {"kind": "rock", "count": 140, "region": [30, -390, 275, -262], "slope": [0.8, 1.0], "h": [3.0, 60], "scale": [0.3, 0.9], "path_max": 0.3},
            {"kind": "boulder", "count": 90, "region": [30, -400, 280, -256], "slope": [0.45, 0.85], "h": [3.0, 120], "scale": [0.9, 2.2]},
        ],
        "place": place,
        "veg": [
            {"kind": "grass", "region": [24, -400, 280, -256], "density": 1.4, "h": [T.TARN_Y + 1.2, 140], "range": 45},
            {"kind": "heather", "region": [24, -400, 280, -256], "density": 0.5, "h": [T.TARN_Y + 4.0, 140], "range": 40},
            {"kind": "sedge", "region": [128, -366, 268, -286], "density": 0.9, "h": [T.TARN_Y + 0.6, T.TARN_Y + 3.0], "range": 40},
        ],
    },
    "edges": edges,
}

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "tarnhall.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
