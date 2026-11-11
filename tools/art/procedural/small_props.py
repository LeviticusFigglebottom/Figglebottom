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
    assets/models/props/knucklebone.tscn   a sheep's knucklebone (THORNWOLD.md 8)
    assets/models/props/birch_ring.tscn    a ring of plaited birch
    assets/models/props/hedge_gate.tscn    the five-bar gate Eyvind never hung
    assets/models/props/fold_tally.tscn    Old Calder's fold-tally (REACH.md 8)
    assets/models/props/calder_boots.tscn  his boots, toes to the wall (stands upright)
    assets/models/props/bone_whistle.tscn  the shepherd's whistle
    assets/models/props/ice_tracks.tscn    one set of footprints in the ice (KETTLE; upright)
    assets/models/props/latch_wool.tscn    a scrap of woad wool (TARNHALL)
    assets/models/props/hall_coat.tscn     the hall guard's coat on its peg (TARNHALL; upright)
    assets/models/props/woad_band.tscn     Wren's band (COLDWELL.md 8)
    assets/models/props/mourning_mask.tscn a mourning mask, woad band (Maren's; upright)
    assets/models/props/child_mask.tscn    the small one off the low peg (upright)

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
       ("seg", "CylinderMesh", {"top_radius": 0.085, "bottom_radius": 0.07, "height": 0.08, "radial_segments": 12,
                                "material": 'SubResource("horn")'}),
       ("foot", "CylinderMesh", {"top_radius": 0.05, "bottom_radius": 0.095, "height": 0.06, "radial_segments": 12,
                                 "material": 'SubResource("birch")'}),
       ("band", "CylinderMesh", {"top_radius": 0.092, "bottom_radius": 0.092, "height": 0.03, "radial_segments": 14,
                                 "material": 'SubResource("tin")'}),
       ("inside", "CylinderMesh", {"top_radius": 0.08, "bottom_radius": 0.08, "height": 0.004, "radial_segments": 14,
                                   "material": 'SubResource("dust")'})]
nodes = [("HostCup", "Node3D", None, {}),
         ("Foot", "MeshInstance3D", ".", {"transform": xf(y=0.025), "mesh": 'SubResource("foot")'})]
# the horn rises off the foot and curls back: segments growing toward the mouth
for i in range(5):
    k = i / 4.0
    sc = 0.55 + 0.45 * k
    x = -0.05 * math.sin(k * 1.4)
    nodes.append(("H%d" % i, "MeshInstance3D", ".", {"transform": xf(sc, 1, sc, x=x, y=0.09 + i * 0.07), "mesh": 'SubResource("seg")'}))
nodes.append(("Band", "MeshInstance3D", ".", {"transform": xf(y=0.4), "mesh": 'SubResource("band")'}))
nodes.append(("Dust", "MeshInstance3D", ".", {"transform": xf(y=0.395), "mesh": 'SubResource("inside")'}))
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

# Thornwold (THORNWOLD.md 8): a sheep's knucklebone, and a ring of plaited birch
res = [mat("bone", 0.86, 0.82, 0.72, 0.6),
       ("knuckle", "CapsuleMesh", {"radius": 0.018, "height": 0.06, "material": 'SubResource("bone")'}),
       ("end", "SphereMesh", {"radius": 0.016, "height": 0.032, "radial_segments": 8, "rings": 4, "material": 'SubResource("bone")'})]
nodes = [("Knucklebone", "Node3D", None, {}),
         ("Body", "MeshInstance3D", ".", {"transform": xf(y=0.03), "mesh": 'SubResource("knuckle")'}),
         ("EndA", "MeshInstance3D", ".", {"transform": xf(x=0.006, y=0.005), "mesh": 'SubResource("end")'}),
         ("EndB", "MeshInstance3D", ".", {"transform": xf(x=-0.006, y=0.056), "mesh": 'SubResource("end")'})]
scene("knucklebone", res, nodes)

res = [mat("birch", 0.9, 0.86, 0.76, 0.8), mat("bark", 0.3, 0.26, 0.22, 0.9),
       ("band", "TorusMesh", {"inner_radius": 0.009, "outer_radius": 0.013, "rings": 18, "ring_segments": 6,
                              "material": 'SubResource("birch")'}),
       ("plait", "TorusMesh", {"inner_radius": 0.0105, "outer_radius": 0.0125, "rings": 9, "ring_segments": 4,
                               "material": 'SubResource("bark")'})]
nodes = [("BirchRing", "Node3D", None, {}),
         ("Band", "MeshInstance3D", ".", {"transform": rotz % (0, 0.0, 0), "mesh": 'SubResource("band")'}),
         ("Plait", "MeshInstance3D", ".", {"transform": rotz % (0.002, 0.0, 0), "mesh": 'SubResource("plait")'})]
scene("birch_ring", res, nodes)

# the gate Eyvind made and never hung (THORNWOLD.md 4, 9): a five-bar field gate
# of riven ash, 3 m wide, standing in the XY plane (hinge stile at -X). The
# landmark leans it on the hedge, then lays it flat across the gap (tilt -90).
res = [mat("ash", 0.62, 0.55, 0.44, 0.9), mat("ashdark", 0.45, 0.39, 0.3, 0.9),
       ("rail", "BoxMesh", {"size": "Vector3(3.0, 0.09, 0.06)", "material": 'SubResource("ash")'}),
       ("stile", "BoxMesh", {"size": "Vector3(0.12, 1.3, 0.1)", "material": 'SubResource("ashdark")'}),
       ("brace", "BoxMesh", {"size": "Vector3(3.15, 0.08, 0.05)", "material": 'SubResource("ash")'})]
nodes = [("HedgeGate", "Node3D", None, {}),
         ("StileHinge", "MeshInstance3D", ".", {"transform": xf(x=-1.5, y=0.65), "mesh": 'SubResource("stile")'}),
         ("StileLatch", "MeshInstance3D", ".", {"transform": xf(x=1.5, y=0.65), "mesh": 'SubResource("stile")'})]
for i in range(5):
    nodes.append(("Rail%d" % i, "MeshInstance3D", ".", {"transform": xf(y=0.12 + i * 0.27, z=0.02), "mesh": 'SubResource("rail")'}))
a = math.atan2(1.08, 3.0)
c, s_ = math.cos(a), math.sin(a)
nodes.append(("Brace", "MeshInstance3D", ".",
              {"transform": "Transform3D(%g, %g, 0, %g, %g, 0, 0, 0, 1, 0, 0.66, -0.04)" % (c, -s_, s_, c), "mesh": 'SubResource("brace")'}))
scene("hedge_gate", res, nodes, upright=True)


# --- Shepherd's Reach, the Coldwell and the pieces on the way up (REACH.md 8,
# COLDWELL.md 8) ---------------------------------------------------------------
WOAD = (0.27, 0.41, 0.59)

# the fold-tally: a hazel stick notched down one edge, each notch crossed and
# crossed again; one more at the end, cut smaller
res = [mat("hazel", 0.58, 0.46, 0.3), mat("cut", 0.22, 0.15, 0.09),
       ("rod", "CylinderMesh", {"top_radius": 0.02, "bottom_radius": 0.024, "height": 0.8,
                                "radial_segments": 8, "material": 'SubResource("hazel")'}),
       ("notch", "BoxMesh", {"size": "Vector3(0.05, 0.007, 0.018)", "material": 'SubResource("cut")'}),
       ("small", "BoxMesh", {"size": "Vector3(0.05, 0.005, 0.009)", "material": 'SubResource("cut")'})]
nodes = [("FoldTally", "Node3D", None, {}),
         ("Rod", "MeshInstance3D", ".", {"transform": xf(y=0.4), "mesh": 'SubResource("rod")'})]
for i in range(43):
    nodes.append(("N%d" % i, "MeshInstance3D", ".", {"transform": xf(y=0.05 + i * 0.016, z=0.02), "mesh": 'SubResource("notch")'}))
nodes.append(("Small", "MeshInstance3D", ".", {"transform": xf(y=0.05 + 44 * 0.016, z=0.021), "mesh": 'SubResource("small")'}))
scene("fold_tally", res, nodes)

# his boots: a pair, side by side, standing
res = [mat("hide", 0.3, 0.22, 0.15, 0.9), mat("sole", 0.16, 0.12, 0.09, 0.95),
       ("shaft", "CylinderMesh", {"top_radius": 0.07, "bottom_radius": 0.06, "height": 0.26, "radial_segments": 10,
                                  "material": 'SubResource("hide")'}),
       ("foot", "BoxMesh", {"size": "Vector3(0.11, 0.08, 0.27)", "material": 'SubResource("hide")'}),
       ("sole", "BoxMesh", {"size": "Vector3(0.12, 0.02, 0.28)", "material": 'SubResource("sole")'})]
nodes = [("CalderBoots", "Node3D", None, {})]
for k, x in enumerate((-0.09, 0.09)):
    nodes += [("Shaft%d" % k, "MeshInstance3D", ".", {"transform": xf(x=x, y=0.2, z=0.07), "mesh": 'SubResource("shaft")'}),
              ("Foot%d" % k, "MeshInstance3D", ".", {"transform": xf(x=x, y=0.06), "mesh": 'SubResource("foot")'}),
              ("Sole%d" % k, "MeshInstance3D", ".", {"transform": xf(x=x, y=0.01), "mesh": 'SubResource("sole")'})]
scene("calder_boots", res, nodes, upright=True)

# the whistle: a shin-bone, two holes, a lanyard knot
res = [mat("bone", 0.88, 0.84, 0.74, 0.6), mat("hole", 0.1, 0.08, 0.06), mat("cord", 0.4, 0.3, 0.2),
       ("tube", "CylinderMesh", {"top_radius": 0.012, "bottom_radius": 0.015, "height": 0.11, "radial_segments": 8,
                                 "material": 'SubResource("bone")'}),
       ("hole", "SphereMesh", {"radius": 0.005, "height": 0.01, "radial_segments": 6, "rings": 3, "material": 'SubResource("hole")'}),
       ("loop", "TorusMesh", {"inner_radius": 0.02, "outer_radius": 0.025, "rings": 12, "ring_segments": 4,
                              "material": 'SubResource("cord")'})]
nodes = [("BoneWhistle", "Node3D", None, {}),
         ("Tube", "MeshInstance3D", ".", {"transform": xf(y=0.055), "mesh": 'SubResource("tube")'}),
         ("H0", "MeshInstance3D", ".", {"transform": xf(x=0.012, y=0.05), "mesh": 'SubResource("hole")'}),
         ("H1", "MeshInstance3D", ".", {"transform": xf(x=0.012, y=0.075), "mesh": 'SubResource("hole")'}),
         ("Loop", "MeshInstance3D", ".", {"transform": xf(y=0.125), "mesh": 'SubResource("loop")'})]
scene("bone_whistle", res, nodes)

# one set of footprints frozen into the ice: six prints going away (-Z), the
# left ones (x < 0) set further ahead of the right than a level stride would
res = [mat("print", 0.16, 0.2, 0.26, 0.4),
       ("sole", "BoxMesh", {"size": "Vector3(0.1, 0.012, 0.24)", "material": 'SubResource("print")'}),
       ("heel", "BoxMesh", {"size": "Vector3(0.085, 0.012, 0.08)", "material": 'SubResource("print")'})]
nodes = [("IceTracks", "Node3D", None, {})]
z = 0.6
for i in range(6):
    left = i % 2 == 0
    z -= 0.78 if left else 0.6
    x = -0.12 if left else 0.12
    nodes += [("P%d" % i, "MeshInstance3D", ".", {"transform": xf(x=x, y=0.006, z=z), "mesh": 'SubResource("sole")'}),
              ("H%d" % i, "MeshInstance3D", ".", {"transform": xf(x=x, y=0.006, z=z + 0.19), "mesh": 'SubResource("heel")'})]
scene("ice_tracks", res, nodes, upright=True)

# a scrap of woad wool, torn off on a latch
res = [mat("woad", *WOAD, 0.95),
       ("tuft", "SphereMesh", {"radius": 0.03, "height": 0.05, "radial_segments": 7, "rings": 4, "material": 'SubResource("woad")'}),
       ("strand", "BoxMesh", {"size": "Vector3(0.008, 0.09, 0.008)", "material": 'SubResource("woad")'})]
nodes = [("LatchWool", "Node3D", None, {}),
         ("Tuft", "MeshInstance3D", ".", {"transform": xf(y=0.06), "mesh": 'SubResource("tuft")'}),
         ("S0", "MeshInstance3D", ".", {"transform": xf(x=0.01, y=0.02), "mesh": 'SubResource("strand")'}),
         ("S1", "MeshInstance3D", ".", {"transform": xf(x=-0.012, y=0.1, z=0.008), "mesh": 'SubResource("strand")'})]
scene("latch_wool", res, nodes)

# the hall guard's coat, hung by its collar on a peg: quilted felt over
# mail, a fur cape on the shoulders, yellow cuffs (origin at the floor)
res = [mat("felt", 0.36, 0.31, 0.25, 0.95), mat("mail", 0.2, 0.21, 0.23, 0.55), mat("fur", 0.5, 0.45, 0.38, 1.0),
       mat("cuff", 0.72, 0.62, 0.2, 0.9), mat("peg", 0.3, 0.22, 0.15, 0.9),
       ("body", "BoxMesh", {"size": "Vector3(0.5, 0.78, 0.14)", "material": 'SubResource("felt")'}),
       ("hem", "BoxMesh", {"size": "Vector3(0.46, 0.14, 0.11)", "material": 'SubResource("mail")'}),
       ("cape", "BoxMesh", {"size": "Vector3(0.6, 0.2, 0.2)", "material": 'SubResource("fur")'}),
       ("sleeve", "BoxMesh", {"size": "Vector3(0.13, 0.62, 0.12)", "material": 'SubResource("felt")'}),
       ("cuff", "BoxMesh", {"size": "Vector3(0.14, 0.07, 0.13)", "material": 'SubResource("cuff")'}),
       ("peg", "CylinderMesh", {"top_radius": 0.018, "bottom_radius": 0.022, "height": 0.2, "radial_segments": 8,
                                "material": 'SubResource("peg")'})]
nodes = [("HallCoat", "Node3D", None, {}),
         ("Peg", "MeshInstance3D", ".", {"transform": "Transform3D(1, 0, 0, 0, 0, -1, 0, 1, 0, 0, 1.72, -0.06)", "mesh": 'SubResource("peg")'}),
         ("Cape", "MeshInstance3D", ".", {"transform": xf(y=1.56), "mesh": 'SubResource("cape")'}),
         ("Body", "MeshInstance3D", ".", {"transform": xf(y=1.1), "mesh": 'SubResource("body")'}),
         ("Hem", "MeshInstance3D", ".", {"transform": xf(y=0.66), "mesh": 'SubResource("hem")'})]
for k, x in enumerate((-0.3, 0.3)):
    nodes += [("Sleeve%d" % k, "MeshInstance3D", ".", {"transform": xf(x=x, y=1.18), "mesh": 'SubResource("sleeve")'}),
              ("Cuff%d" % k, "MeshInstance3D", ".", {"transform": xf(x=x, y=0.86), "mesh": 'SubResource("cuff")'})]
scene("hall_coat", res, nodes, upright=True)

# Wren's band: a strip of woad cloth, the knot still in it
res = [mat("woad", *WOAD, 0.95),
       ("strip", "BoxMesh", {"size": "Vector3(0.008, 0.46, 0.05)", "material": 'SubResource("woad")'}),
       ("knot", "SphereMesh", {"radius": 0.028, "height": 0.05, "radial_segments": 7, "rings": 4, "material": 'SubResource("woad")'})]
nodes = [("WoadBand", "Node3D", None, {}),
         ("Strip", "MeshInstance3D", ".", {"transform": xf(y=0.23), "mesh": 'SubResource("strip")'}),
         ("Knot", "MeshInstance3D", ".", {"transform": xf(y=0.3), "mesh": 'SubResource("knot")'})]
scene("woad_band", res, nodes)


def mask_scene(name, h, root):
    """A smooth mourning mask: two eye holes, a brow line, a woad band; face to +Z."""
    w = h * 0.68
    res = [mat("birch", 0.82, 0.76, 0.64, 0.7), mat("eye", 0.06, 0.05, 0.05), mat("woad", *WOAD, 0.95), mat("brow", 0.4, 0.33, 0.26),
           ("face", "SphereMesh", {"radius": 0.5, "height": 1.0, "radial_segments": 14, "rings": 8, "material": 'SubResource("birch")'}),
           ("eye", "SphereMesh", {"radius": 0.5, "height": 1.0, "radial_segments": 8, "rings": 4, "material": 'SubResource("eye")'}),
           ("band", "BoxMesh", {"size": "Vector3(%g, %g, %g)" % (w * 0.97, h * 0.13, h * 0.32), "material": 'SubResource("woad")'}),
           ("brow", "BoxMesh", {"size": "Vector3(%g, %g, %g)" % (w * 0.7, h * 0.02, h * 0.04), "material": 'SubResource("brow")'})]
    nodes = [(root, "Node3D", None, {}),
             ("Face", "MeshInstance3D", ".", {"transform": xf(w, h, h * 0.3, y=h * 0.5), "mesh": 'SubResource("face")'}),
             ("EyeL", "MeshInstance3D", ".", {"transform": xf(w * 0.22, h * 0.085, h * 0.1, x=-w * 0.2, y=h * 0.56, z=h * 0.155), "mesh": 'SubResource("eye")'}),
             ("EyeR", "MeshInstance3D", ".", {"transform": xf(w * 0.22, h * 0.085, h * 0.1, x=w * 0.2, y=h * 0.56, z=h * 0.155), "mesh": 'SubResource("eye")'}),
             ("Brow", "MeshInstance3D", ".", {"transform": xf(y=h * 0.7, z=h * 0.125), "mesh": 'SubResource("brow")'}),
             # the band lies across the eyes, the holes showing through it
             ("Band", "MeshInstance3D", ".", {"transform": xf(y=h * 0.56), "mesh": 'SubResource("band")'})]
    scene(name, res, nodes, upright=True)


mask_scene("mourning_mask", 0.26, "MourningMask")
mask_scene("child_mask", 0.17, "ChildMask")
