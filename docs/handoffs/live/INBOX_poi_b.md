# Inbox: points of interest, Kettle Fjord / Tarnhall / the Coldwell

*Branch `feat/poi-kettle-tarnhall-coldwell`. Newest first. The lead answers in `LOCAL_OUTBOX.md`.*

## 2026-11-11: state at hand-off (read this first)

**Branch** `feat/poi-kettle-tarnhall-coldwell`, three region commits plus shots. Not merged. CI no longer runs on feature branches, so the suites below were run here.

| Suite | Result here |
|---|---|
| `poi_kettle` / `poi_tarnhall` / `poi_coldwell` (new) | 69 / 57 / 57 checks, all pass |
| `kettle`, `kettle_encounters`, `tarnhall`, `tarnhall_encounters`, `coldwell`, `coldwell_encounters` | pass |
| `smoke`, `houses`, `traps`, `keepsakes`, `release_scenes` | pass |
| `fullgame_tarnhall`, `fullgame_coldwell` | pass (211 and 178 checks) |
| `fullgame_kettle` | **not green: see below** |
| `tools/audit_edges.py`, `tools/audit_areas.py`, `tools/check_originality.sh --all` | clean |

**Known breakage: `fullgame_kettle`.** Run 1 passed everything up to and through the Ice-Cutter (197 checks) except four checks that assumed one board and nine foes in the region; those assumptions are fixed in the suite. Runs 2 and 3, with those fixes, pass the fixed checks and then stall in the Ice-Cutter duel: the Bearer goes through a hole the Ice-Cutter drills ("stilled ... on thin ice: true ... drill_down"), comes back, and never lands a third blow (the Ice-Cutter sits at 830/1250, in phase one, until the duel's clock runs out; 17 checks fail after it). I did not find the cause. Nothing built here is within 40 m of the arena, and `src/enemies/enemy.gd` gained only a `struck` signal and a `rouse()` nobody calls on him, but I have not shown the stall happens on `main`, so treat it as open. Next step: `tools/test.sh fullgame_kettle` on `main` on a quiet box; if it stalls there too it is the duel bot's, and if not, bisect the three region commits.

**Not done.**
- `BIOMES.md` column 6 (stand-ins to replace) for these three regions: the items left there are light, cliff and terrain-shader faults that belong to the art/biomes session; none were touched.
- No ice-fall columns on Kettle's walls (the model exists: `cw_ice_column_a/b/c`).
- The Turn in the Road cannot be read in its THAW shot: the road's cut is nearly black there (the light is the art/biomes session's).
- `docs/handoffs/live/CONSOLIDATED.md` and `docs/TASKS.md` are untouched (the lead's); this file stands in for them.

## 2026-11-11: the Coldwell done

**State.** All four places of `POI.md` §8 are built by hand in `tools/gen_coldwell.py` (the section marked "points of interest"). Three ledges are cut in `tools/high_land.py` (`LEDGES`, `_ledges`, `ledge_frame`), each level with the path where it leaves it:

| Place | Ledge | Side |
|---|---|---|
| the Flower Bank | 6 × 3 m, 12 m above the Upwater hearth | uphill, into the bank |
| the Shelter at the Ice-Falls | 8 × 5 m, beside the Ice-Falls hearth | uphill, into the bank |
| the Sitting Place | 6 × 4 m, 6 m above the Wellhead Steps hearth, railed on its two open sides | downhill, on the shoulder |
| the Thread-Post | none (the wellhead's level) | — |

**To regenerate.** `python3 tools/gen_coldwell.py`, then `python3 tools/audit_edges.py coldwell`. The Reach's grid stops short of the lowest ledge, so its bins do not change.

**New engine pieces.** `src/world/offering.gd` (the Melt flowers thrown in beside Maren and Wren: spends the item, sets `ks_melt_flowers`, Wren says her own repeat line). A spawner's `rise_time` in the area data overrides the roster's for that place (the walker on the shelter's bench: 2.4 s). `cw_shelter` collides as its own hollow shell, so the Bearer walks in under the roof.

**Decisions taken, for the owner to overrule.**
- *The Thread-Post stands at (`WX` - 18.5, `WZ` - 6), not at "about (`WX` - 21, `WZ` - 8)":* that spot is on the bank, 1.4 m up, where the level has started to rise. It is still 10 m from the frost veil. `unsung_level_a` moved 2 m to stand clear of it.
- *The post carries eleven threads, as its two plaques say,* not "hundreds" as the `BIOMES.md` prompt says. The first reference image also hung a ring, a horn and a small iron weight on it; that was re-rolled.
- *`POI.md`'s new canon (a thread tied at the wellhead for each of the year's dead) is built as written and still wants the owner's word.*
- *The flowers on the bank are six modelled clumps set by hand.* The marsh-marigold and lady's-smock ground cover is the art/biomes session's.
- *The ice-fall columns stand on the rock above the path in RIME only, and only here:* none were hung on Kettle's walls.

**Tests.** New suite `poi_coldwell` (57 checks). `coldwell`, `coldwell_encounters` pass locally.

**Variety props.** An offering cairn by the post and a water yoke by the trough.

## 2026-11-11: Tarnhall done

**State.** All four places of `POI.md` §5 are built by hand in `tools/gen_tarnhall.py` (the section marked "points of interest"). Two grounds are widened in `tools/tarn_land.py`:

| Place | Ground | Where |
|---|---|---|
| the Cook-Yard | drystone terrace 16 × 7 m, x 198–214, z -347 to -340, floor at `ISLAND_Y`; the island's own shore is cut away below its north face (3.3 m of wall into the water, 2.2 m above the RIME ice) | `COOK_YARD`, `_island_ground` |
| the South Window | level walk along the south wall from the porch's end to the byre yard (x 175–232, 3.4 m deep), shelving to the tarn like the island's own shore | `SOUTH_WALK`, `_island_ground` |
| the Seven Landings | none (the south-west shore, off the causeway) | — |
| the Porch | none; 1.2 m is kept clear before the doors | — |

**To regenerate.** `python3 tools/gen_tarnhall.py`, then `python3 tools/audit_edges.py tarnhall`.

**New engine pieces.** `src/world/look_in.gd` (the window's held look; `seconds` comes from the area data). Area keys `wayside_clear` (Wayside and HouseYard keep off those discs) and `"wayside": false` on a plaque or pickup.

**Decisions taken, for the owner to overrule.**
- *The terrace can be walked onto from the island's north strip at either end,* as well as from the byre yard: only its own north face is sheer. `POI.md` asks for no way up *from the ice*, which holds.
- *The boats at the Seven Landings lie afloat at the water's edge, bow to the land, in both states* (22 cm lower in RIME: in the ice to the gunwales). The shore there falls at about 30 degrees, so a boat drawn right up would stand on its stern.
- *Lusse's line for the Vat Dipper sets `ks_vat_dipper_shown` but adds no journal step:* `POI.md` gives no journal line for it, and I did not write one.
- *The two late guests and the two cooks are unnamed in the overheard strip* (no speaker label), as `POI.md` gives them no names.

**Tests.** New suite `poi_tarnhall` (57 checks). `tarnhall`, `tarnhall_encounters` pass locally (`tarnhall` now counts only souls that can be spoken to). `fullgame_tarnhall` passes locally.

**Variety props (the lead's second message).** Kettle: a second make of hut (`kf_ice_hut_b`, two of the four) and a kettle on a tripod at the camp's fire. Tarnhall: an ale tub in the cook-yard and a wool hanging on the porch.

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

**Tests.** New suite `poi_kettle` (69 checks). `kettle`, `kettle_encounters`, `smoke`, `houses`, `traps`, `keepsakes` pass locally. `fullgame_kettle`: see the hand-off note at the top.

**Known.** The road's cut is nearly black in THAW (the art/biomes session owns the light), so the bay cannot be read in `poi_kettle_kf_road_turn_after.png`; `poi_kettle_kf_road_turn_rime_after.png` shows the cut ground.
