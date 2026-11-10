"""The combat clip table for build_combat_lib.py: name -> make(ctx) -> [Pose].

Sources per clip are listed in assets/PROVENANCE.md. Mocap comes from the
CC0 Quaternius Universal Animation Library (ual1 / ual2); everything else is
keyed here on the control rig (anim_pose.Rig): key poses solved with IK,
eased between ("in" accelerates into a strike, "out" settles, "over"
overshoots). Clip wind-ups are cut to sit near the data windups of the
movesets that use them, so playback rates stay close to 1.
"""
import anim_pose as A
import anim_rig as R
from anim_pose import concat, warp, two_hand, ease_to

P = R.P
DOWN = [0, 0, -1]


class Ctx:
    def __init__(self, skel, fps, mocap, grips):
        self.skel = skel
        self.fps = fps
        self.mocap = mocap
        self.grips = grips
        self._cache = {}

    def _get(self, key, fn):
        if key not in self._cache:
            self._cache[key] = fn()
        return self._cache[key].copy()

    def stance(self):
        """Blade-ready stance: the first frame of the library's sword idle."""
        return self._get("stance", lambda: self.mocap("ual1", "Sword_Idle", 0, 1)[0])

    def guard(self):
        """Shield raised: the frame the guard-break clip starts from."""
        return self._get("guard", lambda: self.mocap("ual2", "Idle_Shield_Break", 0, 1)[0])

    def rig(self, grip="onehand", base=None):
        return A.Rig(self.skel, base or self.stance(), self.grips[grip], fist_from=self.stance())

    def spear_stance(self):
        """Bladed stance, left side leading, the spear couched at the right hip."""
        return self._get("spear", lambda: self.rig("spear").solve(SPEAR_READY))

    def haft_stance(self, grip):
        return self._get("haft_" + grip, lambda: self.rig(grip).solve(HAFT_READY))

    def bow_stance(self):
        return self._get("bow", lambda: self.rig("onehand").solve(BOW_READY))


def from_stance(c, poses, n=3):
    """Lead in from the stance so a clip cut out of a longer take starts clean."""
    return ease_to(poses, c.stance(), n, end=False)


# ------------------------------------------------------------------ one hand
def sw_light_a(c):
    """Rising cut, right to left. Wind-up stretched to the light windup."""
    p = concat(c.mocap("ual2", "Sword_Regular_A"), c.mocap("ual2", "Sword_Regular_A_Rec"))
    return warp(p, [(0, 6, 1.35)])


def sw_light_b(c):
    """The return cut, level, left to right; starts where light_a ends."""
    return concat(c.mocap("ual2", "Sword_Regular_B"), c.mocap("ual2", "Sword_Regular_B_Rec"))


def sw_cleave(c):
    """Overhead diagonal cleave with a step (the raw take)."""
    return c.mocap("ual1", "Sword_Attack")


def sw_heavy(c):
    """The cleave as a committed heavy: the blade hangs overhead before it
    falls, and the low follow-through is held."""
    return warp(c.mocap("ual1", "Sword_Attack"), [(3, 11, 1.4), (15, 23, 1.3)])


def _slam(c):
    # the last blow of the heavy combo take: the blade swings low behind, the
    # body arches up under it, then a leaping overhead smash into the ground
    return from_stance(c, c.mocap("ual2", "Sword_Heavy_Combo", 62, 130), 4)


def sw_slam(c):
    return warp(_slam(c), [(22, 38, 0.5)])


def sw_dash(c):
    """Running cut: a level sweep out of a lunge."""
    return warp(c.mocap("ual2", "Sword_Dash"), [(3, 8, 1.3)])


def sw_stab(c, grip="onehand", base=None):
    """Riposte: the point is chambered beside the ribs with the body wound
    right, then the whole side drives it home over a long step while the
    guard arm swings clear; a twist, a hold, and the withdrawal."""
    rig = c.rig(grip, base)
    w0 = rig.wctl()
    z3 = [0, 0, 0]
    k = [
        (0.00, "inout", {"weapon": w0, "bones": {"LeftArm": z3}}),
        (0.18, "out", {"hips": [0.02, -0.12, -0.02, -32, 0, 0], "chest": [-30, 2, 0], "head": [40, 0],
                       "weapon": [0.36, -0.28, 1.12, 0.0, 1, 0.02] + DOWN, "rpole": [1.0, -0.6, 0.1],
                       "bones": {"LeftArm": [10, 0, 0]}}),
        (0.26, "inout", {"hips": [0.02, -0.14, -0.03, -35, 0, 0], "weapon": [0.37, -0.32, 1.12, 0.0, 1, 0.02] + DOWN}),
        (0.34, "in", {"hips": [0, 0.36, -0.14, 26, 8, 0], "chest": [34, 6, 0], "head": [-38, -4],
                      "footL": [-0.02, 0.40, 0, 0, 0], "footR": [0, 0, 0.06, 0, 30],
                      "weapon": [0.0, 0.98, 1.24, -0.06, 1, 0.16] + DOWN, "rpole": [0.6, -0.3, -0.8],
                      "bones": {"LeftArm": [46, 0, 0]}}),
        (0.42, "out", {"hips": [0, 0.39, -0.15, 29, 9, 0], "weapon": [0.0, 1.02, 1.25, -0.06, 1, 0.16, 0.8, 0, -0.6]}),
        (0.56, "inout", {"weapon": [0.0, 1.02, 1.24, -0.06, 1, 0.14, 1, 0, 0]}),
        (0.72, "inout", {"hips": [0, 0.16, -0.06, 6, 4, 0], "chest": [6, 3, 0], "head": [-6, 0],
                         "weapon": [0.22, 0.34, 1.10, 0.0, 1, 0.1] + DOWN, "bones": {"LeftArm": [14, 0, 0]}}),
        (0.93, "inout", {"hips": [0] * 6, "chest": z3, "head": [0, 0], "footL": [0] * 5, "footR": [0] * 5,
                         "weapon": w0, "bones": {"LeftArm": z3}}),
    ]
    if grip != "onehand":
        for _, _, ctl in k:
            ctl["left"] = rig.grip.left_at
            ctl.pop("bones", None)
    return rig.clip(k, c.fps)


def guard_hold(c):
    rig = c.rig(base=c.guard())
    return rig.clip([(0.0, "inout", {"hips": [0] * 6, "chest": [0, 0, 0]}),
                     (1.1, "inout", {"hips": [0, 0, -0.012, 0, 0.6, 0], "chest": [0, 1.6, 0]}),
                     (2.2, "inout", {"hips": [0] * 6, "chest": [0, 0, 0]})], c.fps)


def _hit_on(rig, fps, arm="LeftArm"):
    """A blow soaked on the guard: the guard arm is driven in, the body rocks
    back over bent knees, rebounds past the pose and settles."""
    return rig.clip([
        (0.00, "inout", {"hips": [0] * 6, "chest": [0, 0, 0], "head": [0, 0], "bones": {arm: [0, 0, 0]}}),
        (0.06, "out", {"hips": [0, -0.09, -0.07, -4, -5, 0], "chest": [-6, -9, 0], "head": [0, 9],
                       "bones": {arm: [-14, -10, 0]}}),
        (0.20, "inout", {"hips": [0, 0.02, -0.02, 1, 2, 0], "chest": [2, 3, 0], "head": [0, -2],
                         "bones": {arm: [4, 3, 0]}}),
        (0.42, "inout", {"hips": [0] * 6, "chest": [0, 0, 0], "head": [0, 0], "bones": {arm: [0, 0, 0]}}),
    ], fps)


def guard_hit(c):
    return _hit_on(c.rig(base=c.guard()), c.fps)


def guard_parry(c):
    """Shield parry: a short coil to the right, then the board is swept out
    across the blow with a step and the hips behind it (the sweep peaks
    inside the 0.08-0.24 s parry window), held, and recovered."""
    rig = c.rig(base=c.guard())
    z3 = [0, 0, 0]
    z = {"hips": [0] * 6, "chest": z3, "head": [0, 0], "footL": [0] * 5,
         "bones": {"LeftArm": z3, "LeftForeArm": z3, "RightArm": z3}}
    return rig.clip([
        (0.00, "inout", z),
        (0.07, "out", {"hips": [0.03, -0.04, -0.08, -12, 2, 0], "chest": [-22, 4, 0], "head": [18, 0],
                       "bones": {"LeftArm": [-14, 0, 0]}}),
        (0.17, "in", {"hips": [-0.08, 0.10, -0.12, 16, 4, 0], "chest": [34, 3, -5], "head": [-28, 0],
                      "footL": [-0.10, 0.14, 0, 10, 0],
                      "bones": {"LeftArm": [64, -18, 0], "LeftForeArm": [26, 0, 0], "RightArm": [-18, -10, 0]}}),
        (0.26, "out", {"hips": [-0.09, 0.11, -0.12, 18, 4, 0], "chest": [38, 3, -5],
                       "bones": {"LeftArm": [72, -20, 0], "LeftForeArm": [30, 0, 0]}}),
        (0.44, "inout", {"hips": [-0.05, 0.06, -0.07, 10, 2, 0], "chest": [22, 2, -2], "head": [-14, 0],
                         "bones": {"LeftArm": [44, -10, 0], "LeftForeArm": [14, 0, 0], "RightArm": [-8, -4, 0]}}),
        (0.72, "inout", z),
    ], c.fps)


def react_front(c, base=None, grip="onehand"):
    """Stagger from a blow to the front: chest and head whip back, both arms
    are thrown open, a long step back catches the weight, then a hunched,
    winded recovery."""
    rig = c.rig(grip, base)
    z3 = [0, 0, 0]
    z = {"hips": [0] * 6, "chest": z3, "head": [0, 0], "footR": [0] * 5,
         "bones": {"RightArm": z3, "LeftArm": z3, "RightForeArm": z3}}
    return rig.clip([
        (0.00, "inout", z),
        (0.07, "out", {"hips": [0, -0.16, 0.05, -14, -16, 4], "chest": [-18, -30, 6], "head": [0, -24],
                       "footR": [0.04, -0.16, 0.06, 0, 12],
                       "bones": {"RightArm": [-40, -30, 0], "LeftArm": [50, -25, 0], "RightForeArm": [0, -20, 0]}}),
        (0.20, "out", {"hips": [0, -0.26, -0.06, -16, -8, 4], "chest": [-14, -12, 4], "head": [0, 16],
                       "footR": [0.05, -0.36, 0, 0, 0],
                       "bones": {"RightArm": [-48, -12, 0], "LeftArm": [58, -10, 0], "RightForeArm": [0, -8, 0]}}),
        (0.42, "inout", {"hips": [0, -0.20, -0.12, -6, 10, 1], "chest": [-4, 16, 0], "head": [0, 10],
                         "bones": {"RightArm": [-14, 6, 0], "LeftArm": [16, 6, 0], "RightForeArm": z3}}),
        (0.70, "inout", {"hips": [0, -0.06, -0.02, 0, 1, 0], "chest": [0, 1, 0], "head": [0, 0],
                         "footR": [0.01, -0.08, 0, 0, 0],
                         "bones": {"RightArm": z3, "LeftArm": z3}}),
    ], c.fps)


def react_back(c, base=None, grip="onehand"):
    """Stagger from a blow to the back: the hips are driven forward and the
    chest pitches over them, head snapping back then down; a lurching step,
    arms thrown wide, then gathered."""
    rig = c.rig(grip, base)
    z3 = [0, 0, 0]
    z = {"hips": [0] * 6, "chest": z3, "head": [0, 0], "footL": [0] * 5,
         "bones": {"RightArm": z3, "LeftArm": z3}}
    return rig.clip([
        (0.00, "inout", z),
        (0.07, "out", {"hips": [0, 0.18, 0.04, 8, -6, 0], "chest": [10, -14, 0], "head": [0, -26],
                       "footL": [0, 0.16, 0.07, 0, -8],
                       "bones": {"RightArm": [-34, -24, 0], "LeftArm": [40, -24, 0]}}),
        (0.20, "out", {"hips": [0, 0.30, -0.12, 10, 24, 0], "chest": [10, 30, 0], "head": [0, 18],
                       "footL": [0, 0.44, 0, 0, 0],
                       "bones": {"RightArm": [-44, 14, 0], "LeftArm": [50, 14, 0]}}),
        (0.42, "inout", {"hips": [0, 0.22, -0.12, 4, 14, 0], "chest": [2, 12, 0], "head": [0, 6],
                         "bones": {"RightArm": [-12, 4, 0], "LeftArm": [14, 4, 0]}}),
        (0.70, "inout", {"hips": [0, 0.06, -0.02, 0, 1, 0], "chest": [0, 1, 0], "head": [0, 0],
                         "footL": [0, 0.10, 0, 0, 0],
                         "bones": {"RightArm": z3, "LeftArm": z3}}),
    ], c.fps)


def hop_back(c):
    """Backstep: a sharp dip, a flat hop with the knees tucked and the arms
    out for balance, a braced landing on the back foot."""
    rig = c.rig()
    z3 = [0, 0, 0]
    z = {"hips": [0] * 6, "chest": z3, "head": [0, 0], "footL": [0] * 5, "footR": [0] * 5,
         "bones": {"RightArm": z3, "LeftArm": z3}}
    return rig.clip([
        (0.00, "inout", z),
        (0.05, "out", {"hips": [0, 0.04, -0.14, 0, 12, 0], "chest": [0, 8, 0]}),
        (0.14, "out", {"hips": [0, -0.06, 0.10, 0, -10, 0], "chest": [0, -8, 0], "head": [0, 8],
                       "footL": [0, 0.26, 0.20, 0, 30], "footR": [0, -0.22, 0.16, 0, -16],
                       "bones": {"RightArm": [-22, 0, 0], "LeftArm": [22, 0, 0]}}),
        (0.24, "in", {"hips": [0, -0.03, -0.16, 0, 12, 0], "chest": [0, 10, 0], "head": [0, -6],
                      "footL": [0, 0.10, 0.0, 0, 0], "footR": [0, -0.28, 0.0, 0, 0],
                      "bones": {"RightArm": [-8, 0, 0], "LeftArm": [8, 0, 0]}}),
        (0.34, "out", {"hips": [0, -0.02, -0.10, 0, 7, 0], "chest": [0, 6, 0]}),
        (0.50, "inout", {"hips": [0, -0.05, -0.01, 0, 0, 0], "chest": z3, "head": [0, 0],
                         "footL": [0] * 5, "footR": [0, -0.10, 0, 0, 0], "bones": {"RightArm": z3, "LeftArm": z3}}),
    ], c.fps)


def fall_back(c):
    return c.mocap("ual1", "Death01")


def dive_roll(c):
    return c.mocap("ual1", "Roll")


def guard_break(c):
    return c.mocap("ual2", "Idle_Shield_Break")


def knockdown(c):
    return c.mocap("ual2", "Hit_Knockback")


# --------------------------------------------- two hands (greatblade, maul)
HAFT_READY = {"hips": [0, 0, -0.02, -14, 2, 0], "chest": [-8, 3, 0], "head": [20, 0],
              "weapon": [0.20, 0.24, 1.02, -0.22, 0.42, 0.88, 0.2, 1, 0], "left": -0.2,
              "rpole": [0.7, -0.4, -0.6], "lpole": [-0.6, -0.1, -0.8]}


def _two(c, poses, grip):
    return two_hand(poses, c.grips[grip], fist_from=c.stance())


def gs_light_a(c, grip="twohand"):
    """Diagonal cleave from the shoulder, both hands; wind-up held longer."""
    return _two(c, warp(c.mocap("ual1", "Sword_Attack"), [(2, 11, 1.5)]), grip)


def gs_light_b(c, grip="twohand"):
    """The level return cut, both hands: the blade is carried round behind
    (stretched: a great weapon takes its time) and swept across."""
    p = concat(c.mocap("ual2", "Sword_Regular_B"), c.mocap("ual2", "Sword_Regular_B_Rec"))
    return _two(c, warp(p, [(0, 6, 2.2)]), grip)


def gs_heavy(c, grip="twohand"):
    """Leaping overhead smash, both hands: the blade swings low behind, the
    back arches under it, and it comes down into the ground."""
    return _two(c, warp(_slam(c), [(4, 14, 1.6), (22, 38, 0.6)]), grip)


def gs_dash(c, grip="twohand"):
    return _two(c, warp(c.mocap("ual2", "Sword_Dash"), [(2, 8, 1.9)]), grip)


GS_GUARD = dict(HAFT_READY, weapon=[0.16, 0.34, 1.10, -0.50, 0.12, 0.86, 0.2, 1, 0], hips=[0, 0, -0.05, -10, 3, 0])


def _beat(rig, g, fps, left):
    """Weapon parry: the haft is cocked to the right and beaten across the
    line of the blow (peaking inside the parry window), then brought back."""
    coil = dict(g, weapon=[0.40, 0.22, 1.12, 0.42, 0.20, 0.88, 0.2, 1, 0], chest=[-20, 3, 0], left=left)
    hit = dict(g, weapon=[-0.06, 0.46, 1.16, -0.78, 0.26, 0.58, 0.2, 1, 0], chest=[26, 4, 0], left=left,
               hips=[g["hips"][0], 0.08, g["hips"][2] - 0.05, g["hips"][3] + 16, 4, 0])
    over = dict(hit, weapon=[-0.10, 0.48, 1.15, -0.82, 0.26, 0.52, 0.2, 1, 0], chest=[30, 4, 0])
    return rig.clip([(0.0, "inout", g), (0.07, "out", coil), (0.17, "in", hit), (0.26, "out", over),
                     (0.44, "inout", hit), (0.72, "inout", g)], fps)


def gs_parry(c, grip="twohand"):
    return _beat(c.rig(grip), GS_GUARD, c.fps, c.grips[grip].left_at)


def gs_guard(c, grip="twohand"):
    rig = c.rig(grip)
    g = GS_GUARD
    b = dict(g, hips=[0, 0, -0.062, -10, 3.6, 0], chest=[-8, 4.4, 0])
    return rig.clip([(0.0, "inout", g), (1.1, "inout", b), (2.2, "inout", g)], c.fps)


def gs_guard_hit(c, grip="twohand"):
    rig = c.rig(grip)
    g = GS_GUARD
    hit = dict(g, weapon=[0.18, 0.20, 1.06, -0.56, 0.0, 0.83, 0.2, 1, 0], hips=[0, -0.09, -0.11, -13, -3, 0],
               chest=[-12, -6, 0], head=[20, 8])
    reb = dict(g, weapon=[0.16, 0.37, 1.11, -0.50, 0.14, 0.86, 0.2, 1, 0], hips=[0, 0.02, -0.06, -9, 4, 0])
    return rig.clip([(0.0, "inout", g), (0.06, "out", hit), (0.2, "inout", reb), (0.42, "inout", g)], c.fps)


# ---------------------------------------------------------------------- spear
SPEAR_READY = {"hips": [0, 0, -0.04, -32, 3, 0], "chest": [-12, 3, 0], "head": [40, 0],
               "footL": [-0.04, 0.16, 0, 8, 0], "footR": [0.06, -0.16, 0, -38, 0],
               "weapon": [0.27, -0.10, 0.98, -0.16, 1, 0.13, 0.5, 0, -1], "left": 0.55,
               "rpole": [0.8, -0.6, -0.2], "lpole": [-0.5, 0.0, -0.9]}


def _sp(**kw):
    c = dict(SPEAR_READY)
    c.update(kw)
    return c


def sp_thrust_a(c):
    """Low-line thrust: draw back, lunge off the back foot, the lead hand lets
    the shaft run; overshoot, withdraw."""
    rig = c.rig("spear")
    return rig.clip([
        (0.00, "inout", _sp()),
        (0.14, "out", _sp(hips=[0, -0.09, -0.07, -44, 3, 0], chest=[-22, 4, 0], head=[58, 0],
                          weapon=[0.33, -0.34, 1.00, -0.12, 1, 0.08, 0.5, 0, -1], left=0.62)),
        (0.29, "in", _sp(hips=[0, 0.26, -0.12, -8, 10, 0], chest=[8, 10, 0], head=[4, -4],
                         footL=[-0.04, 0.52, 0, 4, 0], footR=[0.06, -0.16, 0.05, -38, 26],
                         weapon=[0.13, 0.46, 1.12, -0.02, 1, 0.02, 0.5, 0, -1], left=0.34)),
        (0.36, "out", _sp(hips=[0, 0.29, -0.13, -5, 11, 0], chest=[10, 11, 0], head=[2, -4],
                          footL=[-0.04, 0.52, 0, 4, 0], footR=[0.06, -0.16, 0.05, -38, 28],
                          weapon=[0.12, 0.51, 1.12, -0.02, 1, 0.02, 0.5, 0, -1], left=0.32)),
        (0.54, "inout", _sp(hips=[0, 0.12, -0.07, -22, 5, 0], chest=[-6, 5, 0], head=[26, 0],
                            footL=[-0.04, 0.40, 0, 6, 0],
                            weapon=[0.24, 0.02, 1.02, -0.12, 1, 0.10, 0.5, 0, -1], left=0.5)),
        (0.80, "inout", _sp()),
    ], c.fps)


def sp_thrust_b(c):
    """High-line thrust: the shaft lifted to the shoulder, driven down at the
    throat. Reads differently from thrust_a so the two alternate."""
    rig = c.rig("spear")
    return rig.clip([
        (0.00, "inout", _sp()),
        (0.12, "out", _sp(hips=[0, -0.06, -0.03, -46, 0, 0], chest=[-24, -4, 0], head=[60, 4],
                          weapon=[0.30, -0.30, 1.46, -0.10, 1, -0.12, 0.6, 0, -1], left=0.60,
                          rpole=[0.9, -0.5, 0.2])),
        (0.25, "in", _sp(hips=[0, 0.22, -0.10, -12, 12, 0], chest=[6, 14, 0], head=[8, -2],
                         footL=[-0.04, 0.46, 0, 4, 0], footR=[0.06, -0.16, 0.05, -38, 24],
                         weapon=[0.14, 0.44, 1.42, -0.02, 1, -0.24, 0.6, 0, -1], left=0.34,
                         rpole=[0.9, -0.4, 0.1])),
        (0.32, "out", _sp(hips=[0, 0.25, -0.11, -9, 13, 0], chest=[8, 15, 0], head=[6, -2],
                          footL=[-0.04, 0.46, 0, 4, 0], footR=[0.06, -0.16, 0.05, -38, 26],
                          weapon=[0.13, 0.49, 1.40, -0.02, 1, -0.26, 0.6, 0, -1], left=0.32,
                          rpole=[0.9, -0.4, 0.1])),
        (0.52, "inout", _sp(hips=[0, 0.10, -0.06, -24, 5, 0], chest=[-8, 4, 0], head=[28, 0],
                            footL=[-0.04, 0.34, 0, 6, 0],
                            weapon=[0.26, 0.00, 1.16, -0.12, 1, 0.02, 0.5, 0, -1], left=0.5)),
        (0.80, "inout", _sp()),
    ], c.fps)


def sp_heavy(c):
    """Committed lunge: a deep coil over the back leg, held, then the whole
    body goes down the shaft; long hold at full extension, slow recovery."""
    rig = c.rig("spear")
    coil = _sp(hips=[0.02, -0.17, -0.13, -56, 4, 0], chest=[-30, 6, 0], head=[78, 2],
               footR=[0.06, -0.20, 0, -42, 0],
               weapon=[0.36, -0.50, 1.10, -0.10, 1, 0.04, 0.5, 0, -1], left=0.66)
    coil2 = dict(coil, hips=[0.02, -0.19, -0.15, -58, 4, 0], weapon=[0.36, -0.53, 1.10, -0.10, 1, 0.04, 0.5, 0, -1])
    hit = _sp(hips=[0, 0.44, -0.24, 2, 12, 0], chest=[16, 8, 0], head=[-10, -4],
              footL=[-0.04, 0.80, 0, 2, 0], footR=[0.06, -0.20, 0.07, -38, 40],
              weapon=[0.10, 0.72, 0.94, 0.0, 1, 0.04, 0.5, 0, -1], left=0.28)
    over = dict(hit, hips=[0, 0.48, -0.25, 4, 13, 0], weapon=[0.09, 0.78, 0.94, 0.0, 1, 0.04, 0.5, 0, -1], left=0.26)
    back = _sp(hips=[0, 0.20, -0.12, -24, 7, 0], chest=[-6, 6, 0], head=[28, 0], footL=[-0.04, 0.60, 0, 4, 0],
               weapon=[0.24, 0.08, 1.04, -0.12, 1, 0.08, 0.5, 0, -1], left=0.5)
    return rig.clip([(0.00, "inout", _sp()), (0.30, "out", coil), (0.42, "inout", coil2), (0.53, "in", hit),
                     (0.62, "out", over), (0.82, "inout", over), (1.08, "inout", back), (1.40, "inout", _sp())],
                    c.fps)


def sp_dash(c):
    """Running thrust: the run's lean kept, the spear couched then punched out
    over a long stride on the right leg."""
    rig = c.rig("spear")
    run = _sp(hips=[0, 0.06, -0.08, -20, 16, 0], chest=[-10, 8, 0], head=[28, -12],
              footL=[-0.04, 0.10, 0, 4, 0], footR=[0.06, -0.26, 0.10, -20, 34],
              weapon=[0.30, -0.22, 1.04, -0.10, 1, 0.02, 0.5, 0, -1], left=0.60)
    hit = _sp(hips=[0, 0.40, -0.20, 8, 22, 0], chest=[14, 12, 0], head=[-12, -18],
              footL=[-0.04, -0.22, 0.08, 4, 36], footR=[0.10, 0.62, 0, -6, 0],
              weapon=[0.10, 0.74, 1.06, 0.0, 1, -0.02, 0.5, 0, -1], left=0.28)
    over = dict(hit, hips=[0, 0.44, -0.21, 10, 23, 0], weapon=[0.09, 0.80, 1.06, 0.0, 1, -0.02, 0.5, 0, -1])
    back = _sp(hips=[0, 0.22, -0.10, -14, 8, 0], chest=[-4, 6, 0], head=[18, 0],
               footL=[-0.04, 0.0, 0, 6, 0], footR=[0.08, 0.30, 0, -24, 0],
               weapon=[0.24, 0.10, 1.04, -0.12, 1, 0.08, 0.5, 0, -1], left=0.5)
    return rig.clip([(0.00, "inout", _sp()), (0.20, "out", run), (0.36, "in", hit), (0.44, "out", over),
                     (0.62, "inout", over), (0.86, "inout", back), (1.15, "inout", _sp())], c.fps)


def sp_parry(c):
    g = _sp(weapon=[0.30, 0.16, 0.96, -0.72, 0.30, 0.62, 0.5, 0, -1], left=0.62, hips=[0, 0, -0.06, -28, 3, 0])
    return _beat(c.rig("spear"), g, c.fps, 0.62)


def sp_guard(c):
    rig = c.rig("spear")
    g = _sp(weapon=[0.30, 0.16, 0.96, -0.72, 0.30, 0.62, 0.5, 0, -1], left=0.62, hips=[0, 0, -0.06, -28, 3, 0])
    b = dict(g, hips=[0, 0, -0.072, -28, 3.6, 0], chest=[-12, 4.4, 0])
    return rig.clip([(0.0, "inout", g), (1.1, "inout", b), (2.2, "inout", g)], c.fps)


def sp_guard_hit(c):
    rig = c.rig("spear")
    g = _sp(weapon=[0.30, 0.16, 0.96, -0.72, 0.30, 0.62, 0.5, 0, -1], left=0.62, hips=[0, 0, -0.06, -28, 3, 0])
    hit = dict(g, weapon=[0.31, 0.04, 0.93, -0.74, 0.20, 0.64, 0.5, 0, -1], hips=[0, -0.09, -0.12, -31, -3, 0],
               chest=[-16, -6, 0], head=[40, 8])
    reb = dict(g, weapon=[0.30, 0.19, 0.97, -0.72, 0.32, 0.62, 0.5, 0, -1], hips=[0, 0.02, -0.07, -27, 4, 0])
    return rig.clip([(0.0, "inout", g), (0.06, "out", hit), (0.2, "inout", reb), (0.42, "inout", g)], c.fps)


def sp_stab(c):
    """Riposte with the spear: the heavy lunge cut short and sharp."""
    rig = c.rig("spear")
    coil = _sp(hips=[0, -0.12, -0.09, -50, 4, 0], chest=[-26, 5, 0], head=[70, 0],
               weapon=[0.34, -0.42, 1.06, -0.10, 1, 0.06, 0.5, 0, -1], left=0.64)
    hit = _sp(hips=[0, 0.34, -0.18, -2, 13, 0], chest=[12, 12, 0], head=[-4, -6],
              footL=[-0.04, 0.64, 0, 2, 0], footR=[0.06, -0.16, 0.06, -38, 34],
              weapon=[0.10, 0.60, 1.14, 0.0, 1, 0.04, 0.5, 0, -1], left=0.30)
    over = dict(hit, hips=[0, 0.37, -0.19, 0, 14, 0], weapon=[0.09, 0.66, 1.14, 0.0, 1, 0.04, 0.5, 0, -1])
    return rig.clip([(0.00, "inout", _sp()), (0.20, "out", coil), (0.34, "in", hit), (0.42, "out", over),
                     (0.56, "inout", over), (0.92, "inout", _sp())], c.fps)


# ------------------------------------------------------------------------ bow
BOW_READY = {"hips": [0, 0, -0.02, -62, 0, 0], "chest": [-18, 0, 0], "head": [78, 0],
             "footL": [-0.02, 0.14, 0, 0, 0], "footR": [0.04, -0.14, 0, -60, 0],
             "lhand": [-0.10, 0.42, 1.18], "lrot": [-80, 0, 0], "lpole": [-0.7, 0, -0.7],
             "rhand": [0.10, 0.30, 1.12], "rrot": [70, 0, 0], "rpole": [0.6, -0.6, -0.5]}


def _bow(**kw):
    c = dict(BOW_READY)
    c.update(kw)
    return c


BOW_DRAWN = _bow(hips=[0, -0.02, -0.03, -74, -2, 0], chest=[-14, -3, 0], head=[86, 0],
                 lhand=[-0.12, 0.66, 1.46], lrot=[-88, 0, 0],
                 rhand=[0.08, -0.04, 1.50], rrot=[80, 0, 0], rpole=[0.5, -1.0, 0.1])


def bow_pull(c):
    """Raise the bow and draw to the cheek (the hold takes over at 0.72 s)."""
    rig = c.rig("onehand")
    up = _bow(lhand=[-0.12, 0.62, 1.42], lrot=[-88, 0, 0], rhand=[0.02, 0.44, 1.42], rrot=[75, 0, 0],
              hips=[0, 0, -0.02, -70, 0, 0], head=[84, 0])
    return rig.clip([(0.00, "inout", _bow()), (0.26, "out", up), (0.66, "inout", BOW_DRAWN),
                     (0.80, "inout", BOW_DRAWN)], c.fps)


def bow_aim(c):
    rig = c.rig("onehand")
    b = dict(BOW_DRAWN, chest=[-14, -1.8, 0], rhand=[0.08, -0.045, 1.495])
    return rig.clip([(0.0, "inout", BOW_DRAWN), (1.0, "inout", b), (2.0, "inout", BOW_DRAWN)], c.fps)


def _pa(fn):
    return lambda c: fn(c, "polearm")


def clips():
    return {
        # one hand (blade + board shield)
        "sw_light_a": sw_light_a, "sw_light_b": sw_light_b, "sw_heavy": sw_heavy, "sw_cleave": sw_cleave,
        "sw_slam": sw_slam, "sw_dash": sw_dash, "sw_stab": sw_stab,
        "guard_hold": guard_hold, "guard_hit": guard_hit, "guard_parry": guard_parry, "guard_break": guard_break,
        "react_front": react_front, "react_back": react_back, "hop_back": hop_back,
        "fall_back": fall_back, "dive_roll": dive_roll, "knockdown": knockdown,
        # two hands
        "gs_light_a": gs_light_a, "gs_light_b": gs_light_b, "gs_heavy": gs_heavy, "gs_dash": gs_dash,
        "gs_stab": lambda c: sw_stab(c, "twohand", c.haft_stance("twohand")),
        "gs_guard": gs_guard, "gs_guard_hit": gs_guard_hit, "gs_parry": gs_parry,
        # long hafts (spade, bill): the two-handed set with the hands spread
        "pa_light_a": _pa(gs_light_a), "pa_light_b": _pa(gs_light_b), "pa_heavy": _pa(gs_heavy),
        "pa_dash": _pa(gs_dash), "pa_stab": lambda c: sw_stab(c, "polearm", c.haft_stance("polearm")),
        "pa_guard": _pa(gs_guard), "pa_guard_hit": _pa(gs_guard_hit), "pa_parry": _pa(gs_parry),
        # spear
        "sp_thrust_a": sp_thrust_a, "sp_thrust_b": sp_thrust_b, "sp_heavy": sp_heavy, "sp_dash": sp_dash,
        "sp_stab": sp_stab, "sp_guard": sp_guard, "sp_guard_hit": sp_guard_hit, "sp_parry": sp_parry,
        # bow
        "bow_pull": bow_pull, "bow_aim": bow_aim,
    }
