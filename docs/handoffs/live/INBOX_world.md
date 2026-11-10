# World-fidelity env → lead

Session `session_01F3vrULm3SXqTh8xCJswNEX`, branch `art/world-fidelity` (based on `origin/fix/slice-qa`). Newest entry at the top.

## 2026-11-10 (6): CI on this branch

**Run 42913988699 at `1b313ff` (main merged in): nothing of mine fails.**

| Suite | Result here | On `main` |
|---|---|---|
| `houses` (new) | 61 checks, 0 failures | not on `main` yet |
| `fullslice` | 106 checks, 0 failures | passes at `fd881f6`, 26 failures at `65b65f6` |
| `tarnhall_encounters` | 109 checks, 0 failures | 1 failure at `65b65f6` ("two benches") |
| `deltas` | 1 failure: `saves carry save_version 3` | same failure at `fd881f6` and `65b65f6` |
| `fullgame_lowe` | 1 failure: `lowe_barrows cleared, its memory as it was left` | same failure at `e3daf04`, `fd881f6`, `65b65f6` |

- **`deltas` and `fullgame_lowe` fail on `main` itself**, with the same check each. They are not from this branch.
- **`fullslice` is intermittent.** It failed once here at `3fb77f7` (the Bearer ended outside the longhouse wall and could not reach the Long Hearth: 14 failures) and passed at `ce498d8` and `1b313ff`. It also fails and passes on `main` between consecutive commits. On my box it failed with 20 failures, starting at the Strand float, well before any house. I found nothing of mine that collides (the `houses` suite asserts it), and the navmesh path from the needle to the Long Hearth is direct in both states.
- **The run for `3ca9229`** (the real-GPU pass) was still going at 23:05Z. I will add its result.

## 2026-11-10 (5): your three messages, and the real-GPU priorities

**Your messages of 19:56, 20:45 and 22:11 all reached me at 22:23.** I still cannot answer them: `send_message` to your session (and to `@parent`) is refused for want of a trusted device. This file is my only channel.

**Branch state:** `origin/main` (`65b65f6`) is merged in. Everything in entries (3) and (4) stands. Pairs you asked for: `world_{before,after}_door_thaw.png`, `_wellhouse_thaw.png`, `_longhouse_in_thaw.png`, and for this pass `world2_{before,after}_kettle_vista_thaw.png`, `_kettle_gorge_thaw.png`, `_coldwell_vista_thaw.png`, `_snow_rime.png`.

**Done for the GPU findings** (table in `docs/art/WORLD_FIDELITY.md`, "Second pass"):

1. **Exposure.** Less forward scatter and bloom in THAW, more ambient and fill; Kettle toned down in its generator; at tier 2 the SSAO is eased and bloom starts later (`render/exposure`).
2. **Cliffs.** Uneven beds, ledges, joints and a macro normal in the terrain shader.
3. **Coldwell horizon.** The horizon mesh and far ground take patches, outcrops and a rolling normal.
4. **RIME snow.** Drift shading, wind ripple, sparkle.

**Please have the GPU worker re-shoot this branch now**, the same 84 views. I need hardware eyes on:

- Kettle vista and start in THAW: is the wash gone and the gorge readable, or is it now flat?
- Any THAW shot under canopy (Thornwold `the_pine`, `hedge_veil`): did the ambient lift help or grey it out?
- Cliff faces at Kettle and Tarnhall: does the macro normal read as rock form or as noise?
- RIME snow at eye height: ripple strength and whether the sparkle shimmers under TAA.
- House interiors: the probes (`HouseProbe`) have only ever been captured by lavapipe.
- `render/exposure/auto`: it is off. Under a software tier-2 run it made the Kettle vista brighter, so I did not trust it. If the worker can spare a pair with it on, I will tune the limits.

**Not done, and why:** Kettle's spire shapes (heightfield generator), rock meshes along cliff lips (scatter rules and area regeneration), straight horizon edges (far grid). Say if you want me to take the generator work; it regenerates the area and its seams.

**Suites green on this state:** smoke, houses, kettle, coldwell, steading, thornwold; placement audit clean.

## 2026-11-10 (4): follow-ups after your merge, ready to merge again

You merged this branch at `ce498d8` (`e3daf04` on `main`). The branch has since **merged `main` back** (one conflict, the reformatted `data/game.json`) and carries these on top. Merging it again is a fast, clean merge.

| Commit | What |
|---|---|
| `316646a` | New suite `houses` (61 checks): collision equals the spec, nothing else collides, LOD hand-over, footprints, a steered capsule through the longhouse door and to the bench wall. |
| `3fb77f7` | A plain core behind the footing stones (no view through the joints). Roofed floors take hoarfrost in RIME, RIME room ambient 0.55 to 0.72. No puddles within 1 m of a wall. The fish-house hearth moves along the room when its spot is taken. Hall and well-house cameras fixed. |
| `2fd8e81` | The 25 final before/after pairs, the cost tables, ADR 0011 numbers. |
| merge | `main` merged in; five `world_merged_*_thaw.png` shots of the combined look. |

**Seen on the merged state:** the Tripo gables sit on these walls without a seam worth fixing, the roof grass roots in the turf, the smoke rises from the louvre. Suites green on the merged state: smoke, houses, steading, lowe, kettle, tarnhall, thornwold, reach, coldwell.

**Still open for you:** items 1 to 4 under entry (3), and the `tarnhall_encounters` flake.

## 2026-11-10 (3): milestone complete, ready to merge

**Branch `art/world-fidelity`.** Write-up: `docs/art/WORLD_FIDELITY.md`. Decisions: `docs/decisions/0011-world-fidelity.md`.

**Since entry (2)**

- **RIME drifts are geometry now** (`HouseDetail.build_drifts`, a rime-only mesh per house). Raising terrain vertices let the bank come up through the longhouse floor: a 1 m grid cannot hug a wall.
- **New suite `houses`** (61 checks): collision boxes equal what each spec implies, nothing else under a house collides, near and far LODs hand over at 70 m, the land knows every footprint, and a steered capsule walks in through the longhouse door and up to the bench wall.
- **Suites green here:** smoke, houses, steading, lowe, kettle, tarnhall, thornwold, reach, coldwell.
- **Before/after pairs** are in `docs/screens/world_before_*.png` and `world_after_*.png`, 25 cameras, all at eye height. I looked at every pair.
- **Cost:** 0 % to +22 % draw calls and +3 % to +35 % triangles per frame at those cameras (table in the write-up). Building an area takes 0.2 to 0.8 s longer. A house is 19k to 74k triangles in 15 to 19 meshes (it was 5k to 13k in 5); past 70 m five plain meshes draw.
- **Trial merge with `origin/art/look-pass-2`: `building_gen.gd` merges clean.** The only conflict is `src/world/scatter.gd`, which I did not touch (it is between `fix/slice-qa` and the look pass).
- **The shot harness prints frame cost** per capture: `[shot] stats <file> draw_calls= primitives= objects=`.

**CI on this branch**

- **`tarnhall_encounters` → "two benches" is a timing flake, and it is on the base too.** CI run 96 failed on `the second goes where he is running to (1 in the air)`. Here it passed once and failed once on my branch, and failed 2 of 4 runs on untouched `origin/fix/slice-qa` (eaa3f09) under the same load. It is the QA env's suite; I left it alone.
- **The edge audit failed on the base as well** (160 unclassed edges in `shepherds_reach`, CI run 71 on eaa3f09). `a8f5c3b` on `fix/slice-qa` addresses it.
- Every other suite was green in CI run 96 (24 suites).

**For you to decide**

1. **Shadow sides at dusk are near black** on houses and barrow facades, before and after. It is the THAW sun and ambient balance outdoors, which I did not change (the sky and the grade are the look pass's). A small lift of the THAW `fill_energy` would help every procedural wall.
2. **Unshadowed fire lights reach through walls.** The Tarnhall hearths (`glow` range 16 m) light the ground outside the hall's long wall. Puddles at the wall foot mirrored them as bright patches, so the terrain now keeps puddles 1 m off any wall. The lights still reach; shortening their range to the hall's half width is area data, not mine.
3. **Door-leaf colliders:** see entry (2), item 3.
4. **The Coldwell well-houses overhang their rock ledges** (`wellhouse_thaw`): the terrain under them is not level. Generator data, not mine.

**Not done**

- Nothing was seen on a real GPU. Ask the GPU worker to shoot `tools/art/world_shots.sh after` at tier 2 and check the probes, the parallax depth and the puddle gloss.
- Decal nodes: not used. Marks are vertex colour and terrain-shader terms (ADR 0011).

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
