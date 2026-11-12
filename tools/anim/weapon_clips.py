"""Per-weapon clips for the Bearer (ADR 0014), built by build_combat_lib.py.

The class sets of ADR 0011 gave every blade the sword's cuts and every haft
the greatsword's. These are the clips a weapon needs because of what it is:

  brand    the torch: carried aloft, a jab, a sweeping brand strike, an
           overhead smash, a running thrust
  chopper  the carving cleaver: short hacks from the shoulder, not sword cuts
  maul     the post maul: the head hangs and is hauled; every blow is paid for
  polearm  the turf spade and the hedging bill: hands spread on the haft,
           hooking cuts, a couched running thrust
  twohand  the greatblade's carry (on the shoulder)

Every strike is keyed so its contact frame IS the strike time the player
state machine uses (movesets.json windup + 0.45 * active): the clip plays at
1x and no timing data moves. Changing a windup means rebuilding the library;
the `anim` suite checks every row. Rows (start/contact/end) are written into
clip_meta.json `clips` by the build; clip sets and classes are hand data there.

Key poses are controls on anim_pose.Rig. A weapon control is the grip point,
where the head points, and (worked out here, `W`) the roll about the haft
that leaves the wrist straightest.
"""
import json
import os

from mathutils import Vector

import anim_pose as A

SHOULDER = Vector((0.20, 0.0, 1.42))   # right shoulder in the stance, [r, f, u]
DOWN = Vector((0.0, 0.0, -1.0))


def W(g, d, lean=0.0):
    """Weapon control [grip, direction, edge]. The mesh's edge side (+Z) lies
    along the knuckles, so the natural roll puts it along the forearm; where
    the weapon is in line with the arm (a thrust) the fist rolls palm-in."""
    gv, dv = Vector(g), Vector(d).normalized()
    e = gv - SHOULDER + Vector((0.0, 0.0, -lean))
    e = e - dv * e.dot(dv)
    if e.length < 0.25:   # in line with the arm: knuckles down and out
        e = DOWN * 0.8 + Vector((0.5, 0.0, 0.0))
        e = e - dv * e.dot(dv)
    e.normalize()
    return list(g) + list(dv) + list(e)


def strike_time(move):
    return max(float(move["windup"]) + float(move["active"]) * 0.45, 0.12)


def total_time(move):
    return float(move["windup"]) + float(move["active"]) + float(move["recovery"])


class Moves:
    def __init__(self, root):
        with open(os.path.join(root, "data/combat/movesets.json")) as fh:
            self.ms = json.load(fh)

    def get(self, moveset, which):
        m = self.ms[moveset]
        if which.startswith("l"):
            return m["lights"][int(which[1:]) - 1]
        return m[which]


# ---------------------------------------------------------------- the brand
BR_CARRY = {"weapon": W([0.40, 0.32, 1.30], [0.16, 0.24, 0.96]), "rpole": [0.8, -0.5, -0.6]}
Z6, Z5, Z3 = [0] * 6, [0] * 5, [0, 0, 0]


def _br_base():
    return dict(BR_CARRY, hips=Z6, chest=Z3, head=[0, 0], footL=Z5, footR=Z5)


def _idle_rig(c, grip):
    """Carries are an arms-only layer over his own idle, walk and run, so
    they are keyed on that upright body, not on the fighting crouch: an arm
    pose keyed on the crouch points a head higher once the chest stands up."""
    return A.Rig(c.skel, c.own_idle("bearer_traveller"), c.grips[grip], fist_from=c.stance())


def _arms(ctl):
    return {k: ctl[k] for k in ("weapon", "left", "rpole", "lpole") if k in ctl}


def _br_rig(c):
    """The brand is not fought from the sword's deep crouch: he stands
    taller under it, the light held over what he is looking at."""
    tall = c.rig("brand").solve({"hips": [0, 0, 0.035, 0, -9, 0], "chest": [0, -13, 0], "head": [0, -4]})
    return A.Rig(c.skel, tall, c.grips["brand"], fist_from=c.stance())


def br_carry(c):
    """Held aloft (arms-only layer, right arm): the flame clear of the hood,
    out to the side, breathing a little so the light is never dead still."""
    rig = _idle_rig(c, "brand")
    a = {"weapon": W([0.42, 0.26, 1.36], [0.16, 0.22, 0.96]), "rpole": [0.8, -0.5, -0.6]}
    b = {"weapon": W([0.425, 0.265, 1.375], [0.19, 0.24, 0.95]), "rpole": [0.8, -0.5, -0.6]}
    return rig.clip([(0.0, "inout", a), (1.3, "inout", b), (2.6, "inout", a)], c.fps)


def br_jab(c, m):
    """Light 1: the brand is pulled back to the shoulder and punched at the
    face, the weight going in behind it; snatched back before it is caught."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = _br_rig(c)
    back = dict(hips=[0, -0.07, -0.03, -24, 0, 0], chest=[-18, 0, 0], head=[20, 0],
                weapon=W([0.38, -0.08, 1.46], [0.02, 0.90, 0.44]), rpole=[1.0, -0.5, -0.2])
    hit = dict(hips=[0, 0.24, -0.08, 16, 7, 0], chest=[22, 6, 0], head=[-18, -2], footL=[-0.02, 0.36, 0, 0, 0],
               footR=[0, 0, 0.05, 0, 26], weapon=W([0.12, 0.74, 1.44], [-0.06, 0.98, 0.18]), rpole=[0.8, -0.3, -0.6])
    over = dict(hit, hips=[0, 0.27, -0.09, 18, 8, 0], weapon=W([0.11, 0.80, 1.44], [-0.06, 0.98, 0.16]))
    out = dict(hips=[0, 0.10, -0.04, 2, 2, 0], chest=[2, 2, 0], head=[0, 0], footL=[-0.02, 0.22, 0, 0, 0],
               footR=Z5, weapon=W([0.30, 0.34, 1.42], [0.06, 0.62, 0.78]), rpole=[0.9, -0.3, -0.5])
    return rig.clip([(0.0, "inout", _br_base()), (t * 0.5, "out", back), (t - 0.02, "in", hit), (t + 0.06, "out", over),
                     (t + 0.18, "inout", over), (t + 0.36, "inout", out), (end, "inout", _br_base())], c.fps), t, end


def br_sweep(c, m):
    """Light 2: the sweeping brand strike. Swung flat from wide on the right
    across the front, fire streaming behind the head, the body turning
    through with it."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = _br_rig(c)
    wide = dict(hips=[0.02, -0.04, -0.04, -22, 0, 0], chest=[-30, 0, 0], head=[26, 0],
                weapon=W([0.66, 0.02, 1.32], [0.80, -0.25, 0.55]), rpole=[0.6, -0.8, -0.3])
    mid = dict(hips=[0, 0.08, -0.06, 2, 4, 0], chest=[2, 4, 0], head=[0, 0],
               weapon=W([0.50, 0.50, 1.30], [0.62, 0.74, 0.26]), rpole=[0.8, -0.3, -0.6])
    hit = dict(hips=[0, 0.16, -0.08, 20, 6, 0], chest=[30, 6, 0], head=[-24, 0], footL=[-0.04, 0.26, 0, 6, 0],
               footR=[0, 0, 0.04, 0, 20], weapon=W([0.02, 0.66, 1.28], [-0.30, 0.94, 0.16]), rpole=[0.7, -0.2, -0.7])
    over = dict(hit, hips=[0, 0.17, -0.09, 28, 6, 0], chest=[44, 6, 0],
                weapon=W([-0.30, 0.46, 1.22], [-0.84, 0.52, 0.12]), rpole=[0.5, -0.2, -0.9])
    out = dict(hips=[0, 0.08, -0.04, 6, 2, 0], chest=[10, 2, 0], head=[-4, 0], footL=[-0.03, 0.16, 0, 3, 0],
               footR=Z5, weapon=W([0.10, 0.44, 1.36], [-0.20, 0.50, 0.84]), rpole=[0.9, -0.3, -0.5])
    return rig.clip([(0.0, "inout", _br_base()), (t * 0.5, "out", wide), (t - 0.07, "in", mid), (t, "inout", hit),
                     (t + 0.09, "out", over), (t + 0.2, "inout", over), (t + 0.4, "inout", out),
                     (end, "inout", _br_base())], c.fps), t, end


def br_smash(c, m):
    """Heavy: the overhead brand smash. Hung high behind the head for the
    whole wind-up, then brought down on the crown with a deep step; the head
    is held where it landed, guttering, before he straightens."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = _br_rig(c)
    up = dict(hips=[0, -0.06, 0.02, -12, -6, 0], chest=[-12, -12, 0], head=[8, -8],
              weapon=W([0.30, -0.10, 1.88], [0.12, -0.42, 0.90]), rpole=[1.0, -0.2, 0.2])
    hang = dict(up, hips=[0, -0.08, 0.03, -14, -8, 0], chest=[-14, -16, 0],
                weapon=W([0.30, -0.15, 1.92], [0.12, -0.58, 0.80]))
    top = dict(hips=[0, 0.06, 0.0, 0, 2, 0], chest=[0, 2, 0], head=[0, 0],
               weapon=W([0.24, 0.30, 1.84], [0.04, 0.55, 0.83]), rpole=[1.0, -0.2, 0.0])
    hit = dict(hips=[0, 0.26, -0.22, 8, 16, 0], chest=[10, 26, 0], head=[-6, -14], footL=[-0.02, 0.44, 0, 0, 0],
               footR=[0, 0, 0.06, 0, 30], weapon=W([0.14, 0.64, 1.00], [-0.02, 0.86, -0.50]), rpole=[0.9, -0.3, -0.4])
    over = dict(hit, hips=[0, 0.28, -0.25, 8, 18, 0], chest=[10, 30, 0],
                weapon=W([0.14, 0.66, 0.86], [-0.02, 0.80, -0.60]))
    out = dict(hips=[0, 0.14, -0.10, 2, 6, 0], chest=[2, 8, 0], head=[0, -2], footL=[-0.02, 0.30, 0, 0, 0],
               footR=Z5, weapon=W([0.26, 0.44, 1.20], [0.04, 0.70, 0.70]), rpole=[0.9, -0.3, -0.5])
    return rig.clip([(0.0, "inout", _br_base()), (0.22, "out", up), (t - 0.11, "inout", hang), (t - 0.05, "in", top),
                     (t, "in", hit), (t + 0.07, "out", over), (t + 0.32, "inout", over), (t + 0.55, "inout", out),
                     (end, "inout", _br_base())], c.fps), t, end


def br_thrust(c, m):
    """Sprint: the run's lean kept, the brand couched low at the hip and
    driven out over a long stride, flame first."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = _br_rig(c)
    couch = dict(hips=[0, 0.05, -0.07, -20, 14, 0], chest=[-12, 8, 0], head=[26, -10],
                 footL=[-0.03, 0.10, 0, 4, 0], footR=[0.04, -0.24, 0.10, -10, 34],
                 weapon=W([0.36, -0.12, 1.16], [0.0, 0.97, 0.24]), rpole=[0.9, -0.7, -0.2])
    hit = dict(hips=[0, 0.42, -0.20, 10, 20, 0], chest=[16, 12, 0], head=[-14, -16],
               footL=[-0.04, -0.22, 0.08, 4, 36], footR=[0.10, 0.62, 0, -6, 0],
               weapon=W([0.10, 0.86, 1.22], [-0.04, 0.99, 0.10]), rpole=[0.8, -0.4, -0.6])
    over = dict(hit, hips=[0, 0.46, -0.21, 12, 21, 0], weapon=W([0.09, 0.92, 1.22], [-0.04, 0.99, 0.08]))
    out = dict(hips=[0, 0.22, -0.10, 0, 8, 0], chest=[4, 6, 0], head=[0, -2], footL=[-0.04, 0.0, 0, 4, 0],
               footR=[0.06, 0.30, 0, -4, 0], weapon=W([0.28, 0.40, 1.34], [0.04, 0.66, 0.74]), rpole=[0.9, -0.3, -0.5])
    return rig.clip([(0.0, "inout", _br_base()), (t * 0.45, "out", couch), (t, "in", hit), (t + 0.07, "out", over),
                     (t + 0.24, "inout", over), (t + 0.5, "inout", out), (end, "inout", _br_base())], c.fps), t, end


# -------------------------------------------------------------- the chopper
def _ch_base(rig):
    return {"hips": Z6, "chest": Z3, "head": [0, 0], "footL": Z5, "footR": Z5, "weapon": rig.wctl()}


def ch_hack_a(c, m):
    """Light 1: a forehand hack. The cleaver goes up beside the ear and
    comes straight down and in, short and close: a butcher's stroke."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = c.rig("chopper")
    z = _ch_base(rig)
    up = dict(hips=[0, -0.04, 0.0, -16, -2, 0], chest=[-14, -6, 0], head=[14, 0],
              weapon=W([0.40, 0.00, 1.64], [0.20, -0.46, 0.86]), rpole=[1.0, -0.3, 0.0])
    hit = dict(hips=[0, 0.18, -0.12, 14, 10, 0], chest=[20, 16, 0], head=[-14, -6], footL=[-0.02, 0.30, 0, 0, 0],
               footR=[0, 0, 0.04, 0, 22], weapon=W([0.14, 0.56, 1.20], [-0.22, 0.88, 0.10]), rpole=[0.9, -0.3, -0.4])
    over = dict(hit, hips=[0, 0.20, -0.15, 18, 12, 0], chest=[26, 20, 0],
                weapon=W([0.02, 0.52, 0.98], [-0.40, 0.78, -0.40]))
    return rig.clip([(0.0, "inout", z), (t * 0.52, "out", up), (t, "in", hit), (t + 0.07, "out", over),
                     (t + 0.2, "inout", over), (end, "inout", z)], c.fps), t, end


def ch_hack_b(c, m):
    """Light 2: the backhand hack, from over the shield shoulder down and
    out to the right; starts where the forehand ends."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = c.rig("chopper")
    z = _ch_base(rig)
    up = dict(hips=[0, 0.02, -0.02, 14, 0, 0], chest=[26, -4, 0], head=[-20, 0],
              weapon=W([-0.10, 0.22, 1.60], [-0.56, -0.20, 0.80]), rpole=[0.6, -0.2, -0.9])
    hit = dict(hips=[0, 0.16, -0.10, -8, 8, 0], chest=[-14, 12, 0], head=[10, -4], footL=[-0.02, 0.24, 0, 0, 0],
               weapon=W([0.26, 0.56, 1.22], [0.30, 0.90, 0.14]), rpole=[0.9, -0.4, -0.5])
    over = dict(hit, hips=[0, 0.17, -0.12, -14, 10, 0], chest=[-24, 14, 0],
                weapon=W([0.46, 0.38, 1.02], [0.66, 0.60, -0.36]))
    return rig.clip([(0.0, "inout", z), (t * 0.5, "out", up), (t, "in", hit), (t + 0.07, "out", over),
                     (t + 0.2, "inout", over), (end, "inout", z)], c.fps), t, end


def ch_cleave(c, m):
    """Heavy: the joint-splitter. Both feet set, the cleaver hauled up and
    back until the spine bows under it, held, then the whole back drives it
    down through the mark and into the board beneath."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = c.rig("chopper")
    z = _ch_base(rig)
    up = dict(hips=[0, -0.06, 0.03, -10, -8, 0], chest=[-10, -14, 0], head=[6, -8],
              weapon=W([0.30, -0.08, 1.86], [0.10, -0.60, 0.80]), rpole=[1.0, -0.2, 0.2])
    hang = dict(up, hips=[0, -0.08, 0.04, -12, -10, 0], chest=[-12, -18, 0],
                weapon=W([0.30, -0.12, 1.90], [0.10, -0.72, 0.70]))
    top = dict(hips=[0, 0.06, 0.0, 0, 2, 0], chest=[0, 2, 0], head=[0, 0],
               weapon=W([0.24, 0.30, 1.80], [0.02, 0.50, 0.86]), rpole=[1.0, -0.2, 0.0])
    hit = dict(hips=[0, 0.24, -0.26, 6, 18, 0], chest=[8, 30, 0], head=[-4, -16], footL=[-0.02, 0.40, 0, 0, 0],
               footR=[0, 0, 0.06, 0, 30], weapon=W([0.14, 0.60, 0.96], [-0.04, 0.88, -0.46]), rpole=[0.9, -0.3, -0.4])
    over = dict(hit, hips=[0, 0.26, -0.30, 6, 20, 0], chest=[8, 34, 0],
                weapon=W([0.14, 0.60, 0.80], [-0.04, 0.80, -0.60]))
    return rig.clip([(0.0, "inout", z), (0.2, "out", up), (t - 0.11, "inout", hang), (t - 0.05, "in", top),
                     (t, "in", hit), (t + 0.07, "out", over), (t + 0.34, "inout", over), (end, "inout", z)],
                    c.fps), t, end


def ch_leap(c, m):
    """Sprint: a running hack, the cleaver thrown down from above the head
    as the lead foot lands."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = c.rig("chopper")
    z = _ch_base(rig)
    up = dict(hips=[0, 0.06, 0.04, -14, 8, 0], chest=[-12, 0, 0], head=[14, -8],
              footL=[-0.03, 0.10, 0, 4, 0], footR=[0.04, -0.22, 0.12, -8, 34],
              weapon=W([0.36, 0.04, 1.84], [0.14, -0.40, 0.90]), rpole=[1.0, -0.3, 0.1])
    hit = dict(hips=[0, 0.42, -0.22, 10, 22, 0], chest=[16, 22, 0], head=[-12, -18],
               footL=[-0.04, -0.20, 0.08, 4, 36], footR=[0.10, 0.60, 0, -6, 0],
               weapon=W([0.12, 0.90, 1.08], [-0.10, 0.92, -0.20]), rpole=[0.9, -0.3, -0.5])
    over = dict(hit, hips=[0, 0.45, -0.25, 12, 24, 0], weapon=W([0.06, 0.90, 0.90], [-0.2, 0.80, -0.56]))
    return rig.clip([(0.0, "inout", z), (t * 0.5, "out", up), (t, "in", hit), (t + 0.07, "out", over),
                     (t + 0.26, "inout", over), (end, "inout", z)], c.fps), t, end


# ---------------------------------------------------------------- long hafts
# The right hand is the weapon mount, low on the haft; the left closes
# `left` metres up it toward the head and does the steering.
def _haft(g, d, left, **kw):
    c = {"weapon": W(g, d, lean=0.3), "left": left, "rpole": [0.7, -0.7, -0.2], "lpole": [-0.7, -0.2, -0.7]}
    c.update(kw)
    return c


# the maul: head hung low out in front, back bent to it
MA_READY = _haft([0.30, -0.06, 0.98], [-0.22, 0.74, -0.63], 0.5,
                 hips=[0, 0, -0.05, -22, 5, 0], chest=[-8, 8, 0], head=[28, -4],
                 footL=[-0.03, 0.14, 0, 6, 0], footR=[0.05, -0.14, 0, -30, 0])


def _ma(**kw):
    c = dict(MA_READY)
    c.update(kw)
    return c


def _re(c, g, d, left, **kw):
    kw["weapon"] = W(g, d, lean=0.3)
    kw["left"] = left
    out = dict(c)
    out.update(kw)
    return out


def ma_swing(c, m):
    """Light: the head is dragged back and round on the right, the body
    wound behind it, and thrown across at the ribs. It does not stop when
    it has hit: it carries him round, and has to be let down and hauled in."""
    t, end = strike_time(m), total_time(m) + 0.07
    rig = c.rig("maul")
    back = _re(MA_READY, [0.44, -0.22, 1.00], [0.74, -0.56, -0.37], 0.46,
               hips=[0.03, -0.08, -0.08, -40, 4, 0], chest=[-30, 6, 0], head=[62, -2])
    load = _re(back, [0.45, -0.25, 1.02], [0.70, -0.66, -0.26], 0.46, hips=[0.03, -0.10, -0.09, -44, 4, 0])
    mid = _re(MA_READY, [0.36, 0.08, 1.02], [0.50, 0.80, -0.16], 0.44,
              hips=[0, 0.06, -0.10, -12, 8, 0], chest=[-4, 8, 0], head=[16, -2])
    hit = _re(MA_READY, [0.12, 0.30, 1.04], [-0.34, 0.93, 0.06], 0.42,
              hips=[0, 0.18, -0.12, 12, 10, 0], chest=[28, 10, 0], head=[-34, -4],
              footL=[-0.05, 0.34, 0, 14, 0], footR=[0.05, -0.14, 0.05, -30, 26])
    over = _re(hit, [-0.02, 0.26, 1.02], [-0.82, 0.56, 0.08], 0.42,
               hips=[0, 0.19, -0.13, 24, 10, 0], chest=[42, 10, 0])
    drop = _re(hit, [0.04, 0.22, 0.90], [-0.74, 0.50, -0.45], 0.46,
               hips=[0, 0.16, -0.16, 18, 14, 0], chest=[30, 16, 0], head=[-20, 6])
    return rig.clip([(0.0, "inout", MA_READY), (0.22, "out", back), (t - 0.14, "inout", load), (t - 0.06, "in", mid),
                     (t, "inout", hit), (t + 0.10, "out", over), (t + 0.34, "inout", drop),
                     (end, "inout", MA_READY)], c.fps), t, end


def ma_smash(c, m):
    """Heavy: heaved up hand over hand until it stands over his head, the
    back arched under it; it hangs there, then everything comes down with
    it. It stays in the ground while he gets his breath."""
    t, end = strike_time(m), total_time(m) + 0.07
    rig = c.rig("maul")
    heave = _re(MA_READY, [0.26, 0.04, 1.26], [0.10, 0.50, 0.86], 0.52,
                hips=[0, -0.02, -0.02, -16, 0, 0], chest=[-6, -2, 0], head=[20, -10])
    up = _re(MA_READY, [0.22, 0.02, 1.56], [0.08, -0.34, 0.94], 0.50,
             hips=[0, -0.06, 0.03, -12, -8, 0], chest=[-4, -14, 0], head=[14, -12],
             rpole=[1.0, -0.2, 0.0], lpole=[-1.0, -0.2, 0.0])
    hang = _re(up, [0.22, -0.02, 1.60], [0.08, -0.56, 0.82], 0.50, hips=[0, -0.08, 0.04, -12, -11, 0],
               chest=[-4, -18, 0])
    top = _re(up, [0.20, 0.22, 1.56], [0.02, 0.50, 0.86], 0.48, hips=[0, 0.06, 0.0, -4, 2, 0], chest=[0, 2, 0])
    hit = _re(MA_READY, [0.14, 0.40, 0.84], [-0.04, 0.93, -0.36], 0.44,
              hips=[0, 0.22, -0.30, 4, 22, 0], chest=[6, 30, 0], head=[-6, -18],
              footL=[-0.05, 0.42, 0, 6, 0], footR=[0.05, -0.14, 0.06, -30, 30])
    over = _re(hit, [0.14, 0.40, 0.70], [-0.04, 0.88, -0.48], 0.44, hips=[0, 0.24, -0.36, 4, 26, 0],
               chest=[6, 36, 0])
    rest = _re(over, [0.14, 0.38, 0.74], [-0.04, 0.88, -0.47], 0.46, hips=[0, 0.22, -0.32, 4, 22, 0],
               chest=[6, 30, 0], head=[-6, -6])
    return rig.clip([(0.0, "inout", MA_READY), (0.20, "inout", heave), (0.40, "out", up), (t - 0.12, "inout", hang),
                     (t - 0.06, "in", top), (t, "in", hit), (t + 0.06, "out", over), (t + 0.45, "inout", rest),
                     (end, "inout", MA_READY)], c.fps), t, end


def ma_drag(c, m):
    """Sprint: the head trails on the ground behind the run and is ripped
    up and through in a rising blow."""
    t, end = strike_time(m), total_time(m) + 0.07
    rig = c.rig("maul")
    trail = _re(MA_READY, [0.42, -0.24, 0.96], [0.46, -0.70, -0.55], 0.44,
                hips=[0, 0.06, -0.10, -34, 16, 0], chest=[-22, 10, 0], head=[50, -12],
                footL=[-0.03, 0.12, 0, 4, 0], footR=[0.05, -0.26, 0.10, -20, 34])
    low = _re(trail, [0.36, 0.06, 0.92], [0.20, 0.80, -0.56], 0.42,
              hips=[0, 0.22, -0.16, -10, 18, 0], chest=[-2, 12, 0], head=[14, -14])
    hit = _re(MA_READY, [0.14, 0.44, 1.12], [-0.12, 0.90, 0.42], 0.40,
              hips=[0, 0.42, -0.16, 12, 14, 0], chest=[22, 4, 0], head=[-20, -12],
              footL=[-0.04, -0.20, 0.08, 4, 36], footR=[0.10, 0.60, 0, -6, 0])
    over = _re(hit, [0.06, 0.40, 1.36], [-0.20, 0.50, 0.84], 0.40,
               hips=[0, 0.44, -0.12, 18, 6, 0], chest=[30, -6, 0], head=[-24, -4])
    return rig.clip([(0.0, "inout", MA_READY), (0.22, "out", trail), (t - 0.09, "in", low), (t, "inout", hit),
                     (t + 0.10, "out", over), (t + 0.30, "inout", over), (end, "inout", MA_READY)], c.fps), t, end


def _haft_guard(ready, g, d, left):
    return _re(ready, g, d, left, hips=[0, 0, -0.06, -24, 4, 0], chest=[-8, 5, 0], head=[30, 0])


def _haft_kit(prefix, grip, ready, guard, carry_ctl):
    """The plain verbs on a long haft: carry, guard, a blow soaked on the
    haft, a beat parry, and the riposte (the butt end driven in)."""

    def carry(c):
        rig = _idle_rig(c, grip)
        a = _arms(carry_ctl)
        w = a["weapon"]
        b = dict(a, weapon=[w[0], w[1] + 0.012, w[2] + 0.012] + w[3:])
        return rig.clip([(0.0, "inout", a), (1.2, "inout", b), (2.4, "inout", a)], c.fps)

    def hold(c):
        rig = c.rig(grip)
        b = dict(guard, chest=[guard["chest"][0], guard["chest"][1] + 1.5, 0])
        return rig.clip([(0.0, "inout", guard), (1.1, "inout", b), (2.2, "inout", guard)], c.fps)

    def hit(c):
        rig = c.rig(grip)
        w = guard["weapon"]
        soak = dict(guard, weapon=[w[0] + 0.02, w[1] - 0.12, w[2] - 0.04] + w[3:],
                    hips=[0, -0.10, -0.12, -27, -3, 0], chest=[-12, -6, 0], head=[30, 8])
        reb = dict(guard, weapon=[w[0], w[1] + 0.03, w[2] + 0.01] + w[3:], hips=[0, 0.02, -0.07, -23, 5, 0])
        return rig.clip([(0.0, "inout", guard), (0.06, "out", soak), (0.2, "inout", reb), (0.42, "inout", guard)],
                        c.fps)

    def parry(c):
        rig = c.rig(grip)
        w = guard["weapon"]
        coil = dict(guard, weapon=[w[0] + 0.10, w[1] - 0.06, w[2] + 0.02] + w[3:], chest=[-24, 4, 0])
        beat = dict(guard, weapon=[w[0] - 0.22, w[1] + 0.22, w[2] + 0.06] + w[3:], chest=[24, 5, 0],
                    hips=[0, 0.08, -0.10, -8, 5, 0])
        over = dict(beat, weapon=[w[0] - 0.27, w[1] + 0.24, w[2] + 0.06] + w[3:], chest=[29, 5, 0])
        return rig.clip([(0.0, "inout", guard), (0.07, "out", coil), (0.17, "in", beat), (0.26, "out", over),
                         (0.44, "inout", beat), (0.72, "inout", guard)], c.fps)

    def stab(c):
        rig = c.rig(grip)
        left = guard["left"]
        coil = _re(ready, [0.36, -0.30, 1.10], [-0.10, 0.98, 0.14], left + 0.08,
                   hips=[0, -0.12, -0.08, -44, 4, 0], chest=[-24, 5, 0], head=[62, 0])
        hit_p = _re(ready, [0.12, 0.44, 1.16], [-0.02, 1.0, 0.04], left - 0.14,
                    hips=[0, 0.32, -0.16, -4, 12, 0], chest=[12, 12, 0], head=[-2, -6],
                    footL=[-0.05, 0.56, 0, 4, 0], footR=[0.05, -0.14, 0.06, -30, 32])
        over = _re(hit_p, [0.11, 0.50, 1.16], [-0.02, 1.0, 0.04], left - 0.16, hips=[0, 0.35, -0.17, -2, 13, 0])
        return rig.clip([(0.0, "inout", ready), (0.20, "out", coil), (0.34, "in", hit_p), (0.42, "out", over),
                         (0.56, "inout", over), (0.92, "inout", ready)], c.fps)

    return {prefix + "_carry": carry, prefix + "_guard": hold, prefix + "_guard_hit": hit,
            prefix + "_parry": parry, prefix + "_stab": stab}


MA_GUARD = _haft_guard(MA_READY, [0.34, 0.12, 0.96], [-0.86, 0.26, 0.44], 0.5)
# walking: the head hangs a hand above the ground in front of the left foot
MA_CARRY = _haft([0.30, 0.02, 0.88], [-0.30, 0.66, -0.69], 0.5)

# the polearm at port arms: butt by the right hip, head up across the left shoulder
PA_READY = _haft([0.30, -0.08, 0.92], [-0.42, 0.42, 0.80], 0.55,
                 hips=[0, 0, -0.03, -24, 3, 0], chest=[-8, 3, 0], head=[30, 0],
                 footL=[-0.03, 0.14, 0, 6, 0], footR=[0.05, -0.14, 0, -30, 0])
PA_GUARD = _haft_guard(PA_READY, [0.32, 0.14, 0.96], [-0.80, 0.26, 0.54], 0.6)
PA_CARRY = _haft([0.34, 0.02, 0.90], [-0.62, 0.25, 0.74], 0.55)
# the spear walks couched at the right hip, point up and ahead
SP_CARRY = _haft([0.30, -0.10, 0.95], [-0.14, 0.86, 0.48], 0.55)


def pa_hook(c, m):
    """Light: a hooking cut. The head is lifted back over the right
    shoulder and pulled down and across with the lead hand; then the haft
    is run back through that hand, ready again."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = c.rig("polearm")
    back = _re(PA_READY, [0.38, -0.16, 1.06], [0.36, -0.30, 0.88], 0.56,
               hips=[0.02, -0.07, -0.05, -38, 2, 0], chest=[-22, 0, 0], head=[54, 0])
    mid = _re(PA_READY, [0.30, 0.06, 1.08], [0.10, 0.60, 0.80], 0.52,
              hips=[0, 0.06, -0.07, -14, 6, 0], chest=[-2, 6, 0], head=[16, 0])
    hit = _re(PA_READY, [0.18, 0.22, 1.00], [-0.28, 0.94, 0.20], 0.48,
              hips=[0, 0.20, -0.11, 8, 10, 0], chest=[24, 12, 0], head=[-28, -4],
              footL=[-0.05, 0.36, 0, 10, 0], footR=[0.05, -0.14, 0.05, -30, 26])
    over = _re(hit, [0.10, 0.20, 0.96], [-0.56, 0.82, -0.08], 0.48, hips=[0, 0.21, -0.13, 16, 12, 0],
               chest=[34, 14, 0])
    pull = _re(hit, [0.22, 0.06, 0.94], [-0.50, 0.70, 0.50], 0.60, hips=[0, 0.12, -0.08, -6, 6, 0],
               chest=[10, 6, 0], head=[-4, 0], footL=[-0.04, 0.28, 0, 8, 0])
    return rig.clip([(0.0, "inout", PA_READY), (t * 0.42, "out", back), (t - 0.07, "in", mid), (t, "inout", hit),
                     (t + 0.08, "out", over), (t + 0.2, "inout", over), (t + 0.4, "inout", pull),
                     (end, "inout", PA_READY)], c.fps), t, end


def pa_fell(c, m):
    """Heavy: the haft slid long through both hands and the head brought
    over in a full falling cut, as he would drop it on a stump."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = c.rig("polearm")
    up = _re(PA_READY, [0.26, -0.04, 1.34], [0.10, -0.26, 0.96], 0.40,
             hips=[0, -0.06, 0.02, -16, -6, 0], chest=[-8, -12, 0], head=[20, -10],
             rpole=[1.0, -0.3, 0.0], lpole=[-1.0, -0.2, 0.0])
    hang = _re(up, [0.26, -0.08, 1.38], [0.10, -0.46, 0.88], 0.40, hips=[0, -0.08, 0.03, -16, -9, 0],
               chest=[-8, -16, 0])
    top = _re(up, [0.22, 0.16, 1.36], [0.02, 0.52, 0.85], 0.40, hips=[0, 0.06, 0.0, -6, 2, 0], chest=[0, 2, 0])
    hit = _re(PA_READY, [0.14, 0.38, 0.94], [-0.04, 0.97, -0.22], 0.40,
              hips=[0, 0.26, -0.24, 4, 18, 0], chest=[8, 26, 0], head=[-8, -14],
              footL=[-0.05, 0.46, 0, 6, 0], footR=[0.05, -0.14, 0.06, -30, 30])
    over = _re(hit, [0.14, 0.38, 0.82], [-0.04, 0.93, -0.36], 0.40, hips=[0, 0.28, -0.28, 4, 22, 0],
               chest=[8, 30, 0])
    return rig.clip([(0.0, "inout", PA_READY), (0.24, "out", up), (t - 0.11, "inout", hang), (t - 0.05, "in", top),
                     (t, "in", hit), (t + 0.07, "out", over), (t + 0.34, "inout", over),
                     (end, "inout", PA_READY)], c.fps), t, end


def pa_charge(c, m):
    """Sprint: couched like a spear and run in, the haft sliding through
    the lead hand as the back arm punches it out."""
    t, end = strike_time(m), total_time(m) + 0.05
    rig = c.rig("polearm")
    couch = _re(PA_READY, [0.34, -0.26, 1.04], [-0.10, 0.99, 0.08], 0.62,
                hips=[0, 0.06, -0.08, -22, 16, 0], chest=[-10, 8, 0], head=[30, -12],
                footL=[-0.03, 0.10, 0, 4, 0], footR=[0.05, -0.26, 0.10, -20, 34])
    hit = _re(PA_READY, [0.14, 0.52, 1.08], [-0.03, 1.0, 0.0], 0.34,
              hips=[0, 0.42, -0.20, 8, 22, 0], chest=[14, 12, 0], head=[-12, -18],
              footL=[-0.04, -0.22, 0.08, 4, 36], footR=[0.10, 0.62, 0, -6, 0])
    over = _re(hit, [0.13, 0.58, 1.08], [-0.03, 1.0, 0.0], 0.32, hips=[0, 0.46, -0.21, 10, 23, 0])
    back = _re(PA_READY, [0.26, 0.10, 1.00], [-0.24, 0.80, 0.50], 0.52,
               hips=[0, 0.22, -0.10, -12, 8, 0], chest=[-2, 6, 0], head=[16, 0],
               footL=[-0.04, 0.0, 0, 6, 0], footR=[0.08, 0.30, 0, -24, 0])
    return rig.clip([(0.0, "inout", PA_READY), (t * 0.5, "out", couch), (t, "in", hit), (t + 0.08, "out", over),
                     (t + 0.26, "inout", over), (t + 0.5, "inout", back), (end, "inout", PA_READY)], c.fps), t, end


# the greatblade rests on the right shoulder between blows
def gb_carry(c):
    rig = _idle_rig(c, "twohand")
    a = {"weapon": W([0.24, 0.14, 1.22], [0.10, -0.52, 0.85], lean=0.3), "left": -0.2,
         "rpole": [0.8, -0.5, -0.4], "lpole": [-0.6, -0.2, -0.8]}
    b = dict(a, weapon=W([0.24, 0.15, 1.23], [0.10, -0.52, 0.85], lean=0.3))
    return rig.clip([(0.0, "inout", a), (1.2, "inout", b), (2.4, "inout", a)], c.fps)


def build(ctx, root):
    """-> ({name: [Pose]}, {name: clip_meta row})."""
    mv = Moves(root)
    clips, rows = {}, {}

    def timed(name, fn, moveset, which):
        poses, t, end = fn(ctx, mv.get(moveset, which))
        clips[name] = poses
        rows[name] = {"start": 0.0, "contact": round(t, 4), "end": round(min(end, (len(poses) - 1) / ctx.fps), 3),
                      "_note": "%s %s, cut to its data strike time (tools/anim/weapon_clips.py)" % (moveset, which)}

    def loop(name, fn):
        clips[name] = fn(ctx)
        rows[name] = {"loop": True}

    def plain(name, fn):
        clips[name] = fn(ctx)
        rows[name] = {"start": 0.0, "end": round((len(clips[name]) - 1) / ctx.fps, 3)}
        for suffix, at in (("_stab", 0.34), ("_guard_hit", 0.06), ("_parry", 0.17)):   # as the class sets' rows
            if name.endswith(suffix):
                rows[name]["contact"] = at

    timed("w_br_jab", br_jab, "longsword", "l1")
    timed("w_br_sweep", br_sweep, "longsword", "l2")
    timed("w_br_smash", br_smash, "longsword", "heavy")
    timed("w_br_thrust", br_thrust, "longsword", "sprint")
    loop("w_br_carry", br_carry)
    timed("w_ch_hack_a", ch_hack_a, "longsword", "l1")
    timed("w_ch_hack_b", ch_hack_b, "longsword", "l2")
    timed("w_ch_cleave", ch_cleave, "longsword", "heavy")
    timed("w_ch_leap", ch_leap, "longsword", "sprint")
    timed("w_ma_swing", ma_swing, "great_hammer", "l1")
    timed("w_ma_smash", ma_smash, "great_hammer", "heavy")
    timed("w_ma_drag", ma_drag, "great_hammer", "sprint")
    timed("w_pa_hook", pa_hook, "halberd", "l1")
    timed("w_pa_fell", pa_fell, "halberd", "heavy")
    timed("w_pa_charge", pa_charge, "halberd", "sprint")
    for prefix, grip, ready, guard, carry in (("w_ma", "maul", MA_READY, MA_GUARD, MA_CARRY),
                                              ("w_pa", "polearm", PA_READY, PA_GUARD, PA_CARRY)):
        for name, fn in _haft_kit(prefix, grip, ready, guard, carry).items():
            if name.endswith(("_carry", "_guard")):
                loop(name, fn)
            else:
                plain(name, fn)
    loop("w_gb_carry", gb_carry)

    def sp_carry(c):
        rig = _idle_rig(c, "spear")
        a = _arms(SP_CARRY)
        w = a["weapon"]
        b = dict(a, weapon=[w[0], w[1] + 0.012, w[2] + 0.012] + w[3:])
        return rig.clip([(0.0, "inout", a), (1.2, "inout", b), (2.4, "inout", a)], c.fps)
    loop("w_sp_carry", sp_carry)
    return clips, rows
