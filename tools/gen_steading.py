#!/usr/bin/env python3
"""Authoring script for data/areas/saltfell_steading.json: the Saltfell slice as
ONE continuous sea-cliff landscape (ADR 0003, 0005).

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
from seams_lowe import seams  # noqa: E402

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


PIECES, PROPS, BOXES, BUILDINGS, HOUSES = [], [], [], [], []


def building(name, cx, cz, w, l, yaw, y, doors=(), open_sides=(), gate_doors=(), **house_kw):
    """A turf-and-stave house built by src/world/building_gen.gd: w along local
    x, l along local z. doors / gate_doors: [(side, bay)] where side is N/S/E/W
    (local -z/+z/+x/-x) and bay the 4 m bay along that side. A gate door is an
    opening the ShortcutGate fills. Returns door world positions by key."""
    out = {}
    half_w, half_l = w / 2.0, l / 2.0
    for side, i in list(doors) + list(gate_doors):
        span = w if side in "NS" else l
        t = -span / 2.0 + 2 + 4 * i
        ox, oz = {"N": (t, -half_l), "S": (t, half_l), "W": (-half_w, t), "E": (half_w, t)}[side]
        x, z = rot_off(cx, cz, yaw, ox, oz)
        out[(side, i)] = (x, z, yaw + {"N": 0, "S": 180, "W": 90, "E": -90}[side])
    wall_h = 3.5 if w >= 12 else 3.2
    HOUSES.append({"id": name, "center": [r2(cx), r2(cz)], "size": [w, l], "yaw": yaw, "y": y, "wall_h": wall_h,
                   "doors": [list(d) for d in doors], "gate_doors": [list(d) for d in gate_doors],
                   "open": list(open_sides), **house_kw})
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
building("boatshed", 25.0, 54.0, 12, 12, 0.0, T.BEACH_FOOT, gate_doors=[("N", 1)], open_sides=("S",))

# the longhouse floor: boards laid over the flattened pad (no collision: the
# pad IS the floor), the long hearth kerb down the middle (waist-high cover)
BOXES.append({"min": [-5.8, SH - 0.02, -51.8], "max": [5.8, SH + 0.02, -20.2], "mat": "M_wood", "collide": False})
# (the kerb is "low": cover for the Bearer, who must go round it; the 3 m
# Netmender steps over it, so it stays out of the navmesh)
BOXES.append({"min": [-0.8, SH, -36.0], "max": [0.8, SH + 0.55, -27.0], "mat": "M_stone_trim", "low": True})
BOXES.append({"min": [-0.55, SH + 0.5, -35.6], "max": [0.55, SH + 0.57, -27.4], "mat": "M_peat", "collide": False})
for i in range(6):
    z = -48.0 + i * 4.6
    for x in (-4.2, 4.2):
        PIECES.append({"kit": "column_4m", "at": [x, SH, r2(z)]})

# ----------------------------------------------------------------- props
# the Strand
prop("boat", -6.0, 70.5, 8, tag="thaw", collide=True)             # Brede's, oars ready
prop("boat", 6.0, 66.0, -6, collide=True)
prop("boat", 13.0, 64.5, 4, tag="thaw", collide=True)
prop("sf_boat_half", 28.5, 52.0, 0, collide=True)                 # on the stocks in the shed: keel, posts and four strakes
# (the Strand's racks stand in rows across the wind: see "the working shore" below)
# the yard: two racks end to end by the path, two side by side at the kailyard
for x, z, r in [(-9.0, 9.0, 33), (-13.2, 11.72, 33), (7.0, 15.0, -22)]:
    prop("drying_rack", x, z, r)
prop("sf_rack_low", 8.1, 12.0, -22)
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
    PROPS.append({"kit": "bench_3m", "at": [-3.1, SH, z], "rot": 90, "tag": "thaw"})
for z in (-23.5, -44.0):
    for x in (-2.6, 2.6):
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
    # cold and inert until the Netmender is released; then it catches (SLICE.md 1, 6).
    # Faces the door: the Bearer kneels (and wakes) on the open boards south of
    # it; at 180 the respawn point sat on the hearth kerb.
    {"id": "hs_long_hearth", "name": "the Long Hearth", "at": [0.0, SH, -26.4], "rot": 0,
     "require_flag": "ks_netmender_released"},
]
sd = store_doors[("W", 0)]
sd = rot_off(sd[0], sd[1], 13.0, -1.8, 0)
spawners = [
    # the Strand (SLICE.md 2, RIME): four along the racks, two of them sitting
    # at a chore and mending nothing; one Oarsman at the waterline facing the
    # sea; two more seated in a row, as though in a boat (beside the drawn-up
    # boat: the slice's one boat-shed holds the first hearth)
    {"enemy": "rimewalker", "id": "strand_racks_a", "at": at(-35.0, 68.0, 0.1), "face": 160},
    {"enemy": "rimewalker", "id": "strand_racks_b", "at": at(-26.0, 66.6, 0.1), "face": -140, "pose": "sit"},
    {"enemy": "rimewalker", "id": "strand_racks_c", "at": at(-45.0, 70.0, 0.1), "face": 120},
    {"enemy": "rimewalker", "id": "strand_racks_d", "at": at(-37.5, 61.0, 0.1), "face": 20, "pose": "sit"},
    {"enemy": "oarsman", "id": "strand_waterline", "at": at(9.0, 76.5, 0.1), "face": 180},
    {"enemy": "oarsman", "id": "strand_rower_bow", "at": at(2.6, 64.4, 0.1), "face": 174},
    {"enemy": "oarsman", "id": "strand_rower_stern", "at": at(2.8, 66.8, 0.1), "face": 174},
    # the yard (SLICE.md 3, RIME): three in the yard (one in the store-house
    # doorway, counting), a Hearthhound across the Longhouse threshold and one
    # in the byre (on the rye sack), two Oarsmen at the cliff edge, and one
    # sitting by the small grave
    {"enemy": "rimewalker", "id": "yard_racks", "at": at(-4.0, 12.0, 0.1), "face": 160},
    {"enemy": "rimewalker", "id": "yard_store", "at": at(sd[0], sd[1], 0.1), "face": -100},
    {"enemy": "rimewalker", "id": "yard_well", "at": at(2.0, 3.0, 0.1), "face": 200},
    {"enemy": "rimewalker", "id": "yard_graves", "at": at(40.0, 17.0, 0.1), "face": 30, "pose": "sit"},
    {"enemy": "oarsman", "id": "cliff_edge_e", "at": at(46.0, 33.0, 0.1), "face": 180},
    {"enemy": "oarsman", "id": "cliff_edge_w", "at": at(6.0, 34.0, 0.1), "face": 180},
    {"enemy": "hearthhound", "id": "byre_hound", "at": at(-27.0, -13.0, 0.1), "face": -90},
    {"enemy": "hearthhound", "id": "threshold_hound", "at": at(0.0, -16.6, 0.1), "face": 90},
    # the Longhouse: at the high end, her back to the door, mending
    {"enemy": "netmender", "id": "netmender", "at": [0.0, SH + 0.1, -46.0], "face": 0,
     "dead_once": True, "frost_veil_id": "hall_veil"},
]
pickups = [
    {"id": "stores_headland", "at": at(-84.0, -4.0), "warmth": 40, "tag": "base", "label": "Take the hidden stores"},
    {"id": "bog_iron_stack", "at": at(-30.0, 104.5), "item": "bog_iron", "count": 2, "tag": "rime",
     "label": "Pry up the bog-iron"},
    {"id": "gully_cache", "at": at(25.4, 30.0), "warmth": 30, "tag": "rime", "label": "Take what was dropped"},
    # Keepsakes (SLICE.md §7): Ingra's missing rye, under the byre hound
    {"id": "rye_sack", "at": at(-27.4, -11.9), "item": "item_rye_sack", "kit": "rye_sack", "tag": "rime",
     "set_flag": "ks_ingra_rye_found", "label": "Take the rye sack"},
    # and Brede's float, frozen into the face of the tide wall
    # frozen into the land face of the tide wall at chest height; a heavy blow
    # chips it free (SLICE.md 2). The prompt zone stays on the shingle.
    {"id": "net_float", "at": at(-8.0, 78.4), "item": "item_net_float", "kit": "net_float", "tag": "rime",
     "set_flag": "ks_brede_float_found", "label": "Chip the float out of the ice",
     "lift": 1.25, "chip_heavy": True},
    # the Mending Needle where she sat (SLICE.md 6). The release sets one down
    # at once (Game._release_leavings, same id); this entry keeps it there if
    # the journey is saved and resumed before it is taken.
    {"id": "mending_needle", "at": [0.0, SH + 0.02, -43.8], "item": "item_mending_needle",
     "scene": "res://assets/models/weapons/mending_needle.glb", "tag": "base",
     "require_flag": "ks_netmender_released", "label": "Take the mending needle"},
    # Wren's knucklebones, four of five, in the turf by the small grave (SLICE.md 8; THORNWOLD.md 7)
    {"id": "knucklebones", "at": at(42.0, 15.5), "item": "ks_knucklebones", "tag": "rime",
     "scene": "res://assets/models/props/knucklebone.tscn", "set_flag": "ks_knucklebones_found",
     "label": "Pick up the knucklebones"},
    # WORLD.md 4.1 (SLICE.md 3): the small mask on the low peg inside the Longhouse door
    {"id": "child_mask", "at": [2.6, SH, -20.75], "rot": 180, "lift": 0.95, "absent_flag": "ending_outsong", "item": "ks_child_mask", "tag": "base",
     "scene": "res://assets/models/props/child_mask.tscn", "label": "Take the small mask down"},
]
# the Longhouse floor in RIME is one frozen net (SLICE.md 4): the Netmender's
# arena; she hauls it and lights it (src/world/net_floor.gd)
# RIME: the tide froze mid-surge (SLICE.md 2). A glass wall ~3 m high along
# the old waterline, a metre or two seaward of it, open where the frozen
# channel runs out to the sea stack.
TIDE_LINE = [(-64, 76.6), (-54, 76.3), (-46, 76.0), (-38, 76.4), (-30, 76.6), (-22, 76.6),
             (-14, 77.8), (-6, 79.5), (2, 80.3), (10, 79.6), (18, 78.6), (26, 76.8),
             (34, 76.0), (44, 76.4)]
TIDE_WALL = {"script": "res://src/world/tide_wall.gd", "at": [0.0, 0.0, 0.0], "tag": "rime",
             "params": {"points": [[x, z] for x, z in TIDE_LINE], "height": 3.9, "gaps": [[-36.0, -23.0]], "base_y": -0.6}}

scripted = [
    {"script": "res://src/world/net_floor.gd", "at": [0.0, SH, -36.0], "tag": "rime",
     "params": {"size": [11.6, 31.6]}},
]
npcs = [
    {"id": "steward_ingra", "at": at(14.0, -5.0), "rot": -60, "tag": "thaw"},
    {"id": "brede", "at": at(-6.2, 73.4), "rot": 160, "tag": "thaw"},
]
plaques = [
    {"at": at(-1.0, 60.5), "rot": 200, "text": "THE STRAND\n\nThe tide is out and the boats are drawn up.\nThe path to the house is cut into the cliff, west of the racks.\nThe hearth is in the boat-shed."},
    {"at": at(3.4, -17.6), "rot": 180, "tag": "rime", "text": "THE LONGHOUSE\n\nThe door is iced shut from the inside.\nSomeone is still mending in there."},
]

# ----------------------------------------------------------------- points of interest
# docs/lore/POI.md 2, and Saltfell's own prop set (docs/art/BIOMES.md). Every
# piece here is set by hand, never by the scatter, so it survives a regenerate.
WAYSIDE_CLEAR = []       # [x, z, r]: ground Wayside leaves open (views, the furrow)
POI_CLEAR = []           # the same for the scatter


def slope_prop(kit, x, z, rot=0, span=2.0, tag="base", **kw):
    """A long piece laid on sloping ground: tilted to the beach under it."""
    a = math.radians(rot)
    zx, zz = math.sin(a), math.cos(a)
    xx, xz = math.cos(a), -math.sin(a)
    sz = (T.sample(x + zx * span, z + zz * span) - T.sample(x - zx * span, z - zz * span)) / (2 * span)
    sx = (T.sample(x + xx * 0.7, z + xz * 0.7) - T.sample(x - xx * 0.7, z - xz * 0.7)) / 1.4
    return prop(kit, x, z, rot, tag=tag, tilt=[r2(-math.degrees(math.atan(sz))), r2(math.degrees(math.atan(sx)))], **kw)


# --- 2.1 sf_drag_mark: the Drag-Mark (the Strand) ---------------------------
# THAW: Brede's boat on its rollers, a second run laid ready beside it.
# RIME: the boat is gone; one furrow goes up the beach beside both runs.
BREDE_BOAT = next(p for p in PROPS if p["kit"] == "boat" and p.get("tag") == "thaw" and p.get("collide"))
BREDE_BOAT["lift"] = 0.15                                      # sat on the rollers
slope_prop("sf_roller_run", -6.1, 69.8, 8, collide=False)
slope_prop("sf_roller_run", -2.6, 69.4, 11, collide=False)
DRAG_LINE = [(-8.6, 74.2), (-9.3, 70.0), (-10.4, 66.0), (-11.9, 62.0), (-13.6, 58.6), (-14.8, 56.6)]
DRAG_HALF = [-1.05, -0.72, -0.46, -0.2, 0.0, 0.2, 0.46, 0.72, 1.05]     # across the mark, metres


def _drag_rows():
    rows = []
    for (ax, az), (bx, bz) in zip(DRAG_LINE, DRAG_LINE[1:]):
        ln = math.hypot(bx - ax, bz - az)
        n = max(2, int(ln / 0.7))
        for k in range(n + (1 if (bx, bz) == DRAG_LINE[-1] else 0)):
            t = k / n
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            # she did not pull straight: the line wanders a hand either way
            w = 0.12 * math.sin(len(rows) * 0.9)
            nx, nz = -(bz - az) / ln, (bx - ax) / ln
            rows.append([[r2(x + nx * (o + w)), ground(x + nx * (o + w), z + nz * (o + w)), r2(z + nz * (o + w))] for o in DRAG_HALF])
    return rows


DRAG_FURROW = {"script": "res://src/world/drag_furrow.gd", "at": [0.0, 0.0, 0.0], "tag": "rime", "params": {"rows": _drag_rows()}}
for (x, z) in DRAG_LINE:
    POI_CLEAR.append([x, z, 2.6])
    WAYSIDE_CLEAR.append([x, z, 5.0])
plaques.append({"at": at(-10.9, 73.6), "rot": 110, "tag": "rime",
                "text": "THE STRAND\n\nOne boat went up the beach.\nThe rollers were lying beside it the whole way."})
pickups.append({"id": "thole_pin", "at": at(-10.6, 65.4), "item": "item_thole_pin", "kit": "sf_thole_pin", "tag": "rime",
                "label": "Pick up the thole pin"})

# --- 2.2 sf_salt_house: the Salt House (the yard's cliff edge) -----------------
# The house the hearth is named for: two salt-boilers inside it in THAW, never
# seen; in RIME the pan outside it has boiled dry and split.
salt_doors = building("salthouse", -39.5, 19.5, 8, 8, -8.0, r2(SH + 0.1), doors=[("E", 1)], style="fish", gable="shed")
SALT_DOOR = salt_doors[("E", 1)]
_sx, _sz = rot_off(SALT_DOOR[0], SALT_DOOR[1], -8.0, -1.6, 0.0)       # a pace inside the door
npcs.append({"id": "salt_boilers", "at": [r2(_sx), r2(SH + 0.1), r2(_sz)], "rot": 0, "tag": "thaw"})
# the pan by the door: whole in THAW, split in RIME (the other two pans stay)
SPLIT_PAN = next(p for p in PROPS if p["kit"] == "salt_pan" and p["at"][0] == -34.0)
SPLIT_PAN["tag"] = "thaw"
prop("sf_salt_pan_split", -34.0, 27.0, 8, tag="rime")
# (the prompt stands at the pan's kerb; the cake lies in the pan)
pickups.append({"id": "pan_salt", "at": at(-34.3, 28.25), "item": "item_pan_salt", "kit": "sf_pan_salt", "tag": "rime",
                "label": "Lift out the salt", "lift": 0.26, "show_at": [0.5, -0.95]})
prop("sf_brine_trough", -33.7, 18.9, 82)
prop("sf_salt_basket", -30.9, 24.9, 24)
prop("sf_salt_basket", -33.4, 23.9, -70)
prop("sf_salt_sacks", -34.3, 16.3, 82)                            # sacked and stacked by the door, for the store

# --- 2.3 sf_cliff_graves: the Cliff Graves (the turf terrace, east) -----------
# Two plaques on one board. The small grave: closed in THAW with today's
# thrift on it; in RIME opened from above, the turf laid to one side in the
# order it came off (lw_sod_row, the one Lowe piece used outside the Lowe).
GRAVE_BOARD = at(38.6, 13.4)
plaques.append({"at": GRAVE_BOARD, "rot": 250, "tag": "thaw",
                "text": "THE CLIFF GRAVES\n\nFisherfolk lie here with their feet to the water.\nThe small one is new. The thrift on it was picked today."})
plaques.append({"at": GRAVE_BOARD, "rot": 250, "tag": "rime",
                "text": "THE CLIFF GRAVES\n\nThe small one was opened from above, with a spade.\nThe turf was laid to one side, grass up, in the order it came off."})
prop("sf_small_grave", 42.6, 17.6, 96, tag="thaw", collide=False)
prop("sf_small_grave_open", 42.6, 17.6, 96, tag="rime", collide=False)
prop("lw_sod_row", 44.3, 17.9, 96, tag="rime", collide=False)
prop("sf_turf_spade", 41.5, 18.6, 40, tag="rime", collide=False)
WAYSIDE_CLEAR.append([42.0, 20.0, 9.0])          # the view of the frozen tide stays open

# --- 2.4 sf_lookout_stone: the Lookout Stone (the west headland) --------------
# A flat stone at the cliff edge that faces up the coast toward Kettle Fjord.
# THAW: a net-needle case left on it. RIME: three bowls, one inside the next.
LOOKOUT = (-94.6, -5.0)
LOOKOUT_TOP = 0.36
prop("sf_lookout_stone", LOOKOUT[0], LOOKOUT[1], 74)
prop("sf_needle_case", LOOKOUT[0] + 0.18, LOOKOUT[1] - 0.55, 30, tag="thaw", collide=False, lift=LOOKOUT_TOP)
pickups.append({"id": "three_bowls", "at": at(LOOKOUT[0] + 0.75, LOOKOUT[1] + 0.25), "item": "item_three_bowls", "kit": "sf_three_bowls",
                "tag": "rime", "label": "Take the bowls", "lift": LOOKOUT_TOP, "show_at": [-0.7, -0.2]})
# the wind-break behind it, and the sinkers hung to dry on its rail
LOOKOUT_WALL = [[-89.2, -10.5], [-88.4, -6.0], [-89.0, -1.5]]
prop("sf_net_sinkers", -89.6, -6.2, 96)
WAYSIDE_CLEAR.append([LOOKOUT[0], LOOKOUT[1], 15.0])

# --- the working shore: everything where the work is done --------------------
# (owner's playtest: props were strewn. Nothing here is random: Wayside is off
# for Saltfell, and each piece stands where the job it is for is done.)
# Boats are hauled bow to the land, above the tide line, each on its own run
# of rollers; the capstan that hauls them stands at the head of the runs.
for b in [p for p in PROPS if p["kit"] == "boat" and p["at"][2] > 60.0 and p is not BREDE_BOAT]:
    b["lift"] = 0.15
    slope_prop("sf_roller_run", b["at"][0] - 0.1, b["at"][2] - 0.7, b["rot"], collide=False)
slope_prop("sf_capstan", 6.6, 60.4, 172, span=0.9)
# the racks: two rows across the onshore wind, west of the path's foot, the
# gutting bench at the row's seaward end and the sinkers on their rail beside it
RACK_ROT = 4.0
for x in (-46.5, -41.0, -35.5):
    slope_prop("drying_rack", x, 63.2, RACK_ROT, span=0.6)
for x in (-43.8, -38.3):                       # the seaward row: the tall racks, for the stockfish
    slope_prop("sf_rack_tall", x, 67.0, RACK_ROT, span=0.6)
slope_prop("sf_gutting_bench", -30.6, 64.6, RACK_ROT, span=0.5)
slope_prop("sf_net_sinkers", -27.4, 62.6, RACK_ROT + 90, span=0.3)
# the boat-shed: oars racked against its west wall, the tar pot and the boat
# turned over for tarring in front of it, out of the path's way
prop("sf_oar_rack", 17.9, 56.4, 90)
prop("boat_upturned", 12.4, 58.3, 82)
slope_prop("sf_tar_pot", 14.4, 61.2, 0, span=0.4)
# variety, each at its work (owner: more kinds, fewer repeats)
slope_prop("sf_rack_low", -49.6, 66.4, RACK_ROT, span=0.5)       # flatfish, at the west end of the seaward row
slope_prop("sf_fish_barrels", -28.0, 67.0, 30, span=0.4)         # what the bench fills
slope_prop("sf_net_pile", -0.4, 71.8, 40, span=0.3)              # Brede's net, by his boat
slope_prop("sf_net_pile", 18.3, 60.6, -20, span=0.3)             # and the shed's
slope_prop("sf_mooring_post", -6.7, 65.6, 10, span=0.3)          # a post at the head of a run: what a hauled boat is made fast to
slope_prop("sf_mooring_post", 5.2, 62.4, 80, span=0.3)
prop("sf_fish_barrels", -9.0, 17.0, 120)                         # the yard bench's
prop("sf_salt_sacks", 17.2, -17.4, 13)                           # at the store-house wall
# kelp carried up off the wrack line to dry on the old walls at the beach head
slope_prop("sf_kelp_rick", -55.0, 63.6, 6, span=0.4)
slope_prop("sf_kelp_rick", 40.5, 62.0, -8, span=0.4)
prop("sf_gutting_bench", -11.2, 14.6, 33)                       # the yard: at the end of its racks
# what the cliff-top road is marked by (was Wayside's): one cairn where the
# path gains the shelf, one where the road turns for the pass
CAIRNS = [(-58.0, 24.5, 30, 1.0), (-78.0, -52.0, 110, 0.9)]

# ----------------------------------------------------------------- the sea's edge
CH = T.CHANNEL
ICE_Z1 = 102.5
# the frozen channel: an invisible sheet carries you; broken floes show where
BLOCKERS = [{"min": [CH["x0"] + 0.8, -0.6, CH["z0"]], "max": [CH["x1"] - 0.8, CH["y"], ICE_Z1], "tag": "rime"}]
FLOES = []
for k in range(14):
    z = CH["z0"] + 1.0 + k * 1.9
    for side in (-1, 1):
        x = -30.0 + side * (0.9 + 0.5 * math.sin(k * 1.7 + side)) + 0.6 * math.sin(k * 0.9)
        FLOES.append({"kind": "ice_floe", "at": [r2(x), r2(z + side * 0.5)], "y": -0.06,
                      "scale": [r2(2.0 + 0.5 * abs(math.sin(k * 2.3 + side))), 0.42, r2(1.8 + 0.4 * abs(math.cos(k * 1.3)))],
                      "rot": r2((k * 61 + side * 37) % 360), "tag": "rime"})
water = [
    {"at": [0, 0.0, 0], "size": [4000, 4000]},                           # the sea
    {"at": [25, T.RAVINE_FLOOR + 0.6, -76], "size": [210, 44]},         # the river in the ravine
]
hazards = [
    {"kind": "drown", "min": [-1200, -40, -1200], "max": [1200, -1.15, 1200]},
    {"kind": "kill", "min": [T.RAVINE_HEAD_X + 2, -10, -112], "max": [130, T.RAVINE_FLOOR + 4.0, -50]},
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
clear += POI_CLEAR
for k in range(15):                       # and so does the gully
    z = T.GULLY_Z0 + k * 3.0
    clear.append([r2(T.gully_x(z)), r2(z), 3.2])
scatter = {
    "seed": 90210,
    "clear": clear,
    "rules": [
        {"kind": "rock", "count": 170, "region": [-74, 54, 56, 86], "slope": [0.85, 1.0], "h": [-0.6, 3.6], "scale": [0.3, 1.0]},
        {"kind": "boulder", "count": 40, "region": [-6, 40, 60, 62], "slope": [0.55, 0.95], "h": [2.8, 7.0], "scale": [0.8, 1.7], "path_max": 0.2},
        {"kind": "boulder", "count": 14, "region": [-80, 40, -66, 70], "slope": [0.55, 0.95], "h": [2.8, 7.0], "scale": [0.8, 1.7], "path_max": 0.2},
        # driftwood: small, sparse, and only where the last tide left it (the wrack line)
        {"kind": "driftwood", "count": 15, "region": [-66, 68, 48, 78], "slope": [0.9, 1.0], "h": [0.55, 1.5], "scale": [0.6, 1.25]},
        {"kind": "rock", "count": 130, "region": [-96, -66, 60, 30], "slope": [0.8, 1.0], "h": [18, 30], "scale": [0.3, 0.9], "path_max": 0.2},
        {"kind": "boulder", "count": 26, "region": [-96, -66, 60, 30], "slope": [0.8, 1.0], "h": [18, 30], "scale": [0.9, 1.6], "path_max": 0.1},
        {"kind": "hummock", "count": 320, "region": [-96, -66, 60, 42], "slope": [0.86, 1.0], "h": [18, 30], "scale": [0.5, 1.2], "path_max": 0.25},
        {"kind": "boulder", "count": 60, "region": [56, -66, 128, 100], "slope": [0.3, 0.75], "h": [18, 70], "scale": [1.0, 2.0]},
        {"kind": "rock", "count": 90, "region": [56, -66, 128, 100], "slope": [0.3, 0.8], "h": [18, 70], "scale": [0.6, 1.4]},
        {"kind": "boulder", "count": 40, "region": [-100, -90, 120, -60], "slope": [0.2, 0.7], "h": [4, 26], "scale": [1.0, 2.2]},
        {"kind": "standing_stone", "count": 22, "region": [-96, -172, 100, -94], "slope": [0.85, 1.0], "scale": [0.9, 1.6]},
        {"kind": "rock", "count": 140, "region": [-96, -172, 100, -90], "slope": [0.8, 1.0], "scale": [0.4, 1.2]},
        {"kind": "hummock", "count": 220, "region": [-96, -172, 100, -90], "slope": [0.85, 1.0], "scale": [0.6, 1.4]},
        # boulders sat back from the cliff tops, breaking the skyline
        {"kind": "boulder", "count": 45, "region": [-100, -70, 64, 46], "slope": [0.8, 1.0], "h": [17, 30], "scale": [0.8, 1.6], "drop_min": 6.0, "drop_r": 4.5, "path_max": 0.15},
        {"kind": "rock", "count": 60, "region": [-100, -70, 64, 46], "slope": [0.75, 1.0], "h": [17, 30], "scale": [0.4, 1.0], "drop_min": 4.0, "drop_r": 3.5, "path_max": 0.15},
        # the gully grows over: tussocks and stones on its ledges and lips
        {"kind": "hummock", "count": 70, "region": [15, 6, 35, 46], "slope": [0.6, 1.0], "scale": [0.4, 1.0], "path_max": 0.5, "flat": 0.6},
        {"kind": "rock", "count": 25, "region": [15, 6, 35, 46], "slope": [0.5, 1.0], "scale": [0.3, 0.8], "path_max": 0.5, "flat": 0.6},
        # talus at the foot of the ravine walls
        {"kind": "boulder", "count": 50, "region": [-100, -100, 110, -55], "slope": [0.5, 0.95], "h": [2.5, 8], "scale": [0.8, 1.8]},
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
    ] + FLOES + [
        # the tide froze mid-surge: a broken glass wall along the old waterline,
        # open where the channel runs out to the stack
        {"kind": "ice_floe", "at": [r2(x), r2(80.6 + 1.2 * math.sin(x * 0.37))],
         "scale": r2(1.5 + 0.6 * abs(math.sin(x * 1.7))), "rot": r2((x * 47) % 360), "tag": "rime"}
        for x in [i * 2.3 - 72 for i in range(55)] if not (-37.5 < x < -22.5)
    ],
    "veg": [
        {"kind": "grass", "region": [-98, -70, 64, 44], "density": 2.6, "h": [16, 40], "range": 50},
        {"kind": "sedge", "region": [-98, -70, 64, 44], "density": 0.35, "h": [16, 40], "range": 45},
        {"kind": "heather", "region": [-98, -70, 64, 44], "density": 0.5, "h": [16, 40], "range": 60},
        {"kind": "grass", "region": [-80, 40, 60, 70], "density": 1.2, "h": [2.5, 16], "range": 45},
        {"kind": "heather", "region": [-96, -172, 100, -86], "density": 0.9, "h": [18, 80], "range": 70},
        {"kind": "grass", "region": [-96, -172, 100, -86], "density": 1.0, "h": [18, 80], "range": 50},
    ],
    "fences": [
        {"kind": "drystone", "points": [[-50, -48], [-53, -30], [-51, -12], [-47, 4], [-49, 16]]},
        {"kind": "drystone", "points": [[36, -44], [40, -26], [38, -8]]},
        {"kind": "drystone", "points": [[34, 33], [42, 34.5], [49, 37.5]]},          # along the cliff top
        {"kind": "drystone", "points": [[-6, 37.5], [4, 38.5], [14, 36.0]]},         # along the cliff top
        {"kind": "drystone", "points": [[37, 9], [41, 6.5], [47, 7.5], [48.5, 13]]},  # round the graves
        {"kind": "wattle", "points": [[8, 18], [15, 16.5], [19, 21], [16, 26]]},     # the kailyard
        {"kind": "wattle", "points": [[-20, -24], [-14, -26], [-8, -24.5]]},
        {"kind": "drystone", "points": LOOKOUT_WALL},                                 # the Lookout Stone's wind-break
    ],
}

# ----------------------------------------------------------------- edges (audit)
edges = {
    "doc": "tools/audit_edges.py classes every walkable boundary: cliff, water, steep, building, thicket.",
    "walk_max_deg": 45.0,
    "water_level": 0.0,
    "drown_depth": 1.15,
    "nav_bounds": [-102, -90, 72, 130],
    "buildings": BUILDINGS,
    "thickets": [],
    "state_floors": [{"tag": "rime", "min": [CH["x0"] + 0.8, CH["z0"]], "max": [CH["x1"] - 0.8, ICE_Z1], "y": CH["y"]}],
    "gates": [{"id": "boatshed_back", "at": GATE_AT, "rot": 0}],
}

START = [-4.0, r2(T.sample(-4.0, 62.0) + 0.2), 62.0]
D = {
    "id": "saltfell_steading",
    "name": "Saltfell",
    "start": {"pos": START, "yaw": 200},
    "env": {"thaw": {"sun_rot": [-12, -36], "sun_energy": 2.3, "fog_density": 0.0008, "vol_density": 0.0032},
            "rime": {"sun_rot": [-34, -30]}},
    # the gully: mist lying in the cut below the cache (Job 4)
    "fog_pockets": [{"id": "gully", "at": [25, 11.5, 30], "size": [18, 9, 32], "density": [0.02, 0.05], "height_falloff": 0.5}],
    "terrain": T.terrain_block(),
    "nav_bounds": [-102, -4, -90, 72, 64, 130],
    "water": water,
    "hazards": hazards,
    "zones": [
        {"name": "THE STRAND", "min": [-80, 50], "max": [60, 130]},
        {"name": "SALTFELL", "min": [-100, -19], "max": [70, 50]},
        {"name": "THE LONGHOUSE", "min": [-6, -52], "max": [6, -20]},
    ],
    "houses": HOUSES,
    "pieces": PIECES,
    "boxes": BOXES,
    "blockers": BLOCKERS,
    "props": PROPS,
    "hearths": hearths,
    "gates": [{"id": "boatshed_back", "at": GATE_AT, "rot": 0, "width": 1.9, "locked_prompt": "Barred from the other side"}],
    "spawners": spawners,
    "frost_veils": [{"id": "hall_veil", "at": [0.0, SH, LH_DOOR_Z], "rot": 0, "tag": "rime",
                     # frozen net mesh, rime-cold (the parchment tint glowed beige
                     # against the blue yard)
                     "shader": {"tint": [0.74, 0.84, 0.96], "mesh_strength": 0.7}}],
    "npcs": npcs,
    "plaques": plaques,
    "pickups": pickups,
    # WORLD.md 6, after the Outsong: two masks on the low pegs inside the Longhouse door
    "landmarks": [{"scene": "res://assets/models/landmarks/lm_fold_cairn.glb", "at": at(x, z, -0.06), "rot": r, "scale": sc,
                   "blocker": [r2(2.0 * sc), r2(2.2 * sc), r2(2.0 * sc)]} for (x, z, r, sc) in CAIRNS] + [
        {"scene": "res://assets/models/props/child_mask.tscn", "at": [2.6, r2(SH + 1.0), -20.75], "rot": 180, "require_flag": "ending_outsong"},
        {"scene": "res://assets/models/props/mourning_mask.tscn", "at": [3.15, r2(SH + 1.12), -20.75], "rot": 180, "require_flag": "ending_outsong"},
    ],
    # one list: a second "scripted" key below used to overwrite this one,
    # and the Longhouse lost its net floor (the drawbridge seam joins it)
    "scripted": scripted + [TIDE_WALL, DRAG_FURROW, seams("saltfell_steading")[1]],
    "wayside_clear": WAYSIDE_CLEAR,
    "wayside": False,          # nothing strewn: every group on Saltfell is set by hand above
    "scatter": scatter,
    "edges": edges,
    # the seams to the Lowe: the cliff-top pass and the drawbridge
    "portals": seams("saltfell_steading")[0],
}

# --- progression gates (ADR 0015) ---------------------------------------------
# The pass to the Lowe: a head-dyke crosses the neck of cliff top between the
# sea cliff and the ravine head, and Gunna's net hangs across the gap in it
# until she is released (WORLD.md 5.1: "the net falls open"). Undone from the
# Lowe side at any time. The track to it is in terrain_saltfell.PATHS.
import progress_gates as PG  # noqa: E402
PASS_GATE = PG.gate(
    "saltfell_steading", "pass_net", T.sample, at=(-89.0, -75.5), toward=(0, -1),
    flag="ks_netmender_released", name="the cliff-top pass", to="lowe_barrows", seam_at=D["portals"][0]["at"],
    flank="drystone", posts="standing_stone", post_scale=0.9, depth=0.3,
    dressing=[{"kit": "net_frame"},
              {"kit": "rope_coil", "along": -1.25, "out": 0.7, "rot": 30, "when": "open"}],
    locked_prompt="Tied off on the far side", unbar_prompt="Untie the net", open_toast="The net comes down.")
PG.install(D, PASS_GATE)
# --- end progression gates

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "saltfell_steading.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
