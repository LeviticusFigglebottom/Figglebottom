# Perf regression after Job 4: found and fixed (gpu/perf-fix)

_2026-11-12, RX 9070 XT, i9-12900K, Windows 10, 1920x1080, quality 1, cap 120, 5 s per view, `tools/perf_tour.sh`. One Godot process at a time, window off-screen, below-normal priority. Every tree was checked as fully imported first (0 of 906 `dest_files` missing, the 1,812 extracted .glb textures present). The owner's Godot editor was open and idle throughout._

## 1. The contention caveat, removed
The morning tour (PERF_GPU.md on gpu/perf) ran beside the gate's walks, so its 2–3× figure mixed two effects. Measured alone and back to back, the picture is this:
- **The Job 4 build (gpu/perf-2, 0000c01) still runs about 210 FPS today** (Saltfell THAW 213 overview / 218 start). The machine is unchanged.
- **Main itself had regressed:** Saltfell THAW 113 FPS at 024ff96. Integration-1112 added only another 5–20% on top, mostly physics in Lowe.

## 2. Bisect: what costs it
Saltfell + Lowe THAW, q1, script ("proc") ms per frame, along main's first-parent merges:

| commit | merge | Saltfell FPS / script ms | Lowe FPS / script ms |
|---|---|---:|---:|
| 77721c1 | gpu/perf-2 (Job 4) | 201 / 3.17 | 210 / 2.95 |
| e3daf04 | merge everything | 176 / 3.99 | 185 / 3.43 |
| fb1b369 | look-pass-5 | 179 / 3.88 | 177 / 3.65 |
| 588951d | fix/qa-regions | 174 / 4.04 | 185 / 3.33 |
| e0d3f9d | art/world-fidelity | 168 / 4.05 | 146 / 4.86 |
| 0f12ada | feat/sfx-redo | 164 / 4.15 | 145 / 4.93 |
| **024ff96** | **feat/ui-map-log-icons** | **115 / 7.31** | **123 / 6.23** |

**Ablation at the integration head** (`--perf-ablate=script:<file>`, Saltfell THAW q1):

| script ablated | FPS | script ms |
|---|---:|---:|
| none | 106 | 7.74 |
| `src/ui/hud.gd` | 166 | 4.05 |
| `src/ui/map_view.gd` | 105 | 7.82 |
| all of `src/ui/` | 173 | 3.81 |

**Cause:**
- `hud.gd` alone costs **about 3.7 ms per frame**.
- Its new tracker calls `_scout()` twice a second: `MapState.scout()` and `refresh_tracker()`, which goes through `Journal.tracker()`.
- `MapState.scout()` called `DB.area_def()` twice and `places_def()` once. Each call **re-reads and JSON-parses the whole area file** (31–186 KB), so that is three full parses per tick.
- The cost grows with file size: Thornwold (186 KB) and the Reach (128 KB) lost the most.

## 3. The fix (ba25af2), with no feel or visual change
- `DB.area_def_ro(id)` parses each area file once and shares it. It is used only by read-only callers: MapState, `Journal.resolve_at`, `Game.toggle_free`. The area builder keeps `area_def()`, a fresh parse it may edit.
- `MapState.places_def()` is built once per area. Its output does not depend on state, because 2295854's board-tag filter is applied separately at scout time.
- The tracker labels are set only when their text changes.
- **Tests:** smoke 11/0, journal_map 74/0, keepsakes 65/0, originality clean.

## 4. Before and after: main a6a45f6 vs gpu/perf-fix ba25af2
q1, every region and both states, interleaved area by area (main, then fix):

| area | state | avg FPS | 1% low | CPU ms | script ms | physics ms | GPU ms |
|---|---|---:|---:|---:|---:|---:|---:|
| coldwell | rime | 117 → 155 | 107 → 131 | 8.54 → 6.52 | 5.03 → 3.01 | 2.94 → 2.94 | 4.28 → 4.29 |
| coldwell | thaw | 155 → 222 | 142 → 195 | 6.48 → 4.15 | 4.89 → 2.58 | 1.06 → 1.03 | 4.31 → 4.29 |
| kettle_fjord | rime | 88 → 149 | 78 → 120 | 11.40 → 6.73 | 8.09 → 3.43 | 2.60 → 2.58 | 4.68 → 4.68 |
| kettle_fjord | thaw | 104 → 215 | 96 → 187 | 9.68 → 4.46 | 7.99 → 2.76 | 1.05 → 1.06 | 4.43 → 4.43 |
| lowe_barrows | rime | 99 → 118 | 84 → 88 | 12.08 → 10.89 | 6.01 → 4.77 | 5.30 → 5.36 | 5.12 → 5.14 |
| lowe_barrows | thaw | 118 → 154 | 101 → 125 | 10.63 → 9.00 | 5.91 → 4.22 | 4.01 → 4.08 | 5.06 → 5.09 |
| saltfell_steading | rime | 86 → 111 | 77 → 91 | 11.94 → 9.59 | 7.99 → 5.64 | 3.09 → 3.10 | 5.02 → 5.00 |
| saltfell_steading | thaw | 110 → 171 | 94 → 132 | 9.40 → 5.84 | 7.52 → 4.05 | 1.09 → 0.99 | 5.04 → 5.01 |
| shepherds_reach | rime | 62 → 101 | 51 → 79 | 16.35 → 10.95 | 11.38 → 5.59 | 4.28 → 4.66 | 4.67 → 4.68 |
| shepherds_reach | thaw | 79 → 184 | 74 → 150 | 12.64 → 5.52 | 10.89 → 3.71 | 1.12 → 1.18 | 4.75 → 4.68 |
| tarnhall | rime | 82 → 127 | 68 → 99 | 12.48 → 8.59 | 7.56 → 3.93 | 4.21 → 3.94 | 4.39 → 4.40 |
| tarnhall | thaw | 104 → 185 | 96 → 147 | 9.75 → 5.50 | 7.87 → 3.59 | 1.00 → 1.03 | 4.30 → 4.26 |
| thornwold | rime | 72 → 135 | 68 → 107 | 13.93 → 7.52 | 11.15 → 4.68 | 1.87 → 1.93 | 5.32 → 5.29 |
| thornwold | thaw | 70 → 166 | 62 → 148 | 14.66 → 5.50 | 12.75 → 3.62 | 1.06 → 1.02 | 5.43 → 5.52 |

Mean over all area/state rows: FPS 96 → 157, script 8.22 → 3.97 ms

GPU time and physics are unchanged, as expected.

## 5. Left: physics in Lowe, measured and not fixed
- **Lowe physics** is 4.0–5.3 ms at q1, against about 1.2 ms before.
- **Bisect over the integration merges** (Lowe THAW physics ms): 024ff96 1.32, 5517104 1.29, f367dee 1.20, **472b1b3 (fix/playtest-1) 3.81**, 781dbbc 3.83, 1c63d9f 3.88, 1b01011 4.15.
- **Ablating** enemies, NPCs, ambient life, particles, hazard volumes, house probes or the bog script does not move it: 3.9–4.2 ms each. The cost is in the physics server, not in scripts.
- **Cause:** fix/playtest-1 gave scatter (rock, boulder, driftwood, peat_stack, standing_stone, ice_floe) a convex hull of each piece's own mesh, `create_convex_shape(true, false)`: the exact hull, 98–292 points per piece. Before, they had primitive spheres and boxes, and small rocks had no collider. A convex shape's contact cost grows with its point count, and Lowe has the most scatter.
- **Tried and reverted:** capping each hull to its 32 or 64 farthest points. That took Lowe physics to 1.2–1.3 ms, but `collision_audit` went from 0 to 6 failures. In Lowe there were 178 new offenders (125 walk_through, mostly peat stacks and boulders), so pieces lost their colliders. That breaks the "what is drawn is what stops you" rule. Not committed.
- **Options, for the scatter and collision owner:**
  - (a) per-kind primitive fits (an oriented box for peat stacks and standing stones, a capsule or sphere for boulders) sized from the mesh AABB, then re-audited;
  - (b) a hull simplifier that keeps volume (decimate, then push the faces out by the error), checked against the audit;
  - (c) a trial of Jolt (`physics/3d/physics_engine`), whose convex collision is much cheaper than Godot Physics. This is project-wide and needs the full gate.

## 6. VRAM, not changed
- The "Tarnhall twice the others" note does not hold in this clean q1 data.
- **About 1.05–1.19 GB:** Tarnhall, Saltfell, Kettle and Coldwell (and the Reach on integration).
- **About 520 MB:** Lowe and Thornwold.
- Two clusters like that look like a rendering feature or buffer that one group of areas switches on, not single large textures. I haven't looked at textures yet, so I made no import changes.
