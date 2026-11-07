#!/usr/bin/env python3
"""Authoring script for data/areas/saltfell_steading.json (the greybox steading).
Run: python3 tools/gen_steading.py"""
import os
import json
D = {
 "id": "saltfell_steading",
 "name": "Saltfell Steading",
 "start": {"pos": [0, 0.2, 26], "yaw": 0},
 "fills": [
  {"kit": "floor_4x4", "min": [-22, 0, -30], "max": [22, 0, 30]},
  {"kit": "floor_4x4", "min": [-8, 0, -58], "max": [8, 0, -30]},
 ],
 "open_air_regions": [{"min": [-22, 0, -30], "max": [22, 0, 30]}, {"min": [12, 1.0, -10], "max": [22, 1.0, 10]}, {"min": [-22, 2.4, -14], "max": [-12, 2.4, -4]}],
 "vault_fields": [
  {"min": [-8, 0, -58], "max": [8, 0, -30], "flat": True, "skip_bands": ["S"]},
 ],
 "rows": [
  {"kit": "wall_4x4", "from": [-20, 0, 30], "dir": [1, 0, 0], "count": 11, "rot": 180},
  {"kit": "wall_4x4", "from": [-20, 0, -30], "dir": [1, 0, 0], "count": 11, "skip": [5]},
  {"kit": "wall_4x4", "from": [-22, 0, -28], "dir": [0, 0, 1], "count": 15, "rot": 90},
  {"kit": "wall_4x4", "from": [22, 0, -28], "dir": [0, 0, 1], "count": 15, "rot": -90},
  {"kit": "wall_4x4", "from": [-8, 0, -56], "dir": [0, 0, 1], "count": 7, "rot": 90},
  {"kit": "wall_4x4", "from": [8, 0, -56], "dir": [0, 0, 1], "count": 7, "rot": -90},
  {"kit": "wall_4x4", "from": [-6, 0, -58], "dir": [1, 0, 0], "count": 4},
  {"kit": "column_4m", "from": [-4, 0, -54], "dir": [0, 0, 1], "count": 6, "step": 4.4},
  {"kit": "column_4m", "from": [4, 0, -54], "dir": [0, 0, 1], "count": 6, "step": 4.4},
  {"kit": "wall_low_4m", "from": [-12, 0, 6], "dir": [1, 0, 0], "count": 3, "skip": [1]},
 ],
 "pieces": [
  {"kit": "portal_4m", "at": [0, 0, -30]},
  {"kit": "column_4m", "at": [-22, 0, -30]}, {"kit": "column_4m", "at": [22, 0, -30]},
  {"kit": "column_4m", "at": [-22, 0, 30]}, {"kit": "column_4m", "at": [22, 0, 30]},
  {"kit": "column_4m", "at": [-8, 0, -58]}, {"kit": "column_4m", "at": [8, 0, -58]},
  {"kit": "ramp_4m", "at": [17, 0, 14]},
  {"kit": "stair_4m", "at": [-17, 2.4, -4], "rot": 180},
 ],
 "boxes": [
  # the fell around the steading: open moor below the walls, far ridges
  {"min": [-160, -0.6, -200], "max": [160, -0.26, 160], "mat": "M_terrain", "collide": False},
  {"min": [-150, -1, -190], "max": [-60, 14, -120], "mat": "M_stone_dark", "collide": False},
  {"min": [-40, -1, -200], "max": [70, 22, -150], "mat": "M_stone_dark", "collide": False},
  {"min": [80, -1, -170], "max": [150, 11, -90], "mat": "M_stone_dark", "collide": False},
  {"min": [90, -1, -40], "max": [150, 8, 60], "mat": "M_stone_dark", "collide": False},
  {"min": [-150, -1, -20], "max": [-90, 9, 90], "mat": "M_stone_dark", "collide": False},
  {"min": [12, 0, -10], "max": [22, 1.0, 10], "mat": "M_stone_trim", "walkable": True},
  {"min": [-22, 0, -14], "max": [-12, 2.4, -4], "mat": "M_stone_trim", "walkable": True},
 ],
 "props": [
  # thaw: the last midsummer evening — tables, benches, lit braziers
  {"kit": "table_3m", "at": [-10, 0, 20], "tag": "thaw"},
  {"kit": "bench_3m", "at": [-10, 0, 21.0], "tag": "thaw"},
  {"kit": "bench_3m", "at": [-10, 0, 19.0], "tag": "thaw"},
  {"kit": "table_3m", "at": [10, 0, 20], "tag": "thaw"},
  {"kit": "bench_3m", "at": [10, 0, 21.0], "tag": "thaw"},
  {"kit": "bench_3m", "at": [10, 0, 19.0], "tag": "thaw"},
  {"kit": "brazier", "at": [-4, 0, 22], "tag": "thaw"},
  {"kit": "brazier", "at": [4, 0, 22], "tag": "thaw"},
  {"kit": "brazier", "at": [-3, 0, -26], "tag": "thaw"},
  {"kit": "brazier", "at": [3, 0, -26], "tag": "thaw"},
  {"kit": "table_3m", "at": [0, 0, -40], "rot": 90, "tag": "thaw"},
  {"kit": "table_3m", "at": [0, 0, -44], "rot": 90, "tag": "thaw"},
  {"kit": "table_3m", "at": [0, 0, -48], "rot": 90, "tag": "thaw"},
  {"kit": "brazier", "at": [-6, 0, -36], "tag": "thaw", "glow": [1.4, 2.2, 10]},
  {"kit": "brazier", "at": [6, 0, -36], "tag": "thaw", "glow": [1.4, 2.2, 10]},
  {"kit": "brazier", "at": [-6, 0, -50], "tag": "thaw", "glow": [1.4, 2.2, 10]},
  {"kit": "brazier", "at": [6, 0, -50], "tag": "thaw", "glow": [1.4, 2.2, 10]},
  {"kit": "woodpile", "at": [-18, 0, 24], "rot": 90, "tag": "thaw"},
  {"kit": "barrel", "at": [16, 1.0, -6], "tag": "thaw"},
  {"kit": "barrel", "at": [17, 1.0, -5], "tag": "thaw"},
  {"kit": "crate", "at": [19, 1.0, -7], "tag": "thaw"},
  # rime: the frozen present — the stores scattered, frost spikes
  {"kit": "crate", "at": [-9, 0, 18], "rot": 30, "tag": "rime"},
  {"kit": "crate", "at": [11, 0, 22], "rot": -20, "tag": "rime"},
  {"kit": "barrel", "at": [-14, 0, 12], "tag": "rime"},
  {"kit": "rime_spike", "at": [-6, 0, 10], "tag": "rime"},
  {"kit": "rime_spike", "at": [7, 0, 4], "rot": 70, "tag": "rime"},
  {"kit": "rime_spike", "at": [-16, 0, -22], "rot": 140, "tag": "rime"},
  {"kit": "rime_spike", "at": [14, 0, -24], "rot": 200, "tag": "rime"},
  {"kit": "rime_spike", "at": [-5, 0, -46], "tag": "rime"},
  {"kit": "rime_spike", "at": [5, 0, -38], "rot": 90, "tag": "rime"},
  {"kit": "brazier", "at": [-6, 0, -44], "tag": "rime", "flames": False, "glow": [2.2, 1.2, 14]},
  {"kit": "brazier", "at": [6, 0, -44], "tag": "rime", "flames": False, "glow": [2.2, 1.2, 14]},
  # both: woodpiles and the long hall's high seat
  {"kit": "woodpile", "at": [18, 0, 26], "rot": 90},
  {"kit": "crate", "at": [-19, 0, 27]},
  {"kit": "bench_3m", "at": [0, 0, -55], "scale": [1.2, 1.4, 1.4]},
 ],
 "hearths": [
  {"id": "steading_hearth", "name": "Steading Hearthstone", "at": [0, 0, 16], "rot": 0}
 ],
 "spawners": [
  {"enemy": "rimewalker", "id": "yard_w", "at": [-12, 0.1, 8], "face": 160},
  {"enemy": "rimewalker", "id": "yard_e", "at": [8, 0.1, 2], "face": -150},
  {"enemy": "rimewalker", "id": "terrace", "at": [17, 1.1, -4], "face": 120},
  {"enemy": "rimewalker", "id": "north_w", "at": [-14, 0.1, -22], "face": 30},
  {"enemy": "rimewalker", "id": "north_e", "at": [10, 0.1, -20], "face": -30},
  {"enemy": "holdfast_of_saltfell", "id": "holdfast", "at": [0, 0.1, -50], "face": 180,
   "dead_once": True, "frost_veil_id": "hall_veil"},
 ],
 "frost_veils": [
  {"id": "hall_veil", "at": [0, 0, -30], "rot": 0, "tag": "rime"}
 ],
 "npcs": [
  {"id": "steward_ingra", "at": [-6, 0, 14], "rot": -60, "tag": "thaw"}
 ],
 "plaques": [
  {"at": [3.5, 0, 24], "rot": 160, "text": "SALTFELL STEADING\n\nThe last long evening of summer.\nThe fires are high. The shearing starts at first light.\n\nRest at the hearthstone, and it will remember for you."},
  {"at": [3.2, 0, -27], "rot": 180, "tag": "rime", "text": "THE LONG HALL\n\nThe headman held this door against the first snow.\nHe is holding it still."},
 ],
 "pickups": [
  {"id": "stores_west", "at": [-18, 0, -26], "warmth": 40, "tag": "base", "label": "Take the hidden stores"},
  {"id": "bog_iron_terrace", "at": [19.5, 1.0, 6], "item": "bog_iron", "count": 2, "tag": "rime", "label": "Pry up the bog-iron"},
 ],
}
json.dump(D, open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'data', 'areas', 'saltfell_steading.json'), 'w'), indent=1)
