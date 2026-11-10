"""Holdfast beats for build_combat_lib.py (ADR 0012 pass 3): the moves that
are not plain strikes. Spins that turn the whole body on the spot, the
Netmender's stitches, and the intro, hold and release beats (mending, tying
off, sitting back down, kneeling to lay the last turf).

Every function returns control-rig keys [(time s, ease, controls)] (see
anim_pose.Rig). Those bound to an attack take its DATA windup `w` and put
their beat on it; nothing here stores a windup.

These are grieving people. The beats are keyed slow and heavy: a head that
bows a moment after the hands have stopped, shoulders that drop last.
"""
import math

import anim_pose as A
import anim_rig as R

Z5 = [0, 0, 0, 0, 0]
Z6 = [0, 0, 0, 0, 0, 0]


def spin(rig, c, th):
    """Turn a whole control set `th` degrees about the vertical through the
    hips: pelvis, both hands, elbows and both feet go round together."""
    cx, cy, _ = A.rfu(rig.base.hips)
    co, si = math.cos(math.radians(th)), math.sin(math.radians(th))

    def rot(r, f):
        return [r * co - f * si, r * si + f * co]

    out = dict(c)
    h = list(c.get("hips") or Z6)
    h[0], h[1] = rot(h[0], h[1])
    h[3] += th
    out["hips"] = h
    for k in ("rhand", "lhand"):
        v = c.get(k)
        if isinstance(v, list):
            r, f = rot(v[0] - cx, v[1] - cy)
            out[k] = [r + cx, f + cy, v[2]]
    for k in ("rpole", "lpole"):
        v = c.get(k)
        if isinstance(v, list):
            out[k] = rot(v[0], v[1]) + [v[2]]
    for sd, k in (("Left", "footL"), ("Right", "footR")):
        f = c.get(k) or Z5
        p0 = A.rfu(rig.foot0[sd][0])
        r, fw = rot(p0[0] + f[0] - cx, p0[1] + f[1] - cy)
        out[k] = [r + cx - p0[0], fw + cy - p0[1], f[2], f[3] + th, f[4]]
    return out


def spin_span(rig, fps, t0, t1, c0, c1, th0, th1, kind="lin", step=0.0):
    """A key every frame from t0 (exclusive) to t1: the pose eases c0 -> c1
    while the body turns th0 -> th1. `step` lifts the feet in turn, once per
    half turn, so the spin is stepped round, not slid."""
    out = []
    n = max(1, int(round((t1 - t0) * fps)))
    for i in range(1, n + 1):
        u = i / n
        c = {k: A._lerp(c0.get(k), c1.get(k), u) for k in set(c0) | set(c1)}
        th = th0 + (th1 - th0) * R.ease(u, kind)
        if step:
            ph = (th % 360.0) / 180.0
            for k, on in (("footL", ph < 1.0), ("footR", ph >= 1.0)):
                f = list(c.get(k) or Z5)
                if on:
                    f[2] += step * math.sin(math.pi * (ph % 1.0))
                    f[4] += 18.0 * math.sin(math.pi * (ph % 1.0))
                c[k] = f
        out.append((t0 + (t1 - t0) * u, "lin", spin(rig, c, th)))
    return out


def _turned(n, th):
    """The rest pose, still facing where a spin left it (360 = 0, but the
    keys must not unwind)."""
    c = dict(n)
    c["hips"] = [0, 0, 0, th, 0, 0]
    c["footL"] = [0, 0, 0, th, 0]
    c["footR"] = [0, 0, 0, th, 0]
    return c


# ------------------------------------------------------------------ spins
def whirl(rig, fps, n, w, atk, **_):
    """The Cupbearer's going-round: side-on with both blades out level like
    a tray (held), then a full turn for every cut the data lists, stepped
    round on the balls of the feet, arms scything, and a skidding stop."""
    hits = [float(h) for h in atk.get("hits", [0.0])]
    tray = {"hips": [0, -0.02, -0.16, 0, 6, 0], "chest": [0, 4, 6], "head": [60, 0],
            "rhand": [0.20, 0.66, 1.04], "lhand": [-0.16, -0.62, 1.10],
            "rpole": [0.9, 0.2, -0.5], "lpole": [-0.9, -0.2, -0.5],
            "footL": [-0.04, 0.10, 0, 0, 0], "footR": [0.06, -0.12, 0, 0, 0], "fists": True}
    cut = {"hips": [0, 0, -0.20, 0, 8, 0], "chest": [20, 6, -8], "head": [20, 0],
           "rhand": [0.74, 0.16, 1.24], "lhand": [-0.58, -0.30, 0.98],
           "rpole": [0.6, -0.6, -0.5], "lpole": [-0.8, -0.2, -0.5],
           "footL": [-0.03, 0.05, 0, 0, 0], "footR": [0.05, -0.05, 0, 0, 0], "fists": True}
    a0, lead = -72.0, 0.15
    rise = min(0.24, (w - lead) * 0.5)
    keys = [(0.0, "inout", n), (rise, "out", spin(rig, tray, a0)),
            (w - lead, "inout", spin(rig, dict(tray, hips=[0, -0.03, -0.19, 0, 7, 0]), a0 - 10))]
    th = a0 - 10
    t = w - lead
    first = 110.0   # the first cut comes across the front on the windup
    keys += spin_span(rig, fps, t, w + hits[0], tray, cut, th, first, "in")
    th, t = first, w + hits[0]
    for h in hits[1:]:
        keys += spin_span(rig, fps, t, w + h, cut, cut, th, th + 360.0, "lin", step=0.07)
        th, t = th + 360.0, w + h
    stop = math.ceil((th + 170.0) / 360.0) * 360.0
    brake = dict(cut, hips=[0, 0.04, -0.26, 0, 12, 0], chest=[30, 10, -4],
                 rhand=[0.30, 0.56, 1.02], lhand=[-0.60, -0.30, 1.16])
    keys += spin_span(rig, fps, t, t + 0.26, cut, brake, th, stop, "out")
    keys += [(t + 0.50, "inout", spin(rig, brake, stop)), (t + 0.98, "inout", _turned(n, stop))]
    return keys


def ring_cut(rig, fps, n, w, atk, **_):
    """The Ice-cutter turns once on the spot with the auger tip trailing on
    the ice: the turn IS the tell, so it runs the length of the windup, low
    and gathering speed, and ends with the tip wrenched up out of the cut."""
    low = {"hips": [0.03, 0.0, -0.26, 0, 16, 0], "chest": [-14, 16, 6], "head": [-20, -4],
           "rhand": [0.52, 0.14, 0.46], "rpole": [0.9, -0.5, 0.3],
           "lhand": [-0.52, 0.10, 1.12], "lpole": [-0.7, -0.5, -0.4],
           "footL": [-0.06, 0.04, 0, 0, 0], "footR": [0.06, -0.04, 0, 0, 0], "fists": True}
    up = {"hips": [0, 0.04, 0.02, 0, -8, 0], "chest": [10, -14, 0], "head": [0, -10],
          "rhand": [0.34, 0.26, 1.78], "rpole": [1.0, -0.2, 0.3],
          "lhand": [-0.50, -0.16, 0.92], "lpole": [-0.7, -0.6, -0.3],
          "footL": [-0.06, 0.04, 0, 0, 0], "footR": [0.06, -0.04, 0.03, 0, 18], "fists": True}
    set_t, wrench = min(0.26, w * 0.2), 0.12
    keys = [(0.0, "inout", n), (set_t, "out", low)]
    keys += spin_span(rig, fps, set_t, w - wrench, low, dict(low, hips=[0.03, 0, -0.30, 0, 18, 0]), 0.0, 360.0,
                      "inout", step=0.05)
    keys += [(w, "in", spin(rig, up, 360.0)), (w + 0.34, "inout", spin(rig, up, 360.0)),
             (w + 0.90, "inout", _turned(n, 360.0))]
    return keys


def plank(th, toe=0.15, ankle=0.11, hip=0.93, behind=0.07):
    """The body rigid as a door, tipped `th` degrees forward about its toes:
    the hips and ankles go round the toes together, heels lifting."""
    c, s_ = math.cos(math.radians(th)), math.sin(math.radians(th))
    foot = [0, -toe * c + ankle * s_ + toe, toe * s_ + ankle * c - ankle, 0, th]
    return {"hips": [0, -behind * c + hip * s_ + behind, behind * s_ + hip * c - hip, 0, th, 0],
            "footL": list(foot), "footR": list(foot)}


def door_fall(rig, fps, n, w, atk, **_):
    """Both arms rise and it leans back, two breaths; then it falls forward
    full length, rigid, like a turf door coming down, the arms landing flat
    ahead. It lies there, and gets up off its hands and one knee."""
    up = {"hips": [0, -0.08, 0.03, 0, -12, 0], "chest": [0, -16, 0], "head": [0, -14],
          "rhand": [0.26, -0.12, 1.86], "lhand": [-0.26, -0.12, 1.86],
          "rpole": [1.0, 0.1, 0.4], "lpole": [-1.0, 0.1, 0.4], "fists": True,
          "footL": [0, 0, 0.03, 0, 14], "footR": [0, 0, 0.03, 0, 14]}
    breath = dict(up, hips=[0, -0.11, 0.05, 0, -16, 0], chest=[0, -24, 0], head=[0, -22])
    down = dict(plank(84), chest=[0, 2, 0], head=[0, -20], fists=True,
                rhand=[0.26, 1.50, 0.10], lhand=[-0.26, 1.50, 0.10],
                rpole=[1.0, 0, 0.2], lpole=[-1.0, 0, 0.2])
    slack = dict(down, head=[0, 4], rhand=[0.34, 1.40, 0.08], lhand=[-0.34, 1.40, 0.08])
    push = {"hips": [0, 0.50, -0.50, 0, 44, 0], "chest": [0, 16, 0], "head": [0, -6],
            "rhand": [0.26, 0.98, 0.10], "lhand": [-0.26, 0.98, 0.10],
            "footR": [0.0, -0.10, -0.03, 0, 70], "footL": [-0.02, 0.36, 0, 0, 0]}
    knee = {"hips": [0, 0.16, -0.34, 0, 20, 0], "chest": [0, 14, 0], "head": [0, 6],
            "rhand": [0.24, 0.40, 0.56], "lhand": [-0.22, 0.44, 0.62],
            "footR": [0.0, -0.20, 0, 0, 40], "footL": [-0.02, 0.26, 0, 0, 0]}
    b = (w - 0.3 - 0.16) / 4.0
    return [(0.0, "inout", n), (0.3, "out", up), (0.3 + b, "inout", breath), (0.3 + 2 * b, "inout", up),
            (0.3 + 3 * b, "inout", breath), (w - 0.16, "inout", dict(up, hips=[0, -0.12, 0.05, 0, -18, 0])),
            (w, "in", down), (w + 0.12, "out", slack), (w + 1.0, "inout", slack), (w + 1.45, "inout", push),
            (w + 1.8, "inout", knee), (w + 2.2, "inout", n)]


# ------------------------------------------------------- the Netmender
def stitch(rig, fps, n, w, atk, one=False, **_):
    """Needle stitches, small and fast, on her hunch: the right hand drawn
    back to the ear, then a jab for every hit the data lists (a late hit is
    re-cocked at the ear first). The arms stay inside her own width; the
    left hand holds the work still in front."""
    hits = [float(h) for h in atk.get("hits", [0.0])]
    ear = {"hips": [0.0, -0.05, -0.05, -14, 8, 0], "chest": [-12, 10, 0], "head": [14, 6],
           "rhand": [0.26, 0.0, 1.50], "rpole": [0.9, -0.5, -0.1]}
    jab = {"hips": [0.0, 0.16, -0.10, 12, 13, 0], "chest": [12, 16, 0], "head": [-12, 10],
           "rhand": [0.05, 0.64, 1.10], "rpole": [0.5, -0.5, -0.7]}
    back = {"hips": [0.0, 0.07, -0.07, -4, 10, 0], "chest": [-4, 12, 0], "head": [2, 8],
            "rhand": [0.22, 0.20, 1.34], "rpole": [0.8, -0.5, -0.3]}
    if not one:   # in her last phase the left hand is behind her back (a carry layer)
        ear["lhand"], ear["lpole"] = [-0.12, 0.36, 1.04], [-0.6, -0.4, -0.7]
        jab["lhand"] = [-0.18, 0.24, 0.98]
        back["lhand"] = [-0.14, 0.32, 1.02]
    rise = min(0.2, w * 0.4)
    keys = [(0.0, "inout", n), (rise, "out", ear),
            (w - 0.08, "inout", dict(ear, rhand=[0.27, -0.03, 1.53]))]
    t = w
    for i, h in enumerate(hits):
        # each jab lands a little lower and further than the last
        j = dict(jab, rhand=[0.05 - 0.02 * i, 0.64 + 0.03 * i, 1.10 - 0.05 * i])
        keys.append((w + h, "in", j))
        t = w + h
        if i + 1 < len(hits):
            gap = hits[i + 1] - h
            if gap > 0.34:   # a beat late: back to the ear, held, then in
                keys += [(t + 0.14, "out", ear), (t + gap - 0.08, "inout", dict(ear, rhand=[0.27, -0.03, 1.53]))]
            else:
                keys.append((t + gap * 0.5, "out", back))
    # the thread drawn up and out, long, before she lets it drop
    draw = dict(back, rhand=[0.40, 0.10, 1.46], hips=[0, 0.02, -0.04, -10, 6, 0], chest=[-12, 6, 0], head=[16, 0])
    keys += [(t + 0.07, "out", dict(jab, rhand=[0.04, 0.68, 1.06])), (t + 0.30, "out", draw),
             (t + 0.48, "inout", draw), (t + 0.92, "inout", n)]
    return keys


SEAT = {"hips": [0, -0.02, -0.56, 0, 14, 0], "footL": [-0.03, 0.22, 0, 6, 0], "footR": [0.03, 0.20, 0, -6, 0],
        "fists": False}


def nm_sit_mend(rig, fps, n, **_):
    """Seated, mending (loop): the needle goes in, the thread is drawn up
    long and slow, twice; then she ties off, pulls the knot tight, and bends
    to bite the twine. Her head follows the needle, never looks up."""
    work = dict(SEAT, chest=[0, 24, 0], head=[0, 28], lhand=[-0.14, 0.38, 0.70], lpole=[-0.7, -0.4, -0.5],
                rhand=[0.02, 0.42, 0.70], rpole=[0.7, -0.4, -0.5])
    drawn = dict(SEAT, hips=[0.02, -0.03, -0.55, -6, 12, 0], chest=[-8, 18, 0], head=[-16, 14],
                 lhand=[-0.14, 0.38, 0.72], rhand=[0.42, 0.26, 1.16], rpole=[0.9, -0.3, -0.3])
    tie = dict(work, rhand=[0.03, 0.38, 0.82], lhand=[-0.07, 0.38, 0.80])
    loop = dict(tie, rhand=[0.10, 0.34, 0.88], lhand=[-0.10, 0.40, 0.78])
    tight = dict(work, chest=[0, 20, 0], rhand=[0.24, 0.36, 0.84], lhand=[-0.28, 0.36, 0.80])
    bite = dict(SEAT, hips=[0, 0.0, -0.57, 0, 20, 0], chest=[0, 34, 0], head=[0, 34],
                rhand=[0.05, 0.34, 1.02], lhand=[-0.08, 0.34, 0.96], rpole=[0.9, -0.3, -0.2], lpole=[-0.9, -0.3, -0.2])
    return [(0.0, "inout", work), (0.25, "inout", work), (0.95, "inout", drawn), (1.15, "inout", drawn),
            (1.75, "inout", work), (2.0, "inout", work), (2.7, "inout", drawn), (2.9, "inout", drawn),
            (3.5, "inout", tie), (3.75, "inout", loop), (4.0, "inout", tie), (4.2, "out", tight),
            (4.5, "inout", tight), (5.0, "inout", bite), (5.4, "inout", bite), (6.0, "inout", work)]


def nm_sit_still(rig, fps, n, **_):
    """Released: she looks at her open hands, lets them fall, and sits back
    down, heavily. The hands come to rest in her lap; her head bows last."""
    look = {"hips": [0, 0, -0.03, 0, 6, 0], "chest": [0, 12, 0], "head": [0, 24],
            "rhand": [0.16, 0.32, 1.10], "lhand": [-0.16, 0.32, 1.08], "fists": False,
            "rpole": [0.7, -0.5, -0.5], "lpole": [-0.7, -0.5, -0.5]}
    fall = dict(look, chest=[0, 6, 0], head=[0, 10], rhand=[0.24, 0.10, 0.90], lhand=[-0.24, 0.10, 0.90])
    lower = dict(SEAT, hips=[0, -0.10, -0.40, 0, 22, 0], chest=[0, 20, 0], head=[0, 8],
                 rhand=[0.18, 0.28, 0.80], lhand=[-0.18, 0.28, 0.80])
    sat = dict(SEAT, chest=[0, 14, 0], head=[0, 6], rhand=[0.10, 0.32, 0.68], lhand=[-0.10, 0.32, 0.68])
    bowed = dict(SEAT, hips=[0, -0.02, -0.57, 0, 16, 0], chest=[0, 26, 0], head=[0, 36],
                 rhand=[0.08, 0.34, 0.66], lhand=[-0.08, 0.34, 0.66])
    return [(0.0, "inout", n), (0.6, "inout", look), (1.1, "inout", look), (1.6, "inout", fall),
            (2.4, "inout", lower), (2.9, "out", sat), (3.3, "inout", sat), (4.2, "inout", bowed)]


def nm_curl(rig, fps, n, w, atk, **_):
    """Hold: she crouches over and curls round what she carries, both arms
    wrapped across her chest, and rocks, slowly. Reached on the windup."""
    gather = {"hips": [0, 0.02, -0.14, 0, 14, 0], "chest": [0, 18, 0], "head": [0, 20],
              "rhand": [-0.06, 0.24, 1.12], "lhand": [0.08, 0.22, 1.00], "fists": False,
              "rpole": [0.8, -0.3, -0.5], "lpole": [-0.8, -0.3, -0.5]}
    curled = {"hips": [0, 0.0, -0.44, 0, 26, 0], "chest": [0, 36, 0], "head": [0, 38],
              "rhand": [-0.14, 0.30, 0.78], "lhand": [0.14, 0.28, 0.68],
              "footL": [-0.04, 0.06, 0, 8, 0], "footR": [0.04, -0.10, 0, -8, 14]}
    rock = dict(curled, hips=[0, 0.05, -0.46, 0, 30, 0], chest=[0, 40, 0])
    return [(0.0, "inout", n), (w * 0.35, "inout", gather), (w, "inout", curled), (w + 1.1, "inout", rock),
            (w + 2.2, "inout", curled), (w + 3.3, "inout", rock), (w + 4.4, "inout", curled)]


# ------------------------------------------------------------- kneeling
def kneel(depth=0.50, lean=10.0):
    """Down on the right knee, the left foot planted ahead."""
    return {"hips": [0, 0.06, -depth, 0, lean, 0], "footR": [0.0, -0.30, -0.03, 0, 78],
            "footL": [-0.02, 0.26, 0, 0, 0]}


def tw_turf_raise(rig, fps, n, **_):
    """At the door, the sod held up to the gap in both hands (loop): he
    presses it home, pats it twice with the flat of his hand, and leans his
    brow to it."""
    up = {"hips": [0, 0.04, 0, 0, 4, 0], "chest": [0, 0, 0], "head": [0, -14], "fists": False,
          "rhand": [0.20, 0.44, 1.50], "lhand": [-0.20, 0.44, 1.50],
          "rpole": [0.9, -0.3, -0.4], "lpole": [-0.9, -0.3, -0.4]}
    press = dict(up, hips=[0, 0.11, -0.01, 0, 8, 0], rhand=[0.20, 0.54, 1.52], lhand=[-0.20, 0.54, 1.52])
    pat_up = dict(press, rhand=[0.27, 0.46, 1.66], head=[-8, -18])
    pat = dict(press, rhand=[0.22, 0.56, 1.58], head=[-8, -18])
    brow = dict(press, hips=[0, 0.14, -0.03, 0, 9, 0], chest=[0, 12, 0], head=[0, 18])
    return [(0.0, "inout", up), (1.2, "inout", press), (1.9, "inout", pat_up), (2.1, "in", pat),
            (2.4, "out", pat_up), (2.6, "in", pat), (3.0, "inout", press), (4.0, "inout", brow),
            (5.0, "inout", brow), (6.2, "inout", up)]


def tw_lay_turf(rig, fps, n, **_):
    """Released: he kneels, lays the sod down square with both hands, presses
    it flat, and stays there with his hands on it and his head down."""
    chest_hold = {"hips": [0, 0, -0.04, 0, 6, 0], "chest": [0, 8, 0], "head": [0, 16], "fists": False,
                  "rhand": [0.18, 0.32, 1.20], "lhand": [-0.18, 0.32, 1.20],
                  "rpole": [0.9, -0.4, -0.3], "lpole": [-0.9, -0.4, -0.3]}
    down = dict(kneel(), chest=[0, 14, 0], head=[0, 22], rhand=[0.18, 0.50, 0.66], lhand=[-0.18, 0.50, 0.66])
    laid = dict(kneel(0.52, 24), chest=[0, 36, 0], head=[0, 20], rhand=[0.18, 0.66, 0.14], lhand=[-0.18, 0.66, 0.14])
    pressed = dict(kneel(0.54, 28), chest=[0, 40, 0], head=[0, 16], rhand=[0.20, 0.68, 0.10], lhand=[-0.20, 0.68, 0.10])
    bowed = dict(kneel(0.54, 26), chest=[0, 42, 0], head=[0, 42], rhand=[0.20, 0.68, 0.10], lhand=[-0.20, 0.68, 0.10])
    return [(0.0, "inout", n), (0.6, "inout", chest_hold), (1.5, "inout", down), (2.1, "inout", laid),
            (2.5, "out", pressed), (2.9, "inout", laid), (3.3, "out", pressed), (4.4, "inout", bowed)]


def _turf_held(sag=0.0):
    return dict(kneel(0.50, 4), chest=[0, -4 + sag * 20, 0], head=[0, -18 + sag * 30], fists=False,
                rhand=[0.20, 0.50, 1.32 - sag], lhand=[-0.20, 0.50, 1.32 - sag],
                rpole=[0.9, -0.4, -0.3], lpole=[-0.9, -0.4, -0.3])


def tw_last_turf(rig, fps, n, w, atk, **_):
    """He kneels and lifts the last sod to the doorway in both hands: up on
    the windup, and held there."""
    at_chest = dict(kneel(0.50, 12), chest=[0, 14, 0], head=[0, 18], fists=False,
                    rhand=[0.18, 0.34, 0.86], lhand=[-0.18, 0.34, 0.86],
                    rpole=[0.9, -0.4, -0.3], lpole=[-0.9, -0.4, -0.3])
    return [(0.0, "inout", n), (w * 0.45, "inout", at_chest), (w * 0.6, "inout", at_chest),
            (w, "inout", _turf_held()), (w + 1.0, "inout", _turf_held(0.03))]


def tw_last_turf_hold(rig, fps, n, **_):
    """Holding it there (loop): the arms tire and sag, and he lifts it again."""
    return [(0.0, "inout", _turf_held(0.03)), (1.8, "inout", _turf_held(0.12)), (2.2, "inout", _turf_held(0.12)),
            (3.0, "out", _turf_held(0.0)), (4.0, "inout", _turf_held(0.03))]


def _drill(lean=0.0, turn=0.0):
    """Kneeling over the auger: the right forearm upright on the ice, the
    left hand bearing down on it."""
    return dict(kneel(0.50, 22 + lean), chest=[turn, 26 + lean, 0], head=[-turn * 0.6, 20], fists=True,
                rhand=[0.10, 0.44, 0.34 - lean * 0.004], rpole=[0.8, -0.2, 0.9],
                lhand=[0.04, 0.40, 0.62 - lean * 0.004], lpole=[-0.9, -0.2, 0.3])


def ic_kneel_drill(rig, fps, n, **_):
    """Kneeling at the hole, drilling (loop): his weight goes down onto the
    auger and his shoulders work it round, and round."""
    return [(0.0, "inout", _drill(0, -10)), (0.5, "inout", _drill(8, 10)), (1.0, "inout", _drill(2, -10)),
            (1.5, "inout", _drill(10, 10)), (2.0, "inout", _drill(0, -10))]


def ic_kneel_down(rig, fps, n, w, atk, **_):
    """He kneels and sets the auger to the rim: set on the windup, then the
    first turns."""
    reach = dict(kneel(0.46, 10), chest=[0, 10, 0], head=[0, 22], rhand=[0.20, 0.40, 0.80], rpole=[0.8, -0.3, 0.6],
                 lhand=[-0.22, 0.28, 0.66], lpole=[-0.8, -0.4, -0.3])
    return [(0.0, "inout", n), (w * 0.5, "inout", reach), (w, "inout", _drill(0, -10)),
            (w + 0.5, "inout", _drill(8, 10)), (w + 1.0, "inout", _drill(2, -10))]


def ic_rest_auger(rig, fps, n, **_):
    """Released: he kneels at the rim, lets the auger arm come to rest across
    his knee, and breathes out. His shoulders drop; his head goes down."""
    down = dict(kneel(0.48, 8), chest=[0, 8, 0], head=[0, 10], rhand=[0.26, 0.24, 0.60], lhand=[-0.22, 0.30, 0.64],
                rpole=[0.8, -0.5, -0.2], lpole=[-0.8, -0.5, -0.2])
    rest = dict(kneel(0.50, 12), chest=[0, 16, 0], head=[0, 14], rhand=[0.20, 0.36, 0.30], lhand=[-0.20, 0.32, 0.60])
    breath = dict(kneel(0.49, 8), chest=[0, 8, 0], head=[0, 2], rhand=[0.20, 0.36, 0.30], lhand=[-0.20, 0.32, 0.60])
    out = dict(kneel(0.52, 16), chest=[0, 28, 0], head=[0, 38], rhand=[0.20, 0.38, 0.26], lhand=[-0.20, 0.34, 0.56])
    return [(0.0, "inout", n), (1.2, "inout", down), (2.0, "inout", rest), (2.8, "inout", breath),
            (4.2, "inout", out)]


# ---------------------------------------------------------------- the Host
def _pour(tip=0.0, along=0.0):
    return {"hips": [along, 0.06, -0.03, 0, 8, 0], "chest": [0, 10 + tip * 8, 0], "head": [0, 16 + tip * 6],
            "rhand": [0.10 + along, 0.48 + tip * 0.04, 1.38 - tip * 0.16], "rpole": [0.9, -0.4, -0.1],
            "lhand": [-0.14 + along, 0.46, 1.02], "lpole": [-0.8, -0.5, -0.4], "fists": True}


def host_pour_horn(rig, fps, n, **_):
    """Filling the horns along the table (loop): he lifts the horn, tips it
    and pours with care, steadies the cup with his left hand, nods to the
    place, and moves along to the next."""
    nod = dict(_pour(0.0), head=[14, 26])
    return [(0.0, "inout", _pour(0)), (0.7, "inout", _pour(1)), (1.9, "inout", _pour(1.15)),
            (2.5, "inout", _pour(0)), (2.9, "inout", nod), (3.3, "inout", _pour(0)),
            (4.1, "inout", _pour(0, 0.07)), (4.8, "inout", _pour(1, 0.07)), (5.9, "inout", _pour(1.15, 0.07)),
            (6.5, "inout", _pour(0, 0.07)), (7.4, "inout", _pour(0))]


def host_set_horn(rig, fps, n, w=1.6, atk=None, **_):
    """He reaches the horn to the table: his hand on it on the windup, and
    it stays there a moment longer than it needs to."""
    reach = {"hips": [0, 0.10, -0.08, -8, 14, 0], "chest": [-8, 16, 0], "head": [6, 18],
             "rhand": [0.22, 0.62, 1.02], "rpole": [0.9, -0.4, -0.2],
             "lhand": [-0.30, 0.20, 0.92], "lpole": [-0.7, -0.5, -0.4]}
    linger = dict(reach, hips=[0, 0.11, -0.09, -8, 15, 0], head=[6, 24])
    return [(0.0, "inout", n), (w * 0.55, "inout", reach), (w, "inout", linger), (w + 0.5, "inout", linger),
            (w + 1.2, "inout", n)]


def host_sit(rig, fps, n, **_):
    """Released: he sets the horn down beside him, his hand slow to leave
    it, and sinks onto the bench end, heavily; hands on his knees, and the
    great head bows last."""
    set_down = {"hips": [0.04, 0.04, -0.14, -14, 14, 0], "chest": [-14, 16, 0], "head": [10, 20],
                "rhand": [0.42, 0.30, 0.86], "rpole": [0.9, -0.5, -0.1],
                "lhand": [-0.28, 0.16, 0.92], "lpole": [-0.7, -0.5, -0.4], "fists": False}
    leave = dict(set_down, rhand=[0.36, 0.26, 0.96], head=[14, 26])
    seat = {"footL": [-0.04, 0.20, 0, 8, 0], "footR": [0.04, 0.18, 0, -8, 0], "fists": False}
    lower = dict(seat, hips=[0, -0.10, -0.30, 0, 24, 0], chest=[0, 20, 0], head=[0, 8],
                 rhand=[0.26, 0.30, 0.82], lhand=[-0.26, 0.30, 0.82], rpole=[0.9, -0.5, -0.1], lpole=[-0.9, -0.5, -0.1])
    sat = dict(seat, hips=[0, -0.04, -0.47, 0, 10, 0], chest=[0, 10, 0], head=[0, 4],
               rhand=[0.22, 0.34, 0.66], lhand=[-0.22, 0.34, 0.66])
    bowed = dict(seat, hips=[0, -0.03, -0.48, 0, 14, 0], chest=[0, 26, 0], head=[0, 40],
                 rhand=[0.20, 0.36, 0.64], lhand=[-0.20, 0.36, 0.64])
    return [(0.0, "inout", n), (0.9, "inout", set_down), (1.5, "inout", set_down), (2.0, "inout", leave),
            (2.9, "inout", lower), (3.4, "out", sat), (3.9, "inout", sat), (5.0, "inout", bowed)]


# ----------------------------------------------------------- the Hedgelayer
def hl_lay_stem(rig, fps, n, **_):
    """Laying a stem (loop): he reaches up for it, bends it down across the
    hedge with his weight, tucks it under with the left hand and holds it
    until it stays."""
    reach = {"hips": [0.02, 0.06, 0.02, -6, -2, 0], "chest": [-8, -6, 0], "head": [-10, -18], "fists": False,
             "rhand": [0.30, 0.42, 1.66], "rpole": [0.9, -0.3, -0.2],
             "lhand": [-0.22, 0.36, 1.04], "lpole": [-0.7, -0.5, -0.4]}
    bend = {"hips": [-0.03, 0.08, -0.14, 10, 12, 0], "chest": [14, 16, 0], "head": [10, 18], "fists": False,
            "rhand": [-0.14, 0.50, 1.00], "rpole": [0.9, -0.2, 0.2],
            "lhand": [-0.26, 0.44, 0.98], "lpole": [-0.8, -0.4, -0.3]}
    tuck = dict(bend, hips=[-0.04, 0.09, -0.18, 12, 14, 0], rhand=[-0.16, 0.52, 0.94], lhand=[-0.10, 0.54, 0.86])
    hold = dict(tuck, head=[10, 26])
    ease_off = dict(bend, hips=[0, 0.05, -0.05, 2, 6, 0], chest=[2, 8, 0], rhand=[0.10, 0.40, 1.06],
                    lhand=[-0.22, 0.40, 1.00], head=[0, 12])
    return [(0.0, "inout", reach), (0.5, "inout", reach), (1.5, "inout", bend), (2.0, "inout", tuck),
            (2.9, "inout", hold), (3.7, "inout", ease_off), (4.8, "inout", reach)]


def hl_kneel_hands(rig, fps, n, **_):
    """Released: he kneels and puts both hands flat on the ground, and his
    head goes down between them."""
    down = dict(kneel(0.48, 8), chest=[0, 10, 0], head=[0, 14], fists=False,
                rhand=[0.22, 0.30, 0.60], lhand=[-0.22, 0.30, 0.60], rpole=[0.8, -0.5, -0.1], lpole=[-0.8, -0.5, -0.1])
    hands = dict(kneel(0.54, 30), chest=[0, 36, 0], head=[0, 10], fists=False,
                 rhand=[0.20, 0.62, 0.07], lhand=[-0.20, 0.62, 0.07], rpole=[0.9, -0.3, 0.3], lpole=[-0.9, -0.3, 0.3])
    bowed = dict(kneel(0.58, 36), chest=[0, 46, 0], head=[0, 44], fists=False,
                 rhand=[0.20, 0.62, 0.07], lhand=[-0.20, 0.62, 0.07])
    return [(0.0, "inout", n), (1.2, "inout", down), (1.5, "inout", down), (2.3, "inout", hands),
            (2.9, "inout", hands), (4.2, "inout", bowed)]


def _gap(side=0.0, drop=0.0, look=0.0):
    """Hands held up either side of the gap, as if it were a thing to hold."""
    return {"hips": [side, 0.04, -0.02, 0, 4, 0], "chest": [0, 4, 0], "head": [look, 6 + drop * 40], "fists": False,
            "rhand": [0.34 + side, 0.46, 1.40 - drop], "lhand": [-0.34 + side, 0.46, 1.40 - drop],
            "rpole": [0.9, -0.4, -0.3], "lpole": [-0.9, -0.4, -0.3],
            "footL": [side, 0, 0, 0, 0], "footR": [side, 0, 0, 0, 0]}


def hl_where(rig, fps, n, w, atk, **_):
    """He turns to the gap and holds his hands up either side of it."""
    return [(0.0, "inout", n), (w * 0.5, "inout", _gap(0, 0.25)), (w, "inout", _gap()), (w + 0.8, "inout", _gap())]


def hl_measure(rig, fps, n, **_):
    """Measuring the gap (loop): he looks from one hand to the other, steps
    to the other side of it, measures it again, and his hands sink: it will
    not come right. Then he tries once more."""
    step_mid = dict(_gap(0.11), footR=[0.22, 0, 0.06, 0, 10], footL=[0, 0, 0, 0, 0])
    back_mid = dict(_gap(0.11), footL=[0, 0, 0.06, 0, 10], footR=[0.22, 0, 0, 0, 0])
    return [(0.0, "inout", _gap()), (0.7, "inout", _gap(0, 0, 22)), (1.4, "inout", _gap(0, 0, -22)),
            (2.0, "inout", _gap()), (2.35, "inout", step_mid), (2.7, "inout", dict(_gap(0.22), footL=[0, 0, 0, 0, 0])),
            (3.0, "inout", _gap(0.22)), (3.8, "inout", _gap(0.22, 0, -22)), (4.6, "inout", _gap(0.22, 0.16)),
            (5.6, "inout", _gap(0.22, 0.20)), (6.0, "inout", back_mid),
            (6.4, "inout", dict(_gap(0), footR=[0.22, 0, 0, 0, 0])), (6.8, "inout", _gap(0, 0.1)), (7.6, "inout", _gap())]


def hl_step_into(rig, fps, n, w, atk, **_):
    """He walks backward into the thorn, arms folding over his chest, head
    going down: three steps, the last on the windup, and it closes over him."""
    def back(df, du=0.0, yaw=0.0):
        return [0.01, df, du, yaw, 0]
    k = [(0.0, "inout", n)]
    t3 = w / 3.0
    arms = [([0.14, 0.24, 1.14], [-0.14, 0.22, 1.08]), ([-0.06, 0.18, 1.26], [0.06, 0.16, 1.18]),
            ([-0.14, 0.14, 1.30], [0.14, 0.12, 1.22])]
    for i in range(3):
        d0, d1 = -0.22 * i, -0.22 * (i + 1)
        r, l = arms[i]
        mover, other = ("footR", "footL") if i % 2 == 0 else ("footL", "footR")
        mid = {"hips": [0, (d0 + d1) / 2 - 0.02, -0.03, 0, -4 + 4 * i, 0], "chest": [0, 4 + 6 * i, 0],
               "head": [0, 8 + 10 * i], mover: back(d1 - 0.06, 0.09), "fists": False}
        down = {"hips": [0, d1, -0.05 - 0.02 * i, 0, -2 + 5 * i, 0], "chest": [0, 6 + 6 * i, 0],
                "head": [0, 12 + 10 * i], mover: back(d1 - 0.12), "rhand": r, "lhand": l,
                "rpole": [0.7, -0.4, -0.6], "lpole": [-0.7, -0.4, -0.6], "fists": False}
        k += [(t3 * (i + 0.5), "inout", mid), (t3 * (i + 1), "inout", down)]
    last = dict(k[-1][2])
    last["footL"] = back(-0.78)
    k += [(w + 0.3, "inout", last), (w + 0.6, "inout", last)]
    return k
