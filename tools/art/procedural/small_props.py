#!/usr/bin/env python3
"""Small release-drop props built from Godot primitives, written as .tscn
scenes (no Tripo spend for a hand-sized object). Each scene's long axis is +Y
and its flat side faces +X, because Pickup lays a display scene on its side
(rotation z 90): the long axis then lies along the ground, the flat side up.

    assets/models/props/tally_stick.tscn   Arne's tally-stick (LOWE.md 9)
    assets/models/props/ivo_mitten.tscn    Ivo's mitten (KETTLE.md 8)

Run: python3 tools/art/procedural/small_props.py"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "props")


def scene(name, resources, nodes):
    """resources: [(id, type, {prop: value})]; nodes: [(name, type, parent, {prop: value})]."""
    lines = ["[gd_scene load_steps=%d format=3]" % (len(resources) + 1), ""]
    for rid, rtype, props in resources:
        lines.append('[sub_resource type="%s" id="%s"]' % (rtype, rid))
        for k, v in props.items():
            lines.append("%s = %s" % (k, v))
        lines.append("")
    for nname, ntype, parent, props in nodes:
        head = '[node name="%s" type="%s"' % (nname, ntype)
        if parent is not None:
            head += ' parent="%s"' % parent
        lines.append(head + "]")
        for k, v in props.items():
            lines.append("%s = %s" % (k, v))
        lines.append("")
    path = os.path.join(OUT, name + ".tscn")
    open(path, "w").write("\n".join(lines))
    print("wrote", path)


def mat(rid, r, g, b, rough=0.85):
    return (rid, "StandardMaterial3D", {"albedo_color": "Color(%.3f, %.3f, %.3f, 1)" % (r, g, b), "roughness": rough})


def xf(sx=1.0, sy=1.0, sz=1.0, x=0.0, y=0.0, z=0.0):
    return "Transform3D(%g, 0, 0, 0, %g, 0, 0, 0, %g, %g, %g, %g)" % (sx, sy, sz, x, y, z)


# the tally-stick: a hazel rod, notched down both edges; the last two notches
# side by side and shallow (cut halfway)
res = [mat("hazel", 0.55, 0.42, 0.28), mat("cut", 0.22, 0.15, 0.09),
       ("rod", "CylinderMesh", {"top_radius": 0.022, "bottom_radius": 0.026, "height": 0.72,
                                "radial_segments": 8, "material": 'SubResource("hazel")'}),
       ("notch", "BoxMesh", {"size": "Vector3(0.05, 0.008, 0.02)", "material": 'SubResource("cut")'}),
       ("half", "BoxMesh", {"size": "Vector3(0.05, 0.008, 0.01)", "material": 'SubResource("cut")'})]
nodes = [("TallyStick", "Node3D", None, {}),
         ("Rod", "MeshInstance3D", ".", {"transform": xf(y=0.36), "mesh": 'SubResource("rod")'})]
for i in range(18):
    y = 0.06 + i * 0.03
    nodes.append(("N%d" % i, "MeshInstance3D", ".", {"transform": xf(x=0.0, y=y, z=0.022 if i % 2 else -0.022),
                                                     "mesh": 'SubResource("notch")'}))
for i, y in enumerate((0.64, 0.665)):
    nodes.append(("Half%d" % i, "MeshInstance3D", ".", {"transform": xf(y=y, z=0.026), "mesh": 'SubResource("half")'}))
scene("tally_stick", res, nodes)

# the mitten: felted grey wool, a leather palm, the thumb darned in another grey
res = [mat("wool", 0.52, 0.53, 0.55, 0.95), mat("darn", 0.38, 0.39, 0.42, 0.95), mat("leather", 0.36, 0.25, 0.16, 0.7),
       ("hand", "CapsuleMesh", {"radius": 0.065, "height": 0.24, "material": 'SubResource("wool")'}),
       ("thumb", "CapsuleMesh", {"radius": 0.026, "height": 0.1, "material": 'SubResource("darn")'}),
       ("palm", "BoxMesh", {"size": "Vector3(0.01, 0.12, 0.09)", "material": 'SubResource("leather")'}),
       ("cuff", "CylinderMesh", {"top_radius": 0.07, "bottom_radius": 0.07, "height": 0.04, "material": 'SubResource("wool")'})]
nodes = [("Mitten", "Node3D", None, {}),
         ("Hand", "MeshInstance3D", ".", {"transform": xf(0.45, 1, 1, y=0.14), "mesh": 'SubResource("hand")'}),
         ("Palm", "MeshInstance3D", ".", {"transform": xf(x=0.03, y=0.12), "mesh": 'SubResource("palm")'}),
         ("Thumb", "MeshInstance3D", ".",
          {"transform": "Transform3D(0.5, 0, 0, 0, 0.82, -0.57, 0, 0.57, 0.82, 0, 0.12, 0.07)", "mesh": 'SubResource("thumb")'}),
         ("Cuff", "MeshInstance3D", ".", {"transform": xf(0.5, 1, 1, y=0.02), "mesh": 'SubResource("cuff")'})]
scene("ivo_mitten", res, nodes)
