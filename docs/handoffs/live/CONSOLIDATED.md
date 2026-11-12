# Live handoff: Rimeholt

_Last updated: 2026-11-10 (lead session, after the all-in merge)_

Read `docs/handoffs/live/TEAM.md` next: it has the roster, file ownership and how the sessions talk.

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

## Area streaming (`feat/streaming`, ADR 0014; not on main)
- `Streamer` (`Game.stream`) builds the next area on a worker thread ahead of each seam, grafts it hidden under a per-frame budget, swaps behind a short dip to black and frees the old area over frames. `--no-streaming` falls back to the old synchronous build. Tuning: `data/game.json` → `streaming`.
- `Game.travel_to` is a coroutine now: wait on `current_area_id` and `player.input_enabled`. Runtime navmesh re-bakes are in the background: tests use `TestBase.nav_wait()`.
- Builders that a worker can reach load scenes with `BuildLock.wload`, never `load` (a plain scene load on a worker waits for a main-loop frame and froze quit). Everything that quits calls `Game.quit()`.
- Numbers, open items and how to measure: `docs/qa/STREAMING.md`. Not yet measured on a real GPU.
- Check: `tools/test.sh streaming`, `tools/qa/quit_check.sh`, then the `fullgame_*` walks.

## Progression gating (`feat/streaming`, ADR 0015; not on main)
- Every region's way on is shut by one `ShortcutGate` until that region's Holdfast is released: the net on the Saltfell pass, sods on the Kettle Road, a stack at the Tarn Steps, the drove gate, a hedge on the fell path, hurdles at the Upwater. Each can be undone from its far side.
- Each area def has `way_on` (where, what to call it, the flag that opens it) for the journal and map.
- Gates and tracks are placed by `tools/progress_gates.py` from marked blocks in each `tools/gen_*.py` and `tools/terrain_*.py`. After merging with a branch that repaints a splat, rerun that generator.
- Check: `tools/test.sh gates` (about ten minutes), then the `fullgame_*` walks.
- For the lead: the THAW half of each gate has no line of text behind it, and Kettle's is the thinnest (ADR 0015, Consequences).

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
- None yet.
