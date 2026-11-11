#!/usr/bin/env python3
"""Cut the Host's third arm off (ADR 0012 pass 5).

Tripo's generation grew a whole extra sleeve and hand out of the small of
his back, slanting down behind him, and the auto-rig bound it to the LEFT
upper arm: in every pose it swung at his left hip, a stiff third arm no clip
could hide. It is one tube joined to the back at its top. This finds it (the
vertices far out behind the hips, flooded up the tube to where it widens
into the body), removes its triangles and caps the cut. Idempotent: with no
tube left it changes nothing. Run once after re-processing the model:
  python3 tools/art/fix_host_hip_arm.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from glb_skin import Glb, Prim  # noqa: E402

GLB = Path(__file__).resolve().parents[2] / "assets/models/bosses/host.glb"
TUBE_MAX = 1500   # the arm is about 900 vertices; the flood past its root takes in half the body


def main():
    g = Glb(GLB)
    p = Prim(g, g.prims()[0])
    # the far end: behind the back (he faces +Z), between knee and chest height
    x, y, z = p.pos.T
    seed = p.live() & (z < -1.0) & (y > 1.4) & (y < 2.4) & (np.abs(x) < 0.6)
    if seed.sum() < 50:
        print("host: no third arm found (already cut)")
        return
    arm = p.tube(seed, TUBE_MAX, lo=0.3, hi=1.2)
    n = p.drop_and_cap(arm)
    p.flush()
    g.save()
    print(f"host: cut the third arm ({int(arm.sum())} vertices, {n} triangles) and capped it")


if __name__ == "__main__":
    main()
