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
