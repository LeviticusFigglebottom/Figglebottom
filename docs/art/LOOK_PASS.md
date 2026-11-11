# The look pass: one art set (branch `art/unified-look`)

**Problem.** The owner's review: "all non-generated assets and textures still look so out of place". The Tripo heroes carry baked, painterly-real 2K PBR detail. Everything procedural was flat colour on shader noise: the terrain, the cliffs, the BuildingGen houses, the scatter, the kit primitives and the Thornwold trees.

**What changed**, in order of impact:

1. **CC0 photo PBR sets for every tiling surface** (`assets/textures/`, 49 MB). `tools/art/fetch_textures.py` holds the manifest: 19 Poly Haven / ambientCG sets with their ids and resolutions. It downloads them to `raw/textures/` (gitignored) and grades each toward the STYLE.md palette (desaturate, compress contrast, pull the mean hue toward a target). It then writes three JPEGs per set: albedo, OpenGL normal, and `orh` (R = AO, G = roughness, B = height). It also writes `.import` files (VRAM-compressed, mipmaps; Godot's JPG default has no mipmaps and shimmers) and records each set's linear mean in `sets.json`. Every set has a row in `assets/PROVENANCE.md`. Re-run the script to rebuild the whole set.
2. **Materials rebuilt around the sets** (`shaders/hall.gdshader`, `src/world/material_lib.gd`).
   - Each family in `MaterialLib.TEXTURES` names a set, a scale (repeats per metre, about 512 px/m near the player) and a strength.
   - The shader divides the photo by its own mean and re-tints it with the family `albedo`. **The family albedo stays the authority for the mean colour.** Palettes and per-area tweaks keep working; the photo supplies only the detail.
   - Anti-tiling: macro brightness and hue drift, plus a 4x lower-frequency sample blended in with distance.
   - The THAW/RIME branch is unchanged: hoarfrost greying, the wavefront frost and melt, and dissolve. RIME snow now uses the snow set and settles into low height first.
3. **Terrain** (`shaders/terrain.gdshader`, `src/world/terrain.gd`).
   - Photo splat layers: turf, heather, shingle, path, schist rock, snow, and packed snow on the paths in RIME.
   - Height-blended transitions: pebbles poke through turf instead of cross-fading.
   - A rotated second sample and a distance blend against tiling.
   - Rock is triplanar on the X and Z planes with v = the bed coordinate, so the schist strata stay level and dip with the beds. A single along-face projection swirled like wood grain on curved faces.
   - The palette uniforms (`turf_a`, `rock_col`, …) are the layer means. A landform can swap a layer's set with `"sets": {"rock": "rock"}` in its terrain block.
4. **UVs on procedural geometry** (`src/world/proc_mesh.gd`).
   - `ProcMesh.box()` maps each face planar in metres, with V along the board's long axis, so grain follows each stave, beam and plank. Each box gets its own UV offset, and a per-board tone in UV2.x.
   - `ProcMesh.append()` brings cylinders and tori in with metre-scaled UVs. `ProcMesh.finish()` indexes the mesh and adds tangents.
   - BuildingGen and Scatter's box props use it. Wide, thin `M_wood` boxes in area JSON (jetties, decks) become `M_planks`.
5. **Tripo heroes in place of primitives.**
   - Scatter rocks, boulders and driftwood use 5 Tripo meshes as MultiMesh variants: `assets/models/scatter/sc_*`, about 5.8k triangles each.
   - KitLib `boat` and `boat_upturned` use the existing Tripo clinker boat. `drying_rack` uses a new Tripo rack.
   - Thornwold trees (pine ×2, birch ×2, the grave pine, a dead snag) and hedge sections (laid, frozen thorn) are Tripo meshes. Each has a decimated far LOD and wind sway.
   - All of these are shaded through `MaterialLib.hero_mat()`, so they take the same THAW/RIME branch, snow crust and wavefront as everything else.
6. **Light.** THAW ambient is lifted from 0.48 to 0.58. The volumetric haze is thinned (0.0075 to 0.0062). Saturation drops from 1.02 to 0.97 and contrast from 1.09 to 1.06. Textured shade no longer sinks into brown-black next to the Tripo albedos.

## How generators must use MaterialLib (rules for new code)

- **Never invent a colour.** Pick a family. Add a family only for a new physical material, and give it a set in `TEXTURES` (or a reason in a comment why it has none).
- **Boxes and primitives you build yourself:** emit them through `ProcMesh` and ask for the uv variant:
  ```gdscript
  var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
  ProcMesh.box(st, Vector3(0.26, 3.0, 0.12), Transform3D(basis, pos))   # grain along the longest axis
  ProcMesh.append(st, cylinder_mesh, xf, Vector2(TAU * r, height))      # UVs in metres
  var mesh := ProcMesh.finish(st)
  mesh.surface_set_material(0, MaterialLib.get_mat("M_timber", mode, true))
  ```
- **Anything without metre UVs** (BoxMesh nodes, kit primitives, lumpy spheres): use `MaterialLib.get_mat(family, mode)`. It is object-aligned triplanar at world scale, rotates with the node, and stays continuous across abutting pieces.
- **Imported meshes with their own baked textures** (Tripo): use `MaterialLib.hero_mat(glb_material, family, mode)`. Never leave a StandardMaterial3D on a world mesh: it would not take the RIME snow, the wavefront or the dissolve.
- **Variants:** put hero meshes behind the same entry point and fall back to the primitives when the file is missing. Examples: `Scatter.HERO`, `KitLib.HERO_PIECES`, `Forest.HERO_TREES`, `Forest.HERO_HEDGES`. Layouts, colliders and the API never change.
- **New photo sets:** add them to `MANIFEST` in `tools/art/fetch_textures.py`, run it, then add the PROVENANCE rows. Use 1K unless the surface is seen at under 2 m.

## Tripo spend and what did not work

- **Re-texturing our own meshes** (`tripo_import` + `tripo_texture` with `use_original_uv`) was tried on the drying rack in five forms: Godot GLB, Blender-cleaned GLB, subdivided to 7.6k faces, OBJ, and `use_original_uv` false. Every attempt failed with "Illegal input" and was refunded. A remesh of the imported model failed the same way. Texturing a Tripo-generated project works (10 credits, standard). The procedural signature pieces therefore got Tripo-generated variants instead (boat, drying rack). `tools/art/export_proc_glb.gd` stays in the repo for when Studio accepts imports.
- The ledger rows are in `docs/art/TRIPO_LEDGER.md`.

## Renderer caveat

Headless screenshots run on lavapipe, which `EnvRig.get_graphics_quality()` puts at tier 1: SSAO is on, but **SDFGI, SSIL and SSR are off**. `--gfx=2` forces tier 2, but SDFGI does not converge in a 30-frame headless shot, so the difference is negligible. The screenshots show SSAO and no GI. On a real GPU (tier 2) the shade will be lighter and bounce-lit.

## Before/after cameras

`docs/screens/look_before_*.png` (origin/main) and `look_after_*.png` (this branch), 1920x1080, `--shot-nohud`:

| shot | area / state | camera |
|---|---|---|
| yard_thaw / yard_rime | saltfell_steading | -20,25,8,-45,-6,58 |
| strand | saltfell_steading thaw | -4,6.5,62,170,-10,62 |
| cliff_path | saltfell_steading thaw | -82,28,62,-66,-14,62 |
| wall_close (2 m) | saltfell_steading thaw | -8,23.7,-34,-90,-3,62 |
| ground_close (1.6 m) | saltfell_steading thaw | -12,23.6,-4,-30,-40,62 |
| lowe_thaw / lowe_rime | lowe_barrows | -53.5,34,-110.5,26.6,-7,62 |
| kettle_thaw | kettle_fjord | -64,4.2,-311,-50,-8,75 |
| kettle_ice_rime | kettle_fjord | -90,6,-330,-60,-8,70 |
| causeway | tarnhall thaw | 105,28,-331,-90,-8,62 |
| thornwold_clearing (after only; before = `thornwold_thaw_clearing.png`) | thornwold thaw | 334,37.3,-298,-56,-10,75 |
| thornwold_maze (after only; before = `thornwold_rime_maze.png`) | thornwold rime | 452,39.9,-347.5,-90,0,75 |

## Verdict and what is still synthetic

- **Now one world:** walls, decks, ground, cliffs, rocks, driftwood, boats, drying racks and the Thornwold wood. A textured stave wall beside Ingra the steward (`compare` camera, 12.5,23.4,1) reads as the same timber the Tripo props are made of.
- **Still giveaways:**
  - the **grass and heather cards** (flat-shaded blades, no texture), which are the biggest remaining tell at eye height;
  - the **fish-house and boat-shed gables**, which are textured but still read as boxes and tori at the barge-board horns;
  - **stacked thorn courses**, which show a faint band where one course sits on the next;
  - the **Kettle ice photo**, which is blotchy from above.
- **Next:**
  - alpha-card grass from a CC0 grass atlas;
  - Tripo gable-end variants once Studio texturing of imports works again (or image-to-model gable pieces at 95 credits each);
  - a taller single-course thorn section.

---

# Look pass 2 (branch `art/look-pass-2`)

**Problem.** After pass 1 the tiling surfaces and the rocks sat with the Tripo heroes. What still gave the procedural world away, in the order a player meets it at eye height: the ground cover (flat untextured blades, pink blobs), the rest sites (a primitive ring, slab and white cone), a flat orange sky, the gable ends, the fences and peat stacks, and the Reach flocks (spheres on sticks).

**What changed.**

1. **Ground cover is painted alpha cards** (`shaders/veg_card.gdshader`, `Scatter.build_veg`, `tools/art/veg_atlas.py`).
   - Three 2x2 atlases (`assets/textures/veg/T_veg_{grass,heather,sedge}.png`), each cut from one Tripo image-generator sprite sheet of four side-on clumps. The script keys the background, un-premultiplies, anchors each clump's root at its cell's bottom centre, bleeds colour into the transparent area (no dark mip halos) and grades.
   - A clump is three crossed cards, each tipped outward and curling (so it has a top from above), three vertex rows each (so the wind bends it). Each card takes a different atlas cell; per-instance custom data picks the base cell, dryness, value and wind phase.
   - Clumps gather in drifts: two octaves of value noise thicken a kind in patches a few metres across and thin it between them; thin ground is also drier.
   - Colour: texture x a tint that drifts across the field, bleached toward straw by dryness, roots sunk into the terrain's own `turf_a` (`Terrain.palette_color`). Lighting: one dome normal per clump on both faces, backlight at the tips.
   - RIME: 30-55% of clumps survive (per kind), half-buried, stiff, frosted pale from the tips down.
   - MultiMesh chunking (24 m), visibility ranges and the rule format are unchanged.
2. **Hearthstones** use `kit_hearthstone.glb` everywhere through `KitLib.HERO_PIECES["hearthstone"]`. `KitLib._hearth_bed` adds a mound of coals (`shaders/coals.gdshader`: Worley lumps with fire in the cracks, lit in THAW, banked to a few red cracks in RIME, following the wave), four low flame tongues and a small ember light. The collider, the interaction zone and the respawn point are untouched. The flame shader lost its blown-out white core; flame lights sit above the tips.
3. **Sky** (`shaders/stylized_sky.gdshader`, `EnvRig.blend`, `data/state_profiles.json` `sky_*` keys). Three-stop gradient, a haze belt that glows toward the sun and goes to dusk away from it, a sun disc and corona, a warped cloud deck with high streaks, lit from below on the sun side. RIME closes the deck (relief from its own thickness), veils the disc, and lets a faint two-ribbon aurora glow through. Every colour and amount is profile data and lerps with the state blend; an area's `env` block can override any `sky_*` key.
4. **Gables.** Two Tripo gable ends (`kit_gable_carved`, `kit_gable_shed`) replace the box-and-torus gable on every BuildingGen house. `BuildingGen._hero_gable` stretches the piece to the house (barge-board span, ridge height from `apex_frac`, tucked under the turf overhang). Sheds are picked by id prefix (`SHED_IDS`) or a `"gable"` key in the house spec.
5. **Props.** Tripo dyke and wattle sections and a peat stack through `Scatter.HERO`; the Lowe's standing stones and the Kettle's fish kettles now use the Tripo landmarks that already existed for the lineups; a Tripo brazier; two Tripo ewes (`M_fleece`, a new off-white wool family) taken in turn for the Reach flocks. Frozen ewes keep their baked detail under `M_rime`.
6. **Static landmarks (`lm_*`)** placed by area JSON are now shaded through `MaterialLib.hero_mat` (tint 0.2). They had been left on their import materials, so they took no RIME snow and no grade: the sheiling roofs were lime green.
7. **Leftovers.** Kettle ice: two photo samples at unrelated scales, clamped, and the bright-fleck term removed (the blotches). Thorn hedge: upper courses are offset half a section and sunk by a random depth, so the join is a ragged bond instead of a level band. `M_drystone` uses the stacked-stone set and `M_stone` has its photo contrast halved: the fieldstone photo's white flecks read as veined black marble on boxes (the Lowe barrow kerbs, house footings).

## Rules added

- **Ground cover:** add a kind by adding an atlas (2x2 clumps on black through `veg_atlas.py`) and a row in `Scatter.VEG_KINDS`. Do not hand-place cards.
- **Sky:** tune it in `state_profiles.json` (`sky_mid`, `sky_haze`, `sky_cloud_lit`, `sky_cloud_shade`, `sky_cloud_cover`, `sky_sun_disc`, `sky_aurora`, `sky_stars`, `sky_aurora_color`), never in the shader.
- **Landmarks:** a `"family"` key on a landmark spec picks the hall-shader behaviour (snow amount, rim); the default is `M_stone`.

## Before/after cameras (pass 2)

`docs/screens/look2_before_*.png` (integration-1110) and `look2_after_*.png`, 1920x1080, `--shot-nohud`:

| shot | area / state | camera |
|---|---|---|
| yard_thaw / yard_rime | saltfell_steading | -20,25,8,-45,-6,58 |
| hearth_thaw / hearth_rime (from behind the slab) | saltfell_steading | -23.8,23.3,25.7,45,-15,55 |
| hearth_front_thaw / _rime (after only) | saltfell_steading | -26.9,23.3,20.9,165,-15,55 |
| grass_eye | saltfell_steading thaw | -14,23.75,2,-45,-4,62 |
| lowe_road | lowe_barrows thaw | -53.5,34,-110.5,26.6,-7,62 |
| kettle_shelf | kettle_fjord thaw | -64,4.2,-311,-50,-8,75 |
| kettle_ice_rime | kettle_fjord rime | -90,6,-330,-60,-8,70 |
| thornwold_clearing | thornwold thaw | 334,37.3,-298,-56,-10,75 |
| thornwold_maze (after only; before = `look_after_thornwold_maze.png`) | thornwold rime | 452,39.9,-347.5,-90,0,75 |
| reach_fold / reach_sheilings | shepherds_reach thaw | 628,76,-342,-40,-20,70 / 572,73,-298,-95,-6,70 |
| coldwell_wellhead | coldwell thaw | 896,160,-478,-90,-20,70 |
| sky_rime (after only) | saltfell_steading rime | -20,26,8,0,25,80 |

---

# Look pass 3 (same branch)

1. **Fire is drawn, not modelled.** `KitLib._flame` builds three crossed cards and `shaders/flame.gdshader` draws the tongue on each: a teardrop whose axis is pushed about by rising noise and whose top tears off where the noise runs out, red at the edges through the tint to a pale core, additive. Every flame in the game (hearths, braziers, torches, hearth fires) goes through it; the instance uniforms and the `*flame*` naming that the lights and `Hearthstone` rely on are unchanged. `KitLib._embers` adds a dozen CPU-particle sparks to hearths and braziers (off in RIME at a hearth).
2. **Furniture.** Tripo trestle table, bench, barrel, rope coil, creel stack and draw-well replace their box and cylinder primitives through `KitLib.HERO_PIECES` (same ids, footprints and colliders by the usual path).
3. **Sheiling roofs.** `tools/art/regrade_glb.py` pulls one hue band of a GLB's embedded base colour to a target; run on `lm_sheiling.glb` it turns the lime roof to turf olive without touching the stone.
4. **Aurora** is at 0.5 and drifts at half the speed.
5. **Sward.** Every grass rule also lays a `sward` kind under itself: 0.4 m rosettes of the grass atlas laid almost flat, four times the rule's density, range 32 m, tinted near the ground colour with no root shadow. From above the clumps now stand in a pile instead of reading as dots on a photo. It is added after all authored rules, so no existing clump moved. `terrain.gdshader` is untouched.

Pairs: `docs/screens/look3_after_*.png`; the before for a shared camera is the matching `look2_after_*.png`. New cameras (after only): hall `2.5,23.6,-22,30,-10,70`, well `9.5,23.3,1,50,-12,55`, sward_top `-14,30,2,-45,-50,62` (all saltfell_steading thaw).

---

# Look pass 4 (same branch)

1. **Decks and piles.** `AreaBuilder._solid_box` no longer draws a timber box as a box: a wide thin one becomes a deck of individual boards (uneven widths, gaps, ragged ends) on two stringers (`_deck_mesh`), and a tall thin one becomes a round, slightly out-of-true post with grain running up it (`_pile_mesh`). Area JSON and colliders are unchanged, so every jetty, bridge deck, pile and fish-house stilt in every region is covered.
2. **Crate** is boards, battens and a lid instead of a cube.
3. **Flames** have a level heart disc low in the tongue (UV2.x = 1), drawn only when looked down on; the coal mound is flatter with smaller lumps.
4. **Grass** has a third layer, `blades`: 0.24 m upright tufts at six times the rule's density, drawn within 11 m.
5. **Well** stone regraded to the dry-stone grey-green with `regrade_glb.py --hue 70 190 --target 0.40 0.41 0.36 --sat-min 0.1 --value 0.9`.
6. **Forest draw cost** (a GPU counted 9.5 M primitives down the Thornwold maze). Heroes now draw in three bands: full mesh to 42 m (trees) / 26 m (hedges), decimated mesh with shadows to 95 / 60 m, decimated mesh without shadows and with a fade to 170 / 110 m. The constants are at the top of `forest.gd`. **Not measured**: this box has no GPU, so the < 2.5 M target is an estimate to verify with the perf tour.

**Blocked:** eight more Tripo props (crate, salt pan, woodpile, net frame, wayside plaque, long-fire logs, door leaf, rime spike) have approved-looking reference images (`look2/img/*` in the session scratchpad, not committed) but the paid generation step was denied by the session's permission system. The same applies to rigging the ewes. Those pieces are still primitives.

Pairs: `docs/screens/look4_after_*.png`; before = the matching `look3_after_*` / `look2_after_*`. New cameras (saltfell_steading thaw): grass_near `-14,23.3,2,-45,-28,62`, fire_above `-26.3,24.6,22.3,165,-62,55`; kettle_jetty `-79,3.6,-311,60,-14,70` (kettle_fjord thaw).

---

# Look pass 5 (branch `art/look-pass-5`)

**Problem.** The real-GPU review (`docs/qa/GPU_VISUAL_DIFF.md`, job 5) ranked what still read as generated. Worst: Thornwold's RIME thorn ("flat glassy shards", "stacked card strips"), the frost veils (one card, gone edge-on), and the last box props. Paid Tripo generation was not available, so everything here is modelled in Blender scripts, built from the CC0 sets, or done in shaders.

**How the modelled pieces are made** (`tools/art/procedural/`, run with the bpy venv):

- `proc_common.py`: a mesh buffer with UVs (tubes on parallel-transport frames, lathes, boxes mapped in metres, lumpy blobs), an atlas builder (columns of committed CC0 sets, V tiling), and `export_glb` (textured Principled material, tangents, JPEGs embedded). The GLB carries base colour, normal and roughness, so `MaterialLib.hero_mat` treats it exactly like a Tripo mesh.
- One script per family; every piece is seeded and deterministic. Re-running a script rewrites its GLBs byte-for-byte unless the script changed.

**What changed.**

1. **Frozen thorn** (`thorn_rime.py`; `Forest.HERO_HEDGES`, `ThornWall`).
   - A skeleton is grown, then skinned: stems and arching canes rise and bend under their own weight, space colonisation fills the volume with twigs, radii follow the pipe model, a smooth displacement kinks it all. Thorns are set along the thin wood; snow lies in the forks and is banked at the foot.
   - Pieces: two hedge sections (`hd_thorn3a/b`, 2.8 m x 3 m), a heap for the plugged drove road (`hd_thorn_heap`, style `thorn_heap`), and the Hedgelayer's raised wall (`hd_thornwall`).
   - A section is set in **one course at the height it was grown for**. Stretching and stacking the old Tripo section is what produced the shards and the bands.
   - Family `M_thorn_rime`: matt black wood under hoar frost, snow crust on top faces. `M_rime`'s gloss and glow on thin geometry was the "glass".
   - The Tripo `hd_thorn2` is removed.
2. **Frost veils** (`shaders/frost_veil.gdshader`, `src/world/frost_veil.gd`, `veil_frame.py`).
   - Three bowed sheets, about 0.9 m through. Each carries its own mist with a parallax offset; the heart sheet refracts the scene behind it; sheets brighten where they turn edge-on.
   - A frame of grown ice (`lm_veil_rime.glb`: crystals up both jambs to a pointed arch, icicles, snow at the feet) replaces the three wooden boxes. Frost drifts about it on CPU particles.
   - Per holdfast (`FrostVeil.DRESS`, overridable from the area's `shader` block): the Netmender's frozen net (the unused Tripo `lm_frost_veil_net`) hangs in the hall door; sod clods at the barrow; sheet-ice cracks at the Kettle and the Coldwell; door boards at Tarnhall; the wood's thorn up the jambs in Thornwold; frozen fleece locks at the fold.
   - The seal, the interaction zone and the aux walls are the same nodes with the same shapes. The dressing melts with the veil and returns on respawn.
3. **Props** (`kit_props.py`, through `KitLib.HERO_PIECES`): woodpile, long-fire logs on an ash bed (lit: coals, two flames, sparks), salt pan, net frame with a real knotted mesh, wayside plaque, door leaf, rime spike. Same ids, footprints and colliders.
   - **The Long Table's "white cubes" were its drinking horns**, drawn as boxes. They are horn beakers now (frozen over in RIME), with bread boards, and soapstone **fat lamps** with a rush wick. No candles (ORIGINALITY.md 3).
   - The causeway "granite cube", the boat-shed "slab" and the box benches in the gallery were the primitive hearthstone and furniture, already replaced in passes 2 and 3; that gallery predates their merge.
4. **Masks** (`masks.py`): the mourning masks are dished birch boards with eye holes cut through, a carved brow and a painted band.
5. **Coldwell.** Landmarks take `"pose": "<clip>@<fraction>"` (`PoseHold`): the river dead hold a frame of their own clips instead of the bind pose. The spring has its own shader (`spring.gdshader`: bed visible at the rim, a dark still eye, slow rings), a cobble kerb (`lm_spring_kerb`) hides the Tripo wellhead's pale base slab, and it is iced over in RIME.
6. **Ewes.** Unrigged still, but alive in THAW: the hall shader swings head and neck about the withers and flicks an ear (`graze_*` uniforms, set per GLB in `HERO_PIECES`), and `FlockWander` ambles each one a few steps at a time on a 2.6 m tether. Sixteen more are out. In RIME they are stills.
7. **Thornwold draw cost.** The full thorn mesh is drawn only within 13 m and casts no shadow; the far mesh casts for it (`SHADOWS_ONLY`), then carries the middle and far bands as before. Counts are in the table below.

## Rules added

- **Modelled pieces:** put the generator in `tools/art/procedural/`, build on `proc_common`, texture from committed CC0 sets through `make_atlas`, add a PROVENANCE row. Author at the kit footprint and leave `length` out of `HERO_PIECES`; set `"tint": 0.0` when one atlas holds several materials.
- **Frozen thorn is never stretched or stacked.** A different height is a different piece.
- **A veil's look is dressing only.** Do not move the seal or the zone for the art.
- **Rigged figures as dressing** need a `"pose"`.

## Before/after cameras (pass 5)

`tools/art/look5_shots.sh before|after [filter]`, 1280x720, `--shot-nohud`; pairs in `docs/screens/look5_{before,after}_*.png`. The gallery's veil cameras stand inside the veil, so each veil also has a camera 6-7 m out.

| pair | area / state | camera | primitives before → after (lavapipe, tier 1) |
|---|---|---|---|
| thornwold_drove_road_rime (gallery camera, inside the road plug) | thornwold rime | 318.0,35.6,-315.0,-67.7,-4.0,70 | 5.21 M → 5.31 M |
| thornwold_hedge_veil_rime (gallery camera, inside the veil) | thornwold rime | 440.0,39.4,-325.0,78.9,-4.0,70 | 2.41 M → 2.57 M |
| veil_thornwold_front (before taken 2 m further back, inside a hedge line) | thornwold rime | 435.4,39.38,-322.4,-60.5,6.0,70 | 3.45 M → 2.60 M |
| veil_tarnhall_front | tarnhall rime | 224.5,26.0,-331.6,112.0,4.0,65 | |
| veil_reach_front | shepherds_reach rime | 648.1,78.45,-356.4,-23.0,4.0,65 | |
| veil_saltfell_front | saltfell_steading rime | 2.6,23.7,-13.5,22.0,4.0,65 | |
| tarnhall_long_table_thaw | tarnhall thaw | 197.0,26.0,-327.4,89.2,-4.0,70 | |
| reach_sheilings_thaw | shepherds_reach thaw | 604.0,69.5,-306.0,18.4,-4.0,70 | |
| coldwell_spring_thaw | coldwell thaw | 915.5,160.4,-474.5,-61.7,-24.0,60 | |
| coldwell_river_dead_rime (after only) | coldwell rime | 757.9,97.5,-397.0,32.1,-6.0,60 | |

The Tarnhall and Reach veil afters were taken before the last mist change (it is a lighter frost-white now, as in the Thornwold and Saltfell shots).

## Verdict and what is still open (pass 5)

- **Fixed for real:** the frozen thorn. It is branching wood with thorns and snow, from inside the plug and from across the ring. The veils have a body, a frame and a region each. The Long Table, the long fires, the spring and the river dead no longer show a primitive or a bind pose.
- **Draw cost: the 2.5 M target is missed by 3% at the hedge_veil camera** (2.57 M; it was 2.41 M with the Tripo section). The modelled section is 19k triangles close up against 3k; it is held to 11 m and casts no shadow. The drove-road view is unchanged at 5.3 M and that is trees, not thorn. Next step if it matters on the GPU: a 9k middle mesh between 6 m and 13 m.
- **Not looked at in game:** the Lowe, Kettle and Coldwell veils (sod, sheet ice, spring ice), the veils from edge-on, the salt pan, woodpile, net frame and rime spike in place (their Blender renders were checked), the masks on their pegs, the ewes moving (stills only; the test proves they walk and stay tethered), the spring in RIME.
- **Known rough edges:** snow lumps on the thorn stems still read a little regular close up; bark stretches on the thickest stems; the veil's refraction was only seen under lavapipe; the ewes' head swing is a vertex bend, not a rig, and their legs do not step when they amble.
- **Still wanted from Tripo when it is allowed:** rigged ewes. The eight queued props are no longer needed.
