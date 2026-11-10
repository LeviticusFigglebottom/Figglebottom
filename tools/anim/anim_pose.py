"""Authoring layer over anim_rig: weapon grips, a control rig whose key
poses are solved with IK and eased between, and clip utilities (concat,
time-warp, two-handed re-pose) for the retargeted mocap.

Everything here speaks [right, forward, up] metres and degrees:
  yaw + = turn left, pitch + = lean forward, roll + = lean right.
"""
import math
from mathutils import Matrix, Quaternion, Vector
import anim_rig as R

P = R.P
SPINE = [P + "Spine", P + "Spine1", P + "Spine2"]
FINGERS = ["Thumb", "Index", "Middle", "Ring", "Pinky"]


def V(r=0.0, f=0.0, u=0.0):
    return Vector((-r, -f, u))


def rfu(v):
    return (-v.x, -v.y, v.z)


def ypr(yaw=0.0, pitch=0.0, roll=0.0):
    return (Quaternion((0, 0, 1), math.radians(yaw)) @ Quaternion((1, 0, 0), math.radians(pitch))
            @ Quaternion((0, 1, 0), math.radians(-roll)))


def frame(a, e):
    a = a.normalized()
    e2 = e - a * e.dot(a)
    if e2.length < 1e-5:
        e2 = Vector((0, 0, 1)) - a * a.z
    e2.normalize()
    return Matrix((a, e2, a.cross(e2))).transposed()


class Grip:
    """A weapon class's grip (tools/anim/grips.json) in rest character space."""

    def __init__(self, d):
        self.a0 = V(*d["blade"]).normalized()
        self.e0 = V(*d["edge"])
        px, py, pz = d["pos"]            # hand-bone space: x forward, y to the fingers, z into the palm
        self.g0 = V(py, px, -pz)
        self.left_at = d.get("left_at", -0.2)
        mir = lambda v: Vector((-v.x, v.y, v.z))
        self.a0L, self.e0L, self.g0L = mir(self.a0), mir(self.e0), mir(self.g0)
        self.f0 = frame(self.a0, self.e0)
        self.f0L = frame(self.a0L, self.e0L)

    def rot(self, direction, edge, left=False):
        return (frame(direction, edge) @ (self.f0L if left else self.f0).inverted()).to_quaternion()

    def weapon_of(self, pose):
        """(grip point, blade direction, edge direction) from the right hand."""
        h = P + "RightHand"
        q = pose.W(h) @ pose.s.w0[h].inverted()
        return pose.pos(h) + q @ self.g0, q @ self.a0, q @ self.e0

    def set_weapon(self, pose, gpos, direction, edge, pole=None):
        h = P + "RightHand"
        q = self.rot(direction, edge)
        pose.arm_ik("Right", gpos - q @ self.g0, pole or V(0.6, -0.5, -0.8))
        pose.set_world(h, q @ pose.s.w0[h])

    def left_on_haft(self, pose, d=None, pole=None):
        """Close the left hand on the haft `d` metres along the blade."""
        h = P + "LeftHand"
        g, a, e = self.weapon_of(pose)
        q = self.rot(a, e, left=True)
        target = g + a * (self.left_at if d is None else d) - q @ self.g0L
        pose.arm_ik("Left", target, pole or V(-0.5, -0.2, -0.9))
        pose.set_world(h, q @ pose.s.w0[h])
        return (pose.pos(h) - target).length


def copy_fist(pose, src_pose):
    """Curl the left fingers as the source pose's right hand (mirrored)."""
    s = pose.s
    mir = lambda q: Quaternion((q.w, q.x, -q.y, -q.z))
    hr, hl = P + "RightHand", P + "LeftHand"
    dr = src_pose.W(hr) @ s.w0[hr].inverted()
    dl = pose.W(hl) @ s.w0[hl].inverted()
    for f in FINGERS:
        for i in (1, 2, 3):
            br, bl = f"{P}RightHand{f}{i}", f"{P}LeftHand{f}{i}"
            if br in s.w0 and bl in s.w0:
                rel = dr.inverted() @ (src_pose.W(br) @ s.w0[br].inverted())
                pose.set_world(bl, dl @ mir(rel) @ s.w0[bl])


# ---------------------------------------------------------------- control rig
def _lerp(a, b, t):
    if a is None or b is None:
        return b if t >= 0.5 else a
    if isinstance(a, Quaternion) or isinstance(b, Quaternion):
        if not (isinstance(a, Quaternion) and isinstance(b, Quaternion)):
            return b if t >= 0.5 else a
        return a.slerp(b, t)
    if isinstance(a, bool):
        return b if t >= 0.5 else a
    if isinstance(a, dict):
        return {k: _lerp(a.get(k, [0, 0, 0]), b.get(k, [0, 0, 0]), t) for k in set(a) | set(b)}
    if isinstance(a, (int, float)):
        return a + (b - a) * t
    return [x + (y - x) * t for x, y in zip(a, b)]


class Rig:
    """Key poses as controls over a base pose; unset parts follow the base by FK.

    controls (all optional, sticky from the previous key):
      hips   [dr, df, du, yaw, pitch, roll]   offset from the base, feet stay planted
      chest  [yaw, pitch, roll]               spread over the three spine bones
      head   [yaw, pitch]
      footL / footR [dr, df, du, yaw, pitch]  offset from the base foot (pitch lifts the heel)
      weapon [r, f, u,  dir r, f, u,  edge r, f, u]   grip point, blade and edge direction
      left   d                                left hand on the haft, d metres along the blade
      lhand  [r, f, u]                        free left wrist target
      rhand  [r, f, u]                        free right wrist target (no weapon control)
      lrot / rrot [yaw, pitch, roll]          free hand orientation from its rest (T) pose
      lfist  True                             close the left hand (as the base's sword hand)
      rpole / lpole [r, f, u]                 elbow direction
      bones  {name: [yaw, pitch, roll]}       extra FK on a bone (short Mixamo name)
    """

    def __init__(self, skel, base, grip, fist_from=None):
        self.s = skel
        self.base = base
        self.grip = grip
        self.fist_from = fist_from
        self.foot0 = {sd: (base.pos(P + sd + "Foot").copy(), base.W(P + sd + "Foot").copy())
                      for sd in R.SIDES}

    def solve(self, c):
        s = self.s
        p = self.base.copy()
        h = c.get("hips") or [0] * 6
        hq = ypr(h[3], h[4], h[5])
        p.hips = self.base.hips + V(h[0], h[1], h[2])
        p.set_world(s.root, hq @ self.base.W(s.root))
        ch = c.get("chest") or [0, 0, 0]
        cq = ypr(*ch)
        third = Quaternion().slerp(cq, 1.0 / 3.0)
        for b in SPINE:
            p.rot_world(b, hq @ third @ hq.inverted())
        hd = c.get("head") or [0, 0]
        fq = hq @ cq
        half = Quaternion().slerp(ypr(hd[0], hd[1], 0), 0.5)
        for b in (P + "Neck", P + "Head"):
            p.rot_world(b, fq @ half @ fq.inverted())
        for name, e in (c.get("bones") or {}).items():
            p.rot_world(P + name, ypr(*e))
        for sd, key in (("Left", "footL"), ("Right", "footR")):
            f = c.get(key) or [0] * 5
            pos0, w0 = self.foot0[sd]
            yq = Quaternion((0, 0, 1), math.radians(f[3]))
            fw = yq @ Quaternion((1, 0, 0), math.radians(f[4])) @ w0
            pole = yq @ (w0 @ s.w0[P + sd + "Foot"].inverted() @ Vector((0, -1, 0)))
            pole.z = 0
            p.leg_ik(sd, pos0 + V(f[0], f[1], f[2]), pole.normalized() + V(0.25 if sd == "Right" else -0.25, 0, 0))
            p.set_world(P + sd + "Foot", fw)
        w = c.get("weapon")
        if w is not None:
            rp = c.get("rpole")
            self.grip.set_weapon(p, V(*w[0:3]), V(*w[3:6]), V(*w[6:9]), V(*rp) if rp else None)
        lp = c.get("lpole")
        if c.get("left") is not None:
            self.grip.left_on_haft(p, c["left"], V(*lp) if lp else None)
            if self.fist_from is not None:
                copy_fist(p, self.fist_from)
        elif c.get("lhand") is not None:
            p.arm_ik("Left", V(*c["lhand"]), V(*lp) if lp else V(-0.5, -0.3, -0.8))
            self._hand_rot(p, "Left", c.get("lrot"))
            if c.get("lfist") and self.fist_from is not None:
                copy_fist(p, self.fist_from)
        if w is None and c.get("rhand") is not None:
            rp = c.get("rpole")
            p.arm_ik("Right", V(*c["rhand"]), V(*rp) if rp else V(0.5, -0.3, -0.8))
            self._hand_rot(p, "Right", c.get("rrot"))
        if c.get("fists") and self.fist_from is not None:
            # both hands closed as the reference's weapon hand (left mirrored)
            mir = lambda q: Quaternion((q.w, q.x, -q.y, -q.z))
            for f in FINGERS:
                for i in (1, 2, 3):
                    br, bl = f"{P}RightHand{f}{i}", f"{P}LeftHand{f}{i}"
                    if br in p.l and bl in p.l:
                        p.l[br] = self.fist_from.l[br].copy()
                        p.l[bl] = mir(self.fist_from.l[br])
            p.dirty()
        return p

    def _hand_rot(self, p, side, rot):
        """A free hand: world rotation if given (Quaternion, or ypr from the
        T rest), else a straight wrist in line with the forearm."""
        h = P + side + "Hand"
        if isinstance(rot, Quaternion):
            p.set_world(h, rot)
        elif rot is not None:
            p.set_world(h, ypr(*rot) @ self.s.w0[h])
        else:
            p.l[h] = self.s.l0[h].copy()
            p.dirty()

    def hands_ctl(self, pose=None):
        """Controls that hold both wrists where a pose has them."""
        q = pose or self.base
        return {"rhand": list(rfu(q.pos(P + "RightHand"))), "rrot": q.W(P + "RightHand").copy(),
                "lhand": list(rfu(q.pos(P + "LeftHand"))), "lrot": q.W(P + "LeftHand").copy()}

    def wctl(self, pose=None):
        """The weapon control that reproduces a pose's right hand."""
        g, a, e = self.grip.weapon_of(pose or self.base)
        return list(rfu(g)) + list(rfu(a)) + list(rfu(e))

    def clip(self, keys, fps=30):
        """keys: [(time s, ease into this key, controls)]. Controls are
        interpolated (so hands and feet travel in world space) and solved
        every frame."""
        full = []
        cur = {}
        for t, kind, c in keys:
            cur = dict(cur)
            for k, v in c.items():
                if k == "bones":
                    b = dict(cur.get("bones") or {})
                    b.update(v)
                    cur["bones"] = b
                else:
                    cur[k] = v
            full.append((t, kind, cur))
        out = []
        n = int(round(full[-1][0] * fps))
        for i in range(n + 1):
            t = i / fps
            j = 0
            while j < len(full) - 2 and t > full[j + 1][0]:
                j += 1
            t0, _, c0 = full[j]
            t1, kind, c1 = full[j + 1]
            u = R.ease((t - t0) / max(t1 - t0, 1e-6), kind)
            c = {k: _lerp(c0.get(k), c1.get(k), u) for k in set(c0) | set(c1)}
            out.append(self.solve(c))
        return out


# ------------------------------------------------------------ clip utilities
def concat(a, b):
    return a + b[1:]


def sample(poses, f):
    f = max(0.0, min(len(poses) - 1.0, f))
    i = int(f)
    if i >= len(poses) - 1:
        return poses[-1].copy()
    return R.slerp_pose(poses[i], poses[i + 1], f - i)


def warp(poses, segs):
    """Stretch frame ranges: segs = [(from, to, scale)]; scale 2 plays that
    range at half speed (a longer wind-up or settle)."""
    out = []
    f = 0.0
    last = len(poses) - 1
    while f <= last + 1e-6:
        out.append(sample(poses, f))
        sc = 1.0
        for a, b, k in segs:
            if a <= f < b:
                sc = k
        f += 1.0 / sc
    return out


def ease_to(poses, target, n, end=True):
    """Blend the last (or first) n frames toward a pose (the stance)."""
    out = [p.copy() for p in poses]
    for i in range(n):
        u = R.ease((i + 1) / n)
        k = len(out) - n + i if end else n - 1 - i
        out[k] = R.slerp_pose(out[k], target, u)
    return out


def hold(pose, n):
    return [pose.copy() for _ in range(n)]


def floor_clamp(poses, grip, length, floor=0.03):
    """Keep the blade out of the ground: where its tip would dip under the
    floor the wrist cocks just enough to lay it along the surface."""
    out = []
    h = P + "RightHand"
    for p in poses:
        p = p.copy()
        g, a, _e = grip.weapon_of(p)
        tip = g + a * length
        if tip.z < floor:
            want_z = max(-0.2, min(1.0, (floor - g.z) / length))
            flat = Vector((a.x, a.y, 0.0))
            if flat.length < 1e-4:
                flat = Vector((0.0, -1.0, 0.0))
            flat.normalize()
            target = flat * math.sqrt(max(0.0, 1.0 - want_z * want_z)) + Vector((0, 0, want_z))
            q = a.rotation_difference(target)
            wrist = p.pos(h).copy()
            p.set_world(h, q @ p.W(h))
            # the grip point stays where it was: the wrist swings round it
            g2, _a2, _e2 = grip.weapon_of(p)
            p.arm_ik("Right", wrist + (g - g2), None)
        out.append(p)
    return out


BODY_R = {"Hips": 0.13, "Spine1": 0.13, "Spine2": 0.14, "Head": 0.11, "LeftLeg": 0.07, "RightLeg": 0.07,
          "LeftFoot": 0.05, "RightFoot": 0.05, "LeftForeArm": 0.05, "RightForeArm": 0.05,
          "LeftHand": 0.04, "RightHand": 0.04, "LeftArm": 0.07, "RightArm": 0.07}


def lift_to_floor(poses, smooth=2):
    """Retargeted falls and rolls sink a little (the source body is slimmer):
    raise the pelvis wherever a body part would be under the ground."""
    need = []
    for p in poses:
        low = min(p.pos(P + b).z - r for b, r in BODY_R.items())
        need.append(max(0.0, -low))
    for _ in range(smooth):   # spread each lift over its neighbours so it never pops
        need = [max(need[i], 0.5 * (need[max(i - 1, 0)] + need[min(i + 1, len(need) - 1)])) for i in range(len(need))]
    out = []
    for p, dz in zip(poses, need):
        p = p.copy()
        p.hips = p.hips + Vector((0, 0, dz))
        p.dirty()
        out.append(p)
    return out


def two_hand(poses, grip, d=None, fist_from=None, chest_help=0.6):
    """Re-pose a one-handed clip two-handed: the left hand closes on the haft.
    Where the haft is out of the left arm's reach the chest turns toward it
    (the right arm is re-solved so the weapon itself never moves)."""
    out = []
    for p in poses:
        p = p.copy()
        s = p.s
        hr = P + "RightHand"
        for _ in range(4):
            g, a, e = grip.weapon_of(p)
            sh = p.pos(P + "LeftArm")
            reach = (s.length(P + "LeftArm", P + "LeftForeArm") + s.length(P + "LeftForeArm", P + "LeftHand")) * 0.96
            tgt = g + a * (grip.left_at if d is None else d)
            over = (tgt - sh).length - reach
            if over <= 0.0:
                break
            # turn the upper spine about the vertical so the left shoulder closes in
            pivot = p.pos(P + "Spine1")
            v1, v2 = sh - pivot, tgt - pivot
            v1.z = v2.z = 0
            if v1.length < 1e-4 or v2.length < 1e-4:
                break
            ang = v1.angle(v2) * chest_help
            if v1.cross(v2).z < 0:
                ang = -ang
            ang = max(-0.35, min(0.35, ang))
            wpos, ww = p.pos(hr).copy(), p.W(hr).copy()
            for b in SPINE[1:]:
                p.rot_world(b, Quaternion((0, 0, 1), ang / 2))
            p.arm_ik("Right", wpos, None)
            p.set_world(hr, ww)
        grip.left_on_haft(p, d)
        if fist_from is not None:
            copy_fist(p, fist_from)
        out.append(p)
    return out


def tip_report(poses, grip, fps, length=0.9):
    """Frame of peak blade-tip speed (the natural contact frame) and a table."""
    tips = []
    for p in poses:
        g, a, _ = grip.weapon_of(p)
        tips.append(g + a * length)
    sp = [0.0] + [(tips[i] - tips[i - 1]).length * fps for i in range(1, len(tips))]
    peak = max(range(len(sp)), key=lambda i: sp[i])
    return peak, sp, tips
