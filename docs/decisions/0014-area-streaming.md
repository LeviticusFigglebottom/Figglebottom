# ADR 0014: area streaming

- **Status:** accepted
- **Date:** 2026-11-11
- **Builds on:** ADR 0003 (terrain areas), ADR 0005 (one area per region), ADR 0006 (seams)
- **Numbers:** `docs/qa/STREAMING.md`

## Context

The owner's playtest of the Windows build: "massive lag spikes when changing areas."

Crossing a seam called `Game.travel_to`, which called `AreaBuilder.build` on the main thread, and the frame that did it did not end until the area stood: terrain meshes, houses, scatter, ground cover, props, both navmesh bakes, then the old area freed in one go. Measured on the build box (`tools/qa/stream_prof.gd`, STREAMING.md), that one frame was 3.5 to 12.6 seconds of main-thread work, 2.4 to 10.5 of it ground cover. A cross-area respawn did the same. A rest brought every foe back in one frame (34 to 106 ms).

Seams are continuous ground: both areas hold the same land at the seam (ADR 0006). The player walks toward one for several seconds before reaching it.

## Options

1. **Slice the build on the main thread.** Turn `AreaBuilder.build` into steps and run a few milliseconds of them a frame. The step sizes are the problem: one house is tens of milliseconds, the ground cover is seconds of one loop, and making them smaller means rewriting the builders, which belong to four other lanes and must not change what they draw.
2. **Compute arrays on workers, build nodes on the main thread.** Thread-safe by construction, but the same rewrite: every builder interleaves its arithmetic with the nodes it makes.
3. **Build the whole area on a worker thread, out of the tree, then graft it in.** The builders run unchanged. Godot allows scene chunks to be built off-thread as long as they are outside the active tree; server calls from a worker are queued to the main thread. What has to be handled: the static caches the builders share with live play, RenderingServer calls that return a value (they wait for the main thread), and making the grafted area inert until the crossing.
4. **Keep both areas loaded always.** No build at the seam at all, but the heaviest region is 5.7k nodes and the highland is a chain of seven: memory and draw cost for nothing most of the time.

## Decision

Option 3, with a disk cache for the three things that are pure functions of their inputs.

### The streamer (`src/core/streamer.gd`, a child of `Game`)

- **Looking ahead.** Every `scan_s` it measures the Bearer's distance to each unlocked `AreaPortal` of the live area (group `area_portals`). Inside `preload_dist` it starts making that neighbour ready. If he walks beyond `drop_dist` for `drop_after_s`, or plainly makes for another seam (`retarget_after_s`), the neighbour is let go. The area just left is not made ready again for `recross_cooldown_s`. Nothing is looked for while an arena is sealed (`Game.arena_locked`): a duel gets the whole machine.
- **The worker build.** `AreaBuilder.build_detached(area_id)` runs the same `_build` as the synchronous path on a `WorkerThreadPool` task, then takes the result apart: the bare `Area`, the static world (ground, houses, props, cover; the terrain childless with its chunks after it), and what acts (hearths, gates, spawners, veils, souls, finds, portals, hazards, zone titles, the env rig). It also loads the model scenes those actors will ask for, so no `_ready` reads a GLB on the main thread. A build nobody waits for any more (`AreaBuilder.cancel_worker`) gives up at its next phase.
- **The graft.** The bare area joins the tree **inert** (`Area.set_inert`): hidden, `PROCESS_MODE_DISABLED` (so its bodies stay out of the physics space), out of `nav_src`, no navmesh. The static world is added under it within `budget_ms` a frame. Nothing that acts is in the tree, so no group that play reads (`hearths`, `seams`, enemies, respawners, state listeners) has a member in it and no audio plays from it.
- **Warm-up.** `ShaderWarm.collect` walks the grafted area (budgeted) for every material it draws with; `ShaderWarm.draw` puts sub-pixel specks of them ahead of the camera for `warm_frames`, inside the sun's shadow reach, so colour, depth and shadow pipelines are built before the swap.
- **The crossing** (`Game.travel_to`, now a coroutine): lock the Bearer, dip to black (`fade_out_s`), `Streamer.swap()` (the old area goes inert and silent and leaves the play groups; the new one is shown, enabled and given its env rig), register, snap the state, place the Bearer. Then `Streamer.settle()`: what acts is grafted within `settle_budget_ms` a frame (a soul, a hearth or a veil gets a frame to itself; foes are counted by what the last ones cost), the navmeshes are applied, the game is saved, and the light returns (`fade_in_s`).
- **Not ready in time** (a sprint, a teleport, an empty cache): the black holds while the same steps run at `cold_budget_ms`. Never a half-built area. A neighbour whose story flags changed since it was built (`require_flag`/`absent_flag` in its data, the endings, cleared) is thrown away and built again.
- **Freeing.** The area left is freed from its leaves in within `free_budget_ms` a frame, starting `free_wait_frames` after it was hidden. Never more than two areas stand; a crossing waits for the freeing if a third would be needed.
- **Respawn and rest.** `Game.respawn_player` takes the same path behind the death's black when the kept hearth is in another area. `Game.respawn_dead` (rest and same-area death) calls each spawner's `respawn` within `respawn_budget_ms` a frame and returns when all have. Because that now takes several frames, the Bearer is carried to the hearth before the first foe returns (a Holdfast must not find him lying in its arena), and a frost veil is raised in the same frame as its Holdfast.
- **Slow frames.** Under a software renderer at a frame a second (the QA shot runs) a few milliseconds a frame would stretch a crossing to minutes. When frames run longer than `slow_frame_ms`, every budget becomes `slow_frame_share` of the frame instead.
- **Fallback.** `streaming/enabled: false`, or `--no-streaming` on the command line, puts back the old synchronous `travel_to`. `AreaBuilder.build` is unchanged for callers: the front door, the title's backdrop, every test that builds an area directly.

### Navmeshes (`src/core/nav_baker.gd`)

Once the new area's colliders are all in the tree, `NavBaker`:

1. **Fingerprints** them: a budgeted walk hashing every static body's layer, shape transforms and shapes. A gate opened, a bridge lowered, a flag-gated blocker gone: each changes the fingerprint, with no list of flags to keep.
2. **Reads the cache** on a worker when both states' meshes are there.
3. **On a miss, parses** the source geometry in budgeted slices on the main thread (`NavigationServer3D.parse_source_geometry_data` reads the tree; a slice is 24 top-level nodes, one state at a time) and **bakes** with `bake_from_source_geometry_data_async`, then writes the result to the cache.

The crossing waits (in the dark) for the navmeshes, so foes never wake without one. `Area.bake_navmeshes` (synchronous) is kept for direct builds.

**Runtime re-bakes** (added 2026-11-12, with ADR 0015's gates). A `ShortcutGate` or `FlagGate` opening and the `DrawBridge` coming down call `Area.rebake_navmeshes()`, which hands the area to `Streamer.rebake`: the same `NavBaker` job (fingerprint, cache, sliced parse within `budget_ms`, background bake), run while the game plays. The old regions stay in the map until the new meshes are ready, then `Area.apply_nav` takes the old out and puts the new in within one frame, so there is no frame with overlapping regions and none with no navmesh. Until then the old navmesh still says the way is shut: a foe does not path through an opening for the half second or so the bake takes. `Area.nav_pending` is true from the asking to the swap and `Area.nav_ready` fires at it (`await area.nav_settled()`; tests use `TestBase.nav_wait`). A second asking while one runs starts over from the colliders as they then are. The bridge asks with a delay of its swing (`DrawBridge.LOWER_S`): its collider turns with the deck, and a bake taken at the windlass, as the synchronous one was, saw the deck on end and left it off the navmesh. Without the streamer (`--no-streaming`, a test that builds an area with no world root) it is the synchronous bake as before.

### The cache (`src/core/stream_cache.gd`, `user://cache`)

| what | key | saves |
|---|---|---|
| ground-cover instance buffers (`Scatter.build_veg`) | rules, seed, keep-clear discs, heights, splat | 2.4 to 10.5 s a build |
| terrain chunk and horizon arrays (`Terrain`) | grid, chunk size, heights, splat | 0.2 to 0.4 s |
| baked navmeshes, per state (`NavBaker`), as vertices and polygons | area, collider fingerprint, bounds | 0.4 to 1.5 s |

Every key also hashes the **source of the builder scripts** (their `.gd`, or `.gdc` in an export) and the engine version, so changed code or data can only miss. A missing, truncated or foreign file reads as a miss and the thing is built. Navmeshes are stored as plain arrays, not as saved Resources: `ResourceLoader` would not read the same `user://` file twice in one run (the second load of a path came back null), which turned every repeat visit into a re-bake. Entries are written beside and renamed. The oldest go past 512 MB. `--cache-dir=` moves it and `--no-cache` turns it off. The synchronous build uses the first two as well, so the front door and the test suites gain too; CI starts empty and builds everything.

**Warming ahead of need** (added 2026-11-12). Three ways the cache is filled before the Bearer needs it:

1. **In idle time.** When the streamer has nothing to do for `warm_idle_s` (no neighbour being made ready, no crossing, nothing being freed, no arena sealed), `Streamer._tick_cache_warm` takes the live area's neighbours one at a time (every portal's `to`, locked or not) and has a worker compute whichever of the terrain arrays and the ground cover is not in the cache (`AreaBuilder.warm_cache`: `Terrain.cache_only`, `Scatter.build_veg` with no area). Arithmetic and a file write: no mesh, no node, nothing in the tree, no RenderingServer call. A preload that becomes wanted calls it off (the worker looks at the flag every row of ground) and starts at the next look; a synchronous build waits the few milliseconds it takes to let go. Navmeshes are not warmed this way: the parse needs the area's colliders in the tree.
2. **By a tool.** `tools/qa/warm_cache.sh` fills the cache for all seven areas, navmeshes of a new journey included (it builds each area and runs `NavBaker`).
3. **Shipped.** `StreamCache` also reads from a second, read-only directory: `cache_seed` beside the executable, or `--cache-seed=PATH`. Not wired into the export or CI (that is the release lane's call); STREAMING.md says how.

### Thread safety

- **`BuildLock`** guards the caches a build shares with live play: `MaterialLib.get_mat`/`hero_mat`/`tex_set`, `KitLib.instance`/`add_collision`, `Forest._mesh`/`_hero_len`. The worker locks. The main thread only locks while a worker build runs, and never sleeps on it: it spins on `try_lock` and flushes the RenderingServer queue, because the worker may be holding the lock while it waits for the main thread to answer a read. Having the lock, it flushes once more: a material the worker has just put in the cache is only allocated until the main thread carries out its queued creation.
- **`World`** flag and area-flag reads and writes take a mutex (the worker reads flags to decide what to build).
- **Nothing with an engine-wide dirty list is made on the worker.** `StandardMaterial3D`, `ParticleProcessMaterial`, `FogMaterial` and `GradientTexture2D` each register with a list that the main thread works through every frame (the material's shader is settled there). A worker still setting the same object up at that moment can corrupt the heap. This cause is inferred, not proven: a full-game walk crashed once mid-build (headless) and a renderer run once ("double free or corruption"), neither with a symbolised trace, and neither came back in the runs made after the change below. So the pieces of a build that make them (ambient particles, smoke, a fall's spray, weather, fog pockets) are wrapped in `AreaBuilder._for_main`: on the main thread they run in place, on a worker they are kept and the Streamer runs them during the graft. `KitLib`'s two shared `StandardMaterial3D`s are made through `BuildLock.on_main`, which has the main thread do it and waits.
- **`BuildProf`** keeps its lap state per thread: the main thread may be lapping a synchronous re-bake (the drawbridge) while a worker laps a build.
- **Scripts are compiled at boot** on the main thread (`Streamer._load_scripts`, about 0.3 s on the build box), so a worker build never compiles one while the main thread runs others.
- **One build at a time.** The builders' own statics (`BuildingGen._hd`, `Scatter._mesh_cache`, ...) are not locked; instead `AreaBuilder.build` on the main thread waits for a worker build to end first (`Streamer.yield_to_sync_build`).
- **RenderingServer reads from the worker** (`PrimitiveMesh.surface_get_arrays` in `ProcMesh.append` and `MeshBuf.append_mesh`, `Texture2D.get_image`, loading a scene) block until the main thread flushes its queue. One flush a frame made a build take as many frames as it has reads (over a minute under a software renderer). So `ProcMesh.arrays_of` keeps a primitive's arrays per shape, and while the worker is in a phase that asks (`BuildLock.computing` is false) the streamer spends three quarters of the build stage's budget flushing.

### Quitting (added 2026-11-12, after a hang on exit)

**What happened.** Two full-game walks printed their result and never exited. Each ended beside a seam with a neighbour being built on a worker. `TestBase.finish` (and after it both `_exit_tree`s) called `Streamer.reset`, which called the build off and waited for the worker in `BuildLock.wait_idle`, three times 120 s; then the engine's own join of the worker pool at exit waited for ever. The player quitting near a seam would have met the same.

**Cause, as far as it was established.** Reproduced with `tools/qa/quit_probe.gd` and narrowed by experiment (the engine binary has no symbols, so the engine-side reason is not named here):

- The worker was not building. The build had seen the cancel and returned; the task was in `Streamer._preload_actors`, inside `load()` of the first model scene (a `.glb`) not yet in the resource cache.
- **A scene loaded with `load()` from a WorkerThreadPool task does not return until the main thread has run a frame.** Measured: four seconds of the main thread waiting outside the frame loop, flushing the RenderingServer all the while, and the load had not returned; one frame later it had. Textures and shaders loaded the same way return at once. `ResourceLoader.load_threaded_request` from the worker completes by itself, but `load_threaded_get` from the worker waits for a frame in the same way; from the main thread it returns in 0.03 to 0.18 ms.
- `wait_idle` runs outside the frame loop (it is what a synchronous build, the return to the title and `_exit_tree` use), so it could never release such a worker. In play nobody noticed: frames kept coming, and each scene load cost the worker one of them.
- A second trap found on the way: with the build posted as a low-priority task, a threaded load it asked for never left "in progress", every other pool thread standing idle; posted at high priority, the same load completed in about 14 ms. The likely reason is the pool's limit on low-priority tasks running at once (one, on four cores, by the engine's default ratio), the load being such a task itself. That reading is inferred from the behaviour, not read from the engine.

**Fix.**

- `BuildLock.wload(path)` replaces `load()` for scenes wherever a worker build can reach it (`KitLib`, `BuildingGen`, `Forest`, `Scatter`, `FrostVeil._hero`, `Streamer._preload_actors`). On a worker it requests a threaded load, polls it, and has the main thread collect the result through `BuildLock.on_main`, which every pump answers: the frame-loop pumps and the waits outside it. What it loaded is kept until the next build starts. On the main thread it is `load()`.
- The build task is posted at high priority, so the pool's low-priority place is free for the loads it asks for.
- `_preload_actors` looks at the cancel flag between scenes and is skipped for a build that was called off.
- `Game.quit(code)` is the way out for the pause sheet, the window's close request (`auto_accept_quit` is off; `Game` answers `NOTIFICATION_WM_CLOSE_REQUEST`), `TestBase.finish` and the QA tools: `Streamer.shutdown` calls every worker off and sees them end a frame at a time while the main loop still runs, then the tree quits. A bare `get_tree().quit()` (the debug tools in `src/debug/`) still ends in `Game._exit_tree`, whose wait now does release the worker.
- `tools/qa/quit_check.sh` quits with each kind of work in flight (a preload, the cache warming, a re-bake, a crossing) in each way (`Game.quit`, a bare tree quit, the close request), each as a process under a timeout; the streaming suite runs three of those cases itself.

**New rule for builders:** a scene is loaded with `BuildLock.wload`, never `load`, in anything a build runs.

## Consequences

- A seam crossed with the neighbour ready is a dip to black of a few tenths of a second with no frame over the budget; the numbers, per area, are in STREAMING.md.
- **The first visit to an area on a machine** needs its ground cover computed once. The idle-time warming does that for the neighbours while the Bearer is busy in the area before; only a player who goes straight from an area's entrance to its next seam in less time than the worker needs can still meet a held black (nothing freezes). A shipped seed removes even that.
- A worker build is slower than the same build on the main thread (each RenderingServer read waits a frame). It is time nobody sees.
- What acts appears a few frames after the swap, behind the black. The black is therefore as long as the area's cast is costly: a region with twenty foes holds it longer than an empty one.
- **Generated building meshes are not cached.** The houses interleave mesh generation with the nodes and colliders they make; caching the meshes alone would mean restructuring `BuildingGen`/`HouseDetail`, which this change was not to do. They are built on the worker (0.1 to 0.6 s), off the main thread.
- **Runtime re-bakes no longer freeze a frame**, and the routes through an opened gate exist a moment later, not in the same frame: anything that must path through it at once waits for `nav_ready`. The suites that did (gates, steading, lowe, tarnhall, fullslice, the full-game walks) now call `nav_wait()`.
- The idle-time warming uses one worker core for some seconds after each arrival, on a first visit only.
- The front door still builds synchronously behind the title's veil, faster for the cache.
- A worker build no longer loses a frame to every scene it loads; how much sooner a neighbour is ready for it was not measured again.
- New rules for builders: anything that acts must be created in the entity section of `AreaBuilder._build` (it is marked late by position); a static cache that both a build and live play reach must take `BuildLock`; and anything that makes a `StandardMaterial3D`, a `ParticleProcessMaterial`, a `FogMaterial` or a `GradientTexture2D` at build time must go through `AreaBuilder._for_main` (or `BuildLock.on_main`).
- Tests that count on `travel_to` being instantaneous must wait for `current_area_id` and `player.input_enabled`, as the full-game walks already do.
