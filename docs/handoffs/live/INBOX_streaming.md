# Inbox: streaming and progression environment → lead

Newest entry at the top. Branch `feat/streaming`.

## 2026-11-12: follow-ups merged (73013bf); **do not merge to main yet: exit hang found**

**Known breakage on this branch.** The process can hang on quit while a worker build is in flight. `fullgame_tarnhall` and `fullgame_reach` both reported 0 failures and then never exited (killed by the 45-minute limit). After the result line the log repeats `BuildLock: a worker build did not end in 120 s` from `Streamer.reset` in `_exit_tree`. Both walks end beside a seam. The same would hang the real game when the player quits near a seam. Cause not yet found; the fix and a fast-failing regression test are in work now.

**Merged since the last entry.**
- **Gate and bridge navmesh re-bakes run in the background.** Was 622 to 756 ms in one frame; now 10 to 15 ms worst frame of nav work (one bridge run: 26 ms). Routes open 0.5 to 0.6 s after the Holdfast falls. Tests wait with `TestBase.nav_wait()` / `await area.nav_settled()`.
- **Bridge behaviour change:** the re-bake now follows the deck's swing. Before, it ran with the deck upright, so the deck was never on the navmesh. The Lowe's `nav_bounds` still end 2.5 m out along the deck; covering all of it needs an area-data change, not made.
- **Cache warming.** After 2 s idle, neighbours' terrain and ground-cover entries are computed on a low-priority worker. `tools/qa/warm_cache.sh` fills all seven areas. A read-only `cache_seed` folder beside the executable (or `--cache-seed=PATH`) is read if present. Export presets and CI untouched.

**Still over budget.** The release frame: `on_boss_slain` 30 to 38 ms, longest frame around the release 52 ms, after spreading the returning souls over frames. What is left is the first soul's instancing and the song's first load.

**Unproven.**
- One `Parameter "m" is null` engine error in one of six streaming runs (the weather freeing a particle node during a graft). Nothing failed.
- The cache seed was checked with the editor binary only, not an exported build.

**Suites on 73013bf, run here.**
| suite | checks | failures | note |
|---|---:|---:|---|
| `streaming` | 102 | 0 | |
| `smoke` | 11 | 0 | |
| `gates` | 151 | 0 | |
| `fullgame_tarnhall` | 213 | 0 | **then hung on exit** |
| `fullgame_thornwold` | 163 | 0 | |
| `fullgame_reach` | 197 | 0 | **then hung on exit** |
| `fullgame_coldwell` | 179 | 0 | |
| `fullgame_ending_outsong` | 161 | 0 | |
| `fullgame_ending_kept` | 193 | 0 | |
| `fullgame_lowe` | 196 | 0 | run on b613e83 here, and on the follow-up code by the agent; my rerun on 73013bf was cut off by the time limit |
| `fullgame_kettle` | | | not run: fails the same 17 on `c3721bb` |

## 2026-11-12: Job 2 merged; both jobs are on `feat/streaming` (b613e83)

**What changed.** Every region's way on is shut by a real object until that region's Holdfast is released, then stands open with a worn track leading to it. ADR: `docs/decisions/0015-progression-gating.md` (both readings of the owner's sentence, and the before/after per region).

| Region → next | Before | Now | Opens on |
|---|---|---|---|
| Saltfell → Lowe (pass) | open turf, no track | head-dyke across the neck, two stones, the Netmender's net in the gap | `ks_netmender_released` |
| Saltfell → Lowe (drawbridge) | raised, windlass on the Lowe side | unchanged | `lowe_bridge_down` |
| Lowe → Kettle | open cutting, no track | sods stacked across the cutting | `ks_turfwright_released` |
| Kettle → Tarnhall | open gully | crates and barrels across the foot of the Tarn Steps | `ks_ice_cutter_released` |
| Tarnhall → Thornwold | open notch | dyke with a barred plank gate | `ks_host_released` |
| Thornwold → Reach | 11 m opening | the Hedgelayer's hedge straight across | `ks_hedgelayer_released` |
| Reach → Coldwell | open corner | head-dyke with two tied hurdles, a cairn | `ks_fellcaller_released` |

- **Evidence for both readings.** No seam in the game had a lock: a new journey could walk from the Strand to the Wellhead Steps without meeting a Holdfast. And no track led to any seam except the Kettle Road, so the pass was open but invisible. Both were true.
- **Mechanism.** One `ShortcutGate` per exit on the base layer (same in THAW and RIME), opened by the release flag where the Bearer stands. Each can be undone by hand from its far side, so nobody is ever shut out of the region behind.
- **For the journal and map (`feat/ui-map-log-icons`):** each area def now has a `way_on` block: `id`, `name`, `to`, `at`, `seam`, `open_flag`, `gate`.
- **Generators:** edits sit inside `# --- progression gates` blocks; shared helper `tools/progress_gates.py`. One edit outside a block: a bog nav-blocker fix in `gen_lowe.py`.
- **Merging note:** six `data/terrain/*_splat.bin` changed (tracks painted). A `feat/poi-*` branch that also repaints a splat must rerun its generator after merging, not pick a side.

**Suites on the merged branch, run here:** `gates` 151/0, `streaming` 78/0, `smoke` 11/0, `steading` 49/0, `deathloop` 26/0. `audit_edges.py`, `audit_areas.py` and the originality check pass. The full-game walks on the merged branch are running now; results in the next entry.

**Suites as the gating agent ran them, before the merge with streaming:** `lowe`, `kettle`, `tarnhall`, `thornwold`, `reach`, `coldwell`, `reach_encounters`, `traps`, `release_scenes`, `houses`, `keepsakes`, `fullslice` (112), `fullgame_tarnhall` (213), `fullgame_thornwold` (163), `fullgame_coldwell`, both endings: pass. `fullgame_lowe`: 1 failure on its last run (a Breathmark left after an unplanned fight death). `fullgame_reach`: 1 failure on its last run (a flock count that passed the run before).

**For the QA env: `fullgame_kettle` fails on `main`'s parent `c3721bb` too.** 17 failures, identical with and without either job: the scripted Ice-Cutter duel is lost (stalls with the boss at 1040/1250). Not caused by this branch; not fixed here.

**Open, for the lead to decide or pass on.**
- **THAW fiction.** Each gate also stands in the remembered evening and is gone from it after the release. No lore line covers this. The Kettle stack is the weakest fit. No dialogue was written; ADR 0015 lists where a line could go.
- **73 sheep.** REACH.md says seventy; three frozen ewes at the hurdles are extra (tagged `gate_piece`, one list in `gen_reach.py` removes them).
- **RIME reveal.** Tracks are under snow in RIME, so there the cue is the emptied gap and its stones or cairn only.
- **Line of sight.** On the Lowe, Tarnhall and Thornwold the gap cannot be seen from the arena; the track starts at the arena mouth.
- **Not seen in motion or on a real GPU.** The gate's 1.4 s sinking was not watched. Screenshots are lavapipe: `docs/screens/gates_*.png` (23 files). The Lowe ones read worst (narrow, shaded cutting).
- **In work now:** gate and drawbridge navmesh re-bakes off the main thread (they fire at every release now), and warming the neighbours' cache in idle time.

## 2026-11-12: Job 1 merged into `feat/streaming` (846c6fa); Job 2 still in work

**What changed.** An area change no longer builds on the main thread. The neighbour is built on a worker when the Bearer is within 70 m of an unlocked seam, grafted in hidden and inert within a per-frame budget, and swapped in behind a dip to black. Design: `docs/decisions/0014-area-streaming.md`. Numbers and re-measure commands: `docs/qa/STREAMING.md`. Tuning: `data/game.json` → `streaming`. `--no-streaming` puts the old path back for A/B.

**Numbers** (this box: headless, four slow shared cores, no GPU; relative only).

| | before | after, warm cache | after, empty cache |
|---|---|---|---|
| main-thread work in the worst frame of a crossing | 3,750 to 13,329 ms (all of it) | 12 to 22 ms | 19 to 27 ms |
| what the player sees | a freeze of 4 to 13 s | black for 0.25 to 0.34 s | black for 0.6 to 1.2 s if the area was ready |
| neighbour made ready, on a worker | not done | 0.4 to 1.2 s | 3.2 to 12.5 s |
| freeing the area left | 67 to 101 ms in one frame | 2.8 to 4.3 ms a frame | same |
| a rest (foes brought back) | 31 to 118 ms in one frame | 6 to 8 ms worst frame | same |
| THAW to RIME, settle frame | respawn spike as above | 8 to 16 ms worst frame | same |
| cross-area respawn | full build in one frame | 13 to 23 ms worst frame | |

No measured crossing, rest, flip or respawn had a frame over the 30 ms budget.

**Not done, or not proven. Read before merging.**
- **Real GPU: nothing measured.** Upload cost, pipeline warm-up coverage and the swap frame need the GPU worker. Command is in STREAMING.md ("the one to run on the GPU box").
- **The swap is a dip to black, not a crossfade.** About a third of a second when ready.
- **First visit with an empty cache.** Saltfell (12.5 s here), the Reach, the Lowe and the Coldwell may not be ready if the player sprints the 70 m. The black then holds; nothing freezes. Once per area per machine, and again after each game update. Follow-up planned: warm the neighbours' cache in idle time.
- **Opening a gate still costs one frame of 0.4 to 1.5 s** (`ShortcutGate`, `FlagGate`, the drawbridge re-bake the navmesh synchronously). This matters more once Job 2's gates open on a release. Follow-up planned after Job 2 merges.
- **Building meshes are not cached**; they are built on the worker (0.1 to 0.6 s).
- **A worker-thread crash was seen twice mid-build** (one SIGSEGV headless, one "double free" under llvmpipe). The fix (no `StandardMaterial3D`, particle, fog or gradient resources made on the worker) is inferred, not proven; no recurrence since.
- The title's front door still builds synchronously, behind the veil; faster for the cache.

**Suites, as the agent ran them on its branch** (my own re-run on the merged branch is in progress).
- `streaming`: 78 checks, 0 failures.
- 29 other suites, all except the full-game walks: 1,568 checks, 0 failures.
- `fullslice`: two runs, one 106/0, one with 20 failures cascading from the net float's prompt on the Strand. Not diagnosed. Treat as possibly flaky, not as harmless.
- `fullgame_lowe`: 194 checks, 2 failures, the same two with `--no-streaming` ("no THAW route to the peat island", "the black water is back").
- `fullgame_kettle`: does not finish; the Ice-Cutter duel stalls. Same stall with `--no-streaming`. Not yet checked against `main` itself.
- Not run: `fullgame_tarnhall`, `_thornwold`, `_reach`, `_coldwell`, both endings.

**For other test authors:** `Game.travel_to` is now a coroutine. Wait for `Game.current_area_id` and `player.input_enabled` after a crossing.

**Files touched in other lanes, small seams only:** `scatter.gd` (ground-cover cache), `forest.gd` (lock wrappers). `building_gen.gd` and `house_detail.gd` are untouched.

## 2026-11-11: owner correction to Job 2 received

- Got the lead's message. Job 2 now follows **hint, then reveal** for every region's exit:
  - **Gate:** the onward route opens only on that region's release (unchanged).
  - **Before the release:** the way on is hinted only: the Lowe seen across the ravine, the raised bridge, a blocked pass that reads as a way later.
  - **After the release:** the way on reads without UI markers: the blockage visibly gone, a worn path, a landmark at the turn, light and composition toward it.
  - **Data:** each area def gets a "way on" entry (place, opening flag, short name) for the journal and map on `feat/ui-map-log-icons`. No journal UI is built here.
- The earlier instruction to soften paths and markers toward seams is withdrawn; the Job 2 agent has been told.
- NPC or scene lines pointing the way: only if they meet `WRITING.md`; otherwise the ADR lists where a line would go and the text is left to the lead.
- ADR 0015 will record both readings.

## 2026-11-11: both jobs started

- Two agents run in parallel on this box, each in its own worktree. Their work lands on `feat/streaming` once each is green here; nothing is merged yet.
  - **Job 1** (local branch `feat/streaming-job1`): build-phase timer first, then the preload, cache, budgeted insert and free, shader warm-up, and the `streaming` suite. Planned ADR: `0014-area-streaming.md`. Numbers go to `docs/qa/STREAMING.md`.
  - **Job 2** (local branch `feat/streaming-gates`): exit audit per region, then gates. Planned ADR: `0015-progression-gating.md`. Generator edits stay inside `# --- progression gates` blocks.
- **Evidence for the lead's reading of the owner's sentence, so far:** `tools/seams_lowe.py` makes the Saltfell cliff-top pass a 20 m wide auto seam with no lock of any kind. It is open from the first minute. The audit of the other six seams is in progress.
- No numbers yet. Nothing needed.

## 2026-11-11: ack

- Started. Session `session_01F3vrUMACDVu2qRDoYvRsVc`, branch `feat/streaming` from `origin/main` at `c3721bb`.
- Godot 4.7 stable is on PATH; xvfb and lavapipe are installed.
- **Job 1 (area-change spikes):** orienting, then instrumenting. First number to expect here: the per-phase build table in `docs/qa/STREAMING.md`.
- **Job 2 (progression gating):** auditing every region's exits against the lore docs and ADR 0003 before changing any generator.
- Commit trailers carry this session's own id, not the lead's, so the history shows which box made each commit.
- Nothing needed yet.
