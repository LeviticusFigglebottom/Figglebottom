#!/usr/bin/env python3
"""The region plants that need volume (docs/art/BIOMES.md column 2, "new
model"): cushions, mats, kelp, a coppice stool, saplings, a creeping juniper.
The cards (tools/art/veg_atlas.py) carry everything that is blades and
flower heads; these are the plants a card cannot be, because they are seen
from above and have a body.

Each is a small mesh with a painted top (a free Tripo image-generator
texture, raw/veg/top_<name>.png; prompts in assets/PROVENANCE.md) mapped
from above, plus a bark column from the committed CC0 set where it has wood.
They go in through Scatter.VEG_KINDS ("glb" kinds), shaded by
MaterialLib.hero_mat like every other modelled piece, so RIME lays its snow
on them; Scatter sinks and thins them in RIME as it does the cards.

  veg_thrift_cushion    Saltfell: a tight cushion of sea thrift
  veg_kelp              Saltfell: bladderwrack and kelp laid along the wrack line
  veg_sphagnum          the Lowe: a sphagnum hummock, wine red and ochre
  veg_crowberry         Kettle: a crowberry mat on a ledge
  veg_moss_cushion      Thornwold: a moss cushion on the forest floor
  veg_hazel_stool       Thornwold: a hazel coppice stool (and _bare, for RIME)
  veg_birch_sapling     Thornwold: a birch sapling (and _bare, for RIME)
  veg_juniper           the Reach: prostrate juniper on the ledges
  veg_saxifrage         the Coldwell: a purple saxifrage cushion
  veg_starmoss          the Coldwell: star moss round the spring

Run: $BPY tools/art/procedural/veg_models.py [-- --only name]
"""
import argparse
import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402

TAU = math.tau
OUT = os.path.join(pc.ROOT, "assets", "models", "veg")
RAW = os.path.join(pc.ROOT, "raw", "veg")
SIZE = 512


def painted(name, bright=1.0, sat=1.0):
    """A painted top as albedo, with a normal and roughness made from it."""
    im = Image.open(os.path.join(RAW, "top_%s.png" % name)).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
    a = np.asarray(im, np.float32) / 255.0
    luma = (a * np.array([0.3, 0.59, 0.11])).sum(axis=2, keepdims=True)
    a = np.clip((luma + (a - luma) * sat) * bright, 0, 1)
    h = luma[..., 0]
    gx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 2.5
    gy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 2.5
    n = np.dstack([-gx, gy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    orh = np.dstack([np.clip(0.55 + h * 0.9, 0, 1), np.full_like(h, 0.86), h])
    return a, n * 0.5 + 0.5, orh


def atlas(name, top, bark_rgb=None, bright=1.0, sat=1.0):
    """Left: the painted top. Right (when asked): a bark column, tinted."""
    a, n, o = painted(top, bright, sat)
    if bark_rgb is None:
        return pc.save_maps(name, a, n, pc.orh_to_orm(o)), (0.01, 0.99), None
    b = pc.load_set("bark", SIZE)
    alb, orh = pc.tint(bark_rgb, 1.0)(b["albedo"][:, :SIZE // 4].copy(), b["orh"][:, :SIZE // 4].copy())
    w = SIZE + SIZE // 4
    A = np.zeros((SIZE, w, 3), np.float32)
    N = np.zeros_like(A)
    O = np.zeros_like(A)
    A[:, :SIZE], N[:, :SIZE], O[:, :SIZE] = a, n, o
    A[:, SIZE:], N[:, SIZE:], O[:, SIZE:] = alb, b["normal"][:, :SIZE // 4], orh
    # square it up (the hall shader does not care, the importer's mips do)
    sq = lambda x: np.asarray(Image.fromarray((np.clip(x, 0, 1) * 255).astype(np.uint8)).resize((SIZE, SIZE), Image.LANCZOS), np.float32) / 255.0
    f = SIZE / w
    return pc.save_maps(name, sq(A), sq(N), pc.orh_to_orm(sq(O))), (0.01, f - 0.01), (f + 0.01, 0.99)


def dome(buf, rng, radius, height, col, segs=12, rings=4, lump=0.14, squash=1.0, centre=(0.0, 0.0), uv_c=(0.5, 0.5), uv_r=0.45, skirt=0.04):
    """A lumpy cushion mapped from above into `col` (a u range), its rim
    tucked under the ground."""
    ph = rng.random(4) * TAU
    grid = []
    for j in range(rings + 1):
        fr = j / rings
        row = []
        for k in range(segs + 1):
            a = TAU * (k % segs) / segs
            edge = 1 + lump * (math.sin(a * 2 + ph[0]) + 0.7 * math.sin(a * 3 + ph[1]) + 0.4 * math.sin(a * 5 + ph[2]))
            r = radius * fr * edge
            z = height * (1 - fr ** 2.2) * (1 + 0.25 * lump * math.sin(a * 3 + fr * 5 + ph[3]) * 4 * fr * (1 - fr))
            if j == rings:
                z = -skirt
            u = col[0] + (col[1] - col[0]) * (uv_c[0] + uv_r * fr * math.cos(a))
            row.append(buf.vert((centre[0] + math.cos(a) * r, centre[1] + math.sin(a) * r * squash, z), (u, uv_c[1] + uv_r * fr * math.sin(a))))
        grid.append(row)
    for j in range(rings):
        for k in range(segs):
            buf.quad(grid[j][k], grid[j + 1][k], grid[j + 1][k + 1], grid[j][k + 1])


def cushion(name, top, radius, height, seed, lobes=1, **kw):
    def fn():
        rng = np.random.default_rng(seed)
        maps, col, _ = atlas(name, top, **{k: v for k, v in kw.items() if k in ("bright", "sat")})
        buf = pc.MeshBuf()
        tile = kw.get("tile", 1.0)        # the paint repeats across a cushion: small flowers, not three big ones
        col = (0.5 - 0.5 * tile, 0.5 + 0.5 * tile)
        dome(buf, rng, radius, height, col, lump=kw.get("lump", 0.14), uv_r=0.45)
        for i in range(lobes - 1):
            a = rng.random() * TAU
            d = radius * rng.uniform(0.55, 0.8)
            s = rng.uniform(0.5, 0.75)
            dome(buf, rng, radius * s, height * rng.uniform(0.6, 1.0), col, segs=10, rings=3, lump=kw.get("lump", 0.14),
                 centre=(math.cos(a) * d, math.sin(a) * d), uv_c=(0.5 + 0.2 * math.cos(a), 0.5 + 0.2 * math.sin(a)), uv_r=0.28)
        if tile != 1.0:
            buf.uv = [(u, 0.5 + (v - 0.5) * tile) for u, v in buf.uv]
        return buf, maps
    return fn


def kelp():
    """Wrack thrown up by the tide: strap fronds lying where they fell, each
    a ribbon with a wavy edge, and the wrack's bladders in clusters."""
    rng = np.random.default_rng(301)
    maps, col, _ = atlas("veg_kelp", "kelp", bright=0.85)
    buf = pc.MeshBuf()
    for i in range(12):
        a = rng.normal(0.0, 0.5) + (math.pi if i % 2 else 0.0)        # along the tide line (X), both ways
        ln = rng.uniform(0.7, 1.5)
        w = rng.uniform(0.09, 0.2)
        x0, y0 = rng.uniform(-0.5, 0.5), rng.uniform(-0.3, 0.3)
        n = 9
        u0 = col[0] + rng.random() * (col[1] - col[0]) * 0.7
        du = (col[1] - col[0]) * 0.22
        left, right = [], []
        for k in range(n):
            t = k / (n - 1)
            bend = a + 0.6 * math.sin(t * 3 + i)
            px = x0 + math.cos(a) * ln * t + 0.08 * math.sin(t * 5 + i)
            py = y0 + math.sin(a) * ln * t + 0.08 * math.cos(t * 4 + i)
            ww = w * (0.35 + 0.65 * math.sin(math.pi * min(1.0, t * 1.15 + 0.08))) * (1 + 0.25 * math.sin(t * 17 + i))
            nx, ny = -math.sin(bend), math.cos(bend)
            z = 0.012 + 0.02 * abs(math.sin(t * 9 + i * 2)) + 0.004 * i
            left.append(buf.vert((px + nx * ww, py + ny * ww, z + 0.015 * math.sin(t * 13)), (u0, t * 1.4)))
            right.append(buf.vert((px - nx * ww, py - ny * ww, z), (u0 + du, t * 1.4)))
        for k in range(n - 1):
            buf.quad(left[k], right[k], right[k + 1], left[k + 1])
            buf.quad(left[k], left[k + 1], right[k + 1], right[k])
    for _ in range(14):
        p = (rng.uniform(-0.7, 0.7), rng.uniform(-0.35, 0.35), 0.03)
        u0 = col[0] + rng.random() * (col[1] - col[0]) * 0.8
        pc.blob(buf, rng, p, (0.035, 0.03, 0.025), 5, 3, u0, u0 + 0.1, rng.random() * 0.7, rng.random() * 0.7 + 0.15, lump=0.2)
    return buf, maps


def _leaves(buf, rng, pts, col, count, size):
    """Leaf blades along a twig: small two-sided diamonds, each turned its
    own way and drooping a little."""
    pts = np.asarray(pts, float)
    for _ in range(count):
        t = rng.uniform(0.25, 1.0)
        i = min(len(pts) - 2, int(t * (len(pts) - 1)))
        f = t * (len(pts) - 1) - i
        p = pts[i] * (1 - f) + pts[i + 1] * f
        a = rng.random() * TAU
        d = np.array([math.cos(a), math.sin(a), rng.uniform(-0.5, 0.15)])
        d /= np.linalg.norm(d)
        side = np.cross(d, (0, 0, 1.0))
        side /= max(np.linalg.norm(side), 1e-6)
        s = size * rng.uniform(0.7, 1.25)
        uc = (col[0] + (col[1] - col[0]) * rng.uniform(0.15, 0.85), rng.uniform(0.15, 0.85))
        du = (col[1] - col[0]) * 0.07
        v = [buf.vert(p, (uc[0], uc[1] - 0.07)), buf.vert(p + d * s * 0.5 + side * s * 0.36, (uc[0] + du, uc[1])),
             buf.vert(p + d * s, (uc[0], uc[1] + 0.07)), buf.vert(p + d * s * 0.5 - side * s * 0.36, (uc[0] - du, uc[1]))]
        buf.quad(*v)
        buf.quad(v[0], v[3], v[2], v[1])


def hazel_stool(bare):
    def fn():
        rng = np.random.default_rng(311)
        maps, col, bark = atlas("veg_hazel", "leaves", bark_rgb=(0.27, 0.21, 0.15), bright=0.95)
        buf = pc.MeshBuf()
        # the stool: an old cut stump, wider than it is high, mossed
        pc.blob(buf, rng, (0, 0, 0.05), (0.3, 0.27, 0.14), 9, 5, bark[0], bark[1], 0.0, 0.5, lump=0.18)
        for k in range(11):
            a = TAU * k / 11 + rng.normal(0, 0.2)
            out = rng.uniform(0.25, 0.75)
            ln = rng.uniform(1.5, 2.5)
            base = np.array([math.cos(a) * 0.17, math.sin(a) * 0.17, 0.1])
            pts = [base]
            for s in range(1, 5):
                t = s / 4
                pts.append(base + np.array([math.cos(a) * out * ln * t * (0.6 + 0.5 * t), math.sin(a) * out * ln * t * (0.6 + 0.5 * t),
                                            ln * t * (1 - 0.12 * t)]) + rng.normal(0, 0.02, 3))
            r0 = rng.uniform(0.014, 0.024)
            pc.tube(buf, pts, [r0, r0 * 0.85, r0 * 0.65, r0 * 0.45, r0 * 0.22], 4, bark[0], bark[1], 2.0, v0=rng.random())
            if not bare:
                _leaves(buf, rng, pts, col, 34, 0.17)
        return buf, maps
    return fn


def birch_sapling(bare):
    def fn():
        rng = np.random.default_rng(321)
        maps, col, bark = atlas("veg_birch", "leaves", bark_rgb=(0.70, 0.67, 0.60), bright=1.05)
        buf = pc.MeshBuf()
        h = 2.6
        stem = [np.array([0.03 * math.sin(t * 5), 0.03 * math.cos(t * 4), h * t]) for t in np.linspace(0, 1, 7)]
        pc.tube(buf, stem, [0.028, 0.025, 0.021, 0.017, 0.012, 0.008, 0.004], 5, bark[0], bark[1], 1.6)
        if not bare:
            _leaves(buf, rng, stem[3:], col, 26, 0.12)
        for k in range(9):
            t = 0.3 + 0.62 * k / 8
            p = np.array([0.0, 0.0, h * t])
            a = k * 2.4 + rng.normal(0, 0.3)
            ln = (1.0 - t) * 1.1 + 0.25
            tw = [p + np.array([math.cos(a) * ln * s, math.sin(a) * ln * s, ln * s * (0.75 - 0.5 * s)]) for s in (0, 0.35, 0.7, 1.0)]
            pc.tube(buf, tw, [0.01, 0.008, 0.005, 0.003], 3, bark[0], bark[1], 2.0)
            if not bare:
                _leaves(buf, rng, tw, col, 24, 0.12)
        return buf, maps
    return fn


def juniper():
    """Prostrate juniper: woody stems creeping out from one root, each
    carrying a long low pad of needles pressed to the rock."""
    rng = np.random.default_rng(331)
    maps, col, bark = atlas("veg_juniper", "juniper", bark_rgb=(0.30, 0.25, 0.20))
    buf = pc.MeshBuf()
    for k in range(6):
        a = TAU * k / 6 + rng.normal(0, 0.25)
        ln = rng.uniform(0.55, 1.0)
        pts = [(0, 0, 0.03), (math.cos(a) * ln * 0.5, math.sin(a) * ln * 0.5, 0.08), (math.cos(a) * ln, math.sin(a) * ln, 0.05)]
        pc.tube(buf, pts, [0.022, 0.016, 0.008], 4, bark[0], bark[1], 2.0)
        for s in (0.55, 0.95):
            c = (math.cos(a) * ln * s, math.sin(a) * ln * s)
            xf = pc.xform(pos=(c[0], c[1], 0.0), rot_z=a)
            sub = pc.MeshBuf()
            dome(sub, rng, 0.3 * rng.uniform(0.8, 1.2), rng.uniform(0.13, 0.22), col, segs=9, rings=3, lump=0.2, squash=0.62,
                 uv_c=(rng.uniform(0.3, 0.7), rng.uniform(0.3, 0.7)), uv_r=0.26)
            buf.merge(sub, xf)
    dome(buf, rng, 0.3, 0.2, col, segs=9, rings=3, lump=0.2)
    return buf, maps


PIECES = {
    "veg_thrift_cushion": cushion("veg_thrift", "thrift", 0.3, 0.16, 201, lobes=2, tile=1.6),
    "veg_kelp": kelp,
    "veg_sphagnum": cushion("veg_sphagnum", "sphagnum", 0.5, 0.26, 211, lobes=3, lump=0.18, bright=0.9, tile=1.5),
    "veg_crowberry": cushion("veg_crowberry", "crowberry", 0.62, 0.07, 221, lobes=3, lump=0.26, bright=1.15, tile=1.5),
    "veg_moss_cushion": cushion("veg_moss", "moss", 0.4, 0.15, 231, lobes=3, lump=0.2, bright=0.6, sat=0.8, tile=1.5),
    "veg_hazel_stool": hazel_stool(False),
    "veg_hazel_stool_bare": hazel_stool(True),
    "veg_birch_sapling": birch_sapling(False),
    "veg_birch_sapling_bare": birch_sapling(True),
    "veg_juniper": juniper,
    "veg_saxifrage": cushion("veg_saxifrage", "saxifrage", 0.27, 0.11, 241, lobes=2, tile=2.4),
    "veg_starmoss": cushion("veg_starmoss", "starmoss", 0.5, 0.05, 251, lobes=3, lump=0.24, bright=0.9, tile=2.0),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    for name, fn in PIECES.items():
        if a.only and a.only != name:
            continue
        buf, maps = fn()
        pc.export_glb(os.path.join(OUT, name + ".glb"), name, buf, maps)


if __name__ == "__main__":
    main()
