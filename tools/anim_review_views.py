#!/usr/bin/env python3
"""Camera manifest for the NPC review shots (anim review, 2026-11-10): one
in-place THAW shot per NPC in every area, 3.2 m in front of the body at its
authored "rot" (mannequin bodies face -Z at rot 0, src/world/npc.gd), 25 deg
round to a three-quarter view, at chest height. NPCs that need a release flag
get it, so the seated release scenes are shot as players see them.
Prints tools/gallery_gpu.sh VIEWS lines:  name area x,y,z,yaw,pitch,fov [--flag=..]
Usage: python3 tools/anim_review_views.py > build/anim_views.txt"""
import json
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
R, OFF, H, PITCH, FOV = 3.2, 25.0, 1.3, -8.0, 50

idx = json.load(open(os.path.join(ROOT, "data", "areas", "index.json"), encoding="utf-8"))
for area in idx["areas"]:
    d = json.load(open(os.path.join(ROOT, "data", "areas", area + ".json"), encoding="utf-8"))
    for n in d.get("npcs", []):
        if n.get("tag", "base") == "rime":
            continue
        x, y, z = n["at"]
        a = math.radians(float(n.get("rot", 0.0)) + OFF)
        # the body's front is -Z turned by rot; stand the camera out there
        cx, cz = x - math.sin(a) * R, z - math.cos(a) * R
        yaw = math.degrees(math.atan2(-(x - cx), -(z - cz)))
        flag = n.get("require_flag", "")
        name = "%s_%s%s" % (area, n["id"], "_released" if flag else "")
        extra = ("--flag=" + flag) if flag else ""
        print("%-44s %-18s %.2f,%.2f,%.2f,%.1f,%.1f,%d %s" % (name, area, cx, y + H, cz, yaw, PITCH, FOV, extra))
