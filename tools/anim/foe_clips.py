"""Foe attack clips for build_combat_lib.py (ADR 0012).

Every clip is hand-keyed on the control rig and cut to its attack's DATA
windup (data/combat/enemies.json), so it plays at 1x: a quick rise into a
clear anticipation shape, that shape HELD (with a slow creep) for as long as
the telegraph lasts, a fast committed strike landing on the windup, an
overshoot, a held follow-through and a recovery. A long windup is a long
hold, never a slow swing.

FOES maps foe id -> attack id -> (archetype, options). Archetypes are
written for the right hand; "side": "L" mirrors them. "post" is the foe's
posture [forward lean deg, crouch m], added to every key pose.
"""
import copy
import json
import os

import anim_pose as A
import anim_rig as R
import combat_clips as C

P = R.P
Z5 = [0, 0, 0, 0, 0]
Z6 = [0, 0, 0, 0, 0, 0]


def neutral(rig):
    n = {"hips": list(Z6), "chest": [0, 0, 0], "head": [0, 0], "footL": list(Z5), "footR": list(Z5),
         "rpole": [0.5, -0.4, -0.8], "lpole": [-0.5, -0.4, -0.8], "fists": True}
    n.update(rig.hands_ctl())
    return n


def mirror(c):
    """Swap a control set left for right."""
    out = {}
    swap = {"rhand": "lhand", "lhand": "rhand", "rpole": "lpole", "lpole": "rpole", "rrot": "lrot", "lrot": "rrot",
            "footL": "footR", "footR": "footL"}
    for k, v in c.items():
        k2 = swap.get(k, k)
        if k in ("rhand", "lhand", "rpole", "lpole"):
            out[k2] = [-v[0], v[1], v[2]]
        elif k == "hips":
            out[k2] = [-v[0], v[1], v[2], -v[3], v[4], -v[5]]
        elif k == "chest":
            out[k2] = [-v[0], v[1], -v[2]]
        elif k == "head":
            out[k2] = [-v[0], v[1]]
        elif k in ("footL", "footR"):
            out[k2] = [-v[0], v[1], v[2], -v[3], v[4]]
        elif k in ("rrot", "lrot"):
            continue   # free wrists follow the forearm on the mirrored side
        else:
            out[k2] = v
    return out


def _mix(a, b, t):
    """a + (b - a) * t on numeric controls (t > 1 extrapolates: overshoot)."""
    out = dict(b)
    for k in b:
        if k in a and isinstance(b[k], list) and isinstance(a[k], list) and len(a[k]) == len(b[k]):
            out[k] = [x + (y - x) * t for x, y in zip(a[k], b[k])]
    return out


def _posture(c, post):
    c = dict(c)
    h = list(c.get("hips", Z6))
    h[4] += post[0] * 0.45
    h[2] -= post[1]
    c["hips"] = h
    ch = list(c.get("chest", [0, 0, 0]))
    ch[1] += post[0] * 0.55
    c["chest"] = ch
    # the eyes stay on the target however far the trunk winds
    hd = list(c.get("head", [0, 0]))
    hd[0] = max(-75.0, min(75.0, -0.9 * (h[3] + ch[0])))
    c["head"] = hd
    return c


# ------------------------------------------------------------- archetypes
# each returns (anticipation, hit, follow-through) controls for the RIGHT hand
def hook(amp=1.0, height=1.28):
    """Wide round swing: the arm cocked out and back, the whole trunk wound,
    then thrown across with a step."""
    a = {"hips": [0.04, -0.09, -0.06, -30 * amp, 4, 0], "chest": [-32 * amp, 2, -4], "head": [34 * amp, 0],
         "rhand": [0.66, -0.36, height + 0.06], "rpole": [0.7, -0.8, 0.1],
         "lhand": [-0.22, 0.34, 1.22], "lpole": [-0.6, -0.2, -0.7], "footR": [0.05, -0.12, 0, -14, 0]}
    h = {"hips": [-0.03, 0.22, -0.11, 26 * amp, 9, 0], "chest": [38 * amp, 8, 4], "head": [-30 * amp, -4],
         "rhand": [-0.14, 0.68, height - 0.04], "rpole": [0.8, -0.2, -0.5],
         "lhand": [-0.42, -0.08, 1.02], "footL": [-0.02, 0.24, 0, 6, 0], "footR": [0.05, -0.12, 0.05, -14, 26]}
    f = {"hips": [-0.05, 0.24, -0.13, 36 * amp, 10, 0], "chest": [52 * amp, 12, 6], "head": [-40 * amp, -4],
         "rhand": [-0.52, 0.30, height - 0.22], "lhand": [-0.44, -0.16, 1.0],
         "footL": [-0.02, 0.24, 0, 6, 0], "footR": [0.05, -0.12, 0.05, -14, 26]}
    return a, h, f


def backhand(amp=1.0, height=1.3):
    """The arm folded across the chest, shoulder turned in; flung out and round."""
    a = {"hips": [-0.03, -0.06, -0.05, 28 * amp, 3, 0], "chest": [34 * amp, 4, 4], "head": [-36 * amp, 0],
         "rhand": [-0.34, 0.26, height + 0.10], "rpole": [0.5, 0.4, -0.7],
         "lhand": [-0.40, -0.10, 1.0], "footL": [-0.04, -0.08, 0, 10, 0]}
    h = {"hips": [0.03, 0.18, -0.09, -22 * amp, 6, 0], "chest": [-34 * amp, 4, -4], "head": [26 * amp, -2],
         "rhand": [0.56, 0.52, height], "rpole": [0.6, -0.3, -0.7],
         "lhand": [-0.34, 0.14, 1.12], "footR": [0.06, 0.22, 0, -8, 0], "footL": [-0.04, -0.08, 0.04, 10, 22]}
    f = {"hips": [0.05, 0.19, -0.11, -32 * amp, 7, 0], "chest": [-48 * amp, 6, -6], "head": [36 * amp, -2],
         "rhand": [0.74, 0.02, height - 0.12], "lhand": [-0.30, 0.20, 1.12],
         "footR": [0.06, 0.22, 0, -8, 0], "footL": [-0.04, -0.08, 0.04, 10, 22]}
    return a, h, f


def overhead(amp=1.0, reach=0.64, low=0.78):
    """The fist hauled up behind the head, back arched, weight on the back
    foot; brought down like a maul with the whole body folding over it."""
    a = {"hips": [0.02, -0.09, 0.03, -12, -9 * amp, 0], "chest": [-14, -16 * amp, 0], "head": [10, -8],
         "rhand": [0.30, -0.26, 2.02], "rpole": [1.0, -0.2, 0.3],
         "lhand": [-0.20, 0.36, 1.28], "lpole": [-0.6, -0.2, -0.7], "footR": [0.04, -0.10, 0, -10, 0]}
    h = {"hips": [0, 0.24, -0.22, 12, 20 * amp, 0], "chest": [14, 28 * amp, 0], "head": [-8, -14],
         "rhand": [0.10, reach, low], "rpole": [0.9, -0.3, -0.3],
         "lhand": [-0.42, -0.04, 0.98], "footL": [-0.02, 0.26, 0, 4, 0], "footR": [0.04, -0.10, 0.05, -10, 28]}
    f = {"hips": [0, 0.26, -0.30, 14, 26 * amp, 0], "chest": [16, 34 * amp, 0], "head": [-8, -6],
         "rhand": [0.04, reach - 0.08, low - 0.26], "lhand": [-0.44, -0.10, 0.92],
         "footL": [-0.02, 0.26, 0, 4, 0], "footR": [0.04, -0.10, 0.05, -10, 28]}
    return a, h, f


def double_slam(amp=1.0):
    """Both fists overhead, up on the balls of the feet, the back arched;
    then the body falls forward behind them."""
    a = {"hips": [0, -0.10, 0.05, 0, -13 * amp, 0], "chest": [0, -20 * amp, 0], "head": [0, -12],
         "rhand": [0.24, -0.20, 2.04], "lhand": [-0.24, -0.20, 2.04],
         "rpole": [1.0, -0.1, 0.2], "lpole": [-1.0, -0.1, 0.2],
         "footL": [0, 0, 0.03, 0, 16], "footR": [0, 0, 0.03, 0, 16]}
    h = {"hips": [0, 0.28, -0.32, 0, 28 * amp, 0], "chest": [0, 36 * amp, 0], "head": [0, -18],
         "rhand": [0.20, 0.66, 0.58], "lhand": [-0.20, 0.66, 0.58],
         "rpole": [0.9, -0.3, -0.2], "lpole": [-0.9, -0.3, -0.2],
         "footL": [-0.02, 0.30, 0, 0, 0], "footR": [0, 0, 0.05, 0, 30]}
    f = {"hips": [0, 0.30, -0.40, 0, 34 * amp, 0], "chest": [0, 40 * amp, 0], "head": [0, -8],
         "rhand": [0.18, 0.60, 0.34], "lhand": [-0.18, 0.60, 0.34],
         "footL": [-0.02, 0.30, 0, 0, 0], "footR": [0, 0, 0.05, 0, 30]}
    return a, h, f


def thrust(amp=1.0, height=1.22, reach=0.88):
    """The fist drawn back to the ribs with the shoulder turned away, the
    other hand forward; then the whole side drives it straight out."""
    a = {"hips": [0.03, -0.12, -0.05, -32 * amp, 2, 0], "chest": [-28 * amp, 3, 0], "head": [40 * amp, 0],
         "rhand": [0.36, -0.30, height - 0.06], "rpole": [0.9, -0.7, 0.0],
         "lhand": [-0.14, 0.46, 1.26], "lpole": [-0.6, -0.1, -0.7]}
    h = {"hips": [0, 0.32, -0.14, 24 * amp, 9, 0], "chest": [32 * amp, 7, 0], "head": [-34 * amp, -4],
         "rhand": [0.02, reach, height + 0.02], "rpole": [0.6, -0.3, -0.8],
         "lhand": [-0.40, -0.14, 1.08], "footL": [-0.02, 0.38, 0, 0, 0], "footR": [0, 0, 0.06, 0, 30]}
    f = _mix(a, h, 1.05)
    return a, h, f


def throw(amp=1.0):
    """Overarm cast: the hand far behind and high, the lead arm pointing; a
    whip through and down across the body."""
    a = {"hips": [0.04, -0.12, -0.03, -36 * amp, -4, 0], "chest": [-34 * amp, -8, -6], "head": [46 * amp, 0],
         "rhand": [0.50, -0.42, 1.74], "rpole": [1.0, -0.3, -0.1],
         "lhand": [-0.10, 0.62, 1.40], "lpole": [-0.5, 0.0, -0.9], "footR": [0.05, -0.14, 0, -18, 0]}
    h = {"hips": [-0.02, 0.24, -0.10, 22 * amp, 12, 0], "chest": [34 * amp, 14, 4], "head": [-30 * amp, -6],
         "rhand": [0.06, 0.78, 1.52], "rpole": [0.9, -0.2, -0.4],
         "lhand": [-0.42, -0.10, 1.04], "footL": [-0.02, 0.30, 0, 4, 0], "footR": [0.05, -0.14, 0.06, -18, 30]}
    f = {"hips": [-0.03, 0.26, -0.14, 30 * amp, 16, 0], "chest": [46 * amp, 20, 6], "head": [-36 * amp, -2],
         "rhand": [-0.34, 0.46, 0.86], "lhand": [-0.44, -0.16, 1.0],
         "footL": [-0.02, 0.30, 0, 4, 0], "footR": [0.05, -0.14, 0.06, -18, 30]}
    return a, h, f


def plant(amp=1.0):
    """Both hands lifted together over one shoulder, then driven straight
    down into the ground on a deep bend."""
    a = {"hips": [0.02, -0.06, 0.03, -10, -8 * amp, 0], "chest": [-12, -12 * amp, 0], "head": [8, 6],
         "rhand": [0.20, 0.10, 1.96], "lhand": [0.02, 0.16, 1.80],
         "rpole": [1.0, -0.2, 0.0], "lpole": [-1.0, 0.2, 0.0]}
    h = {"hips": [0, 0.14, -0.40, 0, 26 * amp, 0], "chest": [0, 30 * amp, 0], "head": [0, -10],
         "rhand": [0.12, 0.52, 0.40], "lhand": [-0.10, 0.50, 0.52],
         "rpole": [0.9, -0.4, 0.0], "lpole": [-0.9, -0.4, 0.0],
         "footL": [-0.06, 0.16, 0, 6, 0], "footR": [0.06, -0.04, 0, -8, 0]}
    f = _mix(a, h, 1.06)
    return a, h, f


def sweep_low(amp=1.0):
    """Both hands on a long tool carried back to the right at the hip, then
    raked flat across the front."""
    a = {"hips": [0.05, -0.08, -0.10, -34 * amp, 8, 0], "chest": [-30 * amp, 8, 0], "head": [44 * amp, 0],
         "rhand": [0.58, -0.30, 0.98], "lhand": [0.20, 0.06, 0.92],
         "rpole": [0.8, -0.8, 0.0], "lpole": [-0.6, -0.4, -0.5], "footR": [0.05, -0.12, 0, -16, 0]}
    h = {"hips": [-0.04, 0.16, -0.16, 26 * amp, 12, 0], "chest": [36 * amp, 12, 0], "head": [-32 * amp, -4],
         "rhand": [-0.10, 0.70, 0.82], "lhand": [-0.44, 0.34, 0.86],
         "rpole": [0.8, -0.3, -0.4], "lpole": [-0.9, -0.2, -0.2],
         "footL": [-0.04, 0.22, 0, 8, 0], "footR": [0.05, -0.12, 0.05, -16, 24]}
    f = {"hips": [-0.06, 0.18, -0.18, 38 * amp, 13, 0], "chest": [50 * amp, 14, 0], "head": [-42 * amp, -2],
         "rhand": [-0.48, 0.44, 0.84], "lhand": [-0.62, -0.04, 0.92],
         "footL": [-0.04, 0.22, 0, 8, 0], "footR": [0.05, -0.12, 0.05, -16, 24]}
    return a, h, f


def cross_cut(amp=1.0):
    """Both forearms crossed tight at the chest, shoulders hunched in; then
    flung open through the target."""
    a = {"hips": [0, -0.06, -0.08, 0, 8, 0], "chest": [0, 12, 0], "head": [0, -8],
         "rhand": [-0.22, 0.24, 1.36], "lhand": [0.22, 0.20, 1.26],
         "rpole": [0.7, 0.2, -0.7], "lpole": [-0.7, 0.2, -0.7]}
    h = {"hips": [0, 0.22, -0.10, 0, 6, 0], "chest": [0, 2, 0], "head": [0, 0],
         "rhand": [0.52, 0.56, 1.16], "lhand": [-0.52, 0.56, 1.30],
         "rpole": [0.7, -0.4, -0.6], "lpole": [-0.7, -0.4, -0.6],
         "footL": [-0.02, 0.26, 0, 0, 0], "footR": [0, 0, 0.05, 0, 24]}
    f = {"hips": [0, 0.24, -0.11, 0, 2, 0], "chest": [0, -8, 0], "head": [0, 4],
         "rhand": [0.72, 0.14, 1.02], "lhand": [-0.72, 0.14, 1.20],
         "footL": [-0.02, 0.26, 0, 0, 0], "footR": [0, 0, 0.05, 0, 24]}
    return a, h, f


def rush(amp=1.0):
    """Set behind the shield arm: sunk low, left forearm across the front,
    right fist cocked; then the whole body is thrown forward behind it."""
    a = {"hips": [0, -0.10, -0.22, -14, 14, 0], "chest": [-10, 12, 0], "head": [20, -12],
         "lhand": [0.06, 0.34, 1.12], "lpole": [-1.0, 0.1, 0.0],
         "rhand": [0.44, -0.24, 1.0], "rpole": [0.8, -0.7, 0.0], "footR": [0.06, -0.26, 0, -20, 0]}
    h = {"hips": [0, 0.36, -0.18, 8, 22, 0], "chest": [10, 16, 0], "head": [-10, -18],
         "lhand": [0.04, 0.70, 1.22], "lpole": [-1.0, 0.1, 0.0],
         "rhand": [0.46, -0.10, 0.96], "footL": [-0.04, 0.44, 0, 0, 0], "footR": [0.06, -0.26, 0.06, -20, 36]}
    f = _mix(a, h, 1.06)
    return a, h, f


def scoop(amp=1.0):
    """Both hands dug low behind the right hip, then flung up and forward."""
    a = {"hips": [0.04, -0.06, -0.26, -26, 22, 0], "chest": [-24, 18, 0], "head": [34, -14],
         "rhand": [0.46, -0.20, 0.42], "lhand": [0.20, 0.06, 0.40],
         "rpole": [0.9, -0.6, 0.2], "lpole": [-0.7, -0.3, 0.2]}
    h = {"hips": [-0.02, 0.16, -0.04, 16, -4, 0], "chest": [22, -10, 0], "head": [-18, 6],
         "rhand": [0.14, 0.70, 1.62], "lhand": [-0.20, 0.62, 1.50],
         "rpole": [0.9, -0.3, -0.4], "lpole": [-0.9, -0.3, -0.4], "footL": [-0.02, 0.22, 0, 0, 0]}
    f = _mix(a, h, 1.05)
    return a, h, f


def keen(amp=1.0):
    """A sung attack: the breath drawn (arms opening low and back, chest
    lifted, head tipped back), then the note thrown: chest and head driven
    forward, both arms flung out, palms to the listener."""
    a = {"hips": [0, -0.06, 0.02, 0, -8 * amp, 0], "chest": [0, -18 * amp, 0], "head": [0, -16 * amp],
         "rhand": [0.52, -0.18, 0.96], "lhand": [-0.52, -0.18, 0.96],
         "rpole": [0.6, -0.9, 0.0], "lpole": [-0.6, -0.9, 0.0], "fists": False}
    h = {"hips": [0, 0.12, -0.08, 0, 12 * amp, 0], "chest": [0, 18 * amp, 0], "head": [0, -8],
         "rhand": [0.44, 0.60, 1.42], "lhand": [-0.44, 0.60, 1.42],
         "rpole": [0.8, -0.2, -0.6], "lpole": [-0.8, -0.2, -0.6], "fists": False,
         "footL": [-0.02, 0.14, 0, 0, 0]}
    f = _mix(a, h, 1.04)
    return a, h, f


def hush(amp=1.0):
    """Both hands raised beside the head, then pressed down and out flat."""
    a = {"hips": [0, -0.02, 0.02, 0, -4, 0], "chest": [0, -8, 0], "head": [0, 6],
         "rhand": [0.26, 0.20, 1.80], "lhand": [-0.26, 0.20, 1.80],
         "rpole": [1.0, -0.1, -0.2], "lpole": [-1.0, -0.1, -0.2], "fists": False}
    h = {"hips": [0, 0.04, -0.16, 0, 10, 0], "chest": [0, 14, 0], "head": [0, -10],
         "rhand": [0.56, 0.36, 0.86], "lhand": [-0.56, 0.36, 0.86],
         "rpole": [0.9, -0.5, 0.2], "lpole": [-0.9, -0.5, 0.2], "fists": False}
    f = _mix(a, h, 1.05)
    return a, h, f


def rouse(amp=1.0):
    """One arm thrown straight up, head back: a call."""
    a = {"hips": [0, -0.03, -0.06, -10, 8, 0], "chest": [-10, 10, 0], "head": [10, -10],
         "rhand": [0.30, 0.20, 1.10], "rpole": [0.8, -0.5, 0.0], "fists": False}
    h = {"hips": [0, 0.02, 0.04, 6, -8, 0], "chest": [6, -14, 0], "head": [-4, -22],
         "rhand": [0.24, 0.16, 2.10], "rpole": [0.9, 0.1, -0.2], "fists": False}
    f = _mix(a, h, 1.03)
    return a, h, f


def double_slice(amp=1.0):
    """Two blades: both drawn across to the left hip, the body coiled over
    them (the held shape); the right cuts out level, the left follows through
    high."""
    a = {"hips": [-0.03, -0.08, -0.10, 30 * amp, 8, 0], "chest": [34 * amp, 10, 4], "head": [-40, -4],
         "rhand": [-0.40, 0.14, 1.02], "lhand": [-0.46, -0.10, 1.30],
         "rpole": [0.3, 0.6, -0.7], "lpole": [-0.9, -0.3, 0.0], "footL": [-0.05, -0.10, 0, 12, 0]}
    h = {"hips": [0.03, 0.22, -0.12, -24 * amp, 8, 0], "chest": [-34 * amp, 6, -4], "head": [30, -2],
         "rhand": [0.62, 0.46, 1.16], "lhand": [-0.10, 0.58, 1.38],
         "rpole": [0.7, -0.3, -0.6], "lpole": [-0.8, -0.2, -0.4],
         "footR": [0.06, 0.26, 0, -8, 0], "footL": [-0.05, -0.10, 0.05, 12, 24]}
    f = {"hips": [0.05, 0.24, -0.14, -36 * amp, 9, 0], "chest": [-50 * amp, 8, -6], "head": [42, -2],
         "rhand": [0.74, -0.06, 1.02], "lhand": [0.44, 0.44, 1.10],
         "footR": [0.06, 0.26, 0, -8, 0], "footL": [-0.05, -0.10, 0.05, 12, 24]}
    return a, h, f


def whirl(amp=1.0):
    """Arms flung wide and level, the body wound right back; then spun
    through more than a half turn on the lead foot, arms scything."""
    a = {"hips": [0.03, -0.06, -0.10, -50 * amp, 6, 0], "chest": [-40 * amp, 6, 0], "head": [70, 0],
         "rhand": [0.20, -0.66, 1.26], "lhand": [-0.50, 0.50, 1.26],
         "rpole": [0.6, -0.3, -0.7], "lpole": [-0.6, 0.2, -0.7], "footR": [0.06, -0.14, 0, -30, 0]}
    h = {"hips": [-0.02, 0.10, -0.12, 60 * amp, 6, 0], "chest": [46 * amp, 6, 0], "head": [-60, 0],
         "rhand": [-0.30, 0.66, 1.22], "lhand": [-0.30, -0.62, 1.30],
         "footL": [-0.03, 0.10, 0, 40, 0], "footR": [0.10, 0.06, 0.05, 30, 20]}
    f = {"hips": [-0.03, 0.10, -0.13, 100 * amp, 6, 0], "chest": [60 * amp, 6, 0], "head": [-70, 0],
         "rhand": [-0.70, 0.10, 1.16], "lhand": [0.30, -0.62, 1.30],
         "footL": [-0.03, 0.10, 0, 70, 0], "footR": [0.14, 0.10, 0, 60, 0]}
    return a, h, f


def heave(amp=1.0):
    """A heavy thing lifted in both hands over the head, the back arched
    under it; hurled forward off the back foot, arms following right through."""
    a = {"hips": [0, -0.12, 0.03, 0, -14 * amp, 0], "chest": [0, -20 * amp, 0], "head": [0, 6],
         "rhand": [0.24, -0.16, 2.06], "lhand": [-0.24, -0.16, 2.06],
         "rpole": [1.0, 0.0, 0.2], "lpole": [-1.0, 0.0, 0.2], "footR": [0.04, -0.16, 0, -10, 0], "fists": False}
    h = {"hips": [0, 0.24, -0.10, 0, 16 * amp, 0], "chest": [0, 22 * amp, 0], "head": [0, -14],
         "rhand": [0.22, 0.74, 1.70], "lhand": [-0.22, 0.74, 1.70],
         "rpole": [0.9, -0.2, -0.4], "lpole": [-0.9, -0.2, -0.4],
         "footL": [-0.02, 0.30, 0, 0, 0], "footR": [0.04, -0.16, 0.06, -10, 30], "fists": False}
    f = {"hips": [0, 0.28, -0.20, 0, 26 * amp, 0], "chest": [0, 32 * amp, 0], "head": [0, -10],
         "rhand": [0.26, 0.66, 0.92], "lhand": [-0.26, 0.66, 0.92],
         "footL": [-0.02, 0.30, 0, 0, 0], "footR": [0.04, -0.16, 0.06, -10, 30], "fists": False}
    return a, h, f


def twist(amp=1.0):
    """A load across the shoulders, hands up on it: the whole frame wound
    back, then spun through so the ends of the load sweep round."""
    def hands(yaw):
        import math
        c, s_ = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
        rot = lambda r, f, u: [r * c + f * s_, -r * s_ + f * c, u]
        # hands out on the ends of the yoke, ahead of the load on the back
        return rot(0.62, 0.22, 1.42), rot(-0.62, 0.22, 1.42)
    ra, la = hands(-58 * amp)
    rh, lh = hands(40 * amp)
    rf, lf = hands(70 * amp)
    a = {"hips": [0.03, -0.06, -0.08, -24 * amp, 4, 0], "chest": [-34 * amp, 4, 0], "head": [50 * amp, 0],
         "rhand": ra, "lhand": la, "rpole": [0.7, -0.2, -0.7], "lpole": [-0.7, -0.2, -0.7],
         "footR": [0.05, -0.10, 0, -16, 0]}
    h = {"hips": [-0.02, 0.12, -0.12, 16 * amp, 6, 0], "chest": [24 * amp, 6, 0], "head": [-30 * amp, 0],
         "rhand": rh, "lhand": lh, "footL": [-0.03, 0.16, 0, 8, 0], "footR": [0.05, -0.10, 0.04, -16, 20]}
    f = {"hips": [-0.03, 0.13, -0.13, 28 * amp, 6, 0], "chest": [42 * amp, 6, 0], "head": [-46 * amp, 0],
         "rhand": rf, "lhand": lf, "footL": [-0.03, 0.16, 0, 8, 0], "footR": [0.05, -0.10, 0.04, -16, 20]}
    return a, h, f


# the Oarsman's ice oar runs from the left hand through the right and on
def oar_stroke(amp=1.0):
    a = {"hips": [0.04, -0.08, -0.08, -34, 6, 0], "chest": [-34, 6, 0], "head": [50, 0],
         "lhand": [0.22, 0.04, 1.04], "rhand": [0.62, -0.34, 1.34],
         "rpole": [0.8, -0.8, 0.0], "lpole": [-0.6, -0.5, -0.4], "footR": [0.05, -0.12, 0, -16, 0]}
    h = {"hips": [-0.04, 0.18, -0.14, 26, 10, 0], "chest": [34, 10, 0], "head": [-30, -4],
         "lhand": [-0.34, 0.20, 1.02], "rhand": [-0.06, 0.66, 1.06],
         "rpole": [0.8, -0.3, -0.4], "lpole": [-0.9, -0.3, -0.2],
         "footL": [-0.04, 0.24, 0, 8, 0], "footR": [0.05, -0.12, 0.05, -16, 24]}
    f = {"hips": [-0.06, 0.20, -0.16, 38, 11, 0], "chest": [48, 12, 0], "head": [-42, -2],
         "lhand": [-0.40, -0.10, 1.06], "rhand": [-0.62, 0.34, 1.02],
         "footL": [-0.04, 0.24, 0, 8, 0], "footR": [0.05, -0.12, 0.05, -16, 24]}
    return a, h, f


def oar_back(amp=1.0):
    a, h, f = oar_stroke(amp)
    return f, _mix(f, a, 0.8), a


def oar_ship(amp=1.0):
    a = {"hips": [0, -0.04, 0.03, 0, -8, 0], "chest": [0, -12, 0], "head": [0, 8],
         "lhand": [0.02, 0.30, 1.40], "rhand": [0.10, 0.30, 2.00],
         "rpole": [1.0, -0.2, 0.0], "lpole": [-1.0, -0.2, 0.0]}
    h = {"hips": [0, 0.08, -0.30, 0, 20, 0], "chest": [0, 22, 0], "head": [0, -10],
         "lhand": [0.00, 0.42, 0.70], "rhand": [0.08, 0.42, 1.30],
         "rpole": [1.0, -0.3, 0.0], "lpole": [-1.0, -0.3, 0.0], "footL": [-0.06, 0.10, 0, 6, 0]}
    f = _mix(a, h, 1.06)
    return a, h, f


ARCH = {"hook": hook, "backhand": backhand, "overhead": overhead, "double_slam": double_slam, "thrust": thrust,
        "throw": throw, "plant": plant, "sweep_low": sweep_low, "cross_cut": cross_cut, "rush": rush,
        "scoop": scoop, "double_slice": double_slice, "whirl": whirl, "heave": heave, "keen": keen, "hush": hush, "rouse": rouse, "twist": twist,
        "oar_stroke": oar_stroke, "oar_back": oar_back, "oar_ship": oar_ship}

# foe id -> {"post": [0, 0.0], attacks: {attack id: (archetype, opts)}}
FOES = {
    "rimewalker": {"attacks": {
        "swipe": ("hook", {"amp": 1.1}), "flail": ("double_slam", {"amp": 1.1})}},
    "oarsman": {"attacks": {
        "stroke": ("oar_stroke", {}), "back_stroke": ("oar_back", {"strike": 0.14}), "ship_oars": ("oar_ship", {})}},
    "barrow_sleeper": {"attacks": {
        "hammer_fist": ("overhead", {"amp": 1.1}), "back_fist": ("backhand", {"side": "L"})}},
    "keener": {"attacks": {
        "breath_note": ("keen", {"amp": 0.8}), "keen": ("keen", {"amp": 1.25, "creep": 0.22}),
        "hush": ("hush", {}), "rouse": ("rouse", {})}},
    # the yoke and its stones ride the back: every raised hand stays wide and ahead of it
    "cairn_carrier": {"clear": [0.16, 0.14], "attacks": {
        "yoke_swing": ("twist", {}), "set_stone": ("plant", {}), "stone_toss": ("heave", {})}},
    "ice_fisher": {"attacks": {
        "pick": ("overhead", {"amp": 0.7, "reach": 0.74, "low": 1.0}), "pick_left": ("hook", {"side": "L"}),
        "cut_hole": ("plant", {})}},
    "sealer": {"attacks": {
        "club": ("overhead", {"amp": 1.15}), "backhand": ("backhand", {}), "hook": ("throw", {})}},
    "feast_guest": {"attacks": {
        "cuff": ("hook", {}), "cuff_left": ("hook", {"side": "L", "amp": 0.85}), "toast": ("overhead", {"amp": 0.9})}},
    "cupbearer": {"attacks": {
        "slice": ("double_slice", {"rise": 0.13, "strike": 0.09}), "lunge": ("thrust", {"amp": 1.1, "reach": 0.92}),
        "going_round": ("whirl", {"strike": 0.16})}},
    "hall_champion": {"attacks": {
        "mace": ("overhead", {"amp": 1.15}), "shield_bash": ("thrust", {"side": "L", "amp": 0.9, "height": 1.2}),
        "shield_rush": ("rush", {})}},
    "collier": {"attacks": {
        "rake": ("sweep_low", {}), "smother": ("double_slam", {}), "cinders": ("scoop", {})}},
    # Holdfasts. Kept on their own clips: transitions, holds, and the prompt
    # clips that read (back_drop, stack_sod, step_into, raise_guests, tip_horn,
    # the Netmender's haul and turn_away).
    "netmender": {"boss": True, "attacks": {
        "needle_stitch": ("thrust", {"amp": 0.9, "height": 1.12}), "one_hand_stitch": ("thrust", {"amp": 0.9, "height": 1.12}),
        "cast": ("throw", {}), "last_cast": ("throw", {"amp": 1.1}),
        "sea_weight": ("double_slam", {"amp": 0.9}), "knot": ("plant", {}), "mend_floor": ("plant", {"amp": 0.8})}},
    "turfwright": {"boss": True, "clear": [0.20, 0.22], "attacks": {
        "spade_chop": ("overhead", {}), "one_hand_chop": ("overhead", {"amp": 1.1}), "drag_swing": ("sweep_low", {}),
        "sod_throw": ("throw", {}), "ground_cut": ("plant", {}), "cross_cut": ("plant", {"amp": 0.9})}},
    "ice_cutter": {"boss": True, "attacks": {
        "auger_thrust": ("thrust", {"amp": 1.1}), "drill_down": ("plant", {}), "trace": ("throw", {}),
        "dog_team": ("rouse", {})}},
    "host": {"boss": True, "attacks": {
        "horn_fist": ("overhead", {"amp": 1.1}), "table_sweep": ("sweep_low", {"amp": 1.15}),
        "bench_throw": ("heave", {})}},
    "hedgelayer": {"boss": True, "attacks": {
        "bill": ("hook", {"amp": 1.05}), "thorn_lash": ("throw", {}), "raise_wall": ("plant", {})}},
}


def _clear(c, clear):
    """Keep raised hands off a load carried on the back: any hand above the
    shoulders is pushed out to its own side and forward."""
    c = dict(c)
    for k, sgn in (("rhand", 1.0), ("lhand", -1.0)):
        v = c.get(k)
        if isinstance(v, list) and v[2] > 1.35:
            c[k] = [v[0] + sgn * clear[0], max(v[1], 0.0) + clear[1], v[2]]
    return c


def telegraph(rig, fps, windup, arch, opts, post, clear=None):
    """Rise, HOLD, strike on `windup`, overshoot, held follow-through, recover."""
    o = dict(opts)
    side = o.pop("side", "R")
    rise = o.pop("rise", 0.26)
    strike = o.pop("strike", 0.11)
    creep = o.pop("creep", 0.10)
    a, h, f = ARCH[arch](**o)
    if side == "L":
        a, h, f = mirror(a), mirror(h), mirror(f)
    n = neutral(rig)
    a, h, f = _posture(a, post), _posture(h, post), _posture(f, post)
    if clear:
        a, h, f = _clear(a, clear), _clear(h, clear), _clear(f, clear)
    rise = min(rise, max(windup - strike - 0.02, 0.06) * 0.6)
    hold_end = windup - strike
    keys = [(0.0, "inout", n), (rise, "out", a)]
    if hold_end - rise > 0.06:
        # the held shape keeps winding a little: alive, and it reads as loading
        a2 = _mix(n, a, 1.0 + creep)
        a2["hips"] = [a2["hips"][0], a2["hips"][1], a2["hips"][2] - 0.015] + a2["hips"][3:]
        keys.append((hold_end, "inout", a2))
    keys += [(windup, "in", h), (windup + 0.07, "out", _mix(a, h, 1.07)), (windup + 0.16, "out", f),
             (windup + 0.38, "inout", f), (windup + 0.38 + 0.50, "inout", n)]
    # the neutral's stored wrist rotations only make sense at rest: free the
    # wrists for every posed key
    for _t, _k, c in keys[1:-1]:
        c.setdefault("rrot", None)
        c.setdefault("lrot", None)
    return rig.clip(keys, fps)


def build(ctx, root):
    """{clip name: poses}, and the meta the game needs (sections, clip sets)."""
    with open(os.path.join(root, "data/combat/enemies.json")) as fh:
        enemies = json.load(fh)
    with open(os.path.join(root, "data/anim/clip_meta.json")) as fh:
        models = json.load(fh)["models"]
    clips, rows, sets = {}, {}, {}
    for foe, spec in FOES.items():
        cfg = enemies.get(foe)
        if not cfg:
            continue
        # each foe is keyed on the way its own body stands (its idle's first
        # frame): the Netmender's hunch, the carrier's stoop under the yoke
        base = ctx.own_idle(str(cfg.get("model", "")))
        rig = A.Rig(ctx.skel, base, ctx.grips["onehand"], fist_from=ctx.stance())
        by_id = {a["id"]: a for a in cfg.get("attacks", [])}
        cs = {}
        for aid, (arch, opts) in spec["attacks"].items():
            if aid not in by_id:
                continue
            w = float(by_id[aid]["windup"])
            name = f"f_{foe}_{aid}"
            poses = telegraph(rig, ctx.fps, w, arch, opts, spec.get("post", [0, 0.0]), spec.get("clear"))
            clips[name] = poses
            rows[name] = {"start": 0.0, "contact": round(w, 3), "end": round((len(poses) - 1) / ctx.fps, 3)}
            cs["@" + aid] = [name]
        # hit react on the foe's own stance (the Bearer's is a sword stance);
        # a Holdfast's is slowed to fill its longer stagger
        st = C.react_front(ctx, base=base)
        if spec.get("boss"):
            st = A.warp(st, [(0, len(st), 1.9)])
        clips[f"f_{foe}_stagger"] = st
        rows[f"f_{foe}_stagger"] = {"start": 0.0, "end": round((len(st) - 1) / ctx.fps, 3)}
        cs["stagger"] = [f"f_{foe}_stagger"]
        sets[foe] = cs
    return clips, rows, sets
