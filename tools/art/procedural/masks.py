#!/usr/bin/env python3
"""Carved mourning masks as real geometry (look pass 5: the pegs after the
Outsong showed a band on a blank oval). STYLE.md: a smooth board of pale
birch, two eye holes and one carved brow line, a household band painted
across the eyes.

The board is a dished oval a finger thick. The eye holes go right through
it (cells of the grid are left out and the cut walled, the rim of each hole
snapped to a true ellipse); the brow is a groove cut into the face; the
woad band is paint, in the atlas.

Out: assets/models/props/mourning_mask.glb (0.26 m), child_mask.glb (0.17 m);
face to the game's +Z, foot at the origin. small_props.py wraps each in the
.tscn the pickups and the pegs already load.

Run: $BPY tools/art/procedural/masks.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402

OUT = os.path.join(pc.ROOT, "assets", "models", "props")
EYE = (0.40, 0.14, 0.19, 0.105)    # centre x, centre y (of the half-size), radii


def in_eye(x, y, grow=1.0):
    for sx in (-1, 1):
        if ((x - sx * EYE[0]) / (EYE[2] * grow)) ** 2 + ((y - EYE[1]) / (EYE[3] * grow)) ** 2 < 1.0:
            return sx
    return 0


def mask(name, h):
    w = h * 0.68
    maps, (birch, woad, cut) = pc.make_atlas(name, [
        ("timber", pc.tint((0.74, 0.67, 0.54), 0.5, rough=0.55)),
        ("timber", pc.tint((0.17, 0.25, 0.40), 0.6, rough=0.8)),
        ("timber", pc.tint((0.10, 0.08, 0.07), 0.4, rough=0.9))], size=512)
    buf = pc.MeshBuf()
    nx, ny = 34, 44
    thick = h * 0.085

    def pos(i, j):
        """Grid point -> unit-disc coords, with the points round each eye
        pulled onto the hole's ellipse so the cut is round, not stepped."""
        x = (i / nx) * 2 - 1
        y = (j / ny) * 2 - 1
        # square grid to oval: keep the grid lines, squeeze the corners in
        ox = x * math.sqrt(max(1 - 0.5 * y * y, 0))
        oy = y * math.sqrt(max(1 - 0.5 * x * x, 0))
        for sx in (-1, 1):
            dx, dy = (ox - sx * EYE[0]) / EYE[2], (oy - EYE[1]) / EYE[3]
            d = math.hypot(dx, dy)
            if 0.55 < d < 1.3:
                k = 1.0 / d
                ox, oy = sx * EYE[0] + dx * k * EYE[2], EYE[1] + dy * k * EYE[3]
        return ox, oy

    def surf(ox, oy, front):
        """Disc coords -> Blender position. Dished like a shallow bowl, the
        brow a groove on the front, edges thinned."""
        r2 = ox * ox + oy * oy
        dish = -h * 0.11 * (1 - r2)            # bulges toward the viewer (-Y)
        edge = 1.0 - 0.6 * max(r2 - 0.7, 0) / 0.3
        yy = dish - thick * 0.5 * edge if front else dish + thick * 0.5 * edge
        if front:
            # the brow: one line carved over both eyes, a shallow V section
            bx = abs(ox)
            by = 0.42 - 0.06 * (bx / 0.7) ** 2
            if bx < 0.72:
                g = max(0.0, 1 - abs(oy - by) / 0.035)
                yy += h * 0.022 * g * min(1.0, (0.72 - bx) / 0.1)
        return (ox * w * 0.5, yy, h * 0.5 + oy * h * 0.5)

    def uv(ox, oy, col):
        return (col[0] + (col[1] - col[0]) * (ox * 0.5 + 0.5), 0.2 + 0.3 * (oy * 0.5 + 0.5))

    keep = {}
    for j in range(ny):
        for i in range(nx):
            cs = [pos(i + a, j + b) for a, b in ((0, 0), (1, 0), (1, 1), (0, 1))]
            cx, cy = np.mean([c[0] for c in cs]), np.mean([c[1] for c in cs])
            keep[(i, j)] = not in_eye(cx, cy, 0.97)
    for j in range(ny):
        for i in range(nx):
            if not keep[(i, j)]:
                continue
            cs = [pos(i + a, j + b) for a, b in ((0, 0), (1, 0), (1, 1), (0, 1))]
            cy = np.mean([c[1] for c in cs])
            # the band: painted straight across at eye height
            band = abs(cy - EYE[1]) < 0.2
            col = woad if band else birch
            cx = abs(np.mean([c[0] for c in cs]))
            if cx < 0.7 and abs(cy - (0.42 - 0.06 * (cx / 0.7) ** 2)) < 0.03:
                col = cut      # the cut of the brow holds the dirt: it reads dark
            f = [buf.vert(surf(c[0], c[1], True), uv(c[0], c[1], col)) for c in cs]
            buf.quad(f[0], f[1], f[2], f[3])
            b = [buf.vert(surf(c[0], c[1], False), uv(c[0], c[1], birch)) for c in cs]
            buf.quad(b[3], b[2], b[1], b[0])
            # wall every open edge: the rim of the board and the eye holes
            for (a0, a1), (di, dj) in (((0, 1), (0, -1)), ((1, 2), (1, 0)), ((2, 3), (0, 1)), ((3, 0), (-1, 0))):
                ni, nj = i + di, j + dj
                if 0 <= ni < nx and 0 <= nj < ny and keep[(ni, nj)]:
                    continue
                hole = 0 <= ni < nx and 0 <= nj < ny
                c = cut if hole else birch
                p0, p1 = cs[a0], cs[a1]
                q = [buf.vert(surf(p0[0], p0[1], True), (c[0] + 0.02, 0.0)), buf.vert(surf(p1[0], p1[1], True), (c[0] + 0.06, 0.0)),
                     buf.vert(surf(p1[0], p1[1], False), (c[0] + 0.06, 0.05)), buf.vert(surf(p0[0], p0[1], False), (c[0] + 0.02, 0.05))]
                buf.quad(q[3], q[2], q[1], q[0])
    # the cord it hangs by: a loop through two small holes at the temples
    loop = [np.array([w * 0.5 * 0.9 * math.cos(a), thick * 0.25, h * 0.5 + h * 0.5 * (0.2 + 0.95 * math.sin(a))]) for a in np.linspace(0.25, math.pi - 0.25, 12)]
    pc.tube(buf, loop, [h * 0.008] * len(loop), 4, cut[0] + 0.02, cut[0] + 0.1, 8.0, cap_end=False)
    pc.export_glb(os.path.join(OUT, name + ".glb"), name, buf, maps, auto_smooth_deg=50)


if __name__ == "__main__":
    mask("mourning_mask", 0.26)
    mask("child_mask", 0.17)
