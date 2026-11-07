"""Decimate a (decompressed) GLB to a triangle budget, keeping UVs and textures (max 2K).

Used when Tripo remesh fails on a model: the result is re-imported with tripo_import and rigged.
usage: $BPY tools/art/decimate_glb.py -- in.glb out.glb 40000
"""
import sys

import bpy

src, out, target = sys.argv[-3], sys.argv[-2], int(sys.argv[-1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in obs: o.select_set(True)
bpy.context.view_layer.objects.active = obs[0]
if len(obs) > 1: bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
m = ob.modifiers.new("d", "DECIMATE"); m.ratio = target / tris; m.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="d")
for img in bpy.data.images:
    if img.size[0] > 2048: img.scale(2048, 2048)
print("tris", tris, "->", sum(len(p.vertices) - 2 for p in ob.data.polygons))
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG")
