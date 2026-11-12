#!/usr/bin/env python3
"""World meshes for the things picked up at the points of interest in Kettle
Fjord, Tarnhall and the Coldwell (docs/lore/POI.md 4, 5, 8): small scenes of
primitives, like the other keepsakes in assets/models/props/.

Each part is (mesh, params, material, position, rotation in degrees).
Run: python3 tools/gen_poi_props_b.py"""
import math
import os

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "models", "props")

ASH = ("ash", (0.56, 0.47, 0.34), 0.8)
IRON = ("iron", (0.20, 0.19, 0.19), 0.6)
TAR = ("tarred", (0.13, 0.11, 0.09), 0.85)
BOARD = ("board", (0.42, 0.33, 0.22), 0.85)
SEAL = ("sealskin", (0.46, 0.43, 0.38), 0.8)
STRAP = ("strap", (0.30, 0.20, 0.12), 0.7)
LINEN = ("linen", (0.78, 0.74, 0.64), 0.95)

SYCAMORE = ("sycamore", (0.66, 0.58, 0.44), 0.7)
DARK_IN = ("stained", (0.30, 0.22, 0.14), 0.8)
STEM = ("stem", (0.30, 0.42, 0.18), 0.8)
MARIGOLD = ("marigold", (0.89, 0.73, 0.23), 0.7)
SMOCK = ("smock", (0.78, 0.68, 0.86), 0.7)

SCENES = {
    # an ash pole shod with iron, leaning at the picket stake
    "sounding_pole": ("SoundingPole", 14, [
        ("cyl", (0.016, 0.02, 2.2), ASH, (0, 1.1, 0), (0, 0, 0)),
        ("cyl", (0.022, 0.012, 0.16), IRON, (0, 0.08, 0), (0, 0, 0)),
        ("cyl", (0.021, 0.021, 0.2), TAR, (0, 1.5, 0), (0, 0, 0)),
    ]),
    # a notched board wound with tarred line, the hook bent out of a nail
    "line_winder": ("LineWinder", 0, [
        ("box", (0.1, 0.02, 0.3), BOARD, (0, 0.03, 0), (0, 20, 0)),
        ("box", (0.108, 0.036, 0.19), TAR, (0, 0.03, 0), (0, 20, 0)),
        ("cyl", (0.004, 0.004, 0.05), IRON, (0.05, 0.05, 0.12), (0, 0, 60)),
    ]),
    # a sealskin pack done up with three straps, a roll of linen under the flap
    "healer_pack": ("HealerPack", 0, [
        ("caps", (0.17, 0.52), SEAL, (0, 0.17, 0), (0, 0, 90)),
        ("cyl", (0.176, 0.176, 0.035), STRAP, (-0.15, 0.17, 0), (0, 0, 90)),
        ("cyl", (0.176, 0.176, 0.035), STRAP, (0.0, 0.17, 0), (0, 0, 90)),
        ("cyl", (0.176, 0.176, 0.035), STRAP, (0.15, 0.17, 0), (0, 0, 90)),
        ("cyl", (0.05, 0.05, 0.3), LINEN, (0, 0.35, 0.02), (0, 0, 90)),
    ]),
    # a long-handled sycamore dipper, its lip worn flat on one side
    "vat_dipper": ("VatDipper", 0, [
        ("cyl", (0.012, 0.014, 0.9), SYCAMORE, (0, 0.03, 0), (0, 0, 90)),
        ("cyl", (0.075, 0.06, 0.08), SYCAMORE, (0.5, 0.05, 0), (0, 0, 0)),
        ("cyl", (0.066, 0.052, 0.01), DARK_IN, (0.5, 0.088, 0), (0, 0, 0)),
    ]),
    # marsh marigold and lady's smock tied with a stem of grass (the modelled bunch, laid down)
    "melt_flowers": ("MeltFlowers", 0, [
        ("cyl", (0.03, 0.012, 0.24), STEM, (0, 0.03, 0), (0, 0, 78)),
        ("sph", (0.045,), MARIGOLD, (0.13, 0.06, 0.0), (0, 0, 0)),
        ("sph", (0.035,), MARIGOLD, (0.11, 0.05, 0.05), (0, 0, 0)),
        ("sph", (0.03,), SMOCK, (0.12, 0.05, -0.05), (0, 0, 0)),
    ]),
}


def mesh_res(kind, p):
    if kind == "cyl":
        return "CylinderMesh", "top_radius = %g\nbottom_radius = %g\nheight = %g\nradial_segments = 8\n" % p
    if kind == "box":
        return "BoxMesh", "size = Vector3(%g, %g, %g)\n" % p
    if kind == "caps":
        return "CapsuleMesh", "radius = %g\nheight = %g\nradial_segments = 10\n" % p
    if kind == "sph":
        return "SphereMesh", "radius = %g\nheight = %g\nradial_segments = 8\nrings = 4\n" % (p[0], p[0] * 2)
    raise ValueError(kind)


def basis(rx, ry, rz):
    """Godot's YXZ Euler order, as nine numbers row-major."""
    cx, sx = math.cos(math.radians(rx)), math.sin(math.radians(rx))
    cy, sy = math.cos(math.radians(ry)), math.sin(math.radians(ry))
    cz, sz = math.cos(math.radians(rz)), math.sin(math.radians(rz))
    mx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    my = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    mz = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]

    def mul(a, b):
        return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    m = mul(my, mul(mx, mz))
    return [m[i][j] for i in range(3) for j in range(3)]


def write(fname, root, lean, parts):
    mats = {}
    for _k, _p, m, _pos, _rot in parts:
        mats[m[0]] = m
    out = ["[gd_scene load_steps=%d format=3]\n" % (len(mats) + len(parts) + 1)]
    for name, col, rough in mats.values():
        out.append('[sub_resource type="StandardMaterial3D" id="%s"]\nalbedo_color = Color(%.3f, %.3f, %.3f, 1)\nroughness = %g\n'
                   % (name, col[0], col[1], col[2], rough))
    for i, (kind, p, m, _pos, _rot) in enumerate(parts):
        typ, body = mesh_res(kind, p)
        out.append('[sub_resource type="%s" id="m%d"]\n%smaterial = SubResource("%s")\n' % (typ, i, body, m[0]))
    out.append('[node name="%s" type="Node3D"]\n' % root)
    # the whole thing leans (a pole against a stake) about its foot
    lb = basis(lean, 0, 0)
    out.append('[node name="Body" type="Node3D" parent="."]\ntransform = Transform3D(%s, 0, 0, 0)\n' % ", ".join("%g" % round(v, 5) for v in lb))
    for i, (_kind, _p, _m, pos, rot) in enumerate(parts):
        b = basis(*rot)
        out.append('[node name="Part%d" type="MeshInstance3D" parent="Body"]\ntransform = Transform3D(%s, %g, %g, %g)\nmesh = SubResource("m%d")\n'
                   % (i, ", ".join("%g" % round(v, 5) for v in b), pos[0], pos[1], pos[2], i))
    with open(os.path.join(OUT, fname + ".tscn"), "w") as f:
        f.write("\n".join(out))
    print("wrote", fname + ".tscn")


def write_mirrored(fname, root, source):
    """The pair of an existing keepsake's mesh, mirrored (POI.md 5.2: the rowan stick)."""
    with open(os.path.join(OUT, fname + ".tscn"), "w") as f:
        f.write('[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="res://assets/models/props/%s.tscn" id="1"]\n\n'
                '[node name="%s" type="Node3D"]\n\n[node name="Pair" parent="." instance=ExtResource("1")]\n'
                'transform = Transform3D(-1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0)\n' % (source, root))
    print("wrote", fname + ".tscn")


if __name__ == "__main__":
    write_mirrored("rowan_stick", "RowanStick", "ottar_stick")
    for fname, (root, lean, parts) in SCENES.items():
        write(fname, root, lean, parts)
