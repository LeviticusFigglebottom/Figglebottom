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
    # mid-spin the arms are not a T: the leading blade is carried high on a
    # bent arm ahead of the turn, the trailing one low and behind, and the
    # trunk leans into the circle
    cut = {"hips": [0, 0, -0.22, 0, 12, -6], "chest": [26, 10, -14], "head": [24, 4],
           "rhand": [0.56, 0.36, 1.40], "lhand": [-0.40, -0.40, 0.84],
           "rpole": [0.9, -0.2, 0.2], "lpole": [-0.5, -0.8, 0.1],
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
    # the skid: side-on and sunk over a braced front foot, the leading blade
    # brought down across the body as a guard, the trailing one tucked back
    # at the hip (it used to stop with both arms flung out level)
    brake = dict(cut, hips=[0.02, 0.06, -0.30, -24, 14, 0], chest=[-16, 14, -4], head=[36, 4],
                 rhand=[0.10, 0.50, 1.06], lhand=[-0.30, -0.16, 0.84],
                 rpole=[0.7, -0.3, -0.7], lpole=[-0.5, -0.8, -0.3],
                 footR=[0.10, 0.30, 0, -12, 0], footL=[-0.08, -0.20, 0, 22, 12])
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
    """He walks backward into the thorn, upright, three long deliberate
    steps, the last on the windup; his arms cross over his chest as he goes
    (they travel back with him) and only his head goes down. It closes over
    him."""
    def back(df, du=0.0, pitch=0.0):
        return [0.01, df, du, 0, pitch]
    k = [(0.0, "inout", n)]
    t3 = w / 3.0
    stride = 0.26
    # [right, forward of the chest, up]: open, half folded, crossed on the breastbone
    arms = [([0.20, 0.20, 1.10], [-0.20, 0.18, 1.06]), ([0.02, 0.21, 1.24], [-0.04, 0.19, 1.16]),
            ([-0.12, 0.17, 1.32], [0.12, 0.15, 1.24])]
    for i in range(3):
        d0, d1 = -stride * i, -stride * (i + 1)
        r, l = arms[i]
        mover = "footR" if i % 2 == 0 else "footL"
        # the foot is lifted clear and reached back; the trunk stays over the standing leg
        mid = {"hips": [0, d0 - 0.05, 0.0, 0, -3, 0], "chest": [0, -2, 0],
               "head": [0, 4 + 8 * i], mover: back(d1 - 0.10, 0.14, 24), "fists": False}
        down = {"hips": [0, d1, -0.02, 0, -2, 0], "chest": [0, 0, 0],
                "head": [0, 8 + 9 * i], mover: back(d1 - 0.10), "rhand": [r[0], r[1] + d1, r[2]],
                "lhand": [l[0], l[1] + d1, l[2]],
                "rpole": [0.8, -0.3, -0.5], "lpole": [-0.8, -0.3, -0.5], "fists": False}
        k += [(t3 * (i + 0.5), "inout", mid), (t3 * (i + 1), "inout", down)]
    last = dict(k[-1][2])
    last["footL"] = back(-stride * 3 - 0.02)
    last["head"] = [0, 34]
    k += [(w + 0.3, "inout", last), (w + 0.6, "inout", last)]
    return k


# ===================================================== Shepherd's Reach
def _keys(n, *ks):
    """[(t, ease, controls)] from the rest and back to it."""
    return [(0.0, "inout", n)] + list(ks)


def crook_sweep(rig, fps, n, w, atk, **_):
    """The Drover's sweep. The crook goes back over the LEFT shoulder in
    both hands, his long frame wound round after it and sunk (held); then one
    long flat cut, left to right, arms right out, on a reaching step; it
    carries him round until the crook trails behind his right hip."""
    a = {"hips": [-0.06, -0.14, -0.05, 40, 0, 4], "chest": [38, -4, 6], "head": [-62, 0],
         "rhand": [-0.34, -0.02, 1.66], "lhand": [-0.42, -0.14, 1.48],
         "rpole": [0.6, 0.5, -0.4], "lpole": [-0.9, -0.3, -0.2],
         "footL": [-0.07, -0.20, 0, 24, 0], "footR": [0.03, 0.06, 0, 0, 0]}
    a2 = dict(a, hips=[-0.07, -0.17, -0.07, 44, 0, 5], chest=[42, -5, 7], rhand=[-0.38, -0.08, 1.68],
              lhand=[-0.45, -0.20, 1.50])
    mid = {"hips": [0.0, 0.12, -0.16, 6, 10, 0], "chest": [4, 8, 0], "head": [-8, 0],
           "rhand": [-0.30, 0.74, 1.30], "lhand": [-0.40, 0.50, 1.24], "rpole": [0.8, -0.2, -0.5],
           "footR": [0.06, 0.34, 0.06, -6, -10]}
    h = {"hips": [0.05, 0.34, -0.20, -30, 14, -4], "chest": [-36, 12, -6], "head": [52, -4],
         "rhand": [0.62, 0.66, 1.18], "lhand": [0.22, 0.60, 1.16], "rpole": [0.8, -0.4, -0.4],
         "lpole": [-0.7, -0.3, -0.5],
         "footR": [0.08, 0.46, 0, -12, 0], "footL": [-0.07, -0.20, 0.07, 24, 34]}
    f = {"hips": [0.09, 0.38, -0.28, -52, 18, -6], "chest": [-56, 14, -8], "head": [70, 0],
         "rhand": [0.80, -0.10, 0.96], "lhand": [0.44, 0.22, 1.02],
         "footR": [0.08, 0.46, 0, -12, 0], "footL": [-0.09, -0.08, 0.04, 10, 40]}
    s = 0.15
    return _keys(n, (0.26, "out", a), (w - s, "inout", a2), (w - s * 0.45, "in", mid), (w, "lin", h),
                 (w + 0.14, "out", f), (w + 0.52, "inout", f), (w + 1.08, "inout", n))


def leg_hook(rig, fps, n, w, atk, **_):
    """The crook turned over, hook down, and slid out along the ground: he
    goes down on a long bent leg behind it and feeds it out, further, until
    his arms are straight (the windup). It bites; then he sits back on his
    heels and hauls, hand over hand, for as long as the pull lasts."""
    pull = float(atk.get("pull_time", 0.4))
    low = {"hips": [0.02, 0.16, -0.20, -10, 26, 0], "chest": [-8, 26, 0], "head": [10, -22],
           "rhand": [0.14, 0.60, 0.50], "lhand": [0.02, 0.38, 0.64],
           "rpole": [0.9, -0.3, 0.3], "lpole": [-0.9, -0.3, 0.3],
           "footL": [-0.05, 0.44, 0, 6, 0], "footR": [0.06, -0.26, 0.0, -14, 20]}
    out = dict(low, hips=[0.02, 0.44, -0.30, -14, 40, 0], chest=[-10, 34, 0], head=[14, -38],
               rhand=[0.10, 1.22, 0.28], lhand=[0.00, 0.96, 0.38],
               footL=[-0.05, 0.70, 0, 6, 0], footR=[0.06, -0.34, 0.03, -14, 40])
    bite = dict(out, rhand=[0.10, 1.20, 0.36], lhand=[0.00, 0.94, 0.46], hips=[0.02, 0.42, -0.30, -12, 38, 0])
    back = {"hips": [0.0, -0.10, -0.30, 14, -6, 0], "chest": [16, -10, 0], "head": [-24, 4],
            "rhand": [0.26, 0.10, 0.84], "lhand": [0.10, 0.30, 0.78],
            "rpole": [0.8, -0.8, 0.0], "lpole": [-0.8, -0.5, 0.0],
            "footL": [-0.05, 0.56, 0, 6, -12], "footR": [0.06, -0.34, 0, -14, 0]}
    back2 = dict(back, hips=[0.0, -0.14, -0.32, 18, -8, 0], rhand=[0.30, -0.06, 0.88], lhand=[0.14, 0.14, 0.80])
    return _keys(n, (0.30, "out", low), (w - 0.07, "inout", out), (w, "in", bite), (w + pull * 0.55, "out", back),
                 (w + pull, "inout", back2), (w + pull + 0.30, "inout", back2), (w + pull + 0.85, "inout", n))


def whistle_in(rig, fps, n, w, atk, **_):
    """Two fingers to the mask and his head goes back; the breath is drawn
    (held), then sent straight up: the chest jumps and the head snaps
    further back. The crook stays planted beside him."""
    draw = {"hips": [0, -0.03, 0.0, 0, -4, 0], "chest": [0, -8, 0], "head": [0, -16], "fists": False,
            "lhand": [-0.05, 0.19, 1.60], "lpole": [-1.0, -0.2, 0.2], "lrot": [-70, 60, 0],
            "rhand": [0.34, 0.16, 1.00], "rpole": [0.8, -0.6, 0.0]}
    full = dict(draw, hips=[0, -0.05, 0.02, 0, -8, 0], chest=[0, -16, 0], head=[0, -30],
                lhand=[-0.05, 0.13, 1.63])
    blow = dict(full, hips=[0, -0.02, 0.05, 0, -10, 0], chest=[0, -22, 0], head=[0, -40],
                lhand=[-0.05, 0.10, 1.66], footL=[0, 0, 0.02, 0, 12], footR=[0, 0, 0.02, 0, 12])
    return _keys(n, (0.28, "out", draw), (w - 0.10, "inout", full), (w, "in", blow), (w + 0.34, "inout", blow),
                 (w + 0.80, "inout", n))


def kneel_fall(rig, fps, n, lean=1.0, **_):
    """A death that is a stopping: the head comes up, the knees go, it sits
    back on its heels a moment with its hands open, and folds forward over
    them. Nothing is thrown."""
    hit = {"hips": [0, -0.08, 0.02, 0, -8, 0], "chest": [0, -14, 0], "head": [0, -20], "fists": False,
           "rhand": [0.34, 0.06, 1.00], "lhand": [-0.34, 0.06, 1.00]}
    knees = {"hips": [0, 0.06, -0.50, 0, 4, 0], "chest": [0, 6, 0], "head": [0, 6], "fists": False,
             "footR": [0.02, -0.26, -0.03, 0, 78], "footL": [-0.02, -0.22, -0.03, 0, 78],
             "rhand": [0.26, 0.16, 0.56], "lhand": [-0.26, 0.16, 0.56],
             "rpole": [0.7, -0.7, 0.0], "lpole": [-0.7, -0.7, 0.0]}
    sat = dict(knees, hips=[0, -0.04, -0.60, 0, 10, 0], chest=[0, 22, 0], head=[0, 30],
               rhand=[0.24, 0.26, 0.40], lhand=[-0.24, 0.26, 0.40])
    # folded right down over its own knees, the brow to the ground between
    # the hands (the feet stay under it: nothing slides)
    over = dict(knees, hips=[0, 0.10 * lean, -0.62, 0, 44, 0], chest=[0, 40, 0], head=[0, 24],
                rhand=[0.26, 0.62 * lean, 0.08], lhand=[-0.26, 0.58 * lean, 0.08],
                rpole=[1.0, -0.2, 0.3], lpole=[-1.0, -0.2, 0.3])
    slack = dict(over, hips=[0, 0.12 * lean, -0.65, 0, 50, 0], chest=[0, 46, 0], head=[18, 30],
                 rhand=[0.34, 0.56 * lean, 0.06], lhand=[-0.32, 0.60 * lean, 0.06])
    return _keys(n, (0.16, "out", hit), (0.62, "in", knees), (1.20, "inout", sat), (1.52, "inout", sat),
                 (1.96, "in", over), (2.14, "out", slack), (2.6, "inout", slack))


def drover_fall(rig, fps, n, **_):
    """The Drover's death: the same stopping (kneel_fall), but he is too
    long to stay folded. From his knees he tips on over his hands and goes
    down his full length, face to the turf, one arm under his head, and the
    last thing to move is his heels settling."""
    k = [(t * 0.8, e, c) for t, e, c in kneel_fall(rig, fps, n)[:-1]]   # to the fold over his knees, a little quicker
    t = k[-1][0]
    tip = {"hips": [0, 0.46, -0.66, 0, 70, 0], "chest": [0, 26, 0], "head": [30, 0], "fists": False,
           "footR": [0.05, -0.38, -0.02, 0, 84], "footL": [-0.05, -0.34, -0.02, 0, 84],
           "rhand": [0.36, 0.98, 0.10], "lhand": [-0.22, 1.16, 0.10],
           "rpole": [1.0, 0.0, 0.4], "lpole": [-1.0, 0.0, 0.4]}
    flat = dict(tip, hips=[0, 0.52, -0.80, 0, 86, 0], chest=[0, 4, 0], head=[56, -8],
                footR=[0.10, -0.42, -0.04, -12, 88], footL=[-0.10, -0.38, -0.04, 12, 88],
                rhand=[0.42, 0.92, 0.07], lhand=[-0.16, 1.24, 0.07])
    rest = dict(flat, hips=[0, 0.52, -0.82, 0, 88, 0], head=[60, -10],
                footR=[0.14, -0.42, -0.05, -20, 90], footL=[-0.13, -0.38, -0.05, 18, 90])
    return k + [(t + 0.42, "in", tip), (t + 0.62, "out", flat), (t + 1.1, "inout", rest), (t + 1.3, "inout", rest)]


# ----------------------------------------------------------- Old Calder
def calder_sit(rig, fps, n, **_):
    """Old Calder sat on the wall he has finished (loop): low, knees apart,
    hands on his knees, an old back. He breathes, looks along the wall, and
    his thumb goes down the tally stick at his belt."""
    sat = {"hips": [0, -0.16, -0.38, 0, -6, 0], "chest": [0, 16, 0], "head": [0, 4], "fists": False,
           "footL": [-0.10, 0.20, 0, 14, 0], "footR": [0.10, 0.24, 0, -14, 0],
           "rhand": [0.24, 0.26, 0.60], "lhand": [-0.24, 0.24, 0.60],
           "rrot": None, "lrot": None,
           "rpole": [0.9, -0.5, 0.1], "lpole": [-0.9, -0.5, 0.1]}
    breath = dict(sat, hips=[0, -0.16, -0.375, 0, -7, 0], chest=[0, 13, 0], head=[0, 2])
    look = dict(breath, chest=[14, 14, 0], head=[36, 0])
    tally = dict(sat, chest=[-8, 20, 0], head=[-20, 22], lhand=[-0.26, 0.06, 0.74], lpole=[-0.9, -0.6, 0.3])
    return [(0.0, "inout", sat), (1.6, "inout", breath), (3.2, "inout", sat), (4.6, "inout", look),
            (6.4, "inout", look), (7.6, "inout", sat), (9.0, "inout", tally), (10.6, "inout", dict(tally, lhand=[-0.26, 0.06, 0.66])),
            (12.0, "inout", sat)]


# ============================================================== Coldwell
def shoulder_shove(rig, fps, n, w, atk, **_):
    """The Upwalker turns side-on and drops the near shoulder, arms tucked,
    its whole weight drawn back over the far leg (one slow step, held);
    then it simply goes through: the shoulder driven forward and up on a
    long step, the body behind it like a door."""
    a = {"hips": [-0.02, -0.16, -0.10, 52, 2, 8], "chest": [20, 8, 10], "head": [-64, 6],
         "lhand": [-0.06, 0.20, 1.10], "lpole": [-0.9, -0.2, -0.3],
         "rhand": [0.30, -0.06, 0.96], "rpole": [0.7, -0.7, 0.0],
         "footR": [0.06, -0.24, 0, -40, 0], "footL": [-0.03, 0.10, 0, 20, 0]}
    a2 = dict(a, hips=[-0.02, -0.21, -0.13, 56, 0, 10], chest=[22, 8, 12])
    h = {"hips": [0.0, 0.46, -0.12, 60, 16, -8], "chest": [24, 12, -14], "head": [-70, -4],
         "lhand": [-0.10, 0.34, 1.16], "rhand": [0.34, -0.26, 1.04],
         "footL": [-0.04, 0.56, 0, 24, 0], "footR": [0.06, -0.14, 0.07, -30, 38]}
    f = dict(h, hips=[0.0, 0.56, -0.10, 62, 20, -12], chest=[26, 14, -18], lhand=[-0.14, 0.44, 1.22])
    return _keys(n, (0.40, "inout", a), (w - 0.18, "inout", a2), (w, "in", h), (w + 0.12, "out", f),
                 (w + 0.50, "inout", f), (w + 1.20, "inout", n))


def let_go(rig, fps, n, w, atk, **_):
    """It stops, and sways back on its heels, twice, breathing; its arms
    hang. Then it goes over on its face full length like a climber letting
    go, arms not catching it. It lies there, and gets its knees under it."""
    stop = {"hips": [0, -0.03, 0.0, 0, -4, 0], "chest": [0, -6, 0], "head": [0, -6], "fists": False,
            "rhand": [0.30, -0.04, 0.92], "lhand": [-0.30, -0.04, 0.92],
            "rpole": [0.6, -0.8, 0.0], "lpole": [-0.6, -0.8, 0.0]}
    back = dict(stop, hips=[0, -0.10, 0.02, 0, -12, 0], chest=[0, -14, 0], head=[0, -16],
                rhand=[0.34, -0.14, 0.94], lhand=[-0.34, -0.14, 0.94],
                footL=[0, 0, 0.0, 0, -8], footR=[0, 0, 0.0, 0, -8])
    down = dict(plank(84), chest=[0, 2, 0], head=[24, -10], fists=False,
                rhand=[0.52, 0.76, 0.08], lhand=[-0.48, 0.80, 0.08], rpole=[1.0, 0, 0.3], lpole=[-1.0, 0, 0.3])
    slack = dict(down, head=[30, 4], rhand=[0.56, 0.70, 0.06], lhand=[-0.52, 0.74, 0.06])
    push = {"hips": [0, 0.50, -0.50, 0, 44, 0], "chest": [0, 16, 0], "head": [0, -6],
            "rhand": [0.28, 0.98, 0.10], "lhand": [-0.28, 0.98, 0.10],
            "footR": [0.0, -0.10, -0.03, 0, 70], "footL": [-0.02, 0.36, 0, 0, 0]}
    knee = {"hips": [0, 0.16, -0.34, 0, 20, 0], "chest": [0, 14, 0], "head": [0, 6],
            "rhand": [0.24, 0.40, 0.56], "lhand": [-0.22, 0.44, 0.62],
            "footR": [0.0, -0.20, 0, 0, 40], "footL": [-0.02, 0.26, 0, 0, 0]}
    lie = float(atk.get("recover", 2.2))
    b = (w - 0.26 - 0.17) / 4.0
    return _keys(n, (0.26, "out", stop), (0.26 + b, "inout", back), (0.26 + 2 * b, "inout", stop),
                 (0.26 + 3 * b, "inout", back), (w - 0.17, "inout", dict(back, hips=[0, -0.12, 0.02, 0, -14, 0])),
                 (w, "in", down), (w + 0.12, "out", slack), (w + lie * 0.5, "inout", slack),
                 (w + lie * 0.72, "inout", push), (w + lie * 0.88, "inout", knee), (w + lie + 0.1, "inout", n))


def ask(rig, fps, n, w, atk, left=False, **_):
    """The Unsung's reach: a hand brought up, palm up, close in, as if to be
    given something (held, and it creeps out); on the windup the arm goes
    right out after it on a step and the whole thin body leans to follow.
    The fingers close on nothing, and the hand is drawn back to the chest."""
    s = -1.0 if left else 1.0
    hk, pk, rk, ok = ("lhand", "lpole", "lrot", "rhand") if left else ("rhand", "rpole", "rrot", "lhand")
    palm = [s * 90, 170, 0]
    offer = {"hips": [0, -0.03, -0.03, s * -8, 4, 0], "chest": [s * -8, 6, 0], "head": [s * 6, 8], "fists": False,
             hk: [s * 0.16, 0.34, 1.08], pk: [s * 0.5, -0.6, -0.6], rk: palm,
             ok: [s * -0.22, 0.10, 0.98]}
    offer2 = dict(offer, hips=[0, 0.0, -0.04, s * -6, 6, 0])
    offer2[hk] = [s * 0.14, 0.44, 1.12]
    out = {"hips": [0, 0.30, -0.12, s * 22, 14, 0], "chest": [s * 24, 12, 0], "head": [s * -20, -6], "fists": False,
           hk: [s * 0.02, 0.92, 1.22], rk: palm, ok: [s * -0.24, 0.16, 0.94],
           "footL" if not left else "footR": [s * -0.02, 0.36, 0, 0, 0],
           "footR" if not left else "footL": [0, 0, 0.05, 0, 28]}
    far = dict(out, hips=[0, 0.34, -0.14, s * 26, 16, 0])
    far[hk] = [s * -0.02, 0.98, 1.20]
    took = {"hips": [0, 0.14, -0.06, s * 6, 8, 0], "chest": [s * 4, 12, 0], "head": [0, 20], "fists": True,
            hk: [s * 0.06, 0.26, 1.24], rk: None, ok: [s * -0.24, 0.04, 0.98]}
    st = 0.10
    return _keys(n, (min(0.2, (w - st) * 0.6), "out", offer), (w - st, "inout", offer2), (w, "in", out),
                 (w + 0.08, "out", far), (w + 0.26, "inout", far), (w + 0.56, "inout", took),
                 (w + 0.90, "inout", n))


def breath_in(rig, fps, n, w, atk, **_):
    """The mask tips back and it draws a long breath, as before a first
    note: the chest fills for the whole of the windup, the shoulders lift,
    the hands open a little at its sides. No note comes. It lets the breath
    go and everything in it drops: shoulders, hands, head."""
    half = {"hips": [0, -0.02, 0.01, 0, -4, 0], "chest": [0, -8, 0], "head": [0, -14], "fists": False,
            "rhand": [0.34, 0.06, 0.98], "lhand": [-0.34, 0.06, 0.98],
            "rpole": [0.6, -0.8, 0.0], "lpole": [-0.6, -0.8, 0.0],
            "bones": {"LeftShoulder": [0, 0, -6], "RightShoulder": [0, 0, 6]}}
    full = dict(half, hips=[0, -0.05, 0.03, 0, -9, 0], chest=[0, -18, 0], head=[0, -30],
                rhand=[0.42, 0.02, 1.06], lhand=[-0.42, 0.02, 1.06],
                bones={"LeftShoulder": [0, 0, -14], "RightShoulder": [0, 0, 14]},
                footL=[0, 0, 0.02, 0, 10], footR=[0, 0, 0.02, 0, 10])
    gone = {"hips": [0, 0.04, -0.08, 0, 10, 0], "chest": [0, 18, 0], "head": [0, 30], "fists": False,
            "rhand": [0.26, 0.12, 0.86], "lhand": [-0.26, 0.12, 0.86],
            "bones": {"LeftShoulder": [0, 0, 6], "RightShoulder": [0, 0, -6]},
            "footL": list(Z5), "footR": list(Z5)}
    return _keys(n, (w * 0.4, "inout", half), (w - 0.14, "inout", full), (w, "in", gone), (w + 0.5, "inout", gone),
                 (w + 1.0, "inout", dict(n, bones={"LeftShoulder": [0, 0, 0], "RightShoulder": [0, 0, 0]})))


def unsung_break(rig, fps, n, **_):
    """It breaks: the hands come up open as if something had been put in
    them after all, the head lifts, and it stands a breath like that before
    the ice lets go (the dissolve takes it standing)."""
    given = {"hips": [0, 0.0, 0.01, 0, -3, 0], "chest": [0, -8, 0], "head": [0, -18], "fists": False,
             "rhand": [0.16, 0.30, 1.14], "lhand": [-0.16, 0.30, 1.14], "rrot": [90, 170, 0], "lrot": [-90, 170, 0],
             "rpole": [0.6, -0.6, -0.4], "lpole": [-0.6, -0.6, -0.4]}
    still = dict(given, hips=[0, 0.0, -0.03, 0, 2, 0], chest=[0, 2, 0], head=[0, 14],
                 rhand=[0.15, 0.28, 1.08], lhand=[-0.15, 0.28, 1.08])
    return _keys(n, (0.22, "out", given), (0.6, "inout", still), (1.4, "inout", still))


# ------------------------------------------------------- the Fellcaller
def _horn_up(tilt=0.0, rise=0.0):
    """The horn in her right fist, its mouthpiece at the mask (the prop is
    mounted for these clips: clip_meta models.fellcaller.held; the horn on
    her belt is part of her mesh and stays there); tilt 1 = thrown right
    back, calling at the sky."""
    return {"hips": [0, -0.02 - 0.06 * tilt, 0.0 + 0.04 * rise, 0, -4 - 10 * tilt, 0],
            "chest": [0, -4 - 20 * tilt, 0], "head": [0, -6 - 30 * tilt],
            "rhand": [0.07, 0.17 - 0.42 * tilt, 1.66 + 0.10 * tilt], "rpole": [1.0, -0.2, -0.1 + 0.3 * tilt],
            "rrot": [180, 0, -90],   # fingers up, palm across the mouth
            "lhand": [-0.36, 0.02 - 0.16 * tilt, 0.96], "lpole": [-0.6, -0.8, 0.0], "fists": True,
            "footL": [0, 0, 0.03 * rise, 0, 14 * rise], "footR": [0, 0, 0.03 * rise, 0, 14 * rise]}


def rising_cry(rig, fps, n, w, atk, **_):
    """She gathers over the horn, low; brings it to her mask; and her head
    goes back, further and further as the breath is drawn (the hold). On
    the windup the cry goes up: she is thrown right back under it, up on
    her toes, and held there. A second cry (the data's `hits`) is drawn and
    thrown the same way."""
    hits = [float(h) for h in atk.get("hits", [0.0])]
    gather = {"hips": [0, 0.06, -0.14, 0, 16, 0], "chest": [0, 20, 0], "head": [0, 16],
              "rhand": [0.10, 0.34, 1.20], "rpole": [0.9, -0.4, -0.2],
              "lhand": [-0.30, 0.16, 0.90], "lpole": [-0.7, -0.6, 0.0], "fists": True}
    k = _keys(n, (0.26, "out", gather), (0.52, "inout", _horn_up(0.0)), (w - 0.13, "inout", _horn_up(0.55)))
    t = w
    for i, h in enumerate(hits):
        t = w + h
        k.append((t, "in", _horn_up(1.0, 1.0)))
        if i + 1 < len(hits):
            gap = hits[i + 1] - h
            k += [(t + gap * 0.35, "inout", _horn_up(1.0, 1.0)), (t + gap * 0.7, "inout", _horn_up(0.3)),
                  (t + gap - 0.12, "inout", _horn_up(0.55))]
    return k + [(t + 0.55, "inout", _horn_up(0.9, 0.6)), (t + 1.25, "inout", n)]


def fc_call(rig, fps, n, **_):
    """Calling over the fold wall (loop): the horn comes to her mask, she
    leans back into a long call, and lowers it to listen, her head turning
    to where the flock should be. Then again."""
    listen = {"hips": [0, 0.02, -0.02, 0, 4, 0], "chest": [10, 4, 0], "head": [24, 4],
              "rhand": [0.24, 0.30, 1.22], "rpole": [0.9, -0.5, -0.2],
              "lhand": [-0.34, 0.06, 0.96], "lpole": [-0.6, -0.8, 0.0], "fists": True}
    listen2 = dict(listen, chest=[-8, 4, 0], head=[-22, 2])
    return [(0.0, "inout", listen), (0.7, "inout", _horn_up(0.0)), (1.5, "inout", _horn_up(0.7, 0.4)),
            (2.9, "inout", _horn_up(0.8, 0.5)), (3.6, "inout", listen), (4.5, "inout", listen2),
            (5.4, "inout", listen2), (6.2, "inout", listen)]


def head_down(rig, fps, n, w, atk, **_):
    """She drops her head till the ram's horns point down the strip, arms
    swept back, and scrapes one foot back, twice. On the windup she goes:
    low, the horns leading, four driving strides for the length of the run
    (the game moves her); then she cannot stop, is carried upright past it,
    and shakes her head clear."""
    run = float(atk.get("active", 0.8))
    low = {"hips": [0, 0.10, -0.22, 0, 30, 0], "chest": [0, 34, 0], "head": [0, 26], "headfree": True,
           "rhand": [0.50, -0.34, 0.98], "lhand": [-0.50, -0.34, 0.98], "fists": True,
           "rpole": [0.7, -0.8, 0.2], "lpole": [-0.7, -0.8, 0.2]}
    sc0 = dict(low, footR=[0.02, 0.12, 0.05, 0, 14])
    sc1 = dict(low, hips=[0, 0.12, -0.25, 0, 33, 0], footR=[0.02, -0.34, 0.0, 0, 26])
    k = _keys(n, (0.26, "out", low))
    t0, per = 0.30, (w - 0.30 - 0.08) / 2.0
    for i in range(2):
        k += [(t0 + per * (i + 0.45), "inout", sc0), (t0 + per * (i + 1.0), "in", sc1)]
    # the run: strides in place, the trunk level and driving
    drive = dict(low, hips=[0, 0.22, -0.26, 0, 38, 0], chest=[0, 36, 0], head=[0, 30],
                 rhand=[0.46, -0.44, 1.04], lhand=[-0.46, -0.44, 1.04])
    n_st = max(2, int(round(run / 0.2)))
    st = run / n_st
    k.append((w, "in", dict(drive, footL=[-0.02, 0.40, 0.0, 0, -10], footR=[0.02, -0.40, 0.10, 0, 50])))
    for i in range(1, n_st + 1):
        lead, trail = ("footR", "footL") if i % 2 else ("footL", "footR")
        d = dict(drive)
        d[lead] = [0.0, 0.42, 0.0, 0, -10]
        d[trail] = [0.0, -0.42, 0.12, 0, 54]
        d["hips"] = [0, 0.22, -0.26 + (0.03 if i % 2 else 0.0), 0, 38, 0]
        k.append((w + st * i, "lin", d))
    t = w + run
    over = {"hips": [0, 0.16, -0.08, 0, 6, 0], "chest": [0, -4, 0], "head": [0, -8], "headfree": True,
            "rhand": [0.44, 0.10, 1.04], "lhand": [-0.44, 0.10, 1.04],
            "footL": [-0.06, 0.34, 0, 8, 0], "footR": [0.06, 0.10, 0, -8, 0]}
    sh_l = dict(over, hips=[0, 0.12, -0.10, 0, 12, 0], chest=[0, 10, 0], head=[34, 14])
    sh_r = dict(over, hips=[0, 0.12, -0.10, 0, 12, 0], chest=[0, 10, 0], head=[-34, 14])
    return k + [(t + 0.30, "out", over), (t + 0.52, "inout", sh_l), (t + 0.70, "inout", sh_r),
                (t + 0.88, "inout", sh_l), (t + 1.04, "inout", dict(sh_r, head=[-16, 8])), (t + 1.45, "inout", n)]


def call_them_in(rig, fps, n, w, atk, **_):
    """One arm out flat to the side, the horn at her mask: a long level
    call, her body leaning away from the arm (held). On the windup the arm
    comes round and down the strip, pointing it, and she steps into it."""
    level = dict(_horn_up(0.1), hips=[0.04, -0.02, -0.02, -10, -4, 4], chest=[-12, -4, 6],
                 lhand=[-0.76, 0.02, 1.44], lpole=[-0.5, -0.8, -0.2], fists=False)
    level2 = dict(level, hips=[0.05, -0.03, -0.03, -14, -5, 5], lhand=[-0.78, -0.10, 1.48])
    send = dict(_horn_up(0.0), hips=[-0.03, 0.20, -0.10, 14, 10, -2], chest=[18, 10, -4], head=[-10, 4],
                rhand=[0.18, 0.30, 1.40], lhand=[-0.14, 0.86, 1.22], lpole=[-0.8, -0.3, -0.4], fists=False,
                footL=[-0.03, 0.30, 0, 6, 0], footR=[0.03, 0, 0.05, 0, 26])
    hold = dict(send, hips=[-0.03, 0.22, -0.12, 16, 12, -2], lhand=[-0.10, 0.88, 1.12])
    return _keys(n, (0.36, "out", level), (w - 0.22, "inout", level2), (w, "in", send), (w + 0.14, "out", hold),
                 (w + 0.80, "inout", hold), (w + 1.40, "inout", n))


def bring_tups(rig, fps, n, w, atk, **_):
    """Two short calls: the horn at her mask dips, and dips again on the
    windup, her whole body nodding with it; then she looks to the wall."""
    up = _horn_up(0.25)
    dip = dict(_horn_up(0.0), hips=[0, 0.06, -0.10, 0, 12, 0], chest=[0, 14, 0], head=[0, 10],
               rhand=[0.08, 0.34, 1.44])
    look = dict(_horn_up(0.0), chest=[-16, 0, 0], head=[-34, -4], rhand=[0.20, 0.30, 1.30])
    return _keys(n, (0.26, "out", up), (w * 0.5 - 0.08, "inout", _horn_up(0.35)), (w * 0.5, "in", dip),
                 (w * 0.5 + 0.2, "out", up), (w - 0.09, "inout", _horn_up(0.4)), (w, "in", dip),
                 (w + 0.3, "out", look), (w + 0.7, "inout", look), (w + 1.2, "inout", n))


def _fc_kneel(bow=0.0):
    return dict(kneel(0.50, 8 + 10 * bow), chest=[0, 8 + 14 * bow, 0], head=[0, 6 + 28 * bow], fists=False,
                rhand=[0.22, 0.30, 0.52 - 0.06 * bow], lhand=[-0.20, 0.34, 0.60 - 0.04 * bow],
                rpole=[0.8, -0.5, -0.1], lpole=[-0.8, -0.5, -0.1])


def count_them(rig, fps, n, w, atk, **_):
    """She turns to her father and comes down to his height, the horn
    lowered, and calls once, low: head level, the horn barely lifted."""
    down = _fc_kneel(0.0)
    call = dict(kneel(0.48, 4), chest=[0, 2, 0], head=[0, -4], fists=True,
                rhand=[0.08, 0.26, 1.12], rpole=[1.0, -0.3, 0.0], lhand=[-0.20, 0.34, 0.60], lpole=[-0.8, -0.5, -0.1])
    return _keys(n, (w * 0.5, "inout", down), (w * 0.72, "inout", down), (w, "inout", call),
                 (w + 1.0, "inout", call))


def fc_kneel_down(rig, fps, n, **_):
    """She kneels by him. The horn is set down on the ground beside her,
    her hand slow to leave it; her hands come to her knees; her head bows."""
    set_h = dict(kneel(0.52, 16), chest=[-10, 20, 0], head=[8, 20], fists=False,
                 rhand=[0.40, 0.30, 0.12], rpole=[0.9, -0.3, 0.2], lhand=[-0.20, 0.34, 0.60], lpole=[-0.8, -0.5, -0.1])
    return [(0.0, "inout", n), (1.3, "inout", _fc_kneel(0.0)), (2.2, "inout", set_h), (2.8, "inout", set_h),
            (3.7, "inout", _fc_kneel(0.2)), (5.0, "inout", _fc_kneel(1.0))]


def fc_arms_up(rig, fps, n, **_):
    """Both arms up, the horn over her head: a call that does not rise.
    Her arms come down slowly through it, and her head with them."""
    up = {"hips": [0, -0.04, 0.03, 0, -8, 0], "chest": [0, -14, 0], "head": [0, -22], "fists": True,
          "rhand": [0.26, 0.10, 2.02], "lhand": [-0.30, 0.10, 1.96], "rpole": [1.0, -0.1, 0.2], "lpole": [-1.0, -0.1, 0.2],
          "footL": [0, 0, 0.02, 0, 10], "footR": [0, 0, 0.02, 0, 10]}
    sink = dict(up, hips=[0, 0.0, -0.04, 0, 2, 0], chest=[0, 4, 0], head=[0, 8],
                rhand=[0.34, 0.22, 1.66], lhand=[-0.40, 0.22, 1.60], footL=list(Z5), footR=list(Z5))
    return [(0.0, "inout", n), (0.6, "out", up), (1.6, "inout", dict(up, hips=[0, -0.05, 0.04, 0, -10, 0])),
            (2.6, "inout", sink), (3.2, "inout", n)]


# -------------------------------------------------------- the Leadvoice
# She never strikes and never reaches for the Bearer. Everything is small:
# the head, the breath in the chest, the arms round the child.
LV_CLOSE = (48.0, 100.0)   # an arm brought round the child: degrees inward, degrees raised forward


def _rel(n, key, dr=0.0, df=0.0, du=0.0):
    v = n[key]
    return [v[0] + dr, v[1] + df, v[2] + du]


def _lv(n, lift=0.0, pitch=0.0, head=(0, 0), close=0.0, rise=0.0, open_=0.0):
    """lift: chest opened (breath). pitch: bowed over the child. close: her
    arms brought round it (1 = closed). open_: an arm let fall a little
    open, away from it.

    Her model decides what can move. The swaddle is bound to her chest. Her
    cloak and the ice at its hem hang from her hips and spine
    (tools/art/fix_leadvoice_cloak.py; they used to be skinned to her
    forearms and fingers, and came up off the ground with them), so the
    pelvis never turns and her legs hang from it (legs_fk). Her real arms
    are one rigid piece each on the upper-arm bones: they are keyed by
    rotation in the chest's frame (cbones), never by a wrist target, so they
    ride the bow and close the same way sat or stood."""
    yaw, up = LV_CLOSE[0] * close - 10.0 * open_, LV_CLOSE[1] * close
    return {"hips": [0, 0, rise, 0, 0, 0], "legs_fk": True,
            "chest": [0, pitch - lift, 0], "head": [head[0], head[1]], "fists": False,
            "rhand": None, "lhand": None, "rrot": None, "lrot": None,
            "cbones": {"LeftArm": [-yaw, -up, 0], "RightArm": [yaw, -up, 0]},
            "bones": {"LeftShoulder": [0, 0, -lift * 0.5], "RightShoulder": [0, 0, lift * 0.5]}}


def _lv_n(rig, n):
    # no wrist targets: her arms hang as her stance has them
    return dict(n, legs_fk=True, fists=False, rhand=None, lhand=None, rrot=None, lrot=None,
                cbones={"LeftArm": [0, 0, 0], "RightArm": [0, 0, 0]})


def lv_held_note(rig, fps, n, w, atk, amp=1.0, **_):
    """Her mask comes up off the child and stays up: a thin breath, drawn
    slowly, and held out. Nothing else moves."""
    n = _lv_n(rig, n)
    up = _lv(n, lift=6 * amp, head=(0, -14 * amp))
    drawn = _lv(n, lift=11 * amp, head=(0, -20 * amp), rise=0.01 * amp)
    note = _lv(n, lift=7 * amp, head=(0, -16 * amp))
    return _keys(n, (0.5, "inout", up), (w - 0.2, "inout", drawn), (w, "inout", note), (w + 0.9, "inout", note),
                 (w + 1.8, "inout", n))


def lv_long_note(rig, fps, n, w, atk, amp=1.0, **_):
    """She draws herself up and the breath goes on and on: taller through
    the whole windup, her free hand falling open; the note is held as long
    as the data's last hit, and she settles only after it."""
    n = _lv_n(rig, n)
    hits = [float(h) for h in atk.get("hits", [0.0])]
    up = _lv(n, lift=8 * amp, head=(0, -12 * amp), rise=0.01)
    tall = _lv(n, lift=16 * amp, head=(0, -26 * amp), rise=0.03 * amp, open_=1.0)
    note = _lv(n, lift=12 * amp, head=(0, -22 * amp), rise=0.02 * amp, open_=1.0)
    k = _keys(n, (0.6, "inout", up), (w - 0.2, "inout", tall), (w, "inout", note))
    t = w
    for h in hits[1:]:
        k += [(w + h - 0.5, "inout", tall), (w + h, "inout", note)]
        t = w + h
    return k + [(t + 1.0, "inout", note), (t + 2.0, "inout", n)]


def lv_not_yet(rig, fps, n, w, atk, amp=1.0, **_):
    """She breathes in as if to begin, and holds it, and does not begin:
    the breath is let go on the windup and her head comes down a long way."""
    n = _lv_n(rig, n)
    inb = _lv(n, lift=12 * amp, head=(0, -12 * amp), rise=0.01)
    held = _lv(n, lift=14 * amp, head=(0, -14 * amp), rise=0.015)
    gone = _lv(n, lift=-4, pitch=10, head=(0, 26), close=0.4)
    return _keys(n, (w * 0.4, "inout", inb), (w - 0.3, "inout", held), (w, "inout", gone), (w + 0.7, "inout", gone),
                 (w + 1.4, "inout", n))


def lv_come_up(rig, fps, n, w, atk, **_):
    """Her head turns to the gap in the stones, and stays there."""
    n = _lv_n(rig, n)
    turn = _lv(n, lift=4, head=(-44, -6))
    stay = _lv(n, lift=5, head=(-50, -8))
    return _keys(n, (w * 0.6, "inout", turn), (w, "inout", stay), (w + 0.8, "inout", stay), (w + 1.5, "inout", n))


def lv_shelter(rig, fps, n, w, atk, amp=1.0, **_):
    """She folds herself down over the child and both arms come round it,
    slowly, the left a moment before the right, her head over its head.
    Held, with one small rock; and slowly up again, the arms last."""
    n = _lv_n(rig, n)
    half = _lv(n, pitch=12 * amp, head=(0, 14), close=0.45)
    over = _lv(n, pitch=28 * amp, head=(0, 32), close=1.0)
    rock = _lv(n, pitch=31 * amp, head=(0, 36), close=1.06)
    up = _lv(n, pitch=8 * amp, head=(0, 12), close=0.7)
    return _keys(n, (w * 0.5, "inout", half), (w, "inout", over), (w + 0.6, "inout", rock), (w + 1.2, "inout", over),
                 (w + 1.9, "inout", up), (w + 2.8, "inout", n))
