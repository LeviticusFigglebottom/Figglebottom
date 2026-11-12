# QA env → lead

Newest first. QA session: `session_01F3vrULw7QwSZZNWUB551br`. Branch: `fix/qa-regions` (based on `origin/fix/slice-qa`).

## 2026-11-12: `fix/playtest-1` — playtest item 4 (the collision audit) merged; all four items in

**Branch state.** `fix/playtest-1` = `origin/main` 300ce5f + the Lowe bog-box fix, the chain fix, and playtest items 1–4. Every commit signed; `.github` is main's.

**Local results on the branch with everything merged (0 failures each):** `smoke` 11, `collision_audit` 45 (new), `prop_hit` 65, `grounded` 304, `leftovers` 125; walks `fullslice` 106, `fullgame_lowe` 194, `fullgame_kettle` 197, `fullgame_tarnhall` 211, `fullgame_thornwold` 160, `fullgame_reach` 195, `fullgame_coldwell` 178. **Not run on the final state:** the two ending walks, `leftovers_longhouse`, the encounter suites, and the default full suite as a whole (the agent ran the seven encounter suites, the region suites and `houses` green on its own branch before the merge).

**One thing that needed a driver change.** With the collision work merged, the Lowe and Kettle walks first failed their planned-death step (6 checks each). In the Lowe the Bearer was standing free inside the first barrow, whose passage has no navmesh floor, only fragments; the nearest fragment was now an isolated one, so the steered walker planned a path that went nowhere. Not a softlock for a player (the way out is physically clear). The walk driver now walks straight at its goal for a few seconds when its planned path is stranded, then re-plans (`fullgame_base.gd`, `_stranded`). Both walks pass with it. **I did not confirm the Kettle cause separately** (it passed after the same change), and I did not pin down which collider created the fragment in the barrow.

### Playtest 4: "several props and terrain lack collision"

Full write-up, method and the offender table with positions, sizes, probable fix and owner: **`docs/qa/COLLISION_AUDIT.md`**. Run it with `tools/test.sh collision_audit` (about 5 minutes: every area, THAW and RIME, released, spring).

- **The heightfield has no holes.** Collider against drawn ground at 41,249 samples across all seven areas: no mismatch. Seam crossings agree (worst 0.15 m).
- **What read as terrain without collision was scatter rock.** 41 driftwood snags and many 1.5 m rocks had no collider, and boulder spheres sat inside or beside their stones. **Fixed** (`scatter.gd`): rocks, boulders, driftwood, peat stacks, standing stones and upright floes collide as the hull of their own mesh once they stand 0.55 m out of the ground. This moves the navmesh in every area.
- **Also fixed:** plaques are solid; the raised drawbridge is solid (the Bearer walked through it off the ravine lip); the Reach's beck ice in RIME was drawn a metre narrower each side than its collider (walking on air over the bank, x 558–704), and a metre-deep ditch at (625.7, 68.8, -334.6) the navmesh crossed and the Bearer could not climb (`gen_reach.py`, regenerated `--keep-terrain`).
- **189 known offenders remain, baselined** (`tools/test/fixtures/collision_baseline.json`): the suite passes on those and fails on any new one. By owner: **152 look-pass agent, 21 endings agent, 12 world-fidelity env, 4 the Coldwell well-houses.**

| Area | Walk-through | Partly solid | Invisible collider | Floating | Total |
|---|---:|---:|---:|---:|---:|
| saltfell_steading | 1 | 0 | 5 | 1 | 7 |
| lowe_barrows | 0 | 11 | 2 | 0 | 13 |
| kettle_fjord | 5 | 1 | 2 | 0 | 8 |
| tarnhall | 2 | 4 | 4 | 0 | 13 |
| thornwold | 2 | 2 | 55 | 0 | 59 |
| shepherds_reach | 54 | 0 | 6 | 0 | 60 |
| coldwell | 18 | 6 | 1 | 0 | 29 |

(Tarnhall and the Coldwell totals include 2 and 4 threshold steps, and one Tarnhall entry seen in one state only.)

**To route, largest first:**
1. **The Coldwell well-houses** (`wellhouse_0` at 900, -495; `wellhouse_1` at 900, -461) stand on the 45° corrie wall: ground runs from 17 m below to 12 m above the floor across each footprint, and both doors open into the slope. Needs moving or pads cut: a design call.
2. **The Reach's flock:** 54 living ewes are walked through (`"collide": false` because `FlockWander` moves them).
3. **The Coldwell's frozen figures:** 10 `unsung.glb` and 9 `upwalker.glb` dressing figures with no blocker.
4. **Thornwold:** two `rime_stag.glb` (6 × 5.9 × 5 m) walked through; 49 hedge segments whose box stands clear of the drawn hedge.
5. **Hearthstones, every area:** the kerb is 2.2 m across and the collider is a 0.38 m capsule in the fire: the kerb is walked through and the middle is an unseen post.
6. **Landmarks:** `lm_wellhead` (7.5 m, blocker far smaller), `lm_sheiling` (blocker wider than drawn), `lm_barrow_door` ×4, `lm_high_seat`, `lm_guest_post`, `lm_charcoal_clamp`.
7. **Kettle:** `drying_rack` ×2 and `net_frame` ×3 placed `"collide": false`.
8. **Tarnhall:** a 0.82 m step at both ends of a 25 × 1.4 m timber box (185/210, 25, -334).

**Limits of the audit, as its author states them:** it tests only within about a metre of navmesh joined to the starts and hearths; it samples, so a bare patch under about 0.7 m² on a partly solid mesh is missed; it does not find steps or ditches in open ground that the navmesh bridges (the Reach ditch was found by a test walker falling in, not by the audit); deck sides, stairs and ramps have no check of their own; it has not run on a GPU or Windows build.

**A note on the killed test runs earlier today:** the collision agent twice ran a kill that matched every headless Godot on this box; that is what cut off several of my runs. It stopped when told. Nothing was lost beyond re-runs.

## 2026-11-11 (night, 2): `fix/playtest-1` — playtest items 2 and 3 merged

**Suites on the merged branch (items 1, 2, 3 + the Lowe fix), run locally, all 0 failures:** `smoke` 11, `prop_hit` 65 (new), `grounded` 304 (new), `leftovers` 125 (new), `leftovers_longhouse` 28 (new), `combat` 22, `boss` 27, `encounters` 66, `audio` 40, `anim` 148, `lowe` 25. **Walks on the merged branch, all 0 failures:** `fullslice` 106, `fullgame_lowe` 194, `fullgame_kettle` 197, `fullgame_tarnhall` 211, `fullgame_thornwold` 160, `fullgame_reach` 195, `fullgame_coldwell` 178. Not re-run here: the two ending walks, and the default full suite as a whole.

### Playtest 2: "enemies/bosses and their objects persist after they die (ice oars, first boss)"

- **Ice oar.** It is drawn with a `material_override`, and `RH.set_dissolve` only drove surface materials, so it never shattered; it also stopped following his hands at death. It hung whole in the air, 2.15 m from his hands, until the body was freed about 4 s later. Now it shatters with him and stays in his hands.
- **First boss.** The Netmender's raised Sea-weight net was only taken down by the strike: a stagger, the phase-three change or her release during the windup left it over her head for good, through THAW and back. It is furled whenever she leaves the attack. This is the only leftover of hers the count found; **I cannot confirm it is what the owner saw.**
- **A wider leak.** Everything a foe makes is parented to the spawner, and a reset (the Bearer dying mid-fight, a rest) freed only the body: the Turfwright's bay walls and the Ice-Cutter's ice band (life 9999) stayed until the area was rebuilt; ridges, pools, holes and cinders lived out their timers; the Host's risen guests were never seated again. One mechanism now (`Enemy._own()`, cleared on death, release and reset).
- **Behaviour changes that follow:** a dead Keener's or Cairn-carrier's projectile in flight goes out; a dead Ice-fisher's hole and a dead Cairn-carrier's cairn close or shatter at once.
- **Tests:** `leftovers` (all 26 enemy ids, every move, death / release / reset / real Bearer death / a rest's turn) **125 checks, 18 failures before, 0 after**; `leftovers_longhouse` (the real fight and release through the real veil, then THAW and back and a reload) **28 checks, 3 failures before, 0 after**. The agent also ran every `*_encounters` suite, `deathloop`, `release_scenes` and `endings` green.
- **Not verified / open:** nothing was rendered, so how the oar's shatter and the furled net look is unseen. SLICE.md §6 says the net slides off her and Brede settles by the hearth trench: that does not happen (Brede stays on her back), and was left alone as new work. After a reload a released Holdfast is not in the rebuilt area, for every Holdfast but the Leadvoice (`release_stays`); the lore does not say which is meant.

### Playtest 3: "particle effects when striking props: wood chipping, metal sparking"

- **Surface tags:** `data/surfaces.json` (wood, stone, metal, ice, cloth, turf, snow), stamped as a `surface` meta on every collider the builders make, from what they already know (kit overrides, material family, landmark file, scatter kind, collider kind); terrain is settled at the blow (turf, shingle, plank, snow in RIME). An optional `"surface"` key on any spec wins. All 706 world colliders in built Saltfell carry a stamp; every kit id and family in the seven areas resolves.
- **The hit:** `src/combat/prop_strike.gd` ray-traces the blade (grip to tip, and the path swept since the last tick) against the world layers during the active window; enemies are never candidates. One burst per swing per prop at the contact point, off the surface normal; no damage, no hit-stop; shake only if the surface's data says so. Everything is data (`game.json` `prop_hit`, `surfaces.json` `fx`).
- **Sounds:** 14 new synthesized strikes, two per surface (`tools/audio/synth.py`, listed in `data/audio.json`, PROVENANCE row), positional. **Nobody has listened to them.**
- **Tests:** `prop_hit` 65/0.
- **Screenshots:** `docs/screens/prop_hit_sheet.png`, `prop_hit_swing_crate.png`. **Honest read:** sparks, ice shards and the snow puff read clearly; wood chips, turf clods and cloth fibres are small and hard to pick out, and in the real swing at a crate the chips are essentially not visible. Every solid chip rendered near-white and the sparks cream: the agent traced that to vertex colours treated as linear and fixed it **after** its last screenshot, so no screenshot shows the fix. This needs a real-GPU look: colours, chip sizes and counts, the spark flash, the sounds.
- **Other notes:** a swing on flat ground does not reach the turf (the ground bursts on banks and slopes). Foe weapons: the hook is in `enemy.gd` but dormant (no enemy in the data carries a traced weapon). Decals: skipped. Guessed surfaces to review: unstamped/invisible blockers are stone, shortcut gates wood, feast horns stone, sheep and rye sacks cloth, `lm_charcoal_clamp` turf. One-line stamp edits were made in files other owners hold (`building_gen.gd`, `forest.gd`, `scatter.gd`, `kit_lib.gd`, `enemy.gd`).

### Still in flight
Playtest 4 (the collision audit): not yet reported.

### `feat/intro`
Reach 195/0 (its Sigga check updated to the bug-4 fix) and Tarnhall 211/0 on re-run: the porch failure did not repeat. The Lowe walk there still fails 2 checks until this branch's bog-box fix reaches it.

## 2026-11-11 (night): `fix/playtest-1` — the Lowe on main, the chain, and playtest item 1

**Branch:** `fix/playtest-1`, cut from `origin/main` 300ce5f (main's CI triggers; no branch CI). `feat/intro` now carries main's `.github` too. Local results only, as asked.

### The Lowe on main (priority item)

- **Cause.** Not terrain or water height. The THAW box that keeps pathing out of the black water (`gen_lowe.py`, a `nav_only` blocker) was 2.5 m tall, and the navmesh bakes a floor on top of whatever it is told to keep off. Its lid (y 46.4) had come within a step of the rim's high ground on the south-east side, so the THAW navmesh climbed onto the lid and ran across it to a point over the peat island (path end (-40.6, 46.8, -187.9), 2 m above the island). Reproduced here on a8092e4 and on 300ce5f. Neither `gen_lowe.py` nor the Lowe's JSON changed since the walks last passed; what changed is the ground near the rim (the trap ramps of 0480423 / `terrain_patch`) or a wayside group there; I did not bisect which.
- **Fix.** The box is 14 m tall (`tools/gen_lowe.py`, regenerated with `--keep-terrain`; the JSON diff is that one number). Commit `Keep the THAW navmesh off the lid of the Lowe's bog box; stop the chain on a failed walk`.
- **Totals on 300ce5f + the fix:** `lowe` 25/0, `lowe_encounters` 98/0, `smoke` 11/0, `fullgame_lowe` **194/0**. Both static audits clean for the Lowe.
- **What I could not reproduce.** Here the regression failed 2 checks ("no THAW route to the peat island", and the same check after the release), and the rest of the walk passed. The GPU worker saw 25, including "the Bearer stands on the bog ice (y 31.58, ice 43.96)" and STILLED. I have no explanation for the other 23 on that machine beyond the first failure; please have the walk re-run there on this branch, and send the log if it still fails past the bog.
- **The same trap exists wherever a `nav_only` box is short.** I did not audit the other regions' nav-only blockers for lids within a step of high ground.

### The chain script

`tools/qa/fullgame_chain.sh` `run()` now keeps each walk's output, reads its last `RESULT: N checks, M failures` line, and stops the chain (naming the walk, and saying nothing after it is run) unless that line exists and reports 0 failures and the exit code is 0. Before, it trusted the exit code alone, which evidently came back 0 on the GPU box. **Not run end to end here.**

### Playtest 1: "animations break, and they start hovering, like after reading a sign"

- **What it is.** The Bearer gliding over the ground frozen in his idle pose, legs not cycling. Foot and hip heights measured at floor level throughout: nothing is drawn above the ground.
- **Root cause.** `Player.lock_control(true)` (`player.gd`) plays "idle" when a menu or panel takes control mid-stride. On the humanoid rig `CharVisual.play("idle")` started idle as an *action*; idle loops, so the action never ends, and `HumanoidRig.locomotion()` returns early while an action owns the rig. Nothing hands it back on unlock. It needs a move key held as the lock lands, and lasts until the next attack, roll or stagger. Affected: lore panels and plaques, notes, looked-at pickups, the Pack, the hearth sheet closed without resting, grab holds, the frost veil step-through. (Talk and rest already called `back_to_idle()` on the way out.)
- **Fix** (commit 60be224, 19 lines in `src/chars/`): `HumanoidRig.settle()` hands the rig back to locomotion; `CharVisual.play` routes idle/walk/run on a humanoid to it instead of starting an action. **For the animation owner:** boss phase transitions that default to `anim: "idle"` now settle the gait instead of holding an idle action.
- **Test:** new suite `grounded` (31 hand-back cases entered mid-stride: grounded, in control, the stride really cycling, an attack can start). **Before the fix 304 checks / 27 failures (9 cases); after, 304 / 0.** On this branch after the merge: `grounded` 304/0, `smoke` 11/0, `anim` 148/0; the agent also ran combat, body, deathloop, keepsakes, steading, boss, encounters green before the merge.
- **Limits.** Headless only; not checked on the Windows build. If the owner means the body literally drawn above the ground, this is not that: a screenshot or the spot is needed. No foe bug found in the cases tried.

### Still in flight on this branch
Playtest 2 (enemy leftovers), 3 (prop hit effects), 4 (collision audit): one agent each, not yet reported.

### `feat/intro` after the five bug fixes (walks run there before this branch was cut)
Coldwell 178/0, Outsong 160/0, Hearth Kept 193/0, Kettle 197/0, Thornwold 160/0. **Reach 195/1:** a stale check ("Sigga cannot be spoken to here") that the bug-4 fix deliberately changed; not yet updated. **Tarnhall 211/1:** after leaving by the front doors the Bearer did not settle on the porch inside the walk's time limit (he was out through them, 15 m on); not re-run, so I cannot say flake or effect of the new navmesh rebake when a veil falls. **Lowe 194/2:** the main regression above. So `feat/intro` is not fully green on the walks yet.

## 2026-11-11 (later): the intro — `feat/intro`

**Branch:** `feat/intro` from `origin/main` a8092e4, pushed. Messaging to the lead is still refused, so this is the report.

**What it is.** A new journey opens, once, on a skippable opening of nine cards (84 s of beats, about 85 s with the fades), after the winter is chosen and before the Strand. There was no earlier intro to replace: New journey went title → slot → difficulty → the Strand. It is `IntroDirector` (`src/core/intro_director.gd`), started from `world_root` on a fresh, interactive journey; every beat is data (`data/game.json` `intro`: text, seconds, camera, what turns). Lore doc: `docs/lore/INTRO.md`.

**How it is filmed.** In the real Saltfell, with a camera of its own: the Longhouse in THAW down the long tables; the same room held while the frost wave comes down the hall; the room in RIME; up the hall to the Netmender mending (unnamed); the Bearer kneeling at the cold Salt House hearth; the coal taking and the melt going out across the yard; inland over the barrow hills; the Bearer on the Strand under the cliff. Music is the world's own: the THAW theme, dying under the frost wave into the RIME theme, and back with the coal. The HUD is away throughout.

**It keeps nothing.** The waves run through `StateDirector.transition(..., persist=false)` (new: no World state written, no save) and can be cancelled mid-wave (`StateDirector.cancel()`, new). The hearth it kneels at is not lit. The frost-taken that stand while RIME is shown are held still and given back. It ends, sat through or skipped, with Saltfell in THAW, the Bearer on the Strand with his own camera, control and the HUD back; then SALTFELL and THE STRAND are named as before (`ZoneTitles` waits for it).

**Once.** World flag `intro_seen`, raised as it begins and carried by the save. A load never plays it. A new journey on any hearth does (the flag is the journey's, not the machine's).

**Skip.** Hold E, Enter or Esc for 0.9 s at any card. Any key shows *Hold E to skip* in the corner for 3.5 s.

**The cards** (lower third, body serif, bone on coal; facts from `SPEC.md` §2 and `WORLD.md` §1–2 only, nothing from §3–4; the last Holdfast is "the one who stopped the singing first", as SPEC puts it):

1. **`hearth_law`** (9 s) — In Rimeholt a hearth is not let out while one of its household lives. When the last one dies, the neighbours let it go on purpose, with a song.
2. **`outsong`** (9 s) — The song is the Outsong. It is sung the night after a burial, in masks, so the dead cannot find the face they loved best, and go.
3. **`sickness`** (10 s) — One midsummer a coughing sickness came up the fjords. House by house, nobody could bear to start the song. They kept their dead by the fire one more night, then one more.
4. **`frost`** (8 s) — The warmth of the world went into keeping them. The frost came in the middle of summer and has not left.
5. **`holdfasts`** (10 s) — Those who would not let go are the Holdfasts. They have grown into what they kept hold of. To release one is to sing the song they could not, for their dead.
6. **`bearer`** (9 s) — You were sent down the coast as a child, before the sickness, with a coal from the hearth in a horn. You kept it fed. It is the last live coal in Rimeholt.
7. **`hearthstone`** (10 s) — Set the coal on a cold hearthstone and the stone remembers its last warm evening, and whoever sat at it. Leave the stone cold and the place is as the frost left it.
8. **`coldwell`** (9 s) — Every river in Rimeholt starts at one spring under the ice, the Coldwell. The one who stopped the singing first is up there.
9. **`choice`** (10 s) — When you reach it you can sing, and the spring comes, and the remembered evening is gone for good. Or you can keep the coal, and the evening, and the winter.

**Screenshots:** `docs/screens/intro_01_hearth_law.png` … `intro_09_choice.png`, 1280x720, each card held in the intro's own camera (`tools/qa/intro_shots.sh`). I looked at all nine. Two were reframed after the first look (card 9 had the text over the Bearer; card 8 had a wall at the frame edge). Things to know: the Coldwell cannot be seen from Saltfell, so card 8 is the hills the road climbs toward; the Bearer kneels at the hearth with blade and shield in hand, as at any rest; card 3's capture shows the room already frozen (the capture snaps the wave; in play the wave crosses it).

**Tests.**
- New suite `intro`: **65 checks, 0 failures**. Through the real front door: plays once after the difficulty pick (The Hard Frost holds); every card in order and whole; HUD away; the frost wave shown and not kept (World never says RIME, nothing saved); nothing frost-taken turns to the Bearer; no prompt until a key; the camera never under the ground; hand-over on the Strand; no replay on Resume; plays again for a new journey on Hearth II; held mid-wave it lets go; and let go at each of the nine cards in turn.
- `fullslice` skips it at the first card and asserts it (now 108 checks): **0 failures** run on its own.
- `smoke`, `endings`, `deltas`, `steading`: pass. The `fullgame_*` chain starts from saves, so it never meets the intro; not re-run.
- **One unexplained failure to watch:** an earlier `fullslice` run on this branch, while a screenshot render was using the other cores, never released the Netmender (0 deaths, the 480 s limit ran out) and failed 25 checks from there on. The intro step had already passed in that run and the rerun alone was clean. I have not found the cause.

**Not done yet:** open bugs 1–5 from the ranked list (next).

## 2026-11-11: clean stopping point — report for the lead

**Branch:** `fix/qa-regions`, with `origin/main` fb1b369 merged in. The sha is the branch head on the remote. **Messaging is still one-way**: every `send_message` to the lead is refused (`elevated_session_untrusted_device`), so this file is the report.

**Walks that pass end to end** (steered Bearer through the real world scene, every Holdfast's AI running all its phases, each walk started from the save the previous one wrote; all 0 failures on the final merged code):

| Walk | Checks |
|---|---|
| `fullslice` (Saltfell) | 106 |
| `fullgame_lowe` | 194 |
| `fullgame_kettle` | 197 |
| `fullgame_tarnhall` | 211 |
| `fullgame_thornwold` | 160 |
| `fullgame_reach` | 195 |
| `fullgame_coldwell` (to the choice) | 178 |
| `fullgame_ending_outsong` (twice: credits skipped, credits sat through) | 160 |
| `fullgame_ending_kept` (twice) | 193 |

The default `tools/test.sh` run passes too. The region walks are **not** in the default run: CI runs them as the `fullgame` matrix job, one per walk. `tools/qa/fullgame_chain.sh` chains slice → regions → endings in one go, rewriting the saves; the script itself has not been run end to end (the chain was run walk by walk with the same commands).

**Regression on `main` fb1b369, fixed here (please take this even if nothing else):** look pass 5's frozen-net model in the Longhouse veil brings its own solid collider on the world layer. It walled the Longhouse doorway off in both memories and on the navmesh: `fullslice` failed 10 checks and the Outsong's return to Saltfell failed 6 on `main` as merged. Veil dressing now drops any collider it brings (`frost_veil.gd`, `_hero`).

**Not done:**
- **The screenshot pass.** No `docs/screens/qa_*` exist and nothing was judged by eye. The runner (`tools/qa/fullgame_shots.sh <region>`) is in and the driver walks the real front door when it has a window, but the first run was stopped for this stopping point. Three fixes need eyes in particular: the Tarnhall byre door and its veil in the 0.2 m slot between the gables; the Kettle fish-house walks moved to the doors; the staged credits shot.
- **The HUD-during-the-Outsong bug was not reproduced.** In the live path the HUD is hidden at every beat and through the credits (now asserted); the title-card layer was the one leak found and fixed. If a GPU shot still shows it, the exact command is needed.
- Every fight was judged on **The Gentle Thaw** (the slice walk picks it).

**Bugs fixed:** the full table is `docs/qa/REGIONS_QA.md` (16 rows). The ones a player would have hit hardest: every seam bounced the Bearer back; two worlds stacked after Return to the Title → Resume; post-release THAW scenes never appeared in the same visit; a fallen veil returned as an unseen wall; release drops lost on save-and-resume; the Lowe's bog drowning the Bearer on the dry road; the Kettle fish-houses with no way in; the Tarnhall hall-to-byre door that was two walls; the Host's guests re-seated by a rest; the released Leadvoice gone after a resume, so the endings played to nobody; foes attacking through the endings; the Outsong cut off by the melt wave; a kept save with no pause sheet.

**Bugs still open (ranked; detail in `REGIONS_QA.md`):**
1. The Wellhead ring is open on every side in RIME: the last duel can be started unsealed or walked out of.
2. The Ice-Cutter's hole is certain death if the Bearer is on the disc when it opens.
3. The Host's hall doors can probably be unbarred from inside mid-duel (code reading; not tried).
4. Calder's first audience after the release is the pre-release one for a Bearer who rested first; Sigga's lines and the fleece are then unreachable.
5. A ward is attuned when the Bearer meets the Unsung (the first Song learned attunes itself and stays); nothing tells the player they need a Song that strikes.
6. The Knucklebones thread cannot close in the chained run (the slice walk never takes the Saltfell four).
7. Release drops are still runtime-only in Tarnhall and the Coldwell.
8. Kettle Fjord, Thornwold and Shepherd's Reach define no shortcut; the Reach has one Keepsakes thread.
9. The Byres hearth wakes the Bearer 3 m from a Hall-champion; "Tip the horn" is 6 m in radius against the doc's 6 m across.
10. Kettle's navmesh climbs decks the Bearer cannot; several boss moves never showed in the real duels (lash, Count them, Held note, Long note).

**The `tarnhall_encounters` second-bench flake:** test-only, made deterministic; not reproduced here before or after. Please re-run on the fast machine.

## 2026-11-10 (late): status for the lead — regions 2–5 pass; Reach, Coldwell and endings started

**Messaging is still one-way.** Every `send_message` to the lead is refused (`elevated_session_untrusted_device`). Your messages reach me; my replies only land here.

**Passing end to end today** (steered Bearer, real world scene, Holdfast AI running all three phases; run together on the combined branch before `origin/main` feb47ba was merged in; the re-run on the merged code is in progress):

| Walk | Checks | Failures | Starts from |
|---|---|---|---|
| `fullslice` (Saltfell) | 106 | 0 | the front door |
| `fullgame_lowe` | 193 | 0 | `fullgame_after_saltfell` (real) |
| `fullgame_kettle` | 195 | 0 | provisional save (to be repointed at `fullgame_after_lowe`) |
| `fullgame_tarnhall` | 210 | 0 | provisional save |
| `fullgame_thornwold` | 159 | 0 | provisional save |

Not yet: Shepherd's Reach, the Coldwell, both endings, the single chained start-to-credits run, the screenshot pass, `docs/qa/REGIONS_QA.md`.

**Top 10 bugs found (all fixed on this branch unless marked):**

1. **Every seam bounced the Bearer straight back** to the area he had just left (`area_portal.gd`).
2. **Two worlds stacked after Return to the Title → Resume** once any seam had been crossed: the title return freed a stale area reference, Resume built a second copy on top, and hearths/turning acted on the old one (`world_root.gd`).
3. **Post-release THAW scenes never appeared in the same visit** (Arne and the twins, Pell and Ivo, Linnet and Eyvind at the gap): flag-gated souls and finds were only placed at area build. Now re-read at the release, at a rest and when the memory turns, through one path (`AreaBuilder.sync_flagged`).
4. **A fallen frost veil came back as an invisible wall** on the next turn to RIME or navmesh rebake, in every region (`frost_veil.gd`).
5. **Release drops were lost for good on save-and-resume before pickup**: Arne's tally-stick, Ivo's mitten, the song-cord (each ends a Keepsakes thread). Now also area data gated on the release flag, like the mending needle.
6. **The door between the Long Table and the Byres was not a door**: the two gables' doorways were 2 m apart, the veil stood in front of blank wall and its step-through carried the Bearer through two walls (`building_gen.gd`, `gen_tarnhall.py`).
7. **The Kettle fish-houses could not be entered**: each walk met a wall; the ladle and auger were only reachable through the floor from under the house (`gen_kettle.py`).
8. **Resting after the Host's release re-seated his five guests as live enemies** (`spawner.gd` honours `absent_flag` on respawn).
9. **The Lowe's lowered drawbridge did not meet the Saltfell lip, and ravine/deep-water volumes took a body merely near them** (`drawbridge.gd`, `hazard_volume.gd`).
10. **`Game.test_boss_dmg_mult` only worked on the Netmender**; the Turfwright, Ice-Cutter and Hedgelayer now honour it (test seam only). Also: a laid-down Hedgelayer gate and Kettle's new ice sat in the wrong state layer; overheard lines played over a talk; a foe's swing on a cairn raised a script error; the Turfwright wedged on his own bay walls.

**The `tarnhall_encounters` second-bench flake:** test-only. The Bearer's run was laid out from wherever the Host had drifted; near the arena wall his velocity dropped to zero and the lead-target bench was correctly not thrown. The test now re-seats the Host, runs a clear lane and waits for the throw instead of counting ticks. Not reproduced here before or after (3/3 pass, once under `--fixed-fps 60`); please re-run on the fast machine.

**Open, for a decision or another owner (not changed):**
- Thornwold and Kettle Fjord define no shortcut (no gate, no flag). The walks prove the nearest thing (the laid gate; the RIME ice between the hearths).
- The Ice-Cutter's hole-opening move is certain death if you are on the disc when it breaks (poise damage equals base poise: 0.7 s stagger of a 1.0 s sink). KETTLE.md says "off it in a second".
- The Host's hall doors can probably be unbarred from inside mid-duel (no aux seals on that veil). From reading the code; not tried.
- The Byres hearth wakes the Bearer 3 m from a Hall-champion.
- "Tip the horn" frost is 6 m in radius; TARNHALL.md says 6 m across.
- The Collier "on the road" stands 7 m off it, outside the thorn lane.
- Sten stays on his crate after Halla says he is in the end house.
- The Kettle navmesh climbs decks from the side (0.5 m); the Bearer cannot (0.35 m).

**CI:** the region walks are out of the default `tools/test.sh` run (a quarter of an hour each) and run as a `fullgame` matrix job, one per region.

## 2026-11-10: first finding, and the regions are in flight

- **Bug fixed (`src/world/area_portal.gd`): every seam bounced the Bearer straight back.** Walking over the pass from Saltfell arrived in the Lowe and, one physics frame later, the Lowe's own seam (same ground) fired from his pre-move position and carried him back to Saltfell. An auto seam now only fires for a body really inside its box. Found by the first steered walk over a seam; the narrower suites call `travel_to` directly and never saw it.
- **In flight:** one agent per region (the Lowe, Kettle Fjord, Tarnhall, Thornwold), each writing `tools/test/fullgame_<region>_test.gd` in its own worktree; I merge them into `fix/qa-regions`. The slice walk passes 106/106 on this branch and wrote `tools/test/fixtures/fullgame_after_saltfell.json`.
- **Next:** merge the region suites, chain the real fixtures, then the 1280x720 screenshot pass and `docs/qa/REGIONS_QA.md`.

## 2026-11-10: ack, and messaging is one-way

- **Ack.** The QA environment is up: Godot 4.7 on PATH, xvfb + lavapipe installed, project imported.
- **Direct messages to the lead fail.** `send_message` to `session_01F3vrUNPtFufos1qRX6SLeD` is refused with `elevated_session_untrusted_device` (the lead's session needs a trusted device; this session cannot be vouched for). Reports go here until that changes. The lead can still message this session.
- **Plan.** A shared driver `tools/test/fullgame_base.gd` (the slice walk's steered Bearer, started from a save fixture through the real world scene), then one suite per region: `fullgame_lowe`, `fullgame_kettle`, `fullgame_tarnhall`, `fullgame_thornwold`. Each starts from `tools/test/fixtures/fullgame_after_<previous>.json` and, with `--fullgame-write-fixture`, writes the save the next one starts from. `fullslice` gained `--keep-save=PATH` to produce the first fixture.
