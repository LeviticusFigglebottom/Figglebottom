"""Far LOD for a Forest hero mesh: decimate to a triangle budget and shrink
its textures, written next to it as <name>_far.glb (Forest swaps to it past
Forest.NEAR). Run after blender_process.py.
usage: $BPY tools/art/forest_lod.py -- assets/models/forest/tr_pine_a.glb 1500 512
"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, target, tex = args[0], int(args[1]), int(args[2])
out = src[:-4] + "_far.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obs = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.ops.object.select_all(action="DESELECT")
for o in obs:
    o.select_set(True)
bpy.context.view_layer.objects.active = obs[0]
if len(obs) > 1:
    bpy.ops.object.join()
ob = bpy.context.view_layer.objects.active
tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
m = ob.modifiers.new("d", "DECIMATE")
m.ratio = min(1.0, target / max(tris, 1))
m.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="d")
for img in bpy.data.images:
    if img.size[0] > tex:
        img.scale(tex, tex)
print("[lod]", src, tris, "->", sum(len(p.vertices) - 2 for p in ob.data.polygons), "->", out)
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG")
