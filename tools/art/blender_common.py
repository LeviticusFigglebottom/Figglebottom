"""Shared Blender helpers for the Rimeholt art pipeline (bpy 4.5 wheel, headless)."""
import os

import bpy
from mathutils import Vector


class _StubOp:
    """io_scene_fbx.import_fbx.load() wants an operator for report(); headless we fake one."""

    def report(self, kind, msg):
        print(f"[fbx] {kind}: {msg}")


def import_any(path):
    ext = os.path.splitext(path)[1].lower()
    with open(path, "rb") as f:
        magic = f.read(4)
    # Studio serves clips of non-remeshed (imported) projects as GLB whatever the name says
    if ext in (".glb", ".gltf") or magic == b"glTF":
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        # The bpy.ops FBX operator can fail headless (no window context), so call the
        # loader directly. Tripo FBX uses cm units and -Y forward. Default axes are fine,
        # and scale is normalised later from the manifest target size anyway.
        import io_scene_fbx.import_fbx as imp
        imp.load(_StubOp(), bpy.context, filepath=path, use_anim=True, ignore_leaf_bones=False,
                 automatic_bone_orientation=False, use_image_search=True)
    else:
        raise SystemExit(f"unsupported: {path}")


def mesh_objects():
    return [o for o in bpy.context.scene.objects if o.type == "MESH"]


def world_bbox(obs):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    dg = bpy.context.evaluated_depsgraph_get()
    for o in obs:
        oe = o.evaluated_get(dg)
        me = oe.to_mesh()
        mw = o.matrix_world
        for v in me.vertices:
            p = mw @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
        oe.to_mesh_clear()
    return lo, hi
