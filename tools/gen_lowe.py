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
# (the two that stood at Hesk's fire are the peat wall along the cutting's lip now: POI.md 3.3)
for (x, z, r) in [(-22, -176, -30), (-20, -200, 10), (-58, -205, 44)]:
    place.append({"kind": "peat_stack", "at": [x, z], "rot": r})
# the island of cut peat in the bog
for k in range(4):
    th = 3.5 + k * 0.62      # stacked on the island's north side
    place.append({"kind": "peat_stack", "at": [r2(L.ISLAND[0] + 2.2 * math.cos(th)), r2(L.ISLAND[1] + 2.2 * math.sin(th))], "rot": k * 50})

# frost veil across the gap in the sod wall
VEIL = [r2(CX), r2(A), r2(CZ + CR - 0.5)]

# the frozen bog (RIME): an invisible sheet carries you; ice shows where
# THAW: the AI must not path through the black water (nothing collides)
# (tall: the navmesh bakes a floor on top of whatever it is told to keep off.
# At 2.5 m over the water the box's lid was within a step of the rim's high
# ground, and the THAW navmesh ran across it to the peat island.)
BLOCKERS.append({"min": [L.BOG[0] - 24, r2(W - 3), L.BOG[1] - 24], "max": [L.BOG[0] + 24, r2(W + 14.0), L.BOG[1] + 24],
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

# ----------------------------------------------------------------- points of interest
# docs/lore/POI.md 3, and the Lowe's own prop set (docs/art/BIOMES.md). Every
# piece here is set by hand, never by the scatter rules, so it survives a
# regenerate.
WAYSIDE_CLEAR = []       # [x, z, r]: ground Wayside leaves open
POI_CLEAR = []           # the same for the scatter rules
NPCS_POI, PLAQUES_POI = [], []


def prop(kit, x, z, rot=0, tag="base", **kw):
    d = {"kit": kit, "at": at(x, z), "rot": r2(rot)}
    if tag != "base":
        d["tag"] = tag
    d.update(kw)
    PROPS.append(d)
    POI_CLEAR.append([r2(x), r2(z), 2.4])
    return d


def barrow_at(bid, ox, oz):
    """A point in a barrow's own frame (x across, +z out of the door) on the map."""
    b = [b for b in list(L.LONG_BARROWS) + [L.TWIN] if b[0] == bid][0]
    return rot_off(b[1], b[2], DOORS[bid][0], ox, oz)


BY = {b[0]: b for b in L.LONG_BARROWS}

# --- 3.1 lw_bread_mound: the Bread Mound (on top of kin_b) ---------------------
# Sod steps up the mound's back shoulder; on top, THAW: a cloth, crumbs and an
# upturned cup; RIME: the cloth is gone and the cup is frozen to the turf.
KB = BY["kin_b"]
KB_YAW = DOORS["kin_b"][0]
KB_TOP = 2.6 + KB[3] * 0.12 - 0.2                      # the mound's crown over its pad (building_gen._barrow)
_sx, _sz = barrow_at("kin_b", 0.0, -(KB[4] * 0.5 + 0.6) - 1.0)
prop("lw_mound_steps", _sx, _sz, KB_YAW + 180, collide=True)
BREAD = barrow_at("kin_b", 0.0, -0.9)                  # the crown (the mound sits 0.6 m back of its pad's middle)
prop("lw_bread_cloth", BREAD[0], BREAD[1], KB_YAW + 20, tag="thaw", collide=False, lift=r2(KB_TOP), settle=True)
CUP = barrow_at("kin_b", 0.62, -0.7)
prop("lw_birch_cup", CUP[0], CUP[1], 0, tag="thaw", collide=False, lift=r2(KB_TOP), settle=True)
BREAD_CUP = {"id": "birch_cup", "at": at(CUP[0], CUP[1]), "item": "item_birch_cup", "kit": "lw_birch_cup", "tag": "rime",
             "label": "Prise the cup off the turf", "raise": r2(KB_TOP), "settle": True}
_px, _pz = barrow_at("kin_b", 1.5, -(KB[4] * 0.5 + 0.6) - 2.9)
prop("lw_kin_post", _px, _pz, KB_YAW + 160)
NPCS_POI.append({"id": "bread_family", "at": at(KB[1], KB[2]), "rot": 0, "tag": "thaw"})

# --- 3.2 lw_last_mound: the Last Mound (the door of kin_d) ----------------------
# THAW: one fresh bunch on the door turf. RIME: one for every evening, heaped
# to the height of the door beside it and spilling across its foot.
KD_YAW = DOORS["kin_d"][0]
_bx, _bz = door_front("kin_d", 0.55)
prop("lw_heather_bunch", _bx, _bz, KD_YAW + 70, tag="thaw", collide=False)
HEAP = barrow_at("kin_d", -1.7, BY["kin_d"][4] * 0.5 + 0.3)
prop("lw_heather_heap", HEAP[0], HEAP[1], KD_YAW, tag="rime", collide=False)
_hx, _hz = barrow_at("kin_d", -1.9, BY["kin_d"][4] * 0.5 + 0.55)
BLOCKERS.append({"min": [r2(_hx - 0.6), g(_hx, _hz), r2(_hz - 0.6)], "max": [r2(_hx + 0.6), r2(g(_hx, _hz) + 1.2), r2(_hz + 0.6)], "tag": "rime"})
_px, _pz = barrow_at("kin_d", 3.3, BY["kin_d"][4] * 0.5 + 3.4)
PLAQUES_POI.append({"at": at(_px, _pz), "rot": r2(KD_YAW + 200), "tag": "rime",
                    "text": "THE LAST MOUND\n\nHeather in bunches, one for every evening.\nThe ones at the bottom have gone to dust. All of it is purple."})
_px, _pz = barrow_at("kin_d", 3.9, BY["kin_d"][4] * 0.5 + 0.9)
prop("lw_kin_post", _px, _pz, KD_YAW + 15)

# --- 3.3 lw_hesk_fire: Hesk's Fire (the peat cutting west of the road) ----------
# His furnace dug into the peat wall behind him. RIME: cold, and the job Arne
# was waiting on lies on the edging stone, one side done.
HESK = (-58.0, -166.0)
HESK_ROT = 238.0
_hf = (-math.sin(math.radians(HESK_ROT)), -math.cos(math.radians(HESK_ROT)))     # the way he faces
FURNACE = (HESK[0] - _hf[0] * 2.7, HESK[1] - _hf[1] * 2.7)
prop("lw_bloomery", FURNACE[0], FURNACE[1], math.degrees(math.atan2(_hf[0], _hf[1])))
EDGING = (HESK[0] + _hf[1] * 1.7 - _hf[0] * 0.6, HESK[1] - _hf[0] * 1.7 - _hf[1] * 0.6)      # at his right hand
prop("lw_edging_stone", EDGING[0], EDGING[1], HESK_ROT + 90)
SPADE_IRON = {"id": "spade_iron", "at": at(EDGING[0] + _hf[0] * 0.75, EDGING[1] + _hf[1] * 0.75), "item": "item_spade_iron",
              "kit": "lw_spade_iron", "tag": "rime", "label": "Take the spade-iron", "lift": 0.41,
              "show_at": [r2(-_hf[0] * 0.75), r2(-_hf[1] * 0.75)]}
prop("lw_spade_rack", HESK[0] - _hf[1] * 2.9 - _hf[0] * 1.5, HESK[1] + _hf[0] * 2.9 - _hf[1] * 1.5, math.degrees(math.atan2(_hf[0], _hf[1])) + 25)
# the peat wall along the cutting's lip, either side of the furnace
for k in (-2, -1, 1, 2):
    wx = FURNACE[0] - _hf[0] * 0.5 + _hf[1] * (k * 2.25 + (0.5 if k > 0 else -0.5))
    wz = FURNACE[1] - _hf[1] * 0.5 - _hf[0] * (k * 2.25 + (0.5 if k > 0 else -0.5))
    place.append({"kind": "peat_wall", "at": [r2(wx), r2(wz)], "rot": r2(math.degrees(math.atan2(_hf[0], _hf[1])) + 4 * k)})
    POI_CLEAR.append([r2(wx), r2(wz), 2.0])
prop("lw_peat_sled", HESK[0] + _hf[0] * 3.4 + _hf[1] * 3.0, HESK[1] + _hf[1] * 3.4 - _hf[0] * 3.0, 100)

# --- 3.4 lw_cutters_bothy: the Cutter's Bothy (below the Drying Stacks hearth) --
# On its pad cut into the slope (terrain_lowe.BOTHY). THAW: Arne's dinner
# cloth on the bench, three spades by the door. RIME: the big one is gone.
BX, BZ = L.BOTHY[0], L.BOTHY[1]
BOTHY_ROT = 18.0
BOTHY_LM = {"scene": "res://assets/models/landmarks/lm_cutters_bothy.glb", "at": at(BX, BZ - 0.4, -0.05), "rot": BOTHY_ROT,
            "family": "M_turf", "blocker": [4.3, 2.6, 4.2]}
POI_CLEAR.append([BX, BZ, 5.5])
WAYSIDE_CLEAR.append([BX, BZ, 6.0])
_dx, _dz = rot_off(BX, BZ - 0.4, BOTHY_ROT, 1.5, 2.55)           # by the door post
prop("lw_three_spades", _dx, _dz, BOTHY_ROT + 180, tag="thaw", collide=False)
SMALL_SPADES = {"id": "small_spades", "at": at(_dx, _dz + 0.55), "item": "item_small_spades", "kit": "lw_small_spades", "tag": "rime",
                "label": "Take the small spades", "show_at": [0.0, -0.55], "rot": 0}
_cx, _cz = rot_off(BX, BZ - 0.4, BOTHY_ROT, -1.45, 2.55)         # on the bench
prop("lw_dinner_cloth", _cx, _cz, 30, tag="thaw", collide=False, lift=0.46)
prop("lw_spade_rack", BX - 3.9, BZ + 1.2, 96)
prop("lw_peat_sled", BX + 3.9, BZ + 2.2, 62)

# --- 3.5 lw_the_rise: the Rise (the road's last crest before the hollow) --------
# From here the stacks can be counted. Nothing is set on the sight-line.
RISE = (39.2, -174.2)
PLAQUES_POI.append({"at": at(RISE[0], RISE[1]), "rot": 215,
                    "text": "THE DRYING STACKS\n\nTurf is cut at midsummer and laid by the Melt.\nThere is more turf cut here than the Lowe has barrows."})
prop("lw_sod_row", 35.4, -174.9, 130, collide=False)
WAYSIDE_CLEAR.append([42.0, -180.0, 11.0])

# --- the Lowe's own prop set, where the work is done ------------------------
for bid in ("kin_a", "kin_c"):
    _px, _pz = barrow_at(bid, 3.9, BY[bid][4] * 0.5 + 0.9)
    prop("lw_kin_post", _px, _pz, DOORS[bid][0] + 10)
_px, _pz = barrow_at("kin_a", -4.4, BY["kin_a"][4] * 0.5 + 0.8)
prop("lw_bier", _px, _pz, DOORS["kin_a"][0])                  # the bier that brought the last of the Holms up
_px, _pz = barrow_at("kin_c", -4.6, BY["kin_c"][4] * 0.5 + 1.3)
prop("lw_sod_row", _px, _pz, DOORS["kin_c"][0] + 90, collide=False)      # the closed barrow: the turf went back the same day
for (x, z, r) in [(-65.0, -148.0, 12), (-62.5, -152.5, 30), (-66.5, -156.5, -8)]:
    place.append({"kind": "peat_row", "at": [x, z], "rot": r})           # footed to dry beside the bog path
    POI_CLEAR.append([x, z, 1.6])

# variety (owner: more kinds, fewer repeats), each where it is used
_px, _pz = barrow_at("kin_b", -4.4, BY["kin_b"][4] * 0.5 + 1.5)
prop("lw_stone_b", _px, _pz, DOORS["kin_b"][0] + 12)                    # the miller's people's stone
prop("lw_stone_c", -61.0, -118.6, 62)                                   # the pair that marks the bog path
prop("lw_stone_c", -88.6, -98.2, 20)                                    # and the pair at the pass
_px, _pz = barrow_at("kin_c", -6.6, BY["kin_c"][4] * 0.5 + 2.8)
for _bx, _bz, _br in ((_px, _pz, DOORS["kin_c"][0] + 70),              # what carried the closed barrow's turf back
                      (36.8, -177.6, 150)):                             # on the Rise, by the sods it brought
    # (its convex hull is a ramp up from the handles, and the Bearer walked up it:
    # two upright rounds along its length stand in for it)
    prop("lw_turf_barrow", _bx, _bz, _br, collide=False)
    for _k in (-0.5, 0.5):
        _cx, _cz = _bx + math.sin(math.radians(_br)) * _k, _bz + math.cos(math.radians(_br)) * _k
        BLOCKERS.append({"radius": 0.52, "at": [r2(_cx), r2(g(_bx, _bz) + 0.9), r2(_cz)], "height": 2.2})
for bid, ox in (("kin_a", 5.6), ("kin_d", 6.0)):
    _px, _pz = barrow_at(bid, ox, BY[bid][4] * 0.5 + 2.2)
    prop("lw_offering_slab", _px, _pz, DOORS[bid][0] + 180)             # what is left for them, at the mound's foot

# cairns where a way leaves the road (were Wayside's, strewn; now two, set by hand):
# at the fork of the bog path, and where the Kettle Road goes down off the moor
CAIRNS = [{"scene": "res://assets/models/landmarks/lm_fold_cairn.glb", "at": at(x, z, -0.06), "rot": r, "scale": sc,
           "blocker": [r2(2.0 * sc), r2(2.2 * sc), r2(2.0 * sc)]} for (x, z, r, sc) in [(-54.5, -110.0, 40, 0.9), (-66.0, -228.0, 15, 1.0)]]
for c in CAIRNS:
    POI_CLEAR.append([c["at"][0], c["at"][2], 2.6])

# the Keener at the bend stands with its back to the heap (POI.md 3.2)
for sp in spawners:
    if sp["id"] == "keener_mounds":
        vx, vz = sp["at"][0] - HEAP[0], sp["at"][2] - HEAP[1]
        sp["face"] = r2(math.degrees(math.atan2(-vx, -vz)) % 360)
# --- the spear at the first mound's kin-post (ADR 0015: a weapon to be found) ---
# Carried up behind the bier that still stands at kin_a's door, and stood
# against the kin-post for the household to carry down. Nobody did: it is
# there in both states, 5 m off the road, the first thing past the hearth.
# The prompt stands on the road side of the post; the spear leans on it.
SPEAR_LEAN = 20.0                                      # degrees off upright, head to the post
_px, _pz = barrow_at("kin_a", 3.9, BY["kin_a"][4] * 0.5 + 0.9 + 0.9)
KIN_SPEAR = {"id": "kin_spear", "at": at(_px, _pz), "rot": DOORS["kin_a"][0], "item": "spear", "tag": "base",
             "label": "Take the spear from the post", "pose": [-SPEAR_LEAN, 0, 0], "show_at": [0.0, -0.43], "lift": 0.5}
pickups += [BREAD_CUP, SPADE_IRON, SMALL_SPADES, KIN_SPEAR]

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
    "props": PROPS,
    "landmarks": [BOTHY_LM] + CAIRNS,
    "wayside": False,          # nothing strewn: the Lowe is dressed by hand above
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
    ] + RELEASE_SCENE + NPCS_POI,
    "plaques": [
        {"at": at(-84, -95), "rot": 20, "text": "THE LOWE\n\nThe barrow hills. Each neighbourhood has its kin-mounds.\nThe turf goes back the same day."},
    ] + PLAQUES_POI,
    "pickups": pickups,
    "portals": portals + [kettle_seam("lowe_barrows")],
    "scripted": [bridge],
    "scatter": {
        "seed": 5150,
        "clear": [[b["center"][0], b["center"][1], r2(math.hypot(*b["size"]) * 0.5 + 1)] for b in BUILDINGS]
                 + [[CX, CZ, CR + 1.0], [L.BOG[0], L.BOG[1], L.BOG[2] + 3]] + POI_CLEAR,
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

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "lowe_barrows.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
