#!/usr/bin/env python3
"""Frozen thorn for Thornwold's RIME state, modelled instead of generated
(look pass 5: the stretched Tripo section read as flat glassy shards).

Each piece grows a real skeleton and skins it:
  - stems and arching canes rise from the ground (canes bend over under
    their own weight, as blackthorn and bramble do);
  - space colonisation (Runions et al.) fills the piece's volume with
    branching twigs from every stem, so the mass is tangled, not combed;
  - radii follow the pipe model, so forks thicken toward the root;
  - a low-frequency displacement kinks everything (gnarl);
  - tubes are skinned with parallel-transport frames, thorns are set along
    the thinner wood, snow sits in the forks and drifts at the foot.

UVs pick one of three columns of a 1024 atlas built from the CC0 bark and
snow sets (assets/textures/{bark,snow}): bare bark for the thick wood,
hoar-frosted bark for twigs and thorns, snow for the clumps. The RIME snow
crust on top faces comes from the hall shader (family M_thorn_rime).

Pieces (assets/models/forest/, each with a <name>_far.glb built from the
same skeleton, not decimated: thin twigs are dropped, the rest thickened):
  hd_thorn3a, hd_thorn3b   hedge section, 2.4 m x 3.2 m x 1.3 m, along X
  hd_thorn_heap            the mound that plugs the drove road, 4.4 m across
  hd_thornwall             the Hedgelayer's raised wall, 1.6 m x 3 m, clawing up

Run: $BPY tools/art/procedural/thorn_rime.py [--only name]
"""
import argparse
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402

OUT = os.path.join(pc.ROOT, "assets", "models", "forest")
# atlas columns (u ranges, inset against mip bleed)
U_BARK = (0.01, 0.49)
U_FROST = (0.51, 0.74)
U_SNOW = (0.76, 0.99)
V_PER_M = 2.2          # bark repeats per metre along a branch
BARK_ACROSS_M = 0.22   # metres of bark the bark column spans


def atlas():
    bark = pc.load_set("bark", 1024)
    snow = pc.load_set("snow", 1024)
    a = np.zeros((1024, 1024, 3), np.float32)
    n = np.zeros_like(a)
    o = np.zeros_like(a)
    rng = np.random.default_rng(5)
    # bare bark, darkened: wet black wood under the frost
    a[:, :512] = bark["albedo"][:, :512] * 0.8
    n[:, :512] = bark["normal"][:, :512]
    o[:, :512] = bark["orh"][:, :512]
    # hoar frost: settles on the ridges of the bark first (height in orh B)
    # and in soft patches; the furrows stay dark
    h = bark["orh"][:, 512:768, 2]
    yy, xx = np.mgrid[0:1024, 0:256]
    patch = np.zeros((1024, 256), np.float32)
    for _ in range(14):
        fy, fx = rng.integers(1, 5), rng.integers(1, 3)
        patch += np.sin(yy * TAU * fy / 1024 + rng.random() * TAU) * np.sin(xx * TAU * fx / 256 + rng.random() * TAU)
    patch = patch / 6.0
    frost = np.clip((h - h.mean()) * 3.2 + 0.62 + patch * 0.45, 0, 1)[..., None]
    grain = (rng.random((1024, 256, 1)) * 0.12 + 0.94).astype(np.float32)
    a[:, 512:768] = bark["albedo"][:, 512:768] * 0.8 * (1 - frost) + np.array([0.80, 0.86, 0.93]) * frost * grain
    n[:, 512:768] = bark["normal"][:, 512:768]
    o[:, 512:768] = bark["orh"][:, 512:768]
    o[:, 512:768, 1] = o[:, 512:768, 1] * (1 - frost[..., 0]) + 0.62 * frost[..., 0]
    a[:, 768:] = snow["albedo"][:, :256]
    n[:, 768:] = snow["normal"][:, :256]
    o[:, 768:] = snow["orh"][:, :256]
    return pc.save_maps("thorn_rime", a, n, pc.orh_to_orm(o))


TAU = math.tau


class Skel:
    def __init__(self):
        self.p = []
        self.par = []

    def add(self, pos, parent):
        self.p.append(np.asarray(pos, dtype=float))
        self.par.append(parent)
        return len(self.p) - 1


def cane(sk, rng, start, heading, length, rise, droop, step=0.1, wobble=0.25, xlim=None, ylim=None):
    """A stem that climbs and then bends over under its own weight."""
    d = np.array([math.cos(heading) * (1 - rise), math.sin(heading) * (1 - rise), rise + 0.4])
    d /= np.linalg.norm(d)
    cur = sk.add(start, -1)
    pos = np.array(start, dtype=float)
    run = 0.0
    while run < length:
        d = d + np.array([0, 0, -droop * step]) + rng.normal(0, wobble * step, 3)
        d /= np.linalg.norm(d)
        if xlim is not None and abs(pos[0] + d[0] * step) > xlim:
            d[0] = -d[0]   # a laid stem is woven back into its own section
        if ylim is not None and abs(pos[1] + d[1] * step) > ylim:
            d[1] = -d[1]
        pos = pos + d * step
        if pos[2] < 0.04:
            break
        cur = sk.add(pos, cur)
        run += step
    return cur


def colonise(sk, rng, attractors, step=0.09, infl=0.5, kill=0.15, iters=120, jitter=0.3, tropism=(0, 0, 0.0)):
    att = np.array(attractors, dtype=float)
    trop = np.array(tropism, dtype=float)
    for _ in range(iters):
        if len(att) == 0:
            break
        nodes = np.array(sk.p)
        d = np.linalg.norm(att[:, None, :] - nodes[None, :, :], axis=2)
        near = d.argmin(axis=1)
        dmin = d[np.arange(len(att)), near]
        live = dmin < infl
        grew = False
        for ni in np.unique(near[live]):
            pull = att[live & (near == ni)] - nodes[ni]
            pull /= np.maximum(np.linalg.norm(pull, axis=1, keepdims=True), 1e-9)
            v = pull.mean(axis=0) + rng.normal(0, jitter, 3) + trop
            ln = np.linalg.norm(v)
            if ln < 1e-6:
                continue
            new = nodes[ni] + v / ln * step
            if new[2] < 0.03:
                new[2] = 0.03
            # no second child on top of an existing one
            if np.min(np.linalg.norm(nodes - new, axis=1)) < step * 0.45:
                continue
            sk.add(new, int(ni))
            grew = True
        att = att[dmin > kill]
        if not grew:
            break


def gnarl(sk, rng, amp=0.07, freq=2.4):
    """Kink the whole skeleton with a smooth vector field (two octaves)."""
    P = np.array(sk.p)
    out = np.zeros_like(P)
    for a, f in ((amp, freq), (amp * 0.4, freq * 2.7)):
        for _ in range(4):
            k = rng.normal(0, f, 3)
            ph = rng.random() * TAU
            axis = rng.normal(0, 1, 3)
            axis /= np.linalg.norm(axis)
            out += a * 0.5 * np.sin(P @ k + ph)[:, None] * axis
    # the foot stays planted
    out *= np.clip(P[:, 2:3] / 0.35, 0, 1)
    sk.p = list(P + out)


def radii(sk, tip=0.0055, power=2.25, grow=0.00035, rmax=0.07):
    n = len(sk.p)
    acc = np.zeros(n)
    r = np.full(n, tip)
    kids = [[] for _ in range(n)]
    for i, pa in enumerate(sk.par):
        if pa >= 0:
            kids[pa].append(i)
    for i in range(n - 1, -1, -1):
        if kids[i]:
            r[i] = min(max(acc[i] ** (1 / power), max(r[k] for k in kids[i]) + grow), rmax)
        pa = sk.par[i]
        if pa >= 0:
            acc[pa] += r[i] ** power
    return r, kids


def chains(sk, r, kids):
    """Split the tree into runs: each node hands on to its thickest (then
    longest) child; the others start a run of their own from the fork."""
    depth = np.zeros(len(sk.p))
    for i in range(len(sk.p) - 1, -1, -1):
        if kids[i]:
            depth[i] = 1 + max(depth[k] for k in kids[i])
    out = []
    starts = [(i, -1) for i, pa in enumerate(sk.par) if pa < 0]
    while starts:
        i, fork = starts.pop()
        run = [fork] if fork >= 0 else []
        while True:
            run.append(i)
            if not kids[i]:
                break
            ks = sorted(kids[i], key=lambda k: (r[k], depth[k]), reverse=True)
            for k in ks[1:]:
                starts.append((k, i))
            i = ks[0]
        if len(run) >= 2:
            out.append(run)
    return out


def simplify(pts, rad, eps):
    """Ramer-Douglas-Peucker on a run, keeping the radii of the kept points."""
    keep = np.zeros(len(pts), bool)
    keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        a, b = stack.pop()
        if b - a < 2:
            continue
        seg = pts[b] - pts[a]
        ln = np.linalg.norm(seg)
        rel = pts[a + 1:b] - pts[a]
        if ln < 1e-9:
            d = np.linalg.norm(rel, axis=1)
        else:
            d = np.linalg.norm(np.cross(rel, seg / ln), axis=1)
        k = int(d.argmax())
        if d[k] > eps:
            keep[a + 1 + k] = True
            stack.append((a, a + 1 + k))
            stack.append((a + 1 + k, b))
    return pts[keep], rad[keep]


def snow_clump(buf, rng, centre, size, sides=7):
    """A lump of caught snow: a flattened, lopsided dome with a short skirt."""
    u0, u1 = U_SNOW
    uc = ((u0 + u1) * 0.5, rng.random())
    ur = (u1 - u0) * 0.45
    top = buf.vert(centre + np.array([rng.normal(0, size * 0.15), rng.normal(0, size * 0.15), size * 0.55]), uc)
    rings = []
    for fr, fz, fu in ((0.6, 0.42, 0.5), (0.88, 0.1, 0.85), (0.55, -0.12, 1.0)):
        ring = []
        for k in range(sides + 1):
            a = TAU * (k % sides) / sides
            wob = 1.0 + 0.28 * math.sin(a * 2 + centre[0] * 9) + 0.15 * math.sin(a * 3 + centre[1] * 7)
            p = centre + np.array([math.cos(a) * size * fr * wob, math.sin(a) * size * fr * wob, size * fz])
            ring.append(buf.vert(p, (uc[0] + ur * fu * math.cos(a), uc[1] + ur * fu * math.sin(a) * 0.25)))
        rings.append(ring)
    for k in range(sides):
        buf.tri(top, rings[0][k], rings[0][k + 1])
        for a, b in ((0, 1), (1, 2)):
            buf.quad(rings[a][k], rings[b][k], rings[b][k + 1], rings[a][k + 1])


def drift(buf, rng, half_len, half_w, height, segs=10, rows=3):
    """Snow banked along the foot: a long low ridge with a ragged edge."""
    u0, u1 = U_SNOW
    grid = []
    for i in range(segs + 1):
        x = -half_len + 2 * half_len * i / segs
        row = []
        endf = math.sin(math.pi * i / segs) ** 0.5 * 0.5 + 0.5
        for j in range(-rows, rows + 1):
            t = j / rows
            w = half_w * (1.0 + 0.25 * math.sin(x * 3.1 + j) + rng.normal(0, 0.06))
            z = height * endf * max(0.0, 1 - t * t) ** 1.5 * (1 + 0.35 * math.sin(x * 2.3 + 1.7)) - 0.03
            row.append(buf.vert((x, t * w, z), (u0 + (u1 - u0) * (t * 0.5 + 0.5), x * 0.8)))
        grid.append(row)
    for i in range(segs):
        for j in range(2 * rows):
            buf.quad(grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1])


def skin(sk, rng, far=False, thorn_every=0.11, snow_n=34, drift_dims=None, fat=1.0):
    r, kids = radii(sk)
    r = r * fat
    buf = pc.MeshBuf()
    P = np.array(sk.p)
    n_thorn = 0
    forks = []
    for run in chains(sk, r, kids):
        pts = P[run]
        rad = r[run].copy()
        # a side run starts inside its parent, at its own child's girth
        if sk.par[run[1]] == run[0] and len(run) > 2:
            rad[0] = rad[1] * 1.15
        length = float(np.sum(np.linalg.norm(np.diff(pts, axis=0), axis=1)))
        rmaxc = float(rad.max())
        if far:
            # the middle distance keeps the wood that carries the silhouette,
            # thickened so it still covers a pixel
            if rmaxc < 0.0105 or length < 0.4:
                continue
            pts, rad = simplify(pts, rad, 0.075)
            rad = np.maximum(rad * 1.6, 0.014)
            sides = 3
        else:
            pts, rad = simplify(pts, rad, 0.006 if rmaxc > 0.012 else 0.011)
            sides = 7 if rmaxc > 0.035 else (5 if rmaxc > 0.016 else (4 if rmaxc > 0.008 else 3))
        if len(pts) < 2:
            continue
        frosted = rmaxc < 0.014
        col = U_FROST if frosted else U_BARK
        across = (U_FROST[1] - U_FROST[0]) if frosted else (U_BARK[1] - U_BARK[0])
        span = min(TAU * rmaxc / BARK_ACROSS_M, 1.0) * across
        u0 = col[0] + rng.random() * (across - span)
        rad_t = rad.copy()
        rad_t[-1] = max(rad_t[-1] * 0.35, 0.0012)
        pc.tube(buf, pts, rad_t, sides, u0, u0 + span, V_PER_M, v0=rng.random(), cap_end=False)
        if far:
            continue
        # thorns: on wood up to a finger thick, alternate sides, raked forward
        if rmaxc < 0.03:
            t, nn, bb = pc.frames(pts)
            acc = rng.random() * thorn_every
            for i in range(1, len(pts)):
                seg = np.linalg.norm(pts[i] - pts[i - 1])
                acc += seg
                while acc > thorn_every:
                    acc -= thorn_every * rng.uniform(0.7, 1.4)
                    a = rng.random() * TAU
                    side = math.cos(a) * nn[i] + math.sin(a) * bb[i]
                    d = side + t[i] * rng.uniform(0.1, 0.6)
                    d /= np.linalg.norm(d)
                    ln = rng.uniform(0.028, 0.07)
                    br = max(rad[i] * 0.55, 0.0028)
                    base = pts[i] + side * rad[i] * 0.6
                    o1 = np.cross(d, t[i])
                    o1 /= max(np.linalg.norm(o1), 1e-9)
                    o2 = np.cross(d, o1)
                    uf = U_FROST[0] + rng.random() * 0.18
                    vf = rng.random()
                    vs = [buf.vert(base + br * (math.cos(q) * o1 + math.sin(q) * o2), (uf + 0.02 * k, vf)) for k, q in enumerate((0, TAU / 3, 2 * TAU / 3))]
                    tip = buf.vert(base + d * ln, (uf + 0.02, vf + 0.08))
                    for k in range(3):
                        buf.tri(vs[k], vs[(k + 1) % 3], tip)
                    n_thorn += 1
    # snow in the forks: the stoutest forks first, biggest lumps low down
    for i, ks in enumerate(kids):
        if len(ks) >= 2 and r[i] > 0.011 and P[i][2] > 0.3 and rng.random() < 0.6:
            forks.append((r[i], i))
    forks.sort(reverse=True)
    step = max(1, len(forks) // max(snow_n, 1))
    picked = forks[::step][:snow_n] if not far else forks[::step][:snow_n // 3]
    for rr, i in picked:
        size = float(np.clip(rr * 2.2 + rng.uniform(0.0, 0.07) ** 1.0, 0.03, 0.13)) * (1.5 if far else 1.0)
        snow_clump(buf, rng, P[i] + np.array([0, 0, rr * 0.5]), size, sides=4 if far else 7)
    if drift_dims:
        drift(buf, rng, *drift_dims, segs=4 if far else 10, rows=1 if far else 3)
    return buf, n_thorn


def box_points(rng, n, half_len, half_w, height, shell=0.55):
    """Attraction points for a hedge: a ragged-topped slab, denser toward
    its faces (a hedge is leaf-out on the outside and hollow in the core)."""
    pts = []
    while len(pts) < n:
        x = rng.uniform(-half_len, half_len)
        top = height * (0.78 + 0.22 * math.sin(x * 2.9 + 0.6) * math.sin(x * 1.3 + 2.0) + rng.normal(0, 0.05))
        z = rng.uniform(0.12, max(top, 0.3))
        taper = 1.0 - 0.35 * (z / height) ** 2
        y = rng.uniform(-1, 1)
        if rng.random() < shell:
            y = math.copysign(abs(y) ** 0.35, y)
        pts.append((x, y * half_w * taper, z))
    return pts


def hedge(seed):
    rng = np.random.default_rng(seed)
    sk = Skel()
    for i in range(13):
        x = -1.2 + 2.4 * (i + rng.uniform(0.2, 0.8)) / 13
        y = rng.uniform(-0.3, 0.3)
        heading = rng.choice([0.0, math.pi]) + rng.normal(0, 0.5)
        # pleachers: half the stems are laid over along the line, half stand
        if i % 2 == 0:
            cane(sk, rng, (x, y, 0.0), heading, rng.uniform(1.8, 2.6), 0.45, 0.55, xlim=1.3, ylim=0.6)
        else:
            cane(sk, rng, (x, y, 0.0), heading, rng.uniform(2.2, 3.1), 0.9, 0.12, xlim=1.3, ylim=0.6)
    colonise(sk, rng, box_points(rng, 1000, 1.3, 0.62, 3.2), jitter=0.32, infl=0.45, kill=0.11, iters=220)
    gnarl(sk, rng)
    return sk, rng, (1.25, 0.6, 0.22)


def heap(seed):
    rng = np.random.default_rng(seed)
    sk = Skel()
    for i in range(22):
        a = rng.random() * TAU
        rad = rng.uniform(0.2, 1.7)
        cane(sk, rng, (math.cos(a) * rad, math.sin(a) * rad * 0.6, 0.0), a + rng.normal(0, 1.2),
             rng.uniform(1.8, 3.4), rng.uniform(0.35, 0.85), rng.uniform(0.5, 0.9), wobble=0.35, xlim=2.2, ylim=0.95)
    pts = []
    while len(pts) < 1300:
        p = rng.uniform(-1, 1, 3)
        p[2] = abs(p[2])
        if np.linalg.norm(p) > 1 or np.linalg.norm(p) < 0.35 * rng.random():
            continue
        pts.append((p[0] * 2.15, p[1] * 0.95, 0.1 + p[2] * 2.7))
    colonise(sk, rng, pts, jitter=0.4, infl=0.5, kill=0.12, iters=220)
    gnarl(sk, rng, amp=0.1)
    return sk, rng, (2.0, 0.95, 0.3)


def wall(seed):
    rng = np.random.default_rng(seed)
    sk = Skel()
    for i in range(9):
        x = -0.7 + 1.4 * (i + rng.uniform(0.2, 0.8)) / 9
        cane(sk, rng, (x, rng.uniform(-0.18, 0.18), 0.0), rng.random() * TAU, rng.uniform(2.4, 3.2), 0.95,
             rng.uniform(-0.05, 0.2), wobble=0.4)
    pts = []
    while len(pts) < 520:
        x = rng.uniform(-0.85, 0.85)
        z = rng.uniform(0.15, 3.0 * (0.8 + 0.2 * math.sin(x * 5.0)))
        pts.append((x, rng.normal(0, 0.2) * (1.0 - 0.5 * z / 3.0), z))
    # it was raised, not grown: everything claws upward
    colonise(sk, rng, pts, jitter=0.3, tropism=(0, 0, 0.35), kill=0.11, iters=200)
    gnarl(sk, rng, amp=0.09, freq=3.0)
    return sk, rng, None


PIECES = {
    "hd_thorn3a": (hedge, 11, 20),
    "hd_thorn3b": (hedge, 29, 20),
    "hd_thorn_heap": (heap, 7, 36),
    "hd_thornwall": (wall, 3, 10),
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    maps = atlas()
    maps_far = pc.half_maps(maps)
    for name, (fn, seed, snow_n) in PIECES.items():
        if a.only and a.only != name:
            continue
        sk, rng, dd = fn(seed)
        near, n_thorn = skin(sk, np.random.default_rng(seed + 1), False, snow_n=snow_n, drift_dims=dd)
        print("[thorn] %s: %d nodes, %d thorns" % (name, len(sk.p), n_thorn))
        pc.export_glb(os.path.join(OUT, name + ".glb"), name, near, maps)
        far, _ = skin(sk, np.random.default_rng(seed + 1), True, snow_n=snow_n, drift_dims=dd)
        pc.export_glb(os.path.join(OUT, name + "_far.glb"), name + "_far", far, maps_far)


if __name__ == "__main__":
    main()
