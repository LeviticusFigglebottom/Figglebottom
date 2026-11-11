#!/usr/bin/env python3
"""The seams between Saltfell and the Lowe, shared by both area generators so
each side of a seam agrees with the other: the cliff-top pass west of the
ravine head, and the drawbridge over the ravine (lowered from the Lowe)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_saltfell as S  # noqa: E402


def r2(v):
    return round(v, 2)


PASS = {"x": -89.0, "z": -85.5, "w": 20.0}
BRIDGE = {"x": S.BRIDGE_X, "hinge_z": -82.5, "south_z": -69.5}


def bridge_y():
    return r2(max(S.height(BRIDGE["x"], BRIDGE["hinge_z"]), S.height(BRIDGE["x"], BRIDGE["south_z"])) + 0.05)


def seams(for_area):
    """The two seams between Saltfell and the Lowe, seen from either side."""
    by = bridge_y()
    blen = BRIDGE["south_z"] - BRIDGE["hinge_z"] + 0.6
    mid = BRIDGE["hinge_z"] + blen * 0.5
    sy = r2(S.height(PASS["x"], PASS["z"] + 4.0) + 0.3)
    ly = r2(S.height(PASS["x"], PASS["z"] - 4.0) + 0.3)
    # the Saltfell lip is lower than the hinge: the lowered deck slopes down
    # to rest on it (laid level, its far end was too high a step to climb)
    far_drop = r2(max(0.0, by - 0.01 - S.height(BRIDGE["x"], BRIDGE["hinge_z"] + blen)))
    bridge = {"script": "res://src/world/drawbridge.gd", "at": [BRIDGE["x"], by, BRIDGE["hinge_z"]], "rot": 180,
              "params": {"flag": "lowe_bridge_down", "length": r2(blen), "width": 2.4,
                         "operable": for_area == "lowe_barrows", "far_drop": far_drop}}
    if for_area == "lowe_barrows":
        portals = [
            {"to": "saltfell_steading", "auto": True, "at": [PASS["x"], sy - 0.3, PASS["z"]], "zone": [PASS["w"], 5, 2],
             "spawn": [PASS["x"], sy, PASS["z"] + 4.0], "spawn_yaw": 180},
            {"to": "saltfell_steading", "auto": True, "at": [BRIDGE["x"], by, r2(mid)], "zone": [3, 4, 2],
             "spawn": [BRIDGE["x"], by + 0.3, r2(mid + 4.0)], "spawn_yaw": 180},
        ]
    else:
        portals = [
            {"to": "lowe_barrows", "auto": True, "at": [PASS["x"], ly - 0.3, PASS["z"]], "zone": [PASS["w"], 5, 2],
             "spawn": [PASS["x"], r2(ly + 0.6), PASS["z"] - 4.0], "spawn_yaw": 0},
            {"to": "lowe_barrows", "auto": True, "at": [BRIDGE["x"], by, r2(mid)], "zone": [3, 4, 2],
             "spawn": [BRIDGE["x"], by + 0.3, r2(mid - 4.0)], "spawn_yaw": 0},
        ]
    return portals, bridge


