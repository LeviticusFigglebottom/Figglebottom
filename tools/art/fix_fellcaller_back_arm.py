#!/usr/bin/env python3
"""Cut the stray forearm off the Fellcaller's back (ADR 0012 pass 5).

Like the Host, her generation grew a spare gloved forearm, here out of the
fleece in the middle of her back, and the auto-rig bound it to the left
shoulder. This finds it from its far end (the glove, the rearmost thing at
hip height in the bind pose), floods up the wrist to where it widens into the
fleece, removes it and caps the cut. Idempotent. Run once after
re-processing the model:
  python3 tools/art/fix_fellcaller_back_arm.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from glb_skin import Glb, Prim  # noqa: E402

GLB = Path(__file__).resolve().parents[2] / "assets/models/bosses/fellcaller.glb"
TUBE_MAX = 900   # glove and wrist are about 450 vertices


def main():
    g = Glb(GLB)
    p = Prim(g, g.prims()[0])
    x, y, z = p.pos.T
    seed = p.live() & (z < -0.75) & (y > 1.3) & (y < 2.3)
    if seed.sum() < 50:
        print("fellcaller: no back forearm found (already cut)")
        return
    arm = p.tube(seed, TUBE_MAX, lo=0.05, hi=1.0)
    n = p.drop_and_cap(arm)
    p.flush()
    g.save()
    print(f"fellcaller: cut the back forearm ({int(arm.sum())} vertices, {n} triangles) and capped it")


if __name__ == "__main__":
    main()
