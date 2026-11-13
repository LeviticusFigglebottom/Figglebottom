#!/usr/bin/env python3
"""Authoring script for data/areas/thornwold.json: Thornwold (WORLD.md 5.5).

    the drove-road        out of the tarn basin through a notch (seam), laid
                          hedges either side, east through birch and pine
    the Collier's Clearing  charcoal clamps smoking under turf, Linnet
    the Hedge             rings of laid hedge round the grave under the
                          oldest pine; the innermost has a gap where a gate
                          should be

THAW: laid hedges waist-high, the gaps in the rings lined up on the road:
walk straight in to the grave. RIME: every hedge has grown into a wall of
frozen thorn twice a man's height; the drove-road is plugged and the rings'
gaps have moved (the old ones grown shut), so the way to the grave is a maze
round between the rings. The Hedgelayer waits inside the innermost ring,
behind the veil in its gap. Thicket holds the wood's edges.

Run: python3 tools/gen_thornwold.py [--keep-terrain]"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_thornwold as K  # noqa: E402
import thorn_land as T  # noqa: E402
from seams_thornwold import seam  # noqa: E402
from seams_high import seam as high_seam  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--keep-terrain" not in sys.argv:
    K.write()


def r2(v):
    return round(v, 2)


def g(x, z):
    return r2(K.sample(x, z))


def at(x, z, dy=0.0):
    return [r2(x), r2(g(x, z) + dy), r2(z)]


HEDGES, THICKETS, PROPS, BOXES, LANDMARKS = [], [], [], [], []
PLAQUES, GATES, POI_PICKUPS, POI_SPAWNERS, POI_CLEAR = [], [], [], [], []
GX, GZ = T.GRAVE


def poly_of(pts, w):
    """Audit polygons: a quad round each segment of a hedge line."""
    out = []
    for (ax, az), (bx, bz) in zip(pts, pts[1:]):
        L = math.hypot(bx - ax, bz - az)
        if L < 0.05:
            continue
        nx, nz = -(bz - az) / L * w * 0.5, (bx - ax) / L * w * 0.5
        ex, ez = (bx - ax) / L * 0.3, (bz - az) / L * 0.3
        out.append([[r2(ax - ex + nx), r2(az - ez + nz)], [r2(bx + ex + nx), r2(bz + ez + nz)],
                    [r2(bx + ex - nx), r2(bz + ez - nz)], [r2(ax - ex - nx), r2(az - ez - nz)]])
    return out


def hedge(pts, style, h, w, tag):
    pts = [[r2(p[0]), r2(p[1])] for p in pts]
    HEDGES.append({"pts": pts, "style": style, "h": h, "w": w, "tag": tag})
    for q in poly_of(pts, w + 0.6):
        THICKETS.append({"poly": q, "tag": tag})


def arc(r, a0, a1, step=2.0):
    """Points round the grave from angle a0 to a1 (degrees, increasing)."""
    n = max(2, int(abs(math.radians(a1 - a0)) * r / step) + 1)
    return [[GX + r * math.cos(math.radians(a0 + (a1 - a0) * i / (n - 1))),
             GZ + r * math.sin(math.radians(a0 + (a1 - a0) * i / (n - 1)))] for i in range(n)]


def ring(r, gaps, style, h, w, tag, gap_m=3.4):
    """A ring of hedge with gaps (angles in degrees, or (angle, metres)
    pairs), gap_m wide unless a pair says otherwise."""
    gs = sorted(((a[0] % 360, a[1]) if isinstance(a, (list, tuple)) else (a % 360, gap_m)) for a in gaps)
    for i, (a, wa) in enumerate(gs):
        b, wb = gs[(i + 1) % len(gs)]
        b += 360 if i == len(gs) - 1 else 0
        hedge(arc(r, a + math.degrees(wa / 2.0 / r), b - math.degrees(wb / 2.0 / r)), style, h, w, tag)


# --- the rings round the grave ----------------------------------------------
# THAW: laid hedges, every gap on the road side (west, 180): straight in.
# RIME: frozen thorn, the gaps moved round (the old ones grown shut): a maze.
R1, R2, R3 = T.RINGS
INNER_GAP = 180.0                  # never decided where the gate went: the same gap in both
# the Layer's Stiles (POI.md 6.4): one bearing, a stile through the outer and
# the middle ring, in both states. In RIME each is grown over until broken
# open from the inside (gates below).
STILE_A = 125.0
STILE_GAP = 2.8          # two posts, the rails either side, and room for a walker's shoulders
for r, gap in ((R3, 180.0), (R2, 180.0), (R1, INNER_GAP)):
    ring(r, [gap] + ([(STILE_A, STILE_GAP)] if r != R1 else []), "laid", 1.35, 1.0, "thaw")
for r, gaps in ((R3, [70.0]), (R2, [295.0]), (R1, [INNER_GAP])):
    ring(r, gaps + ([(STILE_A, STILE_GAP)] if r != R1 else []), "thorn", 3.2, 1.3, "rime")
# RIME: thorn spokes between the rings so the way round is the long way
for a, r0, r1 in ((150.0, R2 + 0.8, R3 - 0.8), (230.0, R1 + 0.8, R2 - 0.8)):
    hedge([[GX + r0 * math.cos(math.radians(a)), GZ + r0 * math.sin(math.radians(a))],
           [GX + r1 * math.cos(math.radians(a)), GZ + r1 * math.sin(math.radians(a))]], "thorn", 3.2, 1.3, "rime")
# the gap with no gate in it (Tripo), at the innermost ring
# the gate he never hung: made, and left leaning on the inside of the ring
# beside the gap where it should go (Tripo)
# (the five-bar gate itself, a small procedural prop: lm_hedge_gate is the Tripo
# hedge gap with the grave, not a gate)
LANDMARKS.append({"scene": "res://assets/models/props/hedge_gate.tscn",
                  "at": at(GX - R1 + 1.6, GZ + 4.4, -0.02), "rot": 75, "tilt": -14,
                  "absent_flag": "ks_hedgelayer_released"})
# on release it lies down flat across the gap (THORNWOLD.md 9; the Hedgelayer's
# release_gate_laid lays the same one in the fight)
LANDMARKS.append({"scene": "res://assets/models/props/hedge_gate.tscn",
                  "at": at(GX - R1, GZ, 0.04), "rot": 90, "tilt": -90,
                  "require_flag": "ks_hedgelayer_released"})
# the grave under the oldest pine
_gy = g(GX + 2.5, GZ)
BOXES.append({"min": [r2(GX + 1.4), r2(_gy - 0.3), r2(GZ - 1.0)], "max": [r2(GX + 3.6), r2(_gy + 0.4), r2(GZ + 1.0)], "mat": "M_turf", "tag": "base"})

# --- the drove-road: laid hedges either side ---------------------------------
CLEAR_X = (T.CLEARING[0] - T.CLEARING[2] - 1.0, T.CLEARING[0] + T.CLEARING[2] + 1.0)
OUTER_X = GX - R3 - 2.0


def side_line(off, x0, x1):
    """The road's line offset sideways by off (+ south), from x0 to x1."""
    pts = []
    for (ax, az), (bx, bz) in zip(T.DROVE, T.DROVE[1:]):
        L = math.hypot(bx - ax, bz - az)
        nx, nz = -(bz - az) / L, (bx - ax) / L
        for k in range(int(L / 2.0) + 1):
            f = k * 2.0 / L
            x, z = ax + (bx - ax) * f + nx * off, az + (bz - az) * f + nz * off
            if x0 <= x <= x1 and (not pts or math.hypot(x - pts[-1][0], z - pts[-1][1]) > 1.0):
                pts.append([x, z])
    return pts


for off in (-3.8, 3.8):
    for (x0, x1) in ((T.DROVE[0][0] + 4.0, CLEAR_X[0]), (CLEAR_X[1], OUTER_X)):
        line = side_line(off, x0, x1)
        # THAW: laid hedge with field gaps; RIME: the same line, frozen thorn
        mid = len(line) // 2
        hedge(line[:mid - 1], "laid", 1.35, 1.0, "thaw")
        hedge(line[mid + 1:], "laid", 1.35, 1.0, "thaw")
        hedge(line[:mid - 1] if off < 0 else line, "thorn", 3.0, 1.3, "rime")
        if off < 0:
            hedge(line[mid + 1:], "thorn", 3.0, 1.3, "rime")
# RIME: the road plugged with thorn twice past the clearing; go round through the wood
for px in (CLEAR_X[1] + 10.0, CLEAR_X[1] + 32.0):
    best = min(T.DROVE, key=lambda p: abs(p[0] - px))
    pz = best[1] + (px - best[0]) * 0.1
    hedge([[px, pz - 4.3], [px, pz + 4.3]], "thorn_heap", 3.0, 1.3, "rime")

# --- the wood's edge: thicket all round, open only where the road comes in ---
x0, z0, x1, z1 = T.WOOD
inset = 3.0
edge = []
R = T.WOOD_R - inset
for (cx, cz, a0) in ((x1 - T.WOOD_R, z0 + T.WOOD_R, -90.0), (x1 - T.WOOD_R, z1 - T.WOOD_R, 0.0),
                     (x0 + T.WOOD_R, z1 - T.WOOD_R, 90.0), (x0 + T.WOOD_R, z0 + T.WOOD_R, 180.0)):
    for k in range(7):
        a = math.radians(a0 + 15.0 * k)
        edge.append([cx + R * math.cos(a), cz + R * math.sin(a)])
edge.append(edge[0])
# densify, then split into runs, open where the drove-road enters (west side)
ROAD_IN_Z = T.DROVE[0][1]
FELL_OUT_Z = -331.0            # the fell path up to Shepherd's Reach leaves the wood's east side
dense = [edge[0]]
for (ax, az), (bx, bz) in zip(edge, edge[1:]):
    n = max(1, int(math.hypot(bx - ax, bz - az) / 3.0))
    for k in range(1, n + 1):
        dense.append([ax + (bx - ax) * k / n, az + (bz - az) * k / n])
runs, cur = [], []
for p in dense:
    if (p[0] < x0 + inset + 3.0 and abs(p[1] - ROAD_IN_Z) < 5.5) or (p[0] > x1 - inset - 3.0 and abs(p[1] - FELL_OUT_Z) < 5.5):
        if len(cur) > 1:
            runs.append(cur)
        cur = []
        continue
    cur.append(p)
if len(cur) > 1:
    runs.append(cur)
if len(runs) > 1 and runs[0][0] == runs[-1][-1]:
    runs[0] = runs[-1] + runs[0][1:]
    runs.pop()
for rn in runs:
    hedge(rn, "thicket", 2.6, 2.6, "base")

# --- the Collier's Clearing ----------------------------------------------------
CX, CZ, CR = T.CLEARING
CLAMPS = []
# the clamp set (BIOMES.md tw_clamp_set). THAW: all four turfed and lit (the
# Notch's plaque counts them). RIME: the two that hold a find are opened and
# raked out; the other two were never opened.
for k, a in enumerate((40.0, 110.0, 200.0, 290.0)):
    x, z = CX + 10.0 * math.cos(math.radians(a)), CZ + 10.0 * math.sin(math.radians(a))
    CLAMPS.append((x, z))
    rot = r2(a * 1.7 % 360)
    if k < 2:
        PROPS.append({"kit": "tw_clamp_b", "at": at(x, z, -0.06), "rot": rot, "tag": "thaw", "smoke": 2.2})
        PROPS.append({"kit": "tw_clamp_c", "at": at(x, z, -0.08), "rot": r2(a + 90.0), "tag": "rime"})   # the 1 m ring stands solid, set into the ground
    else:
        PROPS.append({"kit": "tw_clamp_b", "at": at(x, z, -0.06), "rot": rot, "smoke": 2.2})
# the fifth, not lit yet: billets stacked round the stake, waiting for turf
PROPS.append({"kit": "tw_clamp_a", "at": at(CX - 1.0, CZ - 3.6, -0.04), "rot": 25})
# the wood for the next burn. Each cord is set end-on to the clamp it feeds,
# a few strides out; the dry store is a roofed shelter on the west edge, and
# the sledge that takes the sacks out stands where the clearing meets the road
for k in (1, 3):
    a = math.radians((40.0, 110.0, 200.0, 290.0)[k] + 38.0)
    PROPS.append({"kit": "tw_cordwood", "at": at(CLAMPS[k][0] + 4.4 * math.cos(a), CLAMPS[k][1] + 4.4 * math.sin(a), -0.03),
                  "rot": r2(90.0 - math.degrees(a))})
PROPS.append({"kit": "tw_wood_shelter", "at": at(CX - 14.2, CZ - 4.5, -0.03), "rot": 90})
PROPS.append({"kit": "tw_sledge", "at": at(CX + 7.5, CZ - 13.2, 0.0), "rot": 74})
PROPS.append({"kit": "tw_charcoal_sacks", "at": at(CX + 5.2, CZ - 12.6, 0.0), "rot": 200})
PROPS.append({"kit": "creel_stack", "at": at(CX - 3.0, CZ + 8.0), "rot": 30, "collide": False})
PROPS.append({"kit": "rope_coil", "at": at(CX + 2.0, CZ - 6.0), "rot": 10, "collide": False})

# --- points of interest (docs/lore/POI.md 6) -----------------------------------
# Placed by hand, not scattered: each survives regeneration where it is.


def ring_pt(r, a):
    return GX + r * math.cos(math.radians(a)), GZ + r * math.sin(math.radians(a))


# 6.1 the Notch: a bay on the road's side as it comes out of the notch, a
# hurdle rail, a cord of wood, and one board with a caption for each state.
# The ground is already level there (the wood floor meets the road); the bay
# is cut out of the trees, and a sight line is cut east toward the pine.
NOTCH_BAY = (306.5, -316.0)                   # 6 x 4 m, its long side on the road
POI_CLEAR.append([NOTCH_BAY[0], NOTCH_BAY[1], 4.6])
for k in range(4):                            # the canopy cut: about eight trees
    f = (k + 1) / 5.0
    POI_CLEAR.append([r2(NOTCH_BAY[0] + 4.0 + 20.0 * f), r2(NOTCH_BAY[1] - 1.2 * f), 3.0])
for k in range(3):
    PROPS.append({"kit": "tw_hurdle", "at": at(NOTCH_BAY[0] - 1.9 + 1.9 * k, NOTCH_BAY[1] + 2.15, -0.02), "rot": (4, -3, 5)[k]})
PROPS.append({"kit": "tw_cordwood", "at": at(NOTCH_BAY[0] - 3.3, NOTCH_BAY[1] + 0.3, -0.03), "rot": 84})
NOTCH_BOARD = at(NOTCH_BAY[0] + 2.6, NOTCH_BAY[1] + 1.2, 0.0)
PLAQUES.append({"at": NOTCH_BOARD, "rot": 215, "tag": "thaw",
                "text": "THE NOTCH\n\nFour clamps are lit. Blue smoke means burning and white means cooking.\nAll four are white."})
PLAQUES.append({"at": NOTCH_BOARD, "rot": 215, "tag": "rime",
                "text": "THE NOTCH\n\nThree rings of hedge round one pine.\nA hedge keeps stock in. There is no stock in there."})

# 6.2 Linnet's Hut, on the clearing's edge, its door to the clamps. THAW: one
# bed, two cups, his whetstone on her shelf. RIME: the bed slept in and not
# made, the floor swept into one corner, and what she cut off in the sweepings.
HUT = (335.5, -293.0)
HUT_ROT = r2(math.degrees(math.atan2(CX - HUT[0], CZ - HUT[1])))      # the door (+Z) looks at the clamps
POI_CLEAR.append([HUT[0], HUT[1], 4.2])


def hut_pt(dx, dz, dy=0.0):
    """A point in the hut's own frame (x across the door, z out of it)."""
    a = math.radians(HUT_ROT)
    return at(HUT[0] + dx * math.cos(a) + dz * math.sin(a), HUT[1] - dx * math.sin(a) + dz * math.cos(a), dy)


PROPS.append({"kit": "tw_collier_hut", "at": at(HUT[0], HUT[1], -0.04), "rot": HUT_ROT})
# (the yard's origin is its stool and the interiors' is the bed: thornwold_props.ORIGINS)
PROPS.append({"kit": "tw_hut_yard", "at": hut_pt(1.15, 2.35, -0.02), "rot": HUT_ROT, "collide": False})
PROPS.append({"kit": "tw_hut_thaw", "at": hut_pt(-0.72, -0.5, -0.02), "rot": HUT_ROT, "tag": "thaw", "collide": False,
              "glow": [0.8, 0.9, 3.2]})        # lived in: a little firelight inside, so the door shows the room
PROPS.append({"kit": "tw_hut_rime", "at": hut_pt(-0.72, -0.5, -0.02), "rot": HUT_ROT, "tag": "rime", "collide": False})
PROPS.append({"kit": "tw_riddle_stand", "at": hut_pt(2.7, 2.4), "rot": r2(HUT_ROT + 40)})
PROPS.append({"kit": "tw_charcoal_sacks", "at": hut_pt(-2.7, 1.9), "rot": r2(HUT_ROT - 25)})
POI_PICKUPS.append({"id": "wool_ends", "at": hut_pt(0.6, 1.5, 0.02), "item": "item_wool_ends", "tag": "rime", "label": "Gather the ends",
                    "scene": "res://assets/models/props/wool_ends.tscn", "set_flag": "ks_wool_ends_found"})

# 6.3 the Field They Haven't Got: a square of hedge 14 m a side, laid on three
# sides, a pair of gateposts in the east side and a pair in the west and no
# gate in either. The fourth side, to the road, was never begun. RIME: the
# three sides are frozen thorn, a Rime-stag stands in it, and the Collier
# who stood by the road stands in the open side.
FIELD = (372.0, -302.0)
FH = 7.0
GATE_HALF = 1.5
POI_CLEAR.append([FIELD[0], FIELD[1], 11.3])
for style, hh, ww, tag in (("laid", 1.35, 1.0, "thaw"), ("thorn", 3.0, 1.3, "rime")):
    for sx in (-1, 1):
        x = FIELD[0] + sx * FH
        hedge([[x, FIELD[1] - FH], [x, FIELD[1] - GATE_HALF - 0.35]], style, hh, ww, tag)
        hedge([[x, FIELD[1] + GATE_HALF + 0.35], [x, FIELD[1] + FH]], style, hh, ww, tag)
    hedge([[FIELD[0] - FH, FIELD[1] + FH], [FIELD[0] + FH, FIELD[1] + FH]], style, hh, ww, tag)
GATEPOSTS = [(FIELD[0] + sx * FH, FIELD[1] + sz * GATE_HALF) for sx in (-1, 1) for sz in (-1, 1)]
for k, (x, z) in enumerate(GATEPOSTS):
    PROPS.append({"kit": "tw_gatepost", "at": at(x, z, -0.05), "rot": (90 if x < FIELD[0] else -90) + (8, -6, 5, -9)[k]})
# his work, left where he was doing it: at the unlaid end of the west side,
# the stakes he had pointed, the block and bill he pointed them on, the horse
# he shaved the binders on, and two hurdles leaning ready to stop the gateway
PROPS.append({"kit": "tw_hedging_tools", "at": at(FIELD[0] - FH + 1.7, FIELD[1] - FH + 0.6), "rot": 200})
PROPS.append({"kit": "tw_stake_bundle", "at": at(FIELD[0] - FH + 1.3, FIELD[1] - FH + 2.4), "rot": 96, "collide": False})
PROPS.append({"kit": "tw_shaving_horse", "at": at(FIELD[0] - FH + 3.4, FIELD[1] - FH + 1.6), "rot": 150})
for k in range(2):
    PROPS.append({"kit": "tw_hurdle", "at": at(FIELD[0] - FH + 0.8, FIELD[1] + GATE_HALF + 1.5 + 1.95 * k, 0.0),
                  "rot": 90 + 4 * k, "tilt": -14 - 3 * k, "collide": False})
# the latch he whittled, on the east post nearest the road
LATCH_POST = GATEPOSTS[2]
POI_PICKUPS.append({"id": "gate_latch", "at": at(LATCH_POST[0] - 0.7, LATCH_POST[1], 0.02), "item": "item_gate_latch", "tag": "rime",
                    "label": "Take the latch", "scene": "res://assets/models/props/gate_latch.tscn", "lift": 1.42, "show_off": [0.7, 0.0],
                    "set_flag": "ks_gate_latch_found"})
POI_SPAWNERS.append({"enemy": "rime_stag", "stand_in": "hearthhound", "id": "stag_field", "at": at(FIELD[0] + 1.0, FIELD[1] + 1.5, 0.1), "face": 0})
COLLIER_FIELD = at(FIELD[0], FIELD[1] - FH - 1.2, 0.1)

# 6.4 the Layer's Stiles: the missing shortcut. Two plank stiles on one
# bearing, through the outer and the middle ring. THAW: nobody needs them.
# RIME: thorn has grown over each from the outside; broken off from inside
# its ring, the run from the Outer Ring hearth to the veil is two stiles.
for gid, r in (("stile_outer", R3), ("stile_inner", R2)):
    sx, sz = ring_pt(r, STILE_A)
    rot = r2(90.0 - STILE_A)                       # the gate's barred face (+Z) looks outward
    PROPS.append({"kit": "tw_stile", "at": at(sx, sz, -0.02), "rot": rot, "collide": False})
    GATES.append({"id": gid, "at": at(sx, sz), "rot": rot, "width": STILE_GAP - 0.4, "tag": "rime", "leaves": False, "height": 2.6,
                  "locked_prompt": "Grown over", "open_prompt": "Break the thorn off the stile", "open_toast": "The thorn comes away.",
                  "dressing": {"scene": "res://assets/models/landmarks/lm_thorn_stile.glb", "offset": [0, -0.05, 0.25], "rot": 0,
                               "scale": 1.0, "family": "M_thorn_rime", "range": 40.0, "shadow": False}})
    # the audit's wall for a barred stile (RIME, until it is broken open)
    THICKETS.append({"poly": poly_of([list(ring_pt(r, STILE_A - math.degrees(1.6 / r))), list(ring_pt(r, STILE_A + math.degrees(1.6 / r)))], 1.9)[0],
                     "tag": "rime"})
_px, _pz = ring_pt(R3 - 2.6, STILE_A + 4.5)
PLAQUES.append({"at": at(_px, _pz, 0.0), "rot": r2(270.0 - STILE_A), "tag": "rime",
                "text": "THE HEDGE\n\nThere is a stile in every ring, built the proper way.\nThen he let the thorn grow over them."})

# Draw budget: the wood closes every view at about 70 m, so none of the
# region's own pieces is drawn from further (the hedge maze's view is already
# at its primitive budget; docs/art/LOOK_PASS.md pass 5).
for p in PROPS:
    if str(p.get("kit", "")).startswith("tw_"):
        p["range"] = 45.0 if p["kit"] in ("tw_stake_bundle", "tw_gatepost", "tw_hut_yard", "tw_hut_thaw", "tw_hut_rime", "tw_hedging_tools",
                                          "tw_shaving_horse", "tw_stile") else 75.0

# --- forest -------------------------------------------------------------------
FOREST_CLEAR = [[CX, CZ, CR], [GX, GZ, R3 + 3.0], [481.0, -331.0, 6.0]] + POI_CLEAR
forest = {
    "seed": 5150,
    "clear": FOREST_CLEAR,
    "trees": [
        {"kind": "birch", "count": 260, "region": [x0 + 4, z0 + 4, x1 - 4, z1 - 4], "scale": [0.8, 1.25], "path_max": 0.2},
        {"kind": "pine", "count": 170, "region": [x0 + 4, z0 + 4, x1 - 4, z1 - 4], "scale": [0.85, 1.3], "path_max": 0.2},
        {"kind": "pine", "count": 40, "region": [x0 - 30, z0 - 30, x1 + 10, z1 + 20], "scale": [0.9, 1.4], "path_max": 0.2, "slope_min": 0.55},
        # dead standing pines among the living (Forest falls back to a pine
        # when the hero snag is missing)
        {"kind": "snag", "count": 16, "region": [x0 + 4, z0 + 4, x1 - 4, z1 - 4], "scale": [0.85, 1.15], "path_max": 0.2},
    ],
    # the oldest pine, over the grave: its own gnarled hero (a big pine when missing)
    "place": [{"kind": "grave_pine", "at": [r2(GX + 0.5), r2(GZ - 2.2)], "scale": 1.3}],
    "hedges": HEDGES,
}

# --- people and the frost-taken ----------------------------------------------
hearths = [
    {"id": "hs_drove_road", "name": "the Drove-Road", "at": at(T.DROVE[0][0] + 6.0, T.DROVE[0][1] + 5.0), "rot": 200},
    {"id": "hs_colliers_clearing", "name": "the Collier's Clearing", "at": at(CX - 6.0, CZ + 3.0), "rot": 140},
    # outside the outermost ring's RIME gap: nearest the Holdfast (THORNWOLD.md 1)
    {"id": "hs_outer_ring", "name": "the Outer Ring", "at": at(GX + (R3 + 3.5) * math.cos(math.radians(70.0)),
                                                             GZ + (R3 + 3.5) * math.sin(math.radians(70.0))), "rot": 250},
    # at the grave, woken when he is released (release_hearth)
    {"id": "hs_the_pine", "name": "the Pine", "at": at(GX - 2.0, GZ + 3.0), "rot": 90, "require_flag": "ks_hedgelayer_released"},
]
spawners = [
    {"enemy": "collier", "stand_in": "rimewalker", "id": "collier_clamp_a", "at": at(CLAMPS[0][0] - 2.5, CLAMPS[0][1] + 2.5, 0.1), "face": 200},
    {"enemy": "collier", "stand_in": "rimewalker", "id": "collier_clamp_b", "at": at(CLAMPS[2][0] + 3.0, CLAMPS[2][1], 0.1), "face": 20},
    # (he stood "on the road" 7 m off it; the Field's open side is 7 m off the road)
    {"enemy": "collier", "stand_in": "rimewalker", "id": "collier_road", "at": COLLIER_FIELD, "face": 180},
    {"enemy": "rime_stag", "stand_in": "hearthhound", "id": "stag_wood", "at": at(400.0, -300.0, 0.1), "face": 200},
    {"enemy": "rime_stag", "stand_in": "hearthhound", "id": "stag_rings", "at": at(GX, GZ - (R2 + R3) / 2.0, 0.1), "face": 90},
    {"enemy": "hedgelayer", "stand_in": "netmender", "id": "hedgelayer", "at": at(GX - 4.0, GZ + 4.0, 0.1), "face": 270,
     "dead_once": True, "frost_veil_id": "hedge_veil"},
] + POI_SPAWNERS
VEIL = at(GX + R1 * math.cos(math.radians(INNER_GAP)), GZ + R1 * math.sin(math.radians(INNER_GAP)))
# the frost-taken stag statues, mid-bound in the wood (RIME)
for (sx, sz, rot) in ((372.0, -292.0, 120), (418.0, -350.0, 30)):
    LANDMARKS.append({"scene": "res://assets/models/enemies/rime_stag.glb", "at": at(sx, sz), "rot": rot, "tag": "rime", "hull": True})
pickups = [
    {"id": "hedging_bill", "at": at(GX - R3 - 3.0, GZ + 5.0, 0.05), "item": "hedging_bill", "tag": "rime", "label": "Take the hedging bill",
     "scene": "res://assets/models/weapons/hedging_bill.glb"},
    # THORNWOLD.md 2, 3: the knucklebone on the road going east; the ring in the clamp's ash
    {"id": "knucklebone", "at": at(338.0, -315.2, 0.02), "item": "item_knucklebone", "tag": "rime", "label": "Pick up the knucklebone",
     "scene": "res://assets/models/props/knucklebone.tscn", "set_flag": "ks_knucklebone_found"},
    {"id": "birch_ring", "at": at(CLAMPS[0][0] - 2.6 * math.cos(math.radians(40.0)), CLAMPS[0][1] - 2.6 * math.sin(math.radians(40.0)), 0.02),
     "item": "item_birch_ring", "tag": "rime", "label": "Take the ring from the ash", "scene": "res://assets/models/props/birch_ring.tscn"},
    {"id": "clamp_cache", "at": at(CLAMPS[1][0] - 2.8, CLAMPS[1][1], 0.05), "item": "bog_iron", "count": 2, "tag": "rime",
     "label": "Rake out what the clamp kept"},
    # Linnet's song-cord, on the grave once he is released (THORNWOLD.md 9). The
    # Hedgelayer sets it down himself in the fight (release_drop, the same
    # pickup id, on the turf's edge); this keeps it for a Bearer who walks out
    # or puts the game down before taking it: at the grave's foot, on the
    # ground (audit_areas.py counts the land as floor, not the turf box).
    {"id": "song_cord", "at": at(GX + 1.0, GZ, 0.02), "item": "item_song_cord", "tag": "base", "label": "Take the song-cord",
     "scene": "res://assets/models/props/song_cord.glb", "set_flag": "ks_song_cord_found", "require_flag": "ks_hedgelayer_released"},
] + POI_PICKUPS
npcs = [
    # before the release: Linnet and Eyvind at the clearing, arguing about the gate (THORNWOLD.md 3, 7)
    {"id": "linnet", "at": at(CX + 3.0, CZ + 4.0), "rot": 312, "tag": "thaw", "absent_flag": "ks_hedgelayer_released"},
    {"id": "eyvind", "at": at(CX + 5.0, CZ + 2.2), "rot": 132, "tag": "thaw", "absent_flag": "ks_hedgelayer_released"},
    # after: at the gap of the innermost ring, the gate lying flat across it (THORNWOLD.md 9)
    {"id": "linnet", "at": at(GX - R1 - 1.6, GZ + 2.4), "rot": 341, "tag": "thaw", "require_flag": "ks_hedgelayer_released"},
    {"id": "eyvind_gate", "at": at(GX - R1 - 1.6, GZ - 2.4), "rot": 199, "tag": "thaw", "require_flag": "ks_hedgelayer_released"},
]

portal = seam("thornwold")
arrive = seam("tarnhall")
START = arrive["spawn"]

edges = {
    "doc": "tools/audit_edges.py: hedges and the wood's edge thicket are thickets (per state); "
           "the RIME rings and plugs make the maze.",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [246, -410, 502, -266],
    "buildings": [], "thickets": THICKETS,
    "state_floors": [],
    "gates": [{"id": gt["id"], "at": gt["at"], "rot": gt["rot"]} for gt in GATES],
}

D = {
    "id": "thornwold",
    "name": "Thornwold",
    "start": {"pos": START, "yaw": arrive["spawn_yaw"]},
    # THAW: slanting low sun through the trunks, pollen thick in it
    "env": {"thaw": {"sun_rot": [-22, -75], "sun_energy": 2.5, "sun_color": [1.0, 0.92, 0.76], "fog_density": 0.0014, "vol_density": 0.012,
                     "ambient": [0.34, 0.36, 0.30], "ambient_energy": 0.7, "exposure": 1.08,
                     "fill_color": [0.8, 0.86, 0.7], "fill_energy": 0.35, "fill_rot": [30, 100]},
            "rime": {"sun_rot": [-28, -60], "fog_density": 0.009, "vol_density": 0.02}},
    "terrain": K.terrain_block(),
    "nav_bounds": [246, 0, -410, 502, 120, -266],
    "weather": {"gulls": False, "spindrift": 0},
    "water": [],
    "hazards": [{"kind": "fall", "min": [246, -2, -410], "max": [502, 160, -266]}],
    "zones": [
        {"name": "THE COLLIER'S CLEARING", "min": [246, -410], "max": [392, -266]},
        {"name": "THE HEDGE", "min": [392, -410], "max": [502, -266]},
    ],
    "boxes": BOXES,
    "props": PROPS,
    "landmarks": LANDMARKS,
    "gates": GATES,
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "hedge_veil", "at": VEIL, "rot": -90, "tag": "rime"}],
    "npcs": npcs,
    "plaques": [{"at": at(T.DROVE[0][0] + 3.0, T.DROVE[0][1] - 5.5, 0.0), "rot": 250,
                 "text": "THORNWOLD\n\nThe drove-roads run between laid hedges. Charcoal clearings on the slopes."}] + PLAQUES,
    "pickups": pickups,
    "portals": [portal, high_seam("reach", "thornwold")],
    "forest": forest,
    "scatter": {
        "seed": 5151,
        "clear": FOREST_CLEAR,
        "rules": [
            {"kind": "rock", "count": 90, "region": [x0, z0, x1, z1], "slope": [0.8, 1.0], "scale": [0.3, 0.8], "path_max": 0.3},
            {"kind": "boulder", "count": 40, "region": [x0 - 30, z0 - 30, x1 + 15, z1 + 10], "slope": [0.45, 0.85], "scale": [0.9, 2.0]},
            {"kind": "hummock", "count": 60, "region": [x0, z0, x1, z1], "slope": [0.85, 1.0], "scale": [0.6, 1.1], "path_max": 0.2},
        ],
        "veg": [
            {"kind": "grass", "region": [x0 - 10, z0 - 10, x1 + 10, z1 + 10], "density": 1.0, "range": 40},
            {"kind": "sedge", "region": [x0, z0, x1, z1], "density": 0.5, "range": 35},
        ],
    },
    "edges": edges,
}

# --- progression gates (ADR 0015) ---------------------------------------------
# Where the fell path leaves the wood's east side Eyvind's hedge runs straight
# across it, with no gate in it: laid in THAW, frozen thorn in RIME. It comes
# down with the rest when he is released (THORNWOLD.md 6: "the hedge unlays
# itself stem by stem"). Parted from the fell side at any time. Wings of the
# same hedge close the ground between it and the wood's edge thicket.
import progress_gates as PG  # noqa: E402
_FX, _FZ = 480.6, FELL_OUT_Z   # as far east as leaves standing room for someone set down by the seam
FELL_GATE = PG.gate(
    "thornwold", "fell_hedge", K.sample, at=(_FX, _FZ), toward=(1, 0),
    flag="ks_hedgelayer_released", name="the fell path", to="shepherds_reach",
    seam_at=high_seam("reach", "thornwold")["at"],
    width=3.8, height=2.6, depth=1.0, flank=None, max_span=100.0,
    dressing=[{"hedge": "hd_laid2", "family": "M_thorn", "fit": [4.2, 1.5, 1.2], "tag": "thaw"},
              {"hedge": "hd_thorn3a", "family": "M_thorn_rime", "fit": [4.4, 3.0, 1.5], "tag": "rime"}],
    locked_prompt="Laid shut from the other side", unbar_prompt="Pull the stakes", open_toast="The hedge comes apart.")
FELL_GATE["gate"]["span"] = [-7.0, 7.0]      # (the wings and the edge thicket close it, not the land)
PG.install(D, FELL_GATE)
for _sgn in (-1, 1):
    _wing = [[_FX, _FZ + _sgn * 2.3], [_FX + 1.2, _FZ + _sgn * 4.6], [x1 - inset + 0.4, _FZ + _sgn * 7.6]]
    hedge(_wing, "laid", 1.35, 1.0, "thaw")
    hedge(_wing, "thorn", 3.0, 1.3, "rime")
FOREST_CLEAR.append([_FX, _FZ, 4.0])
# --- end progression gates

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "thornwold.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
