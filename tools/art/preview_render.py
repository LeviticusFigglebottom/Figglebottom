"""Render a 4-view contact sheet of a model (front, left, back, 3/4) for review.

usage: $BPY tools/art/preview_render.py in.(glb|fbx) out.png [--engine workbench|cycles] [--size 512]
Prints the bounding box size, tri count and material count so the reviewer can
sanity-check scale and budget before spending more credits.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from blender_common import import_any, mesh_objects, world_bbox  # noqa: E402


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--engine", default="cycles")
    ap.add_argument("--size", type=int, default=512)
    a = ap.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    import_any(a.inp)
    obs = mesh_objects()
    lo, hi = world_bbox(obs)
    size = hi - lo
    ctr = (lo + hi) / 2
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in obs)
    mats = {s.material.name for o in obs for s in o.material_slots if s.material}
    print(f"[preview] bbox {size.x:.3f} x {size.y:.3f} x {size.z:.3f} (blender XYZ, Z up)  tris={tris}  mats={len(mats)}")

    sc = bpy.context.scene
    if a.engine == "cycles":
        sc.render.engine = "CYCLES"
        sc.cycles.samples = 24
        sc.cycles.device = "CPU"
        sc.cycles.use_denoising = False
    else:
        sc.render.engine = "BLENDER_WORKBENCH"
        sc.display.shading.color_type = "TEXTURE"
        sc.display.shading.light = "STUDIO"
    sc.render.resolution_x = a.size
    sc.render.resolution_y = a.size
    sc.render.film_transparent = False
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.55, 0.58, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.2
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    sc.collection.objects.link(sun)

    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = max(size.x, size.y, size.z) * 1.15
    sc.collection.objects.link(cam)
    sc.camera = cam
    dist = max(size) * 3 + 1
    tiles = []
    # glTF/Godot front (+Z forward) is Blender -Y; looking from -Y shows the front.
    for i, yaw in enumerate((0, 90, 180, 45)):
        r = math.radians(yaw)
        d = Vector((math.sin(r), -math.cos(r), 0.25 if yaw == 45 else 0.0)).normalized()
        cam.location = ctr + d * dist
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        p = a.out + f".{i}.png"
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        tiles.append(p)
    # stitch with Blender images (no PIL in the bpy env)
    import numpy as np
    arrs = []
    for p in tiles:
        im = bpy.data.images.load(p)
        px = np.array(im.pixels[:]).reshape(im.size[1], im.size[0], 4)
        arrs.append(px)
        os.remove(p)
    sheet = np.concatenate(arrs, axis=1)
    out = bpy.data.images.new("sheet", sheet.shape[1], sheet.shape[0])
    out.pixels.foreach_set(sheet.astype(np.float32).ravel())
    out.filepath_raw = a.out
    out.file_format = "PNG"
    out.save()
    print(f"[preview] wrote {a.out}")


if __name__ == "__main__":
    main()
