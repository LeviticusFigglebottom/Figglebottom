#!/usr/bin/env python3
"""Authoring script for data/areas/shepherds_reach.json: Shepherd's Reach
(WORLD.md 5.6).

    the fell path     up out of Thornwold's east side (seam) onto the high grass
    the Sheilings     stone sheilings on the south side of the beck
    the High Fold     a ring of dry-stone fold on a shoulder north of the beck,
                      the fold cairn in it: the Fellcaller's calling ground

THAW: the flocks on the high grass; the beck from the ice runs deep and cold
in its cut, and the only way over is the plank bridge. RIME: the beck is
frozen (cross it anywhere), but the flock froze where it stood when she last
called: a whole slope of white sheep packed between the beck and the High
Fold, all facing the fold, and the way up winds between them.

Run: python3 tools/gen_reach.py [--keep-terrain]"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_reach as K  # noqa: E402
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


PROPS, BOXES, BLOCKERS, LANDMARKS, FLOORS, THICKETS = [], [], [], [], [], []
FX, FZ = H.HIGH_FOLD

# --- the sheilings -------------------------------------------------------------
# (the lower sheiling, S0, is a house the Bearer can go into: POI.md 7.3, below)
for (sx, sz, rot) in H.SHEILINGS[1:]:
    LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_sheiling.glb", "at": at(sx, sz, -0.1), "rot": rot, "scale": 1.6,
                      "blocker": [6.0, 4.6, 6.2]})
# peat stacks and a woodpile by the sheilings
for k, (dx, dz) in enumerate(((7.0, 2.0), (-6.0, 5.0), (9.0, -6.0))):
    sx, sz, _ = H.SHEILINGS[k]
    PROPS.append({"kit": "creel_stack", "at": at(sx + dx, sz + dz), "rot": k * 50, "collide": False})

# --- the High Fold: a dry-stone ring with one gap, the cairn inside --------------
GAP_A = 135.0                      # the gap faces down the trod toward the bridge
fold_pts = []
half = math.degrees(3.2 / 2.0 / H.FOLD_R)
n = 30
for i in range(n + 1):
    a = GAP_A + half + (360.0 - 2 * half) * i / n
    fold_pts.append([r2(FX + H.FOLD_R * math.cos(math.radians(a))), r2(FZ + H.FOLD_R * math.sin(math.radians(a)))])
for (ax, az), (bx, bz) in zip(fold_pts, fold_pts[1:]):
    L = math.hypot(bx - ax, bz - az)
    nx, nz = -(bz - az) / L * 0.6, (bx - ax) / L * 0.6
    THICKETS.append({"poly": [[r2(ax + nx), r2(az + nz)], [r2(bx + nx), r2(bz + nz)], [r2(bx - nx), r2(bz - nz)], [r2(ax - nx), r2(az - nz)]],
                     "tag": "base"})
LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_fold_cairn.glb", "at": at(FX + 3.0, FZ - 3.0, -0.05), "rot": 20, "scale": 1.3,
                  "blocker": [2.6, 3.0, 2.6]})
GAP = (FX + H.FOLD_R * math.cos(math.radians(GAP_A)), FZ + H.FOLD_R * math.sin(math.radians(GAP_A)))

# --- the beck: deep and cold in THAW, frozen in RIME; the plank bridge -----------
hazards = [{"kind": "fall", "min": [466, -2, -420], "max": [722, 200, -252]}]
water_falls = []
STATE_FLOORS = []
bx = 558.0
beck_pts = []
while bx < 704.0:
    bz = H.beck_z(bx)
    fl = H.pasture_y(bx, bz)
    bed = fl - H.BECK_DEPTH
    beck_pts.append([r2(bx), r2(g(bx, bz) + 0.15), r2(bz)])
    # THAW: the water in the cut takes whoever falls in
    hazards.append({"kind": "drown", "tag": "thaw", "min": [r2(bx), r2(bed - 2.0), r2(bz - H.BECK_HALF - 0.6)],
                    "max": [r2(bx + 4.0), r2(bed + 1.2), r2(bz + H.BECK_HALF + 0.6)]})
    # RIME: frozen to the brim; the ice carries you over. Laid in 2 m lengths,
    # each centred on the beck where it runs and reaching past the cut's rim
    # (BECK_HALF + 2.5): in 4 m lengths on the section's first z, an edge of
    # the ice stood up to 0.8 m inside the cut, with a ditch a metre deep
    # between it and the bank that the navmesh crossed and the Bearer could
    # not climb out of toward the path (at 625.7, -334.6).
    for sx in (bx, bx + 2.0):
        sz = H.beck_z(sx + 1.0)
        reach = H.BECK_HALF + 2.7
        top = r2(min(g(xx, sz + side * (H.BECK_HALF + 2.5)) for xx in (sx, sx + 1.0, sx + 2.0) for side in (-1.0, 1.0)) - 0.15)
        # (at the foot of the beck the bank drops below the bed: the slab keeps
        # half a metre of body there, where it was laid upside down, a box of
        # negative height the engine refused)
        BLOCKERS.append({"min": [r2(sx), r2(min(bed - 0.5, top - 0.5)), r2(sz - reach)], "max": [r2(sx + 2.0), top, r2(sz + reach)], "tag": "rime"})
        # the sheet is drawn as wide as the floor that carries: a metre
        # narrower each side, the Bearer walked on air over the bank between
        # the two (tools/audit_collision.sh, "floating")
        BOXES.append({"min": [r2(sx), r2(top - 0.06), r2(sz - reach)], "max": [r2(sx + 2.0), top, r2(sz + reach)],
                      "mat": "M_ice", "tag": "rime", "collide": False})
        STATE_FLOORS.append({"tag": "rime", "min": [r2(sx), r2(sz - reach)], "max": [r2(sx + 2.0), r2(sz + reach)], "y": top})
    # THAW: the AI keeps out of the cut
    BLOCKERS.append({"min": [r2(bx), r2(bed - 1.0), r2(bz - H.BECK_HALF)], "max": [r2(bx + 4.0), r2(fl + 6.0), r2(bz + H.BECK_HALF)],
                     "tag": "thaw", "nav_only": True})
    bx += 4.0
FALLS = [{"pts": beck_pts[::-1], "width": 3.0, "tag": "thaw"},
         {"pts": [[p[0], p[1] + 0.1, p[2]] for p in beck_pts[::-1]], "width": 3.4, "tag": "rime"}]
# the plank bridge (the nav-only walls stop either side of it)
BZ = H.beck_z(H.BRIDGE_X)
deck_y = r2(max(g(H.BRIDGE_X, BZ - 5.0), g(H.BRIDGE_X, BZ + 5.0)) + 0.15)
BOXES.append({"min": [H.BRIDGE_X - 1.4, deck_y - 0.22, r2(BZ - 5.5)], "max": [H.BRIDGE_X + 1.4, deck_y, r2(BZ + 5.5)], "mat": "M_wood", "tag": "base"})
FLOORS.append({"tag": "base", "min": [H.BRIDGE_X - 1.4, r2(BZ - 5.5)], "max": [H.BRIDGE_X + 1.4, r2(BZ + 5.5)], "y": deck_y})
for xx in (H.BRIDGE_X - 1.5, H.BRIDGE_X + 1.5):
    BOXES.append({"min": [r2(xx - 0.06), deck_y, r2(BZ - 4.0)], "max": [r2(xx + 0.06), deck_y + 0.95, r2(BZ + 4.0)], "mat": "M_wood", "tag": "base"})
BLOCKERS[:] = [b for b in BLOCKERS if not (b.get("nav_only") and b["min"][0] < H.BRIDGE_X + 1.6 and b["max"][0] > H.BRIDGE_X - 1.6)]
# the AI gives the rails' ends a wide berth (no snagging on the posts), and
# past the deck's own ends (5.5): a path that came onto the deck over its
# corner met a step of half a metre there, where the bank is lowest, and
# whoever followed it stood stuck beside the cut
for xx in (H.BRIDGE_X - 1.5, H.BRIDGE_X + 1.5):
    for st in ("thaw", "rime"):
        BLOCKERS.append({"min": [r2(xx - 0.45), deck_y - 1.0, r2(BZ - 6.0)], "max": [r2(xx + 0.45), deck_y + 2.0, r2(BZ + 6.0)],
                         "tag": st, "nav_only": True})

# --- the flocks ---------------------------------------------------------------------
# THAW: grazing loose on the high grass. RIME: frozen where they stood, all
# facing the High Fold, packed on the slope between the beck and the fold.
import random  # noqa: E402
rng = random.Random(6060)
TROD = [(H.BRIDGE_X, BZ - 6.0), (GAP[0], GAP[1])]


def near_trod(x, z, w):
    (ax, az), (bx2, bz2) = TROD
    d, _ = H._seg(x, z, ax, az, bx2, bz2)
    return d < w


LANE_KEEP = H.LANE_HALF + 0.6 + 2.0        # centre line to wall, the wall, and 2 m clear of it
placed = 0
while placed < 46:
    x, z = rng.uniform(566, 700), rng.uniform(-396, -272)
    if H.pasture_out(x, z) > -4 or abs(z - H.beck_z(x)) < 6 or math.hypot(x - FX, z - FZ) < H.FOLD_R + 3:
        continue
    if any(math.hypot(x - sx, z - sz) < 7 for sx, sz, _ in H.SHEILINGS):
        continue
    if H.lane_dist(x, z)[0] < LANE_KEEP or math.hypot(x - H.COUNTING_PAD[0], z - H.COUNTING_PAD[1]) < 5.0:
        continue      # the Drift Lane's walls are real: nothing grazes through them (its own ewes are set by hand)
    PROPS.append({"kit": "sheep", "at": at(x, z), "rot": rng.uniform(0, 360), "tag": "thaw", "collide": False})
    placed += 1
# a few more in THAW, in twos and threes near ones already out (ewes keep
# company). Their own stream: the layout stream above must not shift.
rng_more = random.Random(515)
first = [p["at"] for p in PROPS if p["kit"] == "sheep"]
placed = 0
while placed < 16:
    hx, _, hz = first[rng_more.randrange(len(first))]
    x, z = hx + rng_more.uniform(-3.5, 3.5), hz + rng_more.uniform(-3.5, 3.5)
    if H.pasture_out(x, z) > -4 or abs(z - H.beck_z(x)) < 6 or math.hypot(x - FX, z - FZ) < H.FOLD_R + 3:
        continue
    if any(math.hypot(x - sx, z - sz) < 7 for sx, sz, _ in H.SHEILINGS) or math.hypot(x - hx, z - hz) < 1.4:
        continue
    if H.lane_dist(x, z)[0] < LANE_KEEP or math.hypot(x - H.COUNTING_PAD[0], z - H.COUNTING_PAD[1]) < 5.0:
        continue
    # (these are the rigged ewe: FlockWander plays her walk as she ambles)
    PROPS.append({"kit": "sr_ewe", "at": at(x, z), "rot": rng_more.uniform(0, 360), "tag": "thaw", "collide": False, "wander": True})
    placed += 1
placed = 0
tries = 0
while placed < 70 and tries < 4000:
    tries += 1
    x, z = rng.uniform(600, 700), rng.uniform(-398, -345)
    if H.pasture_out(x, z) > -3 or z > H.beck_z(x) - 6 or math.hypot(x - FX, z - FZ) < H.FOLD_R + 3.5 or near_trod(x, z, 2.2):
        continue
    if H.lane_dist(x, z)[0] < LANE_KEEP or math.hypot(x - H.FOLD_GAP[0], z - H.FOLD_GAP[1]) < 7.0:
        continue      # the frozen flock keeps 2 m off the lane's outer wall and out of the gap's mouth; the lane itself is empty
    face = math.degrees(math.atan2(-(FX - x), -(FZ - z)))     # their faces (local -Z) to the fold
    # standing, until she is released (REACH.md 9: one soft call, and the whole
    # slope lies down at once: Fellcaller.lie_flock_down finds them by group);
    # lying, ever after
    PROPS.append({"kit": "sheep", "at": at(x, z), "rot": r2(face), "tag": "rime", "collide": True,
                  "mat_remap": {"M_fleece": "M_rime", "M_wool": "M_rime", "M_leather": "M_rime"},
                  "group": "flock_rime", "absent_flag": "ks_fellcaller_released"})
    PROPS.append({"kit": "sheep", "at": at(x, z), "rot": r2(face), "tag": "rime", "collide": True,
                  "mat_remap": {"M_fleece": "M_rime", "M_wool": "M_rime", "M_leather": "M_rime"},
                  "scale": [1.0, 0.58, 1.0], "require_flag": "ks_fellcaller_released"})
    placed += 1

place = []

# --- people and the frost-taken -------------------------------------------------------
CAIRN = (FX + 3.0, FZ - 3.0)
FELLCALLER = (FX - 2.0, FZ - 2.0)
FATHER = (FELLCALLER[0] + 3.0, FELLCALLER[1] - 1.2)     # enemies.json fellcaller.father_off
hearths = [
    {"id": "hs_fell_path", "name": "the Fell Path", "at": at(538.0, -320.0), "rot": 200},
    {"id": "hs_sheilings", "name": "the Sheilings", "at": at(604.0, -306.0), "rot": 160},
    # wakes on release (REACH.md 1, 9)
    {"id": "hs_high_fold", "name": "the High Fold", "at": at(FX - 6.5, FZ - 5.5), "rot": 60, "require_flag": "ks_fellcaller_released"},
]
spawners = [
    {"enemy": "drover", "id": "drover_path", "at": at(556.0, -323.0, 0.1), "face": 270},
    {"enemy": "drover", "id": "drover_sheilings", "at": at(626.0, -292.0, 0.1), "face": 200},
    {"enemy": "drover", "id": "drover_bridge", "at": at(H.BRIDGE_X + 6.0, BZ - 9.0, 0.1), "face": 160},
    # (stood on the Drift Lane's line; now between the lane's wall and the trod)
    {"enemy": "frost_ram", "id": "ram_slope_a", "at": at(641.0, -357.5, 0.1), "face": 200},
    {"enemy": "frost_ram", "id": "ram_slope_b", "at": at(680.0, -386.0, 0.1), "face": 240},
    {"enemy": "frost_ram", "id": "ram_grass", "at": at(660.0, -300.0, 0.1), "face": 90},
    # REACH.md 6: beside her father at the cairn, calling out over the wall
    {"enemy": "fellcaller", "id": "fellcaller", "at": at(FELLCALLER[0], FELLCALLER[1], 0.1), "face": 315,
     "dead_once": True, "frost_veil_id": "fold_veil"},
]
_fo = (FELLCALLER[0] - FATHER[0], FELLCALLER[1] - FATHER[1])
TALLY_OFF = (_fo[0] / math.hypot(*_fo) * 1.1, _fo[1] / math.hypot(*_fo) * 1.1)
VEIL = at(GAP[0], GAP[1])
S0 = H.SHEILINGS[0]
pickups = [
    # REACH.md 2, 8: the whistle on its nail at the lower sheiling; his boots by the door
    {"id": "shepherds_whistle", "at": at(S0[0] - 3.5, S0[1] + 3.8, 0.05), "item": "item_shepherd_whistle", "tag": "base",
     "scene": "res://assets/models/props/bone_whistle.tscn", "label": "Take the shepherd's whistle"},
    {"id": "calder_boots", "at": at(S0[0] + 2.2, S0[1] + 4.3, 0.02), "rot": 12, "item": "item_calder_boots", "tag": "rime",
     "scene": "res://assets/models/props/calder_boots.tscn", "set_flag": "ks_calder_boots_found", "label": "Take the boots"},
    # REACH.md 9: the fold-tally by his hand. The Fellcaller sets it down herself
    # at the release (release_drop, the same pickup id, at her drop_point());
    # this keeps it for a Bearer who walks out or puts the game down before
    # taking it, on the same spot: 1.1 m from him toward where she stood.
    {"id": "fold_tally", "at": at(FATHER[0] + TALLY_OFF[0], FATHER[1] + TALLY_OFF[1], 0.05), "item": "item_fold_tally", "tag": "base",
     "label": "Take the fold-tally", "scene": "res://assets/models/props/fold_tally.tscn", "set_flag": "ks_fold_tally_found",
     "require_flag": "ks_fellcaller_released"},
]
# the trod from the bridge up to the fold's gap: Sigga calls from the slope beside it
TX, TZ = H.BRIDGE_X + (GAP[0] - H.BRIDGE_X) * 0.6 + 3.0, (BZ - 6.0) + (GAP[1] - (BZ - 6.0)) * 0.6
npcs = [
    # REACH.md 7: before the release, Calder at the gap with the wall; Sigga on the slope
    {"id": "old_calder", "at": at(GAP[0] + 3.5, GAP[1] + 2.0), "rot": 300, "tag": "thaw", "absent_flag": "ks_fellcaller_released"},
    {"id": "sigga", "at": at(TX, TZ), "rot": 200, "tag": "thaw", "absent_flag": "ks_fellcaller_released"},
    # REACH.md 9: after, the two of them in the fold, at the wall he has finished
    {"id": "old_calder", "at": at(FX - 7.0, FZ + 4.0), "rot": 240, "tag": "thaw", "require_flag": "ks_fellcaller_released"},
    {"id": "sigga_fold", "at": at(FX - 5.4, FZ + 5.2), "rot": 300, "tag": "thaw", "require_flag": "ks_fellcaller_released"},
    # REACH.md 4: RIME. He is laid out at the foot of the cairn where she found him (head to the south)
    {"id": "calder_rime", "at": at(FATHER[0], FATHER[1] - 0.9), "rot": 0, "tag": "rime"},
]
# his boots, off, beside him at the wall (after the release, THAW)
LANDMARKS.append({"scene": "res://assets/models/props/calder_boots.tscn", "at": at(FX - 7.9, FZ + 4.9, 0.02), "rot": 240,
                  "tag": "thaw", "require_flag": "ks_fellcaller_released"})

# ----------------------------------------------------------------- points of interest
# docs/lore/POI.md 7, and the Reach's own prop set (docs/art/BIOMES.md). Every
# piece here is set by hand, so it survives a regenerate; Wayside is off.
HOUSES, BUILDINGS, PLAQUES_POI, GATES, FENCES_POI, POI_CLEAR = [], [], [], [], [], []


def rot_off(cx, cz, yaw, ox, oz):
    a = math.radians(yaw)
    return (cx + ox * math.cos(a) + oz * math.sin(a), cz - ox * math.sin(a) + oz * math.cos(a))


def prop(kit, x, z, rot=0, tag="base", **kw):
    d = {"kit": kit, "at": at(x, z), "rot": r2(rot)}
    if tag != "base":
        d["tag"] = tag
    d.update(kw)
    PROPS.append(d)
    POI_CLEAR.append([r2(x), r2(z), 2.2])
    return d


# --- 7.3 sr_lower_sheiling: the Lower Sheiling (S0, a house now) ----------------
# The door is on the latch. THAW: two heather beds, both a mess; a pot, two
# bowls, a crook by the door. RIME: one bed made, the other thrown back.
S0X, S0Z, S0R = H.SHEILINGS[0]
S0Y = g(S0X, S0Z)
HOUSES.append({"id": "sheiling_low", "center": [S0X, S0Z], "size": [8, 4], "yaw": S0R, "y": S0Y, "wall_h": 2.6,
               "doors": [["S", 0]], "gate_doors": [], "open": [], "style": "store", "gable": "shed"})
S0_DOOR = rot_off(S0X, S0Z, S0R, -2.0, 2.0)
BUILDINGS.append({"id": "sheiling_low", "center": [S0X, S0Z], "size": [8, 4], "yaw": S0R, "y": S0Y,
                  "doors": [[r2(S0_DOOR[0]), r2(S0_DOOR[1])]], "open": []})


def in_s0(kit, ox, oz, rot=0, tag="base", **kw):
    x, z = rot_off(S0X, S0Z, S0R, ox, oz)
    d = {"kit": kit, "at": [r2(x), S0Y, r2(z)], "rot": r2(S0R + rot), "collide": False}
    if tag != "base":
        d["tag"] = tag
    d.update(kw)
    PROPS.append(d)
    return d


BED_A = (-2.3, -1.05)          # along the north wall: Sigga's, made in RIME
BED_B = (1.9, 1.05)            # across from it, by the south wall: his, thrown back
in_s0("sr_heather_bed_thrown", BED_A[0], BED_A[1], 0, tag="thaw")
in_s0("sr_heather_bed", BED_A[0], BED_A[1], 0, tag="rime")
in_s0("sr_heather_bed_thrown", BED_B[0], BED_B[1], 180)
in_s0("sr_pot_bowls", 0.3, -1.0, 40)
in_s0("sr_crook_rack", -3.55, 0.6, 90)
in_s0("sr_cheese_press", 3.0, -0.95, -90, collide=True)
in_s0("sr_shearing_stool", 0.2, 0.9, 25)
_bx, _bz = rot_off(S0X, S0Z, S0R, BED_A[0] + 0.35, BED_A[1] + 0.85)
pickups.append({"id": "calder_blanket", "at": [r2(_bx), S0Y, r2(_bz)], "rot": r2(S0R), "item": "item_calder_blanket", "kit": "sr_blanket",
                "tag": "rime", "label": "Take the blanket", "lift": 0.31, "show_at": [r2(rot_off(0, 0, S0R, 0.0, -0.85)[0]), r2(rot_off(0, 0, S0R, 0.0, -0.85)[1])]})

# --- 7.2 sr_smudge: Smudge (at the lower sheiling's door) -----------------------
# One ewe did not answer the call. THAW: grazing by the door and nowhere else;
# the pocket of the Shepherd's Fleece brings her. RIME: stood at the door with
# her back to the fold; she lies down with the rest at the release.
SMUDGE = rot_off(S0X, S0Z, S0R, -1.2, 3.5)
_fx, _fz = S0_DOOR[0] - SMUDGE[0], S0_DOOR[1] - SMUDGE[1]
SMUDGE_FACE = r2(math.degrees(math.atan2(-_fx, -_fz)))             # her face (local -Z) to the door
PROPS.append({"kit": "sr_smudge", "at": at(SMUDGE[0], SMUDGE[1]), "rot": r2(SMUDGE_FACE + 25), "tag": "thaw", "collide": False})
_rm = {"M_fleece": "M_rime", "M_wool": "M_rime", "M_leather": "M_rime"}
PROPS.append({"kit": "sr_smudge", "at": at(SMUDGE[0], SMUDGE[1]), "rot": SMUDGE_FACE, "tag": "rime", "collide": True, "mat_remap": _rm,
              "group": "flock_rime", "absent_flag": "ks_fellcaller_released"})
PROPS.append({"kit": "sr_smudge", "at": at(SMUDGE[0], SMUDGE[1]), "rot": SMUDGE_FACE, "tag": "rime", "collide": True, "mat_remap": _rm,
              "scale": [1.0, 0.58, 1.0], "require_flag": "ks_fellcaller_released"})
_lx, _lz = rot_off(S0X, S0Z, S0R, -0.2, 4.4)
pickups.append({"id": "smudge_look", "at": at(_lx, _lz), "tag": "rime", "bare": True, "label": "Look at the ewe", "set_flag": "ks_smudge_found",
                "look": "A ewe with a dark smear down her nose. She is the only one on the fell not facing the fold. She is facing the door."})
pickups.append({"id": "smudge_pocket", "at": at(_lx, _lz), "tag": "thaw", "bare": True, "label": "Turn out the pocket", "needs_item": "armour_fleece",
                "warmth": 90, "set_flag": "ks_smudge_fed"})
_cx, _cz = rot_off(S0X, S0Z, S0R, -3.3, 2.75)
prop("sr_crook_rack", _cx, _cz, S0R + 180, collide=False)          # the crooks by the door, under the eave

# --- 7.1 sr_counting_stone: the Counting Stone (the beck's south bank) ----------
# On its pad (high_land.COUNTING_PAD), 5 m short of the plank bridge and 3 m
# west of the trod: NOT on the bridge. Two plaques on one board.
CPX, CPZ = H.COUNTING_PAD[0], H.COUNTING_PAD[1]
prop("sr_counting_stone", CPX - 0.5, CPZ - 0.3, 20)
COUNT_BOARD = at(CPX + 1.6, CPZ + 1.2)
PLAQUES_POI.append({"at": COUNT_BOARD, "rot": 200, "tag": "thaw",
                    "text": "THE COUNTING STONE\n\nOne pebble in the hollow for every ewe over the bridge.\nForty-three pebbles, and room in the hollow for one more."})
PLAQUES_POI.append({"at": COUNT_BOARD, "rot": 200, "tag": "rime",
                    "text": "THE COUNTING STONE\n\nNothing has come back over the bridge.\nEvery one of them is facing up the hill."})
# the slab gate at the bridge's south end: the slabs stand clear of the planks
# either side, the rails are drawn and laid by (nothing in the way)
GATE_Z = r2(BZ + 6.2)
prop("sr_slab_gate", H.BRIDGE_X, GATE_Z, 0, collide=False)
for sx in (-1.6, 1.6):
    BLOCKERS.append({"min": [r2(H.BRIDGE_X + sx - 0.14), r2(g(H.BRIDGE_X, GATE_Z) - 0.3), r2(GATE_Z - 0.32)],
                     "max": [r2(H.BRIDGE_X + sx + 0.14), r2(g(H.BRIDGE_X, GATE_Z) + 1.45), r2(GATE_Z + 0.32)], "tag": "base"})

# --- 7.4 sr_drift_lane: the Drift Lane (the shortcut) ---------------------------
# Two drystone walls 3 m apart from the beck's north bank up the west edge of
# the slope to the fold wall. RIME: its bottom gate is tied shut on the lane
# side; untied from above, it is the short way from the Sheilings hearth to
# the fold gap, with no sheep and no rams in it. THAW: the gate stands open.
LANE = H.DRIFT_LANE
WALL_OFF = H.LANE_HALF + 0.3


def _lane_side(sign):
    pts = []
    for i, (x, z) in enumerate(LANE):
        ax, az = LANE[max(i - 1, 0)]
        bx2, bz2 = LANE[min(i + 1, len(LANE) - 1)]
        ln = math.hypot(bx2 - ax, bz2 - az)
        nx, nz = -(bz2 - az) / ln, (bx2 - ax) / ln
        pts.append([r2(x + sign * nx * WALL_OFF), r2(z + sign * nz * WALL_OFF)])
    return pts


LANE_E = _lane_side(1.0)          # the wall on the trod's side
LANE_W = _lane_side(-1.0)
# one section of the east wall is the creep: a hole a ewe can go through
CREEP_AT = 0.5                    # along the second length of the wall
_ca, _cb = LANE_E[1], LANE_E[2]
_cl = math.hypot(_cb[0] - _ca[0], _cb[1] - _ca[1])
_cu = ((_cb[0] - _ca[0]) / _cl, (_cb[1] - _ca[1]) / _cl)
CREEP = (_ca[0] + (_cb[0] - _ca[0]) * CREEP_AT, _ca[1] + (_cb[1] - _ca[1]) * CREEP_AT)
CREEP_ROT = r2(math.degrees(math.atan2(-_cu[1], _cu[0])))
FENCES_POI.append({"kind": "drystone", "points": [LANE_E[0], LANE_E[1], [r2(CREEP[0] - _cu[0] * 1.05), r2(CREEP[1] - _cu[1] * 1.05)]]})
# (a fence is laid in whole 2 m sections and may run a section past its last
# point: the walls stop short of the lane's head so its mouth stays open to the fold gap)
def _short(pts, by=0.8):
    (ax, az), (bx2, bz2) = pts[-2], pts[-1]
    ln = math.hypot(bx2 - ax, bz2 - az)
    return pts[:-1] + [[r2(bx2 - (bx2 - ax) / ln * by), r2(bz2 - (bz2 - az) / ln * by)]]


LANE_E = _short(LANE_E)
LANE_W = _short(LANE_W)
FENCES_POI.append({"kind": "drystone", "points": [[r2(CREEP[0] + _cu[0] * 1.05), r2(CREEP[1] + _cu[1] * 1.05)], LANE_E[2], LANE_E[3], LANE_E[4]]})
FENCES_POI.append({"kind": "drystone", "points": LANE_W})
prop("sr_creep_wall", CREEP[0], CREEP[1], CREEP_ROT)
for side in (LANE_E, LANE_W):
    for (ax, az), (bx2, bz2) in zip(side, side[1:]):
        ln = math.hypot(bx2 - ax, bz2 - az)
        nx, nz = -(bz2 - az) / ln * 0.6, (bx2 - ax) / ln * 0.6
        THICKETS.append({"poly": [[r2(ax + nx), r2(az + nz)], [r2(bx2 + nx), r2(bz2 + nz)], [r2(bx2 - nx), r2(bz2 - nz)], [r2(ax - nx), r2(az - nz)]],
                         "tag": "base"})
_d0 = ((LANE[1][0] - LANE[0][0]), (LANE[1][1] - LANE[0][1]))
_dl = math.hypot(*_d0)
LANE_UP = (_d0[0] / _dl, _d0[1] / _dl)
LANE_GATE_ROT = r2(math.degrees(math.atan2(-LANE_UP[0], -LANE_UP[1])))       # its tied (locked) face, +Z, to the beck
LANE_GATE_AT = at(LANE[0][0], LANE[0][1])
GATES.append({"id": "gate_drift_lane", "at": LANE_GATE_AT, "rot": LANE_GATE_ROT, "width": 3.0, "height": 1.3, "tag": "rime", "leaves": False,
              "locked_prompt": "Tied from the other side", "open_prompt": "Untie the gate", "open_toast": "The gate is untied.",
              "dressing": {"scene": "res://assets/models/landmarks/lm_sr_slip_rails.glb", "rot": 180}})
prop("sr_slab_posts", LANE[0][0], LANE[0][1], LANE_GATE_ROT, collide=False)
prop("sr_rails_down", LANE[0][0] - LANE_UP[0] * 0.9 - LANE_UP[1] * 2.6, LANE[0][1] - LANE_UP[1] * 0.9 + LANE_UP[0] * 2.6, LANE_GATE_ROT + 8,
     tag="thaw", collide=False)
# the cache that lay on the open slope is on the wall's coping halfway down the lane
_mx, _mz = LANE[2]
pickups.append({"id": "fold_cache", "at": at(_mx + (LANE_W[2][0] - _mx) * 0.6, _mz + (LANE_W[2][1] - _mz) * 0.6, 0.05), "item": "bog_iron", "count": 2, "tag": "rime",
                "label": "Pry up what the frost holds"})
# THAW: ewes in the lane, one with her head through the creep
for (t, off, r) in ((0.25, 0.4, 40), (0.62, -0.5, 200)):
    k = int(t * (len(LANE) - 1))
    f = t * (len(LANE) - 1) - k
    x = LANE[k][0] + (LANE[k + 1][0] - LANE[k][0]) * f + off
    z = LANE[k][1] + (LANE[k + 1][1] - LANE[k][1]) * f
    PROPS.append({"kit": "sr_ewe", "at": at(x, z), "rot": r, "tag": "thaw", "collide": False})
PROPS.append({"kit": "sr_ewe", "at": at(CREEP[0] - _cu[1] * -0.75, CREEP[1] + _cu[0] * -0.75), "rot": r2(CREEP_ROT + 180), "tag": "thaw", "collide": False})
# where the wall is being put back: the stones laid out in the order they go
# (at the fold's gap, where Old Calder works; and at the lane's head)
prop("sr_coping_row", GAP[0] + 5.2, GAP[1] + 4.3, 62, collide=False)
prop("sr_coping_row", LANE_W[4][0] - 1.6, LANE_W[4][1] + 0.6, CREEP_ROT, collide=False)
prop("sr_wool_frame", LANE[4][0] - 4.2, LANE[4][1] - 1.2, 30)           # at the lane's top: the clip is packed where the flock is gathered

# --- the Reach's own prop set, where the work is done ---------------------
for k in (1, 2):
    sx, sz, sr = H.SHEILINGS[k]
    _x, _z = rot_off(sx, sz, sr, 2.4, 3.6)
    prop("sr_shearing_stool" if k == 1 else "sr_cheese_press", _x, _z, sr + 150)
    _x, _z = rot_off(sx, sz, sr, -2.6, 3.5)
    prop("sr_crook_rack", _x, _z, sr + 180, collide=False)
# variety (owner: more kinds, fewer repeats), each where it is used
prop("sr_fodder_rack", 611.5, -298.2, 70)                               # winter hay, by the sheilings
prop("sr_fodder_rack", 632.0, -288.0, 15)
prop("sr_stone_trough", 596.0, r2(H.beck_z(596.0) + 8.0), 90)           # filled from the beck, on its south bank
_x, _z = rot_off(H.SHEILINGS[2][0], H.SHEILINGS[2][1], H.SHEILINGS[2][2], -5.2, 4.8)
prop("sr_lamb_pen", _x, _z, H.SHEILINGS[2][2] + 90)                      # the lambing pen, in the upper sheiling's lee
# cairns that mark the way up (were Wayside's): at the head of the fell path and above the bridge
for (x, z, r, sc) in [(569.0, -313.0, 20, 0.9), (626.5, -343.0, 70, 0.8)]:
    LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_fold_cairn.glb", "at": at(x, z, -0.06), "rot": r, "scale": sc,
                      "blocker": [r2(2.0 * sc), r2(2.2 * sc), r2(2.0 * sc)]})
    POI_CLEAR.append([x, z, 2.5])

portals = [seam("reach", "shepherds_reach"), seam("coldwell", "shepherds_reach")]
arrive = seam("reach", "thornwold")
START = arrive["spawn"]

edges = {
    "doc": "tools/audit_edges.py: the fold wall is a thicket; the beck drowns in THAW and is a floor in RIME; the bridge is a floor.",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [466, -420, 722, -252],
    "buildings": BUILDINGS, "thickets": THICKETS,
    "state_floors": FLOORS + STATE_FLOORS,
    "gates": [{"id": gt["id"], "at": gt["at"], "rot": gt["rot"]} for gt in GATES],
}

D = {
    "id": "shepherds_reach",
    "name": "Shepherd's Reach",
    "start": {"pos": START, "yaw": arrive["spawn_yaw"]},
    "env": {"thaw": {"sun_rot": [-18, -80], "sun_energy": 2.6, "sun_color": [1.0, 0.9, 0.74], "fog_density": 0.0012, "vol_density": 0.006,
                     "ambient_energy": 0.68, "exposure": 1.06},
            "rime": {"sun_rot": [-26, -70], "fog_density": 0.008, "vol_density": 0.02}},
    "terrain": K.terrain_block(),
    "nav_bounds": [466, 20, -420, 722, 160, -252],
    "weather": {"gulls": False, "spindrift": 14},
    "water": [],
    "falls": FALLS,
    "hazards": hazards,
    "zones": [
        {"name": "THE SHEILINGS", "min": [466, -420], "max": [636, -252]},
        {"name": "THE HIGH FOLD", "min": [636, -420], "max": [722, -252]},
    ],
    "houses": HOUSES,
    "gates": GATES,
    "wayside": False,          # nothing strewn: the Reach is dressed by hand above
    "boxes": BOXES,
    "blockers": BLOCKERS,
    "props": PROPS,
    "landmarks": LANDMARKS,
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "fold_veil", "at": VEIL, "rot": r2(math.degrees(math.atan2(math.cos(math.radians(GAP_A)), math.sin(math.radians(GAP_A))))), "tag": "rime"}],
    "npcs": npcs,
    "plaques": [{"at": at(548.0, -316.0), "rot": 200, "text": "SHEPHERD'S REACH\n\nHigh pasture under the glacier. Her calls carried three valleys."}] + PLAQUES_POI,
    "pickups": pickups,
    "portals": portals,
    "scatter": {
        "seed": 6061,
        "clear": [[FX, FZ, H.FOLD_R + 3.0]] + [[sx, sz, 7.0] for sx, sz, _ in H.SHEILINGS] + POI_CLEAR
                 + [[x, z, 3.2] for (x, z) in H.DRIFT_LANE] + [[(a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 3.2] for a, b in zip(H.DRIFT_LANE, H.DRIFT_LANE[1:])],
        "rules": [
            {"kind": "rock", "count": 150, "region": [556, -398, 704, -270], "slope": [0.75, 1.0], "scale": [0.3, 0.9], "path_max": 0.3},
            {"kind": "boulder", "count": 70, "region": [470, -420, 722, -252], "slope": [0.45, 0.85], "scale": [1.0, 2.4]},
        ],
        "place": place,
        "fences": [{"kind": "drystone", "points": fold_pts}] + FENCES_POI,
        "veg": [
            {"kind": "grass", "region": [470, -420, 722, -252], "density": 1.4, "range": 45},
            {"kind": "heather", "region": [470, -420, 722, -252], "density": 0.4, "range": 40},
        ],
    },
    "edges": edges,
}

# --- progression gates (ADR 0015) ---------------------------------------------
# The foot of the Upwater: a head-dyke across the neck of the pasture and two
# wattle hurdles tied in its gap to keep the flock off the river. In RIME three
# of her ewes stand frozen against them, facing the fold. Sigga's release
# lays the ewes down and the hurdles stand open (REACH.md 9). Untied from the
# Coldwell side at any time. The track to it is in terrain_reach.path_weight.
import progress_gates as PG  # noqa: E402
_ua, _ub = H.UPWATER[0], H.UPWATER[1]
_uf = 0.45
_RIMED = {"M_fleece": "M_rime", "M_wool": "M_rime", "M_leather": "M_rime"}
_ewe_rot = r2(math.degrees(math.atan2(-(FX - 695.0), -(FZ + 385.0))))
UPWATER_GATE = PG.gate(
    "shepherds_reach", "upwater_hurdle", K.sample,
    at=(_ua[0] + (_ub[0] - _ua[0]) * _uf, _ua[1] + (_ub[1] - _ua[1]) * _uf), toward=(_ub[0] - _ua[0], _ub[1] - _ua[1]),
    flag="ks_fellcaller_released", name="the Upwater", to="coldwell", seam_at=seam("coldwell", "shepherds_reach")["at"],
    width=3.6, height=2.2, depth=0.3, flank="drystone",
    dressing=[{"scatter": "wattle_fence", "fit": [1.85, 1.3, 0.22], "along": -0.92, "rot": 3},
              {"scatter": "wattle_fence", "fit": [1.85, 1.3, 0.22], "along": 0.92, "rot": -2},
              {"scatter": "wattle_fence", "fit": [1.85, 1.3, 0.22], "along": -2.0, "out": -0.95, "rot": 84, "when": "open"},
              {"scatter": "wattle_fence", "fit": [1.85, 1.3, 0.22], "along": 2.0, "out": -0.95, "rot": -80, "when": "open"}]
    + [{"kit": "sheep", "along": al, "out": out, "rot": rr, "tag": "rime", "mat_remap": _RIMED, "abs_rot": True}
       for al, out, rr in ((-1.0, 0.9, 12), (0.1, 1.3, -8), (1.1, 0.8, 5))]
    + [{"kit": "sheep", "along": al, "out": out, "rot": rr, "tag": "rime", "mat_remap": _RIMED, "abs_rot": True,
        "scale": [1.0, 0.58, 1.0], "when": "open"}
       for al, out, rr in ((-2.6, 2.4, 12), (-3.4, 3.6, -8), (2.9, 2.2, 5))],
    locked_prompt="Tied from the other side", unbar_prompt="Untie the hurdles", open_toast="The hurdles swing back.")
for _d in UPWATER_GATE["gate"]["dressing"]:
    if _d.pop("abs_rot", False):          # the ewes face the fold, whichever way the gate runs
        _d["rot"] = r2(_ewe_rot + _d["rot"] - UPWATER_GATE["rot"])
PG.install(D, UPWATER_GATE)
D["landmarks"].append({"scene": "res://assets/models/landmarks/lm_fold_cairn.glb",
                       "at": at(UPWATER_GATE["gate"]["at"][0] - 4.6, UPWATER_GATE["gate"]["at"][2] + 1.2, -0.05), "rot": 140, "scale": 0.9,
                       # (solid: a box inside the round of the stones, not out to their corners)
                       "blocker": [2.0, 2.0, 2.0]})
# --- end progression gates

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "shepherds_reach.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
