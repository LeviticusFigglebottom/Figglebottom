#!/usr/bin/env python3
"""Region prop sets modelled in Blender for Kettle Fjord, Tarnhall and the
Coldwell (docs/art/BIOMES.md section 3, the pieces marked B), and the small
things their points of interest need (docs/lore/POI.md 4, 5, 8).

Each is authored at its KitLib.PIECES footprint (X across, Z up, origin at
the bottom centre) with UVs into a small atlas of committed CC0 sets, and
goes in through KitLib.HERO_PIECES, so it takes the RIME snow and frost.

Kettle Fjord
  kf_jig_frame       a tip-up over a fishing hole: forked stick, balanced arm, line
  kf_fish_cord       frozen cod stacked like cordwood between two stakes
  kf_ice_blocks      sawn ice blocks, stacked three high
  kf_bough_markers   a spruce bough stuck upright to mark a hole or safe ice
  kf_net_hurdle      a hazel hurdle hung with net (the Net-Cleft's gate leaf)
  kf_door_band       a madder band tied on a door ring (the Ice Camp)

Tarnhall
  th_horn_rack       a peg-board of drinking horns for a porch wall, forty pegs
  th_trestles        a trestle table and the overflow's benches, stacked
  th_oar_stand       a stand of oars in seven different cuts of blade
  th_rush_bundles    tied bundles of cut rushes for the hall floor
  th_horn_window     a horn-pane window, one pane out (the South Window)
  th_pail            a stave pail, upturned
  th_boat_oars       a pair of oars left lying in a boat

The Coldwell
  cw_shelter         an open-fronted turf-and-stone shelter, 6 x 3 m, a bench along the back
  cw_staff_rack      a rail of walking sticks, each cut differently (four on it);
                     _full: the rail full; cw_staff_heap: more against a wall and on the ground
  cw_rope_rail       stakes and a rope handrail, 3 m
  cw_slab_bench      a stone slab bench; _snow: the same under snow, sat in at
                     the left end, something set down at the right
  cw_ice_column_a/b/c  ice-fall columns in three sizes
  cw_flower_bunch    marsh marigold and lady's smock tied with a stem of grass

Run: $BPY tools/art/procedural/poi_props_b.py [-- --only name]
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402

TAU = math.tau
OUT = os.path.join(pc.ROOT, "assets", "models", "kit")


def rect(col):
    return (col[0], 0.0, col[1], 1.0)


def strip(col, a=0.0, b=1.0):
    """A sub-strip of an atlas column, for wrapping round a tube."""
    return col[0] + (col[1] - col[0]) * a, col[0] + (col[1] - col[0]) * b


def pole(buf, rng, a, b, r0, r1, col, sides=6, bend=0.02, n=4, v_per_m=1.0):
    """A cut pole from a to b, never quite straight."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    pts = [a + (b - a) * i / (n - 1) + rng.normal(0, bend, 3) * (0 < i < n - 1) for i in range(n)]
    rad = [r0 + (r1 - r0) * i / (n - 1) for i in range(n)]
    u0, u1 = strip(col, 0.0, min(1.0, 0.25 + r0 * 4))
    pc.tube(buf, pts, rad, sides, u0, u1, v_per_m, v0=rng.random())
    return pts


def lash(buf, at, axis, r, col, turns=4, thick=0.007):
    """A lashing: a few turns of cord round a pole at `at`."""
    at, axis = np.asarray(at, float), np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis)
    ref = np.array([0.0, 0.0, 1.0]) if abs(axis[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    a1 = np.cross(axis, ref)
    a1 /= np.linalg.norm(a1)
    a2 = np.cross(axis, a1)
    pts = []
    n = turns * 8
    for k in range(n + 1):
        q = TAU * k / 8
        pts.append(at + axis * (k / n - 0.5) * thick * 2.2 * turns + (math.cos(q) * a1 + math.sin(q) * a2) * (r + thick * 0.6))
    u0, u1 = strip(col, 0.1, 0.3)
    pc.tube(buf, pts, [thick] * len(pts), 4, u0, u1, 4.0, cap_end=False)


# ------------------------------------------------------------------ Kettle Fjord

def jig_frame():
    rng = np.random.default_rng(71)
    maps, (wood, rope, stone) = pc.make_atlas("kf_jig_frame", [
        ("timber", pc.tint((0.40, 0.35, 0.29), 1.1)), ("rope", None), ("fieldstone", pc.tint((0.36, 0.37, 0.38), 1.0))], size=512)
    buf = pc.MeshBuf()
    # the forked stick, set in a wedge of stones
    pole(buf, rng, (0, 0, -0.08), (0.01, 0.0, 0.52), 0.028, 0.022, wood)
    pole(buf, rng, (0.01, 0, 0.5), (0.02, 0.07, 0.7), 0.02, 0.012, wood, n=3, bend=0.004)
    pole(buf, rng, (0.01, 0, 0.5), (0.0, -0.07, 0.69), 0.02, 0.012, wood, n=3, bend=0.004)
    for k in range(4):
        a = TAU * k / 4 + 0.4
        pc.blob(buf, rng, (math.cos(a) * 0.07, math.sin(a) * 0.07, 0.03), (0.06, 0.05, 0.04), 7, 4, *strip(stone, 0.1, 0.6), lump=0.15)
    # the balanced arm through the fork: butt end weighted with a stone, tip over the hole
    butt, tip = np.array([-0.36, 0.0, 0.5]), np.array([0.46, 0.0, 0.74])
    pole(buf, rng, butt, tip, 0.016, 0.009, wood, bend=0.006)
    lash(buf, (0.01, 0, 0.6), tip - butt, 0.018, rope, turns=3, thick=0.005)
    pc.blob(buf, rng, butt + np.array([0.0, 0.0, -0.07]), (0.055, 0.045, 0.05), 7, 5, *strip(stone, 0.3, 0.9), lump=0.12)
    lash(buf, butt + np.array([0.02, 0, 0.0]), tip - butt, 0.017, rope, turns=2, thick=0.004)
    # the line: down from the tip into the hole, and a spare hank on the stick
    u0, u1 = strip(rope, 0.4, 0.5)
    pc.tube(buf, [tip, tip + np.array([0.004, 0.002, -0.4]), tip + np.array([0.0, 0.0, -0.78])], [0.003] * 3, 3, u0, u1, 6.0, cap_end=False)
    hank = [np.array([0.03 * math.cos(q), 0.03 * math.sin(q) * 0.4 - 0.03, 0.3 + 0.05 * math.sin(q)]) for q in np.linspace(0, TAU * 3, 25)]
    pc.tube(buf, hank, [0.004] * len(hank), 3, u0, u1, 6.0, cap_end=False)
    return buf, maps, {}


def fish_cord():
    rng = np.random.default_rng(72)
    maps, (wood, fish, belly, rope) = pc.make_atlas("kf_fish_cord", [
        ("timber", pc.tint((0.38, 0.33, 0.28), 1.0)),
        ("ice", pc.tint((0.34, 0.38, 0.40), 0.6, rough=0.45, keep=0.2)),
        ("snow", pc.tint((0.62, 0.63, 0.60), 0.8, rough=0.5, keep=0.1)), ("rope", None)], size=512)
    buf = pc.MeshBuf()
    for sx in (-0.84, 0.84):
        for sy in (-0.2, 0.2):
            pole(buf, rng, (sx, sy, -0.08), (sx + rng.normal(0, 0.015), sy, 0.92), 0.03, 0.022, wood)
    # cod laid head to tail across, a row at a time, each row the other way
    z, row = 0.02, 0
    while z < 0.7:
        x = -0.78
        while x < 0.76:
            r = rng.uniform(0.05, 0.068)
            ln = rng.uniform(0.5, 0.62)
            flip = 1 if (row + int(x * 10)) % 2 == 0 else -1
            c = np.array([x + r, rng.normal(0, 0.02), z + r * 0.75])
            # a fish: thick at the shoulder, running to a tail, belly pale underneath
            pts, rad = [], []
            for i in range(7):
                t = i / 6
                pts.append(c + np.array([rng.normal(0, 0.003), flip * (t - 0.45) * ln, 0.012 * math.sin(t * 5 + row)]))
                rad.append(r * (0.45 + 1.25 * t) if t < 0.3 else r * max(0.14, 1.0 - 1.15 * (t - 0.3)))
            col = fish if rng.random() < 0.8 else belly
            pc.tube(buf, pts, rad, 7, *strip(col, rng.random() * 0.5, 0.5 + rng.random() * 0.5), 1.4, v0=rng.random(),
                    squash=[(0.72, 1.0)] * 7)
            # the tail fin, a flat wedge
            tp = pts[-1]
            fin = [buf.vert(tp + np.array([0, 0, 0.0]), (belly[0], 0.1)),
                   buf.vert(tp + np.array([0.0, flip * 0.07, 0.05]), (belly[1], 0.1)),
                   buf.vert(tp + np.array([0.0, flip * 0.07, -0.05]), (belly[1], 0.3))]
            buf.tri(*fin)
            buf.tri(fin[0], fin[2], fin[1])
            x += r * 1.75
        z += 0.085
        row += 1
    # a cord over the top, stake to stake
    pc.tube(buf, [(-0.84, 0.0, 0.86), (-0.3, 0.02, z + 0.07), (0.3, -0.02, z + 0.07), (0.84, 0.0, 0.86)], [0.008] * 4, 4,
            *strip(rope, 0.2, 0.4), 4.0, cap_end=False)
    return buf, maps, {}


def ice_blocks():
    rng = np.random.default_rng(73)
    maps, (ice, cut, snow) = pc.make_atlas("kf_ice_blocks", [
        ("ice", pc.tint((0.50, 0.72, 0.74), 0.9, rough=0.12, keep=0.3)),
        ("ice", pc.tint((0.30, 0.52, 0.58), 0.7, rough=0.3, keep=0.2)),
        ("snow", None)], size=512)
    buf = pc.MeshBuf()
    bw, bd, bh = 0.52, 0.36, 0.3
    # three courses, fewer each time, the top one left half built
    for course, n in enumerate((3, 3, 2)):
        for k in range(n):
            for row in range(2 if course < 2 else 1):
                x = (k - (n - 1) / 2) * (bw + 0.015) + (0.13 if course % 2 else 0.0) + rng.normal(0, 0.012)
                y = (row - 0.5) * (bd + 0.02) * (1 if course < 2 else 0) + rng.normal(0, 0.012)
                xf = pc.xform(pos=(x, y, bh * (course + 0.5)), rot_z=rng.normal(0, 0.03))
                pc.box(buf, (bw, bd, bh), xf, rect(ice if rng.random() < 0.7 else cut), uv_per_m=0.6, jitter=0.012, rng=rng)
    # one block set down beside the stack with the tongs' bite still on it, and the sawings
    pc.box(buf, (bw, bd, bh), pc.xform(pos=(0.62, -0.36, bh * 0.5), rot_z=0.5), rect(cut), uv_per_m=0.6, jitter=0.012, rng=rng)
    for _ in range(9):
        a, d = rng.random() * TAU, rng.uniform(0.5, 0.95)
        pc.blob(buf, rng, (math.cos(a) * d, math.sin(a) * d * 0.6, 0.02), (0.07, 0.06, 0.03), 6, 3, *strip(snow, 0.2, 0.6), lump=0.2)
    return buf, maps, {"auto_smooth_deg": 35, "bevel": 0.012}


def bough_markers():
    rng = np.random.default_rng(74)
    maps, (bark, green, tip) = pc.make_atlas("kf_bough_markers", [
        ("bark", pc.tint((0.24, 0.19, 0.15), 1.0)),
        ("turf", pc.tint((0.10, 0.17, 0.12), 1.3, rough=0.85, keep=0.15)),
        ("turf", pc.tint((0.16, 0.25, 0.16), 1.3, rough=0.85, keep=0.15))], size=512)
    buf = pc.MeshBuf()
    stem = pole(buf, rng, (0, 0, -0.1), (0.05, 0.02, 1.12), 0.022, 0.006, bark, n=5, bend=0.012)
    # sprays in whorls up the stem: each a flat drooping fan of needles (two-sided)
    for w in range(7):
        t = 0.22 + 0.11 * w
        base = stem[0] + (stem[-1] - stem[0]) * t
        nb = 5 if w < 5 else 3
        for k in range(nb):
            a = TAU * k / nb + w * 0.9 + rng.normal(0, 0.15)
            ln = (0.34 - 0.035 * w) * rng.uniform(0.85, 1.1)
            out = np.array([math.cos(a), math.sin(a), 0.0])
            side = np.array([-math.sin(a), math.cos(a), 0.0])
            col = green if (w + k) % 3 else tip
            rows = []
            for i in range(4):
                s = i / 3
                c = base + out * ln * s + np.array([0, 0, 0.1 * s - 0.22 * s * s])
                wd = ln * 0.3 * math.sin(math.pi * min(1.0, s + 0.18)) + 0.01
                rows.append((buf.vert(c - side * wd, (col[0], s)), buf.vert(c + np.array([0, 0, 0.025]), ((col[0] + col[1]) / 2, s)),
                             buf.vert(c + side * wd, (col[1], s))))
            for i in range(3):
                for j in range(2):
                    q = (rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j])
                    buf.quad(*q)
                    buf.quad(q[3], q[2], q[1], q[0])
    return buf, maps, {}


def net_hurdle():
    """A gate leaf at the door leaf's footprint (0.95 wide, 2.5 high, hinge
    edge at -x): hazel rods, a net lashed over them."""
    rng = np.random.default_rng(75)
    maps, (hazel, rope, stone) = pc.make_atlas("kf_net_hurdle", [
        ("bark", pc.tint((0.33, 0.27, 0.20), 1.0)), ("rope", None), ("fieldstone", pc.tint((0.36, 0.37, 0.38), 1.0))], size=512)
    buf = pc.MeshBuf()
    w, h = 0.95, 2.3
    for x in (-w / 2 + 0.03, 0.0, w / 2 - 0.03):
        pole(buf, rng, (x, 0, 0.0), (x + rng.normal(0, 0.01), 0, h + rng.uniform(0.0, 0.15)), 0.026, 0.02, hazel, bend=0.008)
    for z in (0.18, 0.75, 1.3, 1.85, 2.22):
        pole(buf, rng, (-w / 2, 0.025, z + rng.normal(0, 0.02)), (w / 2, 0.025, z + rng.normal(0, 0.02)), 0.017, 0.015, hazel, bend=0.006)
        for x in (-w / 2 + 0.03, w / 2 - 0.03):
            lash(buf, (x, 0.012, z), (0, 0, 1), 0.026, rope, turns=3, thick=0.005)
    # the net: a diamond mesh over the face, sagging between the rails
    nu, nv = 9, 22

    def knot(i, j):
        u, v = i / nu, j / nv
        return np.array([(u - 0.5) * (w - 0.04), -0.035 - 0.02 * math.sin(v * math.pi * 4) * math.sin(u * math.pi), 0.1 + v * (h - 0.12)])
    for i0 in range(-nv, nu + 1):
        for sgn in (1, -1):
            line = [knot(i0 + j if sgn > 0 else i0 + nv - j, j) for j in range(nv + 1)
                    if 0 <= (i0 + j if sgn > 0 else i0 + nv - j) <= nu]
            if len(line) >= 2:
                pc.tube(buf, line, [0.005] * len(line), 3, *strip(rope, 0.3, 0.5), 6.0, cap_end=False)
    # holed stones still on the foot rope
    for k in range(4):
        pc.blob(buf, rng, ((k - 1.5) * 0.22, -0.05, 0.12), (0.045, 0.03, 0.04), 6, 4, *strip(stone, 0.1, 0.6), lump=0.15)
    return buf, maps, {}


def door_band():
    """A band of madder-dyed wool tied through a door ring, two ends hanging."""
    rng = np.random.default_rng(76)
    maps, (wool, iron) = pc.make_atlas("kf_door_band", [("wool", pc.tint((0.50, 0.14, 0.10), 1.0)), ("iron", None)], size=256)
    buf = pc.MeshBuf()
    ring = [np.array([0.05 * math.cos(q), 0.0, 0.05 * math.sin(q) + 0.3]) for q in np.linspace(0, TAU, 13)]
    pc.tube(buf, ring, [0.007] * len(ring), 5, *strip(iron, 0.1, 0.3), 4.0, cap_end=False)
    for sx in (-1, 1):
        pts = [np.array([0.0, -0.012, 0.25]), np.array([sx * 0.025, -0.02, 0.17]), np.array([sx * 0.04 + rng.normal(0, 0.006), -0.016, 0.0])]
        pc.tube(buf, pts, [0.016, 0.018, 0.02], 5, *strip(wool, 0.1, 0.5), 2.0, squash=[(1.0, 0.25)] * 3)
    pc.blob(buf, rng, (0, -0.014, 0.25), (0.024, 0.014, 0.022), 6, 4, *strip(wool, 0.5, 0.9), lump=0.1)
    return buf, maps, {}


# ------------------------------------------------------------------ Tarnhall

def horn(buf, rng, base, d, ln, r, col, tipcol, curl=0.5):
    """A drinking horn hung by its mouth: curving down to a point."""
    base, d = np.asarray(base, float), np.asarray(d, float)
    pts, rad = [], []
    for i in range(6):
        t = i / 5
        pts.append(base + np.array([d[0] * t * ln * 0.25 + curl * 0.12 * t * t, d[1] * t * ln * 0.2, -ln * t * (1 - 0.25 * t)]))
        rad.append(r * (1.0 - 0.88 * t))
    c = col if rng.random() < 0.6 else tipcol
    pc.tube(buf, pts, rad, 7, *strip(c, rng.random() * 0.4, 0.6 + rng.random() * 0.4), 2.0, v0=rng.random())


def horn_rack():
    rng = np.random.default_rng(81)
    maps, (board, peg, horn_a, horn_b, cord) = pc.make_atlas("th_horn_rack", [
        ("planks", pc.tint((0.38, 0.31, 0.24), 1.0)), ("timber", pc.tint((0.50, 0.42, 0.31), 0.8)),
        ("timber", pc.tint((0.74, 0.68, 0.55), 0.5, rough=0.4, keep=0.1)),
        ("timber", pc.tint((0.24, 0.20, 0.17), 0.5, rough=0.4, keep=0.1)), ("rope", None)], size=512)
    buf = pc.MeshBuf()
    # two boards on the wall (y = 0 is the wall face), four rows of ten pegs
    for bz in (1.28, 1.86):
        pc.box(buf, (2.5, 0.04, 0.42), pc.xform(pos=(0, -0.02, bz), rot_y=rng.normal(0, 0.006)), rect(board), uv_per_m=0.7, jitter=0.008, rng=rng)
    k = 0
    for row, pz in enumerate((1.16, 1.40, 1.74, 1.98)):
        for i in range(10):
            px = -1.12 + i * 0.249 + (0.06 if row % 2 else 0.0)
            pc.tube(buf, [(px, -0.04, pz), (px, -0.13, pz + 0.025)], [0.012, 0.01], 5, *strip(peg, 0.1, 0.3), 2.0)
            # most pegs hold a horn; a few are bare (their horns are in the hall)
            if (k * 7 + row) % 9 not in (0, 4):
                pc.tube(buf, [(px, -0.12, pz + 0.02), (px + 0.015, -0.13, pz - 0.05)], [0.003, 0.003], 3, *strip(cord, 0.2, 0.3), 6.0, cap_end=False)
                horn(buf, rng, (px + 0.015, -0.13, pz - 0.05), (rng.normal(0, 0.3), -0.3), rng.uniform(0.2, 0.27), rng.uniform(0.026, 0.034),
                     horn_a, horn_b, curl=rng.uniform(-0.6, 0.6))
            k += 1
    return buf, maps, {}


def trestles():
    rng = np.random.default_rng(82)
    maps, (top, leg, dark) = pc.make_atlas("th_trestles", [
        ("planks", pc.tint((0.44, 0.36, 0.27), 1.0)), ("timber", pc.tint((0.36, 0.30, 0.24), 1.0)),
        ("timber", pc.tint((0.27, 0.22, 0.18), 1.0))], size=512)
    buf = pc.MeshBuf()
    # the board: three planks on two A-trestles
    for k in range(3):
        pc.box(buf, (2.9, 0.26, 0.05), pc.xform(pos=(0, -0.3 + (k - 1) * 0.27, 0.78), rot_z=rng.normal(0, 0.005)), rect(top), uv_per_m=0.5,
               jitter=0.008, rng=rng)
    for sx in (-1.05, 1.05):
        for sy in (-1, 1):
            pole(buf, rng, (sx, -0.3 + sy * 0.42, 0.0), (sx, -0.3 + sy * 0.08, 0.75), 0.035, 0.03, leg, bend=0.004)
        pc.box(buf, (0.07, 0.6, 0.06), pc.xform(pos=(sx, -0.3, 0.38)), rect(dark), uv_per_m=0.8, jitter=0.005, rng=rng)
        pc.box(buf, (0.09, 0.3, 0.05), pc.xform(pos=(sx, -0.3, 0.74)), rect(dark), uv_per_m=0.8, jitter=0.005, rng=rng)
    # the benches not yet wanted, stacked seat to seat beside it
    for k in range(3):
        up = k % 2 == 0
        z = 0.42 + k * 0.1 if up else 0.42 + k * 0.1
        pc.box(buf, (2.5, 0.28, 0.05), pc.xform(pos=(0.1 * (k - 1), 0.52 + 0.03 * k, 0.4 + 0.11 * k), rot_z=rng.normal(0, 0.02)), rect(top),
               uv_per_m=0.5, jitter=0.008, rng=rng)
        for sx in (-1.0, 1.0):
            if k == 0:
                pc.box(buf, (0.06, 0.26, 0.4), pc.xform(pos=(sx + 0.1 * (k - 1), 0.52, 0.2)), rect(leg), uv_per_m=0.8, jitter=0.006, rng=rng)
            else:
                pc.box(buf, (0.06, 0.26, 0.36), pc.xform(pos=(sx * 0.8 + 0.1 * (k - 1), 0.52 + 0.03 * k + (0.26 if k == 2 else -0.24), 0.48 + 0.11 * k),
                                                         rot_x=math.radians(90)), rect(leg), uv_per_m=0.8, jitter=0.006, rng=rng)
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.006}


OAR_BLADES = [  # seven neighbourhoods, seven cuts: (length, [(t, half-width)...])
    (0.62, [(0, 0.03), (0.2, 0.07), (0.8, 0.075), (1, 0.05)]),          # square-ended
    (0.7, [(0, 0.03), (0.3, 0.06), (0.7, 0.085), (1, 0.01)]),           # leaf
    (0.8, [(0, 0.03), (0.5, 0.045), (1, 0.05)]),                        # long and narrow
    (0.5, [(0, 0.03), (0.3, 0.1), (0.75, 0.1), (1, 0.03)]),             # broad paddle
    (0.66, [(0, 0.03), (0.15, 0.06), (0.85, 0.06), (1, 0.06)]),         # plank, cut off straight
    (0.72, [(0, 0.03), (0.4, 0.075), (0.9, 0.045), (1, 0.0)]),          # spear point
    (0.6, [(0, 0.03), (0.6, 0.06), (0.85, 0.095), (1, 0.07)]),          # spoon
]


def oar(buf, rng, foot, head, cut, loom, blade):
    """An oar from its handle (foot) to the blade's tip (head)."""
    foot, head = np.asarray(foot, float), np.asarray(head, float)
    ln_b, prof = OAR_BLADES[cut]
    total = np.linalg.norm(head - foot)
    d = (head - foot) / total
    neck = foot + d * (total - ln_b)
    pole(buf, rng, foot, neck, 0.024, 0.02, loom, bend=0.004)
    side = np.cross(d, np.array([0.0, 1.0, 0.0]))
    side /= np.linalg.norm(side)
    nrm = np.cross(side, d)
    rows = []
    for t, w in prof:
        c = neck + d * ln_b * t
        rows.append([buf.vert(c - side * w, (blade[0], t * 0.6)), buf.vert(c + nrm * 0.012, ((blade[0] + blade[1]) / 2, t * 0.6)),
                     buf.vert(c + side * w, (blade[1], t * 0.6)), buf.vert(c - nrm * 0.012, ((blade[0] + blade[1]) / 2, t * 0.6))])
    for i in range(len(rows) - 1):
        for j in range(4):
            a, b = rows[i][j], rows[i][(j + 1) % 4]
            c, e = rows[i + 1][(j + 1) % 4], rows[i + 1][j]
            buf.quad(a, b, c, e)
            buf.quad(e, c, b, a)


def oar_stand():
    rng = np.random.default_rng(83)
    maps, (wood, loom, blade, tar) = pc.make_atlas("th_oar_stand", [
        ("timber", pc.tint((0.34, 0.28, 0.22), 1.0)), ("timber", pc.tint((0.52, 0.45, 0.34), 0.8)),
        ("planks", pc.tint((0.48, 0.42, 0.33), 0.9)), ("planks", pc.tint((0.16, 0.13, 0.11), 0.9))], size=512)
    buf = pc.MeshBuf()
    # two posts and a rail; the oars lean on it, blades up
    for sx in (-0.9, 0.9):
        pole(buf, rng, (sx, 0, -0.08), (sx, 0.0, 1.5), 0.045, 0.038, wood)
        pole(buf, rng, (sx, 0, 0.5), (sx, -0.5, 0.0), 0.03, 0.026, wood, n=3)
    pole(buf, rng, (-1.0, 0.0, 1.42), (1.0, 0.0, 1.42), 0.032, 0.03, wood, bend=0.006)
    for k in range(7):
        x = -0.75 + k * 0.25
        ln = rng.uniform(2.5, 2.85)
        foot = np.array([x + rng.normal(0, 0.03), -0.45 + rng.normal(0, 0.04), 0.0])
        lean = np.array([rng.normal(0, 0.02), 0.45 / 1.42, 1.0])
        lean /= np.linalg.norm(lean)
        oar(buf, rng, foot, foot + lean * ln, k, loom, tar if k in (2, 5) else blade)
    return buf, maps, {}


def boat_oars():
    """A pair of oars left in a boat: laid along the thwarts, blades aft (+y)."""
    rng = np.random.default_rng(87)
    maps, (loom, blade) = pc.make_atlas("th_boat_oars", [
        ("timber", pc.tint((0.52, 0.45, 0.34), 0.8)), ("planks", pc.tint((0.48, 0.42, 0.33), 0.9))], size=256)
    buf = pc.MeshBuf()
    for sx in (-0.32, 0.3):
        oar(buf, rng, (sx, -1.3, 0.02), (sx * 1.5 + rng.normal(0, 0.03), 1.45, 0.1), 0, loom, blade)
    return buf, maps, {}


def rush_bundles():
    rng = np.random.default_rng(84)
    maps, (rush, dry, band) = pc.make_atlas("th_rush_bundles", [
        ("turf", pc.tint((0.38, 0.42, 0.22), 1.2, rough=0.8, keep=0.15)),
        ("turf", pc.tint((0.55, 0.50, 0.30), 1.2, rough=0.8, keep=0.15)), ("rope", None)], size=512)
    buf = pc.MeshBuf()
    lays = [((-0.3, 0.0, 0.13), 0.1, 0.0), ((0.0, 0.03, 0.13), -0.08, 0.0), ((0.3, -0.02, 0.13), 0.05, 0.0),
            ((-0.14, 0.02, 0.36), 0.02, 0.0), ((0.17, 0.0, 0.36), -0.12, 0.0), ((0.52, -0.3, 0.52), 0.0, 1.25)]
    for (c, yaw, tilt) in lays:
        c = np.array(c)
        ax = np.array([math.sin(yaw) * math.cos(tilt), math.cos(yaw) * math.cos(tilt), math.sin(tilt)])
        ln = rng.uniform(1.0, 1.15)
        col = rush if rng.random() < 0.6 else dry
        # a sheaf: a tube pinched at the two ties, splayed at the ends, ragged at the head
        pts, rad = [], []
        for i in range(7):
            t = i / 6
            pts.append(c + ax * (t - 0.5) * ln)
            rad.append(0.13 * (1.0 + 0.25 * abs(t - 0.5) * 2) * (0.82 if i in (2, 4) else 1.0))
        pc.tube(buf, pts, rad, 9, *strip(col, 0.0, 1.0), 1.0, v0=rng.random())
        pc.cap(buf, pts[0], -ax, rad[0], 9, ((col[0] + col[1]) / 2, 0.5), (col[1] - col[0]) * 0.4)
        for i in (2, 4):
            lash(buf, pts[i], ax, rad[i], band, turns=2, thick=0.006)
        for _ in range(14):
            q = rng.random() * TAU
            off = np.cross(ax, np.array([0.0, 0.0, 1.0]) if abs(ax[2]) < 0.9 else np.array([1.0, 0.0, 0.0]))
            off /= np.linalg.norm(off)
            o2 = np.cross(ax, off)
            st = pts[-1] + (math.cos(q) * off + math.sin(q) * o2) * rad[-1] * rng.uniform(0.2, 0.9)
            pc.tube(buf, [st - ax * 0.05, st + ax * rng.uniform(0.06, 0.2) + (math.cos(q) * off + math.sin(q) * o2) * 0.03], [0.008, 0.003], 3,
                    *strip(col, 0.2, 0.3), 2.0)
    return buf, maps, {}


def horn_window():
    """A shuttered opening glazed with scraped horn in a lattice: six panes,
    one gone (dark behind). Y = 0 is the wall's outer face; origin at the sill."""
    rng = np.random.default_rng(85)
    maps, (frame, horn_c, dark) = pc.make_atlas("th_horn_window", [
        ("timber", pc.tint((0.30, 0.25, 0.20), 1.0)),
        ("ice", pc.tint((0.72, 0.62, 0.40), 0.5, rough=0.35, keep=0.1)),
        ("timber", pc.tint((0.03, 0.025, 0.02), 0.3, rough=0.9, keep=0.0))], size=512)
    buf = pc.MeshBuf()
    w, h = 0.9, 0.6
    pc.box(buf, (w + 0.16, 0.1, 0.08), pc.xform(pos=(0, -0.03, -0.04)), rect(frame), uv_per_m=0.8, jitter=0.005, rng=rng)
    pc.box(buf, (w + 0.16, 0.1, 0.08), pc.xform(pos=(0, -0.03, h + 0.04)), rect(frame), uv_per_m=0.8, jitter=0.005, rng=rng)
    for sx in (-1, 1):
        pc.box(buf, (0.08, 0.1, h), pc.xform(pos=(sx * (w / 2 + 0.04), -0.03, h / 2)), rect(frame), uv_per_m=0.8, jitter=0.005, rng=rng)
    pc.box(buf, (w, 0.02, h), pc.xform(pos=(0, 0.02, h / 2)), rect(dark))          # the dark of the hall behind
    for i in range(3):
        for j in range(2):
            if (i, j) == (1, 1):
                continue                                                           # the pane that is out
            cx, cz = (i - 1) * (w / 3), (j + 0.5) * (h / 2)
            pc.box(buf, (w / 3 - 0.035, 0.012, h / 2 - 0.035), pc.xform(pos=(cx, -0.02, cz), rot_x=rng.normal(0, 0.02)), rect(horn_c),
                   uv_per_m=1.2, jitter=0.004, rng=rng)
    for i in (1, 2):
        pc.box(buf, (0.03, 0.04, h), pc.xform(pos=(-w / 2 + i * w / 3, -0.025, h / 2)), rect(frame), uv_per_m=0.8, rng=rng)
    pc.box(buf, (w, 0.04, 0.03), pc.xform(pos=(0, -0.025, h / 2)), rect(frame), uv_per_m=0.8, rng=rng)
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.004}


def pail():
    rng = np.random.default_rng(86)
    maps, (stave, hoop, under) = pc.make_atlas("th_pail", [
        ("planks", pc.tint((0.42, 0.35, 0.27), 1.0)), ("bark", pc.tint((0.30, 0.24, 0.18), 1.0)),
        ("timber", pc.tint((0.36, 0.30, 0.24), 1.0))], size=256)
    buf = pc.MeshBuf()
    # upturned: mouth (wider) down, the bottom board up for a short person to stand on
    pc.lathe(buf, [(0.185, 0.0), (0.175, 0.16), (0.16, 0.33), (0.15, 0.335), (0.0, 0.32)], 14, stave[0], stave[1], 2.0)
    for z in (0.07, 0.25):
        r = 0.185 - 0.025 * z / 0.33 + 0.004
        ring = [np.array([r * math.cos(q), r * math.sin(q), z]) for q in np.linspace(0, TAU, 15)]
        pc.tube(buf, ring, [0.009] * len(ring), 4, *strip(hoop, 0.1, 0.4), 3.0, cap_end=False)
    return buf, maps, {}


# ------------------------------------------------------------------ the Coldwell

def cobble_wall(buf, rng, a, b, height, thick, stone, moss, course=0.26):
    """A drystone wall from a to b of rounded river cobbles."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    ln = np.linalg.norm(b - a)
    d = (b - a) / ln
    yaw = math.atan2(d[1], d[0])
    z, row = 0.0, 0
    while z < height - 0.05:
        t = (row % 2) * 0.2
        while t < ln:
            sl = rng.uniform(0.3, 0.5)
            col = moss if rng.random() < 0.22 else stone
            u0 = col[0] + rng.random() * (col[1] - col[0]) * 0.4
            pc.blob(buf, rng, (0, 0, 0), (sl * 0.6, thick * rng.uniform(0.5, 0.62), course * rng.uniform(0.55, 0.7)), 8, 5,
                    u0, u0 + (col[1] - col[0]) * 0.55, rng.random(), rng.random() + 0.5, lump=0.1,
                    xf=pc.xform(pos=tuple(a + d * min(t + sl / 2, ln) + np.array([0, 0, z + course * 0.5])), rot_z=yaw + rng.normal(0, 0.08),
                                rot_x=rng.normal(0, 0.08)))
            t += sl
        z += course
        row += 1


def shelter():
    """6 x 3 m, open to the front (-y). Back and end walls of cobbles, a turf
    roof on poles falling to the back, a sleeping bench along the back wall."""
    rng = np.random.default_rng(91)
    maps, (stone, moss, wood, turf, plank) = pc.make_atlas("cw_shelter", [
        ("fieldstone", pc.tint((0.40, 0.41, 0.40), 1.0)), ("rock", pc.tint((0.30, 0.36, 0.25), 1.0)),
        ("timber", pc.tint((0.36, 0.31, 0.26), 1.0)), ("turf", pc.tint((0.24, 0.27, 0.15), 1.0)),
        ("planks", pc.tint((0.40, 0.34, 0.27), 1.0))])
    buf = pc.MeshBuf()
    cobble_wall(buf, rng, (-3.0, 1.35, 0), (3.0, 1.35, 0), 1.7, 0.45, stone, moss)
    for sx in (-1, 1):
        cobble_wall(buf, rng, (sx * 2.85, -1.2, 0), (sx * 2.85, 1.3, 0), 1.7, 0.45, stone, moss)
    # posts at the open front, a plate over them, rafters back to the wall head
    for x in (-2.85, -0.95, 0.95, 2.85):
        pole(buf, rng, (x, -1.3, -0.05), (x, -1.3, 2.25), 0.07, 0.06, wood, sides=7)
    pole(buf, rng, (-3.1, -1.3, 2.28), (3.1, -1.3, 2.28), 0.065, 0.06, wood, sides=7, bend=0.01)
    for k in range(9):
        x = -2.9 + k * 0.725
        pole(buf, rng, (x, -1.55, 2.38), (x, 1.6, 1.74), 0.045, 0.04, wood, bend=0.008)
    # the turf: a thick sagging slab over the rafters, ragged at the eave
    nx, ny = 12, 6
    top, bot = [], []
    for j in range(ny + 1):
        rt, rb = [], []
        for i in range(nx + 1):
            x = -3.25 + 6.5 * i / nx
            y = -1.75 + 3.55 * j / ny
            z = 2.46 - 0.64 * (j / ny) + 0.05 * math.sin(i * 1.7 + j) + 0.04 * rng.normal()
            uv = (turf[0] + (turf[1] - turf[0]) * i / nx, j / ny * 1.2)
            rt.append(buf.vert((x, y - (0.08 * rng.random() if j == 0 else 0), z + 0.2), uv))
            rb.append(buf.vert((x, y, z), uv))
        top.append(rt)
        bot.append(rb)
    for j in range(ny):
        for i in range(nx):
            buf.quad(top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i])
            buf.quad(bot[j][i], bot[j + 1][i], bot[j + 1][i + 1], bot[j][i + 1])
    for i in range(nx):
        buf.quad(bot[0][i], bot[0][i + 1], top[0][i + 1], top[0][i])
        buf.quad(top[ny][i], top[ny][i + 1], bot[ny][i + 1], bot[ny][i])
    for j in range(ny):
        buf.quad(top[j][0], top[j + 1][0], bot[j + 1][0], bot[j][0])
        buf.quad(bot[j][nx], bot[j + 1][nx], top[j + 1][nx], top[j][nx])
    # the sleeping bench: planks on cobble piers along the back
    for k in range(3):
        pc.box(buf, (5.1, 0.22, 0.05), pc.xform(pos=(0, 0.62 + (k - 1) * 0.235, 0.46), rot_z=rng.normal(0, 0.003)), rect(plank), uv_per_m=0.4,
               jitter=0.008, rng=rng)
    for x in (-2.3, -0.8, 0.8, 2.3):
        cobble_wall(buf, rng, (x, 0.35, 0), (x, 0.9, 0), 0.44, 0.3, stone, moss, course=0.22)
    return buf, maps, {}


def stick(buf, rng, foot, head, wood, bark, kind):
    """A walking stick, each cut differently: plain, forked, crooked, knobbed, bark left on."""
    pts = pole(buf, rng, foot, head, 0.016, 0.013, bark if kind == 4 else wood, bend=0.01 if kind != 2 else 0.03)
    h = np.asarray(head, float)
    d = h - np.asarray(foot, float)
    d /= np.linalg.norm(d)
    side = np.cross(d, np.array([0.0, 1.0, 0.0]))
    side /= max(np.linalg.norm(side), 1e-6)
    if kind == 1:
        for sg in (-1, 1):
            pc.tube(buf, [h, h + d * 0.1 + side * sg * 0.05], [0.012, 0.008], 5, *strip(wood, 0.1, 0.3), 2.0)
    elif kind == 2:
        pc.tube(buf, [h, h + d * 0.05 + side * 0.05, h + side * 0.11 - d * 0.02], [0.013, 0.012, 0.009], 5, *strip(wood, 0.1, 0.3), 2.0)
    elif kind == 3:
        pc.blob(buf, rng, h + d * 0.02, (0.03, 0.03, 0.035), 6, 4, *strip(bark, 0.1, 0.5), lump=0.2)
    return pts


def staff_rack(n_on=4, heap=False):
    rng = np.random.default_rng(92 + n_on + (50 if heap else 0))
    name = "cw_staff_heap" if heap else ("cw_staff_rack" if n_on <= 4 else "cw_staff_rack_full")
    maps, (post, wood, bark) = pc.make_atlas(name, [
        ("timber", pc.tint((0.34, 0.29, 0.24), 1.0)), ("timber", pc.tint((0.55, 0.47, 0.35), 0.8)),
        ("bark", pc.tint((0.30, 0.24, 0.19), 1.0))], size=512)
    buf = pc.MeshBuf()
    if heap:
        # no room on the rail: a dozen leant together against the wall (+y), and some lying
        for k in range(10):
            x = -0.5 + k * 0.11 + rng.normal(0, 0.03)
            stick(buf, rng, (x, -0.42 + rng.normal(0, 0.06), 0.0), (x + rng.normal(0, 0.08), 0.0, rng.uniform(1.1, 1.4)), wood, bark, k % 5)
        for k in range(4):
            a = rng.normal(0, 0.5)
            c = np.array([rng.uniform(-0.5, 0.5), -0.75 + rng.normal(0, 0.12), 0.02 + 0.03 * k])
            dv = np.array([math.cos(a), math.sin(a), 0.0]) * rng.uniform(0.55, 0.68)
            stick(buf, rng, c - dv, c + dv, wood, bark, (k + 2) % 5)
        return buf, maps, {}
    for sx in (-1.0, 1.0):
        pole(buf, rng, (sx, 0, -0.08), (sx, 0, 1.05), 0.045, 0.04, post, sides=7)
    pole(buf, rng, (-1.1, 0, 0.92), (1.1, 0, 0.92), 0.03, 0.028, post, bend=0.006)
    pc.box(buf, (2.0, 0.1, 0.04), pc.xform(pos=(0, -0.3, 0.02)), rect(post), uv_per_m=0.6, jitter=0.006, rng=rng)
    slots = 13
    order = list(range(slots))
    rng.shuffle(order)
    for k in sorted(order[:n_on]):
        x = -0.84 + k * 0.14
        stick(buf, rng, (x + rng.normal(0, 0.01), -0.3, 0.04), (x + rng.normal(0, 0.02), 0.03, rng.uniform(1.15, 1.42)), wood, bark, k % 5)
    return buf, maps, {}


def rope_rail():
    rng = np.random.default_rng(93)
    maps, (wood, rope) = pc.make_atlas("cw_rope_rail", [("timber", pc.tint((0.36, 0.31, 0.26), 1.0)), ("rope", None)], size=512)
    buf = pc.MeshBuf()
    tops = []
    for x in (-1.5, 0.0, 1.5):
        top = np.array([x + rng.normal(0, 0.02), rng.normal(0, 0.02), 1.02])
        pole(buf, rng, (x, 0, -0.2), top, 0.045, 0.036, wood, sides=7)
        tops.append(top - np.array([0, 0, 0.1]))
        lash(buf, top - np.array([0, 0, 0.1]), (0, 0, 1), 0.04, rope, turns=3, thick=0.007)
    for a, b in zip(tops, tops[1:]):
        pts = [a + (b - a) * t - np.array([0, 0, 0.12 * 4 * t * (1 - t)]) for t in np.linspace(0, 1, 9)]
        pc.tube(buf, pts, [0.016] * len(pts), 6, *strip(rope, 0.0, 0.6), 3.0, cap_end=False)
    return buf, maps, {}


def slab_bench(snow=False):
    rng = np.random.default_rng(94)
    maps, (stone, moss, white) = pc.make_atlas("cw_slab_bench_snow" if snow else "cw_slab_bench", [
        ("fieldstone", pc.tint((0.42, 0.43, 0.42), 1.0)), ("rock", pc.tint((0.30, 0.35, 0.26), 1.0)), ("snow", None)], size=512)
    buf = pc.MeshBuf()
    for x in (-0.62, 0.62):
        pc.blob(buf, rng, (x, 0, 0.19), (0.2, 0.2, 0.21), 9, 6, *strip(stone, 0.0, 0.6), lump=0.12)
        pc.blob(buf, rng, (x + 0.05, 0.02, 0.05), (0.26, 0.24, 0.1), 9, 5, *strip(moss, 0.0, 0.6), lump=0.12)
    pc.box(buf, (1.9, 0.5, 0.1), pc.xform(pos=(0, 0, 0.43), rot_y=0.01), rect(stone), uv_per_m=0.5, jitter=0.014, rng=rng)
    if snow:
        # a hand of snow on the slab: sat in at the left end, and at the right
        # end a smaller, squarer hollow where something was put down
        nx, ny = 30, 9
        rows = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                x = -0.96 + 1.92 * i / nx
                y = -0.26 + 0.52 * j / ny
                edge = min(1.0, min(i, nx - i) / 2.0, min(j, ny - j) / 1.5)
                z = 0.1 * edge ** 0.6 + 0.008 * math.sin(i * 0.9 + j)
                sat = math.exp(-(((x + 0.62) / 0.2) ** 2 + (y / 0.17) ** 2))
                put = 1.0 if (abs(x - 0.68) < 0.12 and abs(y + 0.02) < 0.1) else 0.0
                z *= (1.0 - 0.88 * sat) * (1.0 - 0.8 * put)
                row.append(buf.vert((x, y, 0.48 + z), (white[0] + (white[1] - white[0]) * i / nx, j / ny * 0.3)))
            rows.append(row)
        for j in range(ny):
            for i in range(nx):
                buf.quad(rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i])
    return buf, maps, {"auto_smooth_deg": 50, "bevel": 0.01}


def ice_column(height, girth, seed):
    rng = np.random.default_rng(seed)
    maps, (ice, deep) = pc.make_atlas("cw_ice_column_%s" % "abc"[seed - 95], [
        ("ice", pc.tint((0.50, 0.70, 0.82), 0.9, rough=0.12, keep=0.3)),
        ("ice", pc.tint((0.30, 0.50, 0.70), 0.8, rough=0.2, keep=0.2))], size=512)
    buf = pc.MeshBuf()
    # a curtain of fused icicles against a face (+y): fat at the head and the foot
    n = int(5 + girth * 5)
    for k in range(n):
        x = (k / (n - 1) - 0.5) * girth + rng.normal(0, 0.05)
        h = height * rng.uniform(0.72, 1.0)
        r = rng.uniform(0.09, 0.2) * (0.8 + girth * 0.25)
        pts, rad = [], []
        for i in range(7):
            t = i / 6
            pts.append(np.array([x + 0.05 * math.sin(t * 5 + k), -0.1 * math.sin(t * math.pi) + rng.normal(0, 0.015), h * t]))
            rad.append(r * (1.5 - 1.1 * math.sin(t * math.pi) ** 0.7 * 0.6 + (0.5 if i == 0 else 0)))
        pc.tube(buf, pts, rad, 7, *strip(ice if k % 3 else deep, rng.random() * 0.3, 0.6 + rng.random() * 0.4), 0.7, v0=rng.random())
    for _ in range(int(4 + girth * 3)):                                    # the frozen splash at the foot
        pc.blob(buf, rng, (rng.uniform(-girth * 0.6, girth * 0.6), rng.uniform(-0.5, 0.0), 0.08), (0.3, 0.24, 0.16), 8, 5,
                *strip(ice, 0.1, 0.7), lump=0.2)
    return buf, maps, {}


def flower_bunch():
    rng = np.random.default_rng(98)
    maps, (stem, yellow, lilac) = pc.make_atlas("cw_flower_bunch", [
        ("turf", pc.tint((0.30, 0.42, 0.18), 1.0, rough=0.7, keep=0.1)),
        ("wool", pc.tint((0.88, 0.72, 0.18), 0.5, rough=0.6, keep=0.0)),
        ("wool", pc.tint((0.76, 0.66, 0.84), 0.5, rough=0.6, keep=0.0))], size=256)
    buf = pc.MeshBuf()
    for k in range(11):
        a = TAU * k / 11
        spread = rng.uniform(0.02, 0.07)
        head = np.array([math.cos(a) * spread, math.sin(a) * spread, rng.uniform(0.22, 0.3)])
        pc.tube(buf, [(math.cos(a) * 0.008, math.sin(a) * 0.008, 0.0), head * np.array([0.5, 0.5, 0.5]), head], [0.004, 0.0035, 0.003], 4,
                *strip(stem, 0.1, 0.3), 3.0, cap_end=False)
        col = yellow if k % 3 else lilac
        petals = 5 if k % 3 else 4
        c = buf.vert(head + np.array([0, 0, 0.004]), ((col[0] + col[1]) / 2, 0.5))
        ring = []
        for q in range(petals * 2 + 1):
            r = (0.03 if k % 3 else 0.022) * (1.0 if q % 2 == 0 else 0.45)
            an = TAU * q / (petals * 2)
            ring.append(buf.vert(head + np.array([math.cos(an) * r, math.sin(an) * r, 0.012 if q % 2 == 0 else 0.0]),
                                 (col[0] + (col[1] - col[0]) * (0.5 + 0.5 * math.cos(an)), 0.5 + 0.4 * math.sin(an))))
        for q in range(petals * 2):
            buf.tri(c, ring[q], ring[q + 1])
            buf.tri(c, ring[q + 1], ring[q])
    lash(buf, (0, 0, 0.09), (0, 0, 1), 0.014, stem, turns=3, thick=0.003)
    return buf, maps, {}


PIECES = {
    "th_horn_rack": horn_rack,
    "th_trestles": trestles,
    "th_oar_stand": oar_stand,
    "th_rush_bundles": rush_bundles,
    "th_horn_window": horn_window,
    "th_pail": pail,
    "th_boat_oars": boat_oars,
    "cw_shelter": shelter,
    "cw_staff_rack": lambda: staff_rack(4),
    "cw_staff_rack_full": lambda: staff_rack(13),
    "cw_staff_heap": lambda: staff_rack(0, heap=True),
    "cw_rope_rail": rope_rail,
    "cw_slab_bench": slab_bench,
    "cw_slab_bench_snow": lambda: slab_bench(True),
    "cw_ice_column_a": lambda: ice_column(2.2, 0.9, 95),
    "cw_ice_column_b": lambda: ice_column(3.6, 1.4, 96),
    "cw_ice_column_c": lambda: ice_column(5.2, 2.0, 97),
    "cw_flower_bunch": flower_bunch,
    "kf_jig_frame": jig_frame,
    "kf_fish_cord": fish_cord,
    "kf_ice_blocks": ice_blocks,
    "kf_bough_markers": bough_markers,
    "kf_net_hurdle": net_hurdle,
    "kf_door_band": door_band,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name, fn in PIECES.items():
        if a.only and not name.startswith(a.only):
            continue
        buf, maps, opts = fn()
        pc.export_glb(os.path.join(OUT, name + ".glb"), name, buf, maps, **opts)


if __name__ == "__main__":
    main()
