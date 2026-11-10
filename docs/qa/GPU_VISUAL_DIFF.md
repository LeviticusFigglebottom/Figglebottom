# Real-GPU visual diff (Job 2)

_Rendered 2026-11-07/08 on the owner's PC: AMD RX 9070 XT, i9-12900K, Windows 10, Godot 4.7.2 stable, Forward+, 1920×1080. Branch `gpu/gallery`, based on main `adab65a`, with the textures VRAM-compressed as on `gpu/perf`._

## What was rendered

- **Shots:** `docs/gallery_gpu/<view>_<state>.jpg`. That is 18 viewpoints × THAW and RIME = 36 shots, at quality 2, which is what a real GPU gets by default.
- **Cameras:** these are the exact cameras of the area shots in `docs/screens`. No script recorded those cameras, so I read them back from the pose line each lavapipe shot prints in the corner (`src/ui/hud.gd`).
- **Manifest and runner:** `tools/gallery_gpu.sh`. It runs one Godot process per shot, waits 2,400 frames so the area title and the seam card have both faded, and places the camera 600 frames before capture so SDFGI and the fog history settle.
- **Lossless PNGs** are in `build/gallery_gpu/` on the PC. The committed JPEGs are q92.
- **Shot harness additions** (opt-in; the defaults are unchanged):
  - `--shot-settle=N`: frames between placing the shot camera and capture (default 10).
  - `--shot-quality=0|1|2`: forces the graphics tier.
- **Same-revision lavapipe pairs:** the reference shots in `docs/screens` come from older revisions, mostly the evening of 11-07. To get lavapipe shots from the same revision and cameras, run this in a cloud session:
  `WRAP='xvfb-run -a -s "-screen 0 1920x1080x24"' PNG=build/gallery_lvp JPG=build/gallery_lvp tools/gallery_gpu.sh`

## How to read the comparison

The lavapipe shots differ from these in two ways, and only the second is about hardware.

1. **Revision.** These differences come from content and code changes, not from the GPU:
   - The HUD and title cards were re-skinned.
   - The Bearer is now the Tripo model, not the red stand-in.
   - The RIME ground cover is buried (`114eab9`), so frost tufts are much sparser, and the longhouse floor shards are gone.
   - Spindrift is now drawn as streaks rather than round flecks.
   - The Lowe bridge is raised unless `lowe_bridge_down` is set. The manifest now sets it for the bridge view.
2. **Renderer and tier.** The lavapipe shots ran at quality 1, because headless auto-detect gives 1. A real GPU auto-selects **quality 2**, which adds SSIL, SSR and SDFGI.

## Findings

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

## Per-view notes (GPU q2 against lavapipe)

| View | Notes |
|---|---|
| cliff_path, strand, ravine, yard, terrain_vista | Same composition. The GPU is hazier in the distance and its sea is darker (finding 1). In RIME the ground cover is sparser (revision). |
| longhouse_boss | Interior GI is clean. The floor frost shards are gone (revision). |
| rime_channel | Ice and glints match; the GPU adds more distant fog. |
| lowe_bog | Water is dark at q2 (finding 1). The Bearer is the Tripo model (revision). |
| lowe_bridge | Before the manifest set `lowe_bridge_down`, the bridge stood raised and blocked the view. It is lowered now. |
| lowe_fell, lowe_open_barrow, lowe_pass, lowe_road | Stronger fog and light shafts (finding 2). Otherwise they match. |
| kettle_* | Water and fjord read dark at q2 (finding 1). The breathing hole in THAW blows out toward the sun, and the north wall in THAW is heavily hazed (finding 2). The RIME views match well. |
