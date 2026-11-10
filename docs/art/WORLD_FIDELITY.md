# World fidelity: buildings, interiors, light and ground (branch `art/world-fidelity`)

**Problem.** After the look pass every generated surface had a photo material, but the houses were still slabs: flat board walls, a box of turf, empty rooms lit like a hilltop, ground that stopped dead at the wall. A Tripo character two metres from such a wall showed it up.

**Goal.** Everything that is not a Tripo hero reads as the same world, with collision, door positions, footprints and the `houses` JSON unchanged. Decisions are recorded in ADR 0011.

## What changed

### 1. Buildings (`src/world/house_detail.gd`, `mesh_buf.gd`, `building_gen.gd`)

`BuildingGen` still owns the footprint, the collision solids and the far silhouette. `HouseDetail` builds what is seen inside 70 m.

| Part | Construction |
|---|---|
| Footing | Rounded field stones, some stacked two high, proud of the wall on both faces, on a plain core carried below the floor line so nothing shows through the joints. A house on a deck (fish-houses) stands on two sole logs instead. |
| Walls | A sill beam on the footing. Staves are six-sided sections that bite into their neighbours, so every joint is a real V that catches light. Each is swept through four rings that bow, lean and twist by millimetres. Bay posts every 4 m, a chamfered wall plate, an eave board up to the roof. |
| Doors | A worn threshold stone, chamfered jambs, an eared lintel, short staves over it. A pair of plank leaves stands open: ledges and a brace on the back, tapering iron straps with nail heads, pintles, a ring handle on its plate. |
| Windows | Real holes in the stave wall with a sill, head and jambs, and one ledged shutter on strap hinges, shut, ajar or pinned back. Byres get barred vent slots. Sheds get none. |
| Roof, underside | Individual boards running down the slope, rafters at about 1 m with their tails under the eave, a purlin per slope, a ridge beam. |
| Roof, eave | Birch-bark sheets lapping out past the boards, each drooping its own amount. A turf log held by wooden hooks. The cut soil of the turf above it. |
| Roof, top | Turf as a displaced grid: lumps at two scales, a faint step at every sod course, and a ridge roll whose line wavers and sags between the gables. Pairs of weighted poles cross the ridge and run down each slope, a stone at the foot of some. |
| Smoke-hole | Halls and fish-houses: a boarded curb, corner posts, slanted louvre slats on four sides and a boarded cap. The roof boards are cut away under it. Halls smoke in THAW. |
| Gables | The gable triangle is boarded from inside up to the roof. Barge-boards carry a two-strand interlace between fillets with a lozenge at each end (abstract, no letters). The horns are untouched. |
| Barrows | Split-faced coursed slabs, two orthostats, a threshold, chinking stones along the facade foot, and a kerb ring of boulders round the mound. The mound is finer and lumpier. |

**Marks are vertex colour, not decals.** `MeshBuf` writes R = wear, G = moss, B = AO, which `hall.gdshader` already reads. One pass (`HouseDetail.shade`) darkens wall feet, the wall under the eaves and along the rake, and room corners; puts moss low on the walls and strongest on north faces; smokes the wall over each lintel and the roof round the smoke-hole; and wears the timber near doors.

**LOD.**

| Range | What draws |
|---|---|
| 0 to 36 m | everything |
| 36 to 70 m | iron, bark, hooks, slats, carving and hung goods drop out |
| 49 m | the interior fittings drop out |
| past 70 m | five plain meshes: plank slabs on a stone band, turf slabs with the ridge roll, the corner posts and the gable ends (as before the pass) |

### 2. Interiors (`src/world/house_interior.gd`)

- **Frame.** A king-post truss on every bay line: tie beam on the plates, king post, struts to the purlins, knee braces off the wall posts with peg heads.
- **Benches.** Dwellings get raised side benches down the long walls, with a fleece here and there. They are 0.5 m deep, inside the wall's own collision reach.
- **Hearth.** A kerb of stones set flush with the floor, an ash bed, charred billets, glowing embers and a flickering light (THAW only). It sits under the smoke-hole, or a step along the room if that spot is taken. It is skipped where the area already keeps a fire.
- **Hung goods**, all above head height: hams, sacks and herb bunches in halls and stores; poles of split fish in fish-houses; spare oars across the ties of the boat-shed; rope coils on wall posts.
- **Fittings step round the area's own furniture.** `_occupied()` reads props, pieces, boxes, NPCs, pickups, spawners, hearths and landmarks from the area JSON.

Nothing here collides.

### 3. Light (`src/world/house_probe.gd`)

- **Indoors:** one ReflectionProbe per house, sized wall line to wall line. Inside it surfaces take the room's ambient in place of the sky's and reflect the room, not the sky. The ambient follows `StateDirector.state_blend`: fire-warm in THAW, cold blue in RIME. The values are in `data/game.json` → `render/interior`. The cubemap is captured once and again when a state change settles. Open-fronted sheds get a lighter hand. Quality tier 0 skips the probe.
- **Outdoors:** the contact shadow is the vertex AO above plus the terrain's wall-foot term below.
- **Exposure:** checked with a Tripo NPC two metres from a wall, indoors and out (`hall_lusse_thaw`, `ingra_store_thaw`). No grade or exposure value was changed.

### 4. Ground (`shaders/terrain.gdshader`, `src/world/terrain.gd`)

`Terrain.add_footprint()` passes each building's rectangle, yaw, floor height and doors to the shader (up to 16 footprints, 24 doors).

| Mark | What it does |
|---|---|
| Contact shadow | Albedo and AO fall off within about half a metre of a wall. |
| Wall foot | A ragged strip of bare trodden earth where grass does not grow. |
| Drip line | Washed gravel pokes through the turf 0.8 m out, under the eaves. |
| Doorways | A worn way runs out of every door and fades over 4 m. |
| Under a roof | An earth floor in closed houses. In RIME it takes hoarfrost, not snow. |
| RIME | Snow lies unbroken against the walls. The bank itself is geometry (`HouseDetail.build_drifts`): deeper on the lee side and in corners, dug out at doors, following the terrain. On a deck it is a thin sill. |

Close-up, on all terrain:

- **Parallax** on the path and the shingle (two steps, 5.5 cm, fades by 18 m).
- **A finer second sample** of albedo and normal inside 7 m.
- **Puddles** in the low places of worn ground in THAW: dark, flat, glossy, with a damp rim. In RIME the same places are **ice patches** with pale veins. None lie within a metre of a wall, where they would mirror a fire through it; the worn way out of a door keeps its own.
- **Wet shore:** glosses toward the waterline, with a ragged wrack line where the last tide stopped.

## Verification

`tools/art/world_shots.sh before|after [filter]` renders every pair at 1280x720 from eye height. Files are `docs/screens/world_before_*.png` and `world_after_*.png`.

| Shot | Area / state | Camera (x, y, z, yaw, pitch, fov) |
|---|---|---|
| yard | saltfell_steading thaw, rime | 5, 23.6, -11, 25, -2, 62 |
| door | saltfell_steading thaw | 1.6, 23.6, -16.6, 22, -2, 62 |
| wall (2 m) | saltfell_steading thaw, rime | -8.3, 23.6, -30, -90, -2, 62 |
| foot | saltfell_steading thaw, rime | -9.5, 23.6, -27, -50, -22, 62 |
| longhouse_in, longhouse_in2 | saltfell_steading thaw, rime | 0, 23.6, -22.5, 0, -3, 70 and -2.5, 23.6, -47, -155, -4, 70 |
| byre, boatshed | saltfell_steading thaw | -17.5, 23.6, -12, 80, 0, 62 and 25, 4.8, 66, 0, 2, 66 |
| ingra_store (Tripo NPC by a house) | saltfell_steading thaw | 11.5, 23.4, -2.5, -40, -3, 55 |
| fishhouse, fishhouse_in | kettle_fjord thaw (and rime) | -46.5, 3.7, -314.5, 12, 0, 62 and -48, 3.7, -323.2, 0, -4, 75 |
| hall_in | tarnhall thaw, rime | 183.5, 25.9, -330, -90, -2, 70 |
| hall_lusse (Tripo NPC 2 m from a wall) | tarnhall thaw | 196.5, 25.9, -328.6, -141, -4, 55 |
| barrow | lowe_barrows thaw, rime | -56.4, 33.2, -115.8, 26.57, -2, 62 |
| clearing | thornwold thaw | 334, 37.3, -298, -56, -10, 75 |

**Suites run on this branch:** smoke, steading, lowe, kettle, tarnhall, thornwold, reach, coldwell. All pass.

## Cost

Triangles and mesh instances per house, all LODs together. "Near detail" is `--house-stats` (`godot --headless --path . -- --area=<id> --quit-after=4 --house-stats`): what `HouseDetail` adds inside 70 m.

| House | Size | Before: triangles / meshes | After: triangles / meshes | Near detail | of which small parts (to 36 m) | of which interior (to 49 m) |
|---|---|---|---|---|---|---|
| Tarnhall hall | 14 x 36 | 12,696 / 5 | 73,932 / 18 | 70,704 | 11,028 | 7,768 |
| Saltfell longhouse | 12 x 32 | 11,292 / 5 | 64,456 / 18 | 61,466 | 9,756 | 7,300 |
| Tarnhall byres | 10 x 14 | 7,212 / 5 | 32,300 / 16 | 29,432 | 6,444 | 1,384 |
| Saltfell byre | 8 x 12 | 6,252 / 5 | 27,706 / 16 | 25,076 | 4,968 | 1,352 |
| Saltfell boat-shed | 12 x 12 | 5,256 / 5 | 27,300 / 15 | 25,400 | 6,120 | 1,392 |
| Saltfell store | 8 x 8 | 5,436 / 5 | 22,832 / 17 | 20,202 | 4,788 | 870 |
| Kettle fish-houses | 8 x 8 | 5,400 / 5 | 22,400 to 22,700 / 19 | 18,300 to 19,600 | 4,900 | 3,100 to 4,100 |
| Coldwell well-houses | 6 x 8 | 4,950 / 5 | 19,200 to 20,200 / 17 | 16,800 to 17,800 | 4,000 | 790 |

Three of each house's meshes are the far LOD, so a near house is 12 to 16 draw calls per pass (it was 4), plus one probe. A far house is 5 (it was 4). The rows were measured before two late additions (a plain core behind the footing stones, the fish-house hearths), which add a few hundred triangles each.

Building an area headless takes 0.2 to 0.8 s longer on this box (Saltfell 4.9 s to 5.1 s, Tarnhall 3.4 s to 4.1 s, Kettle 3.3 s to 3.5 s).

Whole-frame counts from the harness (`[shot] stats`, lavapipe, tier 1, shadows included):

| Shot | Draw calls before | after | Triangles before | after | Change |
|---|---|---|---|---|---|
| yard_thaw | 613 | 657 | 1,113,784 | 1,385,352 | +7% calls, +24% triangles |
| door_thaw | 622 | 665 | 1,088,313 | 1,359,593 | +7% calls, +25% triangles |
| wall_thaw | 720 | 774 | 1,551,159 | 1,849,825 | +7% calls, +19% triangles |
| foot_thaw | 990 | 1044 | 1,984,413 | 2,289,219 | +5% calls, +15% triangles |
| longhouse_in_thaw | 847 | 898 | 1,598,671 | 1,893,591 | +6% calls, +18% triangles |
| longhouse_in2_thaw | 779 | 840 | 1,587,787 | 1,905,005 | +8% calls, +20% triangles |
| byre_thaw | 355 | 376 | 1,120,396 | 1,187,204 | +6% calls, +6% triangles |
| boatshed_thaw | 766 | 796 | 2,042,902 | 2,112,754 | +4% calls, +3% triangles |
| ingra_store_thaw | 768 | 818 | 1,922,787 | 2,163,083 | +7% calls, +12% triangles |
| yard_rime | 558 | 603 | 1,190,725 | 1,464,141 | +8% calls, +23% triangles |
| wall_rime | 537 | 581 | 1,318,862 | 1,565,610 | +8% calls, +19% triangles |
| foot_rime | 858 | 912 | 1,943,383 | 2,244,317 | +6% calls, +15% triangles |
| longhouse_in_rime | 621 | 676 | 1,256,585 | 1,556,113 | +9% calls, +24% triangles |
| longhouse_in2_rime | 809 | 870 | 1,881,812 | 2,208,822 | +8% calls, +17% triangles |
| fishhouse_thaw | 233 | 278 | 520,160 | 600,880 | +19% calls, +16% triangles |
| fishhouse_in_thaw | 145 | 176 | 451,336 | 510,744 | +21% calls, +13% triangles |
| hall_in_thaw | 1559 | 1600 | 1,275,977 | 1,573,457 | +3% calls, +23% triangles |
| hall_out_thaw | 1129 | 1167 | 881,664 | 1,193,980 | +3% calls, +35% triangles |
| hall_lusse_thaw | 1063 | 1112 | 1,142,995 | 1,480,823 | +5% calls, +30% triangles |
| barrow_thaw | 234 | 235 | 1,329,129 | 1,369,401 | +0% calls, +3% triangles |
| wellhouse_thaw | 101 | 123 | 387,825 | 433,905 | +22% calls, +12% triangles |

## With the look passes (merged state)

`main` took this branch at `ce498d8` together with look passes 2 to 4. The branch has since merged `main` back, so it shows the two together: the Tripo gable ends over these walls, card grass rooted in this turf and round these wall feet, the painterly sky. `docs/screens/world_merged_*_thaw.png` are five of the cameras above on that state (yard, gable, ingra, in, roof). `building_gen.gd` merged without conflict; the one conflict was a reformatted `data/game.json`.

The pairs above were shot before that merge, on the same base as their "before", so they show this pass alone.

## Second pass: the real-GPU findings (`docs/qa/GPU_VISUAL_DIFF.md`)

The GPU gallery (`docs/gallery_gpu/v2/`) showed four things in this lane. None of the fixes below has been seen on hardware: they were reasoned from the gallery and checked for sanity under lavapipe. Pairs: `docs/screens/world2_before_*.png` and `world2_after_*.png` (lavapipe, tier 1).

| Finding | Change | Where |
|---|---|---|
| THAW washes out toward the low sun | Forward scatter 0.66 to 0.42 (`vol_anisotropy`), bloom 0.65 to 0.5, and at tier 2 bloom starts at 1.15 with less spread. Kettle: sun 2.8 to 2.3, volumetric density 0.006 to 0.0038, anisotropy 0.3, exposure 1.08 to 0.98. | `data/state_profiles.json`, `tools/gen_kettle.py`, `EnvRig._apply_exposure` |
| Shade crushes to black in gorges and under canopy | THAW ambient 0.58 to 0.66 and fill 0.22 to 0.3. Kettle ambient 0.62 to 0.95. At tier 2 the SSAO is scaled by 0.72 (SSIL and SDFGI occlude as well) and SDFGI energy is 1.0. | same, `data/game.json` → `render/exposure` |
| Cliffs: flat facets, even strata | Beds of uneven thickness, a lit ledge and a line of shade at each bed, joints that crack beds into blocks, and a macro normal (9 m and 3 m) so a facet of the heightfield no longer shades as one plane. | `shaders/terrain.gdshader` (`rock_relief`) |
| Coldwell: flat horizon sheets | The horizon mesh is flagged (`UV.y = 1`); it and all ground past 120 m take patches of turf and heather, outcrops and a rolling normal. | `terrain.gdshader`, `Terrain._build_far` |
| RIME snow is featureless | Drift shading (pale crests, blue hollows), wind ripple and drift roll in the normal, and view-dependent sparkle inside 28 m. | `terrain.gdshader` (`snow_ripple`) |

**Auto-exposure is wired but off** (`render/exposure/auto`). Forced to tier 2 under lavapipe it brightened the Kettle vista further, so it should be tried on hardware before it is turned on.

**Not done in this pass:**

- Kettle's spires are the heightfield's own shape. The shader hides the facets' flat shading; it does not change the silhouette. That needs `tools/terrain_kettle.py` or rock meshes along the lips, which is generator and scatter work.
- The horizon sheets still end in straight edges where the far grid steps.
- The stretched texture on near-vertical faces is the 1 m grid: a cliff face spans few vertices. Tessellation near the camera was not attempted.

## Third pass: traps, boss models, yards (owner's report)

**Traps.** `tools/audit_edges.py` now also finds ground the Bearer can drop or slide onto and cannot walk back out of (a step up is limited to the walk slope, a step down is free). It found five regions:

| Area | Where | Size |
|---|---|---|
| Kettle Fjord | x -200..-151, z -298..-289 (the shore at the fjord mouth) | 266 m² |
| Lowe Barrows | x -128..-19, z -320..-251 (the north slope down to the sea) | 2,419 m² |
| Lowe Barrows | x 71..85, z -85..-80 (a chute) | 53 m² |
| Saltfell | x -111..-67, z -171..115 (the shore under the west cliffs) | 1,842 m² |
| Saltfell | x -83..70, z -83..-59 (ledges in the gully north of the longhouse) | 732 m² |

`tools/fix_traps.py` writes them per state to `data/terrain/traps/<area>.json`. In game a `TrapWarden` remembers the last safe ground the Bearer stood on; if he stands in a trap for `hazard/strand_seconds` (2.2 s) he is set back there at a cost of `hazard/strand_damage` (12 % of health, never the last of it). Falling through or crossing a trap does nothing. The audit counts marked cells as guarded and fails on any trap that is not marked, so a new ditch cannot land unnoticed. Suite: `traps` (22 checks).

A ramp of fill was tried first (`fix_traps.py` still has it, with `terrain_patch.py` applied by every terrain generator). The Kettle ramp did not close its trap and the other four need 11 to 25 m of fill, so none is in use.

**Clipping.** Barrow mounds now collide as the mound's own triangles (they were boxes that stopped short of the turf at the shoulders and stood proud of it at the ends). I could not play the game, so other spots where the ground can be walked through were not found by this pass.

**Boss models.**

- The Netmender was the one boss stored as loose triangles with a one-sided material. `tools/art/weld_glb.py` snapped corners within 1.5 mm to one position and one set of skin weights (6,739 corners) and made her double-sided, like the other six.
- All seven bosses import with `generate_lods=false`: importer-made LODs crack a skinned, seam-split mesh at fighting distance.
- `frost_dissolve.gdshader` is `cull_disabled`: it used to cull the backs of the double-sided bodies from the moment of death.

Checked in a still only (`boss` and `anim` suites pass). Whether gaps remain in motion needs a look in game.

**Yards.** `HouseYard` dresses the ground round every house with KitLib's modelled props through `AreaBuilder._piece` (so they collide): woodpiles, barrels, a bench, crates and sacks at halls, stores and byres; creels and rope at sheds. It skips doors, corners, anything the area already placed, and ground that is not level with the floor. That is 27 props at Saltfell and 15 at Tarnhall; the Kettle fish-houses and the Coldwell well-houses get none because they stand on decks and ledges.

**Not done:** new points of interest and denser props away from houses. That is authoring per region in the area generators (`tools/gen_*.py`), and I did not start it.

## What is still synthetic

- **Shadow sides at dusk are very dark**, on houses and on barrow facades alike. That is the sun and ambient balance, not the buildings; it was the same before. It wants SDFGI bounce (tier 2) or a lift in the THAW fill.
- **Carved barge-boards only show where a Tripo gable is missing.** The Tripo piece replaces the old gable whole, so the interlace carved here is a fallback. The gable triangle is still boarded from inside, because the Tripo piece has no inner face.
- **Door leaves and benches do not collide**, by the brief. A body hugging the wall beside a door can clip a leaf.
- **Hung goods are simple shapes.** They read at ceiling height; they would not survive a close look.
- **The Kettle fish-house floors are dim** where no fire is lit. The probe ambient is the only light there.
- **Lavapipe only.** Nothing here was seen on a real GPU. The probe capture, the parallax depth and the puddle gloss want a look at tier 2.
