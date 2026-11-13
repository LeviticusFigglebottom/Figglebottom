#!/usr/bin/env python3
"""Authoring script for data/areas/coldwell.json: the Coldwell (WORLD.md 5.7),
the last area.

    the Upwater    from the High Fold's corner of the Reach (seam), a long,
                   quiet climb along the crest of the mountain's shoulder
                   beside the river, up through its ice-falls; the land
                   falls away on the river's far side and every region lies
                   below, back the way the Bearer came
    the Wellhead   a level of turf at the top, two old houses, a ring of
                   standing stones round the spring under the glacier's lip

THAW (the last Melt before the sickness): the river loud and brown with
flowers in it; Maren holding Wren's hand at the edge. RIME: the river frozen,
every unsung dead of Rimeholt standing in it facing up the water; the
Leadvoice at the wellhead, behind the veil in the ring's gap. After her
release, the `ending_choice` hook at the spring offers the two endings
(SPEC §2 / WORLD.md §6).

Run: python3 tools/gen_coldwell.py [--keep-terrain]"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import terrain_coldwell as K  # noqa: E402
import terrain_lowe as L  # noqa: E402
import high_land as H  # noqa: E402
from seams_high import seam  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if __name__ == "__main__" and "--keep-terrain" not in sys.argv:
    K.write()


def r2(v):
    return round(v, 2)


def g(x, z):
    return r2(K.sample(x, z))


def at(x, z, dy=0.0):
    return [r2(x), r2(g(x, z) + dy), r2(z)]


PROPS, BOXES, LANDMARKS, HOUSES, BUILDINGS = [], [], [], [], []
WX, WZ = H.WELLHEAD


# --- the river beside the Upwater (on its downhill side) -----------------------------
def river_pts(step=2.0):
    pts = []
    for (ax, az, _), (bx, bz, _) in zip(H.UPWATER, H.UPWATER[1:]):
        L2 = math.hypot(bx - ax, bz - az)
        ux, uz = (bx - ax) / L2, (bz - az) / L2
        nx, nz = -uz, ux
        if nz < 0:
            nx, nz = -nx, -nz                 # the downhill side: toward the regions (z larger)
        t = 0.0
        while t < L2:
            x, z = ax + ux * t + nx * H.RIVER_OFF, az + uz * t + nz * H.RIVER_OFF
            pts.append([r2(x), r2(L.height(x, z) + 0.15), r2(z)])
            t += step
    return pts


RIVER = river_pts()
# the river comes out of the spring: carry it on up to the ring
RIVER = RIVER + [[r2(WX - H.RING_R - 2.0), r2(g(WX - H.RING_R - 2.0, WZ + 4.0) + 0.15), r2(WZ + 4.0)]]
FALLS = [{"pts": RIVER[::-1], "width": 5.0, "tag": "thaw"},
         {"pts": [[p[0], p[1] + 0.12, p[2]] for p in RIVER[::-1]], "width": 5.4, "tag": "rime"}]

# RIME: the unsung dead standing in the frozen river, facing up the water
for k in range(8, len(RIVER) - 4, 6):
    x, y, z = RIVER[k]
    nx_, ny_, nz_ = RIVER[k + 1]
    face = math.degrees(math.atan2(nx_ - x, nz_ - z))
    scene = "res://assets/models/enemies/unsung.glb" if k % 12 == 2 else "res://assets/models/enemies/upwalker.glb"
    # each stopped mid-something: wading on, standing, bowed, gone to the knees
    # ("pose": clip@fraction, held by PoseHold; unposed they stand arms-out)
    pose = ["walk@0.15", "idle@0.3", "hit@0.45", "walk@0.62", "defeat@0.38", "idle@0.8", "hit@0.3", "walk@0.4"][(k // 6) % 8]
    # a frozen figure is a solid as tall as its pose (kneeling, bowed, standing): the scene carries no
    # collider of its own, and a box taller than the pose would be an unseen wall (collision audit)
    bh = 1.0 if pose.startswith("defeat") else (1.5 if pose.startswith("hit") else 1.75)
    if "unsung" in scene and pose.startswith("defeat"):
        bh = 1.75   # the unsung's defeat clip sways back at full height, it does not kneel (collision audit)
    LANDMARKS.append({"scene": scene, "at": [x + 0.8 * math.sin(k), r2(y - 0.25), z], "rot": r2(face), "tag": "rime", "pose": pose,
                      "blocker": [0.7, bh, 1.25 if pose.startswith("walk") else (0.95 if "unsung" in scene and pose.startswith("defeat") else 0.7)]})   # (a wading stride runs fore and aft)

# --- the Wellhead ---------------------------------------------------------------------
# a kerb of river cobbles round the pool (modelled, tools/art/procedural/kit_props.py)
LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_spring_kerb.glb", "at": at(WX, WZ, -0.05), "rot": 0, "family": "M_stone"})
# the wellhead was generated frozen (ice basin, rime on every edge): that is
# its RIME face. THAW takes a regrade of the same mesh, the ice-blue pulled
# to wet mossed stone (tools/art/regrade_glb.py, row in PROVENANCE.md).
LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_wellhead_thaw.glb", "at": at(WX, WZ, -0.05), "rot": 90, "scale": 1.0,
                  "tag": "thaw", "blocker": [6.4, 2.6, 5.8]})
LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_wellhead.glb", "at": at(WX, WZ, -0.05), "rot": 90, "scale": 1.0,
                  "tag": "rime", "blocker": [6.4, 2.6, 5.8]})
GAP_A = 180.0                      # the ring opens toward the Upwater (west)
STONES = []
for k in range(14):
    a = GAP_A + 22.0 + k * (360.0 - 44.0) / 13.0
    x, z = WX + H.RING_R * math.cos(math.radians(a)), WZ + H.RING_R * math.sin(math.radians(a))
    STONES.append((x, z))
    LANDMARKS.append({"scene": "res://assets/models/landmarks/lm_standing_stone.glb", "at": at(x, z, -0.15), "rot": r2(a * 1.3 % 360),
                      "scale": 0.85, "blocker": [1.6, 3.0, 1.6]})
GAP = (WX + H.RING_R * math.cos(math.radians(GAP_A)), WZ + H.RING_R * math.sin(math.radians(GAP_A)))
# In RIME the ring is shut everywhere but the veil: rime has grown stone to
# stone, and in from each side of the gap to the veil's width. Without it
# every space between the stones was a way in, the navmesh went round the
# veil, and the last duel could be begun unsealed or walked out of. RIME
# only: the Melt and the spring find the ring as open as it was built.
RIME_SHUT = []
def _shut(x, z, r, n_spikes, along):
    """One closed space: an unseen post the Bearer cannot pass, dressed with
    rime spikes set along `along` (deg, the line the space runs on)."""
    RIME_SHUT.append({"at": [r2(x), r2(g(x, z) + 1.5), r2(z)], "radius": r, "height": 3.4, "tag": "rime"})
    for j in range(n_spikes):
        t = (j - (n_spikes - 1) / 2.0) * (2.0 * r / max(n_spikes, 1)) * 1.3
        sx, sz = x + t * math.cos(math.radians(along)), z + t * math.sin(math.radians(along))
        PROPS.append({"kit": "rime_spike", "at": at(sx, sz, -0.05), "rot": r2((j * 97 + x * 13) % 360), "tag": "rime",
                      "scale": r2(1.15 + 0.2 * ((j + int(abs(x))) % 3)), "collide": False})
for k in range(13):
    (x0, z0), (x1, z1) = STONES[k], STONES[k + 1]
    _shut((x0 + x1) / 2.0, (z0 + z1) / 2.0, 1.05, 2, math.degrees(math.atan2(z1 - z0, x1 - x0)))
# the gap: 7.6 m between its two stones, the veil 3.6 m across in the middle
for (ex, ez) in (STONES[0], STONES[13]):
    for f in (0.36, 0.78):     # from the veil's edge out to the stone
        mx, mz = GAP[0] + (ex - GAP[0]) * (0.47 + 0.53 * f), GAP[1] + (ez - GAP[1]) * (0.47 + 0.53 * f)
        _shut(mx, mz, 0.6, 1, math.degrees(math.atan2(ez - GAP[1], ex - GAP[0])))
# two old houses on the level, north and south of the ring (BuildingGen turf houses). At (WX - 22, WZ -+ 17)
# they stood on the 45-degree corrie wall (ground -17 m to +12 m across the footprint; no floor at either door,
# collision audit "threshold"); 14.5-15 m out the level runs 0.2 m across a 6 x 8 footprint (the south side falls away beyond 16 m), clear of the ring's
# stones (10 m) and of the dipper trough, the Sitting folk and the unsung by the way in (west)
# (the south house stays on the corrie wall for now: on the level 14-15 m south its eaves read "partial"
# in every orientation tried; see INBOX_gpu item 10)
for i, (hx, hz) in enumerate(((WX - 22.0, WZ - 17.0), (WX, WZ + 15.0))):
    hy = g(hx, hz)
    hyaw = 90
    hdoor = "W"                        # the north house's west door faces out from the ring
    HOUSES.append({"id": "wellhouse_%d" % i, "center": [hx, hz], "size": [6, 8], "yaw": hyaw, "y": hy,
                   "doors": [[hdoor, 0 if i == 0 else 1]], "gate_doors": [], "open": [], "wall_h": 2.8})
    BUILDINGS.append({"id": "wellhouse_%d" % i, "center": [hx, hz], "size": [6, 8], "yaw": hyaw, "y": hy, "doors": [], "open": []})

# --- people and the frost-taken ----------------------------------------------------------


def on_path(i, f, off=0.0, dy=0.0):
    ax, az, _ = H.UPWATER[i]
    bx, bz, _ = H.UPWATER[i + 1]
    x, z = ax + (bx - ax) * f, az + (bz - az) * f
    L2 = math.hypot(bx - ax, bz - az)
    x += (bz - az) / L2 * off
    z += -(bx - ax) / L2 * off
    return at(x, z, dy)


hearths = [
    {"id": "hs_upwater", "name": "the Upwater", "at": on_path(1, 0.5, 2.2), "rot": 250},
    {"id": "hs_ice_falls", "name": "the Ice-Falls", "at": on_path(4, 0.6, 2.2), "rot": 230},
    {"id": "hs_wellhead_steps", "name": "the Wellhead Steps", "at": on_path(8, 0.3, 2.2), "rot": 270},
]
spawners = [
    # the climb is long and quiet: few of them, and slow
    {"enemy": "upwalker", "id": "upwalker_low", "at": on_path(2, 0.6, 0.0, 0.1), "face": 240},
    # (upwalker_falls sits on the shelter's bench: see the points of interest)
    {"enemy": "upwalker", "id": "upwalker_high", "at": on_path(7, 0.5, 0.0, 0.1), "face": 250},
    {"enemy": "unsung", "id": "unsung_level_a", "at": at(WX - 14.5, WZ - 4.4, 0.1), "face": 270},
    {"enemy": "unsung", "id": "unsung_level_b", "at": at(WX - 16.0, WZ + 6.0, 0.1), "face": 270},
    # COLDWELL.md 6: sat beyond the spring, facing the gap, Wren against her chest
    # (her own script holds her sat: no idle pose from the spawner)
    {"enemy": "leadvoice", "id": "leadvoice", "at": at(WX + 4.5, WZ, 0.1), "face": 270,
     "dead_once": True, "frost_veil_id": "wellhead_veil"},
]
VEIL = at(GAP[0], GAP[1])
npcs = [{"id": "maren", "at": at(WX - 14.0, WZ + 9.0), "rot": 200, "tag": "thaw"},
        {"id": "wren", "at": at(WX - 13.2, WZ + 9.6), "rot": 200, "tag": "thaw"}]
pickups = [{"id": "upwater_cache", "at": on_path(6, 0.5, 2.6, 0.05), "item": "bog_iron", "count": 2, "tag": "rime",
            "label": "Pry up what the ice holds"}]

# --- points of interest (docs/lore/POI.md 8) -----------------------------------
# Set by hand on the three ledges cut beside the Upwater (high_land.LEDGES) and
# on the wellhead's level. "wayside": false keeps the wayside dressing from
# gathering round them; WAYSIDE_CLEAR keeps it off their ground.
PLAQUES, SCRIPTED, WAYSIDE_CLEAR = [], [], []
POI = {"wayside": False}
KIT_M = "res://assets/models/"


def prop(kit, pos, rot=0.0, tag="base", **kw):
    PROPS.append(dict({"kit": kit, "at": pos, "rot": r2(rot), "tag": tag}, **kw))


def board(pos, rot, thaw=None, rime=None):
    """One wayside board; its caption turns with the state."""
    for tag, text in (("thaw", thaw), ("rime", rime)):
        if text:
            PLAQUES.append(dict(POI, at=pos, rot=rot, tag=tag, text=text))


class Ledge:
    """A ledge's own frame: u metres up the path, v metres out from its middle."""

    def __init__(self, name):
        self.cx, self.cz, self.al, self.out, self.y = H.ledge_frame(name)
        _i, _f, self.along, self.depth, self.side = H.LEDGES[name]
        # yaw of a thing whose front (local +z) looks back at the path, and of one that looks out
        self.to_path = r2(math.degrees(math.atan2(-self.out[0], -self.out[1])))
        self.outward = r2(self.to_path + 180.0)
        WAYSIDE_CLEAR.append([r2(self.cx), r2(self.cz), r2(max(self.along, self.depth) * 0.5 + 3.5)])

    def xz(self, u, v):
        return self.cx + self.al[0] * u + self.out[0] * v, self.cz + self.al[1] * u + self.out[1] * v

    def at(self, u, v, dy=0.0):
        return at(*self.xz(u, v), dy)


# 8.1 the Flower Bank
FB = Ledge("flower_bank")
MELT = dict(POI, id="melt_flowers", at=FB.at(0.6, 0.3), item="item_melt_flowers", tag="thaw", label="Pick a bunch",
            scene=KIT_M + "props/melt_flowers.tscn")
prop("cw_flower_basket", FB.at(-0.5, -0.5), 35, tag="thaw", collide=False)
# the bank in flower (THAW): a few clumps growing, by hand; the art pass owns the ground cover
for k, (u, v) in enumerate([(-2.3, 0.9), (-1.2, 1.2), (0.2, 1.1), (1.5, 1.2), (2.5, 0.8), (2.0, -0.2)]):
    prop("cw_flower_bunch", FB.at(u, v, -0.04), 55 * k, tag="thaw", collide=False, scale=1.5)
# RIME: one of the standing dead in the river beside it, a small woman, a bunch held in both hands
_rx, _rz = FB.xz(0.5, -(FB.depth * 0.5 + H.PATH_HALF * 2 + H.RIVER_OFF - 0.6))
_ry = r2(L.height(_rx, _rz) - 0.1)
_rface = r2(math.degrees(math.atan2(FB.al[0], FB.al[1])))
LANDMARKS.append({"scene": "res://assets/models/enemies/upwalker.glb", "at": [r2(_rx), _ry, r2(_rz)], "rot": _rface, "tag": "rime",
                  "pose": "idle@0.55", "scale": 0.86, "blocker": [0.6, r2(1.75 * 0.86), 0.6]})
prop("cw_flower_bunch", [r2(_rx + FB.al[0] * 0.26), r2(_ry + 0.98), r2(_rz + FB.al[1] * 0.26)], 0, tag="rime", collide=False, on="hands")
# the custom itself: thrown in at the water's edge beside Maren and Wren
SCRIPTED.append({"script": "res://src/world/offering.gd", "at": at(WX - 12.4, WZ + 8.0), "tag": "thaw",
                 "params": {"item": "item_melt_flowers", "set_flag": "ks_melt_flowers", "prompt": "Throw them in",
                            "speaker": "wren", "line": "And that one."}})

# 8.2 the Shelter at the Ice-Falls
SS = Ledge("stick_shelter")
prop("cw_shelter", SS.at(0.4, 0.55), SS.to_path)
board(SS.at(-3.5, -1.6), SS.to_path,
      thaw="THE ICE-FALLS\n\nYou cut a stick to come up, and leave it here for someone going down.\nThe rack is nearly empty. Everyone is up at the water.",
      rime="THE ICE-FALLS\n\nThe rack is full. There are more against the wall, and more on the ground.\nNobody has wanted one going down.")
# the rack by the path: four sticks in THAW; in RIME full, and more leant and laid about the shelter
prop("cw_staff_rack", SS.at(-1.6, -2.05), SS.to_path, tag="thaw")
prop("cw_staff_rack_full", SS.at(-1.6, -2.05), SS.to_path, tag="rime")
prop("cw_staff_heap", SS.at(-2.4, 1.75), SS.to_path, tag="rime", collide=False)
prop("cw_staff_heap", SS.at(3.0, 1.75), SS.to_path, tag="rime", collide=False)
prop("cw_staff_heap", SS.at(3.55, -0.9), SS.to_path - 90, tag="rime", collide=False)
# it got this far and sat down (RIME): on the bench, slow to rise
SHELTER_FOE = {"enemy": "upwalker", "id": "upwalker_falls", "at": SS.at(1.4, 1.0, 0.1), "face": r2(SS.to_path + 180.0),
               "pose": "sit", "rise_time": 2.4}
# a rope rail down the outside of the next steep pitch, and ice on the falls above it
for f in (0.14, 0.26):       # (a third piece ended 0.14 m from the falls' ice: a pinch)
    prop("cw_rope_rail", on_path(5, f, -(H.PATH_HALF - 0.15)), r2(math.degrees(math.atan2(-(H.UPWATER[6][1] - H.UPWATER[5][1]),
                                                                                           H.UPWATER[6][0] - H.UPWATER[5][0]))))
for kit, (i, f, off) in (("cw_ice_column_b", (4, 0.42, 5.0)), ("cw_ice_column_c", (5, 0.2, 5.3)), ("cw_ice_column_a", (5, 0.52, 5.0))):
    # column a stands where the Bearer can reach it, so it is solid; b and c stand out on the falls' ice with
    # no ground beside them to walk in from (poi_coldwell), so they stay dressing
    prop(kit, on_path(i, f, off, -0.3), SS.to_path, tag="rime", embed=True, collide=(kit == "cw_ice_column_a"))

# 8.3 the Sitting Place
SP = Ledge("sitting_place")
prop("cw_slab_bench", SP.at(0.3, 0.3), SP.outward, tag="thaw")
prop("cw_slab_bench_snow", SP.at(0.3, 0.3), SP.outward, tag="rime")
board(SP.at(-2.3, -1.2), SP.outward,
      thaw="THE WELLHEAD STEPS\n\nYou can hear it from here.\nChildren are carried the last part, so they see it all at once.",
      rime="THE WELLHEAD STEPS\n\nThe snow on this bench has been sat in, at the left end only.\nSomething was put down at the right end, and picked up again.")
_al_yaw = r2(math.degrees(math.atan2(-SP.al[1], SP.al[0])))
prop("cw_rope_rail", SP.at(-1.5, SP.depth * 0.5 - 0.15), _al_yaw)
prop("cw_rope_rail", SP.at(1.5, SP.depth * 0.5 - 0.15), _al_yaw)
prop("cw_rope_rail", SP.at(-SP.along * 0.5 + 0.15, 0.4), _al_yaw + 90)

# 8.4 the Thread-Post, on the level between the two houses, outside the ring.
# (POI.md's "about WX - 21, WZ - 8" is on the bank, where the level has begun
# to rise: it stands two strides nearer, on the flat, still 10 m from the veil)
POST = at(WX - 18.5, WZ - 6.0)
prop("cw_thread_post", POST, 200)
board(at(WX - 20.3, WZ - 5.0), 250,
      thaw="THE WELLHEAD\n\nA thread on the post for each one going down the water this year.\nBlue, red and yellow. Eleven. It was a mild winter.",
      rime="THE WELLHEAD\n\nThe same eleven threads, white with frost.\nNobody came up to tie the next year's.")
prop("cw_dipper_trough", at(WX - 13.6, WZ + 5.4), 110)
prop("cw_offering_cairn", at(WX - 16.8, WZ - 9.4), 20)
prop("cw_water_yoke", at(WX - 15.7, WZ + 6.5), 110)
WAYSIDE_CLEAR.append([r2(WX - 18.5), r2(WZ - 7.0), 6.0])
WAYSIDE_CLEAR.append([r2(WX - 13.6), r2(WZ + 6.5), 5.0])

pickups.append(MELT)
spawners.append(SHELTER_FOE)
# --- end of points of interest ------------------------------------------------

portals = [seam("coldwell", "coldwell")]
arrive = seam("coldwell", "shepherds_reach")
START = arrive["spawn"]

edges = {
    "doc": "tools/audit_edges.py: the Upwater along the shoulder; the drop beyond the river is guarded by the fall volume.",
    "walk_max_deg": 45.0, "water_level": 0.0, "drown_depth": 1.15,
    "nav_bounds": [676, -556, 964, -364],
    "buildings": BUILDINGS, "thickets": [],
    "state_floors": [],
    "gates": [],
}


# THAW shade fills (area_builder "shade_fills"): the Ice-Falls path runs under
# the shelter's roof against the cliff, whose underside read black on the GPU.
# A soft cool light 3 m up at the board and along the shelter, THAW only.
SHADE_FILLS = [{"at": at(_px, _pz, 3.0), "range": 14.0, "energy": 2.0, "color": [0.86, 0.9, 1.0], "tag": "thaw"}
               for (_px, _pz) in [(800.4, -453.2), (796.0, -449.0)]]

D = {
    "id": "coldwell",
    "name": "The Coldwell",
    "start": {"pos": START, "yaw": arrive["spawn_yaw"]},
    # THAW is the last Melt, a spring morning, not the midsummer evening
    # (light and fog only: the sky colours belong to the art pass)
    "env": {"thaw": {"sun_rot": [-34, -100], "sun_energy": 2.4, "sun_color": [1.0, 0.95, 0.86], "fog_density": 0.0006, "vol_density": 0.0015,
                     "ambient": [0.36, 0.38, 0.42], "ambient_energy": 0.72, "exposure": 1.04, "saturation": 1.0,
                     "fog_color": [0.74, 0.76, 0.78]},
            "rime": {"sun_rot": [-20, -100], "fog_density": 0.004, "vol_density": 0.01}},
    "terrain": K.terrain_block(),
    "nav_bounds": [676, 40, -556, 964, 220, -364],
    "weather": {"gulls": False, "spindrift": 16},
    # the spring: its own shader (clear rim, dark still eye); RIME: iced over.
    # It lies just over the wellhead model's own flat water, inside the kerb.
    "water": [{"at": [r2(WX), r2(g(WX, WZ) + 0.87), r2(WZ)], "radius": 2.55, "tag": "thaw", "mat": "M_spring"},
              {"at": [r2(WX), r2(g(WX, WZ) + 0.87), r2(WZ)], "radius": 2.55, "tag": "rime", "mat": "M_ice_sheet"}],
    "falls": FALLS,
    "hazards": [{"kind": "fall", "min": [676, -2, -556], "max": [964, 400, -364]}],
    "zones": [
        {"name": "THE UPWATER", "min": [676, -556], "max": [r2(WX - 30.0), -364]},
        # (arriving here the horn is worth another look: WORLD.md 4.7)
        {"name": "THE WELLHEAD", "min": [r2(WX - 30.0), -556], "max": [964, -364], "set_flag": "ks_horn_wellhead"},
    ],
    "houses": HOUSES,
    "boxes": BOXES,
    "blockers": RIME_SHUT,
    "props": PROPS,
    "landmarks": LANDMARKS,
    "hearths": hearths,
    "spawners": spawners,
    "frost_veils": [{"id": "wellhead_veil", "at": VEIL, "rot": -90, "tag": "rime"}],
    "npcs": npcs,
    "scripted": [{"script": "res://src/world/ending_choice.gd", "at": at(WX - 5.5, WZ, 0.0), "rot": -90, "tag": "base",
                  "params": {"release_flag": "ks_leadvoice_released"}}] + SCRIPTED,
    "wayside_clear": WAYSIDE_CLEAR,
    "plaques": [{"at": on_path(0, 0.9, 3.4), "rot": 240, "text": "THE COLDWELL\n\nThe river's source, under the glacier's lip."}] + PLAQUES,
    "pickups": pickups,
    "portals": portals,
    "scatter": {
        "seed": 7071,
        "clear": [[WX, WZ, H.RING_R + 4.0]] + WAYSIDE_CLEAR,      # (no scattered rock on a ledge or by the post)
        "rules": [
            {"kind": "rock", "count": 140, "region": [676, -556, 964, -364], "slope": [0.75, 1.0], "scale": [0.3, 0.9], "path_max": 0.3},
            {"kind": "boulder", "count": 80, "region": [676, -556, 964, -364], "slope": [0.4, 0.85], "scale": [1.0, 2.6]},
            {"kind": "ice_floe", "count": 30, "region": [r2(WX + 14.0), -556, 964, -364], "slope": [0.0, 0.8], "scale": [3.0, 6.0]},
        ],
        "veg": [
            {"kind": "grass", "region": [676, -556, 964, -364], "density": 0.9, "range": 40},
            {"kind": "sedge", "region": [676, -556, 964, -364], "density": 0.4, "range": 35},
        ],
    },
    "edges": edges,
    "shade_fills": SHADE_FILLS,
}

if __name__ == "__main__":
    out = os.path.join(ROOT, "data", "areas", "coldwell.json")
    json.dump(D, open(out, "w"), indent=1)
    print("wrote", out)
