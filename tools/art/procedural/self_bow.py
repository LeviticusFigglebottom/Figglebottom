#!/usr/bin/env python3
"""The fowling bow (weapons overhaul): a yew self bow, modelled here because
three Tripo rolls (a flat image, four views, a three-quarter image) each read
the thin stave as a wide plank or split it into extra limbs.

One stave, braced: a D-section, pale sapwood on the back and red heartwood on
the belly, thickest at the grip and drawn down to the tips; a narrow leather
grip; horn nocks. No string: the game draws it (src/chars/bow_rig.gd), since
it has to follow the drawing hand.

Model space as every weapon: grip at the origin, stave along +Y (Blender Z),
back toward +Z (Blender -Y), so the tips and the string sit toward -Z.
`NOCK` and `BRACE` are read by the game from clip_meta.json weapons.bow.

Atlas: CC0 `timber` (stave, graded sapwood to heartwood round the section;
horn), `leather` (grip).   Out: assets/models/weapons/bow.glb
Run: $BPY tools/art/procedural/self_bow.py
"""
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import proc_common as pc  # noqa: E402

LENGTH = 1.45      # nock to nock, braced (a short bow: weapons.json)
BRACE = 0.17       # grip to string
HALF = LENGTH / 2


def yew(alb, orh):
    """Sapwood to heartwood across the column: the tube wraps it once round
    the stave, so the pale band lands on the back and the red on the belly."""
    w = alb.shape[1]
    u = np.linspace(0.0, 1.0, w, dtype=np.float32)[None, :, None]
    belly = 0.5 - 0.5 * np.cos(u * math.tau)          # 0 at the back (u = 0 and 1), 1 at the belly
    belly = np.clip((belly - 0.35) / 0.3, 0.0, 1.0)   # the sapwood is a band, not a blend
    sap = np.array([0.78, 0.64, 0.42], np.float32)
    heart = np.array([0.50, 0.25, 0.12], np.float32)
    mean = alb.reshape(-1, 3).mean(axis=0)
    detail = alb / np.maximum(mean, 1e-3)
    out = (sap * (1 - belly) + heart * belly) * (1.0 + (detail - 1.0) * 0.8)
    orh = orh.copy()
    orh[..., 1] = np.clip(orh[..., 1] - orh[..., 1].mean() + 0.42, 0.1, 1.0)   # handled wood: a low sheen
    return np.clip(out, 0, 1), orh


def stave_point(s):
    """Centre line at s in [-1, 1] (Blender: Z up the stave, +Y toward the string)."""
    a = abs(s)
    # a stiff handle, the bend taken in the middle of each limb, tips a little straighter
    y = BRACE * (0.18 * a + 0.82 * a ** 2.2)
    return np.array([0.0, y, s * HALF])


def main():
    maps, cols = pc.make_atlas("bow", [("timber", yew), ("leather", pc.tint((0.36, 0.25, 0.16), 0.9, 0.7)),
                                       ("timber", pc.tint((0.86, 0.80, 0.66), 0.35, 0.35))], 1024)
    u_wood, u_leather, u_horn = cols
    buf = pc.MeshBuf()
    n = 48
    ss = np.linspace(-1.0, 1.0, n * 2 + 1)
    pts = [stave_point(s) for s in ss]
    # round at the grip, a flattened D in the limbs, nearly round again at the tips
    radii, squash = [], []
    for s in ss:
        a = abs(s)
        radii.append(0.0165 * (1.0 - 0.52 * a ** 1.3))
        flat = math.sin(min(a / 0.6, 1.0) * math.pi) * 0.35
        squash.append((1.0 + flat, 1.0 - flat * 0.75))
    # frames() starts its normal across the stave; turn u = 0 to the back
    # (-Y) by rolling the section a quarter turn where needed
    t, nn, bb = pc.frames(pts)
    back_on_n = abs(float(nn[0][1])) > 0.5
    sq = [(b, a) for a, b in squash] if back_on_n else squash
    pc.tube(buf, pts, radii, 14, u_wood[0], u_wood[1], 1.4, cap_end=False, squash=sq)
    # the leather grip, proud of the wood
    g = [stave_point(s) for s in np.linspace(-0.075, 0.075, 7)]
    pc.tube(buf, g, [0.0195] * 7, 14, u_leather[0], u_leather[1], 6.0, cap_end=False)
    for z in (-1, 1):   # the wrap's two edges
        e = [stave_point(z * 0.075), stave_point(z * 0.079)]
        pc.tube(buf, e, [0.0195, 0.0162], 14, u_leather[0], u_leather[1], 6.0, cap_end=False)
    # horn nocks: a sleeve over each tip, waisted for the string, with a blunt point
    for z in (-1, 1):
        prof = [(0.91, 1.25), (0.935, 1.3), (0.955, 1.0), (0.965, 0.8), (0.975, 1.15), (0.99, 1.0), (1.012, 0.45)]
        p = [stave_point(z * s) for s, _k in prof]
        r = [0.0165 * (1.0 - 0.52 * min(s, 1.0) ** 1.3) * k for s, k in prof]
        pc.tube(buf, p, r, 10, u_horn[0], u_horn[1], 3.0, cap_end=True)
    # origin = the grip centre (the stave's centre line at s = 0 is already there)
    out = os.path.join(pc.ROOT, "assets", "models", "weapons", "bow.glb")
    pc.export_glb(out, "bow", buf, maps, smooth=True)
    nock = stave_point(1.0)
    print("[bow] nock at stave %.3f m, toward the string %.3f m (clip_meta weapons.bow: nock [0, %.3f, %.3f])"
          % (nock[2], nock[1], nock[2] * 0.968, -stave_point(0.968)[1]))


if __name__ == "__main__":
    main()
