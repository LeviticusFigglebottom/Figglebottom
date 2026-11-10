# GPU performance profile

## Job 4 (2026-11-10): perf and look fixes, all seven areas

_Branch `gpu/perf-2`, based on `feat/integration-1110` `5a2b03b`. Same machine and method as Job 1 below; cap 120, 5 s per view, 1920×1080._

**Before** is `5a2b03b`; **after** is `gpu/perf-2`. Both trees were run **interleaved, area by area** (before then after for each area), so the ±30% CPU drift on this machine falls on both alike. Each cell is the mean over the area's views (start, up to three hearths, the first veil, overview): 84 runs, 42 per tree.

### What changed

1. **Water under SDFGI (decision a).** `water.gdshader` gets a Schlick sky term from EnvRig's sky colours (`rh_sky_top`, `rh_sky_horizon` shader globals), switched on by `rh_water_sky_fill` only when SDFGI is on (q2). It was tuned on the GPU against q1 on the Lowe bog: a full-strength term read as snow at grazing angles, and the shipped weight (0.16, Fresnel capped at 0.6) matches q1's sheen. The cost is not measurable.
2. **Volumetric fog per area.** The env block's `vol_density` was already a per-state override. `vol_anisotropy` is now one too (default 0.66). The deep gorges get **`fog_pockets`**: local ellipsoid `FogVolume`s, blended thaw→rime with the state. They are authored in `tools/gen_kettle.py` (the Breathing Hole), `tools/gen_tarnhall.py` (the Tarn Steps) and `tools/gen_steading.py` (the gully below the cache), so a whole-area density change was not needed. Densities are first-pass; Job 5's gallery will check them in context.
3. **Re-path throttle (a).** `Enemy._st_approach` sets `agent.target_position` only when the quarry has moved past `max(0.35 m, 8% of the distance)`, or every 0.3 s (staggered per foe). Steering still reads `get_next_path_position()` every frame, and no data timing changed.
4. **Weather on the GPU (b).** `Weather` emitters are authored as before, then converted with `GPUParticles3D.convert_from_particles`, with hand-set `visibility_aabb`s. The look was checked against the baseline at the Breathing Hole in RIME.
5. **Profiling tools (c).** `perf_tour.gd` gains `--perf-ablate=script:<path part>`, `--perf-census` (processing nodes per script), `--perf-census-at=x,y,z[,r]` (triangles per mesh near a point) and `--perf-settle=N` (extra settle seconds).

### Headline

- **RIME CPU time fell 8%; RIME script time fell 12%** (means over all 21 RIME area×tier cells: CPU 7.00 → 6.46 ms, script 4.23 → 3.73 ms). The biggest drops are where packs hunt: Tarnhall RIME q2 script 6.16 → 4.21 ms, Kettle RIME q2 4.46 → 3.60 ms, Coldwell RIME 2.7–2.9 → 2.2–2.4 ms. Saltfell and Lowe at q1/q2 are within noise. THAW is flat (−1%), as expected: there is little hunting and little weather.
- **GPU time is unchanged** (4.52 / 4.73 ms THAW / RIME, before and after). GPUParticles moved the snow off the main thread without a measurable GPU cost.
- **VRAM:** unchanged by this branch. It is 276–667 MB at q0/q1 and 936–989 MB at q2 in every area: the q2 buffers (SDFGI cascades, SSR, SSIL) add about 500 MB whatever the area. Thornwold's new texture sets and Tripo trees bring it to 432–454 MB at q0/q1, well inside budget.
- **Physics** (`move_and_slide` of hunting foes) is unchanged and is now the largest CPU item in RIME at the halls.

### The "q2 SDFGI hitch" at the Saltfell hall is not SDFGI

- The one 33.8 ms frame at `hall_veil` RIME q2 appears before and after the branch, and only at q2.
- GPU time is flat at 6.15 ms through it. **Physics** is what moves: 2.6–12.3 ms per frame across four runs of the same view.
- With 8 s of extra settle (`--perf-settle=8`) the hitch is gone in both runs (1% low 25 → 68–136 FPS). The pack in the hall is still converging on the pinned Bearer when sampling starts, and q2's slower load shifts that into the sample window.
- **So the hitch is the hall pack crowding (foe-on-foe collision in `move_and_slide`), not a render cost.** A fix touches how foes crowd (e.g. foe-foe collision off, with nav avoidance doing the spacing), which the feel rule puts to the lead. Not done here.

### Remaining script time (c)

- **Thornwold is the heaviest area** (process 2.5–7.5 ms in both states), but ablation shows it is not script:
  - A census of nodes that process each frame finds only ~50 in the whole area (7 humanoid rigs, 6 enemy visuals, 5 enemies, 4 flames…). Freezing any one class or script (enemies, NPCs, AmbientLife, weather, particles, humanoid_rig, enemy_visual, quad_rig, flame_flicker, player_visual, camera_rig, zone_titles, hedgelayer, hazard_volume, health_bar) moves process time by less than the run-to-run noise.
  - One view dominates: **`hedge_veil`** at **9.3 ms process, 8.0 ms GPU, 9.5 M primitives** (other views: 0.5–1.5 M), whatever is frozen. Process time there is the main thread waiting on the GPU.
  - The triangles are the laid-hedge MultiMesh chunks (~3k tris an instance, 34–49 instances a chunk) and the Tripo birches and pines (~9k tris each), all inside 90 m, times four directional shadow splits.
  - **Recommendation for the art branch:** a `visibility_range_end` on the forest and hedge chunks, shadows off for the hedge chunks past the first split, or an import-time LOD for the hedge mesh. Any one of these should take `hedge_veil` back under 2 M primitives. This is an art call, so it is not done here.

### Before → after, per area, state and tier

| area | state | q | avg FPS | 1% low | GPU ms | CPU ms | script ms | physics ms | draws | VRAM MB | hitches |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| coldwell | rime | 0 | 225 → 252 | 185 → 208 | 3.08 → 3.09 | 4.46 → 4.04 | 2.73 → 2.26 | 1.35 → 1.41 | 276 → 278 | 424 → 426 | 0 → 0 |
| coldwell | rime | 1 | 225 → 246 | 184 → 188 | 3.83 → 3.83 | 4.45 → 3.97 | 2.70 → 2.24 | 1.35 → 1.33 | 276 → 278 | 446 → 447 | 0 → 0 |
| coldwell | rime | 2 | 201 → 204 | 176 → 184 | 4.86 → 4.86 | 4.66 → 4.19 | 2.87 → 2.41 | 1.29 → 1.30 | 276 → 277 | 942 → 944 | 0 → 0 |
| coldwell | thaw | 0 | 304 → 301 | 252 → 255 | 3.03 → 3.03 | 3.18 → 3.25 | 2.21 → 2.24 | 0.63 → 0.66 | 277 → 277 | 424 → 425 | 0 → 0 |
| coldwell | thaw | 1 | 259 → 262 | 229 → 231 | 3.84 → 3.80 | 3.16 → 3.10 | 2.14 → 2.12 | 0.66 → 0.62 | 277 → 276 | 446 → 446 | 0 → 0 |
| coldwell | thaw | 2 | 206 → 205 | 187 → 182 | 4.84 → 4.85 | 3.53 → 3.43 | 2.42 → 2.32 | 0.65 → 0.66 | 277 → 277 | 942 → 943 | 0 → 0 |
| kettle_fjord | rime | 0 | 210 → 218 | 165 → 180 | 3.18 → 3.08 | 4.82 → 4.58 | 2.76 → 2.51 | 1.52 → 1.53 | 663 → 667 | 470 → 472 | 0 → 0 |
| kettle_fjord | rime | 1 | 186 → 202 | 129 → 162 | 4.27 → 4.30 | 5.36 → 4.89 | 3.16 → 2.74 | 1.62 → 1.59 | 665 → 667 | 491 → 494 | 0 → 0 |
| kettle_fjord | rime | 2 | 152 → 171 | 123 → 140 | 4.99 → 5.02 | 6.71 → 5.69 | 4.46 → 3.60 | 1.57 → 1.44 | 666 → 667 | 986 → 989 | 0 → 0 |
| kettle_fjord | thaw | 0 | 252 → 257 | 199 → 189 | 2.69 → 2.65 | 4.00 → 3.93 | 2.65 → 2.54 | 0.85 → 0.88 | 622 → 621 | 470 → 472 | 0 → 0 |
| kettle_fjord | thaw | 1 | 241 → 251 | 203 → 215 | 3.94 → 3.93 | 3.96 → 3.76 | 2.63 → 2.42 | 0.80 → 0.81 | 620 → 619 | 491 → 493 | 0 → 0 |
| kettle_fjord | thaw | 2 | 187 → 190 | 144 → 160 | 4.89 → 4.91 | 4.87 → 4.70 | 3.32 → 3.21 | 0.93 → 0.85 | 627 → 622 | 986 → 989 | 0 → 0 |
| lowe_barrows | rime | 0 | 190 → 216 | 146 → 181 | 4.15 → 4.22 | 5.27 → 4.48 | 2.86 → 2.17 | 1.97 → 1.90 | 391 → 389 | 425 → 426 | 0 → 0 |
| lowe_barrows | rime | 1 | 172 → 175 | 140 → 143 | 4.90 → 4.86 | 5.87 → 5.64 | 3.51 → 3.29 | 1.91 → 1.89 | 389 → 389 | 446 → 447 | 0 → 0 |
| lowe_barrows | rime | 2 | 141 → 139 | 116 → 118 | 5.09 → 5.06 | 7.20 → 7.29 | 4.72 → 4.76 | 1.93 → 1.96 | 387 → 391 | 944 → 945 | 0 → 0 |
| lowe_barrows | thaw | 0 | 244 → 243 | 208 → 202 | 4.12 → 4.12 | 3.47 → 3.48 | 2.18 → 2.18 | 0.91 → 0.92 | 373 → 373 | 425 → 423 | 0 → 0 |
| lowe_barrows | thaw | 1 | 201 → 204 | 166 → 175 | 4.85 → 4.77 | 4.13 → 3.84 | 2.73 → 2.52 | 0.97 → 0.92 | 375 → 375 | 446 → 444 | 0 → 0 |
| lowe_barrows | thaw | 2 | 180 → 179 | 146 → 144 | 5.04 → 5.07 | 5.18 → 5.01 | 3.75 → 3.62 | 0.92 → 0.89 | 375 → 373 | 944 → 942 | 0 → 0 |
| saltfell_steading | rime | 0 | 131 → 162 | 94 → 128 | 4.15 → 4.15 | 8.77 → 7.03 | 4.99 → 3.84 | 3.28 → 2.70 | 437 → 438 | 453 → 455 | 0 → 0 |
| saltfell_steading | rime | 1 | 140 → 148 | 101 → 123 | 4.86 → 4.90 | 7.92 → 7.69 | 4.23 → 3.99 | 3.18 → 3.19 | 435 → 436 | 475 → 476 | 0 → 0 |
| saltfell_steading | rime | 2 | 122 → 119 | 80 → 87 | 5.40 → 5.40 | 8.78 → 8.89 | 4.81 → 4.77 | 3.37 → 3.50 | 436 → 436 | 971 → 972 | 1 → 1 |
| saltfell_steading | thaw | 0 | 230 → 240 | 191 → 192 | 4.15 → 4.15 | 4.33 → 3.99 | 3.10 → 2.78 | 0.80 → 0.79 | 444 → 442 | 453 → 456 | 0 → 0 |
| saltfell_steading | thaw | 1 | 205 → 207 | 157 → 172 | 4.87 → 4.84 | 3.52 → 3.36 | 2.26 → 2.10 | 0.81 → 0.81 | 444 → 444 | 475 → 477 | 0 → 0 |
| saltfell_steading | thaw | 2 | 179 → 184 | 156 → 166 | 5.37 → 5.40 | 4.44 → 4.07 | 3.04 → 2.80 | 0.85 → 0.73 | 444 → 443 | 971 → 973 | 0 → 0 |
| shepherds_reach | rime | 0 | 178 → 187 | 151 → 154 | 3.46 → 3.48 | 5.82 → 5.50 | 3.10 → 2.81 | 2.01 → 1.96 | 1104 → 1105 | 419 → 420 | 0 → 0 |
| shepherds_reach | rime | 1 | 166 → 181 | 134 → 150 | 4.20 → 4.20 | 6.50 → 5.75 | 3.78 → 3.14 | 1.97 → 1.88 | 1104 → 1104 | 440 → 441 | 0 → 0 |
| shepherds_reach | rime | 2 | 138 → 143 | 94 → 113 | 4.71 → 4.94 | 7.78 → 7.43 | 4.20 → 3.86 | 2.72 → 2.73 | 1104 → 1104 | 936 → 937 | 1 → 0 |
| shepherds_reach | thaw | 0 | 245 → 257 | 215 → 235 | 3.41 → 3.44 | 3.82 → 3.73 | 2.63 → 2.52 | 0.64 → 0.65 | 754 → 753 | 419 → 419 | 0 → 0 |
| shepherds_reach | thaw | 1 | 225 → 233 | 188 → 212 | 4.17 → 4.20 | 4.17 → 3.78 | 2.93 → 2.58 | 0.68 → 0.64 | 755 → 755 | 440 → 440 | 0 → 0 |
| shepherds_reach | thaw | 2 | 191 → 192 | 109 → 163 | 4.91 → 4.90 | 4.49 → 4.58 | 3.11 → 3.20 | 0.73 → 0.71 | 753 → 754 | 936 → 936 | 0 → 0 |
| tarnhall | rime | 0 | 151 → 171 | 116 → 129 | 3.39 → 3.37 | 7.90 → 6.21 | 4.16 → 2.53 | 3.23 → 3.15 | 533 → 532 | 455 → 455 | 0 → 0 |
| tarnhall | rime | 1 | 157 → 168 | 125 → 130 | 3.95 → 4.19 | 6.71 → 6.47 | 3.01 → 2.80 | 3.15 → 3.12 | 533 → 532 | 477 → 477 | 0 → 0 |
| tarnhall | rime | 2 | 116 → 130 | 96 → 105 | 4.97 → 4.90 | 11.46 → 9.55 | 6.16 → 4.21 | 4.66 → 4.70 | 532 → 531 | 974 → 975 | 1 → 1 |
| tarnhall | thaw | 0 | 247 → 260 | 187 → 227 | 3.27 → 3.25 | 3.95 → 3.78 | 2.69 → 2.50 | 0.72 → 0.76 | 679 → 679 | 455 → 455 | 0 → 0 |
| tarnhall | thaw | 1 | 226 → 230 | 168 → 192 | 4.13 → 4.16 | 3.89 → 3.92 | 2.58 → 2.60 | 0.75 → 0.76 | 679 → 677 | 477 → 477 | 0 → 0 |
| tarnhall | thaw | 2 | 195 → 194 | 138 → 161 | 4.89 → 4.92 | 4.59 → 4.50 | 3.19 → 3.14 | 0.76 → 0.72 | 678 → 675 | 974 → 975 | 0 → 0 |
| thornwold | rime | 0 | 139 → 137 | 117 → 110 | 6.59 → 6.58 | 7.71 → 7.78 | 5.71 → 5.78 | 1.45 → 1.44 | 650 → 650 | 432 → 432 | 0 → 0 |
| thornwold | rime | 1 | 123 → 120 | 102 → 98 | 7.11 → 7.13 | 8.74 → 8.88 | 6.72 → 6.87 | 1.45 → 1.45 | 651 → 650 | 454 → 454 | 0 → 0 |
| thornwold | rime | 2 | 121 → 123 | 105 → 110 | 7.68 → 7.68 | 9.59 → 9.29 | 7.55 → 7.25 | 1.37 → 1.36 | 650 → 650 | 950 → 950 | 0 → 0 |
| thornwold | thaw | 0 | 182 → 177 | 151 → 154 | 5.55 → 5.54 | 3.96 → 4.41 | 2.62 → 2.98 | 0.82 → 0.89 | 650 → 650 | 432 → 432 | 0 → 0 |
| thornwold | thaw | 1 | 154 → 149 | 131 → 129 | 6.12 → 6.12 | 5.59 → 6.01 | 4.21 → 4.56 | 0.83 → 0.87 | 650 → 651 | 454 → 454 | 0 → 0 |
| thornwold | thaw | 2 | 144 → 149 | 115 → 122 | 6.60 → 6.57 | 6.08 → 6.23 | 4.60 → 4.71 | 0.84 → 0.84 | 651 → 649 | 950 → 950 | 0 → 0 |

### Reproduce

```
GODOT=… TAG=after OUT=build/perf/after AREAS="saltfell_steading lowe_barrows kettle_fjord tarnhall thornwold shepherds_reach coldwell" tools/perf_tour.sh
python3 tools/perf_report.py build/perf/after
# pricing: --perf-ablate=script:humanoid_rig   census: --perf-census --perf-census-at=426.7,40.6,-327.6,90
```

---

## Job 1 (2026-11-07): first profile

_Measured 2026-11-07 on the owner's PC by the local GPU worker. Branch `gpu/perf`._

### Machine

**AMD Radeon RX 9070 XT** (1.4.359) · 12th Gen Intel(R) Core(TM) i9-12900K · Windows 10.0.19045 · 1920x1080 · cap 120, 5s per view

- **GPU:** AMD Radeon RX 9070 XT, Vulkan 1.4.359. Godot picks it as device #0 over the Intel UHD 770 iGPU.
- **CPU:** Intel Core i9-12900K (8P + 8E cores).
- **RAM:** 32 GB.
- **OS:** Windows 10 Home 22H2 (build 19045).
- **Engine:** Godot 4.7.2 stable (official), Forward+, 1920×1080 windowed.

### Method

- **Runs:** `tools/perf_tour.sh` runs `src/debug/perf_tour.gd` (sandbox `perf_tour`) once per area × state × quality tier: 3 × 2 × 3 = 18 runs.
- **Viewpoints** come from each area's JSON, so new areas need no code:
  - `start`
  - up to three built hearths, with the camera looking out from the stone. The flag-gated Long Hearth is skipped.
  - the first frost veil, seen from 10 m out
  - a high `overview` over the whole nav box, which is the worst case for draws
- **Camera:** the Bearer is pinned at each viewpoint and made unhurtable, so the real spring-arm camera frames it. RIME foes still see the Bearer and come for it, which is realistic load.
- **Sampling:** 5 s per view, after a settle of 2 s (4 s on the first view of a run).
- **Frame cap:** the runs were capped at 120 FPS so the owner's PC kept headroom. The FPS columns are therefore **uncapped-equivalent**: per frame, 1000 / max(CPU ms, GPU ms).
  - **GPU ms** is the viewport GPU time measured by `RenderingServer`. Under the cap the GPU clocks down, so it errs high.
  - **CPU ms** is main-thread time: script process + physics process + render submission. Physics is counted every frame, so it errs high too.
  - **1% low** is the 99th-percentile frame cost.
  - **Hitches** are wall-clock frames over 33 ms; they still show under the cap.
- **Reproduce:** `GODOT=… TAG=mine tools/perf_tour.sh`, then `python3 tools/perf_report.py build/perf/mine`. It needs a real display and GPU, not xvfb.
- **CPU noise:** CPU numbers vary by about ±30% between runs on this machine. The likely cause is Windows 10 putting a below-normal-priority process on the 12900K's E-cores. Compare within a run, not across runs. GPU and VRAM numbers repeat to within a few percent.

### Headline

1. **The GPU is nowhere near the limit.**
   - Every viewpoint, at every tier, costs 1.3–3.5 ms of GPU time on this card.
   - Going from quality 0 to 1 (SSAO, ACES, sky radiance) adds about 0.4 ms. Going from 1 to 2 (SSIL, SSR, SDFGI) adds about 1.3 ms.
   - Draw calls (140–1,016) and primitives (0.3–2.7 M) are modest.
2. **The CPU sets the frame rate, and RIME enemies are most of it.** Ablation on Saltfell RIME q1 (`--perf-ablate`):
   - Freezing every `Enemy` drops physics time from 3–5 ms to about 0.7 ms per frame, roughly 0.2–0.3 ms per foe.
   - Freezing all CPU particles saves about 0.7 ms.
   - Freezing `AmbientLife` saves nothing measurable.
   - The cost is in foes that are *hunting*, not idle ones. Skipping idle foes' `move_and_slide` and fist sync saved at most about 1 ms, and nothing at the hall, where the pack is chasing. That experiment was reverted and is not committed.
3. **VRAM was 2.5× what it needed to be.**
   - All 240 textures extracted from the Tripo GLBs were imported **Lossless**.
   - Their `.import` files are generated locally and got the importer's "detect 3D" default, which only switches to VRAM compression inside an interactive editor.
   - So CI, headless imports and **exports** shipped raw RGBA 2048² maps. This is fixed; see below.

### Results (after the fix)

#### Quality 0

| area | state | view | avg FPS | 1% low | GPU ms | CPU ms | draws | prims (k) | VRAM MB | hitches |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| kettle_fjord | rime | start | 170 | 108 | 1.24 | 5.88 | 489 | 711 | 258 | 0 |
| kettle_fjord | rime | hs_landing_ice | 206 | 192 | 1.27 | 4.86 | 212 | 552 | 258 | 0 |
| kettle_fjord | rime | hs_fish_houses | 199 | 171 | 1.43 | 5.03 | 840 | 1160 | 258 | 0 |
| kettle_fjord | rime | breathing_hole_veil | 185 | 173 | 1.33 | 5.41 | 530 | 995 | 258 | 0 |
| kettle_fjord | rime | overview | 181 | 168 | 1.32 | 5.53 | 542 | 552 | 258 | 0 |
| kettle_fjord | thaw | start | 229 | 120 | 1.27 | 4.37 | 505 | 513 | 260 | 1 |
| kettle_fjord | thaw | hs_landing_ice | 364 | 335 | 1.17 | 2.75 | 171 | 385 | 260 | 0 |
| kettle_fjord | thaw | hs_fish_houses | 289 | 256 | 1.26 | 3.46 | 596 | 486 | 260 | 0 |
| kettle_fjord | thaw | breathing_hole_veil | 284 | 253 | 1.29 | 3.52 | 798 | 727 | 260 | 0 |
| kettle_fjord | thaw | overview | 286 | 258 | 1.26 | 3.50 | 553 | 334 | 260 | 0 |
| lowe_barrows | rime | start | 188 | 113 | 1.30 | 5.32 | 455 | 1117 | 292 | 0 |
| lowe_barrows | rime | hs_barrow_road | 170 | 153 | 1.49 | 5.90 | 403 | 1640 | 292 | 0 |
| lowe_barrows | rime | hs_drying_stacks | 161 | 151 | 1.44 | 6.20 | 379 | 1641 | 292 | 0 |
| lowe_barrows | rime | open_barrow_veil | 183 | 161 | 1.41 | 5.47 | 344 | 1428 | 292 | 0 |
| lowe_barrows | rime | overview | 179 | 163 | 1.25 | 5.60 | 292 | 758 | 292 | 0 |
| lowe_barrows | thaw | start | 278 | 150 | 1.45 | 3.60 | 403 | 834 | 292 | 0 |
| lowe_barrows | thaw | hs_barrow_road | 275 | 245 | 1.63 | 3.64 | 339 | 1220 | 292 | 0 |
| lowe_barrows | thaw | hs_drying_stacks | 262 | 240 | 1.65 | 3.82 | 364 | 1635 | 292 | 0 |
| lowe_barrows | thaw | open_barrow_veil | 296 | 259 | 1.58 | 3.38 | 454 | 1520 | 292 | 0 |
| lowe_barrows | thaw | overview | 318 | 293 | 1.31 | 3.15 | 239 | 518 | 292 | 0 |
| saltfell_steading | rime | start | 188 | 178 | 1.28 | 5.33 | 341 | 800 | 284 | 0 |
| saltfell_steading | rime | hs_boat_shed | 183 | 151 | 1.29 | 5.47 | 138 | 678 | 284 | 0 |
| saltfell_steading | rime | hs_salt_house | 134 | 127 | 1.47 | 7.47 | 589 | 1647 | 284 | 0 |
| saltfell_steading | rime | hall_veil | 138 | 85 | 1.82 | 7.24 | 727 | 2670 | 284 | 0 |
| saltfell_steading | rime | overview | 166 | 136 | 1.39 | 6.04 | 604 | 709 | 284 | 0 |
| saltfell_steading | thaw | start | 241 | 134 | 1.16 | 4.14 | 346 | 661 | 284 | 0 |
| saltfell_steading | thaw | hs_boat_shed | 308 | 231 | 1.18 | 3.24 | 139 | 562 | 284 | 0 |
| saltfell_steading | thaw | hs_salt_house | 252 | 207 | 1.41 | 3.97 | 586 | 1453 | 284 | 0 |
| saltfell_steading | thaw | hall_veil | 233 | 192 | 1.69 | 4.29 | 1016 | 2314 | 284 | 0 |
| saltfell_steading | thaw | overview | 267 | 237 | 1.28 | 3.75 | 580 | 422 | 284 | 0 |

#### Quality 1

| area | state | view | avg FPS | 1% low | GPU ms | CPU ms | draws | prims (k) | VRAM MB | hitches |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| kettle_fjord | rime | start | 167 | 107 | 1.74 | 5.99 | 490 | 711 | 279 | 0 |
| kettle_fjord | rime | hs_landing_ice | 227 | 196 | 1.71 | 4.40 | 212 | 552 | 279 | 0 |
| kettle_fjord | rime | hs_fish_houses | 184 | 164 | 2.02 | 5.45 | 846 | 1160 | 279 | 0 |
| kettle_fjord | rime | breathing_hole_veil | 173 | 148 | 1.77 | 5.77 | 535 | 995 | 279 | 0 |
| kettle_fjord | rime | overview | 182 | 167 | 1.69 | 5.51 | 542 | 552 | 279 | 0 |
| kettle_fjord | thaw | start | 250 | 134 | 1.72 | 4.00 | 466 | 518 | 279 | 0 |
| kettle_fjord | thaw | hs_landing_ice | 321 | 283 | 1.63 | 3.11 | 175 | 391 | 279 | 0 |
| kettle_fjord | thaw | hs_fish_houses | 300 | 269 | 1.81 | 3.33 | 475 | 485 | 279 | 0 |
| kettle_fjord | thaw | breathing_hole_veil | 290 | 259 | 1.65 | 3.45 | 652 | 715 | 279 | 0 |
| kettle_fjord | thaw | overview | 288 | 258 | 1.66 | 3.48 | 553 | 334 | 279 | 0 |
| lowe_barrows | rime | start | 190 | 114 | 1.73 | 5.27 | 455 | 1117 | 313 | 0 |
| lowe_barrows | rime | hs_barrow_road | 180 | 154 | 1.96 | 5.56 | 403 | 1640 | 313 | 0 |
| lowe_barrows | rime | hs_drying_stacks | 160 | 150 | 1.93 | 6.26 | 378 | 1641 | 313 | 0 |
| lowe_barrows | rime | open_barrow_veil | 186 | 169 | 1.92 | 5.39 | 347 | 1428 | 313 | 0 |
| lowe_barrows | rime | overview | 202 | 165 | 1.73 | 4.95 | 292 | 758 | 313 | 0 |
| lowe_barrows | thaw | start | 275 | 147 | 1.78 | 3.63 | 403 | 834 | 313 | 0 |
| lowe_barrows | thaw | hs_barrow_road | 274 | 240 | 2.00 | 3.65 | 339 | 1220 | 313 | 0 |
| lowe_barrows | thaw | hs_drying_stacks | 261 | 241 | 2.01 | 3.83 | 367 | 1636 | 313 | 0 |
| lowe_barrows | thaw | open_barrow_veil | 277 | 201 | 2.00 | 3.61 | 457 | 1520 | 313 | 0 |
| lowe_barrows | thaw | overview | 313 | 282 | 1.64 | 3.19 | 239 | 518 | 313 | 0 |
| saltfell_steading | rime | start | 205 | 178 | 1.55 | 4.89 | 341 | 800 | 305 | 0 |
| saltfell_steading | rime | hs_boat_shed | 195 | 143 | 1.54 | 5.13 | 138 | 678 | 305 | 0 |
| saltfell_steading | rime | hs_salt_house | 135 | 126 | 1.79 | 7.38 | 587 | 1647 | 305 | 0 |
| saltfell_steading | rime | hall_veil | 109 | 79 | 2.26 | 9.19 | 727 | 2670 | 305 | 0 |
| saltfell_steading | rime | overview | 149 | 89 | 1.83 | 6.71 | 604 | 709 | 305 | 0 |
| saltfell_steading | thaw | start | 238 | 131 | 1.52 | 4.20 | 346 | 661 | 305 | 0 |
| saltfell_steading | thaw | hs_boat_shed | 337 | 319 | 1.52 | 2.97 | 139 | 562 | 305 | 0 |
| saltfell_steading | thaw | hs_salt_house | 224 | 156 | 1.89 | 4.46 | 582 | 1453 | 305 | 0 |
| saltfell_steading | thaw | hall_veil | 253 | 235 | 2.24 | 3.95 | 1016 | 2314 | 305 | 0 |
| saltfell_steading | thaw | overview | 273 | 253 | 1.77 | 3.66 | 580 | 422 | 305 | 0 |

#### Quality 2

| area | state | view | avg FPS | 1% low | GPU ms | CPU ms | draws | prims (k) | VRAM MB | hitches |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| kettle_fjord | rime | start | 172 | 105 | 2.91 | 5.82 | 490 | 711 | 773 | 0 |
| kettle_fjord | rime | hs_landing_ice | 212 | 176 | 3.14 | 4.71 | 212 | 552 | 775 | 0 |
| kettle_fjord | rime | hs_fish_houses | 163 | 149 | 3.34 | 6.13 | 840 | 1160 | 775 | 0 |
| kettle_fjord | rime | breathing_hole_veil | 171 | 158 | 3.16 | 5.83 | 531 | 995 | 775 | 0 |
| kettle_fjord | rime | overview | 169 | 132 | 3.03 | 5.92 | 542 | 552 | 775 | 0 |
| kettle_fjord | thaw | start | 227 | 127 | 2.90 | 4.40 | 466 | 518 | 773 | 0 |
| kettle_fjord | thaw | hs_landing_ice | 294 | 263 | 3.26 | 3.36 | 175 | 391 | 775 | 0 |
| kettle_fjord | thaw | hs_fish_houses | 273 | 243 | 3.17 | 3.65 | 475 | 485 | 775 | 0 |
| kettle_fjord | thaw | breathing_hole_veil | 271 | 230 | 3.14 | 3.66 | 652 | 715 | 775 | 0 |
| kettle_fjord | thaw | overview | 252 | 220 | 2.92 | 3.97 | 553 | 334 | 775 | 0 |
| lowe_barrows | rime | start | 177 | 110 | 2.90 | 5.64 | 455 | 1117 | 808 | 0 |
| lowe_barrows | rime | hs_barrow_road | 178 | 144 | 3.20 | 5.62 | 403 | 1640 | 811 | 0 |
| lowe_barrows | rime | hs_drying_stacks | 149 | 119 | 3.15 | 6.69 | 375 | 1640 | 811 | 0 |
| lowe_barrows | rime | open_barrow_veil | 168 | 154 | 3.19 | 5.94 | 347 | 1428 | 813 | 0 |
| lowe_barrows | rime | overview | 188 | 157 | 2.83 | 5.32 | 292 | 758 | 813 | 0 |
| lowe_barrows | thaw | start | 236 | 142 | 2.95 | 4.23 | 403 | 834 | 808 | 0 |
| lowe_barrows | thaw | hs_barrow_road | 231 | 200 | 3.31 | 4.33 | 339 | 1220 | 811 | 0 |
| lowe_barrows | thaw | hs_drying_stacks | 230 | 190 | 3.20 | 4.36 | 363 | 1635 | 811 | 0 |
| lowe_barrows | thaw | open_barrow_veil | 251 | 218 | 3.25 | 3.98 | 451 | 1520 | 813 | 0 |
| lowe_barrows | thaw | overview | 270 | 240 | 2.73 | 3.71 | 239 | 518 | 813 | 0 |
| saltfell_steading | rime | start | 189 | 112 | 2.80 | 5.30 | 341 | 800 | 799 | 0 |
| saltfell_steading | rime | hs_boat_shed | 171 | 136 | 2.81 | 5.86 | 138 | 678 | 801 | 0 |
| saltfell_steading | rime | hs_salt_house | 126 | 97 | 2.93 | 7.96 | 594 | 1647 | 801 | 0 |
| saltfell_steading | rime | hall_veil | 86 | 31 | 3.43 | 11.59 | 727 | 2670 | 803 | 1 |
| saltfell_steading | rime | overview | 171 | 141 | 2.97 | 5.85 | 604 | 709 | 803 | 0 |
| saltfell_steading | thaw | start | 289 | 269 | 2.83 | 3.46 | 345 | 661 | 799 | 0 |
| saltfell_steading | thaw | hs_boat_shed | 262 | 207 | 2.84 | 3.82 | 139 | 562 | 801 | 0 |
| saltfell_steading | thaw | hs_salt_house | 232 | 160 | 3.02 | 4.31 | 602 | 1454 | 801 | 0 |
| saltfell_steading | thaw | hall_veil | 231 | 210 | 3.53 | 4.33 | 1016 | 2314 | 803 | 0 |
| saltfell_steading | thaw | overview | 217 | 157 | 2.92 | 4.62 | 580 | 422 | 803 | 0 |

#### Worst 5 views (quality 1, by 1% low)

| area | state | view | avg FPS | 1% low | GPU ms | CPU ms | draws | prims (k) | VRAM MB | hitches |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| saltfell_steading | rime | hall_veil | 109 | 79 | 2.26 | 9.19 | 727 | 2670 | 305 | 0 |
| saltfell_steading | rime | overview | 149 | 89 | 1.83 | 6.71 | 604 | 709 | 305 | 0 |
| kettle_fjord | rime | start | 167 | 107 | 1.74 | 5.99 | 490 | 711 | 279 | 0 |
| lowe_barrows | rime | start | 190 | 114 | 1.73 | 5.27 | 455 | 1117 | 313 | 0 |
| saltfell_steading | rime | hs_salt_house | 135 | 126 | 1.79 | 7.38 | 587 | 1647 | 305 | 0 |

### The 5 worst viewpoints (quality 1)

| # | View | Cost | Likely cause |
|---|---|---|---|
| 1 | Saltfell RIME `hall_veil` | CPU 9.2 ms (12.4 ms in the baseline run), 1% low 79 FPS. 2.67 M prims, the most of any view. At q2, one or two wall-clock hitches over 33 ms in both runs. | **Enemy AI and physics.** The hall pack (Hearthhound plus Rimewalkers) is in pursuit, and physics alone is about 5 ms. The prims are the Tripo longhouse and the hall interior, but GPU time is still only 2.3 ms. The q2-only hitch is most likely the **SDFGI** cascade rebuilding after the camera jump. |
| 2 | Saltfell RIME `overview` | CPU 6.7 ms, 1% low 89 FPS | The same pack. The free camera leaves the Bearer at the hall, so foes keep chasing. Only 604 draws, so again CPU, not GPU. |
| 3 | Kettle RIME `start` | 1% low 107 FPS, average 167 | The **first view of each run**: its tail includes streaming and pipeline warm-up after the 4 s settle, and every area's `start` row shows it. Also the RIME **CPU particles**: snow 900 + 160, plus spindrift 14 × 90 per area. |
| 4 | Lowe RIME `start` | 1% low 114 FPS | Same as #3. |
| 5 | Saltfell RIME `hs_salt_house` | CPU 7.4 ms | Foes on the yard aggro. 1.65 M prims. |

On this GPU, none of the worst views is limited by grass density, shadows, volumetric fog or texture size.

### Fixes on `gpu/perf`, with before/after

### `project.godot` `[importer_defaults] texture`: VRAM compressed, detect-3D off

- Committed `.import` files are untouched. The 23 UI icons stay Lossless, and the fonts are unchanged.
- Verified on a fresh copy: all 240 maps import as S3TC/BPTC, and the `.scn` files reference them.
- The alternative, committing the `.jpg.import` files, was tried and **rejected**. On a fresh clone Godot then skips extraction and embeds raw textures in each `.scn` (2.3 MB instead of 92 KB for the drying rack).
- **Existing checkouts must migrate once:** `python3 tools/art/texture_imports.py && godot --headless --path . --import`. Add `--check` to audit a checkout.

| area | quality | VRAM before (MB) | VRAM after (MB) | GPU ms before | GPU ms after |
|---|---:|---:|---:|---:|---:|
| saltfell_steading | 0 | 729 | 284 | 1.44 | 1.40 |
| saltfell_steading | 1 | 750 | 305 | 1.80 | 1.79 |
| saltfell_steading | 2 | 1247 | 803 | 3.02 | 3.01 |
| lowe_barrows | 0 | 807 | 292 | 1.51 | 1.45 |
| lowe_barrows | 1 | 828 | 313 | 1.89 | 1.87 |
| lowe_barrows | 2 | 1335 | 813 | 3.13 | 3.07 |
| kettle_fjord | 0 | 590 | 260 | 1.35 | 1.28 |
| kettle_fjord | 1 | 612 | 279 | 1.86 | 1.74 |
| kettle_fjord | 2 | 1107 | 775 | 3.10 | 3.10 |

- **VRAM:** 59–62% less at q0 and q1. At q2 the cut is 33–40%, because the SDFGI and SSIL buffers dominate there.
- **GPU time:** unchanged within noise.
- **CPU time:** the after-tables show lower CPU for Saltfell and Lowe than the baseline. That is run-to-run variance (see Method), not this fix: Kettle, measured in a separate run, did not move.
- **Look:** before/after thumbnails at 480 px are indistinguishable. A close-up check for BC artefacts on hero masks and faces belongs in Job 2's gallery.

### Deliberately not changed

Shadow distance, per-tier grass density and visibility ranges all save GPU time, and the GPU has 5–10× headroom here. Changing them would cost some of the look for no measurable gain.

### Against the target: 60 FPS at 1080p, quality 1, on a mid-range PC

- **GPU:** the worst q1 view costs 2.3 ms. A mid-range card (RX 7600 or RTX 4060 class, roughly a third of this one) should land around 7 ms, well inside 16.7 ms. q2 would land around 11 ms there.
- **CPU:** this is the risk. The worst q1 view costs 9–12 ms on a 12900K. A mid-range CPU (Ryzen 5 5600 or i5-12400) is perhaps 15–30% slower per thread, which puts it at about 11–16 ms. That only just makes 60 FPS with a full pack chasing at the hall, with little margin for bigger fights or the boss arenas.

### Recommendations for the lead

These are not done here, because they touch 1:1 systems.

1. **Throttle enemy re-pathing.**
   - `enemy.gd:314` sets `agent.target_position` on every physics tick while approaching, which can make `NavigationAgent3D` re-query its path every tick.
   - Update it only when the target has moved more than about 0.5 m, or at most every 0.15–0.2 s. That reaction-time change is smaller than the data-driven windups.
   - Measure it at Saltfell RIME `hall_veil` with `tools/perf_tour.sh` (`AREAS=saltfell_steading STATES=rime QUALS=1`).
2. **Move the weather to `GPUParticles3D`.**
   - The RIME snow, glitter and spindrift, and the THAW pollen and gulls, are about 2,300 CPU-simulated particles, costing about 0.7 ms of main-thread time.
   - `GPUParticles3D.convert_from_particles()` keeps the current authoring, but it needs a look check.
3. **Profile the remaining script time before tier 3.** With everything frozen, about 2–3 ms is left. Use the editor profiler on the player, HUD, AnimationTrees and audio.
4. **SDFGI hitch at q2:** if the hitch at the hall shows up in real play, tune the cascades or `sdfgi_y_scale`. Otherwise list it as a known issue.
