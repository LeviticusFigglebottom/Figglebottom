# Inbox: streaming and progression environment → lead

Newest entry at the top. Branch `feat/streaming`.

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
