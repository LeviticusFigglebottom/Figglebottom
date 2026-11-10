#!/usr/bin/env python3
"""The rimed frame of a frost veil (look pass 5): grown ice round the gap a
veil hangs in, so the gate has thickness and a silhouette from the side.

Clusters of ice crystals (tapered hexagonal prisms) grow from the ground up
both jambs and meet overhead in a pointed arch, the same arch the veil
shader fades to; icicles hang from the arch; snow is banked at the feet and
caught on the bigger clusters. Authored for the standard 3.4 m x 5.1 m veil;
FrostVeil scales it to the plane it is given.

Atlas: CC0 `ice` set (u 0-0.74) and `snow` set (u 0.76-1).
Out: assets/models/landmarks/lm_veil_rime.glb

Run: $BPY tools/art/procedural/veil_frame.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402
import thorn_rime as tr  # noqa: E402  (snow clumps and drifts: same snow column)

TAU = math.tau
U_ICE = (0.01, 0.74)


def atlas():
    ice = pc.load_set("ice", 1024)
    snow = pc.load_set("snow", 1024)
    a = np.zeros((1024, 1024, 3), np.float32)
    n = np.zeros_like(a)
    o = np.zeros_like(a)
    a[:, :768] = ice["albedo"][:, :768]
    n[:, :768] = ice["normal"][:, :768]
    o[:, :768] = ice["orh"][:, :768]
    o[:, :768, 1] = np.clip(o[:, :768, 1] * 0.8, 0.12, 1)
    a[:, 768:] = snow["albedo"][:, :256]
    n[:, 768:] = snow["normal"][:, :256]
    o[:, 768:] = snow["orh"][:, :256]
    return pc.save_maps("veil_rime", a, n, pc.orh_to_orm(o))


def crystal(buf, rng, base, direction, length, radius, sides=6):
    """A tapered prism with a faceted point; each face is flat-shaded."""
    d = np.asarray(direction, dtype=float)
    d /= np.linalg.norm(d)
    ref = np.array([0.0, 0.0, 1.0]) if abs(d[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    a1 = np.cross(d, ref)
    a1 /= np.linalg.norm(a1)
    a2 = np.cross(d, a1)
    ph = rng.random() * TAU
    shoulder = length * rng.uniform(0.55, 0.8)
    r1 = radius * rng.uniform(0.7, 0.95)
    u0 = U_ICE[0] + rng.random() * (U_ICE[1] - U_ICE[0] - 0.2)
    v0 = rng.random()
    tip = np.asarray(base) + d * length + (a1 * rng.normal(0, 0.15) + a2 * rng.normal(0, 0.15)) * radius
    for k in range(sides):
        q0, q1 = ph + TAU * k / sides, ph + TAU * (k + 1) / sides
        ua, ub = u0 + 0.2 * k / sides, u0 + 0.2 * (k + 1) / sides

        def ring(q, r, h):
            return np.asarray(base) + d * h + r * (math.cos(q) * a1 + math.sin(q) * a2)
        # separate verts per face: hard facets
        b0 = buf.vert(ring(q0, radius, -0.05), (ua, v0))
        b1 = buf.vert(ring(q1, radius, -0.05), (ub, v0))
        s1 = buf.vert(ring(q1, r1, shoulder), (ub, v0 + shoulder * 0.8))
        s0 = buf.vert(ring(q0, r1, shoulder), (ua, v0 + shoulder * 0.8))
        buf.quad(b0, b1, s1, s0)
        t0 = buf.vert(ring(q0, r1, shoulder), (ua, v0 + shoulder * 0.8))
        t1 = buf.vert(ring(q1, r1, shoulder), (ub, v0 + shoulder * 0.8))
        tt = buf.vert(tip, ((ua + ub) * 0.5, v0 + length * 0.8))
        buf.tri(t0, t1, tt)


def arch_path(n=44, half_w=1.62, spring=2.9, apex=4.95):
    """Up the left jamb, over the pointed arch, down the right jamb: points
    and inward normals in the veil's plane (x across, z up)."""
    pts = []
    for i in range(n):
        t = i / (n - 1)
        if t < 0.3:
            pts.append((-half_w, spring * t / 0.3))
        elif t > 0.7:
            pts.append((half_w, spring * (1 - t) / 0.3))
        else:
            s = (t - 0.3) / 0.4 * 2 - 1          # -1..1 across the arch
            x = half_w * (math.sin(s * math.pi / 2))
            z = spring + (apex - spring) * (1 - abs(s) ** 1.5)
            pts.append((x, z))
    return pts


def main():
    rng = np.random.default_rng(17)
    buf = pc.MeshBuf()
    path = arch_path()
    for i, (x, z) in enumerate(path):
        t = i / (len(path) - 1)
        on_arch = 0.3 <= t <= 0.7
        inward = np.array([-x, 0.0, (2.6 - z)])
        inward /= max(np.linalg.norm(inward), 1e-6)
        # thick at the feet (it grew from the ground), thinner overhead
        low = 1.0 - min(z / 3.0, 1.0)
        n_here = 3 + int(5 * low)
        for _ in range(n_here):
            base = np.array([x + rng.normal(0, 0.1), rng.normal(0, 0.16 + 0.12 * low), max(z + rng.normal(0, 0.08), 0.0)])
            out = -inward
            # crystals splay outward and to both faces; a few reach in
            d = out * rng.uniform(0.2, 1.0) + np.array([0, rng.normal(0, 0.7), 0]) + np.array([0, 0, rng.uniform(-0.2, 0.9)])
            if rng.random() < 0.22:
                d = inward * 0.8 + np.array([0, rng.normal(0, 0.5), rng.normal(0, 0.3)])
            if base[2] < 0.5:
                d[2] = abs(d[2]) + 0.3   # nothing grows down into the ground
            ln = rng.uniform(0.16, 0.5) * (1.0 + 0.9 * low)
            crystal(buf, rng, base, d, ln, ln * rng.uniform(0.12, 0.2))
        if on_arch and rng.random() < 0.9:
            # icicles: hang true, longest near the springing
            for _ in range(2):
                ln = rng.uniform(0.2, 0.75) * (0.6 + 0.6 * abs(x) / 1.62)
                crystal(buf, rng, (x + rng.normal(0, 0.06), rng.normal(0, 0.1), z + 0.05),
                        (rng.normal(0, 0.04), rng.normal(0, 0.04), -1.0), ln, rng.uniform(0.025, 0.05), sides=5)
        if rng.random() < 0.3 and z > 0.4:
            tr.snow_clump(buf, rng, np.array([x * 1.03, rng.normal(0, 0.1), z + 0.08]), rng.uniform(0.08, 0.16))
    # snow banked against both feet
    for sx in (-1, 1):
        d = pc.MeshBuf()
        tr.drift(d, rng, 0.75, 0.55, 0.32, segs=6, rows=2)
        buf.merge(d, pc.xform(pos=(sx * 1.75, 0, 0)))
    out = os.path.join(pc.ROOT, "assets", "models", "landmarks", "lm_veil_rime.glb")
    pc.export_glb(out, "lm_veil_rime", buf, atlas(), smooth=False)


if __name__ == "__main__":
    main()
