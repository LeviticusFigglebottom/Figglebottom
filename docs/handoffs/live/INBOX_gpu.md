# GPU worker -> lead

Append-only; one entry per job.

## 2026-11-12T05:09Z Job 2: feat/streaming gate (headless) and area-change hitches on real hardware
Box: RX 9070 XT, i9-12900K, Godot 4.7.2. Headless at below-normal priority, at most 2 Godot processes at once.
The branch head moved during the run, so each line names the commit it tested.

**Headless suites**
| suite / walk | commit | checks | failures |
|---|---|---|---|
| smoke | 73013bf | 11 | 0 |
| streaming | 73013bf | 102 | **3** |
| gates | 73013bf | 151 | 0 |
| fullslice (Saltfell walk) | 25ef245 | 112 | 0 |
| fullgame_lowe | 25ef245 | 195 | **6** |

Failing lines, verbatim:
- streaming:
  - `FAIL - prepared crossing: streaming work per frame within 30 ms (30.3)`
  - `FAIL - and a route runs out onto the deck (navmesh 84.25 m from a point 1.6 m along it; raised: 84.25 m)`
  - `FAIL - and a route runs through the opened gate`
- fullgame_lowe (the bog-ice and peat-island failures seen on main a8092e4 are gone; this cluster remains):
  - `FAIL - the frost-taken bring the Bearer down`
  - `FAIL - STILLED (Stilled)`
  - `FAIL - the warmth hangs as a Breathmark in this region`
  - `FAIL - at hs_barrow_road`
  - `FAIL - with nothing carried`
  - `FAIL - the warmth is taken back (+352 of 0, first fall carried 0, 0 tries)`

**Area-change hitches on real hardware** (`stream_prof.tscn --prof-stream`, Vulkan, 1920x1080, window off-screen; commit 25ef245; full table in `docs/qa/gpu/stream_prof_gpu_25ef245.md`)

| area | worst frame cold (ms) | worst frame warm (ms) | next worst warm (ms) | what the worst warm frame held | turn to RIME worst (ms) |
|---|---:|---:|---:|---|---:|
| saltfell_steading | 238.5 | 107.2 | 45.1 | graft: what acts 107 | 54.0 |
| lowe_barrows | 89.7 | 90.8 | 38.0 | graft: what acts 88 | 53.1 |
| kettle_fjord | 85.1 | 92.9 | 63.0 | graft: what acts 90 | 54.9 |
| tarnhall | 83.8 | 83.3 | 11.3 | graft: what acts 83 | 57.5 |
| thornwold | 101.4 | 96.6 | 18.0 | graft: what acts 94 | 55.4 |
| shepherds_reach | 127.0 | 89.3 | 88.8 | graft: what acts 87 | 58.9 |
| coldwell | 100.8 | 97.2 | 13.8 | graft: what acts 94 | 57.2 |

- **Every crossing has one 83–107 ms frame, cache warm, and it is the "graft: what acts" phase.** Headless it stayed in budget, so on the GPU this is most likely render-side work done on the main thread at graft time: instancing the actors' meshes and materials, pipeline or shader compiles.
- **The cold Saltfell crossing peaks at 238.5 ms.** Its "flush: worker's render commands" phase is 1,994 ms over the crossing.
- **The turn to RIME costs 53–59 ms everywhere.** About 50 ms of it is "flip: wave particles": the particle swap is one synchronous frame.
- **Freeing the area left and resting** stay under 9 ms. Cache: 49 hits, 23 misses. The main thread waited 0.0 ms on BuildLock.
- **Measured only;** nothing changed on the branch.

## 2026-11-12T05:47Z Job 1 (early report, a failure): feat/integration-1112 gate, originality and the full suite
- **`tools/check_originality.sh --all`** at 8c160fd: rc 0, clean.
- **`tools/test.sh` (full, headless)** at **8c160fd**: 41 suites, **2,783 checks, 1 failure**, 79 min.
  - `anim`: `FAIL - the flame gutters more under RIME (0.00 vs 0.00)`
  - Its neighbours pass: "guttering never takes the light under its floor (THAW)" and "(RIME)", "the torch strikes (its own heavy)", "in hand, it is off the belt". Both gutter amounts read 0.00, so the flame does not gutter at all in the test, in either state.
  - **Intro checks pass:** "the intro opens the journey", "the intro begins once the Bearer stands in the world", "no skip prompt until a key is touched", "sat through: the intro is over", "and the intro is gone", "no intro on a load".
- **Still running, one at a time:** the fullgame walks (fullslice; fullgame_lowe ×3; kettle; tarnhall; thornwold; coldwell; reach; both endings). Each refetches the branch head first. Their counts follow in the next entry.

## 2026-11-12T05:47Z Job 5: integration export and boot (not a release)
- **Export:** `godot --headless --export-release "Windows"` at **8c160fd**, rc 0, **no export warnings** in the log. Output `C:\Users\Aaron\Documents\Rimeholt_Windows_TEST_integration_8c160fd\Rimeholt.exe`, **1,566,860,536 bytes (1.57 GB**, the pck embedded; main's a8092e4 build was 1.14 GB).
- **Boot, real GPU** (RX 9070 XT, window off-screen, `--shot-seq-now --shot-seq=3,12`): it boots cleanly to the studio card ("Figglebottom Productions", 3 s) and then the **title** (RIMEHOLT, "The Winter That Would Not End", New journey / Settings, over the Strand with the boats, 12 s).
  - No Vulkan errors. At exit: `WARNING: 7 RIDs of type "Texture" were leaked`.
- **The intro plays and skips:** the exe cannot press "New journey" from the command line, so this comes from the headless suite at the same commit. All intro checks pass:
  - "the intro opens the journey" / "begins once the Bearer stands in the world";
  - "no skip prompt until a key is touched";
  - "a short press does not skip" / "any key shows the prompt … (Hold E to skip)";
  - "skipped mid-wave: the intro is over / control, on his feet / on the Strand (-4.0, 2.7, 62.0) / his own camera is back / the HUD is up";
  - "sat through: the intro is over";
  - "no intro on a load".

## 2026-11-12T05:52Z Job 4: perf tour of feat/integration-1112 (8c160fd)
**Report:** `docs/qa/PERF_GPU.md` on `gpu/perf` (0c792d9): all seven regions, both states, q0/1/2. Raw JSON is in `docs/qa/perf_int_8c160fd/`. Measured only.
- **Since Job 4,** mean FPS is about halved everywhere. Examples at q1: Saltfell THAW 207 → 107, Tarnhall RIME 168 → 73, Reach RIME 181 → 59. GPU time is flat (4–7 ms); **CPU time is up 2–3×**, mostly script time (3–4×), plus physics in Lowe and the Reach.
- **Worst 1 % lows:** Tarnhall q2 19, Reach q2 21.
- **VRAM:** Tarnhall is about 1.09 GB at q0/1, twice the others.
- **Caveat:** job 1's walks were running at the same time in a second Godot process, so the CPU figures may be partly contention. A clean re-run is offered.
- **Fixes proposed, not made:** ablate script per region, the Area3D/physics ablation in Lowe and the Reach, and Tarnhall's textures.

## 2026-11-12T06:40Z Job 3: GPU re-shoot, gallery v4 (integration 0cac9ad)
- **Where:** `docs/gallery_gpu/v4/` on `gpu/gallery-v4` (0442c3c). That's 67 JPEGs at q2, 1920x1080. `README.md` there lists the sets and cameras.
- **Coverage:** 22 POI places across all seven regions in both states, the seven biome views, the Saltfell cliff top and the Strand shore, the Journal and the Map (×2), and the torch, spear, greatblade and bow in RIME.
- **Looks wrong on the GPU:**
  - Very dark THAW under the cliffs: Kettle Road (luma 4/255), the Tarn Causeway, Tarnhall and the Far Landing.
  - Thornwold THAW has a strong yellow fog wash.
  - The `instantiate`-on-null script error appears in every boot.
- **Not covered:**
  - `bearer_light1` does nothing in THAW, so there are no THAW weapon shots.
  - There is no unlit-torch hook.
  - The title card is visible in the weapon shots.
- **POI cameras:** these are generated from the wayside boards, since only Thornwold has scripted POI cameras. Three of them frame badly; they are named in the README.

## 2026-11-12T06:41Z Job 1: FAIL in the fullslice (Saltfell) walk on integration 0cac9ad (pushed at once)
- `walk:fullslice`, commit **0cac9ad**: rc 0, **104 checks, 25 failures**. In the previous gate, fullslice passed 112/0 at 25ef245.
- **First failure:** `FAIL - the Netmender is released (deaths along the way: 6)`. Everything up to it passes: the frost veil offers passage and seals, and "the Netmender sits mending".
- The other 24 failures all follow from it: the Outsong, the quiet card, Saltfell cleared, the veil falls, the needle, the Long Hearth, the THAW turn, Ingra and Brede's threads, and the save/kept checks.
- So the boss fight is no longer won within the walk's tries. Suspects are the collision-baseline commit (0cac9ad itself) or Netmender tuning. The walk is headless and tick-driven; a GPU gallery job was running at the time, so I'll re-run it alone to rule out load.
- **Other results so far:**
  - originality rc 0, and the full suite 2783/1 at 8c160fd ("the flame gutters more under RIME (0.00 vs 0.00)");
  - fullgame_lowe 194/0 at 0cac9ad, passing twice so far: the frost-taken/STILLED cluster is gone.
- The remaining walks are still running.

## 2026-11-12T07:18Z Job 1: fullslice re-run at 0cac9ad fails again, differently (flaky and red)
- **Re-run:** a separate checkout, at the same time as the gate's other walks; there was no GPU job this time. Result **103 checks, 32 failures**.
- **This time it breaks earlier**, at the float in the frozen tide wall, where the earlier run got as far as the Netmender:
```
  FAIL - the float shows its prompt
  FAIL - a heavy blow chips the float out of the ice
  FAIL - warmth carried into the fall (0)
  FAIL - the frost-taken bring the Bearer down
  FAIL - STILLED (Stilled)
  FAIL - the warmth hangs as a Breathmark
  FAIL - the veil seals at the Bearer's back
  FAIL - the Netmender is released (deaths along the way: 1)
```
- The two runs fail at different points, both after "through the boat-shed to the Strand", so the Saltfell walk is **non-deterministic and red** at 0cac9ad. I suspect the new collision sets: the float/ice-wall prompt and the Netmender's arena.
- **Walks since the last entry, all at 0cac9ad:**
  - fullgame_lowe ×3: 194/0 each.
  - fullgame_kettle: 197/0.
  - **fullgame_tarnhall: 211/1**, `FAIL - the Bearer walks out through them onto the porch ((163.7, 24.2, -332.7), 722 ticks)`.
  - fullgame_thornwold: 160/0.
  - fullgame_coldwell: 178/0.
- Still to run: reach and both endings.

## 2026-11-12T07:40Z Job 1 DONE: pre-merge gate on feat/integration-1112, verdict RED
| stage | commit | checks | failures |
|---|---|---:|---:|
| originality | 8c160fd | n/a | 0 (rc 0) |
| full suite (41 suites) | 8c160fd | 2783 | 1 |
| fullslice (Saltfell) | 0cac9ad | 104 | **25** |
| fullslice re-run | 0cac9ad | 103 | **32** |
| fullgame_lowe ×3 | 0cac9ad | 194 each | 0 |
| fullgame_kettle | 0cac9ad | 197 | 0 |
| fullgame_tarnhall | 0cac9ad | 211 | **1** |
| fullgame_thornwold | 0cac9ad | 160 | 0 |
| fullgame_coldwell | 0cac9ad | 178 | 0 |
| fullgame_reach | 0cac9ad | 195 | 0 |
| fullgame_ending_outsong | 0cac9ad | 160 | 0 |
| fullgame_ending_kept | 0cac9ad | 193 | 0 |

**FAIL lines, verbatim:**
- suite: `FAIL - the flame gutters more under RIME (0.00 vs 0.00)`
- tarnhall: `FAIL - the Bearer walks out through them onto the porch ((163.7, 24.2, -332.7), 722 ticks)`
- fullslice: see the two entries above. The run fails at the float prompt or at "the Netmender is released (deaths along the way: 6)", and everything after cascades.

**Notes:**
- The suite and originality ran at 8c160fd. The branch then moved, and every walk ran at 0cac9ad.
- I wouldn't merge yet. The Saltfell walk, the game's opening, is red and non-deterministic. The Tarnhall porch and the anim flame check are single failures.

## 2026-11-12T08:48Z The instantiate-on-null error: a local import fault (not a game bug); gallery v4 is missing props
**The exact text and stack**, from Godot's own log (`user://logs/godot.log`, written during a perf_tour boot):
```
       [5] _ready (res://src/debug/perf_tour.gd:74)
SCRIPT ERROR: Cannot call method 'instantiate' on a null value.
   at: _hero_gable (res://src/world/building_gen.gd:49)
   GDScript backtrace (most recent call first):
       [0] _hero_gable (res://src/world/building_gen.gd:49)
       [1] build (res://src/world/building_gen.gd:144)
       [2] build (res://src/world/area_builder.gd:49)
       [3] _front_door (res://src/core/world_root.gd:120)
       [4] _ready (res://src/core/world_root.gd:16)
       [5] _ready (res://src/debug/perf_tour.gd:74)
       [6] _ready (res://src/debug/perf_tour.gd:74)
SCRIPT ERROR: Cannot call method 'instantiate' on a null value.
   at: _build_hero (res://src/world/kit_lib.gd:440)
   GDScript backtrace (most recent call first):
       [0] _build_hero (res://src/world/kit_lib.gd:440)
       [1] instance (res://src/world/kit_lib.gd:423)
       [2] _piece (res://src/world/area_builder.gd:688)
       [3] build (res://src/world/area_builder.gd:58)
       [4] _front_door (res://src/core/world_root.gd:120)
       [5] _ready (res://src/core/world_root.gd:16)
       [6] _ready (res://src/debug/perf_tour.gd:74)
WARNING: 'res://assets/models/kit/kit_creel_stack_hero.glb': In external resource #0, invalid UID: 'uid://pymdvd8fmq2l' - using text path instead: 'res://assets/models/kit/kit_creel_stack_hero_T_kit_creel_stack_hero_BaseColor.jpg'.
ERROR lines just before them (counts):
```
**Cause:**
- The shot boots ran in worktrees where Godot's one-pass `--headless --import` had exited (rc 0) without importing everything.
- In two fresh worktrees, `.godot/imported` held 2 of 5,254 files.
- `ResourceLoader.exists()` is true (the `.import` remap is committed), but the `.scn` is missing, so `load()` returns null and `building_gen._hero_gable` / `kit_lib._build_hero` call `.instantiate()` on it.
- Cloud sessions import fully, which is why the cloud never shows it.
- Both worktrees are now fully imported (checked: 0 of 906 `dest_files` missing). I check this before every run from now on.

**What it affected:**
1. **Gallery v4 (gpu/gallery-v4, 0442c3c):** the shots were taken in a partly imported tree, so some hero props are missing: carved and shed gables, barrels, creel stacks, door leaves, fat lamps and feast horns. The lighting findings stand, but the shots need a re-shoot. I'll do it after job C.
2. **Earlier gates:** fb_base, the gate worktree, is fully imported. Job C re-imports both gate trees before it starts.

**Hardening, if you want it:** `area_builder` could `push_error` once and skip a kit whose `load()` is null. That's cheaper than an error per instance, but it's your call.

## 2026-11-12T10:37Z Job C, steps 1–2: fullslice is GREEN alone ×3 and paired at 740ca4d
| run | commit | checks | failures | min |
|---|---|---:|---:|---:|
| fullslice alone 1 | 740ca4d | 108 | 0 | 14 |
| fullslice alone 2 | 740ca4d | 108 | 0 | 9 |
| fullslice alone 3 | 740ca4d | 108 | 0 | 15 |
| fullslice, with fullgame_lowe beside it | 740ca4d | 108 | 0 | 8 |
| fullgame_lowe, beside it | 740ca4d | 194 | 0 | 11 |

- Full logs are in `docs/qa/gpu/fullslice_740ca4d_{solo1,solo2,solo3,paired}.log` and `fullgame_lowe_740ca4d_paired.log`.
- The save-directory fix holds under the conditions that failed before.
- Step 3 is running now, two lanes: the full suite, Tarnhall ×3 (per your note), Reach ×2 and the rest once each.

## 2026-11-12T11:51Z Job C, step 3 (two lanes at once): two red results, both while paired. Re-running each alone
| stage | commit | checks | failures | lane |
|---|---|---:|---:|---|
| originality | 740ca4d | n/a | 0 (rc 0) | 1 |
| **full suite** | 740ca4d | 2902 | **27** (rc 1) | 1, beside lane 2's walks |
| fullgame_tarnhall #1 | a37afed | 211 | 0 | 1 |
| fullgame_tarnhall #2 | 740ca4d | 211 | 0 | 2 |
| fullgame_reach #1 | a37afed | 195 | 0 | 1 |
| fullgame_reach #2 | 740ca4d | 195 | 0 | 2 |
| fullgame_coldwell | a37afed | 178 | 0 | 1 |
| fullgame_lowe | 740ca4d | 194 | 0 | 2 |
| **fullgame_kettle** | 740ca4d | 197 | **4** | 2, beside the suite |
| fullgame_thornwold | a37afed | 160 | 0 | 2 |
| fullgame_ending_outsong | a37afed | 160 | 0 | 2 |
| fullgame_ending_kept | a37afed | 193 | 0 | 2 |

a37afed differs from 740ca4d only in ci.yml. Tarnhall #3 is running now, alone.

**The suite's 27 failures, verbatim.** 26 are in its `fullslice` test (log lines 1201–1339) and 1 in a surfaces/prop-strike test:
```
  FAIL - the Netmender is released (deaths along the way: 0)
  FAIL - her AI ran all three phases ([1])
  FAIL - the Outsong is sung (res://assets/audio/music/boss_netmender.ogg)
  FAIL - the quiet card (THE LONGHOUSE)
  FAIL - Saltfell is cleared
  FAIL - the veil falls
  FAIL - the mending needle lies where she sat
  FAIL - the needle is taken
  FAIL - the Long Hearth wakes
  FAIL - the Long Hearth offers to turn the memory
  FAIL - warmed: THAW again
  FAIL - the Long Hearth is lit and kept
  FAIL - Ingra, in THAW again
  FAIL - the rye is home
  FAIL - Ingra, a second time
  FAIL - Ingra's thread is whole (2)
  FAIL - down to the Strand for Brede
  FAIL - Brede, a second time
  FAIL - Brede's thread is whole (2)
  FAIL - the Boat-Shed turns freely too
  FAIL - she does not come back
  FAIL - and warmed once more
  FAIL - the Pack kept
  FAIL - Saltfell cleared and warm
  FAIL - the Long Hearth still burns
  FAIL - story flags kept
  FAIL - no prop burst for a foe (1)
```
**Kettle's 4 failures, verbatim:**
```
  FAIL - the Breathmark offers itself
  FAIL - the warmth is taken back (+0 of 1454, first fall carried 1454, 3 tries)
  FAIL - levels bought with what the fjord gave (10 -> 10, 16 warmth left)
  FAIL - no Breathmark is left lying behind ({ "area": "kettle_fjord", "pos": [-51.2584075927734, 0.02518211305141, -330.735656738281], "amount": 1454 })
```
**Reading:**
- The suite's fullslice fails differently from this morning's run: **deaths 0**, and "her AI ran all three phases ([1])". The Netmender stays in phase 1 and the fight seems to run out of time.
- The walks run in real time (test.sh: "plays the whole 20-minute slice in real time"). Two below-normal Godot processes on this CPU, with its E-cores, can slow the frames enough to change fight timing. That would be separate from the save-directory fault 740ca4d fixed.
- Against that, the paired check in step 2 (fullslice plus lowe) passed. So contention doesn't always break it, but under load it isn't safe.
- **Next:** I'm re-running `tools/test.sh` (the full suite) alone and fullgame_kettle alone. I'll export only if both come back green.
- Full logs: `docs/qa/gpu/suite_740ca4d_paired.log` and `fullgame_kettle_740ca4d_paired.log`.

## 2026-11-12T12:01Z Windows release build of main 4e8ea09: READY for the owner
- **Exe:** `C:\Users\Aaron\Documents\Rimeholt_Windows_main_4e8ea09\Rimeholt.exe`, **1,527,581,152 bytes** (1.53 GB, a single exe with the pack embedded).
- **Built from:** main 4e8ea09, a separate worktree. The tree is the same as a37afed and feat/integration-1112.
- **Imports:** fully imported, checked (0 of 906 `dest_files` missing). The 1,812 textures that Godot extracts from the .glb files are present.
  - A first export from the bare import cache lacked them: 531 MB, with 6 "Failed loading resource" and 6 "invalid UID" warnings for the mask props. That exe was replaced.
- **Export:** `--headless --export-release "Windows"`, rc 0, **no warnings or errors** in the export log.
- **Boot check:** off-screen at below-normal priority.
  - Frame 450: the "Figglebottom Productions" studio card.
  - Frame 2000: the title, "RIMEHOLT / The Winter That Would Not End", New journey / Settings, over the Saltfell steading at dusk (1,356 draws, 4.4 M prims).
  - At exit: only `WARNING: 7 RIDs of type "Texture" were leaked`, the same as every earlier build.
- **Job C so far:** fullgame_tarnhall #3 passed, **211/0** (a37afed, partly overlapping the export). Tarnhall is green 3 of 3 here.
- **Now running, each alone:** fullgame_kettle, then the full `tools/test.sh`, to settle the two red results from paired runs.

## 2026-11-12T13:46Z Job C DONE: RED. The full suite's fullslice test fails ALONE (20 FAIL); everything else is green
| stage | commit | checks | failures | conditions |
|---|---|---:|---:|---|
| `tools/test.sh fullslice` ×3 | 740ca4d | 108 each | 0 | alone |
| `tools/test.sh fullslice` | 740ca4d | 108 | 0 | beside fullgame_lowe |
| **full `tools/test.sh`** | a37afed | 2901 | **20** (rc 1) | **alone**: the 20 are all in its `fullslice` test |
| full `tools/test.sh` | 740ca4d | 2902 | 27 | beside walks |
| fullgame_kettle | a37afed | 197 | 0 | alone (the 4 Breathmark FAILs while paired did not repeat) |
| fullgame_tarnhall ×3 | 740ca4d / a37afed | 211 each | 0 | |
| fullgame_reach ×2, lowe ×2, coldwell, thornwold, ending_outsong, ending_kept | 740ca4d / a37afed | | 0 | |

a37afed is the same tree as 740ca4d apart from ci.yml, and the same as main 4e8ea09.

**The suite's fullslice FAILs (alone), verbatim** (full log: `docs/qa/gpu/suite_a37afed_alone.log`):
```
  FAIL - the float shows its prompt
  FAIL - a heavy blow chips the float out of the ice
  FAIL - warmth carried into the fall (0)
  FAIL - the frost-taken bring the Bearer down
  FAIL - STILLED (Stilled)
  FAIL - the warmth hangs as a Breathmark
  FAIL - the Long Hearth offers to turn the memory
  FAIL - warmed: THAW again
  FAIL - the Long Hearth is lit and kept
  FAIL - Ingra, in THAW again
  FAIL - the rye is home
  FAIL - Ingra, a second time
  FAIL - Ingra's thread is whole (2)
  FAIL - down to the Strand for Brede
  FAIL - Brede, a second time
  FAIL - Brede's thread is whole (1)
  FAIL - stilled again: RIME
  FAIL - and warmed once more
  FAIL - Saltfell cleared and warm
  FAIL - story flags kept
```
**Reading:**
1. **It is not the save slot.** The suite runs each test as its own process, and 740ca4d gives each process its own `test_fullslice_<pid>` directory. No settings.cfg is written anywhere in user://.
2. **The first failure is the same as in my 0cac9ad re-run:** the ice-wall float never shows its prompt. That would be `nearest_interactable()` not finding the float from where the walk stands. The rest cascades: no float, no Breathmark beat, no Long Hearth turn.
3. **The difference from the green runs** is only that 40 other tests ran first in the same `test.sh`, each in its own process. Stand-alone fullslice is green 4 of 4. So either the walk is flaky, failing about 1 in 3 here (my count: 3 red of 8 runs, 2 of them under load), or something earlier leaves a file in `user://` or `res://`. The cache, prof_cache and shader_cache are shared across processes.
4. **Suggestion:** have the walk log the Bearer's position and the float's position and distance when the prompt check fails. That separates "stood in the wrong place" (a physics or real-time timing issue) from "the float isn't interactable" (state).

**The gate is stopped here,** as you asked. The other suite failure while paired, "no prop burst for a foe (1)", did not repeat alone.

## 2026-11-12T14:28Z Gallery v4 re-shot on main a6a45f6, fully imported tree
- **Where:** `gpu/gallery-v4` (54a8fb0). It replaces the first pass: 73 JPEGs at q2, 1920x1080, with no script errors and the hero props present.
- **Weapons, in THAW and RIME, using your new stages:** torch lit and unlit, spear, greatblade, bow. They all work, and the title card is gone.
- **What still looks wrong on the GPU:**
  - The same very dark THAW spots under the cliffs: Kettle Road, Tarn Causeway, Tarnhall, Far Landing. Job B is on it.
  - Thornwold THAW is still washed in yellow fog.
  - **The unlit torch's swing trail** keeps the lit brand's fire colour. The head flame and its light are off, but the swing still reads as burning. `weapon_torch_unlit_thaw` vs `_lit_thaw` shows it.
  - **Greatblade THAW:** the swing trail is a blown-out white slab against the dusk sky.
- **Job A:** `gpu/perf-fix` (ba25af2) is pushed, rebased on main, and the map_state conflict with 2295854's board tags is resolved: places_def does not depend on state, so the cache is safe.
  - smoke 11/0, journal_map 74/0, keepsakes 65/0, originality clean.
  - An interleaved q1 before/after tour (main vs fix, both trees fully imported) is running. Table to follow.

## 2026-11-12T15:46Z Job A DONE: the regression was the HUD re-parsing area JSON; fixed on gpu/perf-fix (mean 96 → 157 FPS at q1)
**Branch:** `gpu/perf-fix`, from main. The fix is ba25af2; the report is e245095, `docs/qa/PERF_FIX_1112.md`.

**Main finding:**
- feat/ui-map-log-icons (024ff96) added the HUD tracker's `_scout()` twice a second.
- `MapState.scout` called `DB.area_def()`, a full file read plus JSON parse of a 31–186 KB area file, three times per tick.
- Ablating `hud.gd` alone was worth 3.7 ms per frame (106 → 166 FPS in Saltfell).
- The rest of the slowdown since Job 4 is small and spread across merges (0.2–0.9 ms of script).

**Fix:**
- `DB.area_def_ro()`, a cached parse for read-only callers. The builder still parses fresh.
- `places_def` is built once per area; it does not depend on state.
- The tracker labels are set only on a change.
- smoke, journal_map and keepsakes are green.

**Before → after** (main a6a45f6 → ba25af2, q1, interleaved, both trees fully imported):
- Mean across 7 regions × 2 states: **96 → 157 FPS**, script **8.22 → 3.97 ms**.
- Examples: Thornwold THAW 70 → 166, Reach THAW 79 → 184, Kettle THAW 104 → 215, Saltfell THAW 110 → 171, Reach RIME 62 → 101.
- GPU and physics are unchanged.

**Measured, not fixed:**
- **Lowe physics** is +2.6–3 ms, from fix/playtest-1 (472b1b3): exact convex hulls (98–292 points) on the scatter.
- A 32 or 64-point cap got it back to 1.2 ms, but collision_audit then fails (178 new in Lowe: pieces lose colliders). It is reverted.
- Options are in the report: per-kind primitives, a volume-keeping simplifier, or a Jolt trial.

**VRAM:** two clusters, about 1.1 GB and about 0.52 GB, by area, not "Tarnhall alone". I made no import changes; I'll look at it after job B.

**Ready to merge:** ba25af2 is one small commit. I'd merge it to main after your gate.

## 2026-11-12T16:19Z Job B: THAW lighting. Authored (data), worse on the GPU; fixed in part on gpu/thaw-light
**Branch:** `gpu/thaw-light` (8cc60a4), from main. The change is data only, in `data/biomes/{kettle_fjord,tarnhall,thornwold}.json` `env.thaw`. RIME is untouched and checked: every RIME shot measures the same luma before and after. smoke 11/0, look5 25/0, originality clean.

**Before and after shots:** `docs/gallery_gpu/thaw_light/` (README, 22 pairs, and a side-by-side sheet).

**Real GPU only, or authored?** Authored. The lavapipe shot of the Kettle road is already dark in THAW (21/255 against 59 in RIME), and q2 SDFGI plus the fog takes it to 4.
- The THAW sun stood 10–22° over deep cuts.
- The shadowless top-down sky fill was 0.95–1.0.
- The THAW ground palettes are dark.
- Thornwold's wash is its yellow-green THAW volumetric fog (0.009).

**The change:**
- Raise the THAW sun: Kettle -34°, Tarnhall -36°, Thornwold -30°.
- Double the sky fill in Kettle and Tarnhall (2.0) and raise their ambient to 1.6.
- Thornwold: fog density halved (0.0045), fog cooled (0.72, 0.74, 0.68), sun less yellow.

**Luma, before → after:**
- Kettle overview 118 → 142; Tarnhall overview 90 → 115.
- Far Landing 31 → 51; Tarn Causeway 18 → 29; Tarnhall POI 35 → 43; Thornwold notch 71 → 85.
- Thornwold overview wash 151 → 135, with depth back.
- Cliff shade still reads as shade.

**Still open:**
- **The Kettle Road cut** stays near-black (4 → 7). Its slope faces away from both the sun and the top-down fill, and my generated camera is a metre from it. More global fill would flatten the open fjord. It needs a local fill light or a brighter path palette in the cut: one for art/biomes.
- **The Tarn Causeway** could take one more step of fill (2.5) if you'd rather have it brighter than keep the cliff contrast.

## 2026-11-12T17:35Z Item 1 DONE: THAW light, second pass, on gpu/thaw-light-2 (484651d), from main
**What:**
- `area_builder` gains **`shade_fills`**: a soft, shadowless, non-specular OmniLight3D per entry, tagged by state.
- The generators write them, **THAW only**:
  - Kettle: 11 down the Kettle Road cut, 2 at the Far Landing.
  - Tarnhall: 10, on the upper steps, the causeway, the porch and the shore board.
  - Lowe: 2, at the Last Mound.
  - Coldwell: 2, under the Ice-Falls shelter.
- Each generator reproduces its committed file exactly before the change.
- THAW exposure: Kettle 1.10, Tarnhall 1.22. Thornwold THAW ambient 1.5, fill 1.15.

**Luma, before (main 86128b6) → after; % of pixels below 10 in brackets:**
- Kettle Road 7.2 (84%) → **66.1 (0.1%)**
- Tarn Causeway 29.1 (16%) → **68.2 (0.0%)**
- Tarnhall 43.3 (25%) → **78.6 (0.2%)**
- Far Landing 51.4 → **75.6**
- Last Mound 37.8 (5.3%) → **64.4 (0.1%)**
- Coldwell Ice-Falls 86.1 (8.0%) → **98.5 (4.4%)**
- Thornwold canopy: Hedge 61.7 → 68.1 (8.7 → 6.7%); Thornwold 64.4 → 70.6 (12.3 → 10.7%). That's leaf shade, and the latter is my camera with a branch at the lens.

**Below the ≥ 70 line:** Kettle Road, Causeway and Last Mound sit at 64–68, but every one is now readable: path, board and people. Thornwold's canopy is the one place still over the 5% line.

**RIME:** unchanged. Per-pixel diffs are at the same level as two runs of main (falling snow).

**Cost:** Kettle THAW q1 GPU 4.42 → 4.49 ms, FPS within noise.

**Tests:** smoke, look5, kettle, tarnhall, lowe and coldwell are green.

**Shots:** `docs/gallery_gpu/thaw_light_2/` (README with the full luma table, before/after JPEGs and a sheet).

**Other regions, surveyed:** Saltfell has no black spots (Cliff Graves and the cliff top are dim at about 55–57, not black). Reach and the rest of Lowe are fine.

**Process note:** a shoot script of mine ended in `git checkout -- .` and wiped one uncommitted pass of this work. It was redone from the same edits, and I now commit before every run.

Next: item 3 (trails, gpu/trail-fix, code ready), then item 2 (Lowe physics, ablation hooks in), then item 4 (full-suite fullslice, gpu/test-seed: an unseeded RNG is the lead suspect).

## 2026-11-12T17:48Z Item 3 DONE: swing trails, on gpu/trail-fix (480a3f3), from main
**Unlit torch:**
- New key `clip_meta.json` `weapons.torch.trail_unlit`: no ember style, a grey tint, low energy and opacity.
- `CharVisual._on_trail_shown` re-applies the trail look as each swing's trail appears, and uses those keys while `brand.is_lit()` is false.
- The put-out brand now leaves a faint grey arc. The lit torch is unchanged.

**Greatblade in THAW:**
- The cause is in the shader: the leading edge's opacity and whiteness ignored all weapon data, and a wide blade's young arc is nearly all leading edge.
- `trail.gdshader` gains an `edge` uniform, default 1.0, so every other weapon is untouched. It is set from a new data key, `trail_edge`.
- The greatblade gets `trail_edge` 0.35, `trail_weight` 0.4 and a steel tint. The arc is now a translucent steel smear in THAW and still reads over RIME snow.

No timing change. smoke 11/0, anim 229/0, combat 22/0, body 8/0. Before/after shots, both states, are in `docs/gallery_gpu/trail_fix/`.

## 2026-11-12T18:44Z Item 2 DONE: "Lowe physics +3 ms" was the perf tour pinning the Bearer inside a peat stack. No game change needed (gpu/lowe-phys)
**Per-view Lowe THAW physics ms** (q1):

| view | f367dee (before playtest-1) | 472b1b3 (playtest-1) | main | gpu/lowe-phys |
|---|---:|---:|---:|---:|
| start | 1.00 | 1.09 | 1.08 | 0.94 |
| hs_barrow_road | 1.32 | 1.39 | 1.34 | 1.05 |
| **hs_drying_stacks** | 1.46 | **14.34** | **15.97** | **0.89** |
| open_barrow_veil | 1.17 | 1.19 | 1.02 | 1.09 |
| overview | 1.03 | 1.03 | 1.19 | 1.14 |

**How I found it:**
1. Taking the scatter colliders off their layer gave 1.25 ms. Ablating the player alone gave 0.51. Enemies, NPCs, casts, the camera arm and Area3Ds don't matter, and no monitoring Area3D overlaps the scatter.
2. Timing the player's step showed `move_and_slide` at **9–10 ms per tick**, but only at hs_drying_stacks, with one 205-point peat-stack hull 1 m away and the Bearer not on the floor.
3. For hearth views, perf_tour pinned him every frame at `respawn_point + 2 m`, **at the hearth's height**. On Lowe's slope that is underground, and beside a convex hull the capsule fought both on every tick.

**The fix, in the tool only:**
- `_clear_spot()` puts the hearth-view spot on the ground (ray down) and steps further out until a 0.6 m capsule is clear of every solid but terrain.
- Lowe drops from 4.1 to **1.02 ms** of physics, 145 → 185 FPS.
- The census also checks every hearth's real **respawn point** in all seven regions: **none** overlaps a scatter collider. So players aren't affected.
- The exact hulls stay, and collision_audit is unaffected: no collider changed. The only game-side line is `scatter_body` group membership on scatter colliders, so the tour can find them.

**One real caution:** a capsule *held inside* a 200-point hull costs about 10 ms a tick. In play, `_unwedge` resolves a wedge within 0.2 s, so it would be a hitch, not a sustained cost.

**Note:** this also explains part of the morning's q1 Lowe figures. Hearth views in other regions move slightly too, onto the ground. Earlier tours' hearth-view numbers are comparable among themselves, not with tours after this.

**Commits:** 1f5a498..8ef7908 on gpu/lowe-phys. The ablation classes and census hooks stay for future use. smoke 11/0.

## 2026-11-12T21:45Z Item 4: seeding makes the walks deterministic (proven); this seed's fight is one the walk loses
**Branch:** `gpu/test-seed` (d543dd6), from main 86128b6.
- `boot.gd` seeds the global RNG from the test's name for every `--test=` run. `--test-seed=N` overrides it.
- `fullslice` logs the Bearer's state and distance if the float's prompt is missing.

**Runs, alone, one at a time, at d543dd6:**

| run | checks | failures |
|---|---:|---:|
| `tools/test.sh fullslice` #1 | 104 | 26 |
| `tools/test.sh fullslice` #2 | 104 | 26 |
| full `tools/test.sh` (fullslice inside it) | 2953 | 26: the same 26, and nothing else fails |

**What it proves:**
- The three fullslice runs are **identical, check for check**: `diff` of their ok/FAIL lines is empty.
- So the full suite and the stand-alone walk now behave the same. **No state leaks from an earlier suite.**
- The red/green split before (4 green alone, red in the suite, red with a different first FAIL in each red run) was the **unseeded RNG**: foes choose with `randf` in enemy.gd, and each process drew a different fight.

**But this seed's fight is one the walk loses, every time:**
```
  ok  - it waits on ground the Bearer can reach (y 21.82)
  ok  - the Bearer wakes at the hearth
  ok  - at the Salt House
  ok  - with nothing carried
  ok  - the Breathmark offers itself
  ok  - the warmth is taken back (+168 of 168, first fall carried 168, 1 tries)
== the frost veil
  ok  - the veil offers passage
  FAIL - the veil seals at the Bearer's back
```
- The first FAIL is `the veil seals at the Bearer's back`, then `the Netmender is released (deaths along the way: 1)` and `her AI ran all three phases ([1])`. The rest cascades.
- So the walk is robust only to some fights. Under this draw the Bearer dies once before the Netmender, the veil step doesn't see the seal, and the boss never leaves phase 1 before the walk gives up.
- I didn't change any assertion, and I didn't go seed-shopping for a green one: that would hide the fragility.

**Options, yours to pick:**
- (a) Keep seeding (determinism is worth having) and fix the walk for this fight: wait for the seal after a death, and give the Netmender's phases more time or retries. Then this seed is a fixed regression case.
- (b) Seed per run (`--test-seed` from CI's run number) and log the seed in the RESULT line, so any red run can be replayed exactly.
- (c) Run a few seeds, say 1..5, to measure the pass rate first. That's about 35 min each here; I can do it after the main gate if you want.

Full logs are in `docs/qa/gpu/fullslice_seeded_run{1,2}.log` and `suite_seeded.log`.

**Now running, in order, alone:** stream_prof on main 0c5263f, then the full gate on main, then the Windows build of main.

## 2026-11-13T00:18Z Main 0c5263f: hitch re-measure, full gate, Windows build
### 1. Real-GPU hitches: stream_prof --prof-stream, alone, RX 9070 XT, 1920x1080
The full tables are in `docs/qa/gpu/stream_prof_gpu_0c5263f.md`. Against the 05:09Z run (25ef245):

| area | worst warm crossing ms (was) | worst cold crossing ms (was) | turn to RIME ms (was) | warm worst frame held |
|---|---:|---:|---:|---|
| saltfell_steading | **48.7** (107.2) | **131.4** (238.5) | 6.8 (54.0) | graft: what acts 49 |
| lowe_barrows | **35.3** (90.8) | 42.3 (89.7) | 6.8 (53.1) | graft: what acts 33 |
| kettle_fjord | **52.4** (92.9) | **58.8** (85.1) | 7.1 (54.9) | graft: what acts 50 |
| tarnhall | **49.3** (83.3) | **51.8** (83.8) | 9.4 (57.5) | graft: what acts 49 |
| thornwold | **35.7** (96.6) | 39.7 (101.4) | 11.2 (55.4) | graft: what acts 33 |
| shepherds_reach | **80.6** (89.3) | **97.9** (127.0) | 8.5 (58.9) | graft: what acts 78 |
| coldwell | **40.1** (97.2) | 35.2 (100.8) | 8.4 (57.2) | graft: what acts 37 |

**Against the targets:**
- **Turn to RIME under 33 ms: met everywhere** (6.8–11.2 ms). The 50 ms wave-particle flip is gone.
- **Cold crossing under 50 ms:** met in Lowe, Thornwold and Coldwell. Not met in Saltfell (131), the Reach (98), Kettle (59) or Tarnhall (52).
- **Warm crossing under 33 ms: not met anywhere** (35–81). Every region roughly halved, but each worst frame is still a single "graft: what acts" step of 33–78 ms. That one graft needs splitting across frames. The Reach's 78 ms graft is the largest.

### 2. Gate on main 0c5263f: alone, one at a time

| stage | commit | checks | failures |
|---|---|---:|---:|
| originality | 0c5263f | n/a | 0 (rc 0) |
| full `tools/test.sh` | 0c5263f | 3300 | **3** (rc 0) |
| fullslice | 0c5263f | 114 | 0 |
| fullgame_lowe | 0c5263f | 196 | 0 |
| fullgame_kettle | 0c5263f | 199 | 0 |
| fullgame_tarnhall | 0c5263f | 213 | 0 |
| fullgame_thornwold | 0c5263f | 163 | 0 |
| fullgame_reach | 0c5263f | 197 | 0 |
| fullgame_coldwell | 0c5263f | 179 | 0 |
| fullgame_ending_outsong | 0c5263f | 161 | 0 |
| fullgame_ending_kept | 0c5263f | 193 | 0 |

**The 3 FAILs, verbatim** (all in the streaming suite, "quitting with a build in flight"):
```
FAIL - preload in flight, quit by tree: the process is gone -1 ms after the asking (exit 1)
FAIL - preload in flight, quit by game: the process is gone -1 ms after the asking (exit 1)
FAIL - crossing in flight, quit by close: the process is gone -1 ms after the asking (exit 1)
```
- **Cause: Windows only, in the test harness, not the game.** `streaming_test.gd:393` runs `OS.execute("timeout", ["60", OS.get_executable_path(), ...])`. On Linux that's coreutils `timeout`. On Windows, `timeout` is cmd's pause command, so it exits 1 at once and the child Godot never starts.
- **Suggested fix:** call the executable directly and time it with `OS.create_process` plus `OS.is_process_running`, or skip that block when `OS.get_name() == "Windows"`. Cloud and CI (Linux) are unaffected.
- **Everything else in the suite is green,** including the unseeded fullslice inside it. Log: `docs/qa/gpu/suite_main_0c5263f.log`.

### 3. Windows build of main 0c5263f
- **Exe:** `C:\Users\Aaron\Documents\Rimeholt_Windows_main_0c5263f\Rimeholt.exe`, **1,767,698,768 bytes** (1.77 GB), up from 1.53 GB at 4e8ea09.
- **Built in:** the fully imported release tree (0 of 906 missing, 1,812 extracted textures).
- **Export:** rc 0, **0 warnings or errors** in the log.
- **Boot check:** off-screen.
  - Frame 450: the studio card.
  - Frame 2000: the title, "New journey / Settings", over a **RIME** Strand backdrop. 4e8ea09's title was the THAW steading, so if the title isn't meant to vary, that's worth a look.
  - Both PNGs (`boot_check_450.png`, `boot_check_2000.png`) are in the build folder.
  - At exit: only `WARNING: 7 RIDs of type "Texture" were leaked`, as in every build.

## 2026-11-13T02:45Z Item 4: gpu/test-seed-2 (from main 0c5263f). Seeding, portable quit checks, Netmender budget. Pass rate
**Branch `gpu/test-seed-2`:**
- 9585549: seed the RNG from the test name; `--test-seed=N`.
- 0a37189: the seed printed in every RESULT line.
- 09d6d32: the veil diagnostic, with the check unchanged.
- 8931f92: portable quit-in-flight harness.
- b1894ca: a per-attempt Netmender budget.
- It's a new branch: the old `gpu/test-seed` wasn't rewritten, and my attempted force-push was rejected.

**Streaming (Windows):** 113/0. The quit checks now launch and time the child: 343 ms and 323 ms, exit 0. It used to
fail on Windows because `OS.execute("timeout")` there is cmd's pause.

**Veil:** on main-based code the seeded fullslice no longer loses at "the veil seals" (114/0 with its name seed). The
diagnostic never fired. No game bug was found there.

**Netmender, the walk's timing.**
- With seeds 1–5 on 8931f92, seeds 2 and 3 failed at "the Netmender is released" (1 and 3 deaths), even though "her AI
  ran all three phases".
- Cause: one 480 s fight budget shared across attempts, while the holdfast is whole again after each fall.
- b1894ca gives each attempt the full budget and ends at three falls. **The assertions are unchanged.**
- Seeds 1–5 on b1894ca:

| seed | result | deaths |
|---|---|---:|
| 1 | 110 checks, **29 failures** (Netmender not released) | 3 |
| 2 | 114 / 0 | 0 |
| 3 | 114 / 0 | 1 |
| 4 | 114 / 0 | 2 |
| 5 | 114 / 0 | 1 |

**Pass rate 4/5 (it was 3/5).**

**Caveat: seeding doesn't make the walk fully deterministic.**
- Seed 1 passed on 8931f92 and fails on b1894ca with 3 deaths.
- Seed 2 died once on 8931f92 and none on b1894ca, even though the code before the first death is the same.
- So frame pacing in a real-time headless walk still varies the fight. Seeding narrows the spread but doesn't remove
  it.
- **Suggestions:**
  - (a) Have the walk advance on physics ticks rather than `_secs` real time in the fight loop.
  - (b) Or treat the Netmender stage as a retry stage: up to N fresh attempts, logging the seed and the attempt count.
  - (c) The game question worth an owner look: a full-health boss after each death, at the walk's damage multiplier
    3.0, makes a three-death loss possible. Is that the intended difficulty?

---

## 5. gpu/walk-ticks: the walks are now deterministic; fullslice seeds 1–5 pass 10/10 (2026-11-13)

Branch `gpu/walk-ticks` from main b1894ca, head **572d495**. A full `tools/test.sh` regression run is in progress;
its result follows in the next entry.

**Result:** fullslice seeds 1–5, each run twice:
- every seed gives the **identical run both times** (every check line plus a 30-frame state trace, 0 differing
  lines);
- **pass rate 10/10, 114/114 each.**

| seed | result (both runs) | deaths at the Netmender | boss hits taken |
|---|---|---:|---:|
| 1 | 114 / 0 | 0 | 0 |
| 2 | 114 / 0 | 1 | 11 |
| 3 | 114 / 0 | 0 | 0 |
| 4 | 114 / 0 | 0 | 0 |
| 5 | 114 / 0 | 1 | 1 |

**Why a fixed timestep alone wasn't enough.** Each fix was found by tracing two runs of one seed to the first
differing frame:
1. **The streamer** slices area builds by wall-clock budget, so builds and foe spawns landed on different frames.
   `--deterministic` now implies `--no-streaming`: synchronous builds and bakes.
2. **The hitstop** ran on real milliseconds, and the ward expired on the wall clock. The hitstop now counts unscaled
   frame time (`Juice._clock_ms`), and the ward the Bearer's physics time. `prop_hit` 65/65.
3. **The nav map and region iterations were async** (Godot 4.5+ default). They're off in `--deterministic`.
4. **The last divergence:** a foe's re-path stagger and flank side were keyed on `get_instance_id() % 7`.
   - Instance ids are a global counter that loads and audio on other threads also advance, so the same foe had id
     mod 7 of 4, 5 or 6 across runs, and a re-path came on a different frame.
   - Foes now take a spawn index (`Enemy._ord`). This one also touches real play: the stagger is still spread over
     7 slots, just keyed differently.

**The walk's combat policy was poor; that, not luck, lost seeds 1 and 5.**
- The new `[hit]` log showed nearly every hit was `needle_stitch` at 1–2 m, taken mid-swing with 2–5 stamina.
  - The bot swung whenever stamina was above 18, queuing combos, so it never had the 24 a roll costs.
  - Its dodge fired 35 % of the time, in the first 0.25 s of an attack.
- It now reads the foe's own attack data (windup, hits, range, lunge):
  - no swing into a windup;
  - a sideways roll just before the first blow (the stitch's 3–4 stabs outlast the 0.28 s of i-frames, so it
    leaves her committed line rather than i-framing);
  - it backs out when winded;
  - one light swing at a time, with a roll kept in hand;
  - it drinks below half, only out of reach.
- That also fixed seed 2's deterministic failure at the frozen float. The Strand fight was dragging it 63 m off.

**What's left (not failures):**
- **Seed 2:** it is pinned in phase 2, at 1.1 m, rolling but still stitched 11 times, and never drinks. Probably a
  roll into the slammed tables after `haul_floor`.
- **Seed 5:** one 112-damage `cast` at 26 m, while she approaches. A snare's pull or haul, not melee.
- Either is a follow-up if you want the walk to beat her deathless.

**Tool:** `--trace` prints the Bearer and a foe checksum every 30 physics frames. Diff two runs to find where they
part.

**My mistakes along the way:** two pushed commits didn't parse.
- dd49ac4: a literal `\n` in `area.gd`.
- ce6fefd: `juice.gd`, where `prop_hit_test` read the old field.
- Both are fixed in the next commits on the same branch, which is unmerged. I now parse-check (`--import`, grep
  SCRIPT ERROR) before every commit.

---

## 6. gpu/walk-ticks: merge checks done; full suite green at e09d46d (2026-11-13)

**Full `tools/test.sh` at e09d46d:** both audits plus **48 / 48 suites pass, 0 failures.** The run is sequential,
with nothing else on the box.

**Check 1, normal play unchanged outside `--deterministic`.**
- My first game-time hitstop was wrong in play. It used an unscaled delta (delta / time_scale), but the delta of the
  frame a hitstop starts was scaled at 1.0, so it counted 20 times over: a 0.09 s stop held 0.010 s.
- **Play now reads the wall clock exactly as before**, for both the hitstop and the ward. Only `--deterministic`
  counts frames × the fixed step (`Juice._now_ms`, `Player._ward_now`).
- **New `clocks` suite:**
  - hitstops of 0.06 / 0.09 / 0.14 s hold 0.071 / 0.098 / 0.152 s (data plus at most a frame);
  - a short stop inside a long one doesn't cut it short;
  - the Warding Hum holds 8.018 s (songs.json 8.0).
- anim 229/0, combat 22/0, deltas 147/0, prop_hit 65/0. `Enemy._ord` only rekeys the 7-slot re-path stagger and the
  flank side.

**Check 2, seed 5's "112-damage cast at 26 m."** It was not a cast; my hit log blamed the boss's last attack for any
HP drop.
- **Cast range:** data gives 8 m, `min_range` 3.5, and `_net_cast` returns early beyond `net_range`. Fine.
- **The real bug:**
  - A sideways roll left the Bearer wedged off the floor at (−4.29, 22.0, −41.09), between the rime-layer
    `table_3m` at (−5, 22, −40) and `column_4m` at (−4.2, 22, −38.8 / −43.4).
  - For 330 frames he couldn't move, while gravity banked fall speed into `velocity.y`, reaching −128 m/s.
  - Freed, he moved 2.1 m a tick, straight through the floor to the kill plane.
- **Fix (`player.gd`, after `move_and_slide`):** fall speed never runs ahead of the real fall,
  `max(v.y, min(real_v.y, 0))`, and never past a terminal `move.max_fall` (40 m/s, game.json).
  - My first version, `max(v.y, real_v.y)`, lent upward speed on step-ups. `poi_thornwold` caught it: he walked onto
    `tw_charcoal_sacks`. That is fixed in e09d46d, where `poi_thornwold` passes 104/0.
- **Still open (level geometry):** the table/column gap in the Long Hall can still pin a capsule. With the fix it is a
  stuck spot, not a fall. Worth a collision look; I left the area data untouched.

**Fullslice at e09d46d:** seeds 1–5 → 114/0 each, **no deaths, 0 boss hits**. Two runs per seed at ec651c3 were
identical.

**Branch head: e09d46d.** Ready to merge from my side.

---

## 7. fix/table-column-gap: the Longhouse pinch closed, plus a pinch audit across every region (2026-11-13)

Branch `fix/table-column-gap` from main e09d46d, head **c99dd04**. Full `tools/test.sh`: both audits plus **49 / 49
suites pass, 0 failures**, the new `gaps` suite included.

**The gap (Saltfell, the Longhouse, RIME).**
- The rime `table_3m` at (−5, 22, −40), rot 94, by the west column row.
- A roll into it put the Bearer *inside* the table's convex hull, hung 2 cm off the floor.
- The same failure the hide tent had: a detailed hero hull the physics server stops naming as a wall.

**The fix, in kit data (no area JSON hand-edited):**
- `table_3m` and `bench_3m` take `"hull": "simple"` (≤ 32 points), the tent's remedy.
- That exposed a second trap: a capsule perched on the column's 0.3 m plinth lip (7.5 cm proud of the post) against
  the post. The plinth is now dress (`no_collide`); the post is the column's wall. This applies to every `column_4m`.

**New `gaps` suite.** 25 rolls into that table from a fan of starts (z −40.4 … −41.6) and angles (±25°):
- none leaves him hung;
- every one walks back out (east, else along the wall).
- Foes are removed for the check: the Netmender wakes within 4 m, and her body would part him into the corner.

**The sweep: `tools/audit_pinch.sh`** (`tools/pinch_audit.gd`; `--areas=a,b`, `--out=gaps.json`).
- Builds every area in THAW and RIME.
- Lists each pair of solid bodies whose footprints, above step height, stand closer than the capsule's diameter
  (0.68 m) without touching.
- ROUTE marks the ones the navmesh reaches within 1 m of, and that lie within 2 m of a navmesh path from the start
  to a hearth, portal, pickup or gate.
- **Before: 782 gaps, 23 on a route (13 sites). After: 647 gaps, 4 route entries**, all left by judgement:
  - a 0.62 m notch in Kettle's floe ring (irregular rock hulls; denser spacing and posts both failed other audits);
  - two NPC cooks by Tarnhall's ale vat (NPC bodies, not geometry);
  - a 3 cm hall/gate seam (too narrow to enter).
- The off-route gaps (rocks, scatter, props against walls) are listed in the JSON, not fixed.

**Fixed through the generators:**
- Saltfell: the shed's net pile off the boat-shed corner.
- Lowe:
  - the kin post off the mound steps;
  - the peat sled set against the bothy. Off it pinched a capsule, and further off bared `lw_three_spades` to the
    collision audit.
  - The arena sod wall packed at 1.1 m.
- Kettle: the Breathing Hole's floe ring at 1.0 m. Unseen posts were tried and failed the collision audit as
  invisible walls, so they're gone.
- Coldwell: the rope-rail piece 0.14 m from the falls' ice dropped.
- Tarnhall:
  - the byres moved 0.2 m west, gable to gable with the hall (a 0.2 m slit beside the through door);
  - the stall partitions run to the wall.

**Collision audit:** 45 / 0. Three baseline offenders now read "gone" (lm_fold_cairn, two Lowe hearthstones), so they
can be dropped from the baseline.

**Open for you:**
- the Kettle notch: hand-tuning those floes' rotations, or a visible infill rock;
- whether the NPC/vat spacing matters to you.

---

## 8. fix/kettle-notch: the floe-ring notch closed, baseline trimmed (2026-11-13)

Branch `fix/kettle-notch` from main c99dd04, head **3ef2fd4**. Full `tools/test.sh`: both audits plus **49 / 49
suites pass, 0 failures**.

**The notch** (the Breathing Hole's floe ring, Kettle Fjord, 0.62 m) is closed with one visible infill ice floe,
placed by `gen_kettle.py`. It is drawn and solid, and reads as part of the ring.
- The first try inserted it mid-list. The scatter picks each piece's mesh in list order, so that re-rolled every
  later floe and opened new notches. It is now appended last, with a comment saying why.

**`pinch_audit`** now treats a gap a third body stands in as filled, not a slot: the midpoint of the closest points
inside another footprint is skipped.

**All-region pinch audit: 509 gaps, 0 on a route.**
- The Tarnhall vat/cooks and the hall/gate seam also drop out, as filled by another body.
- The cooks are untouched, as you asked.

**Collision baseline:** the three "gone" entries are dropped (lm_fold_cairn's blocker and two Lowe hearthstone
entries); nothing else changed. Collision audit 45 / 0, with no new or gone entries.

**Next:** `stream_prof` on main, once you say fix/streaming-followups is merged.
