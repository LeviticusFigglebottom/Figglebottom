#!/usr/bin/env python3
"""The plain spear (weapons overhaul): an ash shaft and a socketed leaf head,
modelled here because both Tripo rolls failed on the long thin shape (one
came back as two joined spears, the four-view one as a plank with a bent
head; see TRIPO_LEDGER.md).

A working spear, not a guardsman's: the shaft is a coppice pole, a little
out of true and thicker toward the butt; the head is a forged leaf with a
raised midrib, its socket split and hammered round the wood, one rivet
through it and a rawhide whipping below.

Model space as every weapon: the hand at the origin, the head along +Y
(Blender Z), the leaf's flat toward +X so an edge leads (+Z).

Atlas: CC0 `timber` (shaft), `iron` (head), `leather` (whipping).
Out: assets/models/weapons/spear.glb      Run: $BPY tools/art/procedural/ash_spear.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402

LENGTH = 2.2
GRIP = 0.6          # the hand, from the butt
SHAFT = 1.86        # wood ends inside the socket
HEAD_BASE = 1.78    # socket mouth
LEAF_FROM = 1.92    # where the socket opens into the leaf


def leaf(buf, u):
    """The blade: a diamond section that swells and comes to a point, so the
    midrib is a real ridge and both edges are thin."""
    z0, z1 = LEAF_FROM, LENGTH
    n = 22
    rings = []
    for i in range(n + 1):
        f = i / n
        z = z0 + (z1 - z0) * f
        # half-width: out fast from the socket, widest at a third, long taper to the point
        w = 0.047 * (math.sin(min(f / 0.34, 1.0) * math.pi / 2) ** 0.8) * (1.0 - max(f - 0.34, 0.0) / 0.66) ** 0.85
        w = max(w, 0.0012)
        rib = 0.0075 * (1.0 - f) ** 0.6 + 0.001     # midrib height above the flat
        ring = []
        # eight points round the section: edge, shoulder, rib, shoulder, edge, ... (flat faces toward +X/-X)
        sec = [(0.0, -w), (rib * 0.35, -w * 0.45), (rib, 0.0), (rib * 0.35, w * 0.45),
               (0.0, w), (-rib * 0.35, w * 0.45), (-rib, 0.0), (-rib * 0.35, -w * 0.45)]
        for k in range(9):
            x, y = sec[k % 8]
            ring.append(buf.vert((x, y, z), (u[0] + (u[1] - u[0]) * k / 8, z * 2.2)))
        rings.append(ring)
    for i in range(n):
        for k in range(8):
            buf.quad(rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k])


def main():
    maps, cols = pc.make_atlas("spear", [("timber", pc.tint((0.55, 0.43, 0.28), 0.9, 0.55)),
                                         ("iron", pc.tint((0.17, 0.16, 0.16), 1.1, 0.5)),
                                         ("leather", pc.tint((0.62, 0.50, 0.34), 0.9, 0.75))], 1024)
    u_wood, u_iron, u_hide = cols
    rng = np.random.default_rng(11)
    buf = pc.MeshBuf()
    # the shaft: 28 mm at the butt to 22 mm under the socket, wandering a few millimetres
    n = 40
    zs = np.linspace(0.0, SHAFT, n + 1)
    wob_x = np.cumsum(rng.normal(0, 0.0006, n + 1))
    wob_y = np.cumsum(rng.normal(0, 0.0006, n + 1))
    wob_x -= np.linspace(wob_x[0], wob_x[-1], n + 1)   # straight overall: both ends on the axis
    wob_y -= np.linspace(wob_y[0], wob_y[-1], n + 1)
    pts = [(wob_x[i], wob_y[i], zs[i]) for i in range(n + 1)]
    radii = [0.014 - 0.003 * (z / SHAFT) + 0.0005 * math.sin(z * 9.0) for z in zs]
    pc.tube(buf, pts[::-1], radii[::-1], 10, u_wood[0], u_wood[1], 1.6, cap_end=True)   # capped at the butt
    # the socket: a cone hammered round the wood, a lip at its mouth
    sock = [(0.0125, HEAD_BASE - 0.004), (0.0155, HEAD_BASE), (0.0150, HEAD_BASE + 0.012), (0.0138, HEAD_BASE + 0.05),
            (0.0105, LEAF_FROM - 0.02), (0.0080, LEAF_FROM + 0.012)]
    pc.lathe(buf, sock, 10, u_iron[0], u_iron[1], 3.0)
    # the rivet, both ends
    for sx in (-1, 1):
        pc.lathe(buf, [(0.0, 0.0), (0.0042, 0.0), (0.0036, 0.003), (0.0, 0.0042)], 6, u_iron[0], u_iron[1], 3.0,
                 xf=pc.xform(pos=(sx * 0.0135, 0, HEAD_BASE + 0.045), rot_y=sx * math.pi / 2))
    leaf(buf, u_iron)
    # rawhide whipping under the socket: seven turns, the last one loose
    for k in range(7):
        z = HEAD_BASE - 0.012 - k * 0.0085
        r = 0.0128 + (0.0012 if k == 6 else 0.0)
        ring = [(math.cos(a) * r, math.sin(a) * r, z + 0.002 * math.sin(a)) for a in np.linspace(0, math.tau, 13)]
        pc.tube(buf, ring, [0.0042] * 13, 6, u_hide[0], u_hide[1], 5.0, cap_end=False)
    # hand at the origin
    for i in range(len(buf.v)):
        x, y, z = buf.v[i]
        buf.v[i] = (x, y, z - GRIP)
    out = os.path.join(pc.ROOT, "assets", "models", "weapons", "spear.glb")
    pc.export_glb(out, "spear", buf, maps, smooth=True, auto_smooth_deg=50)


if __name__ == "__main__":
    main()
