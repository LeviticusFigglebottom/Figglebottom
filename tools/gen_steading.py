#!/usr/bin/env python3
"""Authoring script for data/areas/saltfell_steading.json: the Saltfell slice as
ONE continuous sea-cliff landscape (ADR 0003, 0004).

    the Strand (shingle cove, boat-shed, sea stack)
      -> the cliff path (three switchback legs cut into the face)
      -> Saltfell yard on the turf shelf (longhouse, byre, store-house, racks,
         the Salt House hearth)
      -> the Longhouse (the Netmender, behind the frost veil)
    loop:  the gully from the yard down to the boat-shed's back door, barred
           from the inside: unbar it from above and the Boat-Shed hearth is a
           short walk from the yard
    rime:  the tidal channel freezes; walk it to the sea stack (bog-iron)
    vista: the Lowe barrow hills across the ravine to the north

Everything is placed ON the committed terrain (tools/terrain_saltfell.py).
Run: python3 tools/gen_steading.py [--keep-terrain]   (rewrites the terrain bins)"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_saltfell as T  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--keep-terrain" not in sys.argv:
    T.write()      # the land first: everything below is seated on it


def r2(v):
    return round(v, 2)


def ground(x, z):
    return r2(T.sample(x, z))


def at(x, z, dy=0.0):
    return [r2(x), r2(ground(x, z) + dy), r2(z)]


def rot_off(cx, cz, yaw, ox, oz):
    """Local (ox, oz) offset turned by yaw (Godot rotation.y, degrees)."""
    a = math.radians(yaw)
    return (cx + ox * math.cos(a) + oz * math.sin(a), cz - ox * math.sin(a) + oz * math.cos(a))


PIECES, PROPS, BOXES, BUILDINGS = [], [], [], []


def building(name, cx, cz, w, l, yaw, y, doors=(), open_sides=(), roof=True, skip=()):
    """A turf-roofed house of 4 m wall bays: w along local x, l along local z.
    doors: [(side, index)] where side is N/S/E/W (local -z/+z/+x/-x) and index
    the bay along that side. skip: bays left out (a gate fills them)."""
    out = {}
    half_w, half_l = w / 2.0, l / 2.0
    sides = {
        "N": [(-half_w + 2 + 4 * i, -half_l) for i in range(int(w // 4))],
        "S": [(-half_w + 2 + 4 * i, half_l) for i in range(int(w // 4))],
        "W": [(-half_w, -half_l + 2 + 4 * i) for i in range(int(l // 4))],
        "E": [(half_w, -half_l + 2 + 4 * i) for i in range(int(l // 4))],
    }
    rots = {"N": 0, "S": 180, "W": 90, "E": -90}
    for side, offs in sides.items():
        if side in open_sides:
            continue
        for i, (ox, oz) in enumerate(offs):
            x, z = rot_off(cx, cz, yaw, ox, oz)
            if (side, i) in skip:
                continue
            kit = "portal_4m" if (side, i) in doors else "wall_4x4"
            PIECES.append({"kit": kit, "at": [r2(x), y, r2(z)], "rot": r2(yaw + rots[side])})
            if kit == "portal_4m":
                out[(side, i)] = (x, z, yaw + rots[side])
    for sx in (-1, 1):
        for sz in (-1, 1):
            x, z = rot_off(cx, cz, yaw, sx * half_w, sz * half_l)
            PIECES.append({"kit": "column_4m", "at": [r2(x), y, r2(z)]})
    if roof:
        gable = "gable_12m" if w >= 12 else "gable_8m"
        for i in range(int(l // 4)):
            x, z = rot_off(cx, cz, yaw, 0, -half_l + 2 + 4 * i)
            PIECES.append({"kit": gable, "at": [r2(x), y + 4.0, r2(z)], "rot": r2(yaw + 90), "collide": False})
        for sz in (-1, 1):
            x, z = rot_off(cx, cz, yaw, 0, sz * half_l)
            PIECES.append({"kit": gable.replace("gable_", "gable_end_"), "at": [r2(x), y + 4.0, r2(z)],
                           "rot": r2(yaw), "collide": False})
    BUILDINGS.append({"id": name, "center": [r2(cx), r2(cz)], "size": [w, l], "yaw": yaw, "y": y,
                      "doors": [[r2(v[0]), r2(v[1])] for v in out.values()], "open": list(open_sides)})
    return out


def prop(kit, x, z, rot=0, tag="base", **kw):
    d = {"kit": kit, "at": at(x, z), "rot": rot}
    if tag != "base":
        d["tag"] = tag
    d.update(kw)
    PROPS.append(d)
    return d


# ----------------------------------------------------------------- buildings
SH = T.SHELF_Y
LH_DOOR_Z = -20.0
building("longhouse", 0.0, -36.0, 12, 32, 0.0, SH, doors=[("S", 1)])
byre_doors = building("byre", -27.0, -14.0, 8, 12, -9.0, SH, doors=[("E", 1)])
store_doors = building("store", 22.0, -14.0, 8, 8, 13.0, SH, doors=[("W", 0)])
# the boat-shed: open to the sea; its back door (north, middle bay) is the
# shortcut gate, barred on the inside
GATE_AT = [25.0, T.BEACH_FOOT, 48.0]
building("boatshed", 25.0, 54.0, 12, 12, 0.0, T.BEACH_FOOT, doors=[("N", 1)], open_sides=("S",))

# the longhouse floor: boards laid over the flattened pad (no collision: the
# pad IS the floor), the long hearth kerb down the middle (waist-high cover)
BOXES.append({"min": [-5.8, SH - 0.02, -51.8], "max": [5.8, SH + 0.02, -20.2], "mat": "M_wood", "collide": False})
BOXES.append({"min": [-0.9, SH, -38.0], "max": [0.9, SH + 0.55, -25.0], "mat": "M_stone_trim"})
BOXES.append({"min": [-0.6, SH + 0.5, -37.6], "max": [0.6, SH + 0.57, -25.4], "mat": "M_peat", "collide": False})
for i in range(6):
    z = -48.0 + i * 4.6
    for x in (-3.4, 3.4):
        PIECES.append({"kit": "column_4m", "at": [x, SH, r2(z)]})

# ----------------------------------------------------------------- props
# the Strand
prop("boat", -6.0, 70.5, 8, tag="thaw", collide=True)             # Brede's, oars ready
prop("boat", 6.0, 66.0, -6)
prop("boat", 13.0, 64.5, 4, tag="thaw")
prop("boat", 28.5, 52.0, 0, collide=True)                         # the keel in the shed
for x, z, r in [(-40, 63.5, 18), (-31, 65.5, 12), (-22, 63.0, 22), (-48, 66.5, 28)]:
    prop("drying_rack", x, z, r)
# the yard
for x, z, r in [(-9, 9, 31), (-15, 13, 36), (7, 15, -21), (12, 11, -24)]:
    prop("drying_rack", x, z, r)
prop("well", 6.0, -2.0, 17)
for x, z, r in [(-34, 27.0, 8), (-29.5, 28.5, -5), (-38.5, 26.0, 14)]:
    prop("salt_pan", x, z, r)
prop("brazier", -25.0, 27.0, 0, tag="thaw")
prop("woodpile", 16.5, -8.0, 103)
prop("barrel", 17.0, -10.5, 0, tag="thaw")
prop("crate", 26.5, -9.5, 22, tag="thaw")
prop("crate", 18.0, -5.5, 40, tag="rime")
prop("barrel", -21.0, -9.0, 0)
# the longhouse: thaw laid for eleven; rime dragged to the walls
for z in (-27.0, -31.0, -35.0):
    PROPS.append({"kit": "table_3m", "at": [-2.2, SH, z], "rot": 90, "tag": "thaw"})
    PROPS.append({"kit": "bench_3m", "at": [-2.9, SH, z], "rot": 90, "tag": "thaw"})
for z in (-23.5, -44.0):
    for x in (-4.6, 4.6):
        PROPS.append({"kit": "brazier", "at": [x, SH, z], "tag": "thaw", "glow": [1.4, 2.4, 11]})
        PROPS.append({"kit": "brazier", "at": [x, SH, z], "tag": "rime", "flames": False, "glow": [2.2, 1.6, 14]})
for i, z in enumerate((-29.0, -34.0, -40.0)):
    PROPS.append({"kit": "table_3m", "at": [-5.0, SH, z], "rot": 90 + i * 4 - 4, "tag": "rime"})
for (x, z, r) in [(2.4, -30.0, 30), (-2.2, -42.5, 110), (2.6, -47.5, 70)]:
    PROPS.append({"kit": "rime_spike", "at": [x, SH, z], "rot": r, "tag": "rime"})
PROPS.append({"kit": "bench_3m", "at": [0, SH, -50.6], "scale": [1.2, 1.4, 1.4]})

# ----------------------------------------------------------------- entities
hearths = [
    {"id": "hs_boat_shed", "name": "the Boat-Shed", "at": at(23.0, 55.5), "rot": 0},
    {"id": "hs_salt_house", "name": "the Salt House", "at": at(-26.0, 23.5), "rot": 200},
]
sd = store_doors[("W", 0)]
sd = rot_off(sd[0], sd[1], 13.0, -1.8, 0)
spawners = [
    # the Strand
    {"enemy": "rimewalker", "id": "strand_racks_a", "at": at(-35.0, 68.0, 0.1), "face": 160},
    {"enemy": "rimewalker", "id": "strand_racks_b", "at": at(-26.0, 69.0, 0.1), "face": -140},
    {"enemy": "rimewalker", "id": "strand_racks_c", "at": at(-45.0, 70.0, 0.1), "face": 120},
    {"enemy": "oarsman", "id": "strand_waterline", "at": at(9.0, 76.5, 0.1), "face": 0},
    # the cliff path: the west turn
    {"enemy": "rimewalker", "id": "path_turn", "at": at(-64.0, 46.0, 0.1), "face": 90},
    # the yard
    {"enemy": "rimewalker", "id": "yard_racks", "at": at(-4.0, 12.0, 0.1), "face": 160},
    {"enemy": "rimewalker", "id": "yard_store", "at": at(sd[0], sd[1], 0.1), "face": -100},
    {"enemy": "rimewalker", "id": "yard_graves", "at": at(40.0, 17.0, 0.1), "face": 30},
    {"enemy": "oarsman", "id": "cliff_edge_e", "at": at(36.0, 30.0, 0.1), "face": 0},
    {"enemy": "hearthhound", "id": "byre_hound", "at": at(-27.0, -13.0, 0.1), "face": -90},
    {"enemy": "hearthhound", "id": "yard_hound", "at": at(-14.0, -22.0, 0.1), "face": 200},
    {"enemy": "netmender", "id": "netmender", "at": [0.0, SH + 0.1, -46.0], "face": 180,
     "dead_once": True, "frost_veil_id": "hall_veil"},
]
pickups = [
    {"id": "stores_headland", "at": at(-84.0, -4.0), "warmth": 40, "tag": "base", "label": "Take the hidden stores"},
    {"id": "bog_iron_stack", "at": at(-30.0, 104.5), "item": "bog_iron", "count": 2, "tag": "rime",
     "label": "Pry up the bog-iron"},
    {"id": "gully_cache", "at": at(25.4, 30.0), "warmth": 30, "tag": "rime", "label": "Take what was dropped"},
]
npcs = [
    {"id": "steward_ingra", "at": at(14.0, -5.0), "rot": -60, "tag": "thaw"},
    {"id": "brede", "at": at(-6.2, 73.4), "rot": 160, "tag": "thaw"},
]
plaques = [
    {"at": at(-1.0, 60.5), "rot": 200, "text": "THE STRAND\n\nThe tide is out and the boats are drawn up.\nThe path to the house is cut into the cliff, west of the racks.\n\nKeep hearth in the boat-shed, and it will remember for you."},
    {"at": at(3.4, -17.6), "rot": 180, "tag": "rime", "text": "THE LONGHOUSE\n\nThe door is iced shut from the inside.\nSomeone is still mending in there."},
]

# ----------------------------------------------------------------- the sea's edge
CH = T.CHANNEL
ICE_Z1 = 102.5
BOXES.append({"min": [CH["x0"], -0.6, CH["z0"]], "max": [CH["x1"], CH["y"], ICE_Z1], "mat": "M_ice", "tag": "rime"})
water = [
    {"at": [0, 0.0, 0], "size": [4000, 4000]},                           # the sea
    {"at": [0, T.RAVINE_FLOOR + 0.6, -76], "size": [300, 40]},          # the river in the ravine
]
hazards = [
    {"kind": "drown", "min": [-1200, -40, -1200], "max": [1200, -1.15, 1200]},
    {"kind": "kill", "min": [-130, -10, -96], "max": [130, T.RAVINE_FLOOR + 4.0, -58]},
    {"kind": "fall", "min": [-84, -2, 28], "max": [64, 26, 92]},          # below the cliffs round the cove
    {"kind": "fall", "min": [18, 0, 6], "max": [32, 26, 50]},             # the gully
]

# ----------------------------------------------------------------- scatter
clear = []
for b in BUILDINGS:
    w, l = b["size"]
    clear.append([b["center"][0], b["center"][1], r2(math.hypot(w, l) * 0.5 + 1.5)])
for p in PROPS:
    clear.append([p["at"][0], p["at"][2], 2.2])
clear.append([-30.0, 90.0, 14.0])        # the channel stays clear
scatter = {
    "seed": 90210,
    "clear": clear,
    "rules": [
        {"kind": "rock", "count": 170, "region": [-74, 54, 56, 86], "slope": [0.85, 1.0], "h": [-0.6, 3.6], "scale": [0.3, 1.0]},
        {"kind": "boulder", "count": 70, "region": [-80, 38, 60, 62], "slope": [0.25, 0.9], "h": [2.0, 15.0], "scale": [0.8, 1.7], "path_max": 0.2},
        {"kind": "driftwood", "count": 26, "region": [-70, 60, 50, 80], "slope": [0.9, 1.0], "h": [0.3, 2.6], "scale": [0.8, 1.5]},
        {"kind": "rock", "count": 130, "region": [-96, -66, 60, 42], "slope": [0.8, 1.0], "h": [18, 30], "scale": [0.3, 0.9], "path_max": 0.2},
        {"kind": "boulder", "count": 26, "region": [-96, -66, 60, 30], "slope": [0.8, 1.0], "h": [18, 30], "scale": [0.9, 1.6], "path_max": 0.1},
        {"kind": "hummock", "count": 320, "region": [-96, -66, 60, 42], "slope": [0.86, 1.0], "h": [18, 30], "scale": [0.5, 1.2], "path_max": 0.25},
        {"kind": "boulder", "count": 60, "region": [56, -66, 128, 100], "slope": [0.3, 0.75], "h": [18, 70], "scale": [1.0, 2.0]},
        {"kind": "rock", "count": 90, "region": [56, -66, 128, 100], "slope": [0.3, 0.8], "h": [18, 70], "scale": [0.6, 1.4]},
        {"kind": "boulder", "count": 40, "region": [-100, -90, 120, -60], "slope": [0.2, 0.7], "h": [4, 26], "scale": [1.0, 2.2]},
        {"kind": "standing_stone", "count": 22, "region": [-96, -172, 100, -94], "slope": [0.85, 1.0], "scale": [0.9, 1.6]},
        {"kind": "rock", "count": 140, "region": [-96, -172, 100, -90], "slope": [0.8, 1.0], "scale": [0.4, 1.2]},
        {"kind": "hummock", "count": 220, "region": [-96, -172, 100, -90], "slope": [0.85, 1.0], "scale": [0.6, 1.4]},
        {"kind": "rock", "count": 18, "region": [-44, 100, -16, 126], "slope": [0.7, 1.0], "h": [0.1, 2.0], "scale": [0.4, 1.0]},
    ],
    "place": [
        {"kind": "peat_stack", "at": [-44.0, 2.0], "rot": 23},
        {"kind": "peat_stack", "at": [-46.5, -5.0], "rot": 61},
        {"kind": "peat_stack", "at": [33.0, -30.0], "rot": -14},
        {"kind": "hummock", "at": [41.0, 12.0], "scale": 1.3, "rot": 40},
        {"kind": "hummock", "at": [44.0, 14.5], "scale": 1.1, "rot": 10},
        {"kind": "hummock", "at": [43.5, 9.8], "scale": 0.8, "rot": 75},
        {"kind": "standing_stone", "at": [46.0, 11.5], "scale": 0.6, "rot": 12},
    ] + [
        # the tide froze mid-surge: a broken glass wall along the old waterline,
        # open where the channel runs out to the stack
        {"kind": "ice_floe", "at": [r2(x), r2(80.6 + 1.2 * math.sin(x * 0.37))],
         "scale": r2(1.5 + 0.6 * abs(math.sin(x * 1.7))), "rot": r2((x * 47) % 360), "tag": "rime"}
        for x in [i * 2.3 - 72 for i in range(55)] if not (-37.5 < x < -22.5)
    ],
    "fences": [
        {"kind": "drystone", "points": [[-50, -48], [-53, -30], [-51, -12], [-47, 4], [-49, 16]]},
        {"kind": "drystone", "points": [[36, -44], [40, -26], [38, -8]]},
        {"kind": "drystone", "points": [[34, 33], [42, 34.5], [49, 37.5]]},          # along the cliff top
        {"kind": "drystone", "points": [[-6, 37.5], [4, 38.5], [14, 36.0]]},         # along the cliff top
        {"kind": "drystone", "points": [[37, 9], [41, 6.5], [47, 7.5], [48.5, 13]]},  # round the graves
        {"kind": "wattle", "points": [[8, 18], [15, 16.5], [19, 21], [16, 26]]},     # the kailyard
        {"kind": "wattle", "points": [[-20, -24], [-14, -26], [-8, -24.5]]},
    ],
}

# ----------------------------------------------------------------- edges (audit)
edges = {
    "doc": "tools/audit_edges.py classes every walkable boundary: cliff, water, steep, building, thicket.",
    "walk_max_deg": 45.0,
    "water_level": 0.0,
    "drown_depth": 1.15,
    "nav_bounds": [-102, -76, 66, 128],
    "buildings": BUILDINGS,
    "thickets": [],
    "state_floors": [{"tag": "rime", "min": [CH["x0"], CH["z0"]], "max": [CH["x1"], ICE_Z1], "y": CH["y"]}],
    "gates": [{"id": "boatshed_back", "at": GATE_AT, "rot": 0}],
}

START = [-4.0, r2(T.sample(-4.0, 62.0) + 0.2), 62.0]
D = {
    "id": "saltfell_steading",
    "name": "Saltfell",
    "start": {"pos": START, "yaw": 200},
    "env": {"thaw": {"sun_rot": [-12, -36], "sun_energy": 2.2, "fog_density": 0.0012, "vol_density": 0.006},
            "rime": {"sun_rot": [-34, -30]}},
    "terrain": T.terrain_block(),
    "nav_bounds": [-102, -4, -76, 66, 64, 128],
    "water": water,
    "hazards": hazards,
    "zones": [
        {"name": "THE STRAND", "min": [-80, 50], "max": [60, 130]},
        {"name": "SALTFELL", "min": [-100, -19], "max": [70, 50]},
        {"name": "THE LONGHOUSE", "min": [-6, -52], "max": [6, -20]},
    ],
    "pieces": PIECES,
    "boxes": BOXES,
    "props": PROPS,
    "hearths": hearths,
    "gates": [{"id": "boatshed_back", "at": GATE_AT, "rot": 0, "locked_prompt": "Barred from the other side"}],
    "spawners": spawners,
    "frost_veils": [{"id": "hall_veil", "at": [0.0, SH, LH_DOOR_Z], "rot": 0, "tag": "rime"}],
    "npcs": npcs,
    "plaques": plaques,
    "pickups": pickups,
    "scatter": scatter,
    "edges": edges,
}

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "saltfell_steading.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
