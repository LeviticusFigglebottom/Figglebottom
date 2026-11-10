# Real-GPU visual review

## Job 5 (2026-11-10): the new look at player-eye height, all seven areas

_Branch `gpu/gallery-2`, on `main` `77721c1` (includes `gpu/perf-2`). RX 9070 XT, q2 (SDFGI, SSIL, SSR, volumetric fog), 1920×1080, HUD hidden._

### What was rendered

- **84 shots in `docs/gallery_gpu/v2/`:** 42 viewpoints × THAW/RIME. JPEG q85; the lossless PNGs stay in `build/gallery_v2/`.
- **Cameras** come from `tools/gallery_v2_views.py`, generated from each area's JSON so new areas need no edits:
  - `<area>_eye_<point>`: 1.7 m over the ground (eye height) at the start, every hearth and every frost veil, looking towards the middle of the area's nav box.
  - `<area>_vista`: 26 m up and 30 m behind the start.
  - Three views where that rule hits rock or a wall are hand-set (`OVERRIDES` in the script).
- **Reproduce:**
  ```
  python3 tools/gallery_v2_views.py > build/gallery_v2_views.txt
  VIEWS_FILE=build/gallery_v2_views.txt PNG=build/gallery_v2 JPG=docs/gallery_gpu/v2 EXTRA=--shot-nohud tools/gallery_gpu.sh
  ```

### What still looks synthetic, ranked per region (worst first)

The owner's complaint is procedural assets that clash with the Tripo models. Each entry names the shot to look at. "Primitive" means a box, cone, sphere or flat card that is visibly one.

**Saltfell Steading**
1. **Primitive props: boxes for stone and slabs.** The slab in the boat shed (`saltfell_steading_eye_hs_boat_shed_*`) and the salt-cutting blocks in the yard are plain cuboids with a stretched rock texture, sitting next to the Tripo hound.
2. **The flame is a white cone** on the iron stand (`…_eye_hs_long_hearth_*`), the same in both states. It reads as a placeholder beside the textured hall.
3. **The RIME frost floor is a diamond lattice** (`…_eye_hs_long_hearth_rime`): a regular tiled pattern over the planks, and the same lattice on the door veil. Nothing natural repeats like that.
4. **The snow is featureless.** RIME ground is flat white, broken only by small dark pebbles that look pasted on (`…_eye_hs_salt_house_rime`, `…_eye_start_rime`). The drift by the start is one smooth cone.
5. **The cliffs are banded.** The terrain's cliff texture repeats in even horizontal strata (`…_eye_start_thaw`).

**Lowe Barrows**
1. **The peat drying stacks are black untextured boxes** (`lowe_barrows_eye_hs_open_barrow_*`, `…_open_barrow_veil_*`): dozens of near-black cuboids in rows. **The worst thing in the region.**
2. **Polygon cloud shards in the sky.** Pale flat triangles hang in the sky (`…_eye_hs_drying_stacks_thaw`, `…_eye_hs_open_barrow_thaw`). The same shards show in Shepherd's Reach and Coldwell; see the cross-cutting list.
3. **The boulders look glassy.** The big rock in `…_eye_hs_drying_stacks_*` is so specular it reads as glass or ice in THAW.
4. **The RIME ground** is flat white with scattered pebbles, as in Saltfell.

**Kettle Fjord**
1. **The fjord walls are huge flat facets** with a vertically stretched texture (`kettle_fjord_vista_*`, `…_eye_hs_fish_houses_*`). The spires read as extruded polygons. **The worst thing in the region.**
2. **A white triangular shard** sticks out of the wall at the start (`…_eye_start_rime`) and at the landing. It is a single flat-shaded wedge.
3. **The frost veil is a flat opaque card** when seen edge-on (`…_eye_breathing_hole_veil_rime`): a cream plane filling a third of the frame.
4. **Light: THAW blows out facing the sun at the Breathing Hole**, and the gorge shadow at the start is crushed to black (`…_eye_start_thaw`). This is exposure and bloom, not an asset.

**Tarnhall**
1. **The perfect cube** on the causeway (`tarnhall_eye_hs_tarn_causeway_*`), granite-textured, at eye level in the middle of the road.
2. **The fire on the long hearth is a white cone** (`…_eye_hs_long_table_*`), as at Saltfell. In the same shot the benches are boxes and the candles are white cubes.
3. **The gorge walls are striated** with a stretched texture (`tarnhall_vista_*`).
4. **The Tarn Steps fog pocket (Job 4) reads as brown smog in THAW** (`…_eye_hs_tarn_steps_thaw`). It is fine in RIME. Fixed on this branch: THAW density 0.02 → 0.006 (see below).

**Thornwold**
1. **The RIME frozen thorn is a heap of flat glassy shards** (`thornwold_eye_hs_drove_road_rime`): dozens of untextured gradient planes that clip through each other at eye level. **The worst single thing in the game today.**
2. **The RIME hedges are stacked card strips** (`…_eye_hedge_veil_rime`, `…_eye_hs_outer_ring_rime`): the frosted hedge walls read as repeated horizontal bands.
3. **The THAW fence posts are bright orange boxes** with stretched wood (`…_eye_hs_drove_road_thaw`), clashing with the Tripo trees behind them.
4. **The charcoal clamp is a dome with green dots** (`…_eye_hs_colliers_clearing_rime`).
5. **A Tripo birch, close up** (`…_eye_hs_outer_ring_*`): the trunk texture is low-res and the base has a hard dark band. This one is a Tripo asset, noted for honesty.
6. **Light:** the THAW forest floor goes black under the canopy (`…_eye_hedge_veil_thaw`, `…_eye_hs_the_pine_thaw`).

**Shepherd's Reach**
1. **The sheep are eggs on sticks** (`shepherds_reach_eye_hs_shielings_thaw`): a smooth beige ellipsoid on four box legs, in flocks of dozens (`…_eye_fold_veil_rime`). **The worst thing in the region**, and the most visible procedural model in the game.
2. **The fell flanks smear.** The steep slopes stretch the grass and rock textures into a feather or wing pattern (`shepherds_reach_vista_*`).
3. **Polygon cloud shards in the sky** (`…_eye_hs_shielings_thaw`).
4. **Cut rock ledges are faceted boxes** (`…_eye_fold_veil_*`).

**Coldwell**
1. **Hard flat horizon planes.** Big untextured grey and green sheets cut the skyline with straight edges (`coldwell_eye_hs_wellhead_steps_*`, `…_eye_wellhead_veil_thaw`, and the right side of `coldwell_vista_*`). **The worst thing in the region.**
2. **The Upwater is a flat ribbon with white streaks**, with no blend into its banks (`…_eye_wellhead_veil_thaw`, `…_eye_start_thaw`).
3. **The peak is a smooth extruded pyramid** with tiled stone (`…_eye_hs_ice_falls_*`, `…_eye_start_*`).
4. **The RIME sun disc has a dark ring round it** (`…_eye_hs_wellhead_steps_rime`, `…_eye_wellhead_veil_rime`), a sky-shader artefact.
5. **A box rock at the frame edge** (`…_eye_hs_upwater_*`).

### Cross-cutting, for art/look-pass-2 (most impact first)

1. **Primitive stand-ins:** boxes (peat stacks, slabs, causeway cube, benches, candles), cone flames, and the egg sheep. They are the clearest clash with the Tripo models, and each is a small, well-bounded asset swap.
2. **Rime constructs:** Thornwold's shard heap and card hedges, Saltfell's diamond-lattice frost and door veil, frost veils seen edge-on. RIME is half the game, and these look the most generated.
3. **Terrain cliffs:** stretched triplanar striping on steep faces, Kettle's faceted spires, Coldwell's flat horizon planes, the Reach's smeared flanks.
4. **Sky:** flat polygon cloud shards (Lowe, the Reach, Coldwell, Saltfell), and the dark-ringed RIME sun in Coldwell.
5. **RIME ground:** flat white snow with pasted pebbles. A snow normal/detail map and drift breakup would lift every RIME shot.
6. **Light** (not assets): eye-height shots towards a low sun blow out (bloom and the sun disc), and THAW shadow under the canopy or in deep gorges crushes to black. Worth a look at exposure, SSIL and fill once the assets are in.

### What holds up

The Tripo characters, hound and trees at mid distance; the pebble beaches; the plank halls' textures; the q2 water sheen (restored in Job 4); the volumetric fog in Kettle and Thornwold RIME.

---

## Job 2 (2026-11-08): real-GPU visual diff

_Rendered 2026-11-07/08 on the owner's PC: AMD RX 9070 XT, i9-12900K, Windows 10, Godot 4.7.2 stable, Forward+, 1920×1080. Branch `gpu/gallery`, based on main `adab65a`, with the textures VRAM-compressed as on `gpu/perf`._

### What was rendered

- **Shots:** `docs/gallery_gpu/<view>_<state>.jpg`. That is 18 viewpoints × THAW and RIME = 36 shots, at quality 2, which is what a real GPU gets by default.
- **Cameras:** these are the exact cameras of the area shots in `docs/screens`. No script recorded those cameras, so I read them back from the pose line each lavapipe shot prints in the corner (`src/ui/hud.gd`).
- **Manifest and runner:** `tools/gallery_gpu.sh`. It runs one Godot process per shot, waits 2,400 frames so the area title and the seam card have both faded, and places the camera 600 frames before capture so SDFGI and the fog history settle.
- **Lossless PNGs** are in `build/gallery_gpu/` on the PC. The committed JPEGs are q92.
- **Shot harness additions** (opt-in; the defaults are unchanged):
  - `--shot-settle=N`: frames between placing the shot camera and capture (default 10).
  - `--shot-quality=0|1|2`: forces the graphics tier.
- **Same-revision lavapipe pairs:** the reference shots in `docs/screens` come from older revisions, mostly the evening of 11-07. To get lavapipe shots from the same revision and cameras, run this in a cloud session:
  `WRAP='xvfb-run -a -s "-screen 0 1920x1080x24"' PNG=build/gallery_lvp JPG=build/gallery_lvp tools/gallery_gpu.sh`

### How to read the comparison

The lavapipe shots differ from these in two ways, and only the second is about hardware.

1. **Revision.** These differences come from content and code changes, not from the GPU:
   - The HUD and title cards were re-skinned.
   - The Bearer is now the Tripo model, not the red stand-in.
   - The RIME ground cover is buried (`114eab9`), so frost tufts are much sparser, and the longhouse floor shards are gone.
   - Spindrift is now drawn as streaks rather than round flecks.
   - The Lowe bridge is raised unless `lowe_bridge_down` is set. The manifest now sets it for the bridge view.
2. **Renderer and tier.** The lavapipe shots ran at quality 1, because headless auto-detect gives 1. A real GPU auto-selects **quality 2**, which adds SSIL, SSR and SDFGI.

### Findings

### 1. SDFGI makes open water dark and flat at quality 2 (look bug, affects players by default)

- **What happens:** at q2, open water loses its sky sheen and reads as dark, murky and nearly flat. Examples are the Lowe bog, the Kettle fjord, the Strand's sea and the fish-house water.
- **At q1** the same GPU shows warm, rippled water that matches the lavapipe shots.
- **Ablation** (temporary local switches; Lowe bog, THAW): image in `docs/gallery_gpu/_evidence_water_sdfgi.jpg`.

  | q2 with this off | Water |
  |---|---|
  | SSR | still dark |
  | SSIL | still dark |
  | **SDFGI** | **sheen restored** |

- **Cause:** with SDFGI on, the water's reflected light comes from SDFGI's probes rather than the sky radiance, so open water stops mirroring the bright low sun.
- **Why it matters:** real GPUs auto-select q2, so this is how most players will see every body of water.
- **Fix options** (look decisions, so for the lead):
  - **a.** In `water.gdshader`, add an explicit fresnel sky term. EnvRig already pushes `top_color`, `horizon_color` and `sun_color` to the sky; push them to the water as well.
  - **b.** Put a ReflectionProbe (UPDATE_ONCE, sky only) over each water body.
  - **c.** Default real GPUs to q1 and leave SDFGI opt-in. This also saves about 1.3 ms of GPU per frame (see `PERF_GPU.md`).

### 2. Volumetric fog is much stronger on hardware

- **What changes:** lavapipe draws the fog thinly, while the GPU renders the full volumetric in-scatter.
  - Distant cliffs lose contrast: the Lowe fell, the open barrow and the Kettle north wall.
  - Shadowed fog draws soft vertical light shafts: the Lowe fell in RIME.
- **The worst case:** at the Kettle breathing hole in THAW, the camera looks up the gorge toward the low sun. Glow plus forward-scattering fog (`volumetric_fog_anisotropy` 0.66) washes the left third of the frame to near white.
- **Art direction:** this is mostly the intended "volumetric light" mood, but nobody has seen it on real hardware before.
- **Suggestion:** check the Kettle THAW profile (`fog_density` / `vol_density` in `data/state_profiles.json` or the area's `env` override). Consider a lower anisotropy, or a per-area `vol_density` for the deep gorges.

### 3. No light leaks, banding or broken shaders

- **Light leaks:** the longhouse interior lights cleanly at q2, and SDFGI does not leak sky light through the walls.
- **Banding:** full-resolution crops of the fog gradients (Lowe fell, Kettle north wall, longhouse) show no banding.
- **Rendering errors:** across all 36 shots I saw no SSR streaking and no missing materials. A script check found no magenta pixels and no NaN-style black blocks.
- **Crushed shadows:** two shots have more than 1% pure-black pixels. In the breathing hole (THAW) it is 3.6%, on the shadowed gorge wall. In the longhouse (THAW) it is 1.2%, in the unlit corners. Both are crushed shadow, not artefacts. They are worth a look alongside finding 2, since the sunlit side of the same gorge blows out.
- **Shader compile hitches:** none are visible in the stills. The perf tour (`PERF_GPU.md`) saw no hitches over 33 ms except one or two at q2 at the Saltfell hall, probably an SDFGI cascade update after the camera jump.
- **Texture compression:** with all model textures VRAM-compressed (`gpu/perf`), I see no BC block artefacts at gallery distance.

### Per-view notes (GPU q2 against lavapipe)

| View | Notes |
|---|---|
| cliff_path, strand, ravine, yard, terrain_vista | Same composition. The GPU is hazier in the distance and its sea is darker (finding 1). In RIME the ground cover is sparser (revision). |
| longhouse_boss | Interior GI is clean. The floor frost shards are gone (revision). |
| rime_channel | Ice and glints match; the GPU adds more distant fog. |
| lowe_bog | Water is dark at q2 (finding 1). The Bearer is the Tripo model (revision). |
| lowe_bridge | Before the manifest set `lowe_bridge_down`, the bridge stood raised and blocked the view. It is lowered now. |
| lowe_fell, lowe_open_barrow, lowe_pass, lowe_road | Stronger fog and light shafts (finding 2). Otherwise they match. |
| kettle_* | Water and fjord read dark at q2 (finding 1). The breathing hole in THAW blows out toward the sun, and the north wall in THAW is heavily hazed (finding 2). The RIME views match well. |
