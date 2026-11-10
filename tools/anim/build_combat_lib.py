"""Build assets/anim/combat_lib.glb: the shared combat clip library (ADR 0011).

  BPY=<scratchpad>/bpyenv/bin/python          # bpy 4.5, see tools/art/README.md
  tools/anim/fetch_ual.sh                     # CC0 sources -> raw/anim_src/
  $BPY tools/anim/build_combat_lib.py [--only=clip,clip] [--probe=clip]
  godot --headless --path . --import          # (first time: then lib_import.py, import again)
  tools/anim/sheets.sh attack_l1@hewing_blade ...   # look at it

The library is the Bearer's own skeleton (so Godot's retarget import treats
it exactly like every other Mixamo rig) carrying one glTF animation per
clip in combat_clips.clips(). Each clip is one of:
  * a retarget of a CC0 clip (Quaternius Universal Animation Library 1/2):
    world-rotation deltas from the T rest pose, hips scaled by leg length;
  * that, cut, time-warped or re-posed (two-handed variants: the left hand is
    IK'd onto the haft);
  * hand-keyed: key poses solved with IK and eased between (combat_clips.py).
The build prints each clip's length and the frame of peak blade-tip speed;
section times (start/contact/end) are data in data/anim/clip_meta.json.
"""
import json
import math
import os
import sys

import bpy
from mathutils import Quaternion, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import anim_rig as R          # noqa: E402
import anim_pose as A         # noqa: E402
import combat_clips as C      # noqa: E402

FPS = 30
BASE = "assets/models/characters/bearer_traveller.glb"
OUT = "assets/anim/combat_lib.glb"
SOURCES = {"ual1": "raw/anim_src/UAL1_Standard.glb", "ual2": "raw/anim_src/UAL2_Standard.glb"}

# Quaternius universal rig bone -> Mixamo bone
MAP = {"pelvis": "Hips", "spine_01": "Spine", "spine_02": "Spine1", "spine_03": "Spine2",
       "neck_01": "Neck", "Head": "Head"}
for s, side in (("l", "Left"), ("r", "Right")):
    MAP.update({f"clavicle_{s}": f"{side}Shoulder", f"upperarm_{s}": f"{side}Arm",
                f"lowerarm_{s}": f"{side}ForeArm", f"hand_{s}": f"{side}Hand",
                f"thigh_{s}": f"{side}UpLeg", f"calf_{s}": f"{side}Leg",
                f"foot_{s}": f"{side}Foot", f"ball_{s}": f"{side}ToeBase"})
    for f, m in (("index", "Index"), ("middle", "Middle"), ("ring", "Ring"), ("pinky", "Pinky"), ("thumb", "Thumb")):
        for i in (1, 2, 3):
            MAP[f"{f}_0{i}_{s}"] = f"{side}Hand{m}{i}"


def rp(p):
    return os.path.join(ROOT, p)


def load_base():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=rp(BASE))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in [o for o in bpy.data.objects if o is not arm]:
        bpy.data.objects.remove(o, do_unlink=True)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    arm.animation_data_clear()
    arm.name = "combat_lib_rig"
    bpy.context.view_layer.update()
    return arm


class Source:
    """One CC0 library file: samples its clips as world rotations."""

    def __init__(self, path):
        before = set(bpy.data.objects)
        acts = set(bpy.data.actions)
        bpy.ops.import_scene.gltf(filepath=path)
        self.objs = [o for o in bpy.data.objects if o not in before]
        self.arm = next(o for o in self.objs if o.type == "ARMATURE")
        for o in [o for o in self.objs if o.type == "MESH"]:
            bpy.data.objects.remove(o, do_unlink=True)   # sampling stays cheap
        self.actions = {a.name: a for a in bpy.data.actions if a not in acts}
        mw = self.arm.matrix_world
        self.w0 = {b.name: (mw @ b.matrix_local).to_quaternion() for b in self.arm.data.bones}
        self.pelvis0 = mw @ self.arm.data.bones["pelvis"].head_local
        if self.arm.animation_data is None:
            self.arm.animation_data_create()

    def sample(self, clip, f0=None, f1=None):
        """[(world rot per mapped bone, pelvis world pos)] at FPS."""
        act = self.actions[clip]
        ad = self.arm.animation_data
        for t in ad.nla_tracks:
            t.mute = True
        ad.action = act
        if hasattr(ad, "action_slot") and getattr(act, "slots", None):
            ad.action_slot = act.slots[0]
        a0, a1 = act.frame_range
        f0 = a0 if f0 is None else f0
        f1 = a1 if f1 is None else f1
        out = []
        mw = self.arm.matrix_world
        n = int(round(f1 - f0))
        for i in range(n + 1):
            f = f0 + i
            bpy.context.scene.frame_set(int(f), subframe=f - int(f))
            pb = self.arm.pose.bones
            rots = {src: (mw @ pb[src].matrix).to_quaternion() for src in MAP}
            out.append((rots, mw @ pb["pelvis"].head))
        return out

    def free(self):
        bpy.data.objects.remove(self.arm, do_unlink=True)


def retarget(skel, src, frames):
    """World-rotation deltas from the source rest onto the target rest; the
    pelvis offset scales by the hips-height ratio."""
    k = skel.hips0.z / src.pelvis0.z
    out = []
    for rots, pelvis in frames:
        pose = skel.rest()
        pose.hips = skel.hips0 + (pelvis - src.pelvis0) * k
        w = {}
        for s_name, t_short in MAP.items():
            t = R.P + t_short
            if t in skel.w0:
                w[t] = rots[s_name] @ src.w0[s_name].inverted() @ skel.w0[t]
        for n in skel.names:   # parents first, so set_world sees final parents
            if n in w:
                pose.set_world(n, w[n])
        out.append(pose)
    return out


def write_action(arm, skel, name, poses):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    if hasattr(arm.animation_data, "action_slot") and getattr(act, "slots", None):
        arm.animation_data.action_slot = act.slots[0]
    inv_arm = skel.arm_rot.inverted()
    prev = {}
    for i, pose in enumerate(poses):
        for n in skel.names:
            pb = arm.pose.bones[n]
            q = skel.l0[n].inverted() @ pose.l[n]
            if n in prev and prev[n].dot(q) < 0:
                q.negate()      # keep the hemisphere: no long-way-round blends
            prev[n] = q
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=i)
        d = inv_arm @ (pose.hips - skel.hips0) / skel.arm_scale
        hb = arm.pose.bones[skel.root]
        hb.location = skel.bone_rest[skel.root].inverted() @ d
        hb.keyframe_insert("location", frame=i)
    tr = arm.animation_data.nla_tracks.new()
    tr.name = name
    st = tr.strips.new(name, 0, act)
    if hasattr(st, "action_slot") and getattr(act, "slots", None):
        st.action_slot = act.slots[0]
    arm.animation_data.action = None


def add_dummy_mesh(arm):
    """glTF only exports a skin (and Godot only builds a Skeleton3D) when a
    mesh is bound, so a degenerate triangle rides the hips."""
    me = bpy.data.meshes.new("combat_lib")
    me.from_pydata([(0, 0, 0), (0.001, 0, 0), (0, 0.001, 0)], [], [(0, 1, 2)])
    ob = bpy.data.objects.new("combat_lib", me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = arm
    for b in arm.data.bones:   # a group per bone keeps every joint in the skin
        g = ob.vertex_groups.new(name=b.name)
        g.add([0, 1, 2], 1.0 if b.parent is None else 0.0001, "REPLACE")
    ob.modifiers.new("Armature", "ARMATURE").object = arm


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    only = None
    probe = set()
    for a in argv:
        if a.startswith("--only="):
            only = set(a.split("=", 1)[1].split(","))
        elif a.startswith("--probe="):
            probe = set(a.split("=", 1)[1].split(","))
    arm = load_base()
    skel = R.Skel(arm)
    arm.animation_data_create()
    srcs = {}
    for key, path in SOURCES.items():
        if os.path.exists(rp(path)):
            srcs[key] = Source(rp(path))

    def mocap(lib, clip, f0=None, f1=None):
        if lib not in srcs:
            raise SystemExit(f"missing {SOURCES[lib]} (run tools/anim/fetch_ual.sh)")
        return retarget(skel, srcs[lib], srcs[lib].sample(clip, f0, f1))

    with open(os.path.join(HERE, "grips.json")) as f:
        grips = {k: A.Grip(v) for k, v in json.load(f).items() if not k.startswith("_")}
    ctx = C.Ctx(skel, FPS, mocap, grips)
    built = {}
    for name, make in C.clips().items():
        if only and name not in only:
            continue
        poses = make(ctx)
        built[name] = poses
        peak, sp, _ = A.tip_report(poses, grips["onehand"], FPS)
        drift = max((Vector((p.hips.x - skel.hips0.x, p.hips.y - skel.hips0.y)).length for p in poses))
        print(f"  clip {name}: {len(poses)} fr {(len(poses) - 1) / FPS:.2f}s  tip peak f{peak} t={peak / FPS:.2f} "
              f"({sp[peak]:.1f} m/s)  hips drift {drift:.2f} m")
        if name in probe:
            for i, p in enumerate(poses):
                g, a, _e = grips["onehand"].weapon_of(p)
                tip = A.rfu(g + a * 0.9)
                print(f"    f{i:3d} t={i / FPS:.2f} tip r{tip[0]:+.2f} f{tip[1]:+.2f} u{tip[2]:+.2f} v={sp[i]:5.1f} hips u{p.hips.z:.2f}")
    for s in srcs.values():
        s.free()
    for name, poses in built.items():
        write_action(arm, skel, name, poses)
    add_dummy_mesh(arm)
    out = rp(OUT)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animations=True, export_skins=True,
                              export_animation_mode="NLA_TRACKS", export_force_sampling=True,
                              export_def_bones=False, export_optimize_animation_size=False)
    print("wrote", OUT, os.path.getsize(out) // 1024, "KB")


if __name__ == "__main__":
    main()
