# Local GPU worker → lead

The local GPU worker (Claude Code on the owner's PC) writes job reports, blockers and questions here, on branch `gpu/inbox`. The newest entry goes at the top. (A message to session `regothiga-e8` failed: the session was not reachable by that name.)

## 2026-11-08: Job 2 done (real-GPU gallery), branch `gpu/gallery`

**Branch:** `gpu/gallery`
- Based on main `adab65a`, in 2 commits. It is independent of `gpu/perf`.
- Originality check: OK.
- `tools/test.sh`: 17 suites, 714 checks. One check is **flaky**: `kettle_encounters` "stepped in close, he stands on whole ice" failed once, then passed in 2 re-runs. It is unrelated to this branch: the only code change is two opt-in `shot.gd` flags that no test uses. It is on main too; worth a look.
- Details are in `docs/qa/GPU_VISUAL_DIFF.md`.

**Gallery**
- `docs/gallery_gpu/`: 36 JPEGs, 18 viewpoints × THAW/RIME at q2, on the RX 9070 XT.
- The cameras are the *exact* `docs/screens` cameras. I read them back from the pose line in the corner of each lavapipe shot.
- **Manifest and runner:** `tools/gallery_gpu.sh`, one process per shot.
- **Same-revision lavapipe pairs:** run `WRAP='xvfb-run -a -s "-screen 0 1920x1080x24"' PNG=build/gallery_lvp JPG=build/gallery_lvp tools/gallery_gpu.sh`. The `docs/screens` references are older revisions, so most differences are content changes, not the renderer.
- **`shot.gd` additions** (opt-in; the defaults are unchanged):
  - `--shot-settle=N`: places the camera N frames before capture, so SDFGI and the fog history can converge on hardware.
  - `--shot-quality=N`: forces the graphics tier.

**Findings**
1. **Look bug: SDFGI kills the water at q2.**
   - All open water loses its sky sheen and reads dark and flat.
   - Turning features off one at a time on the Lowe bog: without SSR or SSIL the water stays dark; **without SDFGI the sheen comes back**. q1 matches lavapipe.
   - Real GPUs auto-select q2, so players see this by default.
   - Evidence: `docs/gallery_gpu/_evidence_water_sdfgi.jpg`.
   - **Options:**
     - **a.** Add a fresnel sky term in `water.gdshader`, fed by EnvRig's sky colours.
     - **b.** Add sky-only ReflectionProbes over the water.
     - **c.** Default real GPUs to q1, with SDFGI opt-in. This also saves about 1.3 ms of GPU.
   - **Decision needed from you (look):** which of these, if any. I have not changed it.
2. **Volumetric fog is much stronger on hardware than on lavapipe.**
   - Distant contrast drops, and soft light shafts appear.
   - At the Kettle breathing hole in THAW the frame blows out toward the low sun: the left third is near white, and the shadowed gorge wall crushes to black.
   - Suggestion: a per-area `vol_density` or lower anisotropy for the deep gorges.
3. **Nothing broken.** No light leaks, fog banding, SSR streaks or missing materials.

**Next**
- Job 3, the playtest, needs the owner at the PC. I'm asking them now.
- `gpu/perf` (Job 1, entry below) is still waiting for review.

## 2026-11-07: Job 1 done (performance profile), branch `gpu/perf`

**Branch:** `gpu/perf`
- 3 commits on `978f141`; it merges cleanly into the current main.
- The full `tools/test.sh` passes locally (13 suites, 604 checks), and the originality check is OK.
- Details and full tables are in `docs/qa/PERF_GPU.md`.

**Machine:** AMD RX 9070 XT · i9-12900K · 32 GB · Windows 10 Home 19045 · Godot 4.7.2 stable · Forward+ · 1080p.

**Findings**
1. **The GPU is not the limit.**
   - Every viewpoint, in all 3 areas, both states and all 3 tiers, costs 1.3–3.5 ms of GPU time.
   - Going from q0 to q1 adds about 0.4 ms; going from q1 to q2 adds about 1.3 ms.
2. **The CPU sets the frame rate, and hunting RIME foes are most of it.**
   - Freezing every `Enemy` cuts physics time from 3–5 ms to 0.7 ms, about 0.2–0.3 ms per foe.
   - CPU particles cost about 0.7 ms.
   - The worst view is Saltfell RIME `hall_veil`, at 9–12 ms of CPU on the 12900K. That leaves little margin for 60 FPS on a mid-range CPU.
3. **VRAM bug, fixed.**
   - All 240 textures extracted from the Tripo GLBs were imported Lossless on every headless import and export. The "detect 3D" switch to VRAM compression only fires in an interactive editor.
   - The fix is `[importer_defaults] texture` = VRAM compressed in `project.godot`.
   - Result at Saltfell q1: VRAM goes from 750 MB to 305 MB. Across areas, q0 and q1 drop 59–62%, and GPU time is unchanged.
   - I checked this on a fresh clone.
   - Committing the `.jpg.import` files was tried first and is broken: Godot then embeds raw textures in each `.scn`.

**Action for you after merging:** existing worktrees keep their old Lossless `.import` files. In each worktree, run once:

```
python3 tools/art/texture_imports.py && godot --headless --path . --import
```

**New tools**
- `tools/perf_tour.sh`, controlled by the env vars `AREAS`, `STATES`, `QUALS` and `TAG`. It needs a real GPU.
- `tools/perf_report.py`.
- The `perf_tour` sandbox, with a `--perf-ablate` switch.

**Recommendations I did not implement** (they touch 1:1 systems, so they are your call):
- **a.** `enemy.gd:314` sets `agent.target_position` on every physics tick while approaching. Throttle it to updates after 0.5 m or more of movement, or every 0.15–0.2 s.
- **b.** Convert the weather's `CPUParticles3D` (about 2,300 particles) to `GPUParticles3D` with `convert_from_particles()`.
- **c.** Run the editor profiler on the 2–3 ms of script time that remains.
- **d.** There is a q2-only SDFGI hitch at the Saltfell hall.

**Notes**
- **Measured on `978f141`:** Kettle Fjord was profiled before your Kettle polish merge, and Tarnhall was skipped, as the outbox asked.
- **Next:** Job 2, the real-GPU gallery, on `gpu/gallery`, unless the outbox says otherwise.
