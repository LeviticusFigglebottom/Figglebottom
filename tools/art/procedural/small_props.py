#!/usr/bin/env python3
"""Small release-drop props built from Godot primitives, written as .tscn
scenes (no Tripo spend for a hand-sized object). Each scene's long axis is +Y
and its flat side faces +X, because Pickup lays a display scene on its side
(rotation z 90): the long axis then lies along the ground, the flat side up.

    assets/models/props/tally_stick.tscn   Arne's tally-stick (LOWE.md 9)
    assets/models/props/ivo_mitten.tscn    Ivo's mitten (KETTLE.md 8)
    assets/models/props/host_cup.tscn      the Host's cup (TARNHALL.md 8; stands upright)
    assets/models/props/guest_tally.tscn   the guest-tally, a coiled knotted cord
    assets/models/props/ottar_stick.tscn   Ottar's rowan stick with a horn cap
    assets/models/props/barrel_head.tscn   a fish-barrel head, branded

Run: python3 tools/art/procedural/small_props.py"""
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "props")


def scene(name, resources, nodes, upright=False):
    """resources: [(id, type, {prop: value})]; nodes: [(name, type, parent, {prop: value})].
    upright: the Pickup stands it as it is instead of laying it on its side."""
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
        if parent is None and upright:
            lines.append("metadata/upright = true")
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

# the Host's cup: a big ox-horn on a turned birch foot, tin at the rim, dry
import math
res = [mat("horn", 0.62, 0.52, 0.36, 0.5), mat("tip", 0.25, 0.2, 0.15, 0.5), mat("birch", 0.78, 0.7, 0.55),
       mat("tin", 0.7, 0.72, 0.74, 0.35), mat("dust", 0.42, 0.38, 0.33, 1.0),
       ("seg", "CylinderMesh", {"top_radius": 0.05, "bottom_radius": 0.04, "height": 0.07, "radial_segments": 12,
                                "material": 'SubResource("horn")'}),
       ("foot", "CylinderMesh", {"top_radius": 0.035, "bottom_radius": 0.06, "height": 0.05, "radial_segments": 12,
                                 "material": 'SubResource("birch")'}),
       ("band", "CylinderMesh", {"top_radius": 0.058, "bottom_radius": 0.058, "height": 0.022, "radial_segments": 14,
                                 "material": 'SubResource("tin")'}),
       ("inside", "CylinderMesh", {"top_radius": 0.05, "bottom_radius": 0.05, "height": 0.004, "radial_segments": 14,
                                   "material": 'SubResource("dust")'})]
nodes = [("HostCup", "Node3D", None, {}),
         ("Foot", "MeshInstance3D", ".", {"transform": xf(y=0.025), "mesh": 'SubResource("foot")'})]
# the horn rises off the foot and curls back: segments growing toward the mouth
for i in range(5):
    k = i / 4.0
    sc = 0.55 + 0.45 * k
    x = -0.05 * math.sin(k * 1.4)
    nodes.append(("H%d" % i, "MeshInstance3D", ".", {"transform": xf(sc, 1, sc, x=x, y=0.08 + i * 0.062), "mesh": 'SubResource("seg")'}))
nodes.append(("Band", "MeshInstance3D", ".", {"transform": xf(y=0.36), "mesh": 'SubResource("band")'}))
nodes.append(("Dust", "MeshInstance3D", ".", {"transform": xf(y=0.355), "mesh": 'SubResource("inside")'}))
scene("host_cup", res, nodes, upright=True)

# the guest-tally: a long plaited cord, yellow and oat, coiled; knots along it
# and a clump of knots at the end
res = [mat("yellow", 0.72, 0.6, 0.3, 0.95), mat("oat", 0.8, 0.74, 0.6, 0.95),
       ("cord", "TorusMesh", {"inner_radius": 0.08, "outer_radius": 0.1, "rings": 24, "ring_segments": 6,
                              "material": 'SubResource("yellow")'}),
       ("cord2", "TorusMesh", {"inner_radius": 0.055, "outer_radius": 0.075, "rings": 20, "ring_segments": 6,
                               "material": 'SubResource("oat")'}),
       ("knot", "SphereMesh", {"radius": 0.016, "height": 0.032, "radial_segments": 6, "rings": 4,
                               "material": 'SubResource("oat")'})]
# torus axis is Y: lying on its side turns it onto X, so turn it first (axis +X)
rotz = "Transform3D(0, -1, 0, 1, 0, 0, 0, 0, 1, %g, %g, %g)"
nodes = [("GuestTally", "Node3D", None, {}),
         ("Coil", "MeshInstance3D", ".", {"transform": rotz % (0, 0.0, 0), "mesh": 'SubResource("cord")'}),
         ("Coil2", "MeshInstance3D", ".", {"transform": rotz % (0.012, 0.0, 0), "mesh": 'SubResource("cord2")'})]
for i in range(16):
    a = i * 2 * math.pi / 16
    nodes.append(("K%d" % i, "MeshInstance3D", ".", {"transform": xf(x=0.02, y=math.cos(a) * 0.09, z=math.sin(a) * 0.09),
                                                     "mesh": 'SubResource("knot")'}))
for i in range(5):   # the same knot, over and over, where the cord ends
    nodes.append(("End%d" % i, "MeshInstance3D", ".", {"transform": xf(1.3, 1.3, 1.3, x=0.03, y=-0.02 * i, z=0.12 + 0.012 * i),
                                                       "mesh": 'SubResource("knot")'}))
scene("guest_tally", res, nodes)

# Ottar's stick: rowan with the bark left on the grip, a horn cap, mud at the tip
res = [mat("rowan", 0.5, 0.36, 0.24), mat("bark", 0.3, 0.24, 0.2, 0.95), mat("horncap", 0.66, 0.56, 0.4, 0.5),
       mat("mud", 0.2, 0.15, 0.1, 1.0),
       ("shaft", "CylinderMesh", {"top_radius": 0.018, "bottom_radius": 0.022, "height": 1.3, "radial_segments": 8,
                                  "material": 'SubResource("rowan")'}),
       ("grip", "CylinderMesh", {"top_radius": 0.025, "bottom_radius": 0.025, "height": 0.22, "radial_segments": 8,
                                 "material": 'SubResource("bark")'}),
       ("cap", "SphereMesh", {"radius": 0.032, "height": 0.05, "radial_segments": 8, "rings": 4, "material": 'SubResource("horncap")'}),
       ("tip", "CylinderMesh", {"top_radius": 0.022, "bottom_radius": 0.016, "height": 0.08, "radial_segments": 8,
                                "material": 'SubResource("mud")'})]
nodes = [("OttarStick", "Node3D", None, {}),
         ("Shaft", "MeshInstance3D", ".", {"transform": xf(y=0.65), "mesh": 'SubResource("shaft")'}),
         ("Grip", "MeshInstance3D", ".", {"transform": xf(y=1.12), "mesh": 'SubResource("grip")'}),
         ("Cap", "MeshInstance3D", ".", {"transform": xf(y=1.31), "mesh": 'SubResource("cap")'}),
         ("Tip", "MeshInstance3D", ".", {"transform": xf(y=0.04), "mesh": 'SubResource("tip")'})]
scene("ottar_stick", res, nodes)

# a fish-barrel head: pine boards in a disc, the trader's mark burned in (a
# knot in a ring), two nails half drawn
res = [mat("pine", 0.66, 0.54, 0.38), mat("brand", 0.12, 0.08, 0.05, 1.0), mat("iron", 0.25, 0.24, 0.23, 0.6),
       ("disc", "CylinderMesh", {"top_radius": 0.2, "bottom_radius": 0.2, "height": 0.025, "radial_segments": 20,
                                 "material": 'SubResource("pine")'}),
       ("ring", "TorusMesh", {"inner_radius": 0.07, "outer_radius": 0.085, "rings": 20, "ring_segments": 4,
                              "material": 'SubResource("brand")'}),
       ("dot", "SphereMesh", {"radius": 0.025, "height": 0.01, "radial_segments": 8, "rings": 3, "material": 'SubResource("brand")'}),
       ("nail", "CylinderMesh", {"top_radius": 0.006, "bottom_radius": 0.006, "height": 0.05, "radial_segments": 6,
                                 "material": 'SubResource("iron")'})]
nodes = [("BarrelHead", "Node3D", None, {}),
         ("Disc", "MeshInstance3D", ".", {"transform": rotz % (0, 0, 0), "mesh": 'SubResource("disc")'}),
         ("Ring", "MeshInstance3D", ".", {"transform": rotz % (0.014, 0, 0), "mesh": 'SubResource("ring")'}),
         ("Knot", "MeshInstance3D", ".", {"transform": rotz % (0.014, 0, 0), "mesh": 'SubResource("dot")'}),
         ("Nail0", "MeshInstance3D", ".", {"transform": rotz % (0.03, 0.15, 0.05), "mesh": 'SubResource("nail")'}),
         ("Nail1", "MeshInstance3D", ".", {"transform": rotz % (0.03, -0.12, -0.11), "mesh": 'SubResource("nail")'})]
scene("barrel_head", res, nodes)
