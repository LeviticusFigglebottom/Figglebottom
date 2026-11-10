#!/usr/bin/env python3
"""Camera manifest for the v2 real-GPU gallery (Job 5): for every area in
data/areas/index.json, player-eye views (1.7 m over the ground at the start,
each hearth and each frost veil, looking into the area) and one high vista.
Prints lines in tools/gallery_gpu.sh's VIEWS format:
    name area x,y,z,yaw,pitch,fov
Usage: python3 tools/gallery_v2_views.py > build/gallery_v2_views.txt"""
import json
import math
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
EYE = 1.7
# Hand-set cameras where the rule lands in rock or faces a wall (checked on
# the GPU, 2026-11-10).
OVERRIDES = {
    "kettle_fjord_eye_start": "-70.2,37.0,-258.2,45.0,-8.0,70",     # the game's own start facing
    "kettle_fjord_vista": "-130.0,60.0,-300.0,-90.0,-18.0,62",      # over the fjord mouth, looking in
    "tarnhall_eye_long_table_veil": "218.0,26.0,-329.0,-89.0,-4.0,70",  # into the hall, not the wall
}


def yaw_to(src, dst):
    # Godot: a camera with rotation_degrees.y = yaw looks along (-sin, -cos)
    dx, dz = dst[0] - src[0], dst[2] - src[2]
    return math.degrees(math.atan2(-dx, -dz))


def cam(p, yaw, pitch, fov):
    return "%.1f,%.1f,%.1f,%.1f,%.1f,%d" % (p[0], p[1], p[2], yaw, pitch, fov)


def views(area):
    d = json.load(open(os.path.join(ROOT, "data", "areas", area + ".json"), encoding="utf-8"))
    nb = d.get("nav_bounds", [-60, 0, -60, 60, 40, 60])
    centre = [(nb[0] + nb[3]) * 0.5, 0.0, (nb[2] + nb[5]) * 0.5]
    out = []
    pts = [("start", d["start"]["pos"])]
    pts += [(h["id"], h["at"]) for h in d.get("hearths", [])]
    pts += [(v["id"], v["at"]) for v in d.get("frost_veils", [])]
    for name, at in pts[:7]:
        p = [at[0], at[1] + EYE, at[2]]
        # look into the area; a point on the centre itself looks along its rot
        if math.hypot(centre[0] - p[0], centre[2] - p[2]) < 8.0:
            y = -float(d["start"].get("yaw", 0.0))
        else:
            y = yaw_to(p, centre)
        out.append(("%s_eye_%s" % (area, name), area, cam(p, y, -4.0, 70)))
    s = d["start"]["pos"]
    y = yaw_to(s, centre)
    back = [s[0] + math.sin(math.radians(y)) * 30.0, s[1] + 26.0, s[2] + math.cos(math.radians(y)) * 30.0]
    out.append(("%s_vista" % area, area, cam(back, y, -16.0, 62)))
    return out


if __name__ == "__main__":
    idx = json.load(open(os.path.join(ROOT, "data", "areas", "index.json"), encoding="utf-8"))
    for a in idx["areas"]:
        for name, area, c in views(a):
            print("%-48s %-18s %s" % (name, area, OVERRIDES.get(name, c)))
