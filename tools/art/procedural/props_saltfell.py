#!/usr/bin/env python3
"""Saltfell's own prop set and its points of interest (docs/art/BIOMES.md
"Saltfell"; docs/lore/POI.md 2), the pieces modelled by hand. Each is
authored at its KitLib.PIECES footprint and goes in through
KitLib.HERO_PIECES, so it takes RIME snow and frost like the Tripo pieces.

  kit_sf_brine_trough_p    a hollowed pine log on chocks, salt at the waterline, a scoop
  kit_sf_roller_run_p      six log rollers and two keel blocks laid up the shingle
  kit_sf_oar_rack_p        two posts and pegs holding six oars; thole pins in a bored block
  kit_sf_net_sinkers_p     cords of holed beach stones and bog-iron rings on a peg rail
  kit_sf_kelp_rick_p       kelp laid to dry over a low drystone wall
  kit_sf_salt_pan_split_p  the pan that boiled dry: split bed, scorched salt, ash to the door
  kit_sf_lookout_stone_p   the flat stone on the west headland
  kit_sf_three_bowls_p     three wooden bowls, one inside the next, stew frozen in the top one
  kit_sf_needle_case_p     a net-needle case of horn with a wooden stopper
  kit_sf_thole_pin_p       an ash thole pin
  kit_sf_pan_salt_p        a cake of pan salt, scorched underneath
  kit_sf_turf_spade_p      a turf spade standing in the ground
  kit_sf_small_grave_p     the small grave on the cliff terrace; _open: opened with a spade
  sc_drift_{branch,plank,stump,billet}   small driftwood for the wrack line (assets/models/scatter)

Run: $BPY tools/art/procedural/props_saltfell.py [--only name]
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402
import poi_common as po  # noqa: E402

TAU = math.tau
SALT = ("snow", pc.tint((0.74, 0.73, 0.69), 1.5, rough=0.75, keep=0.0))
PINE = ("timber", pc.tint((0.50, 0.44, 0.36), 1.0))
BLEACHED = ("timber", pc.tint((0.56, 0.54, 0.49), 0.9, rough=0.9))
TARRED = ("timber", pc.tint((0.16, 0.13, 0.11), 1.0, rough=0.6))


def brine_trough():
    rng = np.random.default_rng(301)
    maps, (bark, wood, salt, brine) = pc.make_atlas("sf_brine_trough", [
        ("bark", pc.tint((0.36, 0.31, 0.26), 1.0)), PINE, SALT,
        ("ice", pc.tint((0.30, 0.34, 0.33), 0.5, rough=0.2, keep=0.0))])
    buf = pc.MeshBuf()
    L, R, w = 3.0, 0.31, 0.25
    cz = R + 0.13
    h = math.sqrt(R * R - w * w)
    a0 = math.atan2(h, w)
    n_arc, n_x = 12, 9
    xs = np.linspace(-L / 2, L / 2, n_x)
    wob = [1.0 + 0.04 * math.sin(i * 1.7) for i in range(n_x)]
    # the outside: bark, round, with the top adzed flat
    rows = []
    for i, x in enumerate(xs):
        row = []
        for k in range(n_arc + 1):
            a = a0 - (TAU - (math.pi - 2 * a0)) * k / n_arc
            row.append(buf.vert((x, math.cos(a) * R * wob[i], cz + math.sin(a) * R * wob[i]),
                                (bark[0] + (bark[1] - bark[0]) * k / n_arc, x * 0.8)))
        rows.append(row)
    for i in range(n_x - 1):
        for k in range(n_arc):
            buf.quad(rows[i][k], rows[i + 1][k], rows[i + 1][k + 1], rows[i][k + 1])
    top = cz + h
    # the adzed rim round the basin, and the basin itself
    bw, bl, depth = 0.18, L / 2 - 0.16, 0.24
    def v(x, y, z, col, u=0.5, vv=None):
        return buf.vert((x, y, z), (col[0] + (col[1] - col[0]) * u, x * 0.8 if vv is None else vv))
    for sy in (-1, 1):
        o = [v(x, sy * w * wob[i], top, wood, 0.1) for i, x in enumerate(xs)]
        inn = [v(max(-bl, min(bl, x)), sy * bw, top, wood, 0.4) for x in xs]
        for i in range(n_x - 1):
            if sy > 0:
                buf.quad(o[i], inn[i], inn[i + 1], o[i + 1])
            else:
                buf.quad(o[i], o[i + 1], inn[i + 1], inn[i])
    for sx in (-1, 1):
        a = v(sx * L / 2, -w, top, wood, 0.1, 0.0)
        b = v(sx * L / 2, w, top, wood, 0.9, 0.0)
        c = v(sx * bl, bw, top, wood, 0.8, 0.2)
        d = v(sx * bl, -bw, top, wood, 0.2, 0.2)
        if sx > 0:
            buf.quad(a, d, c, b)
        else:
            buf.quad(a, b, c, d)
    nb = 8
    bx = np.linspace(-bl, bl, 7)
    brows = []
    for x in bx:
        row = []
        for k in range(nb + 1):
            t = math.pi * k / nb
            # salt-white above the waterline, wet wood below it
            col = salt if abs(k - nb / 2) > nb * 0.2 else wood
            row.append(v(x, math.cos(t) * bw, top - math.sin(t) * depth, col, k / nb))
        brows.append(row)
    for i in range(len(bx) - 1):
        for k in range(nb):
            buf.quad(brows[i][k], brows[i][k + 1], brows[i + 1][k + 1], brows[i + 1][k])
    for sx, row in ((-1, brows[0]), (1, brows[-1])):
        c = v(sx * bl, 0, top - depth * 0.4, salt, 0.5, 0.5)
        for k in range(nb):
            if sx < 0:
                buf.tri(c, row[k + 1], row[k])
            else:
                buf.tri(c, row[k], row[k + 1])
    # the brine standing in it
    zb = top - depth * 0.42
    hw = bw * math.sqrt(max(1 - 0.42 ** 2, 0.0))
    q = [v(-bl, -hw, zb, brine, 0.1, 0.0), v(bl, -hw, zb, brine, 0.1, 1.0), v(bl, hw, zb, brine, 0.9, 1.0), v(-bl, hw, zb, brine, 0.9, 0.0)]
    buf.quad(*q)
    # the ends: sawn through
    for sx, i in ((-1, 0), (1, -1)):
        c = v(sx * L / 2, 0, cz, wood, 0.5, 0.5)
        ring = [v(sx * L / 2, math.cos(a0 - (TAU - (math.pi - 2 * a0)) * k / n_arc) * R * wob[i],
                  cz + math.sin(a0 - (TAU - (math.pi - 2 * a0)) * k / n_arc) * R * wob[i], wood,
                  0.5 + 0.4 * math.cos(k), 0.5 + 0.1 * math.sin(k)) for k in range(n_arc + 1)]
        for k in range(n_arc):
            if sx > 0:
                buf.tri(c, ring[k + 1], ring[k])
            else:
                buf.tri(c, ring[k], ring[k + 1])
        if sx > 0:
            buf.tri(c, ring[0], ring[-1])
        else:
            buf.tri(c, ring[-1], ring[0])
    # two chocks under it and a scoop left on the rim
    for x in (-1.0, 1.0):
        po.log(buf, rng, (x, -0.42, 0.1), (x + rng.normal(0, 0.03), 0.42, 0.1), 0.11, bark, wood)
    sx0 = 0.55
    pc.lathe(buf, [(0.0, 0.0), (0.07, 0.01), (0.085, 0.07), (0.075, 0.07), (0.06, 0.02), (0.0, 0.015)], 9, wood[0], wood[1], 1.5,
             xf=pc.xform(pos=(sx0, 0.02, top + 0.0), rot_x=0.08))
    po.pole(buf, rng, [(sx0 + 0.07, 0.02, top + 0.06), (sx0 + 0.36, 0.1, top + 0.03)], 0.014, 0.012, wood, sides=5)
    return buf, maps, {}


def roller_run():
    rng = np.random.default_rng(302)
    maps, (bark, wood, tar) = pc.make_atlas("sf_roller_run", [
        ("bark", pc.tint((0.40, 0.37, 0.33), 0.9)), BLEACHED, TARRED])
    buf = pc.MeshBuf()
    for i in range(6):
        y = -2.5 + i * 1.0 + rng.normal(0, 0.05)
        sk = rng.normal(0, 0.06)
        r = rng.uniform(0.075, 0.095)
        ln = rng.uniform(1.5, 1.75)
        x0 = rng.normal(0, 0.06)
        # worn pale in the middle, where the keel runs
        po.log(buf, rng, (x0 - ln / 2, y - sk, r * 0.92), (x0 + ln / 2, y + sk, r * 0.92), r, wood, wood, sides=9, wobble=0.02)
    for y in (-2.0, 1.5):
        # keel blocks: a notched baulk the keel sits in
        for sx in (-1, 1):
            po.board(buf, rng, (0.2, 0.34, 0.2), (sx * 0.17, y, 0.1), tar, rot_y=sx * 0.12, jitter=0.01)
        po.board(buf, rng, (0.62, 0.3, 0.07), (0, y, 0.035), bark, jitter=0.008)
    return buf, maps, {"auto_smooth_deg": 40}


def oar(buf, rng, grip, d, wood, length=2.9):
    """An oar from its grip end along unit d: loom, then a narrow blade."""
    grip, d = np.asarray(grip, float), np.asarray(d, float)
    d = d / np.linalg.norm(d)
    loom = length * 0.7
    pts = [grip + d * t for t in (0.0, 0.12, loom * 0.5, loom)]
    po.pole(buf, rng, pts, 0.021, 0.024, wood, sides=6)
    rz = math.atan2(d[1], d[0])
    ry = -math.asin(max(-1.0, min(1.0, d[2])))
    c = grip + d * (loom + (length - loom) * 0.5)
    po.board(buf, rng, (length - loom, 0.018, 0.12), c, wood, rot_z=rz, rot_y=ry, jitter=0.004)


def oar_rack():
    rng = np.random.default_rng(303)
    maps, (bark, wood, pale) = pc.make_atlas("sf_oar_rack", [
        ("bark", pc.tint((0.36, 0.33, 0.29), 0.9)), PINE, BLEACHED])
    buf = pc.MeshBuf()
    levels = (0.75, 1.15, 1.55)
    for sx in (-1.05, 1.05):
        po.pole(buf, rng, [(sx, 0, -0.1), (sx + rng.normal(0, 0.01), 0, 1.0), (sx + rng.normal(0, 0.015), 0, 1.95)], 0.065, 0.05, bark, sides=8)
        for z in levels:
            # a peg through the post, standing out both sides and tipped up
            po.pole(buf, rng, [(sx, -0.3, z + 0.05), (sx, 0, z), (sx, 0.3, z + 0.05)], 0.018, 0.018, wood, sides=5)
    k = 0
    for z in levels:
        for sy in (-1, 1):
            x0 = -1.5 + rng.uniform(-0.12, 0.12)
            dirn = 1 if k % 2 == 0 else -1
            g = (x0 if dirn > 0 else -x0, sy * rng.uniform(0.1, 0.2), z + 0.045 + rng.uniform(0, 0.012))
            oar(buf, rng, g, (dirn, rng.normal(0, 0.01), rng.normal(0, 0.006)), pale if k % 3 else wood)
            k += 1
    # the bored block of spare thole pins at the foot
    po.board(buf, rng, (0.5, 0.16, 0.13), (-0.2, 0.34, 0.065), wood, rot_z=0.2, jitter=0.008)
    for i in range(5):
        px = -0.2 + (i - 2) * 0.09
        py = 0.34 + (i - 2) * 0.09 * math.tan(0.2)
        po.pole(buf, rng, [(px, py, 0.1), (px + rng.normal(0, 0.006), py, 0.3)], 0.014, 0.011, pale, sides=5)
    return buf, maps, {"auto_smooth_deg": 40}


def net_sinkers():
    rng = np.random.default_rng(304)
    maps, (wood, stone, iron, cord) = pc.make_atlas("sf_net_sinkers", [
        BLEACHED, ("shingle", pc.tint((0.45, 0.44, 0.41), 1.0)),
        ("iron", pc.tint((0.24, 0.15, 0.11), 1.0, rough=0.85)), ("rope", None)])
    buf = pc.MeshBuf()
    for sx in (-0.82, 0.82):
        po.pole(buf, rng, [(sx, 0, -0.1), (sx + rng.normal(0, 0.012), 0, 0.7), (sx, 0, 1.32)], 0.045, 0.036, wood, sides=7)
    po.board(buf, rng, (1.86, 0.035, 0.12), (0, -0.05, 1.18), wood, jitter=0.006)
    for i in range(7):
        x = -0.75 + i * 0.25
        po.pole(buf, rng, [(x, -0.06, 1.18), (x, -0.17, 1.21)], 0.013, 0.011, wood, sides=5)
        # a cord off each peg: holed stones, or rings of bog-iron
        y = -0.15
        n = int(rng.integers(3, 6))
        zz = 1.19
        irons = i in (1, 4, 6)
        top = zz
        for j in range(n):
            if irons:
                r = rng.uniform(0.04, 0.055)
                zz -= r * 1.7
                po.ring(buf, rng, (x, y, zz), r, 0.011, iron, axis="y" if j % 2 else "x")
            else:
                r = rng.uniform(0.04, 0.065)
                zz -= r * 1.9
                po.stone(buf, rng, (x + rng.normal(0, 0.008), y, zz), (r, r * rng.uniform(0.45, 0.7), r * rng.uniform(0.8, 1.0)), stone, segs=7, rings=4)
        po.pole(buf, rng, [(x, y, top), (x, y, zz - 0.05)], 0.006, 0.006, cord, sides=4)
    # a heap of sinkers waiting at the foot
    for _ in range(7):
        r = rng.uniform(0.05, 0.08)
        po.stone(buf, rng, (rng.uniform(-0.5, 0.3), rng.uniform(0.05, 0.3), r * 0.5), (r, r * 0.8, r * 0.55), stone, segs=7, rings=4)
    return buf, maps, {}


def kelp_rick():
    rng = np.random.default_rng(305)
    maps, (stone, kelp, kelp2) = pc.make_atlas("sf_kelp_rick", [
        ("drystone", None),
        ("leather", pc.tint((0.17, 0.15, 0.07), 1.2, rough=0.5, keep=0.1)),
        ("leather", pc.tint((0.27, 0.19, 0.08), 1.2, rough=0.6, keep=0.1))])
    buf = pc.MeshBuf()
    H, D = 0.72, 0.5
    po.drystone(buf, rng, 3.0, H, D, stone, course=0.19)
    # fronds laid over the top, hanging down both faces
    n = 30
    for i in range(n):
        x = -1.4 + 2.8 * (i + rng.uniform(-0.3, 0.3)) / (n - 1)
        col = kelp if rng.random() < 0.65 else kelp2
        f, b = rng.uniform(0.25, 0.62), rng.uniform(0.2, 0.6)
        dx = rng.normal(0, 0.06)
        pts = [(x - dx, -D / 2 - 0.05, H - f), (x - dx * 0.5, -D / 2 - 0.03, H - f * 0.4), (x, -D * 0.3, H + 0.035 + rng.uniform(0, 0.03)),
               (x, D * 0.3, H + 0.035 + rng.uniform(0, 0.03)), (x + dx * 0.5, D / 2 + 0.03, H - b * 0.4), (x + dx, D / 2 + 0.05, H - b)]
        r = rng.uniform(0.045, 0.085)
        span = (col[1] - col[0]) * 0.5
        u0 = col[0] + rng.random() * ((col[1] - col[0]) - span)
        # a flat strap: wide across the wall's length, a finger thick
        pc.tube(buf, pts, [r * 0.6, r, r, r, r, r * 0.5], 6, u0, u0 + span, 1.2, v0=rng.random(), squash=[(0.2, 1.0)] * 6)
    return buf, maps, {"auto_smooth_deg": 50}


def salt_pan_split():
    """The salt pan's footprint (kit_props.salt_pan), boiled dry: the clay bed
    split along its length, the salt scorched, the firebox packed with ash."""
    rng = np.random.default_rng(23)
    maps, (stone, clay, salt, ash, char) = pc.make_atlas("sf_salt_pan_split", [
        ("fieldstone", None), ("peat", pc.tint((0.26, 0.20, 0.16), 1.0)),
        ("snow", pc.tint((0.52, 0.42, 0.31), 1.6, rough=0.8, keep=0.0)),
        ("snow", pc.tint((0.42, 0.40, 0.38), 1.6, rough=0.95, keep=0.0)),
        ("bark", pc.tint((0.07, 0.065, 0.06), 1.2, rough=0.9, keep=0.1))])
    buf = pc.MeshBuf()

    def kerb(x0, x1, y, along_x, gap=None):
        x = x0
        while x < x1 - 0.05:
            w = min(rng.uniform(0.28, 0.5), x1 - x)
            h = rng.uniform(0.36, 0.47)
            t = rng.uniform(0.14, 0.2)
            c = (x + w / 2, y, h / 2 - 0.03) if along_x else (y, x + w / 2, h / 2 - 0.03)
            size = (w * 0.97, t, h) if along_x else (t, w * 0.97, h)
            if gap is None or not (gap[0] < x + w / 2 < gap[1]):
                pc.box(buf, size, pc.xform(pos=c, rot_z=rng.normal(0, 0.04), rot_x=rng.normal(0, 0.05)), po.rect(stone), uv_per_m=0.55, jitter=0.012, rng=rng)
            x += w
    for y in (-0.91, 0.91):
        kerb(-1.5, 1.5, y, True)
    kerb(-0.82, 0.82, 1.41, False)
    kerb(-0.82, 0.82, -1.41, False, gap=(-0.3, 0.3))      # the firebox door
    nx, ny = 18, 10
    for col, z0, lump, inset in ((clay, 0.2, 0.01, 0.0), (salt, 0.232, 0.02, 0.2)):
        grid = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                u, v = i / nx, j / ny
                x = (u - 0.5) * (2.7 - inset * 2)
                y = (v - 0.5) * (1.7 - inset * 2)
                # the split: a wandering crack down the length, the bed sagging into it
                crack = abs(y - 0.12 * math.sin(x * 2.3) - 0.05 * math.sin(x * 7.1))
                z = z0 + lump * math.sin(u * 23 + v * 7) * math.sin(v * 17 + 1) - (0.26 if inset else 0.1) * math.exp(-(crack / 0.1) ** 2) * (1.0 if abs(x) < 1.15 else 0.3)
                row.append(buf.vert((x, y, z), (col[0] + (col[1] - col[0]) * u, v * 0.9)))
            grid.append(row)
        for j in range(ny):
            for i in range(nx):
                buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
    # ash packed to the door and spilling out of it; burnt ends in the ash
    seg, rings = 12, 4
    grid = []
    for j in range(rings + 1):
        fr = j / rings
        row = []
        for k in range(seg + 1):
            a = TAU * (k % seg) / seg
            r = 0.52 * fr * (1 + 0.15 * math.sin(a * 3 + 1))
            row.append(buf.vert((-1.52 + math.cos(a) * r * 0.75, math.sin(a) * r, 0.3 * (1 - fr ** 1.6) - 0.01),
                                (ash[0] + (ash[1] - ash[0]) * (0.5 + 0.45 * math.cos(a) * fr), 0.5 + 0.3 * math.sin(a) * fr)))
        grid.append(row)
    for j in range(rings):
        for k in range(seg):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    for _ in range(4):
        a = rng.uniform(1.9, 4.4)
        d = np.array([math.cos(a), math.sin(a), 0.0])
        p0 = np.array([-1.5, 0, 0.12]) + d * 0.15
        po.log(buf, rng, p0, p0 + d * rng.uniform(0.3, 0.5) + np.array([0, 0, -0.06]), 0.045, char, char, sides=6)
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.012}


def lookout_stone():
    rng = np.random.default_rng(306)
    maps, (rock, lichen) = pc.make_atlas("sf_lookout_stone", [
        ("schist", pc.tint((0.36, 0.38, 0.35), 1.0)), ("schist", pc.tint((0.52, 0.42, 0.22), 0.8))])
    buf = pc.MeshBuf()
    # one bed of schist, flat on top, worn round at the front edge
    seg, rings = 18, 6
    grid = []
    for j in range(rings + 1):
        t = j / rings
        row = []
        for k in range(seg + 1):
            a = TAU * (k % seg) / seg
            prof = [(0.86, 0.0), (1.0, 0.08), (1.0, 0.3), (0.96, 0.4), (0.8, 0.44), (0.4, 0.45), (0.0, 0.45)][j]
            w = 1.0 + 0.07 * math.sin(a * 3 + 0.6) + 0.05 * math.sin(a * 5 + 2.0)
            x = math.cos(a) * 0.95 * prof[0] * w
            y = math.sin(a) * 0.62 * prof[0] * w
            z = prof[1] + (0.012 * math.sin(x * 9) * math.sin(y * 7) if j >= 4 else 0.0) - 0.06
            col = lichen if (j >= 3 and math.sin(a * 2 + 1) > 0.55) else rock
            row.append(buf.vert((x, y, z), (col[0] + (col[1] - col[0]) * (0.5 + 0.48 * math.cos(a) * prof[0]), 0.5 + 0.45 * math.sin(a) * prof[0] + t * 0.2)))
        grid.append(row)
    for j in range(rings):
        for k in range(seg):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    return buf, maps, {"auto_smooth_deg": 45}


def three_bowls():
    rng = np.random.default_rng(307)
    maps, (wood, dark, stew) = pc.make_atlas("sf_three_bowls", [
        ("timber", pc.tint((0.48, 0.36, 0.24), 0.8)), ("timber", pc.tint((0.30, 0.22, 0.15), 0.8)),
        ("ice", pc.tint((0.50, 0.44, 0.34), 0.6, rough=0.3, keep=0.0))], size=512)
    buf = pc.MeshBuf()
    for i, (r, z0) in enumerate(((0.15, 0.0), (0.138, 0.034), (0.126, 0.068))):
        col = wood if i != 1 else dark
        prof = [(0.0, z0), (r * 0.45, z0), (r * 0.8, z0 + 0.03), (r, z0 + 0.085), (r - 0.008, z0 + 0.085),
                (r * 0.76, z0 + 0.036), (r * 0.4, z0 + 0.012), (0.0, z0 + 0.012)]
        pc.lathe(buf, prof, 16, col[0], col[1], 2.0, xf=pc.xform(pos=(rng.normal(0, 0.003), rng.normal(0, 0.003), 0), rot_z=rng.random()))
    # the stew in the top bowl, frozen with the spoon-mark still in it
    zt = 0.068 + 0.06
    c = buf.vert((0, 0, zt + 0.004), ((stew[0] + stew[1]) / 2, 0.5))
    ring = [buf.vert((math.cos(TAU * k / 14) * 0.105, math.sin(TAU * k / 14) * 0.105, zt + 0.006 * math.sin(k * 2.1)),
                     ((stew[0] + stew[1]) / 2 + (stew[1] - stew[0]) * 0.45 * math.cos(TAU * k / 14), 0.5 + 0.2 * math.sin(TAU * k / 14))) for k in range(15)]
    for k in range(14):
        buf.tri(c, ring[k], ring[k + 1])
    return buf, maps, {}


def needle_case():
    rng = np.random.default_rng(308)
    maps, (horn, wood) = pc.make_atlas("sf_needle_case", [
        ("timber", pc.tint((0.70, 0.64, 0.50), 0.4, rough=0.45)), ("timber", pc.tint((0.38, 0.28, 0.2), 0.8))], size=256)
    buf = pc.MeshBuf()
    # lying on its side along X
    pc.lathe(buf, [(0.0, 0.0), (0.016, 0.0), (0.02, 0.02), (0.02, 0.2), (0.017, 0.22), (0.0, 0.22)], 9, horn[0], horn[1], 3.0,
             xf=pc.xform(pos=(-0.13, 0, 0.02), rot_y=math.pi / 2))
    pc.lathe(buf, [(0.0, 0.0), (0.014, 0.0), (0.015, 0.03), (0.0, 0.034)], 7, wood[0], wood[1], 3.0,
             xf=pc.xform(pos=(0.09, 0, 0.02), rot_y=math.pi / 2))
    po.pole(buf, rng, [(-0.1, 0.0, 0.04), (-0.12, 0.05, 0.005), (-0.02, 0.09, 0.004), (0.06, 0.05, 0.004)], 0.003, 0.003, wood, sides=4)
    return buf, maps, {}


def thole_pin():
    rng = np.random.default_rng(309)
    maps, (ash, _) = pc.make_atlas("sf_thole_pin", [("timber", pc.tint((0.62, 0.55, 0.42), 0.8)),
                                                   ("timber", pc.tint((0.5, 0.44, 0.34), 0.8))], size=256)
    buf = pc.MeshBuf()
    # whittled: a peg with a shoulder, lying in the shingle at a slant
    pc.lathe(buf, [(0.0, 0.0), (0.012, 0.0), (0.016, 0.08), (0.022, 0.09), (0.021, 0.2), (0.017, 0.235), (0.0, 0.24)], 8, ash[0], ash[1], 3.0,
             xf=pc.xform(pos=(-0.1, 0, 0.028), rot_y=math.pi / 2 - 0.25, rot_z=0.4))
    return buf, maps, {}


def pan_salt():
    rng = np.random.default_rng(310)
    maps, (salt, burnt) = pc.make_atlas("sf_pan_salt", [
        ("snow", pc.tint((0.66, 0.65, 0.62), 1.6, rough=0.8, keep=0.0)),
        ("snow", pc.tint((0.33, 0.22, 0.13), 1.6, rough=0.85, keep=0.0))], size=512)
    buf = pc.MeshBuf()
    # loaf-sized: grey above, scorched brown where it sat on the iron
    seg, rings = 12, 6
    grid = []
    for j in range(rings + 1):
        lat = math.pi * (j / rings - 0.5)
        row = []
        for k in range(seg + 1):
            lon = TAU * (k % seg) / seg
            w = 1.0 + 0.1 * math.sin(lon * 3 + 1) * math.cos(lat * 2) + 0.06 * math.sin(lon * 5)
            z = 0.07 + math.sin(lat) * 0.07 * (1.0 if lat > 0 else 0.55)
            col = burnt if j <= 2 else salt
            row.append(buf.vert((math.cos(lat) * math.cos(lon) * 0.17 * w, math.cos(lat) * math.sin(lon) * 0.11 * w, z - 0.03),
                                (col[0] + (col[1] - col[0]) * k / seg, j / rings)))
        grid.append(row)
    for j in range(rings):
        for k in range(seg):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    return buf, maps, {}


def turf_spade():
    rng = np.random.default_rng(311)
    maps, (ash, iron) = pc.make_atlas("sf_turf_spade", [
        ("timber", pc.tint((0.50, 0.42, 0.31), 0.9)), ("iron", pc.tint((0.2, 0.17, 0.15), 1.0, rough=0.6))], size=512)
    buf = pc.MeshBuf()
    # stood in the turf, leaning a little: blade a hand deep in the ground
    lean = 0.12
    top = np.array([math.sin(lean) * 1.25, 0, 0.12 + math.cos(lean) * 1.25])
    po.pole(buf, rng, [(0, 0, 0.12), tuple(top * 0.5 + np.array([0, 0, 0.06])), tuple(top)], 0.02, 0.018, ash, sides=6)
    po.pole(buf, rng, [tuple(top + np.array([0, -0.11, 0])), tuple(top), tuple(top + np.array([0, 0.11, 0]))], 0.016, 0.016, ash, sides=5)
    po.board(buf, rng, (0.012, 0.15, 0.3), (-0.012, 0, 0.02), iron, rot_y=-lean, jitter=0.002)
    po.board(buf, rng, (0.012, 0.07, 0.1), (0.0, 0.1, 0.16), iron, rot_y=-lean, jitter=0.002)   # the side wing that cuts the sod's edge
    return buf, maps, {"auto_smooth_deg": 40}


def small_grave(opened=False):
    """The small grave on the cliff terrace. Closed: a child-length mound of
    turf with a head stone and a bunch of thrift. Opened: the turf lifted off
    (it lies to one side as lw_sod_row), a neat cut, the spoil in one heap."""
    rng = np.random.default_rng(312)
    maps, (turf, peat, stone, thrift) = pc.make_atlas("sf_small_grave", [
        ("turf", None), ("peat", pc.tint((0.15, 0.12, 0.10), 1.0)), ("schist", pc.tint((0.40, 0.41, 0.38), 1.0)),
        ("wool", pc.tint((0.72, 0.42, 0.50), 0.8, keep=0.0))])
    buf = pc.MeshBuf()
    L, W = 1.15, 0.6
    seg, rings = 16, 5
    grid = []
    for j in range(rings + 1):
        fr = j / rings
        row = []
        for k in range(seg + 1):
            a = TAU * (k % seg) / seg
            if opened:
                # a kerb of cut peat round a dark floor: the cut is square and clean
                r = 1.0 - 0.38 * fr
                z = (0.1 * math.sin(min(fr * 3.2, math.pi))) if fr < 0.7 else -0.02
                col = peat
            else:
                r = 1.0 - fr
                z = 0.24 * (1 - (1 - fr) ** 2) * (1 + 0.08 * math.sin(a * 3))
                col = turf
            sq = max(abs(math.cos(a)), abs(math.sin(a))) if opened else 1.0
            x = math.cos(a) * L * 0.5 * r / sq * (1.12 if opened else 1.0)
            y = math.sin(a) * W * 0.5 * r / sq * (1.2 if opened else 1.0)
            row.append(buf.vert((x, y, z - 0.02), (col[0] + (col[1] - col[0]) * (0.5 + 0.45 * math.cos(a) * r), 0.5 + 0.4 * math.sin(a) * r)))
        grid.append(row)
    for j in range(rings):
        for k in range(seg):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    if opened:
        c = buf.vert((0, 0, -0.02), ((peat[0] + peat[1]) / 2, 0.5))
        for k in range(seg):
            buf.tri(c, grid[-1][k], grid[-1][k + 1])
        # the spoil, in one heap at the foot
        for _ in range(9):
            r = rng.uniform(0.09, 0.17)
            po.stone(buf, rng, (L * 0.5 + 0.32 + rng.normal(0, 0.14), rng.normal(0, 0.2), r * 0.45), (r, r * 0.9, r * 0.6), peat, lump=0.2)
    else:
        # thrift, picked today and laid on the turf
        for i in range(7):
            px, py = 0.12 + rng.normal(0, 0.05), rng.normal(0, 0.05)
            po.pole(buf, rng, [(px - 0.14, py + rng.normal(0, 0.03), 0.235), (px, py, 0.25)], 0.004, 0.004, turf, sides=4)
            po.stone(buf, rng, (px + 0.01, py, 0.26), (0.02, 0.02, 0.016), thrift, segs=6, rings=4)
    # the head stone: a beach slab on edge, no mark on it
    pc.box(buf, (0.3, 0.07, 0.42), pc.xform(pos=(-L * 0.5 - 0.1, 0, 0.17), rot_z=math.pi / 2 + 0.05, rot_x=0.06), po.rect(stone),
           uv_per_m=0.6, jitter=0.02, rng=rng)
    return buf, maps, {"auto_smooth_deg": 50}


DRIFT = [("timber", pc.tint((0.60, 0.58, 0.54), 0.8, rough=0.92)), ("timber", pc.tint((0.48, 0.45, 0.41), 0.9, rough=0.92)),
         ("bark", pc.tint((0.5, 0.48, 0.44), 0.6, rough=0.95))]


def _limb(buf, rng, pts, r0, r1, col, sides=7):
    """A sea-worn limb: round, tapering, both ends rubbed blunt."""
    pts = [np.asarray(p, float) for p in pts]
    n = len(pts)
    rad = [(r0 + (r1 - r0) * i / (n - 1)) * rng.uniform(0.9, 1.1) for i in range(n)]
    rad[0] *= 0.7
    span = (col[1] - col[0]) * 0.6
    u0 = col[0] + rng.random() * ((col[1] - col[0]) - span)
    pc.tube(buf, pts, rad, sides, u0, u0 + span, 1.4, v0=rng.random())
    d = pts[0] - pts[1]
    po.disc(buf, pts[0], d / np.linalg.norm(d), rad[0], sides, col, rng)


def drift(kind):
    """Driftwood for the wrack line, small (the Tripo log beside these is the
    big one): a forked branch, a broken strake, a root stump, a short billet."""
    rng = np.random.default_rng({"branch": 321, "plank": 322, "stump": 323, "billet": 324}[kind])
    maps, (pale, grey, worn) = pc.make_atlas("sc_drift", DRIFT)
    buf = pc.MeshBuf()
    if kind == "branch":
        _limb(buf, rng, [(-0.7, 0, 0.06), (-0.3, 0.03, 0.07), (0.1, -0.02, 0.08), (0.45, 0.02, 0.07)], 0.06, 0.04, pale)
        _limb(buf, rng, [(0.1, -0.02, 0.08), (0.35, -0.2, 0.1), (0.62, -0.34, 0.16)], 0.035, 0.02, pale, sides=6)
        _limb(buf, rng, [(-0.25, 0.03, 0.07), (-0.1, 0.2, 0.12), (0.05, 0.3, 0.2)], 0.028, 0.015, grey, sides=5)
    elif kind == "plank":
        # a length of strake off some boat, one end split, the rivet holes still in it
        pc.box(buf, (1.25, 0.17, 0.028), pc.xform(pos=(0, 0, 0.03), rot_y=0.03, rot_x=0.06), po.rect(grey), uv_per_m=0.7, jitter=0.012, rng=rng)
        pc.box(buf, (0.34, 0.07, 0.026), pc.xform(pos=(0.74, 0.05, 0.03), rot_z=0.12), po.rect(pale), uv_per_m=0.7, jitter=0.01, rng=rng)
    elif kind == "stump":
        pc.lathe(buf, [(0.0, 0.0), (0.2, 0.0), (0.17, 0.12), (0.13, 0.3), (0.11, 0.42), (0.0, 0.45)], 9, worn[0], worn[1], 1.2,
                 xf=pc.xform(pos=(0, 0, 0.16), rot_y=1.2), squash=(1.0, 0.85))
        for k in range(5):
            a = TAU * k / 5 + rng.normal(0, 0.2)
            c = np.array([-0.18, 0, 0.16])
            e = c + np.array([-0.25 + rng.normal(0, 0.05), math.cos(a) * 0.3, math.sin(a) * 0.22 + 0.04])
            _limb(buf, rng, [tuple(c), tuple((c + e) / 2 + rng.normal(0, 0.03, 3)), tuple(e)], 0.05, 0.02, pale, sides=5)
    else:
        _limb(buf, rng, [(-0.4, 0, 0.09), (-0.1, 0.02, 0.1), (0.2, -0.01, 0.1), (0.42, 0.0, 0.09)], 0.085, 0.075, grey, sides=8)
    return buf, maps, {}


PIECES = {
    "kit_sf_brine_trough_p": brine_trough,
    "kit_sf_roller_run_p": roller_run,
    "kit_sf_oar_rack_p": oar_rack,
    "kit_sf_net_sinkers_p": net_sinkers,
    "kit_sf_kelp_rick_p": kelp_rick,
    "kit_sf_salt_pan_split_p": salt_pan_split,
    "kit_sf_lookout_stone_p": lookout_stone,
    "kit_sf_three_bowls_p": three_bowls,
    "kit_sf_needle_case_p": needle_case,
    "kit_sf_thole_pin_p": thole_pin,
    "kit_sf_pan_salt_p": pan_salt,
    "kit_sf_turf_spade_p": turf_spade,
    "kit_sf_small_grave_p": small_grave,
    "kit_sf_small_grave_open_p": lambda: small_grave(True),
    "sc_drift_branch": lambda: drift("branch"),
    "sc_drift_plank": lambda: drift("plank"),
    "sc_drift_stump": lambda: drift("stump"),
    "sc_drift_billet": lambda: drift("billet"),
}

if __name__ == "__main__":
    po.run(PIECES, None)
