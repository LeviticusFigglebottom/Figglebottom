#!/usr/bin/env python3
"""Free the Leadvoice's arms from her cloak (ADR 0012 pass 5).

Tripo's auto-rig took the two edges of her ice cloak for her arms: the
forearm, hand and finger bones run down the cloak to the ground and carry
its lower sheet and the ice at its hem, the upper-arm bones carry her real
sleeves and hands AND a band right across the back of the cloak, and a
spare gloved arm hangs out of the cloak behind her right shoulder. So a
wrist moved an inch lifted a slab of the spring, and she could not put her
arms round the child.

This rewrites the skin in place:
  1. the spare arm behind her is cut off and capped (as the Host's was);
  2. everything the forearm, hand and finger bones carried goes to the hips
     and spine by height: the ground ice and lower sheet to the hips alone
     (they stay put while she bows), the sheet up her back to the spine;
  3. the upper-arm bones keep only what is near the real arm (its sleeve),
     fading out over the cloak that hangs from it; the rest goes to the
     spine the same way.
Idempotent. Run once after re-processing the model:
  python3 tools/art/fix_leadvoice_cloak.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from glb_skin import Glb, Prim  # noqa: E402

GLB = Path(__file__).resolve().parents[2] / "assets/models/bosses/leadvoice.glb"
FRONT = np.array([0.36, 0.0, 0.93])   # the way she faces in the bind pose
SIDE = np.array([0.93, 0.0, -0.36])   # her left
# bind-pose heights at which the cloak hands over from one trunk bone to the next
TRUNK = [("Hips", 1.05), ("Spine", 1.35), ("Spine1", 1.75), ("Spine2", 2.15)]
SLEEVE = (0.16, 0.38)   # wholly the arm's inside this distance of its axis; none of it beyond


def trunk_rows(g, y):
    """Joints and weights (k,4) that hang a cloak vertex at height y from the trunk."""
    ids = [g.joint(":" + n) for n, _ in TRUNK]
    hs = np.array([h for _, h in TRUNK])
    w = np.zeros((len(y), len(ids)))
    i = np.clip(np.searchsorted(hs, y) - 1, 0, len(hs) - 2)
    u = np.clip((y - hs[i]) / (hs[i + 1] - hs[i]), 0.0, 1.0)
    u = u * u * (3 - 2 * u)
    w[np.arange(len(y)), i] = 1 - u
    w[np.arange(len(y)), i + 1] = u
    return np.array(ids), w


def seg_dist(p, a, b):
    ab = b - a
    t = np.clip(((p - a) @ ab) / (ab @ ab), 0.0, 1.0)
    return np.linalg.norm(p - (a + np.outer(t, ab)), axis=1)


def main():
    g = Glb(GLB)
    p = Prim(g, g.prims()[0])
    names = [n.split(":")[-1] for n in g.names]
    y = p.pos[:, 1]
    t, s = p.pos @ FRONT, p.pos @ SIDE

    low_ids = [i for i, n in enumerate(names) if "ForeArm" in n or "Hand" in n]
    if p.weight_of(low_ids).max() < 1e-4:
        print("leadvoice: cloak already rebound")
        return

    # 1. the spare arm: its glove hangs behind her, clear of the cloak's back
    arm_ids = {sd: g.joint(":" + sd + "Arm") for sd in ("Left", "Right")}
    arm_mass = p.weight_of(arm_ids.values())
    seed = p.live() & (y > 1.65) & (y < 1.95) & (p.pos[:, 2] < -0.68)
    if seed.sum() >= 30:
        spare = p.tube(seed, 1400, lo=0.05, hi=1.2, axis=(0, 1, 0))   # it hangs straight down
        n = p.drop_and_cap(spare)
        print(f"leadvoice: cut the spare arm ({int(spare.sum())} vertices, {n} triangles)")

    # 2 and 3. per vertex: how much of each arm bone's weight is really sleeve
    keep = {}
    for sd, sgn in (("Left", 1.0), ("Right", -1.0)):
        mine = (arm_mass > 0.5) & (t > 0.35) & (s * sgn > 0)
        hand = p.pos[mine & (y > 1.72) & (y < 1.92)].mean(0)
        top = p.pos[mine & (y > 2.35) & (y < 2.55)].mean(0)
        d = seg_dist(p.pos, hand + (hand - top) * 0.15, top)
        u = np.clip((SLEEVE[1] - d) / (SLEEVE[1] - SLEEVE[0]), 0.0, 1.0)
        keep[sd] = u * u * (3 - 2 * u)
    tj, tw = trunk_rows(g, y)
    nj = len(names)
    dense = np.zeros((len(y), nj))
    np.add.at(dense, (np.repeat(np.arange(len(y)), 4), p.joints.ravel()), p.weights.ravel())
    before = dense.copy()
    freed = dense[:, low_ids].sum(1)
    sleeve = {sd: keep[sd] * (s * sgn > 0) for sd, sgn in (("Left", 1.0), ("Right", -1.0))}
    dense[:, low_ids] = 0.0
    for sd in ("Left", "Right"):
        a = arm_ids[sd]
        total = dense[:, a] + freed * (sleeve[sd] > 0)   # a sleeve tail the hand bones held follows the arm
        freed = freed * ~(sleeve[sd] > 0)
        dense[:, a] = total * sleeve[sd]
        freed = freed + total * (1 - sleeve[sd])
    dense[:, tj] += freed[:, None] * tw
    order = np.argsort(-dense, axis=1)[:, :4]
    w4 = np.take_along_axis(dense, order, 1)
    w4 /= w4.sum(1, keepdims=True)
    order[w4 == 0] = 0
    p.joints, p.weights = order, w4
    print(f"leadvoice: rebound {int((np.abs(dense - before).sum(1) > 1e-4).sum())} cloak vertices to the hips and spine")
    p.flush()
    g.save()


if __name__ == "__main__":
    main()
