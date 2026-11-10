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
    """A ring of hedge with gaps (angles, degrees) gap_m wide."""
    half = math.degrees(gap_m / 2.0 / r)
    gs = sorted(a % 360 for a in gaps)
    for i, a in enumerate(gs):
        b = gs[(i + 1) % len(gs)] + (360 if i == len(gs) - 1 else 0)
        hedge(arc(r, a + half, b - half), style, h, w, tag)


# --- the rings round the grave ----------------------------------------------
# THAW: laid hedges, every gap on the road side (west, 180): straight in.
# RIME: frozen thorn, the gaps moved round (the old ones grown shut): a maze.
R1, R2, R3 = T.RINGS
INNER_GAP = 180.0                  # never decided where the gate went: the same gap in both
for r, gap in ((R3, 180.0), (R2, 180.0), (R1, INNER_GAP)):
    ring(r, [gap], "laid", 1.35, 1.0, "thaw")
for r, gaps in ((R3, [70.0]), (R2, [295.0]), (R1, [INNER_GAP])):
    ring(r, gaps, "thorn", 3.2, 1.3, "rime")
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
    hedge([[px, pz - 4.3], [px, pz + 4.3]], "thorn", 3.0, 1.3, "rime")

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
for k, a in enumerate((40.0, 110.0, 200.0, 290.0)):
    x, z = CX + 10.0 * math.cos(math.radians(a)), CZ + 10.0 * math.sin(math.radians(a))
    CLAMPS.append((x, z))
    LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_charcoal_clamp.glb", "at": at(x, z, -0.1), "rot": r2(a * 1.7 % 360),
                      "smoke": 2.2, "blocker": [3.6, 2.2, 3.6]})
# stacked billets and the collier's tools
for k, (dx, dz, rot) in enumerate(((-5.0, -9.0, 20), (6.0, -10.0, -15), (12.0, 2.0, 80))):
    x, z = CX + dx, CZ + dz
    y = g(x, z)
    BOXES.append({"min": [r2(x - 1.6), r2(y), r2(z - 0.6)], "max": [r2(x + 1.6), r2(y + 1.1), r2(z + 0.6)], "mat": "M_wood", "tag": "base"})
PROPS.append({"kit": "creel_stack", "at": at(CX - 3.0, CZ + 8.0), "rot": 30, "collide": False})
PROPS.append({"kit": "rope_coil", "at": at(CX + 2.0, CZ - 6.0), "rot": 10, "collide": False})

# --- forest -------------------------------------------------------------------
FOREST_CLEAR = [[CX, CZ, CR], [GX, GZ, R3 + 3.0], [481.0, -331.0, 6.0]]
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
    {"enemy": "collier", "stand_in": "rimewalker", "id": "collier_road", "at": at(380.0, -312.0, 0.1), "face": 270},
    {"enemy": "rime_stag", "stand_in": "hearthhound", "id": "stag_wood", "at": at(400.0, -300.0, 0.1), "face": 200},
    {"enemy": "rime_stag", "stand_in": "hearthhound", "id": "stag_rings", "at": at(GX, GZ - (R2 + R3) / 2.0, 0.1), "face": 90},
    {"enemy": "hedgelayer", "stand_in": "netmender", "id": "hedgelayer", "at": at(GX - 4.0, GZ + 4.0, 0.1), "face": 270,
     "dead_once": True, "frost_veil_id": "hedge_veil"},
]
VEIL = at(GX + R1 * math.cos(math.radians(INNER_GAP)), GZ + R1 * math.sin(math.radians(INNER_GAP)))
# the frost-taken stag statues, mid-bound in the wood (RIME)
for (sx, sz, rot) in ((372.0, -292.0, 120), (418.0, -350.0, 30)):
    LANDMARKS.append({"scene": "res://assets/models/enemies/rime_stag.glb", "at": at(sx, sz), "rot": rot, "tag": "rime"})
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
]
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
    "gates": [],
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
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "hedge_veil", "at": VEIL, "rot": -90, "tag": "rime"}],
    "npcs": npcs,
    "plaques": [{"at": at(T.DROVE[0][0] + 3.0, T.DROVE[0][1] - 5.5, 0.0), "rot": 250,
                 "text": "THORNWOLD\n\nThe drove-roads run between laid hedges. Charcoal clearings on the slopes."}],
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

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "thornwold.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
