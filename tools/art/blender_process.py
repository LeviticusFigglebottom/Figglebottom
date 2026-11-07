"""Turn a raw Tripo download into a game-ready GLB, driven by tools/art/manifest.json.

usage: $BPY tools/art/blender_process.py [--only NAME ...] [--manifest tools/art/manifest.json]

Per asset kind:
  static     join meshes, apply transforms, yaw, scale to target width/height, put the
             origin at bottom centre, name the node <name>-col / -convcol so Godot builds
             collision on import.
  weapon     auto-orient by PCA: the long axis becomes up (glTF +Y), the edge faces
             glTF +Z, the grip centre sits at the origin. Scale to target length.
  character  import the rigged FBX, then merge every animation FBX in "anims" as an NLA
             track named after the clip. Scale, yaw and drop it to the floor at the armature
             object level, not by applying them, so root-motion keys keep their meaning.

Always: rename materials to M_<name>[_i], downscale textures to texture_max, and export a
GLB with JPEG textures. LODs are left to Godot's importer (meshes/generate_lods, on by default).
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from blender_common import import_any, mesh_objects, world_bbox  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))


def rp(p):
    return p if os.path.isabs(p) else os.path.join(ROOT, p)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def tri_count(obs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs)


def rename_and_downscale(name, texture_max):
    mats = sorted({s.material for o in mesh_objects() for s in o.material_slots if s.material}, key=lambda m: m.name)
    for i, m in enumerate(mats):
        m.name = f"M_{name}" + (f"_{i}" if i else "")
    for img in bpy.data.images:
        if img.size[0] == 0:
            continue
        # clean names: Godot extracts embedded textures next to the GLB using these
        for key in ("BaseColor", "Normal", "Metallic", "Roughness", "Emissive", "Occlusion", "ORM", "Color"):
            if key.lower() in img.name.lower():
                img.name = f"T_{name}_{key}"
                break
        w, h = img.size
        if max(w, h) > texture_max:
            s = texture_max / max(w, h)
            img.scale(int(w * s), int(h * s))
            print(f"  texture {img.name}: {w}x{h} -> {img.size[0]}x{img.size[1]}")
        # pack so the exporter names the texture after img.name, not the source file path
        if img.packed_file is None or img.is_dirty:
            img.pack()
        img.filepath_raw = f"//{img.name}.jpg"  # the exporter names images by filepath basename


def join_static():
    """Join all meshes into one object with transforms applied, and delete everything else."""
    obs = mesh_objects()
    for o in obs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
    for o in list(bpy.context.scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


def verts_np(ob):
    n = len(ob.data.vertices)
    a = np.empty(n * 3)
    ob.data.vertices.foreach_get("co", a)
    return a.reshape(n, 3)


def set_verts(ob, v):
    ob.data.vertices.foreach_set("co", v.ravel())
    ob.data.update()


def process_static(a, ob):
    v = verts_np(ob)
    yaw = math.radians(a.get("yaw_deg", 0))
    R = np.array(Matrix.Rotation(yaw, 3, "Z"))
    v = v @ R.T
    lo, hi = v.min(0), v.max(0)
    size = hi - lo
    t = a["target"]
    if "fit" in t:
        # per-axis fit (Blender x, y, z in metres) for set pieces whose generated proportions
        # are off the design sheet, e.g. a 12 m hearth trench that Tripo makes short and deep
        f = np.array([t["fit"][k] / size[i] for i, k in enumerate("xyz")])
    elif "width" in t:
        f = t["width"] / size[0]
    elif "height" in t:
        f = t["height"] / size[2]
    else:
        f = t["length"] / size.max()
    v *= f
    lo, hi = v.min(0), v.max(0)
    # origin: bottom_center (kit, props, landmarks) or center (strapped items such as shields)
    z0 = (lo[2] + hi[2]) / 2 if a.get("origin") == "center" else lo[2]
    v -= np.array([(lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, z0])
    set_verts(ob, v)
    return v


def process_weapon(a, ob):
    v = verts_np(ob)
    c = v.mean(0)
    v = v - c
    w, vecs = np.linalg.eigh(np.cov(v.T))
    order = np.argsort(w)[::-1]
    a1, a2, a3 = (vecs[:, i] for i in order)  # long, width, thickness
    # rows: new X = thickness, new Y = -width (edge goes to -Y = glTF +Z), new Z = long
    M = np.array([a3, -a2, a1])
    if np.linalg.det(M) < 0:
        M[0] *= -1
    v = v @ M.T
    L = v[:, 2].max() - v[:, 2].min()

    def thick(sel):
        s = v[sel]
        return (s[:, 0].max() - s[:, 0].min()) if len(s) > 3 else 0

    z0, z1 = v[:, 2].min(), v[:, 2].max()
    lower = thick(v[:, 2] < z0 + 0.2 * L)
    upper = thick(v[:, 2] > z1 - 0.2 * L)
    # grip (round, thick) must be at the bottom; flip about X. Hafted weapons (maul,
    # spade) have the heavy end at the head, so the manifest says grip_end: "thin".
    grip_at_top = upper > lower
    if a.get("grip_end") == "thin":
        grip_at_top = not grip_at_top
    if grip_at_top:
        v = v * np.array([1, -1, -1])
        z0, z1 = v[:, 2].min(), v[:, 2].max()
    # guard = widest slice (Y extent) in the lower 45%
    bins = np.linspace(z0, z0 + 0.45 * L, 24)
    widths = []
    for b0, b1 in zip(bins[:-1], bins[1:]):
        s = v[(v[:, 2] >= b0) & (v[:, 2] < b1)]
        widths.append((s[:, 1].max() - s[:, 1].min()) if len(s) > 3 else 0)
    gi = int(np.argmax(widths))
    z_guard = (bins[gi] + bins[gi + 1]) / 2
    # edge side: in the blade, compare thickness near the +Y and -Y extremes; the edge is thin
    blade = v[v[:, 2] > z_guard + 0.15 * L]
    ymin, ymax = blade[:, 1].min(), blade[:, 1].max()
    bw = ymax - ymin

    def side_thick(sel):
        s = blade[sel]
        return (s[:, 0].max() - s[:, 0].min()) if len(s) > 3 else 0

    t_pos = side_thick(blade[:, 1] > ymax - 0.2 * bw)
    t_neg = side_thick(blade[:, 1] < ymin + 0.2 * bw)
    if t_pos < t_neg:  # edge currently at +Y; we want it at -Y (glTF +Z)
        v = v * np.array([-1, -1, 1])
    # scale to length, then put the grip centre (midway pommel..guard) at the origin
    f = a["target"]["length"] / L
    v *= f
    z_guard *= f
    grip_z = (v[:, 2].min() + z_guard) / 2
    if a.get("grip_from_pommel") is not None:
        # guardless blades (seax, needle): the widest slice is the pommel cap, so the
        # design sheet gives the grip centre as a distance from the pommel end instead
        grip_z = v[:, 2].min() + a["grip_from_pommel"]
        z_guard = grip_z + a["grip_from_pommel"]
    grip = v[np.abs(v[:, 2] - grip_z) < 0.02]
    cx, cy = (grip[:, 0].mean(), grip[:, 1].mean()) if len(grip) else (0, 0)
    v -= np.array([cx, cy, grip_z])
    set_verts(ob, v)
    print(f"  weapon: guard at {z_guard - grip_z:+.3f} m from grip, pommel {v[:, 2].min():+.3f}, tip {v[:, 2].max():+.3f}")
    return v


def merge_anims(arm, anims):
    if arm.animation_data is None:
        arm.animation_data_create()
    for clip, path in anims.items():
        before = set(bpy.data.objects)
        acts_before = set(bpy.data.actions)
        import_any(rp(path))
        new_obs = [o for o in bpy.data.objects if o not in before]
        new_acts = [x for x in bpy.data.actions if x not in acts_before]
        src = [o for o in new_obs if o.type == "ARMATURE" and o.animation_data and o.animation_data.action]
        act = src[0].animation_data.action if src else (new_acts[0] if new_acts else None)
        if act is None:
            raise SystemExit(f"no action in {path}")
        act.name = clip
        act.use_fake_user = True
        _strip_object_keys(act)
        for o in new_obs:
            bpy.data.objects.remove(o, do_unlink=True)
        tr = arm.animation_data.nla_tracks.new()
        tr.name = clip
        st = tr.strips.new(clip, int(act.frame_range[0]), act)
        if hasattr(st, "action_slot") and getattr(act, "slots", None):
            st.action_slot = act.slots[0]
        tr.mute = False
        print(f"  anim {clip}: frames {act.frame_range[0]:.0f}-{act.frame_range[1]:.0f}")
    arm.animation_data.action = None


def _strip_object_keys(act):
    """Drop armature-object transform keys. Tripo's quadruped clips key the object's own
    location/rotation/scale (all identity), which would override the scale and yaw this
    script sets on the armature object."""
    bags = []
    try:
        bags = [act]
        list(act.fcurves)
    except AttributeError:  # slotted actions (Blender 4.4+)
        bags = [cb for layer in act.layers for st in layer.strips for cb in st.channelbags]
    for bag in bags:
        for fc in [f for f in bag.fcurves if not f.data_path.startswith("pose.bones")]:
            bag.fcurves.remove(fc)


def _fcurves(act):
    try:
        return list(act.fcurves)
    except AttributeError:  # slotted actions (Blender 4.4+) without the legacy accessor
        out = []
        for layer in act.layers:
            for st in layer.strips:
                for cb in st.channelbags:
                    out.extend(cb.fcurves)
        return out


def make_in_place(clips, up_index=1, root_bone="Hips"):
    """Remove the horizontal root drift (linear start->end trend) from the Hips location.

    Gameplay moves the capsule; the clip should stay put. Sway and bob are kept. The
    mixamo Hips bone points up, so bone-local Y (index 1) is vertical and X/Z are horizontal.
    """
    for clip in clips:
        act = bpy.data.actions.get(clip)
        if act is None:
            continue
        for fc in _fcurves(act):
            if fc.data_path.endswith('"].location') and root_bone in fc.data_path and fc.array_index != up_index:
                kps = fc.keyframe_points
                if len(kps) < 2:
                    continue
                (x0, y0), (x1, y1) = kps[0].co[:], kps[-1].co[:]
                # remove the start offset and the linear trend, then centre the residual sway
                for k in kps:
                    t = (k.co[0] - x0) / max(1e-6, x1 - x0)
                    d = y0 + (y1 - y0) * t
                    k.co[1] -= d
                    k.handle_left[1] -= d
                    k.handle_right[1] -= d
                mean = sum(k.co[1] for k in kps) / len(kps)
                for k in kps:
                    k.co[1] -= mean
                    k.handle_left[1] -= mean
                    k.handle_right[1] -= mean
                fc.update()
                print(f"  in-place {clip}: removed {y1 - y0:+.3f} drift on location[{fc.array_index}]")


def process_character(a):
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if not arms:
        raise SystemExit("character input has no armature (rig first)")
    arm = arms[0]
    arm.name = a["name"] + "_rig"
    # Tripo rig exports can carry a stray unskinned placeholder mesh (an 80-tri icosphere,
    # 2 m across) that would wreck the size fit; keep only meshes driven by the armature
    for o in mesh_objects():
        if o.parent != arm and not any(m.type == "ARMATURE" for m in o.modifiers):
            print(f"  drop stray mesh {o.name} ({len(o.data.polygons)} faces)")
            bpy.data.objects.remove(o, do_unlink=True)
    merge_anims(arm, a.get("anims", {}))
    # quadruped rigs root at tripo::Root, whose up axis is not bone-local Y: strip only the trend
    make_in_place(a.get("in_place", []), *((-1, a["root_bone"]) if a.get("root_bone") else ()))
    arm.data.pose_position = "REST"
    bpy.context.view_layer.update()
    lo, hi = world_bbox(mesh_objects())
    h = hi.z - lo.z
    f = a["target"]["height"] / h
    yaw = math.radians(a.get("yaw_deg", 0))
    arm.matrix_world = Matrix.Rotation(yaw, 4, "Z") @ Matrix.Scale(f, 4) @ arm.matrix_world
    bpy.context.view_layer.update()
    lo, hi = world_bbox(mesh_objects())
    arm.location -= Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    bpy.context.view_layer.update()
    lo, hi = world_bbox(mesh_objects())
    arm.data.pose_position = "POSE"
    for o in mesh_objects():
        o.name = a["name"]
    print(f"  character rest bbox {hi.x - lo.x:.2f} x {hi.y - lo.y:.2f} x {hi.z - lo.z:.2f} (scale x{f:.3f})")


def export(a):
    out = rp(a["output"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    is_char = a["kind"] == "character"
    kw = dict(filepath=out, export_format="GLB", export_image_format="JPEG", export_jpeg_quality=88,
              export_animations=is_char, export_skins=is_char)
    if is_char:
        kw.update(export_animation_mode="NLA_TRACKS", export_force_sampling=True, export_def_bones=False)
    bpy.ops.export_scene.gltf(**kw)
    return out


def run(a):
    print(f"[process] {a['name']} ({a['kind']}) <- {a['input']}")
    reset()
    import_any(rp(a["input"]))
    if a["kind"] == "character":
        process_character(a)
        obs = mesh_objects()
    else:
        ob = join_static()
        if a.get("decimate_tris"):
            tris = tri_count([ob])
            ratio = min(1.0, a["decimate_tris"] / max(1, tris))
            mod = ob.modifiers.new("dec", "DECIMATE")
            mod.ratio = ratio
            mod.use_collapse_triangulate = True
            bpy.ops.object.modifier_apply(modifier=mod.name)
            print(f"  decimate {tris} -> {tri_count([ob])} tris (ratio {ratio:.4f})")
        if a["kind"] == "weapon":
            process_weapon(a, ob)
        else:
            process_static(a, ob)
        suffix = {"trimesh": "-col", "convex": "-convcol"}.get(a.get("collision") or "", "")
        ob.name = a["name"] + suffix
        ob.data.name = a["name"]
        obs = [ob]
    rename_and_downscale(a["name"], a.get("texture_max", 2048))
    lo, hi = world_bbox(obs)
    out = export(a)
    mb = os.path.getsize(out) / 1e6
    print(f"[done] {a['name']}: size {hi.x - lo.x:.3f} x {hi.y - lo.y:.3f} x {hi.z - lo.z:.3f} m (Blender XYZ; Z=up), "
          f"tris {tri_count(obs)}, {mb:.2f} MB -> {a['output']}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", default=os.path.join(HERE, "manifest.json"))
    ap.add_argument("--only", nargs="*")
    args = ap.parse_args(argv)
    man = json.load(open(args.manifest))
    for a in man["assets"]:
        if args.only and a["name"] not in args.only:
            continue
        if a.get("procedural"):
            continue
        run(a)


if __name__ == "__main__":
    main()
