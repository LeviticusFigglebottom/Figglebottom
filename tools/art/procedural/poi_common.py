"""Shared shapes for the region prop sets and points of interest
(docs/art/BIOMES.md, docs/lore/POI.md): round and split timber, boards,
beach stones, cord, drystone, sods. Built on proc_common; Blender axes
(X across, Y deep, Z up), origin at the bottom centre.
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402

TAU = math.tau


def rect(col):
    return (col[0], 0.0, col[1], 1.0)


def darken(k):
    def fn(alb, orh):
        return np.clip(alb * k, 0, 1), orh
    return fn


def disc(buf, centre, normal, radius, sides, col, rng, squash=(1.0, 1.0), ref=None):
    """A sawn end: a fan mapped as a disc inside one atlas column."""
    uc = ((col[0] + col[1]) * 0.5, rng.random())
    pc.cap(buf, centre, normal, radius, sides, uc, (col[1] - col[0]) * 0.4, squash=squash, ref=ref)


def log(buf, rng, a, b, radius, bark, wood, sides=8, wobble=0.03, taper=1.0, v_per_m=1.0):
    """A round length of timber from a to b with sawn ends."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    n = 4
    pts = [a + (b - a) * i / (n - 1) + rng.normal(0, radius * wobble, 3) * (0 < i < n - 1) for i in range(n)]
    rad = [radius * (1.0 + (taper - 1.0) * i / (n - 1)) * rng.uniform(0.96, 1.04) for i in range(n)]
    span = min(TAU * radius / 0.6, 1.0) * (bark[1] - bark[0])
    u0 = bark[0] + rng.random() * ((bark[1] - bark[0]) - span)
    pc.tube(buf, pts, rad, sides, u0, u0 + span, v_per_m, v0=rng.random(), cap_end=False)
    d = (b - a) / np.linalg.norm(b - a)
    # cap() winds for +normal; the near end faces back down the log
    disc(buf, pts[-1], d, rad[-1], sides, wood, rng)
    disc(buf, pts[0], -d, rad[0], sides, wood, rng)


def pole(buf, rng, pts, r0, r1, col, sides=6, v_per_m=1.2):
    """A thin stake, peg, cord or handle along a polyline (pointed end cap)."""
    pts = [np.asarray(p, float) for p in pts]
    n = len(pts)
    rad = [r0 + (r1 - r0) * i / max(n - 1, 1) for i in range(n)]
    span = min(TAU * max(r0, r1) / 0.5, 1.0) * (col[1] - col[0])
    u0 = col[0] + rng.random() * ((col[1] - col[0]) - span)
    pc.tube(buf, pts, rad, sides, u0, u0 + span, v_per_m, v0=rng.random())
    # close the foot as well: stakes are seen from below on slopes
    t = pts[0] - pts[1]
    t /= np.linalg.norm(t)
    disc(buf, pts[0], t, rad[0], sides, col, rng)


def board(buf, rng, size, pos, col, rot_z=0.0, rot_x=0.0, rot_y=0.0, jitter=0.006, uv_per_m=0.5):
    pc.box(buf, size, pc.xform(pos=pos, rot_z=rot_z, rot_x=rot_x, rot_y=rot_y), rect(col), uv_per_m=uv_per_m,
           jitter=jitter, rng=rng)


def stone(buf, rng, pos, radii, col, lump=0.14, segs=8, rings=5, rot_z=None):
    u0 = col[0] + rng.random() * (col[1] - col[0]) * 0.45
    v0 = rng.random()
    pc.blob(buf, rng, (0, 0, 0), radii, segs, rings, u0, u0 + (col[1] - col[0]) * 0.5, v0, v0 + 0.5, lump=lump,
            xf=pc.xform(pos=pos, rot_z=rng.random() * TAU if rot_z is None else rot_z, rot_x=rng.normal(0, 0.1)))


def sag(a, b, drop, n=7):
    """Points of a cord hung between a and b, sagging by `drop`."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    return [a + (b - a) * t + np.array([0, 0, -drop * 4 * t * (1 - t)]) for t in np.linspace(0, 1, n)]


def ring(buf, rng, centre, radius, thick, col, axis="y", sides=5, segs=10):
    """A closed hoop (iron ring, withy binding) standing in the plane across `axis`."""
    pts = []
    for k in range(segs + 1):
        a = TAU * k / segs
        c, s = math.cos(a) * radius, math.sin(a) * radius
        off = {"y": (c, 0, s), "x": (0, c, s), "z": (c, s, 0)}[axis]
        pts.append(np.asarray(centre, float) + np.array(off))
    span = (col[1] - col[0]) * 0.3
    u0 = col[0] + rng.random() * ((col[1] - col[0]) - span)
    pc.tube(buf, pts, [thick] * len(pts), sides, u0, u0 + span, 2.0, cap_end=False)


def drystone(buf, rng, length, height, depth, col, course=0.2, lean=0.04):
    """A length of dry-stone wall along X: coursed, jittered blocks, a coping."""
    z = 0.0
    k = 0
    while z < height - 0.02:
        h = min(course * rng.uniform(0.8, 1.2), height - z)
        x = -length / 2 + (0.0 if k % 2 else -0.12)
        d = depth * (1.0 - lean * z / max(height, 0.01) * 4)
        while x < length / 2 - 0.04:
            w = min(rng.uniform(0.26, 0.5), length / 2 - x)
            for sy in (-1, 1):
                pc.box(buf, (w * 0.97, d * 0.52, h * 0.96),
                       pc.xform(pos=(x + w / 2, sy * d * 0.25 + rng.normal(0, 0.012), z + h / 2),
                                rot_z=rng.normal(0, 0.05), rot_x=rng.normal(0, 0.04)),
                       rect(col), uv_per_m=0.5, jitter=0.014, rng=rng)
            x += w
        z += h
        k += 1


def sod(buf, rng, pos, size, turf, peat, rot_z=0.0, grass_up=True):
    """One lifted sod: a slab of peat with the turf on one face."""
    sx, sy, sz = size
    xf = pc.xform(pos=pos, rot_z=rot_z, rot_x=rng.normal(0, 0.05), rot_y=rng.normal(0, 0.05))
    pc.box(buf, (sx, sy, sz * 0.7), xf @ pc.xform(pos=(0, 0, -sz * 0.15 if grass_up else sz * 0.15)), rect(peat),
           uv_per_m=0.6, jitter=0.012, rng=rng)
    pc.box(buf, (sx * 1.02, sy * 1.02, sz * 0.34), xf @ pc.xform(pos=(0, 0, sz * 0.33 if grass_up else -sz * 0.33)),
           rect(turf), uv_per_m=0.6, jitter=0.014, rng=rng)


def run(pieces, out_dirs):
    """Common main(): `pieces` name -> fn() -> (buf, maps, export opts)."""
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])
    for name, fn in pieces.items():
        if a.only and a.only not in name:
            continue
        buf, maps, opts = fn()
        sub = "landmarks" if name.startswith("lm_") else ("scatter" if name.startswith("sc_") else "kit")
        pc.export_glb(os.path.join(pc.ROOT, "assets", "models", sub, name + ".glb"), name, buf, maps, **opts)
