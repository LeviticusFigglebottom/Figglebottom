"""Pure-math pose model for the Mixamo skeleton (used by build_combat_lib.py).

Works in CHARACTER SPACE: metres, X = the character's left, -Y = forward,
Z = up (Blender world with the rig standing at the origin facing -Y).
A Pose stores each bone's rotation relative to its parent's world rotation
plus the hips position, so editing a parent carries its children. FK and the
two-bone IK are done here rather than through Blender's depsgraph: a clip is
a plain list of Poses that can be retargeted, edited, blended and only at
the end written to an Action.
"""
import math
from mathutils import Matrix, Quaternion, Vector

P = "mixamorig:"
SIDES = ("Left", "Right")


class Skel:
    """Rest data read once from the armature object."""

    def __init__(self, arm):
        self.arm = arm
        mw = arm.matrix_world
        self.arm_rot = mw.to_quaternion()
        self.arm_scale = mw.to_scale().x
        self.names = []
        self.parent = {}
        self.children = {}
        self.w0 = {}      # rest world rotation
        self.h0 = {}      # rest world head
        self.off = {}     # head offset from the parent head, in the parent's rest frame
        self.l0 = {}      # rest rotation relative to the parent's world rotation
        self.bone_rest = {}   # armature-space rest 3x3 (for location keys)

        def walk(b):
            n = b.name
            self.names.append(n)
            self.children[n] = [c.name for c in b.children]
            self.w0[n] = (mw @ b.matrix_local).to_quaternion()
            self.h0[n] = mw @ b.head_local
            self.bone_rest[n] = b.matrix_local.to_3x3()
            if b.parent:
                p = b.parent.name
                self.parent[n] = p
                self.off[n] = self.w0[p].inverted() @ (self.h0[n] - self.h0[p])
                self.l0[n] = self.w0[p].inverted() @ self.w0[n]
            else:
                self.parent[n] = None
                self.off[n] = Vector((0, 0, 0))
                self.l0[n] = self.w0[n].copy()
            for c in b.children:
                walk(c)

        for b in arm.data.bones:
            if b.parent is None:
                walk(b)
        self.root = self.names[0]
        self.hips0 = self.h0[self.root].copy()

    def rest(self):
        return Pose(self, {n: q.copy() for n, q in self.l0.items()}, self.hips0.copy())

    def length(self, a, b):
        return (self.h0[b] - self.h0[a]).length


class Pose:
    def __init__(self, skel, l, hips):
        self.s = skel
        self.l = l
        self.hips = hips
        self._w = None
        self._p = None

    def copy(self):
        return Pose(self.s, {n: q.copy() for n, q in self.l.items()}, self.hips.copy())

    def dirty(self):
        self._w = None

    def fk(self):
        if self._w is None:
            s = self.s
            w, p = {}, {}
            for n in s.names:   # parents come first
                par = s.parent[n]
                if par is None:
                    w[n] = self.l[n].copy()
                    p[n] = self.hips.copy()
                else:
                    w[n] = w[par] @ self.l[n]
                    p[n] = p[par] + w[par] @ s.off[n]
            self._w, self._p = w, p
        return self._w, self._p

    def W(self, n):
        return self.fk()[0][n]

    def pos(self, n):
        return self.fk()[1][n]

    def set_world(self, n, q):
        par = self.s.parent[n]
        self.l[n] = q.copy() if par is None else self.W(par).inverted() @ q
        self.dirty()

    def rot_world(self, n, q):
        """Rotate bone n (and its children) by world rotation q about its head."""
        self.set_world(n, q @ self.W(n))

    def rot_about(self, n, q, pivot):
        """Rotate the whole body by q about a world pivot (root only)."""
        assert self.s.parent[n] is None
        self.hips = pivot + q @ (self.hips - pivot)
        self.set_world(n, q @ self.W(n))

    def keep_world(self, names, fn):
        """Run fn, then restore the world rotations of `names` (hands, feet)."""
        keep = {n: self.W(n).copy() for n in names}
        fn()
        for n in names:
            self.set_world(n, keep[n])

    # --- IK -----------------------------------------------------------
    def ik2(self, upper, lower, end, target, pole=None, keep_end=True, soft=0.995):
        """Analytic two-bone IK: put `end`'s head on `target`. `pole` is a
        world direction the middle joint should lean toward."""
        s = self.s
        end_w = self.W(end).copy()
        a = self.pos(upper)
        l1 = s.length(upper, lower)
        l2 = s.length(lower, end)
        d = (target - a).length
        d = max(min(d, (l1 + l2) * soft), abs(l1 - l2) + 1e-4)
        # 1. open/close the middle joint to the right reach
        b, c = self.pos(lower), self.pos(end)
        ba, bc = (a - b).normalized(), (c - b).normalized()
        cur = ba.angle(bc, math.pi)
        want = math.acos(max(-1.0, min(1.0, (l1 * l1 + l2 * l2 - d * d) / (2 * l1 * l2))))
        axis = ba.cross(bc)
        if axis.length < 1e-5:
            axis = (pole or Vector((0, -1, 0))).cross(ba)
            if axis.length < 1e-5:
                axis = Vector((1, 0, 0))
        axis.normalize()
        self.rot_world(lower, Quaternion(axis, want - cur))
        # 2. swing the whole limb onto the target
        c = self.pos(end)
        v1, v2 = (c - a), (target - a)
        if v1.length > 1e-6 and v2.length > 1e-6:
            self.rot_world(upper, v1.rotation_difference(v2))
        # 3. swivel the middle joint toward the pole
        if pole is not None:
            a, b, c = self.pos(upper), self.pos(lower), self.pos(end)
            ax = (c - a)
            if ax.length > 1e-5:
                ax.normalize()
                cur_p = (b - a) - ax * (b - a).dot(ax)
                want_p = pole - ax * pole.dot(ax)
                if cur_p.length > 1e-4 and want_p.length > 1e-4:
                    ang = cur_p.angle(want_p)
                    if cur_p.cross(want_p).dot(ax) < 0:
                        ang = -ang
                    self.rot_world(upper, Quaternion(ax, ang))
        if keep_end:
            self.set_world(end, end_w)

    def arm_ik(self, side, target, pole=None):
        self.ik2(P + side + "Arm", P + side + "ForeArm", P + side + "Hand", target, pole)

    def leg_ik(self, side, target, pole=None):
        self.ik2(P + side + "UpLeg", P + side + "Leg", P + side + "Foot", target, pole)

    def move_hips(self, delta, plant=("Left", "Right")):
        """Shift the pelvis while the planted feet stay where they are."""
        feet = {sd: (self.pos(P + sd + "Foot").copy(), self.W(P + sd + "Foot").copy()) for sd in plant}
        self.hips = self.hips + delta
        self.dirty()
        for sd, (fp, fw) in feet.items():
            self.leg_ik(sd, fp, self._knee_pole(sd))
            self.set_world(P + sd + "Foot", fw)

    def turn_hips(self, q, plant=("Left", "Right")):
        """Rotate the pelvis (world q) with the planted feet held."""
        feet = {sd: (self.pos(P + sd + "Foot").copy(), self.W(P + sd + "Foot").copy()) for sd in plant}
        self.set_world(self.s.root, q @ self.W(self.s.root))
        for sd, (fp, fw) in feet.items():
            self.leg_ik(sd, fp, self._knee_pole(sd))
            self.set_world(P + sd + "Foot", fw)

    def _knee_pole(self, side):
        # knees track the foot's forward direction (foot bone runs heel -> toe)
        f = self.W(P + side + "Foot") @ self.s.w0[P + side + "Foot"].inverted() @ Vector((0, -1, 0))
        f.z = 0
        return f.normalized() if f.length > 1e-4 else Vector((0, -1, 0))


def slerp_pose(a, b, t):
    l = {n: a.l[n].slerp(b.l[n], t) for n in a.l}
    return Pose(a.s, l, a.hips.lerp(b.hips, t))


def ease(t, kind="inout"):
    t = max(0.0, min(1.0, t))
    if kind == "lin":
        return t
    if kind == "in":        # slow start, fast end: a strike accelerating into contact
        return t * t * t
    if kind == "out":       # fast start, settles
        return 1 - (1 - t) ** 3
    if kind == "over":      # overshoots by ~8% and settles
        c1 = 1.4
        return 1 + (c1 + 1) * (t - 1) ** 3 + c1 * (t - 1) ** 2
    return t * t * (3 - 2 * t)


def qaxis(axis, deg):
    v = {"x": (1, 0, 0), "y": (0, 1, 0), "z": (0, 0, 1)}[axis] if isinstance(axis, str) else axis
    return Quaternion(Vector(v), math.radians(deg))
