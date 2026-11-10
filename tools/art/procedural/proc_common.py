"""Shared helpers for the Blender-modelled procedural assets (look pass 5).

A MeshBuf collects triangles with UVs in plain Python; `export_glb` turns one
into a Blender mesh with a textured Principled material (base colour, normal,
glTF occlusion/roughness/metal) and writes a GLB with the JPEGs embedded, so
MaterialLib.hero_mat picks the maps up exactly as it does for a Tripo mesh.

Blender is Z-up; the exporter converts to Godot's Y-up. "Along X" here is
along X in the game too.
"""
import math
import os

import bpy
import numpy as np
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TEX = os.path.join(ROOT, "assets", "textures")
TMP = os.path.join(ROOT, "raw", "proc_tmp")


class MeshBuf:
    def __init__(self):
        self.v = []      # (x, y, z)
        self.uv = []     # (u, v) per vertex
        self.f = []      # (a, b, c)

    def vert(self, p, uv):
        self.v.append((float(p[0]), float(p[1]), float(p[2])))
        self.uv.append((float(uv[0]), float(uv[1])))
        return len(self.v) - 1

    def tri(self, a, b, c):
        self.f.append((a, b, c))

    def quad(self, a, b, c, d):
        self.f.append((a, b, c))
        self.f.append((a, c, d))

    def tris(self):
        return len(self.f)

    def merge(self, other, xf=None):
        """Append another buffer, optionally through a 4x4 numpy transform."""
        base = len(self.v)
        if xf is None:
            self.v.extend(other.v)
        else:
            pts = np.array(other.v, dtype=float)
            pts = pts @ xf[:3, :3].T + xf[:3, 3]
            self.v.extend(map(tuple, pts))
        self.uv.extend(other.uv)
        flip = xf is not None and np.linalg.det(xf[:3, :3]) < 0
        for a, b, c in other.f:
            self.f.append((a + base, c + base, b + base) if flip else (a + base, b + base, c + base))


def xform(pos=(0, 0, 0), rot_z=0.0, rot_x=0.0, rot_y=0.0, scale=(1, 1, 1)):
    cz, sz = math.cos(rot_z), math.sin(rot_z)
    cx, sx = math.cos(rot_x), math.sin(rot_x)
    cy, sy = math.cos(rot_y), math.sin(rot_y)
    rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])
    ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]])
    m = np.eye(4)
    m[:3, :3] = rz @ ry @ rx @ np.diag(scale)
    m[:3, 3] = pos
    return m


def frames(pts):
    """Parallel-transport frames (tangent, normal, binormal) down a polyline."""
    pts = np.asarray(pts, dtype=float)
    n = len(pts)
    t = np.zeros_like(pts)
    t[1:-1] = pts[2:] - pts[:-2]
    t[0] = pts[1] - pts[0]
    t[-1] = pts[-1] - pts[-2]
    t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-9)
    ref = np.array([0.0, 0.0, 1.0]) if abs(t[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    nrm = np.cross(t[0], ref)
    nrm /= np.linalg.norm(nrm)
    out_n = [nrm]
    for i in range(1, n):
        v = out_n[-1] - t[i] * np.dot(out_n[-1], t[i])
        ln = np.linalg.norm(v)
        v = v / ln if ln > 1e-6 else out_n[-1]
        out_n.append(v)
    out_n = np.array(out_n)
    return t, out_n, np.cross(t, out_n)


def tube(buf, pts, radii, sides, u0, u1, v_per_m, v0=0.0, cap_end=True, squash=None):
    """A tapered tube down a polyline. u0..u1 is the strip of the atlas wrapped
    once round it; v runs along the length in repeats per metre. `squash`
    (per-point (a, b) radius factors) makes the section oval."""
    pts = np.asarray(pts, dtype=float)
    t, nn, bb = frames(pts)
    rings = []
    v = v0
    for i in range(len(pts)):
        if i > 0:
            v += np.linalg.norm(pts[i] - pts[i - 1]) * v_per_m
        ring = []
        sa, sb = (1.0, 1.0) if squash is None else squash[i]
        for k in range(sides + 1):
            a = TAU * k / sides
            p = pts[i] + radii[i] * (math.cos(a) * nn[i] * sa + math.sin(a) * bb[i] * sb)
            ring.append(buf.vert(p, (u0 + (u1 - u0) * k / sides, v)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(sides):
            buf.quad(rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k])
    if cap_end:
        tip = buf.vert(pts[-1] + t[-1] * radii[-1] * 0.6, ((u0 + u1) * 0.5, v + radii[-1] * v_per_m))
        for k in range(sides):
            buf.tri(rings[-1][k], rings[-1][k + 1], tip)
    return v


def cap(buf, centre, normal, radius, sides, uv_c, uv_r, squash=(1.0, 1.0), ref=None):
    """A flat end disc (sawn log ends, lids): a fan mapped as a disc in UV."""
    normal = np.asarray(normal, dtype=float)
    normal = normal / np.linalg.norm(normal)
    if ref is None:
        ref = np.array([0.0, 0.0, 1.0]) if abs(normal[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    a1 = np.cross(normal, ref)
    a1 /= np.linalg.norm(a1)
    a2 = np.cross(normal, a1)
    c = buf.vert(centre, uv_c)
    ring = []
    for k in range(sides + 1):
        a = TAU * k / sides
        p = np.asarray(centre) + radius * (math.cos(a) * a1 * squash[0] + math.sin(a) * a2 * squash[1])
        ring.append(buf.vert(p, (uv_c[0] + uv_r * math.cos(a), uv_c[1] + uv_r * math.sin(a))))
    for k in range(sides):
        buf.tri(c, ring[k], ring[k + 1])


def box(buf, size, xf, uv_rect, uv_per_m=None, jitter=None, rng=None):
    """A box about its centre with per-face planar UVs inside `uv_rect`
    (u0, v0, u1, v1). With uv_per_m the faces map in metres from a random
    offset in the rect (V along the box's longest axis, so grain follows the
    board; V may run past the rect, the atlases tile in V) instead of
    stretching to it. `jitter` moves the corners: hand-cut timber and stone
    are never square. Edges are chamfered at export (export_glb bevel)."""
    rng = rng or np.random.default_rng(1)
    half = np.array(size, dtype=float) * 0.5
    corners = {}
    for ix in (-1, 1):
        for iy in (-1, 1):
            for iz in (-1, 1):
                j = rng.normal(0, jitter, 3) if jitter else np.zeros(3)
                corners[(ix, iy, iz)] = np.array([ix, iy, iz]) * half + j
    u0, v0, u1, v1 = uv_rect
    long_axis = int(np.argmax(size))
    for axis in range(3):
        a1, a2 = [a for a in range(3) if a != axis]
        if a1 == long_axis:
            a1, a2 = a2, a1
        for sign in (-1, 1):
            w, h = size[a1], size[a2]
            if uv_per_m:
                du = min(w * uv_per_m, u1 - u0)
                dv = h * uv_per_m
                ou = u0 + rng.random() * max((u1 - u0) - du, 0.0)
                ov = rng.random()
            else:
                du, dv, ou, ov = u1 - u0, v1 - v0, u0, v0
            idx = []
            ps = []
            for s1, s2 in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
                key = [0, 0, 0]
                key[axis], key[a1], key[a2] = sign, s1, s2
                p = corners[tuple(key)]
                ps.append(p)
                idx.append(buf.vert(xf[:3, :3] @ p + xf[:3, 3], (ou + du * (s1 * 0.5 + 0.5), ov + dv * (s2 * 0.5 + 0.5))))
            n = np.cross(ps[1] - ps[0], ps[2] - ps[0])
            if (n[axis] > 0) != (sign > 0):
                idx.reverse()
            if np.linalg.det(xf[:3, :3]) < 0:
                idx.reverse()
            buf.quad(*idx)


TAU = math.tau


def load_set(name, size=None, kinds=("albedo", "normal", "orh")):
    """A committed CC0 set (assets/textures/<name>) as float arrays 0..1."""
    out = {}
    for k in kinds:
        im = Image.open(os.path.join(TEX, name, "T_%s_%s.jpg" % (name, k))).convert("RGB")
        if size:
            im = im.resize((size, size), Image.LANCZOS)
        out[k] = np.asarray(im, dtype=np.float32) / 255.0
    return out


def orh_to_orm(orh, metal=0.0):
    """Our sets pack R = AO, G = roughness, B = height; glTF wants B = metal."""
    o = orh.copy()
    o[..., 2] = metal
    return o


def save_maps(name, albedo, normal, orm, quality=88):
    os.makedirs(TMP, exist_ok=True)
    paths = {}
    for k, arr in (("BaseColor", albedo), ("Normal", normal), ("ORM", orm)):
        p = os.path.join(TMP, "T_%s_%s.jpg" % (name, k))
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8)).save(p, quality=quality)
        paths[k] = p
    return paths


def half_maps(maps, size=512):
    """The same maps at a smaller size, for a far LOD."""
    out = {}
    for k, p in maps.items():
        q = p[:-4] + "_%d.jpg" % size
        Image.open(p).resize((size, size), Image.LANCZOS).save(q, quality=85)
        out[k] = q
    return out


def make_material(name, maps):
    mat = bpy.data.materials.new("M_" + name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]

    def img(key, colorspace):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(maps[key])
        n.image.colorspace_settings.name = colorspace
        return n

    nt.links.new(img("BaseColor", "sRGB").outputs["Color"], bsdf.inputs["Base Color"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(img("Normal", "Non-Color").outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(img("ORM", "Non-Color").outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    return mat


def export_glb(path, name, buf, maps, smooth=True, auto_smooth_deg=None, bevel=0.0):
    """Write `buf` as <path> (GLB, JPEG textures, tangents)."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    me = bpy.data.meshes.new(name)
    me.from_pydata(buf.v, [], buf.f)
    uvl = me.uv_layers.new(name="UVMap")
    loops = np.zeros(len(me.loops), dtype=np.int32)
    me.loops.foreach_get("vertex_index", loops)
    uv = np.array(buf.uv, dtype=np.float32)[loops]
    uvl.data.foreach_set("uv", uv.ravel())
    me.polygons.foreach_set("use_smooth", [smooth] * len(me.polygons))
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    if auto_smooth_deg is not None:
        # hard edges where faces meet sharply (boards, cut stone), smooth
        # elsewhere: weld coincident verts first so the angle test sees them
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=0.0004)
        bpy.ops.object.mode_set(mode="OBJECT")
        if bevel > 0.0:
            # one chamfer on every hard edge: a real corner catches a highlight
            m = ob.modifiers.new("b", "BEVEL")
            m.width = bevel
            m.segments = 1
            m.limit_method = "ANGLE"
            m.angle_limit = math.radians(auto_smooth_deg)
            bpy.ops.object.modifier_apply(modifier="b")
            t = ob.modifiers.new("t", "TRIANGULATE")   # tangents need tris
            bpy.ops.object.modifier_apply(modifier="t")
        bpy.ops.object.shade_auto_smooth(angle=math.radians(auto_smooth_deg))
    me.materials.append(make_material(name, maps))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", export_image_format="JPEG",
                              export_tangents=True, export_apply=True, export_yup=True)
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    print("[proc] %s  tris=%d  %.0f kB" % (os.path.relpath(path, ROOT), tris, os.path.getsize(path) / 1024))
    return tris


def lathe(buf, profile, segs, u0, u1, v_per_m=1.0, xf=None, squash=(1.0, 1.0)):
    """Spin a profile [(radius, z), ...] about Z. Winding faces outward when
    the profile runs bottom to top on the outside (and top to bottom inside)."""
    rings = []
    v = 0.0
    for i, (r, z) in enumerate(profile):
        if i > 0:
            v += math.hypot(r - profile[i - 1][0], z - profile[i - 1][1]) * v_per_m
        ring = []
        for k in range(segs + 1):
            a = TAU * k / segs
            p = np.array([math.cos(a) * r * squash[0], math.sin(a) * r * squash[1], z])
            if xf is not None:
                p = xf[:3, :3] @ p + xf[:3, 3]
            ring.append(buf.vert(p, (u0 + (u1 - u0) * k / segs, v)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(segs):
            buf.quad(rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k])


def blob(buf, rng, centre, radii, segs, rings, u0, u1, v0=0.0, v1=0.3, lump=0.12, xf=None):
    """A lumpy ellipsoid (loaves, floats, stones, charcoal)."""
    grid = []
    ph = rng.random(4) * TAU
    for j in range(rings + 1):
        lat = math.pi * (j / rings - 0.5)
        row = []
        for k in range(segs + 1):
            lon = TAU * (k % segs) / segs
            d = np.array([math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat)])
            w = 1.0 + lump * (math.sin(lon * 2 + ph[0]) * math.cos(lat * 3 + ph[1]) + 0.6 * math.sin(lon * 3 + ph[2] + lat * 2))
            p = np.asarray(centre) + d * np.asarray(radii) * w
            if xf is not None:
                p = xf[:3, :3] @ p + xf[:3, 3]
            row.append(buf.vert(p, (u0 + (u1 - u0) * k / segs, v0 + (v1 - v0) * j / rings)))
        grid.append(row)
    for j in range(rings):
        for k in range(segs):
            buf.quad(grid[j][k], grid[j][k + 1], grid[j + 1][k + 1], grid[j + 1][k])


def make_atlas(name, columns, size=1024):
    """Columns side by side, each `(set, fn)`: a committed CC0 set's maps
    cropped to the column, optionally passed through fn(albedo, orh) ->
    (albedo, orh) for a tint or a rough change. V tiles; U does not. Returns
    (maps, [(u0, u1), ...]) with the u ranges inset against mip bleed."""
    n = len(columns)
    w = size // n
    a = np.zeros((size, size, 3), np.float32)
    nm = np.zeros_like(a)
    o = np.zeros_like(a)
    cols = []
    cache = {}
    for i, (sname, fn) in enumerate(columns):
        if sname not in cache:
            cache[sname] = load_set(sname, size)
        s = cache[sname]
        x0 = (i * 97) % (size - w)     # a different strip of the photo for each column
        alb, orh, nrm = s["albedo"][:, x0:x0 + w].copy(), s["orh"][:, x0:x0 + w].copy(), s["normal"][:, x0:x0 + w]
        if fn is not None:
            alb, orh = fn(alb, orh)
        a[:, i * w:(i + 1) * w] = alb
        nm[:, i * w:(i + 1) * w] = nrm
        o[:, i * w:(i + 1) * w] = orh
        pad = 6.0 / size
        cols.append((i / n + pad, (i + 1) / n - pad))
    return save_maps(name, a, nm, orh_to_orm(o)), cols


def tint(rgb, gain=1.0, rough=None, keep=0.35):
    """Column op: pull the photo's mean to `rgb`, keeping its detail."""
    def fn(alb, orh):
        mean = alb.reshape(-1, 3).mean(axis=0)
        detail = alb / np.maximum(mean, 1e-3)
        out = np.asarray(rgb, np.float32) * (1.0 + (detail - 1.0) * gain)
        out = out * (1 - keep) + alb * keep * (np.asarray(rgb, np.float32).mean() / max(mean.mean(), 1e-3))
        if rough is not None:
            orh = orh.copy()
            orh[..., 1] = np.clip(orh[..., 1] - orh[..., 1].mean() + rough, 0.05, 1.0)
        return np.clip(out, 0, 1), orh
    return fn
