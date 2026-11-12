# Collision audit

The owner's Windows playtest reported that "several props and terrain lack collision". This is the automated answer: a headless suite that builds every area and compares what is **drawn** with what is **solid**, a baseline of the offenders it found, and the fixes made so far.

- Suite: `tools/test/collision_audit_test.gd` (`--test=collision_audit`)
- Settings and allow-list: `data/collision_audit.json`
- Known offenders (the gate): `tools/test/fixtures/collision_baseline.json`
- Tables below: `tools/qa/collision_report.py`

## How to run it

```
tools/audit_collision.sh                          # all seven areas, about 5 minutes
tools/audit_collision.sh --areas=tarnhall         # one area (or a,b)
tools/audit_collision.sh --collision-out=/abs/out.json   # every offender as JSON
python3 tools/qa/collision_report.py /abs/out.json       # the tables in this file
tools/audit_collision.sh --update-baseline        # accept today's offenders as known
tools/test.sh collision_audit                     # as a suite (15 minute limit)
```

The suite passes when no offender falls outside both the allow-list and the baseline. Every run prints the baseline (grouped, with owners), any baseline entry that is no longer found (drop it), and every new offender. Update the baseline only after a new offender has been routed to its owner.

Two full runs give the same 189 offenders (the second run reported 0 new). The full pass takes **285 to 290 s** on this box (4 slow cores): Saltfell 88 s, the Lowe 45 s, Kettle 14 s, Tarnhall 22 s, Thornwold 69 s, the Reach 33 s, Coldwell 14 s. Almost all of it is building the areas and baking their navmeshes; the checks themselves take 1 to 5 s per pass.

## What it builds

For each area in `data/areas/index.json`:

| build | world flags | states audited |
|---|---|---|
| default | none | THAW, RIME |
| released | every `require_flag` / `absent_flag` the area's JSON names (its Holdfast's release flag), plus `lowe_bridge_down` for Saltfell and the Lowe | THAW, RIME |
| spring | the above plus `ending_outsong` (only where the JSON names it: Saltfell) | THAW |

Coldwell names no flag, so it has the default build only. That is 27 passes.

## How it works

1. **The playable footprint.** The state's navmesh, cut down to the parts joined to somewhere the game puts the Bearer (start, hearths, portals and arrivals, souls, finds, foes), rasterised to a 1 m grid of walkable heights. Everything below is tested only within about a metre of it.
2. **A physics copy of what is drawn.** Every visible `MeshInstance3D` and every readable `MultiMesh` instance gets a trimesh on a spare physics layer, so "is anything drawn here" is a physics query. Water and falls go on a second layer (drawn, but never a floor mesh).
3. **Drawn but not solid** (`walk_through`, `partial`). Points are spread over each mesh's surface (0.3 m apart, at most 1500 per mesh). Those 0.4 to 1.5 m above the walkable height beside them, and not bedded in the ground, are tested: is a collider within 0.3 m? A first pass tests 64 of them evenly; every sample within 1.5 m of a bare one is then tested too. The largest patch of bare samples that hang together is the finding, if it stands at least 0.6 m out of the floor under it (measured by a ray), is at least 0.5 m wide and at least 0.3 m in its second dimension (so poles, rails and ropes drop out). `walk_through`: no sample is covered and nothing solid is inside the mesh at all. `partial`: some of it is solid, but a bare patch of 8 or more samples remains.
4. **Solid but not drawn** (`invisible`). For every box, sphere, cylinder and capsule collider on the state's layers: lattice points through the shape at body height beside walkable ground; a point is bare if nothing drawn is within 0.45 m and it is not under the ground. Reported when at least 3 points and half of those tested are bare, over at least 0.5 m.
5. **Terrain and floors.**
   - `terrain_collider` (direct): the heightfield collider against the heights the mesh is drawn from, every third cell of the whole grid (4,000 to 9,000 rays per area, 5 cm tolerance).
   - Columns: every 1 m over the footprint and two cells past its edge, four per cell along the edge. `void`: no collider at all below. `floating`: the collision floor is more than 0.3 m above anything drawn. `unbacked_floor`: a wide drawn floor more than 0.3 m above the floor that carries, with no collider of its own.
   - `terrain_edge`: walkable ground within 3 m of the heightfield's edge that can be reached **without** walking through a seam (an auto portal's box carries the Bearer to the neighbour first).
   - `seam`: this area's ground against the neighbour's along each crossing (39 samples per crossing).
   - `spawn`: start, portals and arrivals have a floor within 1.2 m of their authored height, and the capsule fits.
   - `threshold`: through every house door, 1.6 m either side: a step the Bearer cannot climb (`move/step_height` 0.35 m plus 0.05 m slack), a missing floor, or the capsule blocked. Decks, jetties and bridges (the wide thin timber boxes): the same at both ends.
6. **Self-test.** Three planted defects by the start of the first area (a box with no collider, a collider with no mesh, boards drawn 0.7 m over the ground) must each be found, every run.

### Thresholds (`data/collision_audit.json`)

| key | value | meaning |
|---|---:|---|
| `min_height` | 0.6 m | the bare part must stand this far out of the floor |
| `min_width` / `min_second` | 0.5 / 0.3 m | its width, and its second-largest dimension |
| `band_min` .. `band_max` | 0.4 .. 1.5 m | body height above the walkable level |
| `cover_radius` | 0.3 m | a collider this near a drawn point covers it |
| `partial_min` | 8 samples | the smallest bare patch reported on a partly solid mesh |
| `drawn_radius` | 0.45 m | something drawn this near a collider point covers it |
| `surface_tol` | 0.3 m | drawn floor against collision floor |
| `terrain_tol` | 0.05 m | heightfield collider against the drawn mesh |
| `step_slack`, `gap_min`, `spawn_tol` | 0.05, 0.3, 1.2 m | thresholds, deck gaps, spawn height |
| `floor_min_extent` | 2.5 m | a mesh this wide both ways can be a floor |

### The allow-list

Kept in `data/collision_audit.json`, one line of reason each: ground cover (`Veg_*`), roof grass, water and falls sheets, the overhead `beam_4m`, god rays, flames, RIME snow drifts against house walls, trees' boughs (the trunk must still be solid), frost-veil seals, veils and barred gates standing in doorways, and the two drawbridge-end spawn points while the bridge is up. `rime_spike` (in the builder's `PASSABLE_PROPS`) is **not** on it; none was reported. Nothing was added to make the audit pass.

## Terrain: what was found

| finding | where | what was done |
|---|---|---|
| Heightfield collider against the drawn terrain | all seven areas, 41,249 samples | **No mismatch** (worst 0.00 m). The collider and the mesh split each cell along the same diagonal. `Terrain.height_at` is bilinear and differs from both by up to 1.8 m on a twisted cell (a cliff), so the audit uses the mesh's own triangles. |
| Holes in the footprint (`void`) | all areas, both states | **None.** |
| Seams to neighbours | all 14 crossing checks (7 crossings, from both sides) | **Agree** (worst 0.15 m, Saltfell to the Lowe at the pass). |
| Reaching the heightfield's edge | Kettle, Tarnhall, Thornwold, the Reach, Coldwell | Walkable ground does run to the edge in each (for example Tarnhall's fjord-head ice at x 24 to 27, z -337 to -300 in RIME, and 25 x 31 m at 677, -396 in Coldwell), but only past a seam box, which carries the Bearer on first. **Not reachable without crossing a seam**, so not reported. This rests on a 1 m flood fill, not on a played walk. |
| `floating`: the Reach's frozen beck | all along the beck, x 558 to 704, RIME (for example 11 x 1.8 m at 585, 65, -335 and 12 x 2.5 m at 610, 67, -331), up to 1.56 m | **Fixed.** `tools/gen_reach.py` drew the ice a metre narrower each side than the floor that carries, so the Bearer walked on air over the bank. The sheet is now drawn as wide as its collider; regenerated with `--keep-terrain` (no terrain data changed). |
| A ditch between the beck ice and its bank | the Reach, RIME, at 625.7, 68.8, -334.6 (and wherever the beck bends) | **Fixed.** Not found by the audit: found when the Reach suite's walker fell into it after the scatter fix moved its route. The ice was laid in 4 m lengths on each length's first z and stopped 0.5 m short of the cut's rim, so on a bend its edge stood up to 0.8 m inside the cut with a metre-deep ditch behind it; the navmesh crossed there (it climbs 0.4 m on a 0.2 m grid) and the Bearer (0.35 m) could not follow. `tools/gen_reach.py` now lays the ice in 2 m lengths centred on the beck, past the rim, with the top taken from the land itself. `--keep-terrain`; no terrain data changed. |
| `floating`: boulder and floe tops | Lowe 30, 47, -210; Coldwell 737, 89, -396; Tarnhall 219, 24, -296; Saltfell 14, 23, -62 and others | **Fixed** with the scatter colliders (below): these were the tops of sphere colliders standing beside their stones. |
| `floating`: a ledge 1 x 0.5 m | Saltfell -22, 22.5, -29 | Not fixed: the box `Wayside._landmark` fits to a wayside landmark overhangs what is drawn. In the baseline for the look-pass agent. |
| `threshold`: the two well-houses | Coldwell, `wellhouse_0` at 900, -495 and `wellhouse_1` at 900, -461 | **Not fixed, needs a decision.** `gen_coldwell.py` places them "on the level", but they stand on the corrie wall: the ground runs from 17 m below to 12 m above the house floor across each footprint, and both doors open into the slope. Moving them or cutting two 6 x 8 m pads into a 45 degree wall changes the place; that is the lead's call. |
| `threshold`: a 0.82 m step at both ends of `box#8` | Tarnhall 185, 25, -334 and 210, 25, -334 | Not fixed: a 25 x 1.4 m timber box 0.8 m above the hall floor (a side bench by its shape). Either it is not meant to be walked on, or it needs a step. |
| Jetty ends 0.35 to 0.38 m above the shore | Kettle boxes 0, 22, 41, 71 | Under the 0.40 m threshold, so not reported; the Kettle suite walks them. Noted because they sit on the limit. |
| Arrival 1.04 m above the ground | the Lowe, arriving from Saltfell at -89, 24, -89.5 | By design (`tools/seams_lowe.py` adds 0.9 m); under the 1.2 m threshold. |

So the heightfield itself has no holes. What a player would call terrain without collision was the scatter: boulders, slabs and "cliff chunks" drawn as terrain-sized rock with no collider, or with a sphere somewhere else.

## Builder fixes made

1. **Scatter colliders are the hull of what is drawn** (`src/world/scatter.gd`). The old shapes were sized for the primitive stand-ins. With the hero meshes: a "small" rock (scale under 1.2) stood up to 1.6 m tall with no collider; driftwood snags 3 to 4 m across were walked through (23 in Saltfell, 18 in Kettle); a boulder's sphere was smaller than its stone or beside it (bare patches up to 3.9 x 3.6 m, and invisible spheres up to 6.6 m across beside them). Rocks, boulders, driftwood, peat stacks, standing stones and upright ice floes now get the exact convex hull of their own mesh at their own scale, drawn in 0.2 m a side, when the piece stands 0.55 m or more out of the land under it and is 0.5 m wide. (Hard against the mesh, two placed boulders closed the drove-road's notch at Tarnhall's tarn, 253, -326; the inset keeps the ways the generators left.) This changes where the navmesh runs in every area: routes that went through a stone's flank now go round it. Fences keep their boxes. Flat ice floes and hummocks still get none.
2. **Plaques are solid** (`src/world/plaque.gd`): the 1.4 m carved stones were walked through in every area.
3. **The raised drawbridge is solid** (`src/world/drawbridge.gd`): raised, its collider was off, so the Bearer walked through the standing planks and off the ravine lip at -8, 23, -82.5 in the Lowe.
4. **MultiMesh transforms are kept on the node** (`scatter.gd`, `forest.gd`, meta `instance_xfs`): the headless rendering server keeps no instance buffer, so `get_instance_transform` answers identity and no headless test could see where a scattered rock or a tree stands.
5. **The Reach's beck ice** (`tools/gen_reach.py`), above.

## What the audit cannot see

- **Only near the navmesh.** Things more than about a metre from walkable ground joined to the start are not tested. The Bearer is not bound to the navmesh: ground it rejects (steeper than 44 degrees, narrower than the 0.6 m agent) is not sampled.
- **Reach is a 1 m grid.** Heights come from navmesh polygons; the final height test is a ray, but which samples are tried depends on the grid.
- **Sampled, not exhaustive.** A bare patch smaller than 8 samples (about 0.7 m2) on a partly solid mesh is not reported, and meshes over 135 m2 are sampled coarser than 0.3 m. A missing wall bay would be found; a missing plank would not.
- **`partial` on big composite meshes names the mesh, not the part.** A house's `staves` or `frame` finding gives the position of the bare patch; someone still has to look at what stands there.
- **MultiMeshes without `instance_xfs`** cannot be read headless: ground cover and roof grass (allow-listed), and the Hedgelayer's `ThornWall` (255 instances, raised in the fight, listed each run).
- **Convex hull and trimesh colliders are assumed to match their mesh** in the reverse check; only primitive shapes are tested for being invisible.
- **Deck sides are not tested**, only both ends. Stairs and ramps have no check of their own: a wrong one shows only as `floating`, `unbacked_floor` or a hole in the footprint.
- **Foes, souls and anything spawned at run time** are skipped (a `CharacterBody3D` brings its own body).
- **Steps inside the footprint.** The navmesh climbs 0.4 m and the Bearer 0.35 m. Only doors and deck ends are profiled for steps; a ledge or a ditch in open ground that the navmesh bridges (the beck ice above) is not found.
- **Nothing here plays the game.** A collider that exists but is too thin to stop a sprinting capsule, a camera clipping through a wall, or a difference between this build and the Windows export would not show. The seam and edge findings rest on a flood fill, not a walk.
- **It has not been run on a GPU build.** Meshes hidden or shown by visibility range are taken as drawn; far LODs are skipped as copies of the near one.

## Suites after the fixes

Run headless on this branch, after the last fix:

| suite | result |
|---|---|
| `collision_audit` | 45 checks, 0 failures (189 known, 0 new), twice |
| `python3 tools/audit_edges.py` | exit 0 |
| `python3 tools/audit_areas.py` | exit 0, every area clean |
| `smoke` | 11 checks, 0 failures |
| `steading` | 47 checks, 0 failures |
| `lowe` | 25 checks, 0 failures |
| `kettle` | 34 checks, 0 failures |
| `tarnhall` | 37 checks, 0 failures |
| `thornwold` | 26 checks, 0 failures |
| `reach` | 28 checks, 0 failures (4 runs) |
| `coldwell` | 31 checks, 0 failures |
| `houses` | 61 checks, 0 failures |
| `encounters`, `lowe_encounters`, `kettle_encounters`, `tarnhall_encounters`, `thornwold_encounters`, `reach_encounters`, `coldwell_encounters` | 66, 98, 84, 110, 78, 94, 82 checks, 0 failures |

Not run here: `fullslice` and the `fullgame_*` walks. They are the ones most likely to notice the scatter fix, because their routes now go round stones they used to pass through. On the way to green, the hull fix failed two suites and both were fixed at the cause: Tarnhall's drove-road notch (the 0.2 m inset) and the Reach's beck ditch (the generator).

## Results (this commit)

189 known offenders: 82 walk-through, 25 partly solid, 75 invisible colliders, 6 thresholds, 1 floating ledge. By owner: 152 the lead's look-pass agent, 21 the lead's endings agent, 12 the World-fidelity env, 4 the two Coldwell well-houses (lead's call). None is QA's: every terrain and floor finding that was QA's to fix is fixed.

The 75 invisible colliders are small: 49 are Thornwold hedge segments whose box stands 0.45 m or more clear of the drawn hedge at half its body-height points, 16 are the hearthstone's capsule (it stands in the fire, inside a kerb that is itself not solid), the rest are landmark boxes wider than their landmark.

### Counts per area and pass

| area | pass | walk_through | partial | invisible | floating | unbacked_floor | void | terrain_collider | terrain_edge | seam | spawn | threshold |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| coldwell | rime | 18 | 5 | 1 |  |  |  |  |  |  |  | 4 |
| coldwell | thaw |  | 3 | 1 |  |  |  |  |  |  |  | 4 |
| kettle_fjord | rime | 5 | 1 | 2 |  |  |  |  |  |  |  |  |
| kettle_fjord | rime+released | 5 | 1 | 2 |  |  |  |  |  |  |  |  |
| kettle_fjord | thaw | 5 | 1 | 2 |  |  |  |  |  |  |  |  |
| kettle_fjord | thaw+released | 5 | 1 | 2 |  |  |  |  |  |  |  |  |
| lowe_barrows | rime |  | 11 | 1 |  |  |  |  |  |  |  |  |
| lowe_barrows | rime+released |  | 11 | 2 |  |  |  |  |  |  |  |  |
| lowe_barrows | thaw |  | 7 | 1 |  |  |  |  |  |  |  |  |
| lowe_barrows | thaw+released |  | 7 | 2 |  |  |  |  |  |  |  |  |
| saltfell_steading | rime | 1 |  | 4 | 1 |  |  |  |  |  |  |  |
| saltfell_steading | rime+released | 1 |  | 5 | 1 |  |  |  |  |  |  |  |
| saltfell_steading | thaw | 1 |  | 4 | 1 |  |  |  |  |  |  |  |
| saltfell_steading | thaw+released | 1 |  | 5 | 1 |  |  |  |  |  |  |  |
| saltfell_steading | thaw+spring | 1 |  | 5 | 1 |  |  |  |  |  |  |  |
| shepherds_reach | rime |  |  | 4 |  |  |  |  |  |  |  |  |
| shepherds_reach | rime+released |  |  | 5 |  |  |  |  |  |  |  |  |
| shepherds_reach | thaw | 54 |  | 5 |  |  |  |  |  |  |  |  |
| shepherds_reach | thaw+released | 54 |  | 5 |  |  |  |  |  |  |  |  |
| tarnhall | rime | 2 | 2 | 3 |  |  |  |  |  |  |  | 2 |
| tarnhall | rime+released | 2 | 2 | 4 |  |  |  |  |  |  |  | 2 |
| tarnhall | thaw | 2 | 4 | 3 |  |  |  |  |  |  |  | 2 |
| tarnhall | thaw+released | 2 | 4 | 4 |  |  |  |  |  |  |  | 2 |
| thornwold | rime | 2 | 2 | 54 |  |  |  |  |  |  |  |  |
| thornwold | rime+released | 2 | 2 | 55 |  |  |  |  |  |  |  |  |
| thornwold | thaw |  | 2 | 53 |  |  |  |  |  |  |  |  |
| thornwold | thaw+released |  | 2 | 54 |  |  |  |  |  |  |  |  |

### Offenders (grouped: one row per area, kind and thing)

| area | kind | what | n | passes | largest (m) | where (x, y, z) | probable fix | owner |
|---|---|---|---:|---|---|---|---|---|
| saltfell_steading | floating | `node:StaticBody3D` | 1 | rime, rime+released, thaw, thaw+released, thaw+spring | 0.5 x 0.0 x 0.0 | -22, 22, -29 | Wayside._landmark: the fitted box (0.8 of the mesh's AABB) overhangs the drawn landmark, so its top is a ledge with nothing under it: fit a hull, or shrink the box | Lead's look-pass agent |
| saltfell_steading | invisible | `node:StaticBody3D` | 2 | rime, rime+released, thaw, thaw+released, thaw+spring | 2.3 x 2.2 x 2.3 | -12, 23, -14; -90, 23, 10 | the box collider is wider than what is drawn (Forest._hedge: seg + 0.2 by h + 0.4 by max(w, 0.8); Wayside._landmark: 0.8 of the mesh's AABB) | Lead's look-pass agent |
| saltfell_steading | invisible | `kit:hearthstone` | 3 | rime, rime+released, thaw, thaw+released, thaw+spring | 1.0 x 0.9 x 1.0 | -26, 23, 23; 23, 4, 56; 0, 23, -26 | src/world/hearthstone.gd: the 0.38 m capsule stands in the middle of the fire, where nothing is drawn; see the partial entry | Lead's look-pass agent |
| saltfell_steading | walk_through | `house:boatshed/turf_edge` | 1 | rime, rime+released, thaw, thaw+released, thaw+spring | 13.8 x 6.2 x 13.5 | 18, 7, 48 | src/world/house_detail.gd / building_gen.gd: a collider for the part, or keep it inside the wall's | World-fidelity env |
| lowe_barrows | invisible | `node:StaticBody3D` | 1 | rime, rime+released, thaw, thaw+released | 2.9 x 2.6 x 2.9 | -61, 28, -105 | the box collider is wider than what is drawn (Forest._hedge: seg + 0.2 by h + 0.4 by max(w, 0.8); Wayside._landmark: 0.8 of the mesh's AABB) | Lead's look-pass agent |
| lowe_barrows | invisible | `kit:hearthstone` | 1 | rime+released, thaw+released | 1.0 x 0.9 x 1.0 | 40, 47, -204 | src/world/hearthstone.gd: the 0.38 m capsule stands in the middle of the fire, where nothing is drawn; see the partial entry | Lead's look-pass agent |
| lowe_barrows | partial | `house:kin_c/M_drystone` | 1 | rime, rime+released, thaw, thaw+released | 17.5 x 2.7 x 20.1 | -4, 38, -145 | src/world/house_detail.gd / building_gen.gd: a collider for the part, or keep it inside the wall's | World-fidelity env |
| lowe_barrows | partial | `house:kin_a/M_drystone` | 1 | rime, rime+released, thaw, thaw+released | 15.9 x 2.7 x 18.5 | -64, 33, -120 | src/world/house_detail.gd / building_gen.gd: a collider for the part, or keep it inside the wall's | World-fidelity env |
| lowe_barrows | partial | `house:kin_d/M_drystone` | 1 | rime, rime+released, thaw, thaw+released | 16.2 x 2.8 x 16.9 | 16, 33, -133 | src/world/house_detail.gd / building_gen.gd: a collider for the part, or keep it inside the wall's | World-fidelity env |
| lowe_barrows | partial | `house:twin/M_drystone` | 1 | rime, rime+released, thaw, thaw+released | 13.8 x 2.8 x 17.7 | 40, 48, -216 | src/world/house_detail.gd / building_gen.gd: a collider for the part, or keep it inside the wall's | World-fidelity env |
| lowe_barrows | partial | `scene:lm_barrow_door.glb` | 4 | rime, rime+released, thaw, thaw+released | 6.7 x 3.7 x 5.8 | 46, 49, -212; 18, 33, -138; -58, 33, -120; -27, 30, -119 | a landmark placed without "blocker" (or with one smaller than the mesh): add or widen it in the generator | Lead's look-pass agent |
| lowe_barrows | partial | `scene:lm_veil_rime.glb` | 1 | rime, rime+released | 5.2 x 5.5 x 1.8 | 48, 46, -177 | src/world/frost_veil.gd: the veil's dressing is wider than its seal; once the veil is cleared it is walked through | Lead's look-pass agent |
| lowe_barrows | partial | `kit:hearthstone` | 2 | rime, rime+released, thaw, thaw+released | 2.2 x 1.2 x 2.2 | -82, 26, -103; 32, 41, -165 | src/world/hearthstone.gd: the kerb is 2.2 m across and the collider a 0.38 m capsule in its middle: fit the collider to the kerb | Lead's look-pass agent |
| kettle_fjord | invisible | `kit:hearthstone` | 2 | rime, rime+released, thaw, thaw+released | 1.0 x 0.9 x 1.0 | -58, 3, -313; -104, 3, -303 | src/world/hearthstone.gd: the 0.38 m capsule stands in the middle of the fire, where nothing is drawn; see the partial entry | Lead's look-pass agent |
| kettle_fjord | partial | `house:fishhouse_0/staves` | 1 | rime, rime+released, thaw, thaw+released | 9.6 x 8.1 x 9.8 | -49, 4, -321 | src/world/house_detail.gd / building_gen.gd: a collider for the part, or keep it inside the wall's | World-fidelity env |
| kettle_fjord | walk_through | `kit:drying_rack` | 2 | rime, rime+released, thaw, thaw+released | 4.1 x 2.6 x 2.0 | 12, 3, -293; -117, 3, -298 | the generator places it with "collide": false: drop that (AreaBuilder then gives it a convex hull) | Lead's look-pass agent |
| kettle_fjord | walk_through | `kit:net_frame` | 3 | rime, rime+released, thaw, thaw+released | 3.5 x 2.6 x 0.7 | -124, 3, -295; -1, 3, -297; 25, 3, -292 | the generator places it with "collide": false: drop that (AreaBuilder then gives it a convex hull) | Lead's look-pass agent |
| tarnhall | invisible | `kit:hearthstone` | 4 | rime, rime+released, thaw, thaw+released | 1.0 x 0.9 x 1.0 | 124, 25, -331; 82, 15, -316; 197, 25, -327; 220, 25, -322 | src/world/hearthstone.gd: the 0.38 m capsule stands in the middle of the fire, where nothing is drawn; see the partial entry | Lead's look-pass agent |
| tarnhall | partial | `house:byres/staves` | 1 | thaw, thaw+released | 15.8 x 7.4 x 11.9 | 217, 26, -329 | src/world/house_detail.gd / building_gen.gd: a collider for the part, or keep it inside the wall's | World-fidelity env |
| tarnhall | partial | `kit:hearthstone` | 1 | rime, rime+released, thaw, thaw+released | 2.0 x 1.2 x 2.0 | 82, 15, -316 | src/world/hearthstone.gd: the kerb is 2.2 m across and the collider a 0.38 m capsule in its middle: fit the collider to the kerb | Lead's look-pass agent |
| tarnhall | partial | `scene:lm_hall_doors.glb` | 1 | rime, rime+released | 0.6 x 2.4 x 2.0 | 179, 26, -329 | ShortcutGate: the barred doors' collider is thinner than the drawn pair | World-fidelity env |
| tarnhall | partial | `kit:door_leaf` | 2 | thaw, thaw+released | 0.9 x 2.5 x 0.1 | 179, 26, -330; 179, 26, -328 | gen_tarnhall.py: the open leaf is "collide": false | World-fidelity env |
| tarnhall | threshold | `box#8(M_wood) end` | 2 | rime, rime+released, thaw, thaw+released | 25.0 x 0.1 x 1.4 | 185, 25, -334; 210, 25, -334 | generator: a step or a ramp at the deck's end, or drop the collider if it is not meant to be walked | World-fidelity env |
| tarnhall | walk_through | `scene:lm_high_seat.glb` | 1 | rime, rime+released, thaw, thaw+released | 1.3 x 2.5 x 1.3 | 214, 25, -334 | a landmark placed without "blocker" (or with one smaller than the mesh): add or widen it in the generator | Lead's look-pass agent |
| tarnhall | walk_through | `scene:lm_guest_post.glb` | 1 | rime, rime+released, thaw, thaw+released | 1.0 x 3.0 x 1.0 | 181, 26, -327 | a landmark placed without "blocker" (or with one smaller than the mesh): add or widen it in the generator | Lead's look-pass agent |
| thornwold | invisible | `landmark_blocker:lm_charcoal_clamp.glb` | 3 | rime, rime+released, thaw, thaw+released | 5.1 x 2.2 x 5.1 | 349, 36, -316; 336, 36, -309; 343, 36, -297 | generator: the landmark's "blocker" box is wider than what is drawn | Lead's look-pass agent |
| thornwold | invisible | `node:StaticBody3D` | 49 | rime, rime+released, thaw, thaw+released | 2.2 x 3.0 x 2.8 | 321, 36, -280; 304, 37, -369; 304, 36, -360; 304, 37, -366; 482, 38, -361; 482, 38, -360 ... | the box collider is wider than what is drawn (Forest._hedge: seg + 0.2 by h + 0.4 by max(w, 0.8); Wayside._landmark: 0.8 of the mesh's AABB) | Lead's look-pass agent |
| thornwold | invisible | `kit:hearthstone` | 3 | rime, rime+released, thaw, thaw+released | 1.1 x 0.9 x 1.1 | 340, 35, -303; 462, 39, -297; 450, 39, -322 | src/world/hearthstone.gd: the 0.38 m capsule stands in the middle of the fire, where nothing is drawn; see the partial entry | Lead's look-pass agent |
| thornwold | partial | `mm:Forest_hedge_hd_laid2_base` | 2 | rime, rime+released, thaw, thaw+released | 1.9 x 1.8 x 2.0 | 303, 35, -314; 483, 40, -337 | src/world/forest.gd _hedge: a hedge section stands outside its segment's box collider (the ends of a run, upper courses) | Lead's look-pass agent |
| thornwold | walk_through | `scene:rime_stag.glb` | 2 | rime, rime+released | 6.0 x 5.9 x 5.0 | 373, 38, -293; 419, 38, -349 | a landmark placed without "blocker" (or with one smaller than the mesh): add or widen it in the generator | Lead's look-pass agent |
| shepherds_reach | invisible | `landmark_blocker:lm_sheiling.glb` | 2 | rime, rime+released, thaw, thaw+released | 7.8 x 4.6 x 7.9 | 586, 67, -283; 600, 69, -295 | generator: the landmark's "blocker" box is wider than what is drawn | Lead's look-pass agent |
| shepherds_reach | invisible | `node:StaticBody3D` | 2 | rime, rime+released, thaw, thaw+released | 2.8 x 2.6 x 2.8 | 606, 69, -285; 639, 72, -344 | the box collider is wider than what is drawn (Forest._hedge: seg + 0.2 by h + 0.4 by max(w, 0.8); Wayside._landmark: 0.8 of the mesh's AABB) | Lead's look-pass agent |
| shepherds_reach | invisible | `kit:hearthstone` | 2 | rime, rime+released, thaw, thaw+released | 1.0 x 0.9 x 1.0 | 654, 78, -377; 604, 69, -306 | src/world/hearthstone.gd: the 0.38 m capsule stands in the middle of the fire, where nothing is drawn; see the partial entry | Lead's look-pass agent |
| shepherds_reach | walk_through | `kit:sheep` | 54 | thaw, thaw+released | 1.2 x 1.0 x 1.2 | 598, 68, -305; 603, 68, -316; 676, 74, -306; 612, 69, -310; 678, 75, -338; 609, 67, -385 ... | gen_reach.py sets the living flock "collide": false because FlockWander moves it: give each ewe a body that moves with her | Lead's look-pass agent |
| coldwell | invisible | `kit:hearthstone` | 1 | rime, thaw | 1.1 x 0.9 x 1.1 | 800, 117, -451 | src/world/hearthstone.gd: the 0.38 m capsule stands in the middle of the fire, where nothing is drawn; see the partial entry | Lead's look-pass agent |
| coldwell | partial | `scene:lm_wellhead_thaw.glb` | 1 | thaw | 7.5 x 3.2 x 8.0 | 922, 158, -482 | gen_coldwell.py: the "blocker" is far smaller than the 7.5 m wellhead | Lead's endings agent |
| coldwell | partial | `scene:lm_wellhead.glb` | 1 | rime | 7.5 x 3.2 x 8.0 | 922, 158, -482 | gen_coldwell.py: the "blocker" is far smaller than the 7.5 m wellhead | Lead's endings agent |
| coldwell | partial | `scene:lm_veil_rime.glb` | 1 | rime | 1.8 x 5.5 x 5.2 | 912, 158, -476 | src/world/frost_veil.gd: the veil's dressing is wider than its seal; once the veil is cleared it is walked through | Lead's look-pass agent |
| coldwell | partial | `kit:hearthstone` | 2 | rime, thaw | 2.2 x 1.2 x 2.2 | 800, 116, -450; 724, 87, -399 | src/world/hearthstone.gd: the kerb is 2.2 m across and the collider a 0.38 m capsule in its middle: fit the collider to the kerb | Lead's look-pass agent |
| coldwell | partial | `scene:upwalker.glb` | 1 | rime | 1.4 x 1.9 x 2.0 | 822, 124, -454 | gen_coldwell.py landmark without "blocker": add one (about 0.7 x 1.7 x 0.7) | Lead's endings agent |
| coldwell | threshold | `door W0 of wellhouse_0` | 2 | rime, thaw | 0.0 x 0.0 x 0.0 | 898, 173, -493; 898, 175, -490 | the house stands on a 45-degree corrie wall (ground runs -17 m to +12 m across its footprint): move it to level ground, or cut a pad in tools/terrain_coldwell.py | Lead's endings agent (Coldwell) with the World-fidelity env |
| coldwell | threshold | `door W1 of wellhouse_1` | 2 | rime, thaw | 0.0 x 0.0 x 0.0 | 902, 143, -460; 902, 145, -456 | the house stands on a 45-degree corrie wall (ground runs -17 m to +12 m across its footprint): move it to level ground, or cut a pad in tools/terrain_coldwell.py | Lead's endings agent (Coldwell) with the World-fidelity env |
| coldwell | walk_through | `scene:upwalker.glb` | 8 | rime | 1.7 x 1.9 x 1.8 | 769, 100, -412; 787, 107, -428; 804, 115, -442; 749, 92, -400; 727, 85, -389; 841, 133, -462 ... | gen_coldwell.py landmark without "blocker": add one (about 0.7 x 1.7 x 0.7) | Lead's endings agent |
| coldwell | walk_through | `scene:unsung.glb` | 10 | rime | 1.5 x 1.8 x 1.7 | 778, 104, -420; 795, 111, -435; 759, 96, -406; 814, 120, -450; 832, 129, -459; 715, 82, -385 ... | gen_coldwell.py landmark without "blocker": add one (about 0.7 x 1.7 x 0.7) | Lead's endings agent |

### Every offender

| area | kind | what | x, y, z | size (m) | passes | finding |
|---|---|---|---|---|---|---|
| saltfell_steading | floating | `node:StaticBody3D` | -21.8, 22.5, -29.2 | 0.5 x 0.0 x 0.0 | thaw, rime, thaw+released, rime+released, thaw+spring | 2 samples over 1.0 x 0.5 m; the collision floor is up to 0.85 m above anything drawn |
| saltfell_steading | invisible | `node:StaticBody3D` | -11.6, 23.3, -14.4 | 2.3 x 2.2 x 2.3 | thaw, rime, thaw+released, rime+released, thaw+spring | 20 of 36 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_fold_cairn.glb |
| saltfell_steading | invisible | `node:StaticBody3D` | -89.5, 22.5, 10.3 | 2.9 x 0.8 x 3.0 | thaw, rime, thaw+released, rime+released, thaw+spring | 9 of 16 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_sledge.glb |
| saltfell_steading | invisible | `kit:hearthstone` | -26.0, 23.1, 23.4 | 1.0 x 0.9 x 1.0 | thaw, rime, thaw+released, rime+released, thaw+spring | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| saltfell_steading | invisible | `kit:hearthstone` | 23.0, 4.2, 55.6 | 0.8 x 0.9 x 0.8 | thaw, rime, thaw+released, rime+released, thaw+spring | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| saltfell_steading | invisible | `kit:hearthstone` | 0.0, 22.9, -26.3 | 0.8 x 0.9 x 0.8 | thaw+released, rime+released, thaw+spring | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is box#0(M_wood) |
| saltfell_steading | walk_through | `house:boatshed/turf_edge` | 18.3, 6.9, 47.7 | 13.8 x 6.2 x 13.5 | thaw, rime, thaw+released, rime+released, thaw+spring | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.5 x 0.5 x 1.4 m, standing 2.7 m out of the floor |
| lowe_barrows | invisible | `node:StaticBody3D` | -60.5, 28.4, -104.7 | 2.9 x 2.6 x 2.9 | thaw, rime, thaw+released, rime+released | 33 of 62 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_fold_cairn.glb |
| lowe_barrows | invisible | `kit:hearthstone` | 39.5, 46.6, -203.6 | 1.0 x 0.9 x 1.0 | thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| lowe_barrows | partial | `house:kin_c/M_drystone` | -4.2, 38.0, -145.4 | 17.5 x 2.7 x 20.1 | thaw, rime, thaw+released, rime+released | 34 of 130 body-height samples have no collider within 0.30 m; the largest bare patch is 19 samples, 1.4 x 0.9 x 0.8 m, standing 1.4 m out of the floor |
| lowe_barrows | partial | `house:kin_a/M_drystone` | -63.7, 32.6, -120.0 | 15.9 x 2.7 x 18.5 | thaw, rime, thaw+released, rime+released | 32 of 150 body-height samples have no collider within 0.30 m; the largest bare patch is 16 samples, 1.3 x 1.2 x 0.6 m, standing 1.7 m out of the floor |
| lowe_barrows | partial | `house:kin_d/M_drystone` | 15.6, 33.0, -132.7 | 16.2 x 2.8 x 16.9 | thaw, rime, thaw+released, rime+released | 22 of 127 body-height samples have no collider within 0.30 m; the largest bare patch is 13 samples, 0.7 x 0.5 x 0.8 m, standing 1.1 m out of the floor |
| lowe_barrows | partial | `house:twin/M_drystone` | 39.6, 48.4, -215.6 | 13.8 x 2.8 x 17.7 | thaw, rime, thaw+released, rime+released | 29 of 111 body-height samples have no collider within 0.30 m; the largest bare patch is 15 samples, 1.3 x 0.7 x 0.4 m, standing 1.4 m out of the floor |
| lowe_barrows | partial | `scene:lm_barrow_door.glb` | 46.1, 48.7, -212.1 | 6.7 x 3.7 x 5.8 | thaw, rime, thaw+released, rime+released | 86 of 114 body-height samples have no collider within 0.30 m; the largest bare patch is 83 samples, 6.2 x 1.2 x 2.4 m, standing 1.8 m out of the floor |
| lowe_barrows | partial | `scene:lm_barrow_door.glb` | 17.7, 33.4, -137.5 | 5.3 x 2.2 x 5.2 | rime, rime+released | 150 of 191 body-height samples have no collider within 0.30 m; the largest bare patch is 150 samples, 3.2 x 1.3 x 2.7 m, standing 1.9 m out of the floor |
| lowe_barrows | partial | `scene:lm_barrow_door.glb` | -58.4, 32.9, -119.9 | 5.2 x 2.2 x 4.9 | rime, rime+released | 157 of 208 body-height samples have no collider within 0.30 m; the largest bare patch is 157 samples, 3.4 x 1.4 x 2.9 m, standing 1.9 m out of the floor |
| lowe_barrows | partial | `scene:lm_veil_rime.glb` | 47.8, 46.1, -177.1 | 5.2 x 5.5 x 1.8 | rime, rime+released | 31 of 274 body-height samples have no collider within 0.30 m; the largest bare patch is 21 samples, 1.1 x 1.4 x 1.4 m, standing 1.7 m out of the floor |
| lowe_barrows | partial | `scene:lm_barrow_door.glb` | -26.6, 29.6, -119.1 | 5.0 x 2.2 x 4.7 | rime, rime+released | 155 of 214 body-height samples have no collider within 0.30 m; the largest bare patch is 155 samples, 3.5 x 1.3 x 2.5 m, standing 1.9 m out of the floor |
| lowe_barrows | partial | `kit:hearthstone` | -82.2, 26.0, -103.5 | 2.2 x 1.2 x 2.2 | thaw, rime, thaw+released, rime+released | 27 of 55 body-height samples have no collider within 0.30 m; the largest bare patch is 27 samples, 1.4 x 1.2 x 0.6 m, standing 1.3 m out of the floor |
| lowe_barrows | partial | `kit:hearthstone` | 32.1, 40.7, -165.4 | 2.2 x 1.2 x 2.2 | thaw, rime, thaw+released, rime+released | 13 of 22 body-height samples have no collider within 0.30 m; the largest bare patch is 12 samples, 1.0 x 1.0 x 0.3 m, standing 1.3 m out of the floor |
| kettle_fjord | invisible | `kit:hearthstone` | -58.0, 2.8, -313.3 | 1.0 x 0.9 x 1.0 | thaw, rime, thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| kettle_fjord | invisible | `kit:hearthstone` | -104.0, 2.7, -303.0 | 0.8 x 0.9 x 0.8 | thaw, rime, thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| kettle_fjord | partial | `house:fishhouse_0/staves` | -49.1, 3.6, -321.1 | 9.6 x 8.1 x 9.8 | thaw, rime, thaw+released, rime+released | 17 of 108 body-height samples have no collider within 0.30 m; the largest bare patch is 9 samples, 0.1 x 0.9 x 0.5 m, standing 1.8 m out of the floor |
| kettle_fjord | walk_through | `kit:drying_rack` | 12.3, 3.3, -293.3 | 4.1 x 2.6 x 2.0 | thaw, rime, thaw+released, rime+released | 100 of 100 body-height samples have no collider within 0.30 m; the largest bare patch is 100 samples, 3.4 x 1.5 x 1.2 m, standing 2.2 m out of the floor |
| kettle_fjord | walk_through | `kit:drying_rack` | -117.4, 3.3, -297.5 | 4.0 x 2.6 x 1.8 | thaw, rime, thaw+released, rime+released | 120 of 120 body-height samples have no collider within 0.30 m; the largest bare patch is 120 samples, 3.5 x 1.9 x 1.1 m, standing 2.5 m out of the floor |
| kettle_fjord | walk_through | `kit:net_frame` | -124.0, 3.2, -295.5 | 3.5 x 2.6 x 0.7 | thaw, rime, thaw+released, rime+released | 32 of 32 body-height samples have no collider within 0.30 m; the largest bare patch is 32 samples, 3.3 x 1.2 x 0.4 m, standing 2.0 m out of the floor |
| kettle_fjord | walk_through | `kit:net_frame` | -0.7, 3.1, -296.7 | 3.5 x 2.6 x 0.6 | thaw, rime, thaw+released, rime+released | 36 of 36 body-height samples have no collider within 0.30 m; the largest bare patch is 36 samples, 3.3 x 1.5 x 0.4 m, standing 2.1 m out of the floor |
| kettle_fjord | walk_through | `kit:net_frame` | 25.3, 3.1, -291.9 | 3.5 x 2.6 x 0.5 | thaw, rime, thaw+released, rime+released | 35 of 35 body-height samples have no collider within 0.30 m; the largest bare patch is 35 samples, 3.4 x 1.2 x 0.4 m, standing 1.8 m out of the floor |
| tarnhall | invisible | `kit:hearthstone` | 123.9, 24.6, -331.0 | 1.0 x 0.9 x 1.0 | thaw, rime, thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| tarnhall | invisible | `kit:hearthstone` | 81.9, 15.0, -316.1 | 1.0 x 0.9 x 1.0 | thaw, rime, thaw+released, rime+released | 4 of 8 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| tarnhall | invisible | `kit:hearthstone` | 197.1, 25.2, -327.4 | 0.8 x 0.9 x 0.8 | thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| tarnhall | invisible | `kit:hearthstone` | 219.6, 25.2, -322.1 | 0.8 x 0.9 x 0.8 | thaw, rime, thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| tarnhall | partial | `house:byres/staves` | 216.6, 25.5, -329.1 | 15.8 x 7.4 x 11.9 | thaw, thaw+released | 16 of 104 body-height samples have no collider within 0.30 m; the largest bare patch is 8 samples, 0.1 x 1.0 x 1.0 m, standing 1.7 m out of the floor |
| tarnhall | partial | `kit:hearthstone` | 81.7, 14.5, -315.6 | 2.0 x 1.2 x 2.0 | thaw, rime, thaw+released, rime+released | 18 of 29 body-height samples have no collider within 0.30 m; the largest bare patch is 18 samples, 1.2 x 1.1 x 1.2 m, standing 1.2 m out of the floor |
| tarnhall | partial | `scene:lm_hall_doors.glb` | 179.2, 25.7, -329.1 | 0.6 x 2.4 x 2.0 | rime, rime+released | 427 of 511 body-height samples have no collider within 0.30 m; the largest bare patch is 427 samples, 0.3 x 1.3 x 1.9 m, standing 1.8 m out of the floor |
| tarnhall | partial | `kit:door_leaf` | 179.2, 25.7, -330.4 | 0.9 x 2.5 x 0.1 | thaw, thaw+released | 20 of 34 body-height samples have no collider within 0.30 m; the largest bare patch is 20 samples, 0.5 x 1.2 x 0.1 m, standing 1.8 m out of the floor |
| tarnhall | partial | `kit:door_leaf` | 179.2, 25.7, -327.6 | 0.9 x 2.5 x 0.1 | thaw, thaw+released | 20 of 34 body-height samples have no collider within 0.30 m; the largest bare patch is 20 samples, 0.5 x 1.2 x 0.1 m, standing 1.8 m out of the floor |
| tarnhall | threshold | `box#8(M_wood) end` | 185.0, 25.1, -333.6 | 25.0 x 0.1 x 1.4 | thaw, rime, thaw+released, rime+released | a 0.82 m step between the deck and the ground at its end (the Bearer climbs 0.35) |
| tarnhall | threshold | `box#8(M_wood) end` | 210.0, 25.1, -333.6 | 25.0 x 0.1 x 1.4 | thaw, rime, thaw+released, rime+released | a 0.82 m step between the deck and the ground at its end (the Bearer climbs 0.35) |
| tarnhall | walk_through | `scene:lm_high_seat.glb` | 214.2, 25.4, -333.5 | 1.3 x 2.5 x 1.3 | thaw, rime, thaw+released, rime+released | 65 of 65 body-height samples have no collider within 0.30 m; the largest bare patch is 65 samples, 1.2 x 1.0 x 1.2 m, standing 1.8 m out of the floor |
| tarnhall | walk_through | `scene:lm_guest_post.glb` | 180.9, 25.6, -327.0 | 1.0 x 3.0 x 1.0 | thaw, rime, thaw+released, rime+released | 38 of 38 body-height samples have no collider within 0.30 m; the largest bare patch is 38 samples, 0.7 x 1.2 x 0.7 m, standing 1.9 m out of the floor |
| thornwold | invisible | `landmark_blocker:lm_charcoal_clamp.glb` | 349.4, 36.2, -315.6 | 5.1 x 2.2 x 5.1 | thaw, rime, thaw+released, rime+released | 55 of 108 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is box#2(M_wood) |
| thornwold | invisible | `landmark_blocker:lm_charcoal_clamp.glb` | 336.5, 35.8, -309.1 | 4.6 x 2.2 x 4.6 | thaw, rime, thaw+released, rime+released | 54 of 87 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_charcoal_clamp.glb |
| thornwold | invisible | `landmark_blocker:lm_charcoal_clamp.glb` | 342.7, 36.0, -296.7 | 4.0 x 2.2 x 4.0 | thaw, rime, thaw+released, rime+released | 58 of 76 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_charcoal_clamp.glb |
| thornwold | invisible | `node:StaticBody3D` | 304.4, 36.7, -368.6 | 2.8 x 3.0 x 2.2 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 321.3, 35.8, -280.4 | 2.2 x 3.0 x 2.8 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 304.3, 36.5, -359.7 | 2.6 x 3.0 x 1.7 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 304.3, 36.6, -365.5 | 2.6 x 3.0 x 1.7 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 481.7, 38.0, -361.1 | 2.6 x 3.0 x 1.7 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 481.7, 38.2, -359.7 | 2.6 x 3.0 x 1.7 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 481.7, 38.5, -358.2 | 2.6 x 3.0 x 1.7 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_birch_a2_base |
| thornwold | invisible | `node:StaticBody3D` | 304.3, 34.9, -332.1 | 2.6 x 3.0 x 1.7 | thaw, rime, thaw+released, rime+released | 6 of 11 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 333.4, 38.7, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 357.7, 36.9, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 380.2, 37.7, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 405.9, 36.6, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 322.8, 35.7, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 334.9, 38.7, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 341.1, 36.0, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 342.3, 36.1, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 351.5, 36.8, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 359.1, 37.0, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 360.4, 37.0, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 360.5, 36.3, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_b_base |
| thornwold | invisible | `node:StaticBody3D` | 374.0, 37.5, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 384.9, 37.9, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 389.2, 35.4, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 390.7, 35.4, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 392.2, 35.5, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 393.9, 38.0, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 395.3, 38.0, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 396.7, 37.9, -280.3 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Scatter_rock_base |
| thornwold | invisible | `node:StaticBody3D` | 401.3, 36.3, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 420.9, 37.8, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 422.3, 37.9, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 425.4, 38.2, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 426.8, 38.3, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_birch_a2_base |
| thornwold | invisible | `node:StaticBody3D` | 437.5, 39.0, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 438.9, 39.0, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 443.7, 38.8, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 444.9, 38.8, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 448.2, 38.6, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 6 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 449.6, 38.6, -385.7 | 1.7 x 3.0 x 2.6 | thaw, rime, thaw+released, rime+released | 7 of 12 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_hedge_hd_laid2_base |
| thornwold | invisible | `node:StaticBody3D` | 335.8, 35.6, -283.5 | 0.8 x 4.0 x 0.8 | thaw, rime, thaw+released, rime+released | 12 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 342.7, 37.2, -373.8 | 0.8 x 4.0 x 0.8 | thaw, rime, thaw+released, rime+released | 8 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 308.4, 36.1, -290.5 | 0.8 x 4.0 x 0.8 | thaw, rime, thaw+released, rime+released | 11 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 423.8, 37.8, -351.3 | 0.8 x 4.0 x 0.8 | thaw, rime, thaw+released, rime+released | 9 of 14 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 312.2, 35.4, -345.8 | 0.8 x 4.0 x 0.8 | thaw, rime, thaw+released, rime+released | 10 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 369.9, 37.4, -299.5 | 0.8 x 4.0 x 0.8 | thaw, rime, thaw+released, rime+released | 11 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 318.1, 37.9, -376.8 | 0.7 x 4.0 x 0.7 | thaw, rime, thaw+released, rime+released | 10 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 446.3, 38.6, -378.6 | 0.7 x 4.0 x 0.7 | thaw, rime, thaw+released, rime+released | 10 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 408.4, 36.9, -365.9 | 0.7 x 4.0 x 0.7 | thaw, rime, thaw+released, rime+released | 10 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `node:StaticBody3D` | 362.1, 37.5, -332.4 | 0.7 x 4.0 x 0.7 | thaw, rime, thaw+released, rime+released | 10 of 15 body-height points of this CylinderShape3D have nothing drawn within 0.45 m; the nearest drawn thing is mm:Forest_tree_tr_pine_a_base |
| thornwold | invisible | `kit:hearthstone` | 340.1, 35.3, -303.1 | 1.1 x 0.9 x 1.1 | thaw, rime, thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| thornwold | invisible | `kit:hearthstone` | 462.0, 38.6, -297.3 | 1.0 x 0.9 x 1.0 | rime, rime+released | 4 of 6 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| thornwold | invisible | `kit:hearthstone` | 450.1, 38.6, -322.0 | 0.8 x 0.9 x 0.8 | thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| thornwold | partial | `mm:Forest_hedge_hd_laid2_base` | 303.4, 35.0, -313.8 | 1.9 x 1.8 x 2.0 | thaw, rime, thaw+released, rime+released | 16 of 47 body-height samples have no collider within 0.30 m; the largest bare patch is 16 samples, 1.2 x 1.1 x 0.4 m, standing 1.9 m out of the floor |
| thornwold | partial | `mm:Forest_hedge_hd_laid2_base` | 483.2, 39.7, -336.9 | 1.9 x 1.7 x 2.0 | thaw, rime, thaw+released, rime+released | 20 of 50 body-height samples have no collider within 0.30 m; the largest bare patch is 20 samples, 1.4 x 1.0 x 0.5 m, standing 1.7 m out of the floor |
| thornwold | walk_through | `scene:rime_stag.glb` | 373.1, 37.8, -292.7 | 6.0 x 5.9 x 5.0 | rime, rime+released | 16 of 16 body-height samples have no collider within 0.30 m; the largest bare patch is 16 samples, 2.6 x 0.6 x 1.9 m, standing 1.9 m out of the floor |
| thornwold | walk_through | `scene:rime_stag.glb` | 418.6, 38.4, -349.0 | 5.0 x 5.9 x 6.0 | rime, rime+released | 16 of 16 body-height samples have no collider within 0.30 m; the largest bare patch is 16 samples, 1.9 x 0.6 x 2.6 m, standing 1.9 m out of the floor |
| shepherds_reach | invisible | `landmark_blocker:lm_sheiling.glb` | 586.1, 67.5, -282.6 | 7.8 x 4.6 x 7.9 | thaw, rime, thaw+released, rime+released | 40 of 78 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_sheiling.glb |
| shepherds_reach | invisible | `landmark_blocker:lm_sheiling.glb` | 599.5, 68.9, -294.7 | 7.2 x 4.6 x 7.3 | thaw, rime, thaw+released, rime+released | 44 of 82 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_sheiling.glb |
| shepherds_reach | invisible | `node:StaticBody3D` | 605.9, 69.5, -285.0 | 2.8 x 2.6 x 2.8 | thaw, rime, thaw+released, rime+released | 26 of 50 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_fold_cairn.glb |
| shepherds_reach | invisible | `node:StaticBody3D` | 638.7, 72.0, -343.7 | 2.6 x 2.5 x 2.6 | thaw | 25 of 49 body-height points of this BoxShape3D have nothing drawn within 0.45 m; the nearest drawn thing is scene:lm_fold_cairn.glb |
| shepherds_reach | invisible | `kit:hearthstone` | 653.6, 77.7, -377.4 | 1.0 x 0.9 x 1.0 | thaw+released, rime+released | 4 of 5 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| shepherds_reach | invisible | `kit:hearthstone` | 604.0, 68.8, -306.1 | 1.0 x 0.9 x 1.0 | thaw, rime, thaw+released, rime+released | 4 of 7 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| shepherds_reach | walk_through | `kit:sheep` | 611.5, 69.2, -310.5 | 1.2 x 1.0 x 1.2 | thaw, thaw+released | 9 of 9 body-height samples have no collider within 0.30 m; the largest bare patch is 9 samples, 0.7 x 0.3 x 0.8 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 598.2, 68.2, -305.0 | 1.2 x 1.0 x 1.2 | thaw, thaw+released | 11 of 11 body-height samples have no collider within 0.30 m; the largest bare patch is 11 samples, 0.8 x 0.3 x 0.8 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 602.8, 68.4, -316.1 | 1.2 x 1.0 x 1.2 | thaw, thaw+released | 9 of 9 body-height samples have no collider within 0.30 m; the largest bare patch is 9 samples, 0.8 x 0.3 x 0.8 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 675.8, 74.2, -306.0 | 1.2 x 1.0 x 1.2 | thaw, thaw+released | 5 of 5 body-height samples have no collider within 0.30 m; the largest bare patch is 5 samples, 0.5 x 0.1 x 0.6 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 677.8, 74.5, -337.6 | 1.2 x 1.0 x 1.2 | thaw, thaw+released | 10 of 10 body-height samples have no collider within 0.30 m; the largest bare patch is 10 samples, 0.6 x 0.3 x 0.8 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 608.9, 67.1, -384.9 | 1.1 x 1.0 x 1.2 | thaw, thaw+released | 9 of 9 body-height samples have no collider within 0.30 m; the largest bare patch is 9 samples, 0.6 x 0.3 x 0.8 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 644.2, 71.5, -283.1 | 1.2 x 1.0 x 1.1 | thaw, thaw+released | 12 of 12 body-height samples have no collider within 0.30 m; the largest bare patch is 12 samples, 0.8 x 0.3 x 0.8 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 592.9, 65.7, -389.1 | 1.2 x 1.0 x 1.1 | thaw, thaw+released | 8 of 8 body-height samples have no collider within 0.30 m; the largest bare patch is 8 samples, 0.7 x 0.3 x 0.6 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 595.7, 67.2, -344.4 | 1.1 x 1.0 x 1.2 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.7 x 0.2 x 0.7 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 698.8, 76.0, -348.8 | 1.2 x 1.0 x 1.1 | thaw, thaw+released | 5 of 5 body-height samples have no collider within 0.30 m; the largest bare patch is 5 samples, 0.6 x 0.1 x 0.6 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 627.1, 70.7, -298.6 | 1.2 x 1.0 x 1.1 | thaw, thaw+released | 5 of 5 body-height samples have no collider within 0.30 m; the largest bare patch is 5 samples, 0.6 x 0.2 x 0.6 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 671.0, 76.5, -351.5 | 1.3 x 1.0 x 1.1 | thaw, thaw+released | 23 of 23 body-height samples have no collider within 0.30 m; the largest bare patch is 23 samples, 0.9 x 0.6 x 0.7 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 581.3, 66.4, -310.7 | 1.1 x 1.0 x 1.3 | thaw, thaw+released | 10 of 10 body-height samples have no collider within 0.30 m; the largest bare patch is 10 samples, 0.6 x 0.3 x 0.9 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 694.3, 74.8, -297.1 | 1.3 x 1.0 x 1.1 | thaw, thaw+released | 4 of 4 body-height samples have no collider within 0.30 m; the largest bare patch is 4 samples, 0.7 x 0.1 x 0.4 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 590.2, 67.7, -296.2 | 1.0 x 1.0 x 1.3 | thaw, thaw+released | 10 of 10 body-height samples have no collider within 0.30 m; the largest bare patch is 10 samples, 0.6 x 0.3 x 0.9 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 616.1, 67.8, -381.8 | 1.3 x 1.0 x 1.0 | thaw, thaw+released | 5 of 5 body-height samples have no collider within 0.30 m; the largest bare patch is 5 samples, 0.6 x 0.1 x 0.6 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 588.4, 65.9, -382.2 | 1.0 x 1.0 x 1.3 | thaw, thaw+released | 10 of 10 body-height samples have no collider within 0.30 m; the largest bare patch is 10 samples, 0.6 x 0.3 x 0.9 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 594.6, 67.6, -321.3 | 1.3 x 1.0 x 1.0 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.7 x 0.2 x 0.5 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 595.6, 66.0, -386.4 | 1.3 x 1.0 x 1.0 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.9 x 0.2 x 0.4 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 695.8, 76.0, -349.8 | 1.3 x 1.0 x 0.9 | thaw, thaw+released | 5 of 5 body-height samples have no collider within 0.30 m; the largest bare patch is 5 samples, 0.7 x 0.1 x 0.5 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 674.0, 73.5, -279.3 | 1.2 x 0.8 x 1.2 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.6 x 0.1 x 0.7 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 690.5, 74.7, -303.4 | 1.2 x 0.8 x 1.2 | thaw, thaw+released | 4 of 4 body-height samples have no collider within 0.30 m; the largest bare patch is 4 samples, 0.6 x 0.0 x 0.3 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 669.5, 73.6, -310.7 | 1.2 x 0.8 x 1.2 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.6 x 0.1 x 0.7 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 659.0, 73.0, -333.7 | 1.1 x 0.8 x 1.2 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.4 x 0.1 x 0.7 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 611.0, 67.2, -384.0 | 1.1 x 0.8 x 1.2 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.6 x 0.1 x 0.6 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 595.1, 67.9, -306.4 | 1.1 x 0.8 x 1.2 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.6 x 0.1 x 0.7 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 587.0, 66.7, -356.8 | 1.1 x 0.8 x 1.2 | thaw, thaw+released | 4 of 4 body-height samples have no collider within 0.30 m; the largest bare patch is 4 samples, 0.4 x 0.0 x 0.6 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 632.5, 69.9, -351.0 | 0.9 x 1.0 x 1.3 | thaw, thaw+released | 13 of 13 body-height samples have no collider within 0.30 m; the largest bare patch is 13 samples, 0.6 x 0.4 x 0.9 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 624.7, 70.5, -297.1 | 1.1 x 0.8 x 1.2 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.6 x 0.1 x 0.6 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 582.1, 66.4, -354.6 | 1.2 x 0.8 x 1.1 | thaw, thaw+released | 8 of 8 body-height samples have no collider within 0.30 m; the largest bare patch is 8 samples, 0.8 x 0.3 x 0.5 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 613.4, 69.4, -313.7 | 1.1 x 0.8 x 1.3 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.4 x 0.1 x 0.7 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 655.8, 72.7, -315.3 | 1.3 x 0.8 x 1.1 | thaw, thaw+released | 4 of 4 body-height samples have no collider within 0.30 m; the largest bare patch is 4 samples, 0.6 x 0.0 x 0.4 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 634.1, 71.2, -361.4 | 1.1 x 0.8 x 1.3 | thaw, thaw+released | 13 of 13 body-height samples have no collider within 0.30 m; the largest bare patch is 13 samples, 0.8 x 0.6 x 0.9 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 674.8, 74.2, -335.6 | 1.1 x 0.8 x 1.3 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.5 x 0.1 x 0.7 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 574.4, 65.6, -309.0 | 1.2 x 1.0 x 0.8 | thaw, thaw+released | 9 of 9 body-height samples have no collider within 0.30 m; the largest bare patch is 9 samples, 0.9 x 0.3 x 0.5 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 584.3, 66.4, -358.1 | 1.3 x 0.8 x 1.0 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.7 x 0.3 x 0.5 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 615.5, 69.7, -298.9 | 1.0 x 0.8 x 1.3 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.3 x 0.2 x 0.7 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 681.9, 74.5, -320.3 | 1.3 x 0.8 x 1.0 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.8 x 0.1 x 0.4 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 584.9, 66.5, -356.4 | 1.3 x 0.8 x 1.0 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.8 x 0.1 x 0.4 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 629.5, 70.8, -297.9 | 1.3 x 0.8 x 0.9 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.7 x 0.1 x 0.4 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 631.9, 69.7, -385.9 | 0.9 x 0.8 x 1.3 | thaw, thaw+released | 8 of 8 body-height samples have no collider within 0.30 m; the largest bare patch is 8 samples, 0.5 x 0.4 x 0.9 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 698.1, 76.0, -342.4 | 0.9 x 0.8 x 1.3 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.5 x 0.1 x 0.7 m, standing 0.7 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 579.8, 66.2, -325.8 | 1.2 x 1.0 x 0.8 | thaw, thaw+released | 8 of 8 body-height samples have no collider within 0.30 m; the largest bare patch is 8 samples, 0.8 x 0.3 x 0.4 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 582.9, 66.2, -357.6 | 0.8 x 1.0 x 1.2 | thaw, thaw+released | 12 of 12 body-height samples have no collider within 0.30 m; the largest bare patch is 12 samples, 0.5 x 0.4 x 1.0 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 671.5, 75.3, -348.1 | 0.9 x 0.8 x 1.3 | thaw, thaw+released | 16 of 16 body-height samples have no collider within 0.30 m; the largest bare patch is 16 samples, 0.5 x 0.6 x 1.0 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 601.1, 68.3, -307.6 | 1.2 x 1.0 x 0.7 | thaw, thaw+released | 11 of 11 body-height samples have no collider within 0.30 m; the largest bare patch is 11 samples, 0.9 x 0.3 x 0.4 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 574.7, 65.6, -307.4 | 1.2 x 0.8 x 0.8 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.8 x 0.1 x 0.4 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 698.5, 76.0, -357.6 | 0.7 x 1.0 x 1.2 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.4 x 0.2 x 0.8 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 637.4, 71.1, -338.4 | 0.7 x 1.0 x 1.2 | thaw, thaw+released | 6 of 6 body-height samples have no collider within 0.30 m; the largest bare patch is 6 samples, 0.4 x 0.2 x 0.8 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 632.0, 70.1, -348.0 | 1.2 x 1.0 x 0.6 | thaw, thaw+released | 11 of 11 body-height samples have no collider within 0.30 m; the largest bare patch is 11 samples, 0.9 x 0.3 x 0.4 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 676.9, 78.2, -375.2 | 0.6 x 1.0 x 1.2 | thaw, thaw+released | 19 of 19 body-height samples have no collider within 0.30 m; the largest bare patch is 19 samples, 0.5 x 0.6 x 0.9 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 655.6, 72.7, -306.5 | 1.2 x 1.0 x 0.6 | thaw, thaw+released | 8 of 8 body-height samples have no collider within 0.30 m; the largest bare patch is 8 samples, 0.8 x 0.3 x 0.3 m, standing 0.9 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 592.5, 67.4, -280.9 | 0.6 x 1.0 x 1.2 | thaw, thaw+released | 7 of 7 body-height samples have no collider within 0.30 m; the largest bare patch is 7 samples, 0.3 x 0.2 x 0.9 m, standing 0.8 m out of the floor |
| shepherds_reach | walk_through | `kit:sheep` | 650.1, 76.0, -358.6 | 0.6 x 0.8 x 1.2 | thaw, thaw+released | 25 of 25 body-height samples have no collider within 0.30 m; the largest bare patch is 25 samples, 0.4 x 0.6 x 1.1 m, standing 0.8 m out of the floor |
| coldwell | invisible | `kit:hearthstone` | 799.7, 116.9, -450.6 | 1.1 x 0.9 x 1.1 | thaw, rime | 4 of 8 body-height points of this CapsuleShape3D have nothing drawn within 0.45 m; the nearest drawn thing is kit:hearthstone |
| coldwell | partial | `scene:lm_wellhead_thaw.glb` | 922.2, 158.3, -481.8 | 7.5 x 3.2 x 8.0 | thaw | 134 of 223 body-height samples have no collider within 0.30 m; the largest bare patch is 38 samples, 2.1 x 1.2 x 0.5 m, standing 1.8 m out of the floor |
| coldwell | partial | `scene:lm_wellhead.glb` | 922.2, 158.3, -481.8 | 7.5 x 3.2 x 8.0 | rime | 134 of 223 body-height samples have no collider within 0.30 m; the largest bare patch is 38 samples, 2.1 x 1.2 x 0.5 m, standing 1.8 m out of the floor |
| coldwell | partial | `scene:lm_veil_rime.glb` | 912.1, 158.0, -476.1 | 1.8 x 5.5 x 5.2 | rime | 19 of 165 body-height samples have no collider within 0.30 m; the largest bare patch is 12 samples, 1.4 x 1.2 x 0.5 m, standing 1.7 m out of the floor |
| coldwell | partial | `kit:hearthstone` | 799.8, 116.4, -450.0 | 2.2 x 1.2 x 2.2 | thaw, rime | 18 of 33 body-height samples have no collider within 0.30 m; the largest bare patch is 18 samples, 1.4 x 1.1 x 0.8 m, standing 1.1 m out of the floor |
| coldwell | partial | `scene:upwalker.glb` | 821.5, 123.9, -453.7 | 1.4 x 1.9 x 2.0 | rime | 46 of 57 body-height samples have no collider within 0.30 m; the largest bare patch is 46 samples, 0.8 x 1.6 x 1.6 m, standing 1.8 m out of the floor |
| coldwell | partial | `kit:hearthstone` | 724.4, 86.7, -398.7 | 2.0 x 1.2 x 2.0 | thaw, rime | 11 of 15 body-height samples have no collider within 0.30 m; the largest bare patch is 11 samples, 1.4 x 1.0 x 0.6 m, standing 1.0 m out of the floor |
| coldwell | threshold | `door W0 of wellhouse_0` | 898.0, 172.8, -492.8 | 0.0 x 0.0 x 0.0 | thaw, rime | the doorway is blocked by node:Terrain/TerrainBody (the floor runs 172.17 to 174.20 over the 3.2 m through the door; the house floor is 174.62) |
| coldwell | threshold | `door W0 of wellhouse_0` | 898.0, 174.6, -490.4 | 0.0 x 0.0 x 0.0 | thaw, rime | no floor on the way through |
| coldwell | threshold | `door W1 of wellhouse_1` | 902.0, 143.4, -459.6 | 0.0 x 0.0 x 0.0 | thaw, rime | the doorway is blocked by node:Terrain/TerrainBody (the floor runs 142.05 to 143.43 over the 3.2 m through the door; the house floor is 144.64) |
| coldwell | threshold | `door W1 of wellhouse_1` | 902.0, 144.6, -456.4 | 0.0 x 0.0 x 0.0 | thaw, rime | no floor on the way through |
| coldwell | walk_through | `scene:upwalker.glb` | 768.8, 99.9, -412.2 | 1.7 x 1.9 x 1.8 | rime | 49 of 49 body-height samples have no collider within 0.30 m; the largest bare patch is 49 samples, 1.1 x 1.0 x 1.4 m, standing 1.5 m out of the floor |
| coldwell | walk_through | `scene:upwalker.glb` | 786.8, 107.4, -427.5 | 1.7 x 1.9 x 1.8 | rime | 58 of 58 body-height samples have no collider within 0.30 m; the largest bare patch is 58 samples, 1.1 x 1.3 x 1.4 m, standing 1.6 m out of the floor |
| coldwell | walk_through | `scene:upwalker.glb` | 804.4, 115.3, -442.3 | 1.6 x 1.9 x 1.8 | rime | 63 of 63 body-height samples have no collider within 0.30 m; the largest bare patch is 63 samples, 1.1 x 1.6 x 1.4 m, standing 1.7 m out of the floor |
| coldwell | walk_through | `scene:upwalker.glb` | 749.2, 92.4, -399.8 | 1.5 x 1.9 x 1.9 | rime | 57 of 57 body-height samples have no collider within 0.30 m; the largest bare patch is 57 samples, 0.9 x 1.3 x 1.5 m, standing 1.4 m out of the floor |
| coldwell | walk_through | `scene:upwalker.glb` | 726.6, 85.3, -389.2 | 1.2 x 1.9 x 2.0 | rime | 49 of 49 body-height samples have no collider within 0.30 m; the largest bare patch is 49 samples, 0.7 x 1.3 x 1.7 m, standing 1.3 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 777.8, 103.5, -419.9 | 1.5 x 1.8 x 1.7 | rime | 39 of 39 body-height samples have no collider within 0.30 m; the largest bare patch is 39 samples, 0.9 x 1.4 x 1.1 m, standing 1.7 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 795.2, 111.0, -434.7 | 1.5 x 1.8 x 1.7 | rime | 45 of 45 body-height samples have no collider within 0.30 m; the largest bare patch is 45 samples, 0.9 x 1.5 x 1.1 m, standing 1.8 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 759.2, 96.3, -406.1 | 1.3 x 1.8 x 1.8 | rime | 34 of 34 body-height samples have no collider within 0.30 m; the largest bare patch is 34 samples, 0.7 x 1.3 x 1.2 m, standing 1.6 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 813.7, 120.0, -449.9 | 1.3 x 1.8 x 1.8 | rime | 50 of 50 body-height samples have no collider within 0.30 m; the largest bare patch is 50 samples, 0.7 x 1.8 x 1.2 m, standing 2.2 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 832.2, 128.6, -459.1 | 1.2 x 1.8 x 1.8 | rime | 45 of 45 body-height samples have no collider within 0.30 m; the largest bare patch is 45 samples, 0.6 x 1.5 x 1.2 m, standing 1.9 m out of the floor |
| coldwell | walk_through | `scene:upwalker.glb` | 840.9, 133.2, -462.0 | 1.0 x 1.9 x 2.0 | rime | 62 of 62 body-height samples have no collider within 0.30 m; the largest bare patch is 62 samples, 0.6 x 1.6 x 1.7 m, standing 1.8 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 715.5, 81.9, -385.0 | 1.1 x 1.8 x 1.8 | rime | 28 of 28 body-height samples have no collider within 0.30 m; the largest bare patch is 28 samples, 0.5 x 1.3 x 1.3 m, standing 1.4 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 737.6, 88.8, -393.6 | 1.1 x 1.8 x 1.8 | rime | 27 of 27 body-height samples have no collider within 0.30 m; the largest bare patch is 27 samples, 0.5 x 1.4 x 1.3 m, standing 1.5 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 852.7, 138.1, -464.8 | 0.9 x 1.8 x 1.8 | rime | 43 of 43 body-height samples have no collider within 0.30 m; the largest bare patch is 43 samples, 0.4 x 1.4 x 1.3 m, standing 1.8 m out of the floor |
| coldwell | walk_through | `scene:upwalker.glb` | 862.3, 142.5, -466.6 | 0.7 x 1.9 x 1.9 | rime | 61 of 61 body-height samples have no collider within 0.30 m; the largest bare patch is 61 samples, 0.5 x 1.4 x 1.8 m, standing 1.6 m out of the floor |
| coldwell | walk_through | `scene:upwalker.glb` | 884.6, 150.7, -468.4 | 0.7 x 1.9 x 1.9 | rime | 52 of 52 body-height samples have no collider within 0.30 m; the largest bare patch is 52 samples, 0.5 x 1.3 x 1.8 m, standing 1.5 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 874.5, 146.9, -467.7 | 0.6 x 1.8 x 1.8 | rime | 39 of 39 body-height samples have no collider within 0.30 m; the largest bare patch is 39 samples, 0.4 x 1.4 x 1.4 m, standing 1.7 m out of the floor |
| coldwell | walk_through | `scene:unsung.glb` | 896.8, 154.8, -469.1 | 0.6 x 1.8 x 1.8 | rime | 31 of 31 body-height samples have no collider within 0.30 m; the largest bare patch is 31 samples, 0.4 x 1.3 x 1.4 m, standing 1.4 m out of the floor |
