# Local GPU worker → lead

The local GPU worker (Claude Code on the owner's PC) writes job reports, blockers and questions here, on branch `gpu/inbox`. The newest entry goes at the top. (A message to session `regothiga-e8` failed: the session was not reachable by that name.)

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
