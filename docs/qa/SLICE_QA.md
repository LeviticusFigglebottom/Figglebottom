# Saltfell slice QA (2026-11-08, branch `fix/slice-qa`)

**Goal:** the slice plays start to finish as a finished 20-minute game, verified through the real game.

## The full-loop test

`tools/test/fullslice_test.gd` (103 checks) drives the **real** front door: the world scene, the house card, the title, New journey and the choice of winter. Then a capsule-steered Bearer walks the route on the navmesh:

1. Brede on the Strand.
2. The cliff path to the yard, and Ingra.
3. The forced first rest (THAW → RIME).
4. The yard fought with a melee bot.
5. The rye from under the byre hound, and the float from the ice.
6. One level.
7. The gully shortcut.
8. One real death to the frost-taken, then STILLED and the Breathmark taken back.
9. The frost veil and the Netmender. Her AI runs all three phases; only the Bearer's blows on her are scaled, through `Game.test_boss_dmg_mult`.
10. The release: the Outsong, the card, the needle, and the Long Hearth lit and kept.
11. Both Keepsakes threads closed in THAW, with steps 3 and 4 in separate talks.
12. Free turning at two hearths.
13. Pause → Return to the Title → Resume, with level, Pack, journal, flags, the shortcut, the Long Hearth and the winter all checked.

Run it on its own with `tools/test.sh fullslice` (about 15 minutes headless). `tools/qa/fullslice_shots.sh` runs the same route with a renderer and writes the screenshots plus a per-leg frame log. The full suite is 559 checks (456 → 559) and all pass.

## Fixed

| # | Bug | Fix | Commit |
|---|---|---|---|
| 1 | **Missing transition.** There was no way back to the title from play: the pause sheet could only quit the app. | Added Return to the Title. It saves first, tears the world down and re-runs the front door without the house card. | c5fb2bb |
| 2 | On a first boot the difficulty was asked **before** the title, so New journey skipped it. The "(default)" marker checked a stale id and never showed. The slot ledger printed `long` instead of the winter's name. | Now: title → New journey → difficulty (Esc returns to the title). The marker and the names are fixed. | c5fb2bb |
| 3 | **Wrong text.** A new journey opened with the card "Saltfell" on the Strand, then showed SALTFELL again in the yard. THE STRAND was never shown. | The arrival card names the zone the Bearer lands in. | aeb2edb, 08404f7 |
| 4 | **Softlock-ish.** Dying to the sea or a ravine hung the Breathmark under water or out of reach. | It now waits on the last ground stood on. | 08404f7 |
| 5 | Bringing the rye or the float **after the release** (the only time it can happen, since the area is locked in RIME until then) skipped the dog and knot lines, and closed steps 3 and 4 in one talk. | An errand closed in a talk is answered first. Its release lines wait for the next talk. | b6b521a |
| 6 | **Missing arena.** `gen_steading.py` wrote two `"scripted"` keys; the second (the drawbridge) overwrote the first, so the Longhouse had **no net floor** and the Netmender's haul and pulse did nothing. | One list. The net floor is back (slice_19). | fd8901d |
| 7 | The Mending Needle was runtime-only: saving and resuming before taking it lost it forever. | It is also area data, gated on the release flag. | fd8901d |
| 8 | **Softlock-ish.** The Long Hearth's respawn point sat **on the hearth kerb**, so the rest prompt could not be reached from the hall floor. | The hearth faces the door. | bedbe97 |
| 9 | **Janky camera.** Hearthstones carried an invisible 2.4 m post. With a hearth behind the Bearer, the camera arm folded into his back and the frame was a wall of wool (`slice_fix_cloak_before.png`; after: slice_23, slice_24). | The post is now waist height, and the body hides while the arm is folded inside it. | 67bfe19 |
| 10 | Talking from behind put the Bearer's hood over Ingra (`slice_fix_talk_before/after.png`). | The camera turns to the speaker over the shoulder. | 707fab4, 67bfe19 |
| 11 | **UI overlap.** The place card sat over the dialogue and rest panels (`slice_fix_card_before.png`; after: slice_05). | It clears when a panel opens. | 707fab4 |
| 12 | A dev pose and coordinates line was printed in the corner of **every frame of play**. | Only shown with `--surveyor` or F3. | 707fab4 |
| 13 | The Bearer spawned facing the lens on a new journey and on resume. | He faces along the camera, and wakes facing out from the hearth. | 67bfe19 |
| 14 | The Strand sign was a bare pale box (a "rune stone", a banned motif) filling the first frame. | It is now a board on a stake. | 7f979b5 |
| 15 | The shingle's speckle read as a pixel mosaic. | It is now rounded pebbles on the flat. | 7f979b5 |
| 16 | The frost veil was a glowing parchment-beige slab in the blue yard. SLICE asks for frozen net. | It is now frozen diamond net in rime blue, through per-veil shader params. | 1e5bda3 |
| 17 | **Missing sound.** The Hearthhound alerted with the villagers' moan. | It now has a synthesized bark (`synth.py hound`, its own seed). | 47441a9 |
| 18 | **Text that broke WRITING.md.** "The dead are patient; gather more", "Gourds are cheap; what fills them isn't", "Warmth first, Bearer", "the seeing will end", "warm the thaw", and the Strand sign's aphorism closer. | Rewritten plainly. | b6b521a, fd8901d |
| 19 | **Perf.** Scatter MultiMeshes were area-wide: never culled, and pebbles blinked out on the beach. | Chunked. Shadow reach is tiered, and small props get ranges. See PERF.md. | ba04378, b86b006, b7ef74a |

Before and after: `slice_fix_sign_before.png` and `slice_fix_strand_before/after.png` for #14–15; `slice_fix_veil_before/after.png` for #16.

## Second pass (after merging main)

| # | Was remaining issue | Fix | Commit |
|---|---|---|---|
| 20 | **The Bearer walked through enemies** and clipped into the Netmender. | After each move he is eased out of each foe's body ring by a collide-move: `Enemy.push_radius()` from `push_r`, else max(col_r, 0.9·hurt_r), which is 0.9 m for the Netmender against her 0.7 m nav capsule. Tuning is in `combat/body_push`. Rolls and backsteps skip it, so the i-frame dodge through a swing is unchanged. **Feel:** walking and lunges now stop at the body; hauls and grabs end at the ring; nothing hard-collides, so there is no wedging on a 3 m boss. `tools/test/body_test.gd` (8 checks). | 68d44fa |
| 21 | **No tide wall; the float was invisible.** | `src/world/tide_wall.gd`: a rime glass wall about 3 m high along the old waterline, with its crest curling landward and kelp and an oar caught inside. It is open where the frozen channel runs to the sea stack. The float sits in its face at chest height with a glint, and only a heavy blow chips it free (pickup `chip_heavy`). The full-slice test chips it with a heavy swing. Before and after: `slice_fix_tide_before/after.png`. | d73e6a8 |
| 22 | **The released Netmender sat inside the Long Hearth.** | `release_clear` (opt-in, 3.2 m) moves her off the hearth's spot before the needle and the hearth are set down. | 79df70b |
| 23 | **Title hitch.** Each stop swap rebuilt the whole steading. | The stage is built once and only the camera moves. `ShaderWarm` draws one speck of each costly in-play material under the first fade (frost dissolve and its shatter branch, veil, net floor, flame, ice, the rime families). | 416bd6f |
| 24 | **Per-enemy cost.** | **Measured, and my first-pass figure was wrong.** Each frost-taken is one skinned mesh (two for the Oarsman, with his oar) and has no lights. Its HP bar quads and hit-flash meshes stay hidden until used. The frost-shatter material is now shared per source material and cloned per body only as it dies. The ~260 small meshes in Saltfell are kit props built from primitives; see PERF.md. | 416bd6f |

## Remaining issues (ranked)

1. **SLICE beats not yet built:**
   - The THAW Longhouse door stop until Ingra's first talk.
   - Ingra coming in to the hall after two talks.
   - Brede on the gunwale, mending, after the release.
   - The frozen cat and washing line, the empty small grave, and the child's mask peg.
2. **Kit props are many small meshes.** A drying rack is 13 meshes, a hearth 6, the boat-shed gate 16. Merging each KitLib primitive piece into one mesh per material, after its collision is built, is the biggest draw-call lever left (PERF.md).
3. **The released Netmender pops to her new seat.** The 3.2 m move is instant, under the release card. A sit-down slide would read better.
4. **The byre's stave walls let light through at the seams** (slice_11).
5. **The RIME hearth trench** reads as a flat dark box with a pale kerb (slice_19).
6. **Place cards are not persisted.** The region and place cards show again after every load.
7. **The level sheet names weapon families** (bow, spear, greatsword) that are not in the slice (slice_12).
8. **The tide wall uses the shared opaque `M_ice`.** A glassier, see-through variant would show what is stopped inside, but MaterialLib and the art shaders belong to the art agent.

## Screenshots

**Provenance.** slice_01–19 and slice_21–30 come from the final runs, with every fix in. slice_20 (phase 2) comes from an earlier run that was identical up to that point. slice_30 predates the last lowering of the hearth post, so its camera still sits a little close.

**Under llvmpipe** (about 1 fps) the screenshot run is flaky on the two combat-timing legs, the provoked death and the duel: contact frames are lost between rendered frames. For that reason `fullslice_shots.sh` uses a 20x boss scale. The headless test is the source of truth, and it passes 103/103.


`docs/screens/slice_01…30_*.png`, captured along the route from the player camera (1280x720, llvmpipe), after the fixes above. They follow the route in order: the house card, the title, the difficulty, the Strand, Brede, the yard, Ingra, the first rest, the RIME yard, the byre, the level sheet, the gully, the float, STILLED, the Breathmark, the veil, the Netmender (mending and in phase 2), the release card, the needle, the Long Hearth, the hall in THAW, Brede and the float, the Strand in RIME and in THAW, the pause sheet, the title on Resume, and the resumed game.
