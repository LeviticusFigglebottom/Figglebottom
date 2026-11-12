#!/usr/bin/env python3
"""Shepherd's Reach's own prop set and its points of interest
(docs/art/BIOMES.md "Shepherd's Reach"; docs/lore/POI.md 7), the pieces
modelled by hand. Pale limestone, laid dry: through-stones and a coping.

  kit_sr_creep_wall_p      a drystone wall section with a creep hole and its slab door
  kit_sr_slab_gate_p       two limestone slabs on edge as gateposts, the three slip-rails drawn and leaned by
  kit_sr_slab_posts_p      the two slabs alone (a gate that has its rails elsewhere)
  kit_sr_rails_down_p      three slip-rails lying in the grass
  lm_sr_slip_rails         the three rails in their slots across the gap, tied with wool (a shut gate's dressing)
  kit_sr_crook_rack_p      crooks and a hazel stick on pegs
  kit_sr_counting_stone_p  a flat stone with a worn hollow, forty-three pebbles in it
  kit_sr_coping_row_p      wall stones laid out on the grass in the order they go back
  kit_sr_heather_bed_p     a bed of heather, made; _thrown: thrown back, blankets on the floor
  kit_sr_blanket_p         a grey wool blanket folded in four
  kit_sr_pot_bowls_p       a pot and two bowls

Run: $BPY tools/art/procedural/props_reach.py [--only name]
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402
import poi_common as po  # noqa: E402

TAU = math.tau
LIME = ("drystone", pc.tint((0.60, 0.60, 0.56), 0.9))
LIME_DARK = ("drystone", pc.tint((0.47, 0.48, 0.45), 0.9))
LICHEN = ("drystone", pc.tint((0.62, 0.60, 0.44), 0.7))
ASH = ("timber", pc.tint((0.52, 0.45, 0.34), 0.9))
HAZEL = ("bark", pc.tint((0.36, 0.28, 0.2), 0.9))
WOOL = ("wool", pc.tint((0.60, 0.59, 0.56), 0.9, keep=0.1))


def _wall(buf, rng, cols, length=2.0, height=1.05, depth=0.55, hole=None):
    """Coursed limestone, two faces and a heart, a row of through-stones at
    half height and a coping of stones set on edge. `hole` (x0, x1, top)
    leaves a creep through it under a lintel."""
    lime, dark, lichen = cols
    z = 0.0
    k = 0
    through_at = None
    while z < height - 0.02:
        h = min(rng.uniform(0.13, 0.21), height - z)
        d = depth * (1.0 - 0.18 * z / height)                 # battered: narrower at the top
        x = -length / 2 + (0.0 if k % 2 else -0.14)
        is_through = through_at is None and z > height * 0.42
        while x < length / 2 - 0.03:
            w = min(rng.uniform(0.22, 0.46), length / 2 - x)
            if hole and hole[0] - 0.02 < x + w / 2 < hole[1] + 0.02 and z + h * 0.5 < hole[2]:
                x += w
                continue
            col = lichen if rng.random() < 0.12 else (dark if rng.random() < 0.3 else lime)
            if is_through and rng.random() < 0.45:
                # a through-stone: one stone the whole width, standing proud of both faces
                pc.box(buf, (w * 0.9, d * 1.22, h * 0.9), pc.xform(pos=(x + w / 2, 0, z + h / 2), rot_z=rng.normal(0, 0.03)),
                       po.rect(col), uv_per_m=0.5, jitter=0.012, rng=rng)
            else:
                for sy in (-1, 1):
                    pc.box(buf, (w * 0.97, d * 0.52, h * 0.95),
                           pc.xform(pos=(x + w / 2, sy * d * 0.25 + rng.normal(0, 0.012), z + h / 2), rot_z=rng.normal(0, 0.05), rot_x=rng.normal(0, 0.04)),
                           po.rect(col), uv_per_m=0.5, jitter=0.014, rng=rng)
            x += w
        if is_through:
            through_at = z
        z += h
        k += 1
    if hole:
        pc.box(buf, (hole[1] - hole[0] + 0.34, depth * 1.02, 0.13), pc.xform(pos=((hole[0] + hole[1]) / 2, 0, hole[2] + 0.05)), po.rect(dark),
               uv_per_m=0.5, jitter=0.012, rng=rng)
    # the coping: slabs on edge, leaning on one another along the top
    x = -length / 2
    while x < length / 2 - 0.02:
        t = min(rng.uniform(0.07, 0.13), length / 2 - x)
        ch = rng.uniform(0.2, 0.3)
        pc.box(buf, (t, depth * rng.uniform(0.78, 0.92), ch), pc.xform(pos=(x + t / 2, rng.normal(0, 0.015), height + ch / 2 - 0.02), rot_y=rng.normal(0.18, 0.08)),
               po.rect(lime if rng.random() < 0.7 else lichen), uv_per_m=0.5, jitter=0.01, rng=rng)
        x += t


def creep_wall():
    rng = np.random.default_rng(501)
    maps, cols = pc.make_atlas("sr_wall", [LIME, LIME_DARK, LICHEN])
    buf = pc.MeshBuf()
    _wall(buf, rng, cols, hole=(-0.28, 0.28, 0.6))
    # its slab door, lifted out and leaned by the hole
    pc.box(buf, (0.62, 0.07, 0.72), pc.xform(pos=(0.66, -0.4, 0.33), rot_x=-0.26, rot_z=0.1), po.rect(cols[1]), uv_per_m=0.5, jitter=0.014, rng=rng)
    return buf, maps, {"auto_smooth_deg": 40}


GAP = 3.0        # between the slabs' inner faces


def _slabs(buf, rng, cols):
    for sx in (-1, 1):
        pc.box(buf, (0.2, 0.62, 1.5), pc.xform(pos=(sx * (GAP / 2 + 0.1), 0, 0.66), rot_y=sx * rng.uniform(0.02, 0.05), rot_z=rng.normal(0, 0.05)),
               po.rect(cols[0]), uv_per_m=0.5, jitter=0.02, rng=rng)
        # packing stones at each slab's foot
        for _ in range(3):
            r = rng.uniform(0.08, 0.14)
            po.stone(buf, rng, (sx * (GAP / 2 + 0.1 + rng.normal(0, 0.12)), rng.choice((-1, 1)) * rng.uniform(0.3, 0.42), r * 0.5), (r, r * 0.8, r * 0.6), cols[1])


def _rail(buf, rng, a, b, bark, wood):
    po.log(buf, rng, a, b, 0.037, bark, wood, sides=6, wobble=0.06)


def slab_gate(mode="drawn"):
    rng = np.random.default_rng(502)
    maps, (lime, dark, bark, wood, wool) = pc.make_atlas("sr_slab_gate", [LIME, LIME_DARK, HAZEL, ASH, WOOL])
    buf = pc.MeshBuf()
    cols = (lime, dark)
    if mode in ("drawn", "posts"):
        _slabs(buf, rng, cols)
    if mode == "drawn":
        # the rails slipped out and laid along the wall foot beyond the east slab
        for i in range(3):
            x = GAP / 2 + 0.42 + i * 0.1
            _rail(buf, rng, (x + rng.normal(0, 0.02), -0.2, 0.04 + (0.07 if i == 1 else 0.0)), (x + rng.normal(0, 0.04), 3.0, 0.04 + (0.07 if i == 1 else 0.0)), bark, wood)
    elif mode == "down":
        for i in range(3):
            _rail(buf, rng, (-1.6 + rng.normal(0, 0.05), -0.12 + i * 0.12, 0.04), (1.6 + rng.normal(0, 0.05), -0.1 + i * 0.13 + rng.normal(0, 0.03), 0.04), bark, wood)
    elif mode == "shut":
        for i, z in enumerate((0.38, 0.74, 1.1)):
            _rail(buf, rng, (-GAP / 2 - 0.24, rng.normal(0, 0.02), z), (GAP / 2 + 0.24, rng.normal(0, 0.02), z + rng.normal(0, 0.02)), bark, wood)
        # tied shut on the lane side (-Y): a hank of wool cord round the top rail and the slab
        for z in (1.08, 1.12):
            po.ring(buf, rng, (GAP / 2 - 0.02, -0.02, z), 0.085, 0.012, wool, axis="x", sides=4, segs=8)
        po.pole(buf, rng, [(GAP / 2 - 0.02, -0.1, 1.06), (GAP / 2 - 0.04, -0.13, 0.86), (GAP / 2 - 0.02, -0.11, 0.7)], 0.01, 0.008, wool, sides=4)
    return buf, maps, {"auto_smooth_deg": 40}


def crook_rack():
    rng = np.random.default_rng(503)
    maps, (bark, wood, ash) = pc.make_atlas("sr_crook_rack", [HAZEL, ("timber", pc.tint((0.44, 0.38, 0.3), 0.9)), ASH])
    buf = pc.MeshBuf()
    for sx in (-0.55, 0.55):
        po.pole(buf, rng, [(sx, 0, -0.1), (sx + rng.normal(0, 0.008), 0, 0.8), (sx, 0, 1.62)], 0.04, 0.032, bark, sides=7)
    po.board(buf, rng, (1.26, 0.04, 0.11), (0, -0.045, 1.5), wood)
    for i, x in enumerate((-0.36, 0.0, 0.36)):
        po.pole(buf, rng, [(x, -0.05, 1.5), (x, -0.17, 1.54)], 0.013, 0.011, wood, sides=5)
        if i < 2:
            # a crook: the long shank down, the horn-shaped head hooked over the peg
            pts = [(x, -0.15, 0.12 + i * 0.05), (x + 0.01, -0.14, 0.9), (x, -0.13, 1.46)]
            for k in range(7):
                a = math.pi * k / 6
                pts.append((x + 0.085 * (1 - math.cos(a)) * (1 if i == 0 else -1), -0.13, 1.46 + 0.1 * math.sin(a)))
            pts.append((x + 0.17 * (1 if i == 0 else -1), -0.13, 1.4))
            po.pole(buf, rng, pts, 0.014, 0.011, ash, sides=5)
        else:
            # a hazel stick hung by its thong
            po.pole(buf, rng, [(x, -0.14, 0.2), (x + 0.02, -0.14, 0.8), (x, -0.14, 1.38)], 0.013, 0.015, bark, sides=5)
            po.ring(buf, rng, (x, -0.14, 1.46), 0.06, 0.005, wood, axis="y", sides=4, segs=8)
    return buf, maps, {"auto_smooth_deg": 40}


def counting_stone():
    rng = np.random.default_rng(504)
    maps, (lime, dark, peb) = pc.make_atlas("sr_counting_stone", [("fieldstone", pc.tint((0.62, 0.62, 0.58), 0.5)), ("fieldstone", pc.tint((0.40, 0.41, 0.39), 0.5)),
                                                                 ("shingle", pc.tint((0.74, 0.72, 0.66), 0.8))])
    buf = pc.MeshBuf()
    seg, rings = 20, 8
    R = (0.72, 0.52)
    prof = [(0.9, 0.0), (1.0, 0.1), (1.0, 0.36), (0.94, 0.44), (0.7, 0.46), (0.5, 0.455), (0.3, 0.41), (0.12, 0.385), (0.0, 0.38)]
    grid = []
    for j, (pr, pz) in enumerate(prof):
        row = []
        for k in range(seg + 1):
            a = TAU * (k % seg) / seg
            w = 1.0 + (0.06 * math.sin(a * 3 + 1.2) + 0.04 * math.sin(a * 5 + 0.3)) * (1.0 if j < 5 else 0.3)
            col = dark if j >= 5 else lime          # the hollow, worn dark by hands
            x, y = math.cos(a) * R[0] * pr * w, math.sin(a) * R[1] * pr * w
            # mapped from above (a slab's top is what is looked at); the sides run on down
            row.append(buf.vert((x, y, pz - 0.05), (col[0] + (col[1] - col[0]) * (0.5 + x / 1.7), 0.5 + y / 1.7 - (0.46 - pz) * 0.5 * (1 if j < 4 else 0))))
        grid.append(row)
    for j in range(len(prof) - 1):
        for k in range(seg):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])
    # forty-three pebbles in the hollow, and room for one more
    n = 0
    tries = 0
    put = []
    while n < 43 and tries < 4000:
        tries += 1
        a, rr = rng.random() * TAU, math.sqrt(rng.random()) * 0.3
        x, y = math.cos(a) * rr * 1.25, math.sin(a) * rr * 0.92
        if abs(x - 0.2) < 0.05 and abs(y + 0.08) < 0.05:
            continue                                  # the one place left empty
        if any(math.hypot(x - px, y - py) < 0.05 for px, py in put):
            continue
        put.append((x, y))
        r = rng.uniform(0.022, 0.03)
        zz = 0.335 + 0.06 * (math.hypot(x / 1.25, y / 0.92) / 0.3) ** 2
        po.stone(buf, rng, (x, y, zz + r * 0.6), (r, r * 0.85, r * 0.7), peb, segs=6, rings=4, lump=0.1)
        n += 1
    return buf, maps, {"auto_smooth_deg": 50}


def coping_row():
    rng = np.random.default_rng(505)
    maps, cols = pc.make_atlas("sr_wall", [LIME, LIME_DARK, LICHEN])
    buf = pc.MeshBuf()
    # laid out along the wall's foot, biggest first: footings, face stones, hearting, cope
    x = -1.3
    for i in range(11):
        f = 1.0 - i / 14.0
        w, d, h = rng.uniform(0.2, 0.3) * (0.7 + f * 0.6), rng.uniform(0.2, 0.3) * (0.6 + f * 0.6), rng.uniform(0.1, 0.16) * (0.6 + f * 0.7)
        col = cols[int(rng.integers(0, 3))]
        pc.box(buf, (w, d, h), pc.xform(pos=(x + w / 2, rng.normal(0, 0.03), h / 2 - 0.01), rot_z=rng.normal(0, 0.15)), po.rect(col), uv_per_m=0.5,
               jitter=0.016, rng=rng)
        x += w + rng.uniform(0.03, 0.07)
    for i in range(5):                                  # the cope stones in their own short row behind
        pc.box(buf, (0.09, 0.4, 0.24), pc.xform(pos=(-1.0 + i * 0.16, 0.5, 0.11), rot_y=0.5 + rng.normal(0, 0.05)), po.rect(cols[0]), uv_per_m=0.5,
               jitter=0.012, rng=rng)
    return buf, maps, {"auto_smooth_deg": 40}


BED_COLS = [("heather", pc.tint((0.30, 0.24, 0.22), 1.0, keep=0.1)), ("timber", pc.tint((0.40, 0.34, 0.27), 0.9)), WOOL,
            ("wool", pc.tint((0.45, 0.42, 0.37), 0.9, keep=0.1))]


def _blanket(buf, rng, col, pos, size=(0.5, 0.36), layers=4, rot_z=0.0):
    """Folded in four, corners squared."""
    for i in range(layers):
        pc.box(buf, (size[0] * (1 - 0.01 * i), size[1] * (1 - 0.01 * i), 0.028), pc.xform(pos=(pos[0], pos[1], pos[2] + 0.014 + i * 0.03), rot_z=rot_z),
               po.rect(col), uv_per_m=1.2, jitter=0.003, rng=rng)


def _heap(buf, rng, col, cx, cy, sx, sy, h, z0=0.0, rot=0.0, ruck=0.03):
    """A blanket lying how it fell: a rucked sheet over a low mound."""
    nx, ny = 9, 7
    grid = []
    c, s = math.cos(rot), math.sin(rot)
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            lx, ly = (u - 0.5) * sx, (v - 0.5) * sy
            e = min(u, 1 - u, v, 1 - v)
            z = z0 + h * min(1.0, e * 4) * (0.6 + 0.4 * math.sin(u * 7 + v * 3)) + ruck * math.sin(u * 13) * math.sin(v * 9 + 1) + 0.012
            row.append(buf.vert((cx + lx * c - ly * s, cy + lx * s + ly * c, z), (col[0] + (col[1] - col[0]) * u, v * 0.8)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])


def heather_bed(thrown=False):
    """A sheiling bed: a frame of four poles on the floor, packed with heather, tops up."""
    rng = np.random.default_rng(506 + (1 if thrown else 0))
    maps, (heath, wood, grey, brown) = pc.make_atlas("sr_heather_bed", BED_COLS)
    buf = pc.MeshBuf()
    L, W = 1.9, 0.8
    for sy in (-1, 1):
        po.log(buf, rng, (-L / 2, sy * W / 2, 0.07), (L / 2, sy * W / 2, 0.07), 0.06, wood, wood, sides=7)
    for sx in (-1, 1):
        po.log(buf, rng, (sx * L / 2, -W / 2 - 0.08, 0.1), (sx * L / 2, W / 2 + 0.08, 0.1), 0.055, wood, wood, sides=7)
    # the heather: a springy mattress, lumpy on top
    nx, ny = 12, 6
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            e = min(u, 1 - u, v, 1 - v)
            z = 0.1 + 0.16 * min(1.0, e * 5) + 0.025 * math.sin(u * 17 + v * 5) * math.sin(v * 11)
            if thrown:
                z += 0.04 * math.sin(u * 5 + 1) * math.sin(v * 4)      # slept in and left
            row.append(buf.vert(((u - 0.5) * (L - 0.1), (v - 0.5) * (W - 0.08), z), (heath[0] + (heath[1] - heath[0]) * v, u * 2.2)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
    if thrown:
        # thrown back: one blanket half off the foot, one on the floor beside it
        _heap(buf, rng, brown, 0.5, 0.08, 0.85, 0.66, 0.08, z0=0.2, rot=0.3, ruck=0.03)
        _heap(buf, rng, grey, 0.2, -0.75, 1.0, 0.6, 0.07, z0=0.0, rot=-0.2, ruck=0.035)
    else:
        # made: the under-blanket drawn smooth over the heather (the folded one on it is the pickup)
        grid = []
        for j in range(ny + 1):
            row = []
            for i in range(nx + 1):
                u, v = i / nx, j / ny
                e = min(u, 1 - u, v, 1 - v)
                z = 0.1 + 0.16 * min(1.0, e * 5) + 0.04
                row.append(buf.vert(((u - 0.5) * (L - 0.16), (v - 0.5) * (W - 0.12), z), (brown[0] + (brown[1] - brown[0]) * v, u * 1.6)))
            grid.append(row)
        for j in range(ny):
            for i in range(nx):
                buf.quad(grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i])
    return buf, maps, {"auto_smooth_deg": 50}


def blanket():
    rng = np.random.default_rng(508)
    maps, (grey, _) = pc.make_atlas("sr_blanket", [WOOL, ("wool", pc.tint((0.5, 0.5, 0.47), 0.9, keep=0.1))], size=512)
    buf = pc.MeshBuf()
    _blanket(buf, rng, grey, (0, 0, 0.0))
    return buf, maps, {"auto_smooth_deg": 40, "bevel": 0.006}


def pot_bowls():
    rng = np.random.default_rng(509)
    maps, (iron, wood) = pc.make_atlas("sr_pot_bowls", [("iron", pc.tint((0.13, 0.12, 0.115), 1.0, rough=0.7)),
                                                         ("timber", pc.tint((0.48, 0.37, 0.25), 0.8))], size=512)
    buf = pc.MeshBuf()
    pc.lathe(buf, [(0.0, 0.0), (0.1, 0.0), (0.17, 0.07), (0.18, 0.16), (0.15, 0.24), (0.16, 0.26), (0.145, 0.26), (0.135, 0.23), (0.15, 0.15),
                   (0.13, 0.06), (0.0, 0.04)], 14, iron[0], iron[1], 1.5)
    for i, (x, y) in enumerate(((0.36, 0.08), (0.42, -0.2))):
        r = 0.085
        pc.lathe(buf, [(0.0, 0.0), (r * 0.45, 0.0), (r * 0.85, 0.02), (r, 0.055), (r - 0.007, 0.055), (r * 0.75, 0.025), (r * 0.4, 0.01), (0.0, 0.01)],
                 12, wood[0], wood[1], 2.0, xf=pc.xform(pos=(x, y, 0.0), rot_z=rng.random()))
    return buf, maps, {}


PIECES = {
    "kit_sr_creep_wall_p": creep_wall,
    "kit_sr_slab_gate_p": slab_gate,
    "kit_sr_slab_posts_p": lambda: slab_gate("posts"),
    "kit_sr_rails_down_p": lambda: slab_gate("down"),
    "lm_sr_slip_rails": lambda: slab_gate("shut"),
    "kit_sr_crook_rack_p": crook_rack,
    "kit_sr_counting_stone_p": counting_stone,
    "kit_sr_coping_row_p": coping_row,
    "kit_sr_heather_bed_p": heather_bed,
    "kit_sr_heather_bed_thrown_p": lambda: heather_bed(True),
    "kit_sr_blanket_p": blanket,
    "kit_sr_pot_bowls_p": pot_bowls,
}

if __name__ == "__main__":
    po.run(PIECES, None)
