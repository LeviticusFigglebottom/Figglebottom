# GPU performance profile (Job 1)

_Measured 2026-11-07 on the owner's PC by the local GPU worker. Branch `gpu/perf`._

## Machine

**AMD Radeon RX 9070 XT** (1.4.359) · 12th Gen Intel(R) Core(TM) i9-12900K · Windows 10.0.19045 · 1920x1080 · cap 120, 5s per view

- **GPU:** AMD Radeon RX 9070 XT, Vulkan 1.4.359. Godot picks it as device #0 over the Intel UHD 770 iGPU.
- **CPU:** Intel Core i9-12900K (8P + 8E cores).
- **RAM:** 32 GB.
- **OS:** Windows 10 Home 22H2 (build 19045).
- **Engine:** Godot 4.7.2 stable (official), Forward+, 1920×1080 windowed.

## Method

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

## Headline

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

## Results (after the fix)

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

## The 5 worst viewpoints (quality 1)

| # | View | Cost | Likely cause |
|---|---|---|---|
| 1 | Saltfell RIME `hall_veil` | CPU 9.2 ms (12.4 ms in the baseline run), 1% low 79 FPS. 2.67 M prims, the most of any view. At q2, one or two wall-clock hitches over 33 ms in both runs. | **Enemy AI and physics.** The hall pack (Hearthhound plus Rimewalkers) is in pursuit, and physics alone is about 5 ms. The prims are the Tripo longhouse and the hall interior, but GPU time is still only 2.3 ms. The q2-only hitch is most likely the **SDFGI** cascade rebuilding after the camera jump. |
| 2 | Saltfell RIME `overview` | CPU 6.7 ms, 1% low 89 FPS | The same pack. The free camera leaves the Bearer at the hall, so foes keep chasing. Only 604 draws, so again CPU, not GPU. |
| 3 | Kettle RIME `start` | 1% low 107 FPS, average 167 | The **first view of each run**: its tail includes streaming and pipeline warm-up after the 4 s settle, and every area's `start` row shows it. Also the RIME **CPU particles**: snow 900 + 160, plus spindrift 14 × 90 per area. |
| 4 | Lowe RIME `start` | 1% low 114 FPS | Same as #3. |
| 5 | Saltfell RIME `hs_salt_house` | CPU 7.4 ms | Foes on the yard aggro. 1.65 M prims. |

On this GPU, none of the worst views is limited by grass density, shadows, volumetric fog or texture size.

## Fixes on `gpu/perf`, with before/after

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

## Against the target: 60 FPS at 1080p, quality 1, on a mid-range PC

- **GPU:** the worst q1 view costs 2.3 ms. A mid-range card (RX 7600 or RTX 4060 class, roughly a third of this one) should land around 7 ms, well inside 16.7 ms. q2 would land around 11 ms there.
- **CPU:** this is the risk. The worst q1 view costs 9–12 ms on a 12900K. A mid-range CPU (Ryzen 5 5600 or i5-12400) is perhaps 15–30% slower per thread, which puts it at about 11–16 ms. That only just makes 60 FPS with a full pack chasing at the hall, with little margin for bigger fights or the boss arenas.

## Recommendations for the lead

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
