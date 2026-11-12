# Area streaming: the numbers

_Branch `feat/streaming-job1`, 2026-11-11. Design and reasons: `docs/decisions/0014-area-streaming.md`._

The complaint was "massive lag spikes when changing areas". This is what one area change cost before, what it costs now, and how to measure it again.

## Read this first

- **These timings are relative.** They were taken on the build box: four slow shared cores (Xeon 2.1 GHz), no GPU, headless (the dummy renderer, so mesh and texture uploads cost nothing here) unless a table says otherwise. Another agent's test and render jobs ran on the same cores throughout. A desktop CPU is roughly three times faster per core. **The real-GPU worker must re-measure**, with a renderer, on the target machine.
- **What is counted.** `BuildProf` (`src/core/build_prof.gd`) books main-thread milliseconds per phase. "Worst frame" is the most streaming work any single frame carried during a crossing (or a rest, or a respawn): build, graft, swap, state snap, spawning, navmesh work, save, freeing. It is not the frame time: game logic and rendering are on top of it, and were there before. "Longest frame" in the test log is wall-clock and noisy on this box.
- **Budget.** `data/game.json` → `streaming`. `budget_ms` 4 while the Bearer plays, `settle_budget_ms` 8 behind the dip to black, `hitch_ms` 30 is what the suite asserts on.

### To measure again

```
# BEFORE: the synchronous build, cache off (what the game did at every area change)
godot --headless --path . -- --scene=res://tools/qa/stream_prof.tscn --no-cache --prof-out=/tmp/before.md

# AFTER: every area made ready as near a seam, crossed into, rested in, turned, left;
# once from an empty cache, once warm
godot --headless --path . -- --scene=res://tools/qa/stream_prof.tscn --prof-stream --prof-out=/tmp/after.md

# the same with a renderer, so uploads and pipeline builds are in the numbers (the one to run on the GPU box)
godot --path . --rendering-driver vulkan --resolution 1920x1080 \
  -- --scene=res://tools/qa/stream_prof.tscn --prof-stream --prof-out=/tmp/after_gpu.md

# the suite (asserts on the budget; prints the re-bake, release and warming numbers too)
tools/test.sh streaming

# fill the cache for every area ahead of time (see "Warming the cache")
tools/qa/warm_cache.sh [--cache-dir=PATH]

# A/B in the running game: the old synchronous area change on the same build
godot --path . -- --no-streaming
# a line of streamer state every two seconds in the log
STREAM_DBG=1 godot --path .
```

`--prof-areas=a,b` limits either mode to some areas. `--cache-dir=PATH` and `--no-cache` apply to the game as well.

## Headline

| | before | after (cache warm) | after (first visit on a machine) |
|---|---|---|---|
| main-thread work to change area, spread over the frames before and during the crossing | 3,750 to 13,329 ms | 83 to 136 ms of work, plus 113 to 494 ms spent answering the worker's renderer reads inside the per-frame budget (220 to 629 ms in all) | 184 to 404 ms of work, plus 108 to 734 ms answering (338 to 1,138 ms in all) |
| ...of which in one frame | all of it | 12 to 22 ms (worst frame) | 19 to 27 ms (worst frame) |
| what the player sees | a freeze of 4 to 13 s | a dip to black of 0.25 to 0.34 s | a dip to black of 0.6 to 1.2 s, if the area was ready |
| neighbour made ready ahead in | (not done) | 0.4 to 1.2 s, on a worker | 3.2 to 12.5 s, on a worker |
| freeing the area left | 67 to 101 ms in one frame | 2.8 to 4.3 ms a frame over 6 to 33 frames | same |
| a rest (every foe brought back) | 31 to 118 ms in one frame | 6 to 8 ms worst frame (8 to 18 in an earlier, busier run) | same |
| the turn THAW to RIME (settle frame) | 1 to 3 ms + the respawn above | 8 to 16 ms worst frame, respawn included | same |
| a gate opening or the bridge coming down (navmesh re-bake) | 622 to 756 ms in one frame (the Lowe) | 10 to 15 ms worst frame of nav work, 26 ms once; routes open 0.5 to 0.6 s later | same |
| synchronous build phases on the main thread during a crossing | all of them | none | none |

At the Bearer's run speed (7.5 m/s) the 70 m preload distance is 9.3 s of walking. With a warm cache every area is ready in under 2 s on this box. With an empty cache Saltfell (12.5 s), the Reach (8.9 s), the Lowe (8.6 s) and the Coldwell (7.8 s) may not be ready if he sprints straight at the seam: the black then holds until they are, at `cold_budget_ms` a frame, with nothing frozen. That happens once per area per machine (and again after a game update, because the cache key includes the builders' source).

## Before

Synchronous `AreaBuilder.build`, then `add_child`, the deferred `bake_navmeshes`, `StateDirector.snap`, and `RH.free_gently` of the old area. Everything in this table happened inside one frame of `Game.travel_to` (cache off, headless).

| phase | saltfell_steading | lowe_barrows | kettle_fjord | tarnhall | thornwold | shepherds_reach | coldwell |
|---|---:|---:|---:|---:|---:|---:|---:|
| def parse | 1 | 2 | 3 | 4 | 4 | 6 | 3 |
| terrain setup | 1 | 0.4 | 0.3 | 0.3 | 0.3 | 0.3 | 0.2 |
| terrain mesh | 424 | 359 | 227 | 175 | 139 | 170 | 214 |
| terrain horizon | 52 | 83 | 48 | 49 | 44 | 40 | 49 |
| terrain collider | 1 | 1 | 1 | 0.4 | 0.3 | 0.4 | 1 |
| terrain (other) | 1 | 1 | 0.3 | 0.3 | 0.3 | 0.3 | 0.3 |
| water, hazards | 3 | 0.4 | 4 | 2 | 0.1 | 2 | 4 |
| houses | 588 | 158 | 207 | 438 | 0.0 | 0.0 | 110 |
| pieces, props, landmarks | 133 | 0.1 | 125 | 82 | 35 | 120 | 171 |
| entities, spawners | 17 | 1 | 6 | 16 | 0.5 | 1 | 10 |
| scatter stones, fences | 210 | 32 | 24 | 20 | 9 | 11 | 30 |
| scatter ground cover | 10615 | 7002 | 2435 | 4174 | 3762 | 6607 | 6687 |
| forest | 0.0 | 0.0 | 0.0 | 0.0 | 131 | 0.0 | 0.0 |
| weather, traps, wayside | 186 | 248 | 13 | 23 | 394 | 242 | 17 |
| indoor marks, ambient | 11 | 3 | 2 | 5 | 1 | 1 | 2 |
| enter tree | 285 | 81 | 127 | 67 | 108 | 83 | 90 |
| nav bake thaw | 355 | 305 | 200 | 185 | 296 | 280 | 717 |
| nav bake rime | 339 | 346 | 255 | 298 | 360 | 406 | 796 |
| state snap | 8 | 2 | 3 | 4 | 6 | 4 | 5 |
| first frames (2) | 2 | 2 | 1 | 1 | 1 | 1 | 1 |
| free old area | 98 | 67 | 68 | 94 | 101 | 84 | 70 |
| **total** | **13329** | **8694** | **3750** | **5637** | **5392** | **8058** | **8975** |

State changes and teardown, each one frame:

| area | nodes | first frame ms | snap THAW ms | snap RIME ms | flip pre ms | flip settle ms | respawn ms | free ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| saltfell_steading | 3695 | 2 | 8 | 9 | 1 | 1 | 111 | 98 |
| lowe_barrows | 2142 | 2 | 2 | 2 | 0 | 1 | 71 | 67 |
| kettle_fjord | 1447 | 1 | 3 | 2 | 1 | 1 | 45 | 68 |
| tarnhall | 2628 | 1 | 4 | 3 | 1 | 2 | 118 | 94 |
| thornwold | 6016 | 1 | 6 | 6 | 3 | 3 | 39 | 101 |
| shepherds_reach | 2372 | 1 | 4 | 7 | 1 | 1 | 43 | 84 |
| coldwell | 1484 | 1 | 5 | 7 | 0 | 1 | 31 | 70 |

- **Ground cover is 65 to 82 % of every build** (`Scatter.build_veg`: a GDScript loop over every square metre of the playable land).
- The navmesh bakes are 0.5 to 1.5 s more; the houses up to 0.6 s; the terrain meshes 0.2 to 0.5 s.
- The flip itself (`pre_transition`, `apply_state`) was never the problem: 1 to 3 ms. The respawn that follows it was: every foe built in one frame.

## After

### Crossing into each area, made ready ahead

Each area is made ready the way the Streamer does it near a seam, then crossed into with `Game.travel_to`. "Made ready" is the worker build plus the budgeted graft and material collection, start to ready. "Black" is from the call to `travel_to` to the Bearer's hands being free: fade out, swap, what acts joining, navmeshes, save. Headless.

| area | nodes | made ready, cold cache ms | made ready, warm cache ms | black, cold ms | black, warm ms | swap frame ms | worst frame, cold ms | worst frame, warm ms | next worst, warm ms | what the worst frame held (warm) | nav bake thaw/rime, cold ms (background) | nav from cache, warm | sync phases |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| saltfell_steading | 3695 | 12490 | 1241 | 897 | 341 | 8.9 | 26.9 | 21.9 | 11.3 | graft: what acts 22;  | 286 / 341 | [true, true] | none |
| lowe_barrows | 2142 | 8600 | 490 | 744 | 276 | 11.6 | 18.9 | 15.8 | 13.5 | graft: what acts 13; free: old area 3;  | 301 / 328 | [true, true] | none |
| kettle_fjord | 1447 | 3215 | 494 | 573 | 249 | 7.5 | 21.5 | 11.5 | 11.2 | graft: deferred (foes raised) 9; free: old area 3;  | 202 / 215 | [true, true] | none |
| tarnhall | 2628 | 5532 | 798 | 647 | 289 | 10.4 | 20.8 | 13.6 | 13.0 | swap 10; state snap, place Bearer 3;  | 200 / 228 | [true, true] | none |
| thornwold | 6016 | 5615 | 659 | 763 | 303 | 14.2 | 21.6 | 21.3 | 18.1 | swap 14; state snap, place Bearer 7;  | 297 / 346 | [true, true] | none |
| shepherds_reach | 2372 | 8859 | 372 | 747 | 264 | 16.2 | 22.5 | 20.5 | 14.4 | swap 16; state snap, place Bearer 4;  | 322 / 295 | [true, true] | none |
| coldwell | 1484 | 7765 | 753 | 1213 | 248 | 7.8 | 19.9 | 13.7 | 10.3 | graft: what acts 11; free: old area 3;  | 855 / 807 | [true, true] | none |

- The warm-cache worst frames are a soul or a hearth joining the tree (its model is instanced on the main thread: 10 to 20 ms here), or, in Thornwold, the swap itself (6,016 nodes shown and their bodies put into the physics space in one frame: 14 ms).
- With an empty cache the black is longer because the navmeshes are baked (in the background) before the light returns: 0.2 to 0.8 s per state here, both states at once.
- **No synchronous build phase ran on the main thread in any crossing.**

### Freeing, a rest, the turn to RIME

| area | foes raised | free: worst frame ms | free: frames | rest: worst frame ms | turn to RIME: worst frame ms | what it held |
|---|---:|---:|---:|---:|---:|---|
| saltfell_steading | 19 | 2.8 | 7 | 5.9 | 10.2 | flip: apply_state 2.4; flip: save 0.9; respawn: foes 7.0;  |
| lowe_barrows | 11 | 4.3 | 18 | 7.5 | 10.6 | flip: pre_transition 6.7; flip: wave particles 3.9;  |
| kettle_fjord | 11 | 3.1 | 9 | 6.8 | 7.5 | flip: pre_transition 5.4; flip: wave particles 2.1;  |
| tarnhall | 15 | 3.1 | 6 | 6.6 | 8.8 | flip: apply_state 2.7; flip: save 0.8; respawn: foes 5.2;  |
| thornwold | 8 | 3.6 | 10 | 7.7 | 16.2 | flip: pre_transition 9.5; flip: wave particles 6.7;  |
| shepherds_reach | 11 | 3.1 | 33 | 7.2 | 10.9 | flip: apply_state 3.4; flip: save 1.0; respawn: foes 6.6;  |
| coldwell | 8 | 3.1 | 9 | 7.3 | 8.2 | flip: apply_state 1.3; flip: save 1.0; respawn: foes 5.8;  |

Main thread waited at most 0.0 ms for a cache a worker build held (BuildLock). Cache: 35 hits, 21 misses.

"Foes raised" is how many the turn to RIME brought back, a few a frame (`respawn_budget_ms`). The turn's settle frame holds `apply_state`, the save, and that frame's share of foes. A cross-area respawn (the kept hearth in another area) takes the crossing path behind the death's black: the streaming suite measured 13 to 23 ms for its worst frame over five runs.

### Per phase, cache warm

Main-thread milliseconds, with worker-thread milliseconds in brackets. The worker columns are wall-clock on a worker thread: they include waiting for the main thread to answer RenderingServer reads, so a worker phase can read longer than the same phase did on the main thread.

| phase | saltfell_steading | lowe_barrows | kettle_fjord | tarnhall | thornwold | shepherds_reach | coldwell |
|---|---:|---:|---:|---:|---:|---:|---:|
| flush: worker's render commands | 494 | 166 | 199 | 330 | 252 | 113 | 223 |
| def parse | 0 (+1 w) | 0 (+1 w) | 0 (+2 w) | 0 (+2 w) | 0 (+2 w) | 0 (+2 w) | 0 (+1 w) |
| terrain setup | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain mesh | 0 (+26 w) | 0 (+28 w) | 0 (+13 w) | 0 (+19 w) | 0 (+16 w) | 0 (+15 w) | 0 (+27 w) |
| terrain horizon | 0 (+16 w) | 0 (+20 w) | 0 (+14 w) | 0 (+20 w) | 0 (+24 w) | 0 (+17 w) | 0 (+38 w) |
| terrain collider | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain (other) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| water, hazards | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+1 w) | 0 (+0 w) |
| houses | 0 (+556 w) | 0 (+157 w) | 0 (+163 w) | 0 (+421 w) | 0 | 0 | 0 (+189 w) |
| pieces, props, landmarks | 0 (+208 w) | 0 (+0 w) | 0 (+133 w) | 0 (+141 w) | 0 (+51 w) | 0 (+102 w) | 0 (+286 w) |
| entities, spawners | 0 (+2 w) | 0 (+1 w) | 0 (+1 w) | 0 (+18 w) | 0 (+0 w) | 0 (+1 w) | 0 (+4 w) |
| scatter stones, fences | 0 (+133 w) | 0 (+34 w) | 0 (+23 w) | 0 (+15 w) | 0 (+18 w) | 0 (+13 w) | 0 (+41 w) |
| scatter ground cover | 0 (+69 w) | 0 (+35 w) | 0 (+7 w) | 0 (+13 w) | 0 (+25 w) | 0 (+38 w) | 0 (+43 w) |
| forest | 0 | 0 | 0 | 0 | 0 (+42 w) | 0 | 0 |
| weather, traps, wayside | 0 (+107 w) | 0 (+54 w) | 0 (+6 w) | 0 (+23 w) | 0 (+334 w) | 0 (+62 w) | 0 (+24 w) |
| indoor marks, ambient | 0 (+5 w) | 0 (+3 w) | 0 (+2 w) | 0 (+4 w) | 0 | 0 | 0 (+2 w) |
| worker: models read ahead | 0 (+63 w) | 0 (+124 w) | 0 (+91 w) | 0 (+70 w) | 0 (+79 w) | 0 (+57 w) | 0 (+48 w) |
| graft: area root | 0.0 | 0.1 | 0.0 | 0.1 | 0.0 | 0.0 | 0.0 |
| graft: static world | 4 | 3 | 2 | 7 | 9 | 5 | 5 |
| graft: particles, weather (main-thread steps) | 7 | 7 | 9 | 10 | 7 | 12 | 9 |
| warm: collect materials | 7 | 4 | 2 | 4 | 9 | 5 | 3 |
| swap | 9 | 12 | 7 | 10 | 14 | 16 | 8 |
| state snap, place Bearer | 2 | 2 | 2 | 3 | 7 | 4 | 2 |
| graft: what acts | 48 | 38 | 37 | 45 | 37 | 39 | 33 |
| graft: deferred (foes raised) | 41 | 31 | 22 | 52 | 21 | 20 | 21 |
| nav fingerprint | 6 | 5 | 2 | 4 | 15 | 4 | 2 |
| nav apply | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 |
| save | 10 | 1 | 1 | 1 | 1 | 1 | 1 |
| **total** | **629 (+1187 w)** | **266 (+457 w)** | **283 (+457 w)** | **466 (+747 w)** | **371 (+593 w)** | **220 (+310 w)** | **306 (+703 w)** |

The first row, "flush: worker's render commands", is the main thread answering the reads a worker build asks of the renderer (primitive arrays, texture images, scene loads). It is not build work: while the worker is in a phase that asks, the streamer spends up to three quarters of that frame's `budget_ms` (3 of 4 ms) pumping the queue so the build does not take a frame per read. It is the largest main-thread row and it is inside the per-frame budget, before the crossing, while the Bearer walks. The work rows without it come to 83 to 136 ms an area.

### Per phase, cache empty

| phase | saltfell_steading | lowe_barrows | kettle_fjord | tarnhall | thornwold | shepherds_reach | coldwell |
|---|---:|---:|---:|---:|---:|---:|---:|
| def parse | 0 (+1 w) | 0 (+1 w) | 0 (+2 w) | 0 (+1 w) | 0 (+2 w) | 0 (+2 w) | 0 (+1 w) |
| flush: worker's render commands | 734 | 192 | 265 | 345 | 410 | 108 | 174 |
| terrain setup | 0 (+1 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain mesh | 0 (+521 w) | 0 (+451 w) | 0 (+228 w) | 0 (+203 w) | 0 (+200 w) | 0 (+234 w) | 0 (+326 w) |
| terrain horizon | 0 (+89 w) | 0 (+71 w) | 0 (+74 w) | 0 (+81 w) | 0 (+80 w) | 0 (+83 w) | 0 (+102 w) |
| terrain collider | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain (other) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| water, hazards | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+1 w) |
| houses | 0 (+708 w) | 0 (+184 w) | 0 (+221 w) | 0 (+441 w) | 0 | 0 | 0 (+120 w) |
| pieces, props, landmarks | 0 (+300 w) | 0 (+0 w) | 0 (+200 w) | 0 (+157 w) | 0 (+36 w) | 0 (+114 w) | 0 (+201 w) |
| entities, spawners | 0 (+2 w) | 0 (+1 w) | 0 (+2 w) | 0 (+21 w) | 0 (+0 w) | 0 (+1 w) | 0 (+0 w) |
| scatter stones, fences | 0 (+295 w) | 0 (+37 w) | 0 (+24 w) | 0 (+15 w) | 0 (+11 w) | 0 (+11 w) | 0 (+26 w) |
| scatter ground cover | 0 (+10235 w) | 0 (+7635 w) | 0 (+2304 w) | 0 (+4475 w) | 0 (+4393 w) | 0 (+8253 w) | 0 (+6881 w) |
| forest | 0 | 0 | 0 | 0 | 0 (+476 w) | 0 | 0 |
| weather, traps, wayside | 0 (+161 w) | 0 (+55 w) | 0 (+6 w) | 0 (+24 w) | 0 (+288 w) | 0 (+44 w) | 0 (+22 w) |
| indoor marks, ambient | 0 (+6 w) | 0 (+3 w) | 0 (+2 w) | 0 (+4 w) | 0 | 0 | 0 (+1 w) |
| worker: models read ahead | 0 (+91 w) | 0 (+131 w) | 0 (+107 w) | 0 (+71 w) | 0 (+72 w) | 0 (+58 w) | 0 (+41 w) |
| graft: area root | 0.1 | 0.0 | 0.0 | 0.0 | 0.1 | 0.0 | 0.1 |
| graft: static world | 8 | 3 | 2 | 2 | 6 | 4 | 5 |
| graft: particles, weather (main-thread steps) | 25 | 6 | 9 | 6 | 5 | 10 | 8 |
| warm: collect materials | 5 | 3 | 2 | 3 | 7 | 4 | 3 |
| swap | 5 | 9 | 8 | 7 | 9 | 12 | 9 |
| state snap, place Bearer | 9 | 5 | 3 | 3 | 4 | 3 | 2 |
| graft: what acts | 85 | 52 | 77 | 49 | 56 | 57 | 55 |
| graft: deferred (foes raised) | 62 | 50 | 41 | 95 | 45 | 46 | 55 |
| nav fingerprint | 5 | 3 | 2 | 5 | 12 | 4 | 2 |
| nav parse | 201 | 106 | 37 | 71 | 110 | 89 | 62 |
| nav apply | 0.1 | 0.1 | 0.1 | 0.1 | 1 | 0.2 | 0.1 |
| save | 0.2 | 1 | 3 | 1 | 1 | 1 | 1 |
| **total** | **1138 (+12409 w)** | **428 (+8571 w)** | **449 (+3171 w)** | **587 (+5494 w)** | **666 (+5560 w)** | **338 (+8801 w)** | **376 (+7723 w)** |

### Cache: hit against miss

| what | miss (built) | hit (read) | on disk, all seven areas |
|---|---|---|---|
| ground cover, per area | 2,356 to 10,537 ms | 6 to 71 ms | 65 MB |
| terrain chunks + horizon, per area | 229 to 571 ms | 25 to 37 ms | 18 MB |
| navmeshes, both states, per area | 42 to 221 ms of parsing on the main thread (budgeted) + 0.4 to 1.5 s of baking in the background | 2 to 13 ms (the fingerprint walk; the read is on a worker) | 0.6 MB |

- The whole cache for seven areas is about 84 MB in `user://cache`; entries past 512 MB are dropped oldest first.
- The synchronous build reads the first two as well: the front door and every suite that builds an area are that much faster on a second run. CI starts empty and builds everything.
- A corrupt, truncated or foreign entry reads as a miss (the suite overwrites every entry with junk and crosses again).

### With a renderer (llvmpipe, 320x180)

The same streamed walk for two areas with a real RenderingServer (Vulkan on llvmpipe, no GPU), so the worker's queued mesh and texture uploads are really carried out on the main thread and the warm-up specks are really drawn. Three other test processes shared the four cores during this run.

- llvmpipe draws about a frame a second here, so every budget was the slow-frame share (a fifth of the frame): the worst-frame milliseconds are far above the 60-a-second budgets by design. Read the phases against each other, not against 30 ms.
- "flush: worker's render commands" is mostly the main thread waiting inside its own budget to answer the worker's reads (three quarters of a 200 ms budget, frame after frame), not upload work. Without that row the main-thread total is about 170 ms an area, the same as headless: **no upload cost shows on the main thread.**
- The worker columns are a thread starved by the software rasteriser. "Models read ahead" (the cast's GLB scenes, 20 s here against 0.1 s headless) is the one to look at on a real GPU.
- The run ended clean: no error from the renderer, and a screenshot of the Kettle streamed in is the same scene as one built synchronously (compared by eye; particles differ by a few seconds of drift).

| area | nodes | made ready, cold cache ms | made ready, warm cache ms | black, cold ms | black, warm ms | swap frame ms | worst frame, cold ms | worst frame, warm ms | next worst, warm ms | what the worst frame held (warm) | nav bake thaw/rime, cold ms (background) | nav from cache, warm | sync phases |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| kettle_fjord | 1447 | 20757 | 50875 | 26948 | 13629 | 7.4 | 264.7 | 123.3 | 9.4 | graft: what acts 30; nav fingerprint 2; graft: deferred (foes raised) 91;  | 2789 / 2789 | [true, true] | none |
| lowe_barrows | 2142 | 58741 | 56681 | 21838 | 16351 | 6.1 | 240.7 | 147.3 | 7.6 | graft: what acts 41; nav fingerprint 3; graft: deferred (foes raised) 102;  | 3882 / 3882 | [true, true] | none |

Per phase, warm cache, main-thread ms (+ worker ms):

| phase | kettle_fjord | lowe_barrows |
|---|---:|---:|
| def parse | 0 (+1 w) | 0 (+0 w) |
| terrain setup | 0 (+0 w) | 0 (+0 w) |
| flush: worker's render commands | 2334 | 2723 |
| terrain mesh | 0 (+26 w) | 0 (+26 w) |
| terrain horizon | 0 (+38 w) | 0 (+17 w) |
| terrain collider | 0 (+0 w) | 0 (+0 w) |
| terrain (other) | 0 (+0 w) | 0 (+0 w) |
| water, hazards | 0 (+0 w) | 0 (+0 w) |
| houses | 0 (+442 w) | 0 (+2970 w) |
| pieces, props, landmarks | 0 (+3286 w) | 0 (+0 w) |
| entities, spawners | 0 (+1 w) | 0 (+1 w) |
| scatter stones, fences | 0 (+23 w) | 0 (+59 w) |
| scatter ground cover | 0 (+8 w) | 0 (+50 w) |
| forest | 0 | 0 |
| weather, traps, wayside | 0 (+7 w) | 0 (+2975 w) |
| indoor marks, ambient | 0 (+2 w) | 0 (+3 w) |
| worker: models read ahead | 0 (+20099 w) | 0 (+21391 w) |
| graft: area root | 0.0 | 0.0 |
| graft: static world | 3 | 3 |
| graft: particles, weather (main-thread steps) | 32 | 18 |
| warm: collect materials | 3 | 4 |
| warm: draw materials | 1 | 1 |
| swap | 7 | 6 |
| state snap, place Bearer | 2 | 2 |
| graft: what acts | 30 | 41 |
| nav fingerprint | 2 | 3 |
| graft: deferred (foes raised) | 91 | 102 |
| nav apply | 0.1 | 0.1 |
| save | 1 | 1 |
| **total** | **2506 (+23933 w)** | **2904 (+27493 w)** |

## Runtime re-bakes: a gate opens, the bridge comes down

Added 2026-11-12, after the progression gates (ADR 0015) made every region's way on a `ShortcutGate` that opens the moment its Holdfast is released. Before, each opening called `Area.bake_navmeshes` in that frame. Now it calls `Area.rebake_navmeshes()`: fingerprint, sliced parse within `budget_ms`, background bake, and the old navmesh in the map until the new one replaces it in one frame (ADR 0014, "Runtime re-bakes").

Measured in the Lowe by the streaming suite, four runs on this box (headless; other suites on the same cores):

| | before | after |
|---|---|---|
| the bake itself | 622 to 756 ms, one frame, main thread | 276 to 397 ms per state, in the background |
| main-thread nav work in the worst frame, bridge | all of it | 13.7 to 15.1 ms in three runs, 26.4 ms in one (the next worst frame 9.6 to 19.2 ms); the terrain's parse slice is the large one |
| main-thread nav work in the worst frame, release | all of it | 10.4 to 14.2 ms (next worst 9.9 to 12.5 ms) |
| frames carrying nav work | 1 | 17 to 24 |
| release: Holdfast falls to routes open through the gate | the same frame, frozen | 0.52 to 0.62 s later, nothing frozen |
| bridge: windlass to the deck on the navmesh | never (see below) | 3.0 s, of which 2.4 s is the deck's swing |
| synchronous phases on the main thread | nav bake thaw, nav bake rime | none |

- **The release moment end to end** (story flag set, `Game.on_boss_slain`, the gate answers, re-bake, routes open): no frame carries more than 14.2 ms of nav work. The longest frame of that window, wall-clock, was 63 to 94 ms in the first three runs. That was not the navmesh: `Game.on_boss_slain` itself took 92 to 118 ms, placing every soul and find the release brings back in one frame (`AreaBuilder.refresh_flagged`, about 20 to 30 ms a soul here). They are now placed one a frame; `on_boss_slain` measured 30 to 38 ms after that (the first soul and the song's first load), and the window's longest frame 52 ms. **Still over 30 ms on this box**: one soul's instancing is the known largest single item (below).
- **The bridge.** The old bake was taken the frame the windlass turned, with the deck still on end (its collider turns with it), so the deck never was on the navmesh. The re-bake now waits for the swing. The Lowe's nav bounds end 2.5 m out along the deck (z -80), so its navmesh reaches that far and no further; the suite checks that, and the full-game walk's own note "(the deck on the Lowe's navmesh: false)" asks about a point beyond the bounds and is unchanged. Widening the bounds is area data, not touched here.
- **In the gap** the old navmesh still says shut: a foe does not path through the opening for that half second. The Bearer's capsule is not on the navmesh and walks through at once.
- **Not exercised by the `gates` suite**: it builds areas with no world root, where there is no streamer and `rebake_navmeshes` is the synchronous bake as before. The streamed path is covered by the streaming suite (bridge, release gate), `fullslice` and `fullgame_lowe`.

## Warming the cache

Added 2026-11-12. A first visit to an area computed its ground cover at the seam (3 to 12 s on a worker here), and a player who reached the seam first met a held black. Three things now fill the cache earlier.

**Idle time.** With the streamer idle for `warm_idle_s` (2 s; `warm_cache: false` turns it off), the live area's neighbours have their missing terrain and ground-cover entries computed on a low-priority worker, one area at a time. Arithmetic and a file write only: no mesh, no node, no RenderingServer call. Navmeshes are not included (the parse needs the colliders in the tree); they are baked in the background on arrival as before, 0.3 to 0.8 s behind the black.

| measured by the streaming suite, standing in the Lowe with an empty cache | |
|---|---|
| both neighbours (Saltfell, the Kettle) warmed | 17.8 s of idle time, on one worker |
| the Kettle then made ready and crossed into | 3 hits, 0 misses for terrain, horizon and ground cover; 1.2 s from the call to arrival, cold (nothing preloaded) |
| worst frame of that crossing | 15 to 19 ms (next 13 to 16 ms) |
| a synchronous build calling the warming off | 33.5 ms in the one run measured before the finer checks; the suite allows 250 ms. A preload near a seam does not wait: it calls the warming off and starts at the next look. |

**The tool.** `tools/qa/warm_cache.sh` fills the cache for all seven areas: terrain, horizon, ground cover, and both navmeshes as a new journey finds them. Here: the Lowe 8.3 s + 2.7 s for its navmeshes, the Kettle 2.8 s + 1.4 s; two areas 18.5 MB. With the cache it left, a first streamed visit to the Kettle was ready in 1.1 s and black for 0.31 s, navmeshes read from the cache (against 3.2 s and 0.57 s from empty).

**Shipping it with an export** (not wired in: export presets and CI are not this lane's).

1. Export the game. The cache key holds the hash of the builder scripts as the running build has them (`.gdc` in an export, `.gd` in the editor), so the cache must be made by the exported build, not by the editor.
2. Run the exported binary once on the build machine: `GODOT=./rimeholt.x86_64 tools/qa/warm_cache.sh --cache-dir=/abs/path/cache_seed` (it needs `res://tools/qa/warm_cache.tscn` and `.gd` in the export's file filter). About 84 MB for seven areas, mostly ground cover; zstd-compressed already.
3. Ship the `cache_seed` directory beside the executable. `StreamCache` looks there (or where `--cache-seed=PATH` says) when `user://cache` has no entry, read-only; whatever a journey adds (navmeshes after gates open) goes to `user://cache` as before.
4. Nothing else changes: a seed made by another build simply never matches and the game computes its own.

Checked here with the editor binary only (`--cache-seed=` pointing at a filled directory: every entry found, nothing computed). **Not checked with an exported build.**

## What the suite asserts (`tools/test.sh streaming`)

102 checks, from an empty scratch cache (`user://test_streaming`), headless:

- a cold crossing (nothing ready, empty cache) arrives, with both navmeshes baked in the background and no synchronous build phase on the main thread;
- 25 m from a seam the neighbour starts being made ready; it stands in the tree unseen, unprocessing, in none of the groups play reads, with no hearth, foe, seam or navmesh in the world and none of its colliders in the physics space;
- a save made while it is being built holds the current area, hearth and Bearer;
- walked away from, it is kept for `drop_after_s`, then freed, and the node count is back to one area;
- walked toward at walking pace from outside the preload distance, it is ready before arrival (64 m to spare here) and the crossing's second-worst frame is within `hitch_ms`; the swap is one frame within it too;
- never more than two areas alive; the area left is freed;
- the next crossing reads navmeshes, ground cover and terrain from the cache; with every entry corrupted the area is built all the same;
- a rest, the turn to RIME and a cross-area respawn stay within `hitch_ms` with no synchronous phase;
- the bridge lowered: a re-bake is asked for, the old navmesh answers meanwhile, `nav_ready` fires, no frame over `hitch_ms` and no synchronous phase, the navmesh then reaches out onto the deck, two regions stand and no more;
- a release: the way-on gate answers the flag, the old navmesh still says shut, `nav_ready` fires within the budget, and a route runs through the opened gate;
- idle time: from an empty cache both neighbours' ground cover and terrain appear on disk with nothing built or grafted, the next crossing reads them (no miss), and a wanted build calls the warming off.

The budget assertion is on the **second-worst** frame's streaming work: on a shared box one frame can be taken by the OS in the middle of a 4 ms slice, and that is not a hitch of ours. The worst frame is printed beside it.

## Suites run on this branch (headless, this box)

After the follow-up (runtime re-bakes, cache warming), on the merged `feat/streaming` code:

| suite | result | note |
|---|---|---|
| streaming | 102 checks, 0 failures in the last three runs, the last of them on the final code | an earlier run failed one check, "calls the warming off at once (33.5 ms)" against 30 ms; the cancel checks were made finer and the limit for a synchronous build set to 250 ms. In the final-code run the dummy renderer logged `Parameter "m" is null` (`mesh_get_surface_count`) once, from `Weather._gpu` freeing a `CPUParticles3D` on the main thread during a graft; nothing failed. Not explained. |
| gates | 151 checks, 0 failures | (synchronous path: see "Runtime re-bakes") |
| smoke, steading, lowe, tarnhall, deathloop, traps | 11, 49, 25, 39, 26, 22 checks, 0 failures | run twice, the second time before the last change (a release's souls spread over frames) |
| release_scenes, kettle, endings, keepsakes, encounters, boss, lowe_encounters | 32, 34, 85, 64, 66, 27, 98 checks, 0 failures | on the final code |
| fullslice | 112 checks, 0 failures | two runs, the second on the final code |
| fullgame_lowe | 196 checks, 0 failures | one run, on the final code (the bridge and a release gate re-baked in the background) |
| fullgame_kettle, fullgame_tarnhall, fullgame_thornwold, fullgame_reach, fullgame_coldwell, fullgame_ending_kept, fullgame_ending_outsong; houses, thornwold, reach, coldwell, combat, controller, deltas, anim, audio, body, look5, the other five `*_encounters` | not run after the follow-up | before it: see the earlier table in git history (`a9cffc4`); `fullgame_kettle` stalled in the Ice-Cutter duel then, with and without streaming |


## Still over budget, or not verified

- **Real GPU.** Nothing here was measured on one. What can only show there: the cost of the worker's uploads when the main thread flushes them (in the "flush" row with a renderer); whether the warm-up specks really build every pipeline variant the area's meshes need (they are quads: a mesh with another vertex format may still compile its own variant on first sight); the swap frame when several thousand instances become visible at once.
- **The first soul or foe of a kind** costs 15 to 25 ms on this box to instance (skeleton, materials, animation library), on the main thread, alone in its frame. Under 30 ms here; it is the largest single item left.
- **Thornwold's swap frame** (14 ms headless) is the largest swap: 6,016 nodes.
- **A first visit with an empty cache** can still hold the black if the Bearer goes from an area's entrance to its next seam faster than the idle-time warming computes that neighbour (Saltfell: about 12 s of worker time). A shipped seed removes it ("Warming the cache"); the export is not set up to make one.
- **The release frame** is still 30 to 52 ms long here, wall-clock: the first soul the release brings back and the song's first load. None of it is navmesh work.
- **One bridge re-bake frame of 26 ms** of nav parse (the terrain slice) in one run of four; the others 14 to 15 ms. Under `hitch_ms`, over the usual.
- **Runtime re-bakes on a real GPU box, and with foes mid-chase at a gate**: not measured, not staged. The gap is half a second of the old routes.
- **Generated building meshes are not cached** (ADR 0014, Consequences). They are built on the worker: 0.1 to 0.7 s there, nothing on the main thread.
- **The front door** (title to first area) is still a synchronous build behind the title's veil. The cache helps it all the same: Saltfell builds in 2.4 s here with a warm cache, against 13.3 s.
