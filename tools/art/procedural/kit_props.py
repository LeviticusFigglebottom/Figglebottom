#!/usr/bin/env python3
"""The last box-and-cylinder kit props, modelled (look pass 5; the paid
generation they were queued for is not available, and these are plain
craft pieces that model well by hand).

Each is authored at its KitLib.PIECES footprint (X across, Z up, origin at
the bottom centre) with UVs into a small atlas of committed CC0 sets, and
goes in through KitLib.HERO_PIECES like the Tripo furniture: same ids, same
footprints, colliders unchanged.

  kit_woodpile_p      split logs stacked between stakes, end grain to the front
  kit_hearth_logs_p   charred split logs crossed on an ash bed (long fires)
  kit_salt_pan_p      a kerbed evaporating pan, salt crusted on the clay
  kit_net_frame_p     a net hung to dry: poles, head rope, knotted mesh, floats
  kit_plaque_p        a knife-cut board on a driftwood stake
  kit_door_leaf_p     a ledged and braced plank door, strap hinges, ring pull
  kit_rime_spike_p    a spray of grown ice crystals
  kit_feast_horn_p    a horn beaker (the Long Table's places); _frozen: iced over
  kit_trencher_p      a bread board with a loaf and a turned bowl
  kit_fat_lamp_p      a soapstone fat lamp with a rush wick (not a candle)

Run: $BPY tools/art/procedural/kit_props.py [--only name]
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402
import thorn_rime as tr  # noqa: E402
import veil_frame as vf  # noqa: E402

TAU = math.tau
OUT = os.path.join(pc.ROOT, "assets", "models", "kit")


def split_log(buf, rng, a, b, radius, bark_u, wood_u, v_per_m=1.2, sides=7, char=False):
    """A split length of firewood from a to b: a wedge-ish section (round on
    the bark side, flatter on the split side), sawn ends showing the wood."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    n = 4
    pts = [a + (b - a) * i / (n - 1) + rng.normal(0, radius * 0.06, 3) * (0 < i < n - 1) for i in range(n)]
    sq = (1.0, rng.uniform(0.55, 0.9))
    rad = [radius * rng.uniform(0.92, 1.08) for _ in range(n)]
    span = min(TAU * radius / 0.5, 1.0) * (bark_u[1] - bark_u[0])
    u0 = bark_u[0] + rng.random() * ((bark_u[1] - bark_u[0]) - span)
    pc.tube(buf, pts, rad, sides, u0, u0 + span, v_per_m, v0=rng.random(), cap_end=False, squash=[sq] * n)
    d = (b - a) / np.linalg.norm(b - a)
    t, nn, bb = pc.frames(pts)
    uc = ((wood_u[0] + wood_u[1]) * 0.5, rng.random())
    ur = (wood_u[1] - wood_u[0]) * 0.4
    for p, nrm, i in ((pts[0], -d, 0), (pts[-1], d, -1)):
        _disc(buf, p, nrm, nn[i], bb[i], rad[i], sides, uc, ur, sq, flip=(i == 0))


def _disc(buf, centre, normal, a1, a2, radius, sides, uc, ur, sq, flip):
    c = buf.vert(centre, uc)
    ring = []
    for k in range(sides + 1):
        q = TAU * k / sides
        ring.append(buf.vert(centre + radius * (math.cos(q) * a1 * sq[0] + math.sin(q) * a2 * sq[1]),
                             (uc[0] + ur * math.cos(q), uc[1] + ur * 0.25 * math.sin(q))))
    for k in range(sides):
        if flip:
            buf.tri(c, ring[k + 1], ring[k])
        else:
            buf.tri(c, ring[k], ring[k + 1])


def rect(col):
    return (col[0], 0.0, col[1], 1.0)


def darken(k):
    def fn(alb, orh):
        return np.clip(alb * k, 0, 1), orh
    return fn


def woodpile():
    rng = np.random.default_rng(41)
    maps, (bark, wood) = pc.make_atlas("woodpile", [("bark", None), ("timber", pc.tint((0.50, 0.40, 0.29), 1.0))])
    buf = pc.MeshBuf()
    # four stakes hold the ends; logs lie front to back, a row at a time
    for sx in (-0.95, 0.95):
        for sy in (-0.3, 0.3):
            pc.tube(buf, [(sx, sy, -0.05), (sx + rng.normal(0, 0.01), sy, 0.5), (sx + rng.normal(0, 0.02), sy, 0.95)],
                    [0.035, 0.032, 0.026], 6, bark[0], bark[0] + 0.1, 1.2)
    z = 0.0
    row = 0
    while z < 0.68:
        x = -0.88 + rng.uniform(0, 0.05)
        row_h = 0.0
        while x < 0.86:
            r = rng.uniform(0.055, 0.095)
            if x + r > 0.9:
                break
            ln = rng.uniform(0.78, 0.98)
            y0 = rng.normal(0, 0.03)
            cz = z + r * 0.8
            split_log(buf, rng, (x + r, y0 - ln / 2, cz), (x + r + rng.normal(0, 0.01), y0 + ln / 2, cz + rng.normal(0, 0.01)), r, bark, wood)
            x += r * 1.9
            row_h = max(row_h, r * 1.45)
        z += row_h
        row += 1
    # a few thrown on top, askew
    for _ in range(4):
        x = rng.uniform(-0.6, 0.6)
        ang = rng.normal(0, 0.5)
        r = rng.uniform(0.05, 0.08)
        d = np.array([math.sin(ang), math.cos(ang), 0]) * 0.42
        split_log(buf, rng, np.array([x, 0, z + r * 0.7]) - d, np.array([x, 0, z + r * 0.7]) + d, r, bark, wood)
    return buf, maps, {}


def hearth_logs():
    rng = np.random.default_rng(8)
    maps, (char, wood, ash) = pc.make_atlas("hearth_logs", [
        ("bark", pc.tint((0.07, 0.065, 0.06), 1.2, rough=0.9, keep=0.1)),
        ("timber", pc.tint((0.16, 0.12, 0.09), 1.0)),
        ("snow", pc.tint((0.42, 0.40, 0.38), 1.6, rough=0.95, keep=0.0))])
    buf = pc.MeshBuf()
    # the ash bed: a low lumpy mound
    seg, rings = 14, 4
    grid = []
    for j in range(rings + 1):
        fr = j / rings
        row = []
        for k in range(seg + 1):
            a = TAU * (k % seg) / seg
            r = 0.66 * fr * (1 + 0.12 * math.sin(a * 3 + 1) + 0.08 * math.sin(a * 5))
            z = 0.075 * (1 - fr ** 2) + 0.012 * math.sin(a * 4 + fr * 9) - 0.01
            row.append(buf.vert((math.cos(a) * r, math.sin(a) * r * 0.82, z), (ash[0] + (ash[1] - ash[0]) * (0.5 + 0.5 * math.cos(a) * fr), 0.5 + 0.3 * math.sin(a) * fr)))
        grid.append(row)
    for j in range(rings):
        for k in range(seg):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    # split logs laid like spokes, butts out, the burnt ends meeting
    for k in range(5):
        a = TAU * k / 5 + rng.normal(0, 0.15)
        d = np.array([math.cos(a), math.sin(a) * 0.9, 0])
        split_log(buf, rng, d * 0.62 + np.array([0, 0, 0.07]), d * 0.04 + np.array([0, 0, 0.13 + 0.03 * (k % 2)]),
                  rng.uniform(0.06, 0.085), char, wood, sides=7)
    for k in range(2):
        a = rng.random() * TAU
        d = np.array([math.cos(a), math.sin(a), 0]) * 0.36
        split_log(buf, rng, -d + np.array([0, 0, 0.2]), d + np.array([0, 0, 0.23]), 0.055, char, wood, sides=6)
    for _ in range(9):
        a, r = rng.random() * TAU, rng.uniform(0.1, 0.5)
        pc.blob(buf, rng, (math.cos(a) * r, math.sin(a) * r * 0.8, 0.06), (0.035, 0.028, 0.022), 5, 3, char[0], char[0] + 0.1)
    return buf, maps, {}


def salt_pan():
    rng = np.random.default_rng(23)
    maps, (stone, clay, salt) = pc.make_atlas("salt_pan", [
        ("fieldstone", None), ("peat", pc.tint((0.30, 0.25, 0.20), 1.0)),
        ("snow", pc.tint((0.80, 0.78, 0.72), 1.5, rough=0.7, keep=0.0))])
    buf = pc.MeshBuf()
    # kerb: upright slabs set edge to edge round the pan, none quite alike
    def kerb(x0, x1, y, along_x):
        x = x0
        while x < x1 - 0.05:
            w = min(rng.uniform(0.28, 0.5), x1 - x)
            h = rng.uniform(0.36, 0.47)
            t = rng.uniform(0.14, 0.2)
            c = (x + w / 2, y, h / 2 - 0.03) if along_x else (y, x + w / 2, h / 2 - 0.03)
            size = (w * 0.97, t, h) if along_x else (t, w * 0.97, h)
            pc.box(buf, size, pc.xform(pos=c, rot_z=rng.normal(0, 0.04), rot_x=rng.normal(0, 0.05)), rect(stone), uv_per_m=0.55, jitter=0.012, rng=rng)
            x += w
    for y in (-0.91, 0.91):
        kerb(-1.5, 1.5, y, True)
    for x in (-1.41, 1.41):
        kerb(-0.82, 0.82, x, False)
    # the bed: puddled clay, and a crust of salt drying on it, thickest in
    # the middle where the last brine stood
    nx, ny = 14, 9
    for col, z0, lump, inset in ((clay, 0.2, 0.01, 0.0), (salt, 0.235, 0.022, 0.16)):
        grid = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                u, v = i / nx, j / ny
                x = (u - 0.5) * (2.7 - inset * 2) * (1 + (0.04 * math.sin(v * 9) if inset else 0))
                y = (v - 0.5) * (1.7 - inset * 2) * (1 + (0.05 * math.sin(u * 11) if inset else 0))
                edge = min(u, 1 - u, v, 1 - v)
                z = z0 + lump * math.sin(u * 23 + v * 7) * math.sin(v * 17 + 1) + (0.03 * min(edge * 4, 1) if inset else 0) - (0.04 if inset and edge == 0 else 0)
                row.append(buf.vert((x, y, z), (col[0] + (col[1] - col[0]) * u, v * 0.9)))
            grid.append(row)
        for j in range(ny):
            for i in range(nx):
                buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.012}


def net_frame():
    rng = np.random.default_rng(12)
    maps, (wood, rope, cork) = pc.make_atlas("net_frame", [
        ("timber", pc.tint((0.36, 0.31, 0.26), 1.0)), ("rope", None), ("timber", pc.tint((0.55, 0.47, 0.36), 0.7))])
    buf = pc.MeshBuf()
    tops = {}
    for sx in (-1, 1):
        base = np.array([sx * 1.68, 0.0, -0.05])
        top = np.array([sx * 1.58, rng.normal(0, 0.03), 2.5])
        mid = (base + top) / 2 + np.array([sx * 0.03, 0.02, 0])
        pc.tube(buf, [base, mid, top], [0.06, 0.052, 0.04], 7, wood[0], wood[0] + 0.14, 0.8)
        tops[sx] = top - np.array([0, 0, 0.18])
        # a stay each side, pegged
        pc.tube(buf, [tops[sx], np.array([sx * 1.75, -0.14 * sx, 0.0])], [0.008, 0.008], 3, rope[0], rope[0] + 0.05, 3.0, cap_end=False)

    def head(u):
        """The head rope: hung between the poles, sagging."""
        p = tops[-1] + (tops[1] - tops[-1]) * u
        return p - np.array([0, 0, 0.26 * 4 * u * (1 - u)])
    pc.tube(buf, [head(i / 16) for i in range(17)], [0.014] * 17, 5, rope[0], rope[0] + 0.1, 3.0, cap_end=False)
    # the net: a diamond mesh hanging from the head rope, bellied by its own
    # weight and gathered a little at the foot
    nu, nv = 26, 12

    def knot(i, j):
        u, v = i / nu, j / nv
        hp = head(u)
        drop = 1.72 * v
        belly = 0.16 * math.sin(v * math.pi) * math.sin(u * math.pi * 3 + 0.7) + 0.05 * math.sin(u * 17 + v * 5)
        gather = 1.0 - 0.06 * v * math.cos(u * math.pi * 2)
        return np.array([hp[0] * gather, hp[1] + belly, hp[2] - drop * (1 - 0.05 * math.sin(u * 9))])
    for i0 in range(-nv, nu + 1):
        for sgn in (1, -1):
            line = []
            for j in range(nv + 1):
                i = i0 + j if sgn > 0 else i0 + nv - j
                if 0 <= i <= nu:
                    line.append(knot(i, j))
            if len(line) >= 2:
                pc.tube(buf, line, [0.0055] * len(line), 3, rope[0] + 0.02, rope[0] + 0.06, 6.0, cap_end=False)
    # cork floats threaded on the head rope; a few net weights at the foot
    for k in range(8):
        p = head((k + 0.5) / 8)
        pc.blob(buf, rng, p, (0.075, 0.05, 0.05), 7, 4, cork[0], cork[0] + 0.12, lump=0.05)
    return buf, maps, {}


def plaque():
    rng = np.random.default_rng(31)
    maps, (drift, board, iron) = pc.make_atlas("plaque", [
        ("timber", pc.tint((0.45, 0.42, 0.38), 1.2)), ("planks", pc.tint((0.40, 0.34, 0.27), 1.0)), ("iron", None)], size=512)
    buf = pc.MeshBuf()
    # the stake: a crooked length of driftwood, split at the head
    pts = [np.array([0.0, 0.02, -0.1]), np.array([0.012, 0.03, 0.4]), np.array([-0.01, 0.045, 0.85]), np.array([0.008, 0.07, 1.24])]
    pc.tube(buf, pts, [0.07, 0.062, 0.055, 0.04], 7, drift[0], drift[0] + 0.25, 0.9, squash=[(1, 0.8)] * 4)
    # the board: one adzed plank, top edge broken, hung a little out of true
    xf = pc.xform(pos=(0.0, -0.035, 1.02), rot_y=math.radians(2.5), rot_x=math.radians(7))
    pc.box(buf, (0.72, 0.045, 0.44), xf, rect(board), uv_per_m=0.9, jitter=0.012, rng=rng)
    for sx in (-0.12, 0.1):
        hx = pc.xform(pos=(sx, -0.065, 1.02 + rng.normal(0, 0.06)), rot_x=math.radians(7))
        pc.lathe(buf, [(0.0, 0.012), (0.014, 0.008), (0.016, 0.0)], 6, iron[0], iron[0] + 0.1, 1.0, xf=hx @ pc.xform(rot_x=math.radians(90)))
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.006}


def door_leaf():
    rng = np.random.default_rng(19)
    maps, (plank, dark, iron) = pc.make_atlas("door_leaf", [
        ("planks", pc.tint((0.38, 0.32, 0.26), 1.0)), ("timber", pc.tint((0.26, 0.21, 0.17), 1.0)), ("iron", None)])
    buf = pc.MeshBuf()
    widths = np.array([0.26, 0.2, 0.27, 0.22])
    widths *= 0.95 / widths.sum()
    x = -0.475
    for w in widths:
        h = 2.45 + rng.uniform(-0.02, 0.03)
        pc.box(buf, (w - 0.008, 0.055, h), pc.xform(pos=(x + w / 2, rng.normal(0, 0.004), h / 2 + 0.02)), rect(plank), uv_per_m=0.5, jitter=0.004, rng=rng)
        x += w
    # ledges and a brace on the back (+Y in Blender is the game's -Z)
    for zz in (0.42, 2.05):
        pc.box(buf, (0.9, 0.05, 0.15), pc.xform(pos=(0, 0.052, zz)), rect(dark), uv_per_m=0.5, jitter=0.004, rng=rng)
    pc.box(buf, (0.11, 0.045, 1.78), pc.xform(pos=(0, 0.05, 1.235), rot_y=math.radians(26)), rect(dark), uv_per_m=0.5, jitter=0.004, rng=rng)
    # strap hinges on the face, each ending in a spear point, and their nails
    for zz in (0.42, 2.05):
        pc.box(buf, (0.62, 0.012, 0.05), pc.xform(pos=(-0.16, -0.034, zz)), rect(iron), uv_per_m=1.0, jitter=0.001, rng=rng)
        pc.box(buf, (0.09, 0.012, 0.09), pc.xform(pos=(0.17, -0.034, zz), rot_y=math.radians(45)), rect(iron), uv_per_m=1.0, rng=rng)
        for nx in (-0.4, -0.2, 0.0):
            pc.lathe(buf, [(0.0, 0.012), (0.012, 0.007), (0.014, 0.0)], 6, iron[0], iron[0] + 0.1, 1.0,
                     xf=pc.xform(pos=(nx, -0.04, zz), rot_x=math.radians(90)))
    # the ring pull on its staple
    ring = [np.array([0.3 + 0.06 * math.cos(q), -0.05, 1.2 - 0.03 + 0.06 * math.sin(q)]) for q in np.linspace(0, TAU, 13)]
    pc.tube(buf, ring, [0.009] * 13, 5, iron[0], iron[0] + 0.1, 2.0, cap_end=False)
    pc.box(buf, (0.03, 0.03, 0.05), pc.xform(pos=(0.3, -0.036, 1.235)), rect(iron), uv_per_m=1.0, rng=rng)
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.005}


def rime_spike():
    rng = np.random.default_rng(9)
    maps = vf.atlas()
    buf = pc.MeshBuf()
    # one tall leaning crystal and the smaller ones crowding its foot
    vf.crystal(buf, rng, (0.0, 0.0, 0.0), (0.1, 0.05, 1.0), 1.78, 0.17)
    for k in range(11):
        a = TAU * k / 11 + rng.normal(0, 0.2)
        r = rng.uniform(0.08, 0.3)
        ln = rng.uniform(0.35, 1.15) * (1.0 - r)
        d = (math.cos(a) * rng.uniform(0.25, 0.7), math.sin(a) * rng.uniform(0.25, 0.7), 1.0)
        vf.crystal(buf, rng, (math.cos(a) * r, math.sin(a) * r, 0.0), d, ln, ln * rng.uniform(0.11, 0.17))
    for k in range(6):
        a = rng.random() * TAU
        vf.crystal(buf, rng, (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.02), (math.cos(a), math.sin(a), 0.5), rng.uniform(0.15, 0.3), 0.035)
    d = pc.MeshBuf()
    tr.drift(d, rng, 0.42, 0.4, 0.14, segs=6, rows=2)
    buf.merge(d)
    return buf, maps, {"smooth": False}


def _horn_col(alb, orh):
    """Cow horn: cream running to brown-black at the tip, fine streaks down it."""
    h, w, _ = alb.shape
    rng = np.random.default_rng(2)
    streak = np.cumsum(rng.normal(0, 1, (1, w)), axis=1)
    streak = (streak - streak.min()) / (np.ptp(streak) + 1e-6)
    v = np.linspace(0, 1, h)[:, None]
    base = np.array([0.78, 0.71, 0.56], np.float32) * (0.82 + 0.25 * streak[..., None])
    out = base * (0.9 + 0.1 * np.sin(v * 40)[..., None]) * (0.75 + 0.25 * alb / max(alb.mean(), 1e-3))
    orh = orh.copy()
    orh[..., 1] = 0.38
    return np.clip(out, 0, 1).astype(np.float32), orh


def _horn_maps(name):
    return pc.make_atlas(name, [
        ("leather", _horn_col), ("iron", None), ("peat", pc.tint((0.16, 0.09, 0.04), 0.5, rough=0.15, keep=0.0)),
        ("ice", pc.tint((0.74, 0.84, 0.92), 0.8, rough=0.2))], size=512)


def feast_horn(frozen=False):
    rng = np.random.default_rng(4)
    maps, (horn, iron, ale, ice) = _horn_maps("feast_horn_frozen" if frozen else "feast_horn")
    buf = pc.MeshBuf()
    # a horn cut to stand: the tip sawn off flat, an iron band at the foot
    # and one under the lip, the wall thin at the rim
    out = [(0.024, 0.0), (0.027, 0.02), (0.031, 0.1), (0.038, 0.2), (0.046, 0.29), (0.048, 0.3)]
    inner = [(0.044, 0.3), (0.041, 0.262)]
    pc.lathe(buf, out + inner, 12, horn[0], horn[1], 2.0, squash=(1.0, 0.92))
    pc.lathe(buf, [(0.0, 0.0), (0.024, 0.0)], 12, iron[0], iron[0] + 0.1)            # underside
    for z0, r0, r1 in ((0.012, 0.0285, 0.0295), (0.25, 0.0435, 0.045)):
        pc.lathe(buf, [(r0, z0), (r0 + 0.0035, z0 + 0.003), (r1 + 0.0035, z0 + 0.021), (r1, z0 + 0.024)], 12, iron[0], iron[1], 4.0, squash=(1.0, 0.92))
    if frozen:
        # full and frozen over: the ale has heaved up through the rim
        pc.lathe(buf, [(0.044, 0.292), (0.04, 0.312), (0.026, 0.33), (0.0, 0.338)], 12, ice[0], ice[1], 2.0, squash=(1.0, 0.92))
        for k in range(3):
            a = rng.random() * TAU
            vf_crystal_small(buf, rng, (math.cos(a) * 0.046, math.sin(a) * 0.042, 0.296), ice)
    else:
        pc.lathe(buf, [(0.041, 0.262), (0.0, 0.262)], 12, ale[0], ale[1])
    return buf, maps, {"auto_smooth_deg": 50}


def vf_crystal_small(buf, rng, base, ice):
    """A short icicle off the rim."""
    ln = rng.uniform(0.03, 0.07)
    pc.lathe(buf, [(0.0, -ln), (0.006, -ln * 0.3), (0.008, 0.004)], 5, ice[0], ice[0] + 0.1, 2.0, xf=pc.xform(pos=base))


def trencher():
    rng = np.random.default_rng(6)
    maps, (board, crust, bowl) = pc.make_atlas("trencher", [
        ("planks", pc.tint((0.45, 0.37, 0.27), 1.0)), ("peat", pc.tint((0.42, 0.27, 0.13), 0.9, rough=0.8, keep=0.0)),
        ("timber", pc.tint((0.33, 0.24, 0.16), 0.8, rough=0.5))], size=512)
    buf = pc.MeshBuf()
    pc.box(buf, (0.46, 0.34, 0.03), pc.xform(pos=(0, 0, 0.015), rot_z=0.05), rect(board), uv_per_m=1.2, jitter=0.004, rng=rng)
    # a round rye loaf, flat-bottomed, a cross cut in the crust
    pc.blob(buf, rng, (-0.09, 0.02, 0.062), (0.11, 0.1, 0.05), 12, 6, crust[0], crust[1], 0.0, 0.5, lump=0.06)
    # a turned ash bowl: foot, belly, thin lip, hollow
    prof = [(0.0, 0.0), (0.035, 0.0), (0.04, 0.006), (0.062, 0.03), (0.072, 0.052), (0.068, 0.052), (0.057, 0.03), (0.03, 0.012), (0.0, 0.01)]
    pc.lathe(buf, prof, 14, bowl[0], bowl[1], 3.0, xf=pc.xform(pos=(0.13, -0.04, 0.03)))
    return buf, maps, {"auto_smooth_deg": 50, "bevel": 0.004}


def fat_lamp():
    rng = np.random.default_rng(15)
    maps, (stone, fat, wick) = pc.make_atlas("fat_lamp", [
        ("fieldstone", pc.tint((0.36, 0.38, 0.35), 0.6, rough=0.55)), ("snow", pc.tint((0.78, 0.70, 0.52), 0.5, rough=0.3, keep=0.0)),
        ("rope", pc.tint((0.12, 0.10, 0.08), 0.8))], size=512)
    buf = pc.MeshBuf()
    # an open soapstone lamp: a hollowed oval dish on a low foot, a lip
    # pinched out at one end where the wick lies
    prof = [(0.0, 0.0), (0.05, 0.0), (0.055, 0.008), (0.05, 0.02), (0.085, 0.045), (0.098, 0.07), (0.09, 0.072), (0.078, 0.052), (0.03, 0.03), (0.0, 0.028)]
    pc.lathe(buf, prof, 14, stone[0], stone[1], 3.0, squash=(1.25, 0.9))
    # rendered fat set in the bowl
    pc.lathe(buf, [(0.08, 0.058), (0.04, 0.062), (0.0, 0.063)], 14, fat[0], fat[1], 3.0, squash=(1.25, 0.9))
    # the wick: a peeled rush lying in the fat, its end up over the lip
    pc.tube(buf, [(0.02, 0.0, 0.06), (0.07, 0.004, 0.066), (0.108, 0.006, 0.082), (0.118, 0.006, 0.098)], [0.004, 0.004, 0.0035, 0.003], 4,
            wick[0], wick[0] + 0.1, 6.0)
    return buf, maps, {"auto_smooth_deg": 50}


PIECES = {
    "kit_woodpile_p": woodpile,
    "kit_hearth_logs_p": hearth_logs,
    "kit_salt_pan_p": salt_pan,
    "kit_net_frame_p": net_frame,
    "kit_plaque_p": plaque,
    "kit_door_leaf_p": door_leaf,
    "kit_rime_spike_p": rime_spike,
    "kit_feast_horn_p": feast_horn,
    "kit_feast_horn_frozen_p": lambda: feast_horn(True),
    "kit_trencher_p": trencher,
    "kit_fat_lamp_p": fat_lamp,
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name, fn in PIECES.items():
        if a.only and a.only != name:
            continue
        buf, maps, opts = fn()
        pc.export_glb(os.path.join(OUT, name + ".glb"), name, buf, maps, **opts)


if __name__ == "__main__":
    main()
