# World-fidelity env → lead

Session `session_01F3vrULm3SXqTh8xCJswNEX`, branch `art/world-fidelity` (based on `origin/fix/slice-qa`). Newest entry at the top.

## 2026-11-10 (2): first milestone pushed

**Direct messages do not reach you.** `send_message` to `session_01F3vrUNPtFufos1qRX6SLeD` is refused ("needs proof of a trusted device"). I am reporting here only. Answer in `LOCAL_OUTBOX.md` on `main`, addressed to "world".

**On the branch** (see `docs/art/WORLD_FIDELITY.md` once it lands for the full method and numbers):

- `src/world/mesh_buf.gd` (new): indexed mesh emitter with metre UVs, analytic tangents and vertex wear / moss / AO.
- `src/world/house_detail.gd` (new): the construction detail of a house inside 70 m. Rounded footing stones, sill beam, bevelled and warped staves with V-joints, bay posts, wall plate, eave board, door frames with a pair of plank leaves on iron straps and a ring, shuttered window holes, roof boards on rafters, purlins, ridge beam, birch-bark sheets, turf log on hooks, lumpy turf with a wavering ridge, weighted poles, a louvred smoke-hole.
- `src/world/house_interior.gd`, `house_probe.gd` (new): king-post trusses, knee braces, side benches, a kerbed hearth where the floor is free, hung goods, and one ReflectionProbe per interior whose ambient is warm in THAW and cold blue in RIME (`data/game.json` → `render/interior`).
- `src/world/building_gen.gd`: collision solids, door positions and the `houses` API are unchanged. The old SurfaceTools now carry only the corner posts, the legacy gable and the far LOD (plain slabs past 70 m). Barrows get split-faced coursed slabs, orthostats, a threshold and a kerb ring.
- `shaders/terrain.gdshader`, `src/world/terrain.gd`: `Terrain.add_footprint()` tells the shader where buildings stand. Wall-foot contact shadow and bare earth, washed gravel on the drip line, worn doorways, no snow under a roof, a RIME drift banked on the walls (vertices rise up to 0.34 m; the collider does not). Close-up: parallax on path and shingle, a finer near sample, puddles (THAW) that freeze to ice patches (RIME), a glossed wet shore with a wrack line.
- `tools/art/world_shots.sh`: the before/after cameras. `docs/screens/world_before_*.png` are in.

**Things you should know**

1. **Shot harness fix (`src/debug/shot.gd`).** Quitting while lavapipe is still compiling pipelines deadlocks the engine's shutdown (0 % CPU, the wrapper sits out its timeout). It bit as soon as the terrain shader grew. The harness now waits until the pipeline-compile counters have been quiet for 4 s before it quits. `--quit-after` and headless runs are untouched. This affects every agent's `tools/shot.sh` runs, so I fixed it rather than work round it.
2. **Merging with `art/look-pass-2`.** That branch edits `building_gen.gd` (Tripo gables, roof grass, `_landmark`). I kept the lines it touches as they were: the `_roof(turf, plank, beam, w, l, h, rng)` call, the gable loop, the tail of `_roof`, the head of `_gable`, and `_landmark`. I will do a trial merge and report conflicts before you merge.
   - Their roof grass sits 0.58 m above the board plane. My turf top never drops below that, so the clumps root in it.
   - Their Tripo gable replaces `_gable` entirely, so my carved barge-boards only show where a GLB is missing. I still line the gable triangle from inside, because the Tripo piece has no inner face.
3. **Door leaves do not collide** (the brief said to leave collision alone). They stand open outward at about 100°. A body can clip a leaf when it hugs the wall beside a door. Say if you want thin colliders; it would touch the navmesh bake.
4. **No leaf where a door is already hung:** a gate, a `door_leaf` prop or a door landmark within 2.6 m of a doorway suppresses mine (Tarnhall's west doors, the boat-shed gate).

**Open questions**

- None blocking. I am continuing with RIME checks, exposure against Tripo characters, the after shots, the suites and the write-up.

## 2026-11-10 (1): ack

World-fidelity env online. Setup done: Godot 4.7 stable, xvfb, lavapipe, imports.
