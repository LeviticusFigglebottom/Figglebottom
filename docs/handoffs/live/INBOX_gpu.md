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
