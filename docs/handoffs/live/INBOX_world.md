# World-fidelity env → lead

Session `session_01F3vrULm3SXqTh8xCJswNEX`, branch `art/world-fidelity` (based on `origin/fix/slice-qa`). Newest entry at the top.

## 2026-11-11 (9): biome pass, first complete round on `art/biomes`

**Branch `art/biomes`** (cut from `origin/main` c5b918f, then `art/world-fidelity` merged in, so it also carries the light-balance and wayside commits you have not merged yet; it now has main's CI triggers). I still cannot message you; this file is the channel. Both of your notes (CI on main only; take main's `.github`) are done.

**The mechanism (all data, no generator edits at all)**

- `data/biomes/<area>.json`, loaded by `src/world/biome.gd` and laid over the generator's blocks at build time. Keys: `terrain.palette`, `terrain.sets`, `terrain.shader` (rock character), `env.thaw` / `env.rime`, `weather`, `veg`. The format is documented at the top of `biome.gd` and in each file's `_doc`.
- **`veg` key for `feat/poi-thornwold-plants`:** `{"density": {<kind>: scale, 0 removes it}, "swap": {<kind>: <kind>}, "add": [ <scatter rule>, ... ]}`. `add` is empty in all seven files and is theirs to fill; `Biome.veg_rules()` appends those rules to the area's own.
- `--no-biome` (user arg) builds the regions as the generators made them. The before shots use it.
- `shaders/terrain.gdshader`: seven new rock uniforms (`bed_thickness`, `bed_strength`, `joint_vertical`, `joint_spacing`, `streak_strength`, `rock_moss`, `rock_stain`). Defaults reproduce the old schist.
- `src/world/weather.gd`: `pollen*`, `snow*`, `glitter` keys so each region and state has its own particles.

**Per region**

| Region | Added | Still shared |
|---|---|---|
| Saltfell | sets `sf_turf`, `sf_shingle`, `sf_wrack`; thicker warm-stained beds; sideways fine snow in RIME, pearl fog; no ling | rock set (schist), heath set |
| The Lowe | `lw_peat` path; near-unbedded mossy rock, more puddles; blue drift motes in THAW, slow hoar in RIME, lilac fog; ling x1.5 | turf, heath, shingle, rock sets |
| Kettle | `kf_shore`, `kf_granite`; pale upright-jointed granite with water streaks; cool sky fill on the shaded wall; grey fog in place of orange; no snowfall, heavy glitter | turf, shingle sets |
| Tarnhall | `th_grass`, `th_mud`, `th_slate`, `th_rock`; thin blue slate beds; rose fog, big flakes straight down under flat overcast; ling swapped to sedge | none of the four ground layers |
| Thornwold | `tw_needles`, `tw_leaves`, `tw_mud`, `tw_rock`; mossy unbedded boulders; green-gold fog, thick pollen, violet RIME shade | shingle set |
| Shepherd's Reach | `sr_turf`, `sr_scree`, `sr_rock`; pale close-jointed limestone; clear air, thistledown on the wind, spindrift in RIME; no ling, grass x1.3 | heath, path sets |
| The Coldwell | `cw_gravel`, `cw_moss`, `cw_cobble`, `cw_moraine`; blue-stained moraine; cool-white sun, blue RIME shade, glitter, nothing falls | path set |

**Texture ids I substituted or dropped after looking at them:** `withered_grass` (Lowe bog grass: reads as sand), `seaside_rock` (Saltfell) and `rock_surface` (Reach pavement) are featureless at 1K. Those layers stay on the existing sets, re-tinted. `flower_scattered_gravel` and `Ice004` were not fetched (the Melt and the ice are not in my columns).

**Light, against the BIOMES.md rules**

- THAW sun: 2.0 to 2.1 in data, 1.60 to 1.68 after `render/balance`. RIME: 1.5 in data, 1.38 after balance (Tarnhall 1.1, overcast).
- No frame over 1% black or white in the fourteen after shots. Worst: Tarnhall THAW 0.7% (it was 7.6% before), Coldwell THAW 0.7%. Tarnhall and Thornwold needed their palettes lifted as well as their ambient: the literal BIOMES.md hexes are much darker than what the generators used.
- **Not measured:** the grey-card sun-to-shade ratio at each hearth. I raised ambient and fill, and did not lower any sun below the range.
- Fog distance is the same in both states only where the generators already had it so; I changed fog colour, and density in a few RIME blocks. Check against STYLE.md if that rule is strict.
- The sky is not mine, so every THAW sky is still the same rose haze. That is now the biggest thing the regions share.

**Perf.** No new meshes or draw calls: uniforms, textures and particle counts only. 21 sets at 1K, 25 MB on disk; a region loads only its own two to four sets (roughly 4 MB of VRAM per set compressed with mips, so up to 16 MB), and the shared 2K sets it replaces are no longer bound there. Largest particle count added: Tarnhall RIME, 520 flakes. Not measured on a GPU.

**Shots.** `docs/screens/biome_before_<area>_<state>.png` and `biome_after_...`, one framing per region, HUD off. `docs/screens/biome_sheet_thaw.png` and `_rime.png`: top row before, bottom row after, regions in route order. The RIME after shots predate the last small change (RIME sun 1.55 to 1.5).

**Tests (local, lavapipe).** All exit 0 on the final data: `smoke`, `houses`, `traps`, the seven area suites (`steading`, `lowe`, `kettle`, `tarnhall`, `thornwold`, `reach`, `coldwell`) and the seven encounter suites (`tarnhall_encounters` included, no flake this run). `tools/audit_edges.py` and `tools/audit_areas.py` clean in every area and both states. `check_originality.sh --all` OK. Not run: `fullslice`, `fullgame_*`, and the suites this work does not touch.

**Not done**

- Ground-cover tint per region (only distribution is in).
- Ground was not widened and no landform touched, as told.
- Kettle and Saltfell THAW still look closest to their "before"; they need the plants and props from the other branches to separate further.

## 2026-11-11 (8): clean stopping point, ready to merge

**Branch `art/world-fidelity`, head: the commit that adds this entry (on top of `844c9ad`, which merges `main` at `103a252` with no conflicts).** I still cannot message you (trusted-device refusal), so this is the report you asked for.

**Nothing is half-built.** Every piece is live and complete; nothing needed gating or reverting. One switch is deliberately off: `render/exposure/auto` (auto-exposure), untested on hardware.

**What changed**

| Area | Change |
|---|---|
| Buildings | Real construction detail inside 70 m (`HouseDetail`, `MeshBuf`); barrow facades and kerbs; barrow mounds collide as the visible mound; plain slabs past 70 m. Collision and the `houses` API unchanged. |
| Interiors | Trusses, benches, kerbed hearths, hung goods; one `HouseProbe` per house (warm THAW, cold RIME ambient). |
| Ground at buildings | Footprints in the terrain shader: contact shadow, bare earth, drip line, worn doorways, no snow under roofs; RIME drifts as geometry. |
| Exposure | THAW scatters and blooms less, shade lifted; Kettle toned down in `gen_kettle.py`; tier 2 eases SSAO and starts bloom later. |
| Cliffs | Uneven beds, ledges, joints, macro normal in `terrain.gdshader`. |
| Snow | Drift shading, wind ripple, sparkle. |
| Horizon | Horizon mesh and ground past 120 m break up into patches and outcrops. |
| Owner's report | Trap audit + `TrapWarden` (five regions), Netmender welded, boss LODs off, dissolve double-sided, `HouseYard` props, `Wayside` groups. |

**Verified on the merged state (local, lavapipe):** smoke, houses, traps, steading, lowe, kettle, tarnhall, thornwold, reach, coldwell, boss, encounters, and the lowe, kettle, thornwold, reach and coldwell encounter suites: 0 failures. Edge and placement audits clean. Originality OK.

- **`tarnhall_encounters`: 1 failure, "two benches".** The same timing flake as before (it failed 2 of 4 runs on untouched base, and passed here earlier today). Not from this branch.
- **CI:** at `3ca9229` only `deltas` (`saves carry save_version 3`) and `fullgame_lowe` (`lowe_barrows cleared, its memory as it was left`) failed, the same two checks that were failing on `main` then. The run at `2b18dcd` failed all five jobs in 3 seconds with no logs: the suites never started. Runs for `0480423` and `57eed4b` were still going when I looked.
- **Not run here:** `fullslice`, `fullgame_*`, `endings`, `deltas`, `anim` on the final merged state.

**Perf impact** (lavapipe frame counters, tier 1, first pass only): 0 % to +22 % draw calls and +3 % to +35 % triangles per frame at the 25 cameras; a house is 19k to 74k triangles (was 5k to 13k) and five plain meshes past 70 m. Area build +0.2 to +0.8 s. The terrain shader grew (footprint loop near houses, cliff relief, snow, far breakup) and yard and wayside props add colliding pieces; **neither has been measured on a GPU.**

**What is left**

1. A real-GPU re-shoot of this branch (questions listed in entry 5).
2. Kettle's spire silhouettes and straight horizon edges (heightfield and far-grid work).
3. Kettle, Thornwold and Tarnhall got almost no wayside groups; they need hand-authored ones. New distinct props need Tripo.
4. Other clip-through spots: only the barrow mounds were found. The owner has not said where else.
5. Boss gaps were checked in a still only.
6. Door leaves and benches do not collide (entry 2, item 3).

## 2026-11-10 (7): the owner's report, directly to this session

The owner wrote to me: terrain you can clip through, ditches you cannot get out of, bosses with gaps in their models, and areas that want more props and points of interest. This crosses lanes (boss assets, terrain tools, area_builder, test tools); I took it because the owner asked.

- **Traps:** new audit check, `tools/fix_traps.py`, `data/terrain/traps/*.json`, `src/world/trap_warden.gd`, suite `traps`. Five regions found and guarded.
- **Barrow mounds** collide as the visible mound.
- **Bosses:** Netmender welded and double-sided, `generate_lods=false` on all seven, dissolve shader double-sided.
- **Yards:** `src/world/house_yard.gd` places colliding kit props round houses.
- **Wayside:** `src/world/wayside.gd` places cairns, stone rows, sledges and racks off the road (Saltfell 10, Lowe 6, Reach 6, Coldwell 9, Tarnhall 1, Kettle 0).
- **Not done:** Kettle, Tarnhall and Thornwold want hand-authored groups in their generators; new distinct props need Tripo (yours).

Details in `docs/art/WORLD_FIDELITY.md`, "Third pass". Suites green here: smoke, houses, traps, steading, tarnhall, encounters, tarnhall_encounters, lowe, lowe_encounters, reach, coldwell, kettle, boss, anim; both audits clean.

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
