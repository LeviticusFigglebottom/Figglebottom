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
for (sx, sz, rot) in H.SHEILINGS:
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
    # RIME: frozen to the brim; the ice carries you over
    top = r2(min(H.pasture_y(bx, bz - H.BECK_HALF - 2.5), H.pasture_y(bx, bz + H.BECK_HALF + 2.5)) - 0.15)
    BLOCKERS.append({"min": [r2(bx), r2(bed - 0.5), r2(bz - H.BECK_HALF - 2.0)], "max": [r2(bx + 4.0), top, r2(bz + H.BECK_HALF + 2.0)],
                     "tag": "rime"})
    BOXES.append({"min": [r2(bx), r2(top - 0.06), r2(bz - H.BECK_HALF - 1.0)], "max": [r2(bx + 4.0), top, r2(bz + H.BECK_HALF + 1.0)],
                  "mat": "M_ice", "tag": "rime", "collide": False})
    STATE_FLOORS.append({"tag": "rime", "min": [r2(bx), r2(bz - H.BECK_HALF - 2.0)], "max": [r2(bx + 4.0), r2(bz + H.BECK_HALF + 2.0)], "y": top})
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
# the AI gives the rails' ends a wide berth (no snagging on the posts)
for xx in (H.BRIDGE_X - 1.5, H.BRIDGE_X + 1.5):
    for st in ("thaw", "rime"):
        BLOCKERS.append({"min": [r2(xx - 0.45), deck_y - 1.0, r2(BZ - 4.6)], "max": [r2(xx + 0.45), deck_y + 2.0, r2(BZ + 4.6)],
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


placed = 0
while placed < 46:
    x, z = rng.uniform(566, 700), rng.uniform(-396, -272)
    if H.pasture_out(x, z) > -4 or abs(z - H.beck_z(x)) < 6 or math.hypot(x - FX, z - FZ) < H.FOLD_R + 3:
        continue
    if any(math.hypot(x - sx, z - sz) < 7 for sx, sz, _ in H.SHEILINGS):
        continue
    PROPS.append({"kit": "sheep", "at": at(x, z), "rot": rng.uniform(0, 360), "tag": "thaw", "collide": False})
    placed += 1
placed = 0
tries = 0
while placed < 70 and tries < 4000:
    tries += 1
    x, z = rng.uniform(600, 700), rng.uniform(-398, -345)
    if H.pasture_out(x, z) > -3 or z > H.beck_z(x) - 6 or math.hypot(x - FX, z - FZ) < H.FOLD_R + 3.5 or near_trod(x, z, 2.2):
        continue
    face = math.degrees(math.atan2(-(FX - x), -(FZ - z)))     # their faces (local -Z) to the fold
    # standing, until she is released (REACH.md 9: one soft call, and the whole
    # slope lies down at once: Fellcaller.lie_flock_down finds them by group);
    # lying, ever after
    PROPS.append({"kit": "sheep", "at": at(x, z), "rot": r2(face), "tag": "rime", "collide": True,
                  "mat_remap": {"M_wool": "M_rime", "M_leather": "M_rime"},
                  "group": "flock_rime", "absent_flag": "ks_fellcaller_released"})
    PROPS.append({"kit": "sheep", "at": at(x, z), "rot": r2(face), "tag": "rime", "collide": True,
                  "mat_remap": {"M_wool": "M_rime", "M_leather": "M_rime"},
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
    {"enemy": "frost_ram", "id": "ram_slope_a", "at": at(642.0, -360.0, 0.1), "face": 200},
    {"enemy": "frost_ram", "id": "ram_slope_b", "at": at(680.0, -386.0, 0.1), "face": 240},
    {"enemy": "frost_ram", "id": "ram_grass", "at": at(660.0, -300.0, 0.1), "face": 90},
    # REACH.md 6: beside her father at the cairn, calling out over the wall
    {"enemy": "fellcaller", "id": "fellcaller", "at": at(FELLCALLER[0], FELLCALLER[1], 0.1), "face": 315,
     "dead_once": True, "frost_veil_id": "fold_veil"},
]
VEIL = at(GAP[0], GAP[1])
S0 = H.SHEILINGS[0]
pickups = [
    # REACH.md 2, 8: the whistle on its nail at the lower sheiling; his boots by the door
    {"id": "shepherds_whistle", "at": at(S0[0] - 3.5, S0[1] + 3.8, 0.05), "item": "item_shepherd_whistle", "tag": "base",
     "scene": "res://assets/models/props/bone_whistle.tscn", "label": "Take the shepherd's whistle"},
    {"id": "calder_boots", "at": at(S0[0] + 2.2, S0[1] + 4.3, 0.02), "rot": 12, "item": "item_calder_boots", "tag": "rime",
     "scene": "res://assets/models/props/calder_boots.tscn", "set_flag": "ks_calder_boots_found", "label": "Take the boots"},
    {"id": "fold_cache", "at": at(FX - 9.0, FZ + 18.0, 0.05), "item": "bog_iron", "count": 2, "tag": "rime", "label": "Pry up what the frost holds"},
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

portals = [seam("reach", "shepherds_reach"), seam("coldwell", "shepherds_reach")]
arrive = seam("reach", "thornwold")
START = arrive["spawn"]

edges = {
    "doc": "tools/audit_edges.py: the fold wall is a thicket; the beck drowns in THAW and is a floor in RIME; the bridge is a floor.",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [466, -420, 722, -252],
    "buildings": [], "thickets": THICKETS,
    "state_floors": FLOORS + STATE_FLOORS,
    "gates": [],
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
    "boxes": BOXES,
    "blockers": BLOCKERS,
    "props": PROPS,
    "landmarks": LANDMARKS,
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "fold_veil", "at": VEIL, "rot": r2(math.degrees(math.atan2(math.cos(math.radians(GAP_A)), math.sin(math.radians(GAP_A))))), "tag": "rime"}],
    "npcs": npcs,
    "plaques": [{"at": at(548.0, -316.0), "rot": 200, "text": "SHEPHERD'S REACH\n\nHigh pasture under the glacier. Her calls carried three valleys."}],
    "pickups": pickups,
    "portals": portals,
    "scatter": {
        "seed": 6061,
        "clear": [[FX, FZ, H.FOLD_R + 3.0]] + [[sx, sz, 7.0] for sx, sz, _ in H.SHEILINGS],
        "rules": [
            {"kind": "rock", "count": 150, "region": [556, -398, 704, -270], "slope": [0.75, 1.0], "scale": [0.3, 0.9], "path_max": 0.3},
            {"kind": "boulder", "count": 70, "region": [470, -420, 722, -252], "slope": [0.45, 0.85], "scale": [1.0, 2.4]},
        ],
        "place": place,
        "fences": [{"kind": "drystone", "points": fold_pts}],
        "veg": [
            {"kind": "grass", "region": [470, -420, 722, -252], "density": 1.4, "range": 45},
            {"kind": "heather", "region": [470, -420, 722, -252], "density": 0.4, "range": 40},
        ],
    },
    "edges": edges,
}

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "shepherds_reach.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
