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
from seams_thornwold import seam as wood_seam  # noqa: E402

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
BYRE_C, BYRE_W, BYRE_L = (HALL_X1 + 7.4, -330.0), 10.0, 14.0   # gable to gable: a 0.2 m slit beside the door pinched a capsule
BYRE_X0 = BYRE_C[0] - BYRE_L / 2
BYRE_DOOR = (BYRE_C[0] - 1.0, BYRE_C[1] + BYRE_W / 2)                  # the cattle door, south wall
# (the byre's gable is 10 m, its bays stand 2 m off the hall's: the door
# through to the hall is shifted along the gable to meet the hall's own,
# or each door opens on the other building's wall)
HOUSES.append({"id": "byres", "center": list(BYRE_C), "size": [BYRE_W, BYRE_L], "yaw": 90, "y": FY,
               "doors": [["N", 1, -2.0], ["W", 1]], "gate_doors": [], "open": [], "wall_h": 3.4})
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
# Modelled pieces (KitLib feast_horn, trencher, fat_lamp): a horn at every
# place, a bread board at every other, and soapstone fat lamps down the
# middle of the board, lit in THAW and cold in RIME.
k = 0
x = TX0 + 0.8
while x < TX1 - 0.6:
    for side in (-1, 1):
        hz = TABLE_Z + side * 0.42
        PROPS.append({"kit": "feast_horn", "at": [r2(x), FY + 0.82, r2(hz)], "rot": (k * 67 + side * 20) % 360, "tag": "thaw", "collide": False, "on": "table"})
        PROPS.append({"kit": "feast_horn_frozen", "at": [r2(x), FY + 0.82, r2(hz)], "rot": (k * 67 + side * 20) % 360, "tag": "rime", "collide": False, "on": "table"})
    if k % 2 == 0:
        PROPS.append({"kit": "trencher", "at": [r2(x + 0.52), FY + 0.82, r2(TABLE_Z)], "rot": (k * 23) % 40 - 20, "collide": False, "on": "table"})
    if k % 3 == 1:
        PROPS.append({"kit": "fat_lamp", "at": [r2(x + 1.05), FY + 0.82, r2(TABLE_Z)], "rot": k * 50, "tag": "thaw", "collide": False, "on": "table"})
        PROPS.append({"kit": "fat_lamp_cold", "at": [r2(x + 1.05), FY + 0.82, r2(TABLE_Z)], "rot": k * 50, "tag": "rime", "collide": False, "on": "table"})
    k += 1
    x += 1.6
SEATS = []
# the guests. THAW: the benches packed. RIME: the same guests, white, in
# their seats (the Tripo feast-guest as a still); some stand when you come in.
for i in range(8):
    gx = TX0 + 1.5 + i * (TX1 - TX0 - 3.0) / 7.0
    for side in (-1, 1):
        gz = TABLE_Z + side * 1.95
        if (i + (side > 0)) % 2 == 0:
            PROPS.append({"kit": "mannequin_thaw", "at": [r2(gx), FY, r2(gz)], "rot": 0 if side > 0 else 180, "tag": "thaw", "collide": False})
        elif i % 3 != 1:
            # seated in their places (sit_feast); the Host raises them (TARNHALL.md 6)
            SEATS.append({"enemy": "feast_guest_seated", "id": "seat_%d_%s" % (i, "s" if side > 0 else "n"),
                          "at": [r2(gx), FY + 0.1, r2(gz)], "face": 0 if side > 0 else 180, "pose": "sit_feast",
                          "absent_flag": "ks_host_released"})
# the long hearth down the middle of the floor: fires burning along it in
# THAW (light through the smoke-holes above), cold ash in RIME
HEARTH_Z = HALL_C[1] + 1.6
BOXES.append({"min": [HALL_X0 + 6.0, FY, r2(HEARTH_Z - 0.75)], "max": [HALL_X1 - 8.0, FY + 0.22, r2(HEARTH_Z + 0.75)],
              "mat": "M_drystone", "tag": "base"})
SMOKE_HOLES = []
for i, hx in enumerate((HALL_X0 + 8.5, HALL_X0 + 15.0, HALL_X0 + 21.5)):
    PROPS.append({"kit": "hearth_fire", "at": [r2(hx), FY + 0.22, r2(HEARTH_Z)], "rot": i * 37, "tag": "thaw", "collide": False,
                  "glow": [1.4, 3.2, 16.0], "embed": True})
    PROPS.append({"kit": "hearth_logs", "at": [r2(hx), FY + 0.22, r2(HEARTH_Z)], "rot": i * 37, "tag": "rime", "collide": False, "embed": True})
    SMOKE_HOLES.append([r2(hx), FY + 2.6, r2(HEARTH_Z)])

# --- the byres --------------------------------------------------------------
for i in range(3):
    sx = BYRE_X0 + 3.0 + i * 4.0
    BOXES.append({"min": [r2(sx - 0.1), FY, r2(BYRE_C[1] - 4.85)], "max": [r2(sx + 0.1), FY + 1.3, r2(BYRE_C[1] - 1.6)],
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
            water_here = T.tarn_e(xm, z) < 0.98 and T.island_e(xm, z) > 1.12 and not T.on_island_ground(xm, z)
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
    # the byre yard by the cattle door: nearest hearth to the Host (TARNHALL.md 1)
    {"id": "hs_byres", "name": "the Byres", "at": at(BYRE_C[0] - 4.0, BYRE_C[1] + 8.0), "rot": 180},
    # the hall's cold fire, woken when he is released (release_hearth)
    {"id": "hs_long_table", "name": "the Long Table", "at": [r2(HALL_C[0] - 1.0), FY, r2(HALL_C[1] + 2.6)], "rot": 90,
     "require_flag": "ks_host_released"},
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
    # at the cattle door, facing out into the yard (TARNHALL.md 3)
    {"enemy": "hall_champion", "stand_in": "cairn_carrier", "id": "champion_byre_door", "at": at(BYRE_DOOR[0], BYRE_DOOR[1] + 1.8, 0.1), "face": 180},
    # the Host at the long table, filling the horns (TARNHALL.md 4, 6)
    {"enemy": "host", "stand_in": "netmender", "id": "host", "at": [r2(HALL_C[0] + 2.0), FY + 0.1, r2(TABLE_Z + 3.0)], "face": 0,
     "dead_once": True, "frost_veil_id": "long_table_veil"},
] + SEATS
# in the doorway itself, between the hall's gable and the byre's: a veil
# standing free inside the byre could be walked round once the door is a door
VEIL = [r2(HALL_X1 + 0.3), FY, DOOR_Z]
pickups = [
    {"id": "byre_cache", "at": [r2(BYRE_C[0] + 4.6), FY, r2(BYRE_C[1] - 3.2)], "item": "bog_iron", "count": 2, "tag": "rime",
     "label": "Pry up what the byre floor holds"},
    {"id": "tarn_horn", "at": [r2(HALL_X0 - 4.6), PORCH_Y, r2(HALL_C[1] + 5.8)], "warmth": 45, "tag": "base", "label": "Take the guest's horn"},
    # TARNHALL.md 3, 4, 9
    {"id": "feast_cleaver", "at": [r2(BYRE_C[0] + 3.4), FY, r2(BYRE_C[1] + 2.2)], "item": "feast_cleaver", "tag": "rime",
     "scene": "res://assets/models/weapons/feast_cleaver.glb", "label": "Take the carving cleaver"},
    {"id": "barrel_head", "at": at(BYRE_C[0] + 1.0, BYRE_C[1] + 7.5), "item": "item_barrel_head", "tag": "rime",
     "scene": "res://assets/models/props/barrel_head.tscn", "label": "Prise off the barrel head"},
    {"id": "ottar_staff", "at": [r2(HALL_X0 + 1.2), FY, r2(DOOR_Z - 1.6)], "item": "item_ottar_staff", "tag": "rime",
     "scene": "res://assets/models/props/ottar_stick.tscn", "label": "Take the walking stick", "set_flag": "ks_ottar_staff_found"},
    # TARNHALL.md 8: the hall guard's coat, on a peg on the gable wall beside the doors
    {"id": "hall_coat", "at": [r2(HALL_X0 + 0.45), FY, r2(DOOR_Z - 3.1)], "rot": 90, "item": "armour_hall", "tag": "rime",
     "scene": "res://assets/models/props/hall_coat.tscn", "label": "Take the coat off its peg"},
    {"id": "guest_tally", "at": [r2(HALL_X0 + 1.7), FY, r2(DOOR_Z + 2.4)], "item": "item_guest_tally", "tag": "rime",
     "scene": "res://assets/models/props/guest_tally.tscn", "label": "Untie the guest-tally",
     "appear_flag": "ks_host_released", "set_flag": "ks_guest_tally_found"},
    # WORLD.md 4.4: a scrap of woad wool on the latch, outside the barred door
    {"id": "latch_wool", "at": [r2(HALL_X0 - 0.75), PORCH_Y, r2(DOOR_Z + 0.7)], "lift": 1.05, "item": "item_latch_wool", "tag": "rime",
     "scene": "res://assets/models/props/latch_wool.tscn", "label": "Take the wool off the latch"},
]
npcs = [{"id": "lusse", "at": [r2(HALL_C[0] + 1.0), FY, r2(HALL_C[1] + 4.6)], "rot": 200, "tag": "thaw"},
        # just inside the front door with his boots on (TARNHALL.md 7)
        {"id": "ottar", "at": [r2(HALL_X0 + 2.2), FY, r2(DOOR_Z - 1.4)], "rot": 270, "tag": "thaw"}]

# --- points of interest (docs/lore/POI.md 5) -----------------------------------
# Set by hand on the south shore and on the island's two widened grounds
# (tarn_land: COOK_YARD, SOUTH_WALK). Nothing stands on the causeway or its
# bridge, and the porch keeps 1.2 m clear before the doors. "wayside": false
# keeps the wayside dressing from gathering round them; WAYSIDE_CLEAR keeps
# it, and the hall's own yard clutter, off their ground.
PLAQUES, SCRIPTED, WAYSIDE_CLEAR = [], [], []
POI = {"wayside": False}
KIT_M = "res://assets/models/"


def prop(kit, pos, rot=0.0, tag="base", **kw):
    PROPS.append(dict({"kit": kit, "at": pos, "rot": r2(rot), "tag": tag}, **kw))


def board(pos, rot, thaw=None, rime=None):
    """One wayside board; its caption turns with the state."""
    for tag, text in (("thaw", thaw), ("rime", rime)):
        if text:
            PLAQUES.append(dict(POI, at=pos, rot=rot, tag=tag, text=text))
    other = "rime" if rime is None else ("thaw" if thaw is None else None)
    if other:           # the board itself still stands in the state that has no caption
        prop("plaque", pos, rot, tag=other)   # solid, as the board that reads is (LorePlaque)


def face(frm, to):
    """The yaw that turns a thing at `frm` (facing -z at rest) toward `to`."""
    return r2(math.degrees(math.atan2(-(to[0] - frm[0]), -(to[1] - frm[1]))))


# 5.1 the Seven Landings: seven boats bow to the land on the south-west shore,
# beside the causeway's land end; one with its oars left in
def shore(a_deg, e):
    """A point on the tarn's shore ellipse at angle a (180 west, 90 south), at
    elliptic radius e (1 the shore's top, about 0.925 the waterline)."""
    a = math.radians(a_deg)
    lo, hi = 20.0, 70.0
    for _ in range(40):             # along the ray from the tarn's middle
        mid = (lo + hi) * 0.5
        if T.tarn_e(T.TARN_C[0] + math.cos(a) * mid, T.TARN_C[1] + math.sin(a) * mid) < e:
            lo = mid
        else:
            hi = mid
    return T.TARN_C[0] + math.cos(a) * lo, T.TARN_C[1] + math.sin(a) * lo


LANDING_A = [172.0, 165.0, 158.0, 151.0, 144.0, 137.0, 130.0]
OARS_IN = 3                         # the boat that was left ready to go
for k, a in enumerate(LANDING_A):
    bx, bz = shore(a, 0.865)
    lx, lz = shore(a, 1.0)
    yaw = r2(math.degrees(math.atan2(lx - bx, lz - bz)) + [3, -4, 2, 0, -3, 5, -2][k])     # bow to the land
    # THAW: afloat at the water's edge. RIME: in the ice to the gunwales.
    PROPS.append({"kit": "boat", "at": [r2(bx), T.TARN_Y - 0.12, r2(bz)], "rot": yaw, "tag": "thaw", "embed": True})
    PROPS.append({"kit": "boat", "at": [r2(bx), T.TARN_Y - 0.5, r2(bz)], "rot": yaw, "tag": "rime", "embed": True})
    if k == OARS_IN:
        PROPS.append({"kit": "th_boat_oars", "at": [r2(bx), T.TARN_Y + 0.38, r2(bz)], "rot": yaw, "tag": "thaw", "collide": False, "on": "boat"})
        PROPS.append({"kit": "th_boat_oars", "at": [r2(bx), T.TARN_Y + 0.0, r2(bz)], "rot": yaw, "tag": "rime", "collide": False, "on": "boat"})
_ox, _oz = shore(LANDING_A[OARS_IN], 1.035)
_gx, _gz = shore(LANDING_A[OARS_IN] + 1.6, 1.05)
LANDING_GUESTS = [
    {"id": "landing_guest_a", "at": at(_ox, _oz), "rot": face((_ox, _oz), (_gx, _gz)), "tag": "thaw"},
    {"id": "landing_guest_b", "at": at(_gx, _gz), "rot": face((_gx, _gz), (_ox, _oz)), "tag": "thaw"},
]
# the oars of the six boats that were drawn up properly, each neighbourhood's own cut
_sx, _sz = shore(176.5, 1.07)
OAR_STAND_ROT = face((_sx, _sz), shore(176.5, 0.8)) + 180
prop("th_oar_stand", at(_sx, _sz), OAR_STAND_ROT)
# the greatblade stood in the oar-stand (ADR 0015: a weapon to be found).
# Blades stay down at the boats at a feast; this one waits with the oars to be
# picked up on the way home. In both states, on the causeway side of the
# stand, 10 m off the causeway's land end and in sight of its hearth. The
# prompt is on the grass in front; the blade leans in against the rack.
_ra = math.radians(OAR_STAND_ROT)                      # 1.7 m along the stand's own x, 0.4 m along its z
_gx = _sx + 1.7 * math.cos(_ra) + 0.4 * math.sin(_ra)
_gz = _sz - 1.7 * math.sin(_ra) + 0.4 * math.cos(_ra)
OAR_BLADE = dict(POI, id="oar_greatblade", at=at(_gx, _gz), rot=r2(OAR_STAND_ROT), item="greatblade", tag="base",
                 label="Take the blade from the oar-stand", pose=[0, 0, 12], show_at=[-0.8, 0.0], lift=0.3)
for a in (161.5, 140.5):
    _cx, _cz = shore(a, 1.02)
    prop("rope_coil", at(_cx, _cz), a * 3 % 360, collide=False)
# the board stands where the hall's west doors show between two prows
_bx, _bz = shore((LANDING_A[2] + LANDING_A[3]) * 0.5, 1.075)
LANDING_BOARD = at(_bx, _bz)
board(LANDING_BOARD, face((_bx, _bz), (HALL_X0, DOOR_Z)) + 180,
      rime="THE TARN CAUSEWAY\n\nSeven boats. One was left ready to go, with the oars in.\nNobody came back down for any of them.")
_mx, _mz = shore(151.0, 1.0)
WAYSIDE_CLEAR.append([r2(_mx), r2(_mz), 19.0])

# 5.2 the Porch: what she put down to knock (RIME); wet cloaks and sticks (THAW)
ROWAN = dict(POI, id="rowan_stick", at=[r2(HALL_X0 - 1.0), PORCH_Y, r2(DOOR_Z - 1.4)], item="item_rowan_stick", tag="rime",
             scene=KIT_M + "props/rowan_stick.tscn", label="Take the stick")
WALL_X = HALL_X0 - 0.24             # the gable's outer face, on the porch
prop("th_horn_rack", [WALL_X, PORCH_Y, r2(DOOR_Z - 4.3)], -90, collide=False, on="wall")
prop("th_hanging", [WALL_X, PORCH_Y + 0.5, r2(DOOR_Z + 4.4)], -90, collide=False, on="wall")
for k, dz in enumerate((2.3, 2.9)):
    LANDMARKS.append({"scene": KIT_M + "props/hall_coat.tscn", "at": [r2(WALL_X - 0.12), PORCH_Y, r2(DOOR_Z + dz)], "rot": -90, "tag": "thaw"})
for k, dz in enumerate((-2.5, -2.75)):
    LANDMARKS.append({"scene": KIT_M + "props/ottar_stick.tscn", "at": [r2(WALL_X - 0.3), PORCH_Y, r2(DOOR_Z + dz)], "rot": -90 + 25 * k,
                      "tilt": -11.0, "tag": "thaw"})

# 5.3 the Cook-Yard: the terrace behind the hall's east half
CY_X0, CY_Z0, CY_X1, CY_Z1 = T.COOK_YARD


def yard(x, z, dy=0.0):
    return [r2(x), r2(FY + dy), r2(z)]


# the retaining wall's face, and a low parapet along the open north side
BOXES.append({"min": [CY_X0 - 0.3, T.TARN_Y - 1.4, CY_Z0 - 0.45], "max": [CY_X1 + 0.3, FY - 0.02, CY_Z0 - 0.02], "mat": "M_drystone",
              "tag": "base", "collide": False})
BOXES.append({"min": [CY_X0, FY - 0.3, CY_Z0 - 0.1], "max": [CY_X1, FY + 0.55, CY_Z0 + 0.4], "mat": "M_drystone", "tag": "base"})
VAT = (CY_X0 + 8.0, CY_Z0 + 3.3)
prop("th_ale_vat", yard(*VAT), 180)
SPIT = (CY_X0 + 3.4, CY_Z0 + 2.5)
prop("th_spit", yard(*SPIT), 0)
prop("hearth_fire", yard(SPIT[0], SPIT[1], 0.12), 90, tag="thaw", collide=False, embed=True, on="spit", scale=0.8)
prop("th_bake_oven", yard(CY_X1 - 2.2, CY_Z0 + 2.1), 180)
prop("th_carving_frame", yard(CY_X0 + 1.6, CY_Z1 - 1.3), 90)
prop("th_trestles", yard(CY_X0 + 9.6, CY_Z1 - 1.0), 0)
prop("th_ale_tub", yard(VAT[0] + 2.6, VAT[1] - 0.9), 30)
COOKS = [
    {"id": "cook_a", "at": yard(VAT[0] - 1.5, VAT[1] + 0.9), "rot": face((VAT[0] - 1.5, VAT[1] + 0.9), VAT), "tag": "thaw"},
    {"id": "cook_b", "at": yard(VAT[0] + 0.2, VAT[1] + 1.7), "rot": face((VAT[0] + 0.2, VAT[1] + 1.7), VAT), "tag": "thaw"},
]
# RIME: two Cupbearers, one each side of the vat (they work as a pair: data "flank")
CUPBEARERS = [
    {"enemy": "cupbearer", "stand_in": "keener", "id": "cupbearer_vat_a", "at": yard(VAT[0] - 2.0, VAT[1] + 0.2, 0.1), "face": 270},
    {"enemy": "cupbearer", "stand_in": "keener", "id": "cupbearer_vat_b", "at": yard(VAT[0] + 2.0, VAT[1] + 0.4, 0.1), "face": 90},
]
DIPPER = dict(POI, id="vat_dipper", at=yard(VAT[0] + 0.2, VAT[1] + 1.25), lift=1.2, item="item_vat_dipper", tag="rime",
              scene=KIT_M + "props/vat_dipper.tscn", label="Take the dipper")
WAYSIDE_CLEAR.append([(CY_X0 + CY_X1) * 0.5, (CY_Z0 + CY_Z1) * 0.5 + 1.0, 11.0])
WAYSIDE_CLEAR.append([HALL_X1 + 1.0, CY_Z1 + 1.5, 5.0])        # the walk round the hall's north-east corner

# 5.4 the South Window: a horn pane out, at eye height, on the walk along the south wall
WIN_X = 190.0
WIN_Z = HALL_C[1] + HALL_W / 2 + 0.22            # the wall's outer face
prop("th_horn_window", [WIN_X, FY + 1.25, r2(WIN_Z)], 0, collide=False, on="wall")
prop("th_pail", [WIN_X + 0.35, FY, r2(WIN_Z + 0.42)], 20, collide=False)
prop("th_rush_bundles", [WIN_X - 3.1, FY, r2(WIN_Z + 0.75)], 90)
for tag, cap in (("thaw", "They are on the ninth verse. The high seat is empty."),
                 ("rime", "Everyone is sitting down. One man is on his feet, going along the table with a horn.")):
    SCRIPTED.append({"script": "res://src/world/look_in.gd", "at": [WIN_X, FY, r2(WIN_Z + 0.1)], "rot": 0, "tag": tag,
                     "params": {"prompt": "Look in", "caption": cap, "seconds": 4.0,
                                "eye": [0.0, 1.52, 0.12], "look_at_local": [3.5, 1.0, r2(TABLE_Z - WIN_Z)]}})
SW = T.SOUTH_WALK
x = SW[0] + 3.0
while x < SW[2]:
    WAYSIDE_CLEAR.append([r2(x), r2((SW[1] + SW[3]) * 0.5), 3.4])
    x += 5.0

pickups += [ROWAN, DIPPER, OAR_BLADE]
spawners += CUPBEARERS
npcs += LANDING_GUESTS + COOKS
# --- end of points of interest ------------------------------------------------

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

# THAW shade fills (area_builder "shade_fills"): the top of the Tarn Steps, the
# causeway and the hall's porch sit in the gorge's shade, which read murky on
# the GPU. A soft cool light 4 m up at each, THAW only (RIME is unchanged).
SHADE_FILLS = []
_shade = [(x, z) for (x, z, _y) in T.STEPS[3:]]
(_cax, _caz), (_cbx, _cbz) = T.CAUSEWAY
_shade += [((_cax + _cbx) / 2, (_caz + _cbz) / 2), (_cbx, _cbz)]
_shade += [(HALL_X0 - 3.0, DOOR_Z), (139.0, -300.0), (150.0, -306.0)]   # the porch; the board on the shore walk
for (_px, _pz) in _shade:
    SHADE_FILLS.append({"at": at(_px, _pz, 4.0), "range": 18.0, "energy": 3.0, "color": [0.86, 0.9, 1.0], "tag": "thaw"})

D = {
    "id": "tarnhall",
    "name": "Tarnhall",
    "start": {"pos": START, "yaw": arrive["spawn_yaw"]},
    # THAW: clear evening light (not a dusk-orange wash), a soft bounce
    "env": {"thaw": {"sun_rot": [-20, -110], "sun_energy": 2.6, "sun_color": [1.0, 0.9, 0.74], "fog_density": 0.001, "vol_density": 0.004,
                     "ambient": [0.36, 0.35, 0.34], "ambient_energy": 0.78, "exposure": 1.12, "saturation": 0.98,
                     "fill_color": [0.92, 0.84, 0.72], "fill_energy": 0.45, "fill_rot": [24, 70]},
            "rime": {"sun_rot": [-26, -70], "fog_density": 0.006, "vol_density": 0.016}},
    # the Tarn Steps: mist pooled in the cleft of the stair (Job 4); thin in
    # THAW, where a denser pocket read as brown smog (Job 5)
    "fog_pockets": [{"id": "tarn_steps", "at": [82, 15, -316], "size": [32, 12, 32], "density": [0.006, 0.05], "height_falloff": 0.5}],
    "terrain": K.terrain_block(),
    "nav_bounds": [24, -16, -400, 280, 90, -256],
    "weather": {"gulls": False, "spindrift": 10},
    "water": water,
    "falls": FALLS,
    # light coming down through the smoke-holes onto the hearth (THAW)
    "scripted": [{"script": "res://src/world/god_rays.gd", "at": sh, "tag": "thaw",
                  "params": {"count": 3, "span_x": 2.5, "span_z": 1.6, "sun": [-78, -100], "seed_v": k3}}
                 for k3, sh in enumerate(SMOKE_HOLES)] + SCRIPTED,
    "wayside_clear": WAYSIDE_CLEAR,
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
                 "text": "TARNHALL\n\nSeven neighbourhoods came up the water every Long Light to feast here."}] + PLAQUES,
    "pickups": pickups,
    "portals": [portal, wood_seam("tarnhall")],
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
    "shade_fills": SHADE_FILLS,
}

# --- progression gates (ADR 0015) ---------------------------------------------
# The drove gate in the mouth of the notch: a dyke across it and a plank gate,
# barred from the Thornwold side like every other door Gaute barred. His
# release lifts this bar with the rest (TARNHALL.md 9). The track to it is
# terrain_tarnhall.DROVE_OUT.
import progress_gates as PG  # noqa: E402
import thorn_land as _TH  # noqa: E402
_na, _nb = _TH.NOTCH[0], _TH.NOTCH[1]
_nf = 0.87
DROVE_GATE = PG.gate(
    "tarnhall", "drove_gate", K.sample,
    at=(_na[0] + (_nb[0] - _na[0]) * _nf, _na[1] + (_nb[1] - _na[1]) * _nf), toward=(_nb[0] - _na[0], _nb[1] - _na[1]),
    flag="ks_host_released", name="the drove-road", to="thornwold", seam_at=wood_seam("tarnhall")["at"],
    width=3.6, height=2.5, flank="drystone", floor=T.TARN_Y - 0.9, leaves=True,
    locked_prompt="Barred from the other side", unbar_prompt="Unbar the gate", open_toast="The gate stands open.")
PG.install(D, DROVE_GATE)
# --- end progression gates

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "tarnhall.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
