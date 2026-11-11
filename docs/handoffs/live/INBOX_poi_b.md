# Inbox: points of interest, Kettle Fjord / Tarnhall / the Coldwell

*Branch `feat/poi-kettle-tarnhall-coldwell`. Newest first. The lead answers in `LOCAL_OUTBOX.md`.*

## 2026-11-11: Kettle Fjord done

**State.** All five places of `POI.md` §4 are built by hand in `tools/gen_kettle.py` (the section marked "points of interest"), on ground widened in `tools/terrain_lowe.py`:

| Place | Ground | Where in the terrain script |
|---|---|---|
| the Turn in the Road | bay 5 × 4 m outside the last bend | `ROAD_BAY`, `_road_bay` |
| the Dog Lines | shingle spit, x -64 to -54, 6 m out | `DOG_SPIT`, `_dog_spit` |
| the Net-Cleft | notch through the east spur, 3 m between the faces on whole grid rows, about 9 m long | `CLEFT_Z`, `_net_cleft` |
| the Far Landing | 12 × 7 m of level shingle on the north shore | `FAR_LANDING`, `_far_landing` |
| the Ice Camp | none (the RIME ice; THAW under the west wall) | — |

**To regenerate.** `python3 tools/gen_kettle.py` (writes the Kettle bins), then `python3 tools/terrain_lowe.py` (the Lowe shares the landform, so its bins change too), then `python3 tools/audit_edges.py`.

**Merge note.** `data/terrain/lowe_h.bin`, `lowe_far.bin` and `data/terrain/traps/lowe_barrows.json` are regenerated here. If another branch also changes `terrain_lowe.py`, take both script changes and regenerate: `python3 tools/terrain_lowe.py && python3 tools/fix_traps.py --no-ramps lowe_barrows`.

**Decisions taken, for the owner to overrule.**
- *The Far Landing is 12 × 7 m of level ground, but only 4 m of it stands out into the fjord; the back 3 m is cut into the wall foot.* The fjord is at its narrowest there (38 m), and a full 7 m spit opposite the Dog Lines' spit left under 9 m of deep water between them in THAW.
- *The Far Landing stands at x -59 to -47, not centred on -60:* a fall comes down the north wall at x -64.
- *The Net-Cleft is 3.0 m between its rock faces* (four whole grid rows), not 2.6: on a 1 m heightmap a 2.6 m slot leaves under 2 m of level floor.
- *The crevasse off the Fish-Houses moved 1.5 m north*, two fish-kettles moved off the cleft's mouths, and one boat that was leaving moved from x -60 to -70, all to clear the new ground.
- *The camp's Sealer waits on data, not a flag:* a spawner's `wakes_with` sets its sight and hearing to nought until one of the named foes is struck (`Spawner._bind_wakes`, `Enemy.struck`, `Enemy.rouse`).

**Tests.** New suite `poi_kettle` (69 checks). `kettle`, `kettle_encounters`, `smoke`, `houses`, `traps`, `keepsakes` pass locally. `fullgame_kettle` is left to CI.

**Known.** The road's cut is nearly black in THAW (the art/biomes session owns the light), so the Turn in the Road's bay cannot be read in `poi_kettle_kf_road_turn_after.png`; the RIME shot shows it.
