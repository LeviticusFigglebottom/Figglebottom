#!/usr/bin/env python3
"""Thornwold's own prop set, modelled (docs/art/BIOMES.md section 3; the
three Tripo pieces of the set are in tools/art/manifest.json).

Each is authored at its KitLib.PIECES footprint (X across, Z up, origin at
the bottom centre) with UVs into a small atlas of committed CC0 sets, and
goes in through KitLib.HERO_PIECES.

  kit_tw_clamp_a        charcoal clamp, stage 1: billets stacked on end round a stake
  kit_tw_clamp_b        stage 2: turfed over, vents at the foot (the smoke is the area's)
  kit_tw_clamp_c        stage 3: opened and raked out, half the turf wall standing
  kit_tw_cordwood       billets corded between two pairs of stakes, 2.4 m
  kit_tw_hurdle         a woven hazel hurdle, 1.8 m
  kit_tw_stake_bundle   hazel stakes tied in a bundle, a coil of binders on it
  kit_tw_stile          a two-step plank stile between two hand posts
  kit_tw_charcoal_sacks sacks of charcoal, three stacked and one spilled
  kit_tw_gatepost       an adzed oak gatepost with its hanging pegs, no gate

Run: $BPY tools/art/procedural/thornwold_props.py [-- --only name]
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


def strip(rng, col, frac):
    """A random sub-strip of an atlas column, `frac` of its width."""
    w = (col[1] - col[0]) * frac
    u0 = col[0] + rng.random() * ((col[1] - col[0]) - w)
    return u0, u0 + w


def billet(buf, rng, a, b, radius, bark, wood, sides=6):
    """A round length of cordwood from a to b, sawn ends showing."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    mid = (a + b) / 2 + rng.normal(0, radius * 0.12, 3)
    u0, u1 = strip(rng, bark, min(1.0, TAU * radius / 0.6))
    rad = [radius * rng.uniform(0.95, 1.08), radius, radius * rng.uniform(0.88, 1.0)]
    pc.tube(buf, [a, mid, b], rad, sides, u0, u1, 1.2, v0=rng.random(), cap_end=False)
    d = (b - a) / np.linalg.norm(b - a)
    uc = ((wood[0] + wood[1]) * 0.5, rng.random())
    ur = (wood[1] - wood[0]) * 0.35
    pc.cap(buf, b, d, rad[2], sides, uc, ur)
    pc.cap(buf, a, -d, rad[0], sides, uc, ur)


def mound(buf, rng, radius, height, col, segs=16, rings=5, lump=0.05, squash=1.0, v_scale=0.5, hole=0.0):
    """A low lumpy mound mapped from above into one atlas column."""
    grid = []
    ph = rng.random(3) * TAU
    for j in range(rings + 1):
        fr = hole + (1.0 - hole) * j / rings
        row = []
        for k in range(segs + 1):
            a = TAU * (k % segs) / segs
            r = radius * fr * (1 + lump * (math.sin(a * 3 + ph[0]) + 0.6 * math.sin(a * 5 + ph[1])))
            z = height * (1 - fr ** 2) + lump * height * math.sin(a * 4 + fr * 7 + ph[2]) * fr
            row.append(buf.vert((math.cos(a) * r, math.sin(a) * r * squash, z if j < rings else -0.03),
                                (col[0] + (col[1] - col[0]) * (0.5 + 0.48 * math.cos(a) * fr), 0.5 + v_scale * math.sin(a) * fr)))
        grid.append(row)
    for j in range(rings):
        for k in range(segs):
            buf.quad(grid[j][k], grid[j + 1][k], grid[j + 1][k + 1], grid[j][k + 1])


def coal(buf, rng, pos, size, col):
    u0, u1 = strip(rng, col, 0.3)
    pc.blob(buf, rng, pos, (size * rng.uniform(0.7, 1.3), size * rng.uniform(0.6, 1.1), size * rng.uniform(0.5, 0.9)),
            5, 3, u0, u1, rng.random(), rng.random() + 0.2, lump=0.25,
            xf=None)


def clamp_atlas(name):
    return pc.make_atlas(name, [
        ("bark", None),
        ("timber", pc.tint((0.52, 0.42, 0.30), 1.0)),
        ("turf", pc.tint((0.30, 0.35, 0.16), 1.0)),
        ("peat", pc.tint((0.27, 0.215, 0.16), 1.1, rough=0.95)),
        ("peat", pc.tint((0.028, 0.027, 0.027), 1.6, rough=0.55, keep=0.1)),   # charcoal
        ("snow", pc.tint((0.40, 0.385, 0.37), 1.5, rough=0.95, keep=0.0)),     # ash
    ])


def clamp_a():
    """Stage 1: the stack. Billets on end, leaning in on a centre stake, two
    tiers and a cap; nothing covers it yet."""
    rng = np.random.default_rng(101)
    maps, (bark, wood, turf, earth, char, ash) = clamp_atlas("tw_clamp")
    buf = pc.MeshBuf()
    # the stake the stack is built round, standing proud of the top
    pc.tube(buf, [(0, 0, 0), (0.02, 0, 1.2), (0.0, 0.02, 2.25)], [0.06, 0.05, 0.035], 6, bark[0], bark[0] + 0.1, 1.0)
    # (ring radius, foot height, billet length, lean inward)
    tiers = ((1.55, 0.0, 1.0, 0.16), (1.36, 0.0, 1.0, 0.2), (1.12, 0.86, 0.95, 0.34), (0.86, 0.9, 0.95, 0.42),
             (0.58, 0.98, 0.9, 0.5), (0.3, 1.5, 0.62, 0.42))
    for ring_r, z0, ln, lean in tiers:
        n = max(6, int(TAU * ring_r / 0.165))
        for k in range(n):
            a = TAU * (k + rng.uniform(-0.2, 0.2)) / n
            r = rng.uniform(0.062, 0.088)
            rr = ring_r + rng.normal(0, 0.02)
            foot = np.array([math.cos(a) * rr, math.sin(a) * rr, z0 + rng.uniform(-0.02, 0.03)])
            inw = lean + rng.normal(0, 0.04)
            top = foot + np.array([-math.cos(a) * math.sin(inw), -math.sin(a) * math.sin(inw), math.cos(inw)]) * ln * rng.uniform(0.93, 1.05)
            billet(buf, rng, foot, top, r, bark, wood, sides=5)
    # the dark heart behind the gaps
    pc.lathe(buf, [(1.3, 0.0), (1.22, 0.9), (0.8, 1.3), (0.25, 1.9), (0.0, 1.95)], 10, char[0], char[1], 0.4)
    # a few billets not yet set, lying at the foot, and the chips of the work
    for k in range(5):
        a = 0.4 + k * 0.33 + rng.normal(0, 0.05)
        c = np.array([math.cos(a) * 2.0, math.sin(a) * 2.0, 0.07])
        d = np.array([-math.sin(a), math.cos(a), 0]) * 0.48
        billet(buf, rng, c - d, c + d + np.array([0, 0, rng.uniform(0, 0.03)]), rng.uniform(0.06, 0.08), bark, wood, sides=5)
    return buf, maps, {}


def _turf_dome(buf, rng, turf, earth, char, radius, height, a0=0.0, a1=TAU, sods=64):
    """The turf skin: an earth dome with sods laid on it like scales, grass
    side in, so the outside is root-mat and soil with green at the joints."""
    segs, rings = 18, 6
    span = a1 - a0
    grid = []
    for j in range(rings + 1):
        t = j / rings
        row = []
        for k in range(segs + 1):
            a = a0 + span * k / segs
            lat = t * math.pi * 0.5
            r = radius * math.cos(lat) ** 0.8 * (1 + 0.03 * math.sin(a * 5 + t * 4))
            z = height * math.sin(lat) ** 0.9
            row.append(buf.vert((math.cos(a) * r, math.sin(a) * r, z - (0.04 if j == 0 else 0)),
                                (earth[0] + (earth[1] - earth[0]) * ((k / segs * 3.0) % 1.0), t * 1.3)))
        grid.append(row)
    for j in range(rings):
        for k in range(segs):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    for i in range(sods):
        a = a0 + span * rng.random()
        t = rng.random() ** 1.5 * 0.94
        lat = t * math.pi * 0.5
        r = radius * math.cos(lat) ** 0.8
        z = height * math.sin(lat) ** 0.9
        col = turf if rng.random() < 0.45 else earth
        u0, u1 = strip(rng, col, 0.5)
        pc.blob(buf, rng, (0, 0, 0), (rng.uniform(0.24, 0.36), rng.uniform(0.16, 0.24), 0.07), 7, 4, u0, u1,
                rng.random(), rng.random() + 0.4, lump=0.12,
                xf=pc.xform(pos=(math.cos(a) * (r + 0.02), math.sin(a) * (r + 0.02), z + 0.02), rot_z=a + math.pi / 2 + rng.normal(0, 0.25),
                            rot_x=-(math.pi / 2 - lat) * 0.92))


def clamp_b():
    """Stage 2: turfed and burning. Vent holes round the foot, the stake
    drawn and the top hole plugged with a sod; a rammer and a ladder pole."""
    rng = np.random.default_rng(102)
    maps, (bark, wood, turf, earth, char, ash) = clamp_atlas("tw_clamp")
    buf = pc.MeshBuf()
    _turf_dome(buf, rng, turf, earth, char, 1.72, 1.95, sods=170)
    # vents: dark mouths at the foot, each with a kerb sod over it
    for k in range(7):
        a = TAU * (k + 0.3) / 7
        p = (math.cos(a) * 1.7, math.sin(a) * 1.7, 0.12)
        pc.blob(buf, rng, p, (0.11, 0.11, 0.1), 6, 4, char[0], char[0] + 0.08, lump=0.05)
        pc.blob(buf, rng, (0, 0, 0), (0.2, 0.12, 0.06), 6, 3, *strip(rng, turf, 0.4),
                xf=pc.xform(pos=(math.cos(a) * 1.72, math.sin(a) * 1.72, 0.27), rot_z=a + math.pi / 2))
    # the plugged top: a ring of soot and the last sod
    pc.lathe(buf, [(0.42, 1.9), (0.3, 1.97), (0.0, 1.99)], 10, char[0], char[1], 0.5)
    pc.blob(buf, rng, (0.03, 0.0, 2.0), (0.2, 0.17, 0.07), 7, 4, *strip(rng, turf, 0.4), lump=0.12)
    # a notched pole to climb it by, laid against the side
    pc.tube(buf, [(1.95, 0.5, 0.0), (1.4, 0.38, 1.0), (0.82, 0.24, 1.75)], [0.05, 0.045, 0.04], 6, bark[0], bark[0] + 0.1, 1.0)
    for i in range(4):
        f = 0.2 + 0.2 * i
        p = np.array([1.95, 0.5, 0.0]) * (1 - f) + np.array([0.82, 0.24, 1.75]) * f
        pc.box(buf, (0.07, 0.3, 0.035), pc.xform(pos=p + np.array([0.03, 0, 0.03]), rot_y=-0.9), rect(wood), uv_per_m=0.5, jitter=0.004, rng=rng)
    return buf, maps, {}


def clamp_c():
    """Stage 3: opened. The turf is thrown off one side, the charcoal raked
    out in a fan across the hearth, and the rake left on it."""
    rng = np.random.default_rng(103)
    maps, (bark, wood, turf, earth, char, ash) = clamp_atlas("tw_clamp")
    buf = pc.MeshBuf()
    # the hearth: ash and fines, wider than the stack stood
    mound(buf, rng, 2.05, 0.1, ash, segs=18, rings=4, lump=0.06)
    # what is left of the turf wall, a broken crescent on the far side
    segs = 12
    for j in range(segs):
        a = math.radians(35 + 220 * j / (segs - 1))
        h = 0.75 * math.sin(math.pi * j / (segs - 1)) ** 0.6 * rng.uniform(0.7, 1.1) + 0.12
        for layer in range(int(h / 0.16) + 1):
            col = turf if (layer + j) % 3 == 0 else earth
            rr = 1.6 - layer * 0.07 + rng.normal(0, 0.03)
            pc.blob(buf, rng, (0, 0, 0), (0.3, 0.2, 0.1), 7, 4, *strip(rng, col, 0.5), rng.random(), rng.random() + 0.4, lump=0.14,
                    xf=pc.xform(pos=(math.cos(a) * rr, math.sin(a) * rr, 0.08 + layer * 0.15), rot_z=a + math.pi / 2 + rng.normal(0, 0.2),
                                rot_x=rng.normal(0, 0.15)))
    # sods thrown clear
    for _ in range(9):
        a = math.radians(rng.uniform(20, 270))
        rr = rng.uniform(2.0, 2.5)
        pc.blob(buf, rng, (0, 0, 0), (0.26, 0.18, 0.07), 6, 3, *strip(rng, turf if rng.random() < 0.5 else earth, 0.5), lump=0.15,
                xf=pc.xform(pos=(math.cos(a) * rr, math.sin(a) * rr, 0.06), rot_z=rng.random() * TAU, rot_x=rng.normal(0, 0.3)))
    # the charcoal: a heap in the heart, raked out toward the open side (-Y)
    for _ in range(120):
        if rng.random() < 0.55:
            a, r = rng.random() * TAU, abs(rng.normal(0, 0.45))
            p = (math.cos(a) * r, math.sin(a) * r, 0.1 + max(0.0, 0.34 - r * 0.45) * rng.random())
        else:
            a = math.radians(rng.uniform(-125, -55))
            r = rng.uniform(0.5, 1.95)
            p = (math.cos(a) * r, math.sin(a) * r, 0.09 + 0.03 * rng.random())
        coal(buf, rng, p, rng.uniform(0.05, 0.1), char)
    # half-burnt brands standing in the heap
    for _ in range(5):
        a, r = rng.random() * TAU, rng.uniform(0.1, 0.5)
        f = np.array([math.cos(a) * r, math.sin(a) * r, 0.1])
        pc.tube(buf, [f, f + np.array([rng.normal(0, 0.1), rng.normal(0, 0.1), rng.uniform(0.3, 0.5)])], [0.04, 0.025], 5,
                char[0], char[0] + 0.06, 1.5)
    # the rake: a long ash handle and a toothed head, lying on the fan
    pc.tube(buf, [(0.5, -2.3, 0.1), (0.3, -1.3, 0.14), (0.12, -0.45, 0.16)], [0.02, 0.019, 0.018], 6, wood[0], wood[0] + 0.05, 1.0)
    pc.box(buf, (0.46, 0.045, 0.04), pc.xform(pos=(0.12, -0.45, 0.16), rot_z=-0.2), rect(wood), uv_per_m=0.5, jitter=0.003, rng=rng)
    for i in range(6):
        x = -0.2 + i * 0.08
        pc.tube(buf, [(0.12 + x * math.cos(-0.2), -0.45 + x * math.sin(-0.2), 0.15), (0.12 + x * math.cos(-0.2), -0.45 + x * math.sin(-0.2) + 0.01, 0.07)],
                [0.008, 0.005], 4, wood[0], wood[0] + 0.03, 2.0)
    return buf, maps, {}


def cordwood():
    """A cord: billets a metre long between two pairs of stakes, 2.4 m."""
    rng = np.random.default_rng(111)
    maps, (bark, wood) = pc.make_atlas("tw_cordwood", [("bark", None), ("timber", pc.tint((0.55, 0.45, 0.32), 1.0))])
    buf = pc.MeshBuf()
    for sx in (-1.16, 1.16):
        for sy in (-0.34, 0.34):
            pc.tube(buf, [(sx, sy, -0.05), (sx + rng.normal(0, 0.01), sy, 0.7), (sx + rng.normal(0, 0.025), sy, 1.38)],
                    [0.04, 0.036, 0.028], 6, bark[0], bark[0] + 0.1, 1.2)
    # two bearers on the ground keep the bottom row out of the wet
    for sy in (-0.3, 0.3):
        billet(buf, rng, (-1.15, sy, 0.05), (1.15, sy, 0.05), 0.05, bark, wood)
    z = 0.1
    while z < 1.1:
        x = -1.1 + rng.uniform(0, 0.04)
        row_h = 0.0
        while x < 1.08:
            r = rng.uniform(0.06, 0.1)
            if x + r * 2 > 1.12:
                break
            ln = rng.uniform(0.92, 1.06)
            y0 = rng.normal(0, 0.025)
            cz = z + r
            billet(buf, rng, (x + r, y0 - ln / 2, cz), (x + r + rng.normal(0, 0.01), y0 + ln / 2, cz + rng.normal(0, 0.008)), r, bark, wood, sides=6)
            x += r * 2.02
            row_h = max(row_h, r * 1.78)
        z += row_h
    return buf, maps, {}


def hurdle():
    """A woven hazel hurdle, 1.8 m by 1.15: nine upright zales, the rods
    woven round them and twisted back at the ends."""
    rng = np.random.default_rng(121)
    maps, (rod, pale) = pc.make_atlas("tw_hurdle", [("bark", pc.tint((0.30, 0.22, 0.15), 1.0)), ("timber", pc.tint((0.58, 0.47, 0.32), 1.0))])
    buf = pc.MeshBuf()
    xs = [-0.86 + 1.72 * i / 8 for i in range(9)]
    for i, x in enumerate(xs):
        top = 1.28 if i in (0, 8) else 1.2 + rng.uniform(-0.03, 0.04)
        pc.tube(buf, [(x, 0, -0.25 if i in (0, 8) else 0.0), (x + rng.normal(0, 0.006), rng.normal(0, 0.006), 0.6), (x, 0, top)],
                [0.022, 0.02, 0.014], 5, rod[0], rod[0] + 0.08, 1.5)
    z = 0.06
    row = 0
    while z < 1.14:
        r = rng.uniform(0.009, 0.014)
        pts = []
        for k in range(-1, 18):
            x = -0.9 + 1.8 * (k + 0.5) / 17
            # in front of one zale, behind the next
            y = 0.03 * math.sin(math.pi * ((x + 0.86) / (1.72 / 8)) + math.pi * row) * (1.0 if -0.9 < x < 0.9 else 0.3)
            pts.append((max(-0.93, min(0.93, x)), y, z + rng.normal(0, 0.004)))
        col = pale if rng.random() < 0.18 else rod      # a few peeled rods among the green
        u0, u1 = strip(rng, col, 0.12)
        pc.tube(buf, pts, [r] * len(pts), 4, u0, u1, 1.6, v0=rng.random())
        z += r * 2.0 + rng.uniform(0.0, 0.004)
        row += 1
    return buf, maps, {}


def stake_bundle():
    """Hazel stakes and binders, tied: what a hedge-layer carries to the work."""
    rng = np.random.default_rng(131)
    maps, (rod, pale, withy) = pc.make_atlas("tw_stakes", [("bark", pc.tint((0.30, 0.23, 0.16), 1.0)), ("timber", pc.tint((0.60, 0.49, 0.34), 1.0)),
                                                         ("rope", pc.tint((0.35, 0.27, 0.17), 1.0))])
    buf = pc.MeshBuf()
    # stakes lying along X in a rough round bundle, points one way
    placed = []
    for i in range(16):
        while True:
            y, z = rng.normal(0, 0.09), abs(rng.normal(0.11, 0.07))
            if all(math.hypot(y - py, z - pz) > 0.045 for py, pz in placed) and z > 0.025:
                break
        placed.append((y, z))
        r = rng.uniform(0.02, 0.028)
        x0 = -0.78 + rng.normal(0, 0.03)
        u0, u1 = strip(rng, rod, 0.12)
        pc.tube(buf, [(x0, y, z), (0.0, y + rng.normal(0, 0.008), z + rng.normal(0, 0.006)), (0.66, y, z), (0.8, y, z)],
                [r, r, r * 0.9, 0.004], 5, u0, u1, 1.4, v0=rng.random(), cap_end=False)
        pc.cap(buf, (x0, y, z), (-1, 0, 0), r, 5, ((pale[0] + pale[1]) / 2, rng.random()), (pale[1] - pale[0]) * 0.3)
    # two withy ties
    for x in (-0.42, 0.36):
        ring = [(x + rng.normal(0, 0.004), math.cos(a) * 0.2, 0.13 + math.sin(a) * 0.15) for a in np.linspace(0, TAU, 13)]
        pc.tube(buf, ring, [0.009] * len(ring), 4, withy[0], withy[0] + 0.06, 3.0, cap_end=False)
    # the binders: long thin rods, coiled and laid on top
    for k in range(4):
        pts = []
        for a in np.linspace(0, TAU * 1.6, 26):
            rr = 0.3 + 0.012 * k + 0.02 * math.sin(a * 2 + k)
            pts.append((0.02 + math.cos(a) * rr, math.sin(a) * rr * 0.62, 0.25 + 0.012 * k + 0.02 * a / TAU + 0.05 * abs(math.sin(a))))
        pc.tube(buf, pts, [0.007] * len(pts), 4, rod[0], rod[0] + 0.05, 2.0)
    return buf, maps, {}


def stile():
    """A two-step plank stile: two hand posts a stride apart, a low sill
    board between them and a step either side, on short blocks. It is built
    low on purpose here; the Bearer walks it without a climb."""
    rng = np.random.default_rng(141)
    maps, (oak, plank) = pc.make_atlas("tw_stile", [("timber", pc.tint((0.33, 0.28, 0.22), 1.0)), ("planks", pc.tint((0.44, 0.37, 0.28), 1.0))])
    buf = pc.MeshBuf()
    for sx in (-0.78, 0.78):
        # hand posts: adzed square, a rounded head worn by palms
        pc.box(buf, (0.16, 0.15, 1.5), pc.xform(pos=(sx, 0, 0.6), rot_z=rng.normal(0, 0.06), rot_y=sx * 0.03), rect(oak), uv_per_m=0.5, jitter=0.008, rng=rng)
        pc.blob(buf, rng, (sx + sx * 0.02, 0, 1.36), (0.095, 0.09, 0.07), 7, 4, oak[0], oak[0] + 0.1, lump=0.05)
    # the sill through the hedge, and a step either side of it
    pc.box(buf, (1.42, 0.3, 0.07), pc.xform(pos=(0, 0, 0.19), rot_z=0.02), rect(plank), uv_per_m=0.5, jitter=0.006, rng=rng)
    for sy, zz in ((-0.48, 0.1), (0.5, 0.1)):
        pc.box(buf, (1.2, 0.34, 0.06), pc.xform(pos=(rng.normal(0, 0.02), sy, zz), rot_z=rng.normal(0, 0.04)), rect(plank), uv_per_m=0.5, jitter=0.006, rng=rng)
        for sx in (-0.45, 0.45):
            pc.box(buf, (0.14, 0.3, 0.1), pc.xform(pos=(sx, sy, 0.03)), rect(oak), uv_per_m=0.5, jitter=0.006, rng=rng)
    for sx in (-0.56, 0.56):
        pc.box(buf, (0.12, 0.26, 0.18), pc.xform(pos=(sx, 0, 0.07)), rect(oak), uv_per_m=0.5, jitter=0.006, rng=rng)
    # a rail from post to hedge on each side, at hip height, to keep stock out
    for sx in (-1, 1):
        pc.tube(buf, [(sx * 0.78, 0.0, 0.92), (sx * 1.05, 0.02, 0.9), (sx * 1.32, 0.0, 0.84)], [0.03, 0.028, 0.024], 5, oak[0], oak[0] + 0.08, 1.0)
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.008}


def charcoal_sacks():
    """Sacks of charcoal: three stood and stacked, one tipped and spilling."""
    rng = np.random.default_rng(151)
    maps, (sack, tie, char) = pc.make_atlas("tw_sacks", [("felt", pc.tint((0.30, 0.26, 0.21), 1.0)), ("rope", None),
                                                       ("peat", pc.tint((0.028, 0.027, 0.027), 1.6, rough=0.55, keep=0.1))])
    buf = pc.MeshBuf()

    def one(pos, rot_z=0.0, rot_x=0.0, h=0.42):
        xf = pc.xform(pos=pos, rot_z=rot_z, rot_x=rot_x)
        u0, u1 = strip(rng, sack, 0.6)
        k = h / 0.42
        prof = [(0.0, 0.0), (0.2, 0.015), (0.27, 0.16 * k), (0.28, 0.45 * k), (0.24, 0.68 * k), (0.13, 0.8 * k), (0.07, 0.84 * k)]
        prof = [(r * (1 + 0.06 * math.sin(i * 2.3 + pos[0] * 9)), z) for i, (r, z) in enumerate(prof)]
        pc.lathe(buf, prof, 12, u0, u1, 0.9, xf=xf, squash=(1.0, 0.78))
        # the gathered neck and its tie
        pc.blob(buf, rng, (0, 0, h * 2 + 0.02), (0.07, 0.06, 0.08), 6, 3, u0, u0 + 0.05, lump=0.2, xf=xf)
        ring = [(math.cos(a) * 0.062, math.sin(a) * 0.055, h * 2 - 0.03) for a in np.linspace(0, TAU, 9)]
        ring = [tuple(xf[:3, :3] @ np.array(p) + xf[:3, 3]) for p in ring]
        pc.tube(buf, ring, [0.008] * 9, 4, tie[0], tie[0] + 0.06, 3.0, cap_end=False)

    one((-0.42, 0.05, 0.0), 0.2)
    one((0.12, 0.12, 0.0), -0.3)
    one((-0.14, -0.02, 0.36), 1.4, rot_x=1.35, h=0.4)      # laid across the two
    one((0.62, -0.28, 0.16), 0.5, rot_x=1.5, h=0.38)       # tipped over, mouth open
    for _ in range(46):
        a = rng.uniform(-1.0, 0.2)
        r = abs(rng.normal(0, 0.28)) + 0.05
        coal(buf, rng, (0.78 + math.cos(a) * r * 0.6, -0.72 + math.sin(a) * r * 0.5 - r * 0.35, 0.03 + 0.03 * rng.random()), rng.uniform(0.03, 0.06), char)
    return buf, maps, {}


def gatepost():
    """One oak gatepost, hewn square below and rounded at the head, with two
    pegs bored through for a gate that was never hung."""
    rng = np.random.default_rng(161)
    maps, (oak, grain) = pc.make_atlas("tw_gatepost", [("timber", pc.tint((0.30, 0.26, 0.21), 1.0)), ("timber", pc.tint((0.50, 0.42, 0.31), 1.0))])
    buf = pc.MeshBuf()
    pc.box(buf, (0.22, 0.2, 1.5), pc.xform(pos=(0, 0, 0.62), rot_z=0.05, rot_y=0.02), rect(oak), uv_per_m=0.5, jitter=0.01, rng=rng)
    pc.blob(buf, rng, (0.012, 0, 1.4), (0.125, 0.115, 0.1), 8, 5, oak[0], oak[0] + 0.12, lump=0.05)
    for z in (0.42, 1.08):
        pc.tube(buf, [(-0.02, 0, z), (0.2, 0.0, z + 0.01)], [0.022, 0.02], 6, grain[0], grain[0] + 0.05, 1.0)
    # packing stones at the foot
    for k in range(5):
        a = TAU * k / 5 + rng.normal(0, 0.2)
        pc.blob(buf, rng, (math.cos(a) * 0.2, math.sin(a) * 0.19, 0.03), (0.1, 0.08, 0.06), 6, 4, oak[0], oak[0] + 0.1, lump=0.2)
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.01}


# ---------------------------------------------------------------- Linnet's hut
# A collier's hut is a cone of poles under turf (BIOMES.md tw_collier_hut).
# This one is modelled, not generated: POI.md 6.2 needs its inside seen from
# the door in two states, and a generated solid has no inside.
HUT_R, HUT_H = 1.9, 2.65
DOOR_HALF = math.radians(23.0)          # the doorway, centred on -Y (the game's +Z)
DOOR_H = 1.55


def hut_atlas():
    return pc.make_atlas("tw_hut", [
        ("bark", None),
        ("timber", pc.tint((0.40, 0.33, 0.25), 1.0)),
        ("turf", pc.tint((0.29, 0.34, 0.16), 1.0)),
        ("peat", pc.tint((0.26, 0.21, 0.16), 1.1, rough=0.95)),
        ("peat", pc.tint((0.07, 0.065, 0.06), 1.3, rough=0.8, keep=0.1)),      # soot, and the dark inside
        ("leather", pc.tint((0.27, 0.20, 0.14), 1.0)),
        ("wool", pc.tint((0.55, 0.50, 0.40), 1.0)),
        ("fieldstone", pc.tint((0.36, 0.36, 0.34), 1.0)),
    ])


def _in_door(a, z):
    d = (a + math.pi / 2 + math.pi) % TAU - math.pi      # angle from -Y
    return abs(d) < DOOR_HALF and z < DOOR_H


def collier_hut():
    rng = np.random.default_rng(171)
    maps, (bark, wood, turf, earth, soot, hide, wool, stone) = hut_atlas()
    buf = pc.MeshBuf()

    def cone_r(z):
        return HUT_R * (1.0 - z / HUT_H) + 0.06

    # the skin, outside (earth and root-mat) and inside (smoke-black), cut at the door
    segs, rows = 30, 9
    for inside in (False, True):
        col = soot if inside else earth
        off = -0.07 if inside else 0.0
        grid = []
        for j in range(rows + 1):
            z = (HUT_H - 0.35) * j / rows
            row = []
            for k in range(segs + 1):
                a = TAU * k / segs
                r = cone_r(z) + off + (0.0 if inside else 0.025 * math.sin(a * 7 + z * 5))
                row.append(buf.vert((math.cos(a) * r, math.sin(a) * r, z - (0.05 if j == 0 else 0)),
                                    (col[0] + (col[1] - col[0]) * ((k / segs * 4.0) % 1.0), z * 0.6)))
            grid.append(row)
        for j in range(rows):
            zc = (HUT_H - 0.35) * (j + 0.5) / rows
            for k in range(segs):
                if _in_door(TAU * (k + 0.5) / segs, zc):
                    continue
                if inside:
                    buf.quad(grid[j][k], grid[j + 1][k], grid[j + 1][k + 1], grid[j][k + 1])
                else:
                    buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    # the floor inside: trodden black earth
    pc.cap(buf, (0, 0, 0.012), (0, 0, 1), HUT_R - 0.02, 16, ((soot[0] + soot[1]) / 2, 0.5), (soot[1] - soot[0]) * 0.45)
    # sods laid up it like scales, the lower courses green, soot toward the top
    for i in range(210):
        a = rng.random() * TAU
        z = rng.random() ** 1.3 * (HUT_H - 0.75)
        if _in_door(a, z + 0.12):
            continue
        r = cone_r(z) + 0.03
        col = soot if z > 1.75 and rng.random() < 0.7 else (turf if rng.random() < 0.5 else earth)
        u0, u1 = strip(rng, col, 0.5)
        slope = math.atan2(HUT_R, HUT_H)
        pc.blob(buf, rng, (0, 0, 0), (rng.uniform(0.22, 0.32), rng.uniform(0.15, 0.22), 0.06), 7, 4, u0, u1, rng.random(), rng.random() + 0.4,
                lump=0.12, xf=pc.xform(pos=(math.cos(a) * r, math.sin(a) * r, z + 0.05), rot_z=a + math.pi / 2 + rng.normal(0, 0.2),
                                       rot_x=-(math.pi / 2 - slope)))
    # the poles: butts in the ground, crossing at the peak and standing out of it
    for k in range(13):
        a = TAU * (k + 0.5) / 13 + rng.normal(0, 0.04)
        if abs((a + math.pi / 2 + math.pi) % TAU - math.pi) < DOOR_HALF * 0.8:
            continue
        foot = np.array([math.cos(a) * (HUT_R - 0.02), math.sin(a) * (HUT_R - 0.02), -0.05])
        top = np.array([-math.cos(a) * 0.3, -math.sin(a) * 0.3, HUT_H + rng.uniform(0.25, 0.6)])
        mid = (foot + top) / 2 + rng.normal(0, 0.02, 3)
        u0, u1 = strip(rng, bark, 0.12)
        pc.tube(buf, [foot, mid, top], [0.05, 0.042, 0.028], 5, u0, u1, 1.2)
    # the door frame: two jamb poles and a lintel, and the hide flap tied back
    jl = []
    for sgn in (-1, 1):
        a = -math.pi / 2 + sgn * DOOR_HALF
        foot = np.array([math.cos(a) * (HUT_R + 0.04), math.sin(a) * (HUT_R + 0.04), -0.05])
        top = np.array([math.cos(a) * (cone_r(DOOR_H) + 0.05), math.sin(a) * (cone_r(DOOR_H) + 0.05), DOOR_H + 0.08])
        pc.tube(buf, [foot, top], [0.05, 0.045], 6, bark[0], bark[0] + 0.1, 1.2)
        jl.append(top)
    pc.tube(buf, [jl[0] + np.array([-0.12, 0, 0]), jl[1] + np.array([0.12, 0, 0])], [0.045, 0.04], 6, bark[0], bark[0] + 0.1, 1.2)
    # the flap: hung from the lintel, gathered to the left jamb
    nx, nz = 6, 8
    grid = []
    for j in range(nz + 1):
        t = j / nz
        row = []
        for i in range(nx + 1):
            u = i / nx
            width = 0.62 * (1.0 - 0.72 * t)                 # gathered narrower toward the tie
            x = jl[0][0] - 0.05 + u * width + 0.03 * math.sin(u * 9 + t * 5)
            y = jl[0][1] - 0.07 - 0.05 * math.sin(u * 12) * t - 0.1 * t * (1 - t) * 4 * 0.3
            z = DOOR_H + 0.02 - t * 1.25 + 0.05 * u * t
            row.append(buf.vert((x, y, z), (hide[0] + (hide[1] - hide[0]) * u, t * 0.9)))
        grid.append(row)
    for j in range(nz):
        for i in range(nx):
            buf.quad(grid[j][i], grid[j + 1][i], grid[j + 1][i + 1], grid[j][i + 1])
            buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
    return buf, maps, {}


def hut_yard():
    """What stands outside the door: a three-legged stool and a water pail."""
    rng = np.random.default_rng(172)
    maps, (bark, wood, turf, earth, soot, hide, wool, stone) = hut_atlas()
    buf = pc.MeshBuf()
    sx, sy = 1.15, -2.35
    pc.lathe(buf, [(0.0, 0.36), (0.17, 0.36), (0.18, 0.4), (0.0, 0.41)], 9, wood[0], wood[1], 1.0, xf=pc.xform(pos=(sx, sy, 0)))
    for k in range(3):
        a = TAU * k / 3 + 0.4
        pc.tube(buf, [(sx + math.cos(a) * 0.2, sy + math.sin(a) * 0.2, 0.0), (sx + math.cos(a) * 0.09, sy + math.sin(a) * 0.09, 0.37)],
                [0.022, 0.026], 5, bark[0], bark[0] + 0.06, 1.5)
    px, py = 1.62, -1.95
    pc.lathe(buf, [(0.0, 0.02), (0.15, 0.02), (0.18, 0.34), (0.165, 0.34), (0.14, 0.05), (0.0, 0.05)], 10, wood[0], wood[1], 1.0,
             xf=pc.xform(pos=(px, py, 0)))
    for z in (0.09, 0.27):
        ring = [(px + math.cos(a) * (0.158 + z * 0.09), py + math.sin(a) * (0.158 + z * 0.09), z) for a in np.linspace(0, TAU, 13)]
        pc.tube(buf, ring, [0.008] * 13, 4, bark[0], bark[0] + 0.05, 3.0, cap_end=False)
    arc = [(px + math.cos(a) * 0.17, py, 0.34 + math.sin(a) * 0.15) for a in np.linspace(0, math.pi, 7)]
    pc.tube(buf, arc, [0.007] * 7, 4, hide[0], hide[0] + 0.05, 3.0, cap_end=False)
    return buf, maps, {}


def _bed(buf, rng, wood, turf, wool, made):
    """A pallet of poles and bracken along the back wall, and her blanket."""
    bx, by = -0.72, 0.5
    for sx in (-0.3, 0.3):
        pc.tube(buf, [(bx + sx, by - 0.85, 0.09), (bx + sx, by + 0.8, 0.09)], [0.04, 0.04], 5, wood[0], wood[0] + 0.1, 1.0)
    pc.blob(buf, rng, (bx, by, 0.16), (0.36, 0.86, 0.1), 10, 5, turf[0], turf[1], 0.0, 0.6, lump=0.06)
    if made:
        # folded once and laid square at the foot
        pc.box(buf, (0.6, 0.62, 0.07), pc.xform(pos=(bx, by - 0.45, 0.285), rot_z=0.03), rect(wool), uv_per_m=0.6, jitter=0.012, rng=rng)
        pc.box(buf, (0.58, 0.3, 0.05), pc.xform(pos=(bx, by - 0.6, 0.345), rot_z=-0.02), rect(wool), uv_per_m=0.6, jitter=0.012, rng=rng)
    else:
        # thrown back and left: a ridge down one side, a heap at the foot
        for k in range(7):
            t = k / 6
            pc.blob(buf, rng, (bx + 0.2 - 0.25 * math.sin(t * 2.5), by - 0.75 + 1.25 * t, 0.29 + 0.05 * math.sin(k * 1.7)),
                    (0.24 - 0.05 * t, 0.22, 0.08 + 0.03 * (k % 2)), 7, 4, *strip(rng, wool, 0.5), rng.random(), rng.random() + 0.4, lump=0.25)
        pc.blob(buf, rng, (bx - 0.05, by - 0.85, 0.3), (0.3, 0.2, 0.13), 8, 4, *strip(rng, wool, 0.5), lump=0.3)


def _shelf(buf, rng, wood, bark, stone, cups):
    """Two stakes and a board: two cups, and a whetstone that is not hers."""
    sx, sy = 0.85, 0.62
    for dy in (-0.33, 0.33):
        pc.tube(buf, [(sx + 0.05, sy + dy, 0.0), (sx + 0.03, sy + dy, 0.86)], [0.03, 0.026], 5, bark[0], bark[0] + 0.08, 1.2)
    pc.box(buf, (0.26, 0.86, 0.035), pc.xform(pos=(sx - 0.05, sy, 0.88), rot_z=0.02), rect(wood), uv_per_m=0.6, jitter=0.005, rng=rng)
    cup = [(0.0, 0.0), (0.035, 0.0), (0.045, 0.075), (0.037, 0.075), (0.03, 0.012), (0.0, 0.012)]
    spots = [(sx - 0.05, sy - 0.25), (sx - 0.07, sy - 0.1)]
    for i in range(cups):
        pc.lathe(buf, cup, 8, wood[0], wood[0] + 0.15, 1.0, xf=pc.xform(pos=(spots[i][0], spots[i][1], 0.9)))
    pc.box(buf, (0.05, 0.17, 0.028), pc.xform(pos=(sx - 0.04, sy + 0.2, 0.912), rot_z=0.5), rect(stone), uv_per_m=0.6, jitter=0.003, rng=rng)
    return cup


def hut_thaw():
    rng = np.random.default_rng(173)
    maps, (bark, wood, turf, earth, soot, hide, wool, stone) = hut_atlas()
    buf = pc.MeshBuf()
    _bed(buf, rng, wood, turf, wool, True)
    _shelf(buf, rng, wood, bark, stone, 2)
    return buf, maps, {}


def hut_rime():
    rng = np.random.default_rng(174)
    maps, (bark, wood, turf, earth, soot, hide, wool, stone) = hut_atlas()
    buf = pc.MeshBuf()
    _bed(buf, rng, wood, turf, wool, False)
    cup = _shelf(buf, rng, wood, bark, stone, 1)
    # the other cup is on the floor by the bed, on its side
    pc.lathe(buf, cup, 8, wood[0], wood[0] + 0.15, 1.0, xf=pc.xform(pos=(-0.2, -0.1, 0.05), rot_x=1.5, rot_z=0.8))
    # the floor swept into one corner by the door: dust, bark and ash in a heap
    heap = pc.MeshBuf()
    mound(heap, rng, 0.3, 0.07, earth, segs=10, rings=3, lump=0.12)
    for k in range(9):
        a = rng.random() * TAU
        pc.tube(heap, [(math.cos(a) * 0.12, math.sin(a) * 0.12, 0.06), (math.cos(a) * 0.12 + rng.normal(0, 0.05), math.sin(a) * 0.12 + rng.normal(0, 0.05), 0.075)],
                [0.006, 0.005], 4, *((wool[0], wool[0] + 0.05) if k % 2 else (wool[1] - 0.05, wool[1])), 4.0)
    buf.merge(heap, pc.xform(pos=(0.6, -1.3, 0.012)))
    # the besom she swept it with, leaning in the door
    pc.tube(buf, [(0.88, -1.45, 0.0), (0.98, -1.2, 0.75), (1.04, -1.05, 1.25)], [0.016, 0.015, 0.013], 5, bark[0], bark[0] + 0.05, 1.5)
    for k in range(12):
        a = TAU * k / 12
        pc.tube(buf, [(0.9 + math.cos(a) * 0.015, -1.4 + math.sin(a) * 0.015, 0.34), (0.86 + math.cos(a) * 0.07, -1.5 + math.sin(a) * 0.07, 0.0)],
                [0.006, 0.003], 3, bark[0], bark[0] + 0.03, 2.0)
    return buf, maps, {}


def thorn_stile():
    """The thorn grown over a stile: a narrow piece at stile width, grown for
    this height (frozen thorn is never stretched). The decimated skin is used
    close up as well: there are two of these and they are seen at arm's length
    for as long as it takes to break them."""
    import thorn_rime as tr
    rng = np.random.default_rng(57)
    sk = tr.Skel()
    for i in range(22):
        x = rng.uniform(-1.15, 1.15)
        y = rng.uniform(-0.3, 0.55)
        tr.cane(sk, rng, (x, y, 0.0), rng.normal(-math.pi / 2, 0.9), rng.uniform(1.6, 2.6), rng.uniform(0.55, 0.9), rng.uniform(0.3, 0.7),
                wobble=0.35, xlim=1.3, ylim=0.7)
    pts = []
    while len(pts) < 1000:
        p = rng.uniform(-1, 1, 3)
        p[2] = abs(p[2])
        if np.linalg.norm(p) > 1:
            continue
        pts.append((p[0] * 1.3, p[1] * 0.7, 0.1 + p[2] * 2.5))
    tr.colonise(sk, rng, pts, jitter=0.4, infl=0.5, kill=0.12, iters=200)
    tr.gnarl(sk, rng, amp=0.08)
    buf, _ = tr.skin(sk, np.random.default_rng(58), False, snow_n=14, drift_dims=(1.25, 0.7, 0.22))
    return buf, tr.atlas(), {}


PIECES = {
    "kit_tw_clamp_a": clamp_a,
    "kit_tw_clamp_b": clamp_b,
    "kit_tw_clamp_c": clamp_c,
    "kit_tw_cordwood": cordwood,
    "kit_tw_hurdle": hurdle,
    "kit_tw_stake_bundle": stake_bundle,
    "kit_tw_stile": stile,
    "kit_tw_charcoal_sacks": charcoal_sacks,
    "kit_tw_gatepost": gatepost,
    "kit_tw_collier_hut": collier_hut,
    "kit_tw_hut_yard": hut_yard,
    "kit_tw_hut_thaw": hut_thaw,
    "kit_tw_hut_rime": hut_rime,
    "lm_thorn_stile": thorn_stile,
}


# pieces set inside or beside the hut carry their own origin: the stool for
# the yard, the bed for the two interiors (gen_thornwold.py places them so)
ORIGINS = {"kit_tw_hut_yard": (1.15, -2.35), "kit_tw_hut_thaw": (-0.72, 0.5), "kit_tw_hut_rime": (-0.72, 0.5)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name, fn in PIECES.items():
        if a.only and a.only != name:
            continue
        buf, maps, opts = fn()
        if name in ORIGINS:
            # the piece's own origin (the audit reads two kits on one spot as a clash)
            ox, oy = ORIGINS[name]
            buf.v = [(x - ox, y - oy, z) for x, y, z in buf.v]
        out_dir = OUT if name.startswith("kit_") else os.path.join(pc.ROOT, "assets", "models", "landmarks")
        pc.export_glb(os.path.join(out_dir, name + ".glb"), name, buf, maps, **opts)


if __name__ == "__main__":
    main()
