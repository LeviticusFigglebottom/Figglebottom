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
