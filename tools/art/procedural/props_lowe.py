#!/usr/bin/env python3
"""The Lowe's own prop set and its points of interest (docs/art/BIOMES.md
"The Lowe"; docs/lore/POI.md 3), the pieces modelled by hand. Each is
authored at its KitLib.PIECES footprint and goes in through
KitLib.HERO_PIECES.

  kit_lw_sod_row_p         lifted sods laid in a row, grass up, the cut strip beside them
  kit_lw_peat_stack_p      cut peats stacked herringbone to dry, round-topped, 1.4 m
  kit_lw_peat_wall_p       the same stacked to a straight wall, 2 m
  kit_lw_peat_row_p        the first drying: peats footed on end along the bank
  kit_lw_spade_rack_p      a rail with four peat spades and a turf knife
  kit_lw_heather_bunch_p   one tied bunch of heather; _heap: sixty of them at a barrow door
  kit_lw_bread_cloth_p     a cloth on the turf with crumbs on it
  kit_lw_birch_cup_p       a small birch cup, upside down
  kit_lw_spade_iron_p      a spade blade with no handle, one face ground bright
  kit_lw_edging_stone_p    the smith's edging stone
  kit_lw_small_spades_p    two child-sized turf spades by a door; _three: with the full-size one
  kit_lw_dinner_cloth_p    a dinner tied in a cloth
  kit_lw_mound_steps_p     sod steps up a kin-mound's shoulder

Run: $BPY tools/art/procedural/props_lowe.py [--only name]
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402
import poi_common as po  # noqa: E402

TAU = math.tau
PEAT = ("peat", pc.tint((0.13, 0.10, 0.085), 1.1, rough=0.95))
PEAT_DRY = ("peat", pc.tint((0.24, 0.18, 0.13), 1.1, rough=0.97))
TURF = ("turf", None)


def sod_row():
    rng = np.random.default_rng(401)
    maps, (turf, peat) = pc.make_atlas("lw_sod_row", [TURF, PEAT])
    buf = pc.MeshBuf()
    n = 7
    for i in range(n):
        # in the order they came off: each a spade wide, edge to edge
        x = -1.2 + i * 0.4
        po.sod(buf, rng, (x + rng.normal(0, 0.012), 0.34 + rng.normal(0, 0.015), 0.07), (0.38, 0.5, 0.14), turf, peat, rot_z=rng.normal(0, 0.04))
    # the cut strip they came from: bare black peat, a spade's depth of edge
    pc.box(buf, (2.8, 0.52, 0.05), pc.xform(pos=(0, -0.3, 0.0)), po.rect(peat), uv_per_m=0.5, jitter=0.01, rng=rng)
    return buf, maps, {"auto_smooth_deg": 45, "bevel": 0.01}


def _peat(buf, rng, pos, rot_z, cols, size=(0.36, 0.15, 0.095), rot_x=0.0, rot_y=0.0):
    """One cut peat: a brick a spade long, never square, darker where it is still wet."""
    col = cols[0] if rng.random() < 0.6 else cols[1]
    sz = (size[0] * rng.uniform(0.85, 1.1), size[1] * rng.uniform(0.85, 1.1), size[2] * rng.uniform(0.85, 1.1))
    pc.box(buf, sz, pc.xform(pos=pos, rot_z=rot_z + rng.normal(0, 0.07), rot_x=rot_x + rng.normal(0, 0.05), rot_y=rot_y + rng.normal(0, 0.05)),
           po.rect(col), uv_per_m=1.1, jitter=0.012, rng=rng)


def _courses(buf, rng, cols, length, depth, height, round_top=True, herring=0.5):
    """Peats laid herringbone: each course leans the other way from the one under it."""
    z = 0.05
    k = 0
    ch = 0.1
    while z < height:
        fr = z / height
        # the stack draws in toward the top so the rain runs off it
        inset = (0.5 * fr ** 2.2 if round_top else 0.08 * fr)
        hl, hd = length * 0.5 * (1 - inset * 0.7), depth * 0.5 * (1 - inset)
        lean = herring * (1 if k % 2 == 0 else -1)
        step = 0.17
        n = max(1, int(hl * 2 / step))
        for sy in (-1, 1):
            for i in range(n):
                x = -hl + (i + 0.5) * (hl * 2 / n) + (0.04 if k % 2 else -0.04)
                _peat(buf, rng, (x, sy * max(hd - 0.16, 0.0), z), math.pi / 2 + lean * sy, cols)
        if hd > 0.34:
            for i in range(max(1, n // 2)):      # the heart of the stack, laid flat
                x = -hl + (i + 0.5) * (hl * 2 / max(1, n // 2))
                _peat(buf, rng, (x, 0, z), rng.normal(0, 0.3), cols)
        for sx in (-1, 1):                       # the ends, headers out
            _peat(buf, rng, (sx * (hl - 0.02), 0, z), lean * 0.4, cols)
        z += ch
        k += 1
    return z


PEAT_COLS = [PEAT, PEAT_DRY, ("peat", pc.tint((0.19, 0.145, 0.11), 1.1, rough=0.96))]


def peat_stack():
    """The round-topped drying stack, 1.4 m: the Lowe's skyline (scatter kind peat_stack)."""
    rng = np.random.default_rng(402)
    maps, (wet, dry, mid) = pc.make_atlas("lw_peat_stack", PEAT_COLS)
    buf = pc.MeshBuf()
    top = _courses(buf, rng, (mid, dry), 1.5, 1.05, 1.3)
    for i in range(4):       # the cap: peats laid along the ridge
        _peat(buf, rng, (-0.45 + i * 0.3, 0, top), 0.0, (dry, mid))
    return buf, maps, {"auto_smooth_deg": 40}


def peat_wall():
    """Stacked to a straight wall, 2 m long: the lip of a cutting, the side of a yard."""
    rng = np.random.default_rng(403)
    maps, (wet, dry, mid) = pc.make_atlas("lw_peat_wall", PEAT_COLS)
    buf = pc.MeshBuf()
    _courses(buf, rng, (mid, dry), 2.05, 0.62, 1.2, round_top=False, herring=0.35)
    return buf, maps, {"auto_smooth_deg": 40}


def peat_row():
    """The first drying: peats footed on end in threes along the bank, still black."""
    rng = np.random.default_rng(404)
    maps, (wet, dry, mid) = pc.make_atlas("lw_peat_row", PEAT_COLS)
    buf = pc.MeshBuf()
    for i in range(7):
        cx = -0.95 + i * 0.32 + rng.normal(0, 0.02)
        cy = rng.normal(0, 0.03)
        for k in range(3):
            a = TAU * k / 3 + rng.normal(0, 0.2)
            # leaned together at the top, feet apart
            _peat(buf, rng, (cx + math.cos(a) * 0.07, cy + math.sin(a) * 0.07, 0.16), a, (wet, mid), rot_y=math.pi / 2 - 0.3)
        if rng.random() < 0.6:
            _peat(buf, rng, (cx, cy, 0.36), rng.random() * TAU, (wet, mid))
    return buf, maps, {"auto_smooth_deg": 40}


def _spade(buf, rng, foot, top, ash, iron, blade_w=0.15, blade_l=0.3, grip=0.11, wing=True):
    """A turf spade from the blade's tip (foot) to the T-grip (top)."""
    foot, top = np.asarray(foot, float), np.asarray(top, float)
    d = (top - foot) / np.linalg.norm(top - foot)
    neck = foot + d * blade_l
    po.pole(buf, rng, [tuple(neck - d * 0.05), tuple((neck + top) / 2 + rng.normal(0, 0.004, 3)), tuple(top)], 0.02, 0.017, ash, sides=6)
    side = np.cross(d, [0, 1, 0])
    side = side / np.linalg.norm(side) if np.linalg.norm(side) > 0.1 else np.array([1.0, 0, 0])
    po.pole(buf, rng, [tuple(top - side * grip), tuple(top), tuple(top + side * grip)], 0.015, 0.015, ash, sides=5)
    # the blade: flat to the rack, its face across `side`
    rz = math.atan2(side[1], side[0])
    ry = -math.asin(max(-1.0, min(1.0, side[2])))
    tilt = math.atan2(d[1], d[2]) if abs(d[0]) < 0.5 else 0.0
    pc.box(buf, (blade_w, 0.012, blade_l), pc.xform(pos=tuple(foot + d * blade_l * 0.5), rot_z=rz, rot_y=ry, rot_x=-tilt), po.rect(iron),
           uv_per_m=1.0, jitter=0.002, rng=rng)
    if wing:
        pc.box(buf, (0.012, 0.07, blade_l * 0.34), pc.xform(pos=tuple(foot + d * blade_l * 0.8 + side * blade_w * 0.5), rot_z=rz, rot_y=ry, rot_x=-tilt),
               po.rect(iron), uv_per_m=1.0, jitter=0.002, rng=rng)


TOOL_COLS = [("timber", pc.tint((0.50, 0.42, 0.31), 0.9)), ("iron", pc.tint((0.2, 0.17, 0.15), 1.0, rough=0.6)),
             ("bark", pc.tint((0.34, 0.30, 0.26), 0.9))]


def spade_rack():
    rng = np.random.default_rng(405)
    maps, (ash, iron, bark) = pc.make_atlas("lw_spade_rack", TOOL_COLS)
    buf = pc.MeshBuf()
    for sx in (-0.9, 0.9):
        po.pole(buf, rng, [(sx, 0, -0.1), (sx + rng.normal(0, 0.01), 0, 0.6), (sx, 0, 1.15)], 0.05, 0.04, bark, sides=7)
    po.log(buf, rng, (-1.02, 0, 1.05), (1.02, 0.01, 1.07), 0.035, bark, ash, sides=6)
    # four peat spades leaned on the rail, blades down, and a turf knife hung by its crook
    for i in range(4):
        x = -0.62 + i * 0.4 + rng.normal(0, 0.03)
        _spade(buf, rng, (x + rng.normal(0, 0.02), -0.34, 0.0), (x, -0.04, 1.34 + rng.normal(0, 0.04)), ash, iron,
               blade_w=0.13, blade_l=rng.uniform(0.26, 0.32))
    po.pole(buf, rng, [(0.66, -0.05, 1.1), (0.66, -0.07, 0.62)], 0.014, 0.013, ash, sides=5)
    pc.box(buf, (0.012, 0.045, 0.36), pc.xform(pos=(0.66, -0.07, 0.45), rot_x=0.06), po.rect(iron), uv_per_m=1.0, jitter=0.002, rng=rng)
    return buf, maps, {"auto_smooth_deg": 40}


HEATHER_COLS = [("heather", pc.tint((0.36, 0.21, 0.36), 1.3, keep=0.1)), ("heather", pc.tint((0.24, 0.17, 0.2), 1.0, keep=0.1)),
                ("bark", pc.tint((0.20, 0.15, 0.12), 0.9)), ("rope", None)]


def _bunch(buf, rng, base, d, cols, length=0.34, fresh=True):
    """A tied bunch of heather: woody stems to the tie, a dozen flowering sprigs spread above it."""
    bloom, dust, stem, cord = cols
    base, d = np.asarray(base, float), np.asarray(d, float)
    d = d / np.linalg.norm(d)
    tie = base + d * length * 0.3
    po.pole(buf, rng, [tuple(base), tuple(tie)], 0.014, 0.018, stem, sides=5)
    po.pole(buf, rng, [tuple(tie - d * 0.012), tuple(tie + d * 0.012)], 0.023, 0.023, cord, sides=5)
    col = bloom if fresh else dust
    side = np.cross(d, [0.3, 0.2, 1.0])
    side /= np.linalg.norm(side)
    up2 = np.cross(d, side)
    for k in range(5):
        a = TAU * k / 5 + rng.random()
        spread = rng.uniform(0.1, 0.2)
        tip = tie + d * length * 0.7 + (math.cos(a) * side + math.sin(a) * up2) * length * spread * 2.2
        mid = tie + (tip - tie) * 0.45 + (math.cos(a) * side + math.sin(a) * up2) * length * 0.04
        r = length * rng.uniform(0.07, 0.1)
        span = (col[1] - col[0]) * 0.4
        u0 = col[0] + rng.random() * ((col[1] - col[0]) - span)
        # a sprig: thin at the tie, a flowering spike that tapers to its tip
        pc.tube(buf, [tuple(tie), tuple(mid), tuple(tie + (tip - tie) * 0.8), tuple(tip)], [r * 0.35, r, r * 0.85, r * 0.25], 5, u0, u0 + span, 3.0,
                v0=rng.random())


def heather_bunch():
    """One bunch, fresh: what Aud ties to the door turf every evening."""
    rng = np.random.default_rng(406)
    maps, cols = pc.make_atlas("lw_heather", HEATHER_COLS, size=512)
    buf = pc.MeshBuf()
    _bunch(buf, rng, (-0.16, 0.0, 0.035), (1.0, 0.1, 0.1), cols)
    return buf, maps, {}


def heather_heap():
    """About sixty bunches, one for every evening, heaped to the height of a
    barrow door and spilling down both sides of it. The ones at the bottom
    have gone to dust; all of it is purple."""
    rng = np.random.default_rng(407)
    maps, cols = pc.make_atlas("lw_heather", HEATHER_COLS, size=512)
    bloom, dust, stem, cord = cols
    buf = pc.MeshBuf()

    def hz(x, y):
        # against the door (y = 0, the piece's back): tall in the middle, skirts out
        front = max(0.0, min(1.0, (y + 1.15) / 1.0))
        return 1.4 * math.exp(-(x / 0.95) ** 2) * front ** 0.8 + 0.1 * front * (1.0 - min(abs(x) / 1.9, 1.0))

    # the heap's own body: the years of it underneath, gone to dust
    nx, ny = 22, 9
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = -1.9 + 3.8 * i / nx
            y = -1.2 + 1.25 * j / ny
            z = hz(x, y) * (1.0 + 0.1 * math.sin(x * 9 + y * 5)) - (0.03 if i in (0, nx) or j == 0 else 0.0)
            col = dust
            row.append(buf.vert((x, y, z), (col[0] + (col[1] - col[0]) * (i / nx), y * 0.8 + 0.2 * math.sin(x * 3))))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
    for i in range(62):
        x = max(-1.8, min(1.8, rng.normal(0, 0.8)))
        y = rng.uniform(-1.05, -0.02)
        z = hz(x, y)
        # lying down the heap's slope, every which way
        gx = (hz(x + 0.05, y) - hz(x - 0.05, y)) / 0.1
        gy = (hz(x, y + 0.05) - hz(x, y - 0.05)) / 0.1
        a = rng.random() * TAU
        d = np.array([math.cos(a), math.sin(a), 0.0])
        d[2] = gx * d[0] + gy * d[1]
        _bunch(buf, rng, (x, y, z + 0.035), d, cols, length=rng.uniform(0.3, 0.38), fresh=z > 0.45 or rng.random() < 0.3)
    return buf, maps, {}


def bread_cloth():
    """An undyed cloth spread on the turf, the crumbs of bread and cheese on it."""
    rng = np.random.default_rng(408)
    maps, (cloth, crumb) = pc.make_atlas("lw_bread_cloth", [("wool", pc.tint((0.66, 0.62, 0.52), 0.9, keep=0.1)),
                                                             ("timber", pc.tint((0.62, 0.5, 0.3), 0.6))], size=512)
    buf = pc.MeshBuf()
    nx, ny = 9, 7
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            x, y = (u - 0.5) * 0.95, (v - 0.5) * 0.7
            edge = min(u, 1 - u, v, 1 - v)
            # lying over the grass: rucked, one corner turned back
            z = 0.025 + 0.012 * math.sin(u * 9 + v * 5) * math.sin(v * 11) + (0.05 * max(0.0, 0.25 - math.hypot(u - 1, v - 1)) * 4)
            if u > 0.8 and v > 0.8:
                x -= (u - 0.8) * 0.5
                y -= (v - 0.8) * 0.4
            row.append(buf.vert((x + 0.02 * math.sin(v * 7), y + 0.02 * math.sin(u * 6), z - 0.02 * (edge < 0.01)), (cloth[0] + (cloth[1] - cloth[0]) * u, v * 0.7)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
    for _ in range(14):
        r = rng.uniform(0.006, 0.016)
        po.stone(buf, rng, (rng.normal(-0.05, 0.14), rng.normal(0, 0.1), 0.04 + r * 0.4), (r, r, r * 0.7), crumb, segs=5, rings=3)
    # a heel of bread nobody wanted
    po.stone(buf, rng, (0.18, -0.12, 0.06), (0.07, 0.05, 0.035), crumb, segs=7, rings=4)
    return buf, maps, {}


def birch_cup():
    """A small birch cup left upside down, so the dew stays out."""
    rng = np.random.default_rng(409)
    maps, (birch, pale) = pc.make_atlas("lw_birch_cup", [("timber", pc.tint((0.62, 0.52, 0.36), 0.7)),
                                                          ("timber", pc.tint((0.74, 0.62, 0.42), 0.5))], size=256)
    buf = pc.MeshBuf()
    # rim down on the turf, foot up
    pc.lathe(buf, [(0.05, 0.0), (0.052, 0.012), (0.046, 0.05), (0.03, 0.075), (0.026, 0.085), (0.0, 0.085)], 12, birch[0], birch[1], 2.0)
    return buf, maps, {}


def spade_iron():
    """The blade of a turf spade with no handle in it: one face ground bright."""
    rng = np.random.default_rng(410)
    maps, (iron, bright) = pc.make_atlas("lw_spade_iron", [("iron", pc.tint((0.2, 0.17, 0.15), 1.0, rough=0.7)),
                                                            ("iron", pc.tint((0.55, 0.56, 0.57), 0.5, rough=0.3))], size=256)
    buf = pc.MeshBuf()
    # lying flat: the bright face up, the socket empty
    pc.box(buf, (0.3, 0.15, 0.008), pc.xform(pos=(0.0, 0, 0.012), rot_y=0.03), po.rect(bright), uv_per_m=1.0, jitter=0.002, rng=rng)
    pc.box(buf, (0.3, 0.15, 0.008), pc.xform(pos=(0.0, 0, 0.005), rot_y=0.03), po.rect(iron), uv_per_m=1.0, jitter=0.002, rng=rng)
    pc.box(buf, (0.1, 0.07, 0.01), pc.xform(pos=(0.1, 0.1, 0.012), rot_y=0.03), po.rect(iron), uv_per_m=1.0, jitter=0.002, rng=rng)
    pc.lathe(buf, [(0.02, 0.0), (0.024, 0.0), (0.02, 0.1), (0.016, 0.1), (0.02, 0.0)], 7, iron[0], iron[1], 2.0,
             xf=pc.xform(pos=(0.15, 0, 0.026), rot_y=math.pi / 2))
    return buf, maps, {"auto_smooth_deg": 40}


def edging_stone():
    """The smith's edging stone: a block of sandstone, hollowed along the top by the work."""
    rng = np.random.default_rng(411)
    maps, (stone, worn) = pc.make_atlas("lw_edging_stone", [("fieldstone", pc.tint((0.5, 0.46, 0.38), 0.9)),
                                                             ("fieldstone", pc.tint((0.6, 0.56, 0.47), 0.6))], size=512)
    buf = pc.MeshBuf()
    pc.box(buf, (0.62, 0.36, 0.4), pc.xform(pos=(0, 0, 0.19)), po.rect(stone), uv_per_m=0.8, jitter=0.02, rng=rng)
    pc.box(buf, (0.5, 0.2, 0.02), pc.xform(pos=(0, 0, 0.395)), po.rect(worn), uv_per_m=0.8, jitter=0.004, rng=rng)
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.012}


def small_spades(big=False):
    """Two turf spades with blades a hand wide, on handles cut down from a
    broken rake, leaned by a door. With `big`, Arne's own stands beside them."""
    rng = np.random.default_rng(412)
    maps, (ash, iron, bark) = pc.make_atlas("lw_small_spades", TOOL_COLS, size=512)
    buf = pc.MeshBuf()
    # leaned on a wall at y = +0.14 (the piece's back), blades on the ground in front
    for i, x in enumerate((-0.13, 0.11)):
        _spade(buf, rng, (x + rng.normal(0, 0.015), -0.16, 0.0), (x, 0.1, 0.78 + i * 0.03), ash, iron, blade_w=0.085, blade_l=0.17, grip=0.07, wing=False)
    if big:
        _spade(buf, rng, (0.42, -0.24, 0.0), (0.4, 0.1, 1.32), ash, iron)
    return buf, maps, {"auto_smooth_deg": 40}


def dinner_cloth():
    """A dinner tied up in a cloth, left on the bench."""
    rng = np.random.default_rng(413)
    maps, (cloth, knot) = pc.make_atlas("lw_dinner_cloth", [("wool", pc.tint((0.5, 0.47, 0.4), 0.9, keep=0.1)),
                                                             ("wool", pc.tint((0.42, 0.4, 0.34), 0.9, keep=0.1))], size=256)
    buf = pc.MeshBuf()
    po.stone(buf, rng, (0, 0, 0.07), (0.14, 0.12, 0.08), cloth, lump=0.12, segs=9, rings=6)
    for a in (0.5, 2.6):
        po.stone(buf, rng, (math.cos(a) * 0.035, math.sin(a) * 0.035, 0.165), (0.05, 0.02, 0.03), knot, segs=6, rings=4, rot_z=a)
    return buf, maps, {}


def mound_steps():
    """Sod steps cut into a kin-mound's shoulder: the way up for whoever
    brings the bread. Rises 1.7 m in 3.2 m (the piece's back, +Y, is the top)."""
    rng = np.random.default_rng(414)
    maps, (turf, peat) = pc.make_atlas("lw_mound_steps", [TURF, PEAT])
    buf = pc.MeshBuf()
    n = 8
    run, rise, wid = 3.2, 1.7, 1.3
    for i in range(n):
        y = -run / 2 + (i + 0.5) * run / n
        ztop = (i + 1) * rise / n
        # each step a block of the mound's own turf: riser of cut peat, tread of grass
        pc.box(buf, (wid * rng.uniform(0.92, 1.05), run / n * 1.08, ztop + 0.3), pc.xform(pos=(rng.normal(0, 0.03), y, ztop / 2 - 0.17)),
               po.rect(peat), uv_per_m=0.6, jitter=0.02, rng=rng)
        pc.box(buf, (wid * rng.uniform(0.95, 1.08), run / n * 1.12, 0.07), pc.xform(pos=(rng.normal(0, 0.03), y, ztop - 0.02), rot_x=0.05),
               po.rect(turf), uv_per_m=0.6, jitter=0.02, rng=rng)
    return buf, maps, {"auto_smooth_deg": 45}


PIECES = {
    "kit_lw_sod_row_p": sod_row,
    "kit_lw_peat_stack_p": peat_stack,
    "kit_lw_peat_wall_p": peat_wall,
    "kit_lw_peat_row_p": peat_row,
    "kit_lw_spade_rack_p": spade_rack,
    "kit_lw_heather_bunch_p": heather_bunch,
    "kit_lw_heather_heap_p": heather_heap,
    "kit_lw_bread_cloth_p": bread_cloth,
    "kit_lw_birch_cup_p": birch_cup,
    "kit_lw_spade_iron_p": spade_iron,
    "kit_lw_edging_stone_p": edging_stone,
    "kit_lw_small_spades_p": small_spades,
    "kit_lw_three_spades_p": lambda: small_spades(True),
    "kit_lw_dinner_cloth_p": dinner_cloth,
    "kit_lw_mound_steps_p": mound_steps,
}

if __name__ == "__main__":
    po.run(PIECES, None)
