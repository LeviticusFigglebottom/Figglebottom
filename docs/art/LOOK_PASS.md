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
