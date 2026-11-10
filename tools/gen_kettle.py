#!/usr/bin/env python3
"""Authoring script for data/areas/kettle_fjord.json: Kettle Fjord (WORLD.md 5.3).

    the Kettle Road   down from the Lowe through a cleft in the fell wall (seam)
    the Landing Ice   the shelf under the south wall where the road comes down
    the Fish-Houses   houses on stilts over the water, kettles, the trader's boat
    the Breathing Hole  the Ice-Cutter's hole, out on the ice by the fjord head

THAW: open water. The shelf is cut twice by rock running into the fjord; the
jetties go round the ends. RIME: one sheet of ice wall to wall: walk anywhere,
but the crevasses and the thin ice round the cut holes give under you, and
the boats that were trying to leave lie frozen in it.

Run: python3 tools/gen_kettle.py [--keep-terrain]"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_kettle as K  # noqa: E402
import terrain_lowe as L  # noqa: E402
from seams_kettle import seam  # noqa: E402
from seams_tarnhall import seam as tarn_seam  # noqa: E402
import tarn_land as TL  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--keep-terrain" not in sys.argv:
    K.write()


def r2(v):
    return round(v, 2)


def g(x, z):
    return r2(K.sample(x, z))


def at(x, z, dy=0.0):
    return [r2(x), r2(g(x, z) + dy), r2(z)]


def fz(x):
    return L.fjord_z(x)


def edge_z(x):
    """The south waterline (the shelf's outer lip)."""
    return L.fjord_z(x) + L.fjord_half(x) - L.shelf_width(x)


DECK = L.SHELF_Y + 0.32         # jetties and hut platforms: a natural step up off the shingle
HOUSES, BUILDINGS, PROPS, BOXES, BLOCKERS, FLOORS = [], [], [], [], [], []


def deck(x0, z0, x1, z1, tag="base"):
    """A plank walkway on posts over the water (and its audit floor)."""
    mnx, mxx = min(x0, x1), max(x0, x1)
    mnz, mxz = min(z0, z1), max(z0, z1)
    BOXES.append({"min": [r2(mnx), DECK - 0.22, r2(mnz)], "max": [r2(mxx), DECK, r2(mxz)], "mat": "M_wood", "tag": tag})
    FLOORS.append({"tag": tag, "min": [r2(mnx), r2(mnz)], "max": [r2(mxx), r2(mxz)], "y": DECK})
    # posts down into the water
    x = mnx + 0.3
    while x < mxx:
        for zz in (mnz + 0.2, mxz - 0.2):
            BOXES.append({"min": [r2(x - 0.12), -4.0, r2(zz - 0.12)], "max": [r2(x + 0.12), DECK - 0.2, r2(zz + 0.12)],
                          "mat": "M_wood_dark", "collide": False, "tag": tag})
        x += 3.0


# --- the jetties round the two rock spurs that cut the shelf (THAW route)
for spx, spw in L.SHELF_SPURS:
    xa, xb = spx - spw - 4.0, spx + spw + 4.0
    if spx > -30:
        xa = spx - spw + 0.6          # (the third fish-house stands where the leg would)
    za, zb = edge_z(xa), edge_z(xb)
    zo = min(za, zb) - 7.0
    deck(xa - 1.2, za + 5.6, xa + 1.2, zo)          # out from the shelf
    deck(xa - 1.2, zo - 1.2, xb + 1.2, zo + 1.2)    # along, clear of the rock
    deck(xb - 1.2, zo, xb + 1.2, zb + 5.6)          # back in to the shelf

# --- the fish-houses on stilts, between the spurs
FISH = [(-48.0, 0.0), (-38.5, 6.0), (-29.0, -5.0)]
for i, (hx, yaw) in enumerate(FISH):
    hz = edge_z(hx) - 6.5
    HOUSES.append({"id": "fishhouse_%d" % i, "center": [hx, r2(hz)], "size": [8, 8], "yaw": yaw, "y": DECK,
                   "doors": [["S", 0 if i != 1 else 1]], "gate_doors": [], "open": [], "wall_h": 2.8})
    # the door: an 8 m front has its door bays 2 m either side of the middle
    # (BuildingGen), so the walk to the shore runs from there. A walk from
    # the middle met the wall, and nobody could go in for the ladle or the auger.
    lx = -2.0 if i != 1 else 2.0
    dx = hx + lx * math.cos(math.radians(yaw)) + 4.0 * math.sin(math.radians(yaw))
    dz = hz - lx * math.sin(math.radians(yaw)) + 4.0 * math.cos(math.radians(yaw))
    BUILDINGS.append({"id": "fishhouse_%d" % i, "center": [hx, r2(hz)], "size": [8, 8], "yaw": yaw, "y": DECK,
                      "doors": [[r2(dx), r2(dz)]], "open": []})
    deck(hx - 4.6, hz - 4.6, hx + 4.6, hz + 4.6)                   # the platform
    deck(dx - 1.1, hz + 4.0, dx + 1.1, edge_z(dx) + 5.6)          # the walk to the shore

# the trader's boat at the middle house, sail half furled (THAW)
TRADER = (-38.5, edge_z(-38.5) - 14.0)
PROPS.append({"kit": "boat", "at": [TRADER[0], 0.05, r2(TRADER[1])], "rot": 84, "tag": "thaw", "scale": [1.5, 1.4, 1.6], "embed": True})
BOXES.append({"min": [TRADER[0] - 0.1, 0.4, TRADER[1] - 0.1], "max": [TRADER[0] + 0.1, 8.5, TRADER[1] + 0.1],
              "mat": "M_wood", "collide": False, "tag": "thaw"})
# boats on the water in THAW, frozen in the ice in RIME (they were leaving)
for k, (bx, dz, rot) in enumerate([(-88, -10, 70), (-60, -16, 100), (-12, -12, 75), (2, -22, 110), (-100, -18, 60)]):
    bz = edge_z(bx) + dz
    PROPS.append({"kit": "boat", "at": [bx, 0.05, r2(bz)], "rot": rot, "tag": "thaw", "embed": True})
    PROPS.append({"kit": "boat", "at": [bx + 3, -1.0, r2(bz - 6)], "rot": rot + 25, "tag": "rime", "collide": False, "embed": True})
# the fish-kettles on the shelf
for (kx, dz) in [(-54, 6.0), (-22, 5.5), (-17, 6.0)]:
    PROPS.append({"kit": "fish_kettle", "at": at(kx, edge_z(kx) + dz), "rot": kx * 7 % 360})

# --- RIME: the ice sheet, crevasses and thin ice
ICE = {"min": [-150.0, -0.6, -365.0], "max": [46.0, 0.05, -275.0]}
BLOCKERS.append({"min": ICE["min"], "max": ICE["max"], "tag": "rime"})
BOXES.append({"min": [ICE["min"][0], 0.02, ICE["min"][2]], "max": [ICE["max"][0], 0.07, ICE["max"][2]],
              "mat": "M_ice_sheet", "tag": "rime", "collide": False})


def thaw_water_blockers():
    """THAW: the AI keeps out of the open water. Tall nav-only walls over the
    water in strips, stopping short of the shelf lip and of every deck, so the
    navmesh can neither run out over the fjord floor nor onto a flat top."""
    xs = set(range(-150, 47, 2))
    for f in FLOORS:
        xs.add(f["min"][0])
        xs.add(f["max"][0])
    xs = sorted(x for x in xs if -150 <= x <= 46)
    for a, b in zip(xs, xs[1:]):
        if b - a < 0.05:
            continue
        zmax = min(edge_z(a), edge_z(b), edge_z((a + b) * 0.5)) + 1.0
        for f in FLOORS:
            if f["min"][0] < b - 0.01 and f["max"][0] > a + 0.01:
                zmax = min(zmax, f["min"][1] - 0.6)
        BLOCKERS.append({"min": [r2(a), -16.0, -368.0], "max": [r2(b), 8.0, r2(zmax)], "tag": "thaw", "nav_only": True})


thaw_water_blockers()

HOLE = (22.0, r2(fz(22.0) + 2.0))
THIN = [
    # crevasses: long cracks across the ice
    {"min": [-96.0, -1.0, r2(fz(-96) - 14)], "max": [-94.8, 0.8, r2(fz(-96) + 8)]},
    {"min": [-64.0, -1.0, r2(fz(-64) - 3)], "max": [-50.0, 0.8, r2(fz(-64) - 1.8)]},
    {"min": [-6.0, -1.0, r2(fz(-6) - 16)], "max": [-4.8, 0.8, r2(fz(-6) + 2)]},
    # the floe edge at the fjord mouth: the ice breaks up into open sea
    {"min": [-157.0, -1.0, -366.0], "max": [-149.0, 0.8, -274.0]},
    # thin ice round the fishers' cut holes
    {"min": [-80.0, -1.0, r2(fz(-80) - 3)], "max": [-77.0, 0.8, r2(fz(-80))]},
    {"min": [-30.0, -1.0, r2(fz(-30) - 8)], "max": [-27.0, 0.8, r2(fz(-30) - 5)]},
]
hazards = [
    {"kind": "drown", "min": [-1200, -40, -1200], "max": [1200, -1.15, 1200]},
    {"kind": "fall", "min": [-150, -2, -400], "max": [60, 90, -230]},
    # the Breathing Hole itself: the water under it does not let go
    {"kind": "thin", "tag": "rime", "seconds": 0.05, "min": [HOLE[0] - 1.6, -1.0, HOLE[1] - 1.6], "max": [HOLE[0] + 1.6, 0.8, HOLE[1] + 1.6]},
] + [dict(t, kind="thin", tag="rime") for t in THIN]
# the AI walks round the cracks, not into them
for t in THIN:
    BLOCKERS.append({"min": [t["min"][0] - 0.3, -1.0, t["min"][2] - 0.3], "max": [t["max"][0] + 0.3, 8.0, t["max"][2] + 0.3],
                     "tag": "rime", "nav_only": True})
# THAW: open water everywhere. RIME: clear ice over the fjord (the boats show
# through it) on dark depths; open sea beyond the floe edge.
water = [{"at": [0, 0.0, -300], "size": [4000, 4000], "tag": "thaw"},
         {"at": [-675.0, 0.0, -300], "size": [1050, 4000], "tag": "rime"},
         {"at": [-52.0, -3.0, -320], "size": [200, 100], "tag": "rime"},
         {"at": [446.0, 0.0, -300], "size": [800, 4000], "tag": "rime"}]
for t in THIN:
    water.append({"at": [r2((t["min"][0] + t["max"][0]) * 0.5), 0.08, r2((t["min"][2] + t["max"][2]) * 0.5)],
                  "size": [r2(t["max"][0] - t["min"][0]), r2(t["max"][2] - t["min"][2])], "tag": "rime"})
water.append({"at": [HOLE[0], 0.08, HOLE[1]], "radius": 1.6, "tag": "rime"})

# --- the Breathing Hole: an arena on the ice ringed by pressure ridges
ARENA_R = 15.0
place = []
n = int(2 * math.pi * ARENA_R / 1.8)
for k in range(n):
    th = 2 * math.pi * k / n
    deg = math.degrees(th) % 360
    if abs(deg - 90) < 9:
        continue               # the way in, from the shelf side (south)
    x = HOLE[0] + ARENA_R * math.cos(th)
    z = HOLE[1] + ARENA_R * math.sin(th)
    if z > edge_z(x) - 1.0:
        continue
    place.append({"kind": "ice_floe", "at": [r2(x), r2(z)], "y": -0.2, "rot": r2(k * 47 % 360),
                  "scale": [r2(2.2 + 0.6 * math.sin(k * 1.7)), r2(1.3 + 0.5 * abs(math.sin(k * 2.3))), 2.0], "tag": "rime"})
VEIL = [HOLE[0], 0.05, r2(HOLE[1] + ARENA_R)]
# loose floes and pressure ridges elsewhere on the ice
for k in range(26):
    x = -130 + k * 6.3
    z = fz(x) - 10 + 14 * math.sin(k * 1.9)
    if math.hypot(x - HOLE[0], z - HOLE[1]) < ARENA_R + 4:
        continue
    place.append({"kind": "ice_floe", "at": [r2(x), r2(z)], "y": -0.15, "rot": r2(k * 61 % 360),
                  "scale": [r2(1.4 + 0.8 * abs(math.sin(k))), 0.6, 1.6], "tag": "rime"})

# --- the walls: falls down the north gullies, running in THAW, frozen in RIME
FALLS = []
for fx in L.FALLS_X:
    fzz = fz(fx) - L.fjord_half(fx)            # the north waterline
    pts, top = [], None
    zz = fzz - 40.0
    while zz <= fzz + 0.6:
        hh = L.height(fx, zz)
        if top is None or hh < top - 0.3:
            pts.append([fx, r2(hh + 0.3), r2(zz)])
            top = hh
        zz += 1.0
    pts[-1][1] = 0.05
    if len(pts) >= 4:
        FALLS.append({"pts": pts, "width": 2.2, "side": [1, 0, 0], "tag": "thaw"})
        FALLS.append({"pts": [[p[0], p[1] + 0.15, p[2] + 0.2] for p in pts], "width": 3.0, "side": [1, 0, 0], "tag": "rime"})

# the tarn's outflow down the Tarn Steps, over the lip into the fjord head
_st = TL.stream(L.height)
FALLS.append({"pts": _st, "width": 2.4, "tag": "thaw"})
FALLS.append({"pts": [[p[0], p[1] + 0.12, p[2]] for p in _st], "width": 2.8, "tag": "rime"})

# --- the shelf: nets drying, fish racks, boats hauled up, rope and creels
# (kept to the wall side so the shelf stays a walk; nothing on a jetty root,
# a house walk, a hearth or where the foes stand)
KEEP_CLEAR = [f["min"][0] for f in FLOORS] + [f["max"][0] for f in FLOORS] + [-104, -58, -52, -90, -12, -54, -22, -17]
SHELF_KIT = ["net_frame", "drying_rack", "boat_upturned", "creel_stack", "net_frame", "rope_coil", "drying_rack", "creel_stack"]


def wall_foot(x):
    """The back of the shelf, a little short of where the wall rises."""
    z = fz(x) + L.fjord_half(x)
    while L.height(x, z) > L.SHELF_Y + 0.08 and z > edge_z(x) + 6:
        z -= 0.5
    return z - 1.6


k = 0
x = -124.0
while x < 34.0:
    if all(abs(x - c) > 4.0 for c in KEEP_CLEAR) and not (-80 < x < -64) and not (-26 < x < -10 and False):
        kit = SHELF_KIT[k % len(SHELF_KIT)]
        zf = wall_foot(x)
        if zf - edge_z(x) > 7.5:
            big = kit in ("boat_upturned", "drying_rack", "net_frame")
            PROPS.append({"kit": kit, "at": at(x, zf - (1.0 if kit == "boat_upturned" else 0.0)),
                          "rot": 90 if kit == "boat_upturned" else (k * 13) % 9 - 4, "collide": kit == "boat_upturned"})
            if not big:
                PROPS.append({"kit": "rope_coil", "at": at(x + 1.4, zf + 0.2), "rot": k * 40 % 360, "collide": False})
        k += 1
    x += 6.5
# coils and creels on the jetty roots and the house walks
for f in FLOORS[:]:
    if f["tag"] == "base" and f["max"][1] - f["min"][1] > 5 and f["max"][0] - f["min"][0] < 3:
        PROPS.append({"kit": "rope_coil", "at": [r2(f["min"][0] + 0.45), DECK, r2(f["max"][1] - 1.2)], "rot": 30, "collide": False})

# --- people and the frost-taken
SH = lambda x, d=0.0: at(x, edge_z(x) + 7.5 + d)  # noqa: E731
hearths = [
    {"id": "hs_landing_ice", "name": "the Landing Ice", "at": SH(-104, 0.5), "rot": 180},
    {"id": "hs_fish_houses", "name": "the Fish-Houses", "at": SH(-58, 0.2), "rot": 160},
    # no hearth wakes at the Breathing Hole (KETTLE.md 1): warmed to THAW it is
    # open water, and the shelf above it is cut off from the road
]
# KETTLE.md 2-4: the frost-taken where they froze
spawners = [
    {"enemy": "ice_fisher", "stand_in": "rimewalker", "id": "fisher_landing", "at": [-82.0, 0.15, r2(fz(-82) - 6)], "face": 30,
     "pose": "kneel_fish"},
    {"enemy": "ice_fisher", "stand_in": "rimewalker", "id": "fisher_houses", "at": [-33.0, 0.15, r2(fz(-33) - 2)], "face": -60,
     "pose": "kneel_fish"},
    {"enemy": "ice_fisher", "stand_in": "rimewalker", "id": "fisher_head", "at": [4.0, 0.15, r2(fz(4))], "face": 90},
    {"enemy": "ice_fisher", "stand_in": "rimewalker", "id": "fisher_road", "at": at(-100, -276, 0.1), "face": 200},
    # the pair in harness below Ivo's place, facing out toward the fjord head
    {"enemy": "sledge_dog", "stand_in": "hearthhound", "id": "dogs_a", "at": [-58.0, 0.15, r2(fz(-58) + 4)], "face": 60},
    {"enemy": "sledge_dog", "stand_in": "hearthhound", "id": "dogs_b", "at": [-56.5, 0.15, r2(fz(-56) + 5.5)], "face": 60},
    {"enemy": "sealer", "stand_in": "oarsman", "id": "sealer_shelf", "at": SH(-12, 0.0), "face": 180},
    {"enemy": "sealer", "stand_in": "oarsman", "id": "sealer_jetty", "at": SH(-90, 0.0), "face": 90},
    # he kneels at the north rim of the hole, facing it and the way in
    {"enemy": "ice_cutter", "stand_in": "netmender", "id": "ice_cutter", "at": [HOLE[0], 0.15, r2(HOLE[1] - 2.64)],
     "face": 180, "dead_once": True, "frost_veil_id": "breathing_hole_veil"},
]
FH = [(hx, edge_z(hx) - 6.5) for hx, _y in FISH]      # the fish-house platforms' centres
B0 = (-88 + 3, edge_z(-88) - 10 - 6)                  # a boat that was leaving, frozen in
pickups = [
    # Ivo's supper: the pot on its hook in the westmost house, the ladle standing up in it
    {"id": "kettle_ladle", "at": [FH[0][0] + 0.6, DECK, r2(FH[0][1] - 1.0)], "item": "item_kettle_ladle", "tag": "rime",
     "label": "Take the ladle", "set_flag": "ks_ivo_supper"},
    {"id": "north_shore_cache", "at": [-60.0, 0.06, r2(fz(-60) - L.fjord_half(-60) + 3.5)], "item": "bog_iron", "count": 2,
     "tag": "rime", "label": "Pry up what the ice holds"},
    # Halla's cord, tied round the mooring post at the middle house
    {"id": "halla_cord", "at": [TRADER[0] + 1.6, 0.06, r2(TRADER[1])], "item": "item_halla_cord", "tag": "rime",
     "label": "Untie the cord", "set_flag": "ks_halla_cord_found"},
    # the spare auger on the tool bench in the eastmost house
    {"id": "ice_auger", "at": [FH[2][0] - 1.2, DECK, r2(FH[2][1] - 1.5)], "item": "ice_auger", "tag": "rime",
     "label": "Take the auger", "scene": "res://assets/models/weapons/ice_auger.glb"},
    # a sealer's harpoon frozen into the ice beside a boat that was leaving
    {"id": "sealer_harpoon", "at": [r2(B0[0] + 2.5), 0.06, r2(B0[1] + 1.5)], "item": "sealer_harpoon", "tag": "rime",
     "label": "Work the harpoon free", "scene": "res://assets/models/weapons/sealer_harpoon.glb"},
    # Ivo's mitten in the new ice over the hole (KETTLE.md 9). The release sets
    # one down at once (Game._release_leavings, same id); this entry keeps it
    # there if the journey is saved and resumed before it is taken.
    {"id": "ivo_mitten", "at": [HOLE[0], 0.17, HOLE[1]], "item": "item_ivo_mitten", "tag": "rime",
     "label": "Chip the mitten free", "set_flag": "ks_ivo_mitten_found",
     "scene": "res://assets/models/props/ivo_mitten.tscn", "require_flag": "ks_ice_cutter_released",
     "audit_skip": "the hole under it is thin ice until the release seals it (release_seal)"},
]
KX = -54.0
KZ = edge_z(KX) + 6.0                  # the westmost fish-kettle (see PROPS)


def at_kettle(dx, dz):
    """A place by the westmost kettle, and the yaw that faces it (a character faces -z)."""
    x, z = KX + dx, KZ + dz
    return at(x, z), r2(math.degrees(math.atan2(dx, dz)))


PELL_AT, PELL_ROT = at_kettle(-1.7, 1.25)
IVO_AT, IVO_ROT = at_kettle(1.6, 1.15)
npcs = [
    {"id": "ivo", "at": SH(-52, 0.4), "rot": 150, "tag": "thaw", "absent_flag": "ks_ice_cutter_released"},
    # after the release (KETTLE.md 9): Old Pell and Ivo at the kettle, supper on
    {"id": "pell", "at": PELL_AT, "rot": PELL_ROT, "tag": "thaw", "require_flag": "ks_ice_cutter_released"},
    {"id": "ivo", "at": IVO_AT, "rot": IVO_ROT, "tag": "thaw", "require_flag": "ks_ice_cutter_released",
     "pose": "sit", "seat": "wood"},
    # the trader and her crewman at the foot of the middle house's walk
    {"id": "halla", "at": SH(-41.0, -0.8), "rot": 140, "tag": "thaw"},
    {"id": "sten", "at": SH(-35.5, -1.2), "rot": 170, "tag": "thaw"},
]
portal = seam("kettle_fjord")
arrive = seam("lowe_barrows")          # where the Lowe's side of the seam sets you down
START = arrive["spawn"]

edges = {
    "doc": "tools/audit_edges.py: jetties and hut platforms are THAW/RIME floors; the RIME ice is a floor over the fjord.",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [-150, -368, 58, -236],
    "buildings": BUILDINGS, "thickets": [],
    "state_floors": FLOORS + [{"tag": "rime", "min": [ICE["min"][0], ICE["min"][2]], "max": [ICE["max"][0], ICE["max"][2]], "y": 0.05}],
    "gates": [],
}

D = {
    "id": "kettle_fjord",
    "name": "Kettle Fjord",
    "start": {"pos": START, "yaw": arrive["spawn_yaw"]},
    # THAW: a low evening sun straight down the fjord from the sea, its light
    # thrown back warm off the water onto the walls
    "env": {"thaw": {"sun_rot": [-13, -96], "sun_energy": 2.8, "fog_density": 0.0012, "vol_density": 0.006,
                     "ambient_energy": 0.62, "exposure": 1.08,
                     "fill_color": [1.0, 0.7, 0.42], "fill_energy": 0.7, "fill_rot": [28, 84]},
            "rime": {"sun_rot": [-24, -60], "fog_density": 0.007, "vol_density": 0.018}},
    "terrain": K.terrain_block(),
    "nav_bounds": [-150, -16, -368, 58, 70, -236],
    "weather": {"gulls": True, "gull_y": 30.0, "gull_dz": -20.0, "spindrift": 12},
    "water": water,
    "falls": FALLS,
    "scripted": [{"script": "res://src/world/god_rays.gd", "at": [gx, 14.0, r2(fz(gx) + 4)], "tag": "thaw",
                  "params": {"count": 6, "span_x": 30, "span_z": 26, "sun": [-13, -96], "seed_v": int(gx) % 97}}
                 for gx in (-112.0, -64.0, -16.0)],
    "hazards": hazards,
    "zones": [
        {"name": "THE LANDING ICE", "min": [-150, -370], "max": [-66, -236]},
        {"name": "THE FISH-HOUSES", "min": [-66, -370], "max": [-14, -236]},
        {"name": "THE BREATHING HOLE", "min": [-14, -370], "max": [60, -236]},
    ],
    "houses": HOUSES,
    "boxes": BOXES,
    "blockers": BLOCKERS,
    "props": PROPS,
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "breathing_hole_veil", "at": VEIL, "rot": 0, "tag": "rime"}],
    "npcs": npcs,
    "plaques": [{"at": SH(-108, 1.0), "rot": 160, "text": "KETTLE FJORD\n\nThe ice comes in the Hearth-months, and the fishing moves out onto it."}],
    "pickups": pickups,
    "portals": [portal, tarn_seam("kettle_fjord")],
    "scatter": {
        "seed": 7070,
        "clear": [[b["center"][0], b["center"][1], 7.0] for b in BUILDINGS] + [[HOLE[0], HOLE[1], ARENA_R + 2]],
        "rules": [
            {"kind": "rock", "count": 120, "region": [-140, -300, 45, -270], "slope": [0.8, 1.0], "h": [1.0, 4.0], "scale": [0.3, 0.9], "path_max": 0.3},
            {"kind": "boulder", "count": 60, "region": [-150, -380, 60, -240], "slope": [0.45, 0.85], "h": [2.0, 60], "scale": [0.9, 2.0]},
            {"kind": "driftwood", "count": 14, "region": [-130, -300, 40, -275], "slope": [0.85, 1.0], "h": [1.0, 3.5], "scale": [0.8, 1.3]},
        ],
        "place": place,
        "veg": [
            {"kind": "grass", "region": [-150, -380, 60, -236], "density": 1.2, "h": [1.2, 90], "range": 45},
            {"kind": "sedge", "region": [-150, -310, 60, -270], "density": 0.8, "h": [1.2, 4.5], "range": 40},
        ],
    },
    "edges": edges,
}

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "kettle_fjord.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
