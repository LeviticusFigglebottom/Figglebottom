"""Procedural Rimeholt kit pieces (plain walls, dry-stone, racks).

Owner decision (pilot): Tripo is reserved for hero assets, so plain modular kit is
built here. It follows the same naming, grid and origin rules as Tripo pieces
(docs/art/STYLE.md, docs/art/design/pilot.md).

Look: each piece is bevelled boxes with per-part vertex-colour tints (COLOR_0).
That tint is multiplied by a small generated tiling detail texture (wood grain or
stone mottle). glTF multiplies baseColorTexture by COLOR_0, and Godot honours that,
so we get variation with no baking.

Run (deterministic, seeded):
  $BPY tools/art/procedural/kit_procedural.py --out assets/models/kit [--only kit_drystone_wall_4m]
where $BPY is a python with the bpy wheel (see tools/art/README.md).
"""
import argparse
import math
import os
import random
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix

# ---------------------------------------------------------------- helpers

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_lin(c):
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4) for x in c)


def make_detail_image(name, kind, size=512, seed=0):
    """Tileable grey detail map (values around 0.75-1.0 so tints stay readable)."""
    rng = np.random.default_rng(seed)

    def tile_noise(freq):
        # sum of random-phase sines on integer frequencies => seamless tiling
        y, x = np.mgrid[0:size, 0:size] / size * 2 * math.pi
        acc = np.zeros((size, size))
        for _ in range(6):
            fx, fy = rng.integers(1, freq + 1, 2)
            ph = rng.uniform(0, 2 * math.pi)
            acc += np.sin(fx * x + fy * y * rng.choice([-1, 1]) + ph) / (fx + fy)
        return acc

    if kind == "wood":
        y, x = np.mgrid[0:size, 0:size] / size * 2 * math.pi
        warp = tile_noise(3) * 1.5
        grain = np.sin(x * 24 + warp * 4) * 0.5 + 0.5          # vertical grain (along V)
        fine = np.sin(x * 97 + tile_noise(5) * 6) * 0.5 + 0.5
        v = 0.78 + 0.12 * grain + 0.07 * fine
    else:  # stone
        blot = tile_noise(4) + tile_noise(9) * 0.6 + tile_noise(17) * 0.3
        blot = (blot - blot.min()) / (np.ptp(blot) + 1e-6)
        speck = rng.random((size, size)) * 0.06
        v = 0.72 + 0.24 * blot + speck
    v = np.clip(v, 0, 1)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = v
    img = bpy.data.images.new(name, size, size, alpha=False)
    img.pixels.foreach_set(rgba.ravel())
    img.file_format = "PNG"
    img.pack()
    return img


def make_material(name, img, roughness):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    mul = nt.nodes.new("ShaderNodeMix")
    mul.data_type = "RGBA"
    mul.blend_type = "MULTIPLY"
    mul.inputs["Factor"].default_value = 1.0
    nt.links.new(tex.outputs["Color"], mul.inputs[6])
    nt.links.new(vc.outputs["Color"], mul.inputs[7])
    nt.links.new(mul.outputs[2], bsdf.inputs["Base Color"])
    return m


class Builder:
    """Accumulates bevelled boxes into one bmesh with per-part colour and box UVs."""

    def __init__(self, uv_scale=1.0):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.uv_scale = uv_scale

    def box(self, size, loc, rot=(0, 0, 0), color=(1, 1, 1), bevel=0.02, jitter=0.0, rng=None, grain_axis=2, mat=0, taper=None):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
        if bevel > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=min(bevel, min(size) * 0.45),
                            segments=1, profile=0.5, affect="EDGES")
        if taper is not None:  # (bottom_scale_x, top_scale_x) across local z
            for v in tmp.verts:
                t = (v.co.z / size[2]) + 0.5
                v.co.x *= taper[0] + (taper[1] - taper[0]) * t
        if jitter > 0 and rng is not None:
            for v in tmp.verts:
                v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * jitter
        mat_r = Matrix.Rotation(rot[0], 4, "X") @ Matrix.Rotation(rot[1], 4, "Y") @ Matrix.Rotation(rot[2], 4, "Z")
        bmesh.ops.transform(tmp, matrix=Matrix.Translation(Vector(loc)) @ mat_r, verts=tmp.verts)
        lin = tuple(color) + (1.0,)  # bmesh byte-colour layer takes sRGB-ish values directly
        # copy into main bmesh
        vmap = {v: self.bm.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            nf = self.bm.faces.new([vmap[v] for v in f.verts])
            nf.material_index = mat
            nf.smooth = False
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            for l in nf.loops:
                l[self.col] = lin
                c = l.vert.co
                # box projection; keep grain running along grain_axis
                if ax == 0:
                    u, w = c.y, c.z
                elif ax == 1:
                    u, w = c.x, c.z
                else:
                    u, w = c.x, c.y
                if grain_axis == 0 and ax != 0:
                    u, w = w, c.x
                l[self.uv].uv = (u * self.uv_scale, w * self.uv_scale)
        tmp.free()

    def to_object(self, name, mats):
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for m in mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        return ob


def tint(rng, base, var):
    # luminance-led variation; tiny hue drift only (per-channel jitter reads as green/magenta)
    k = 1.0 + rng.uniform(-var, var) * 2.5
    return tuple(max(0, min(1, b * k + rng.uniform(-0.008, 0.008))) for b in base)


# ---------------------------------------------------------------- pieces
# Colours are sRGB, taken from the STYLE.md palette.
TIMBER = (0.42, 0.36, 0.30)       # brown-grey
TIMBER_SILVER = (0.55, 0.53, 0.50)
SCHIST = (0.45, 0.48, 0.43)       # grey-green
SCHIST_DARK = (0.33, 0.36, 0.33)
FISH = (0.70, 0.66, 0.58)


def build_longhouse_wall(rng):
    """4 m wide x 3 m tall stave wall: sill beam, split staves, head beam."""
    W, H, D = 4.0, 3.0, 0.25
    b = Builder(uv_scale=0.5)
    sill_h, head_h = 0.28, 0.24
    b.box((W, D, sill_h), (0, 0, sill_h / 2), color=tint(rng, TIMBER, 0.03), bevel=0.03, grain_axis=0)
    b.box((W, D * 0.95, head_h), (0, 0, H - head_h / 2), color=tint(rng, TIMBER, 0.03), bevel=0.03, grain_axis=0)
    # inner backing boards (wall lining): no daylight through stave joints
    b.box((W, 0.03, H - sill_h - head_h + 0.04), (0, 0.085, sill_h + (H - sill_h - head_h) / 2),
          color=tint(rng, TIMBER, 0.02), bevel=0.0)
    x = -W / 2
    while x < W / 2 - 1e-3:
        sw = min(rng.uniform(0.2, 0.3), W / 2 - x)
        th = rng.uniform(0.11, 0.16)
        cx = x + sw / 2
        weather = rng.random()
        col = tuple(TIMBER[i] * (1 - weather * 0.6) + TIMBER_SILVER[i] * weather * 0.6 for i in range(3))
        b.box((sw - 0.008, th, H - sill_h - head_h + 0.06), (cx, rng.uniform(-0.015, 0.015), sill_h + (H - sill_h - head_h) / 2),
              rot=(0, rng.uniform(-0.006, 0.006), 0), color=tint(rng, col, 0.04), bevel=0.02, jitter=0.004, rng=rng)
        x += sw
    # wooden pegs through the head beam and sill (both faces)
    for px in np.arange(-W / 2 + 0.5, W / 2, 1.0):
        for z in (sill_h / 2, H - head_h / 2):
            b.box((0.05, D + 0.04, 0.05), (px, 0, z), color=tint(rng, TIMBER, 0.05), bevel=0.01)
    return b


def build_drystone_wall(rng):
    """4 m wide x 1.4 m tall battered dry-stone wall with on-edge capstones."""
    W, H = 4.0, 1.4
    base_d, top_d = 0.75, 0.48
    cap_h = 0.22
    b = Builder(uv_scale=1.0)
    # hearting core (hidden) so there are no see-through gaps
    b.box((W, top_d * 0.8, H - cap_h), (0, 0, (H - cap_h) / 2), color=SCHIST_DARK, bevel=0.0)
    z = 0.0
    course = 0
    while z < H - cap_h - 0.05:
        ch = rng.uniform(0.11, 0.19)
        ch = min(ch, H - cap_h - z)
        t = (z + ch / 2) / (H - cap_h)
        d = base_d + (top_d - base_d) * t
        for side in (-1, 1):
            x = -W / 2 + (rng.uniform(0, 0.25) if course % 2 else 0)
            if course % 2:  # stagger joints; fill the start
                b.box((x + W / 2 + 0.02, 0.25, ch), ((x - W / 2) / 2, side * (d / 2 - 0.12), z + ch / 2),
                      color=tint(rng, SCHIST, 0.06), bevel=0.03, jitter=0.01, rng=rng)
            while x < W / 2 - 0.02:
                sl = min(rng.uniform(0.28, 0.6), W / 2 - x)
                sd = rng.uniform(0.22, 0.32)
                col = tint(rng, SCHIST if rng.random() > 0.3 else SCHIST_DARK, 0.06)
                b.box((sl - 0.02, sd, ch - 0.012), (x + sl / 2, side * (d / 2 - sd / 2 + rng.uniform(-0.015, 0.015)), z + ch / 2),
                      rot=(side * 0.08, rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03)),
                      color=col, bevel=0.035, jitter=0.012, rng=rng)
                x += sl
        z += ch
        course += 1
    # capstones set on edge
    x = -W / 2
    while x < W / 2 - 0.02:
        ct = min(rng.uniform(0.09, 0.15), W / 2 - x)
        hh = cap_h + rng.uniform(-0.04, 0.05)
        b.box((ct - 0.01, top_d + rng.uniform(-0.05, 0.08), hh), (x + ct / 2, 0, z + hh / 2 - 0.02),
              rot=(0, rng.uniform(-0.12, 0.12), rng.uniform(-0.05, 0.05)),
              color=tint(rng, SCHIST, 0.07), bevel=0.025, jitter=0.01, rng=rng)
        x += ct
    return b


def build_drying_rack(rng):
    """3 m fish-drying rack: two A-frames, ridge pole, two hanging poles of split fish."""
    W, H = 3.0, 2.2
    b = Builder(uv_scale=0.5)
    leg = 2.35
    spread = 0.55
    ang = math.asin(spread / leg)
    for ex in (-W / 2 + 0.12, W / 2 - 0.12):
        for s in (-1, 1):
            b.box((0.09, 0.09, leg), (ex, s * spread / 2, leg * math.cos(ang) / 2), rot=(s * ang, 0, 0),
                  color=tint(rng, TIMBER, 0.05), bevel=0.02, jitter=0.006, rng=rng)
        # lashing collar
        b.box((0.13, 0.13, 0.08), (ex, 0, H - 0.02), color=(0.55, 0.47, 0.35), bevel=0.02)
    b.box((W + 0.2, 0.08, 0.08), (0, 0, H), color=tint(rng, TIMBER_SILVER, 0.05), bevel=0.02, grain_axis=0)
    for s in (-1, 1):
        y = s * 0.33
        zp = 1.45
        b.box((W - 0.1, 0.06, 0.06), (0, y, zp), color=tint(rng, TIMBER_SILVER, 0.05), bevel=0.015, grain_axis=0)
        x = -W / 2 + 0.35
        while x < W / 2 - 0.3:
            fl = rng.uniform(0.42, 0.6)
            b.box((0.012, 0.012, 0.12), (x, y, zp - 0.07), color=(0.6, 0.55, 0.42), bevel=0.0)  # twine
            # split fish: flattened pair + tail
            # stockfish hang tail-up: narrow tail wrist at the top, broad head end below
            b.box((0.13, 0.03, fl), (x, y, zp - 0.16 - fl / 2), rot=(rng.uniform(-0.05, 0.05), 0, rng.uniform(-0.12, 0.12)),
                  color=tint(rng, FISH, 0.05), bevel=0.012, jitter=0.004, rng=rng, mat=1, taper=(1.0, 0.25))
            # forked tail fin above the wrist
            for side in (-1, 1):
                b.box((0.06, 0.01, 0.08), (x + side * 0.03, y, zp - 0.12), rot=(0, side * 0.5, 0),
                      color=tint(rng, FISH, 0.04), bevel=0.0, mat=1, taper=(0.3, 1.0))
            x += rng.uniform(0.16, 0.22)
    return b


PIECES = {
    "kit_longhouse_wall_4m": (build_longhouse_wall, [("wood", 0.85)]),
    "kit_drystone_wall_4m": (build_drystone_wall, [("stone", 0.92)]),
    "kit_drying_rack": (build_drying_rack, [("wood", 0.85), ("stone", 0.6)]),
}


def bake_single_material(ob, name, size=1024, roughness=0.88):
    """Bake (vertex tint x detail texture) into one texture on a fresh UV unwrap.

    Godot's glTF importer ignores COLOR_0 for albedo, so tints must live in the texture.
    It also leaves each piece with one material, so one draw call.
    """
    me = ob.data
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    uv_bake = me.uv_layers.new(name="bake")
    me.uv_layers.active = uv_bake
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new(f"T_{name}", size, size, alpha=False)
    for m in me.materials:
        nt = m.node_tree
        # detail texture must keep reading the box-projected UVs
        uvn = nt.nodes.new("ShaderNodeUVMap")
        uvn.uv_map = "UVMap"
        for n in nt.nodes:
            if n.type == "TEX_IMAGE":
                nt.links.new(uvn.outputs["UV"], n.inputs["Vector"])
        mix = [n for n in nt.nodes if n.type == "MIX"][0]
        em = nt.nodes.new("ShaderNodeEmission")
        nt.links.new(mix.outputs[2], em.inputs["Color"])
        out = nt.nodes["Material Output"]
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        nt.nodes.active = tn
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 1
    sc.render.bake.margin = 4
    bpy.ops.object.bake(type="EMIT")
    img.pack()
    # replace with one plain PBR material on the bake UVs
    final = bpy.data.materials.new(f"M_{name}")
    final.use_nodes = True
    bsdf = final.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    t = final.node_tree.nodes.new("ShaderNodeTexImage")
    t.image = img
    final.node_tree.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    for poly in me.polygons:
        poly.material_index = 0
    me.materials.clear()
    me.materials.append(final)
    me.uv_layers.remove(me.uv_layers["UVMap"])
    me.uv_layers["bake"].name = "UVMap"
    for a in list(me.color_attributes):
        me.color_attributes.remove(a)
    return img


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default=None)
    ap.add_argument("--seed", type=int, default=7)
    a = ap.parse_args(argv)
    os.makedirs(a.out, exist_ok=True)
    for name, (fn, mat_kinds) in PIECES.items():
        if a.only and name != a.only:
            continue
        reset()
        rng = random.Random(f"{a.seed}:{name}")
        mats = []
        for i, (kind, rough) in enumerate(mat_kinds):
            img = make_detail_image(f"T_{name}_{i}", kind, seed=a.seed + i)
            mats.append(make_material(f"M_{name}" + (f"_{i}" if i else ""), img, rough))
        b = fn(rng)
        # node suffix tells Godot's importer to build collision (see tools/art/godot_import.md)
        suffix = "-col" if "wall" in name else "-convcol"
        ob = b.to_object(name + suffix, mats)
        ob.data.name = name
        bake_single_material(ob, name, size=1024)
        # origin is already bottom centre (all parts built from z=0, centred on x/y)
        path = os.path.join(a.out, name + ".glb")
        bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_vertex_color="NONE", export_image_format="JPEG", export_jpeg_quality=90)
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        dims = ob.dimensions
        print(f"[kit] {name}: {dims.x:.2f} x {dims.z:.2f} (h) x {dims.y:.2f} m, {tris} tris -> {path}")


if __name__ == "__main__":
    main()
