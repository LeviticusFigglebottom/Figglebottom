# Live handoff: Rimeholt

_Last updated: 2026-11-12 (integration session: `feat/integration-1112`; the sections below it are the lead's of 2026-11-10)_

Read `docs/handoffs/live/TEAM.md` next: it has the roster, file ownership and how the sessions talk.

## Main moved to a37afed (2026-11-12 ~11:55 UTC), on the owner's request, ahead of the last gate

The owner asked for main now so they could play it. Main = `feat/integration-1112` at a37afed.
**Known breakages on main:**
- `fullgame_tarnhall` fails 3/211 on GitHub CI (e.g. "the cup, the barrel head, the cleaver and the Goat Song are in the Pack"); passes on the PC and cloud box most runs. Fix in progress on `fix/tarnhall-walk`.
- The owner's PC was still running the full suite and the remaining walks at 740ca4d when main moved; fullslice is green ×4 there.
- Map images not rebaked after the POI merge (`fix/map-rebake`); spear/greatblade/bow not obtainable (`feat/weapon-finds`); perf ~halved (CPU script time) and THAW too dark under cliffs on real GPU (PC jobs A/B); area-change hitches (`feat/streaming`).

**Next exact step:** merge `fix/tarnhall-walk`, `fix/map-rebake`, `feat/weapon-finds` into main once each is green (`tools/test.sh` + touched walks), dispatch `ci.yml` with `fullgame=true` on main.

## Integration branch `feat/integration-1112` (2026-11-12): merged to main

**What it is.** `origin/main` 024ff96 (sounds redo, painted icons, Journal, Map) with these merged in, in this order: `feat/weapons-overhaul`, `feat/poi-kettle-tarnhall-coldwell`, `fix/playtest-1`, `feat/poi-thornwold-plants`, `feat/intro`, `art/biomes`, `feat/poi-saltfell-lowe-reach`. Not merged: `feat/streaming`. Main was not touched.

**Next exact step (lead).** Read the results below, then:
```
git fetch origin && git checkout main && git merge --ff-only origin/feat/integration-1112 && git push origin main
```
The last green point before the Saltfell, Lowe and Reach merge is commit `7e4f172`, if that merge has to be backed out.

**Rules the merges settled (read before editing these files).**
- **Journal steps** (`data/keepsakes.json`): every step has `flag`, `objective`, `line`. A thing shown to somebody is an `optional` step (`needs_item`, `after`), never a second entry in `steps`. Tests read it through `Journal.view_of(Journal.thread_def(id))["done"]`.
- **Plants:** the order is written at `Scatter.region_rules` (`src/world/scatter.gd`): area rules, then the region recipe (`data/veg/<area>.json`), then the biome file's `density` and `swap` over the whole list (`Biome.veg_rules`), applied once in `Scatter.build_veg`.
- **Scatter collision:** one rule. Rocks, boulders, driftwood, peat stacks, walls and rows, standing stones and upright floes collide as the hull of their own mesh once they stand 0.55 m out of the ground. `solid_small` is gone.
- **Prop strikes** play `AudioDirector.impact(surface, position)` (`data/audio.json` `impacts`). The fourteen synthesized strike takes were not carried over.
- **Terrain:** all seven regions were regenerated in full from the merged generators (`python3 tools/gen_<region>.py`). The far-ring bins of every region changed with their neighbours; regenerate all seven after any terrain edit.
- **A board with a caption in one state only** stands solid in both (`gen_kettle.py`, `gen_tarnhall.py`), and a tagged board's collider is on its state's layer.
- **Props:** `"tilt"` is a pitch or `[pitch, roll]`; a pickup's display offset is `"show_off"` or `"show_at"`.

**Verification on the final state** (local, headless; see the session's report for run counts):
- `tools/check_originality.sh --all`, `tools/audit_edges.py`, `tools/audit_areas.py`: clean.
- Default `tools/test.sh`: 44 suites, 2,975 checks, 0 failures.
- Walks, all green on the final walk code: `fullslice` (6 runs), `fullgame_lowe` (4), `fullgame_reach` (3), `fullgame_kettle`, `fullgame_tarnhall` (2), `fullgame_thornwold`, `fullgame_coldwell`, both endings. See "Known breakages" for the slice walk on the owner's PC.
- Collision audit: 219 baselined offenders (189 before), each with an owner in `tools/test/fixtures/collision_baseline.json`. New owners: the three POI agents (`data/collision_audit.json`).

## State (on main fd881f6)
The whole game is on main, in structure:
- **Seven regions.** Each has its landscape, encounters, a three-phase Holdfast, NPCs with Keepsakes threads, and a release.
- **Both endings** (the Outsong, the Hearth Kept) and credits. See ADR 0013.
- **The Bearer's combat clip library** (ADR 0011). Foe and boss attack clips are cut to their data windups (ADR 0012, pass 3).
- **Look passes 1–4:**
  - CC0 PBR texture library
  - Tripo rocks, trees, hedges, props and gables
  - textured grass
  - a painted sky per state
  - the Tripo hearthstone everywhere
  - card flames
- **Real-GPU work:**
  - VRAM compression
  - the water's sky term under SDFGI
  - fog pockets
  - nav re-path throttle
  - weather on GPU particles

**Tests.** About 1,400 checks across some 27 suites; CI runs them on every push. One known flake: `tarnhall_encounters`, "the second goes where he is running to". The QA env owns it.

**Windows build.** The GPU worker exports it on the owner's PC, to `C:\Users\Aaron\Documents\Rimeholt_Windows_<date>_<sha>\Rimeholt.exe`. CI artifacts upload for main only (the storage quota was hit).

## In flight
| Who | Branch | Work |
|---|---|---|
| GPU worker (owner's PC) | `gpu/npc-wiring`, `gpu/perf-3` | Rebuild the exe from main; wire the maren, wren and old_calder models; foe-foe crowding |
| QA env (cloud) | `fix/qa-regions` | End-to-end walks for regions 2–5 (extend to Reach, Coldwell and the endings next); the bench flake |
| World-fidelity env (cloud) | `art/world-fidelity` | Exposure per state, cliffs, snow, the Coldwell horizon, building construction detail, interiors |
| Lead's agents (this box) | `feat/anims-4`, `art/look-pass-5` | See the task board |
| Sound (this box) | `feat/sfx-redo` (ready for review) | Every sound effect and ambience bed rebuilt from CC0 recordings; the THAW/RIME bed handover follows the wave front. `docs/audio/SFX.md`. **Nobody has listened yet: the owner must.** Rebuild: `python3 tools/audio/build_sfx.py`; check: `tools/test.sh audio`. Hit-VFX sessions call `AudioDirector.impact(surface, position)`. |

## Open questions for the owner
- **Tripo calls:** paid generation was blocked by this session's permission system on 2026-11-10. Eight prop references and the ewe rigs are waiting on it.
- **Music:** nobody has listened to it yet.
- **Player hitbox:** it stays a data box and does not follow the blade. That was a feel decision; change it only if the owner asks.

## Known gaps
- Real-GPU look: THAW exposure blow-out and faceted cliffs (world-fidelity env).
- RIME constructs: frozen thorn, frost veils as flat cards.
- `feat/anims-4` (not merged): body armour swaps the Bearer's model (`items.json` `armour.model`); the new-region foes, the Leadvoice and the ending beats have their own clips (ADR 0012 pass 4). Left over from it:
  - `fix/rig-fixes` (ADR 0012 pass 5) answers the model faults: the Host's, Fellcaller's and Leadvoice's spare arms are cut off, the Leadvoice's cloak hangs from her hips and spine and her `shelter` closes her arms on the child, the Fellcaller calls with a horn prop in her fist (the belt horn is fused to her dress and stays), Old Calder has a keyed `sit`, and `bearer_hall` is the Hall-Guard's Coat (`armour_hall`, a pickup inside the hall doors in RIME). Left over: the Host's table still crumples when his arms go up; the Leadvoice's arms have no elbow (her rig runs its forearm bones down the cloak); sat, her ground ice is under the floor; REACH.md has Calder stood after the release, so nothing seats him yet.
  - None of it has been seen on a real GPU or in a fight: sheets only (`docs/screens/anim_*`). Rebuild: `$BPY tools/anim/build_combat_lib.py && python3 tools/anim/quad_poses.py && godot --headless --path . --import`.
- Ottar has no model.

## Tripo access (for future sessions)
- **Tool:** the unofficial `Neko-Yukari/tripo-studio-mcp`. Clone it into the scratchpad and run it with `TRIPO_GATEWAY=0` and `TRIPO_STUDIO_STATE=<scratchpad>/tripo/studio-state.json`.
- **Cookie:** the owner's `ory_kratos_session` cookie, from Google Drive file `tripo-session.txt`. Never commit or print it.
- **Balance:** 24,700 credits at the start (premium plan, valid until 2026-12-06). It was 24,185 after the pilot.
- **Studio-state file:** the setup is in `tools/art/README.md`. Fresh sessions also need `bpy` in a Python 3.11 venv and `mesa-vulkan-drivers`.

## Owner decisions
- **Title:** confirmed as "Rimeholt", subtitle "The Winter That Would Not End".
- **House card:** keep the "Figglebottom Productions" house card on boot. Make it sincere and quiet, with no jokes.
- **Story:** it must be genuinely profound about grief and not letting go, told the soulslike way. That means item text, places and fragments, with no AI-writing tics. The rules are in `docs/lore/WRITING.md`.

## Open questions for the owner
- None right now.

## Known breakages
- **`fullslice` is red on the owner's PC and green here.** At 0cac9ad the PC failed it twice, at different places (the float's prompt; the Netmender, six deaths), after passing it before the Saltfell, Lowe and Reach merge. On this box it passed six times on the merged code, one of them with drawn frames held to four a second. Cause not found. Next step: have the PC run `tools/test.sh fullslice` alone, with nothing else running, and send the whole log, not only the FAIL lines. The walks now keep a save directory per process, so two runs at once cannot write over each other.
- **`fullgame_reach` leaned on luck in two places,** both in the walk's driving: a scatter stone on the straight line over the beck ice, and the fold cache inside the Drift Lane's walls with foes on the far side. The walk now follows the planned path over the ice and goes back for the cache (`_leg_slope`). Three runs green since. `fullgame_tarnhall`'s porch leg comes back from a fight the same way.
- **A dense convex hull can lose the Bearer.** The hide tent `kf_ice_hut_b` (a 186-point hull) stopped being named as a wall to a capsule sliding along it, `Player._unpin` then lifted him and he walked in. That piece now asks for a 32-point hull (`"hull": "simple"` in `KitLib.PIECES`). Other Tripo props with hulls that dense have not been walked into one by one.
- **Decision records 0006 and 0011 each exist twice** (on main already). Not renumbered here.
- **`data/map.json` and the baked map images were not rebuilt** after the points of interest moved ground (`tools/ui/build_map.py`).
