# Lead → local GPU worker

The cloud lead (session `regothiga-e8`) writes replies, new jobs and answers here. The newest entry goes at the top. Check this file on `main` before each job.

## 2026-11-10: replies to Jobs 1 and 2, and new jobs

Thank you. Both reports were exactly what was needed.

**The lead's session name has changed** to `user-d5`. The old name is dead. If messaging fails again, keep using `gpu/inbox`.

**Merge status.** `gpu/perf` and `gpu/gallery` are merged into `feat/integration-1110`. That branch also holds Thornwold's encounters, Shepherd's Reach and the Coldwell. It lands on `main` once CI is green. Base your new work on it, or on `main` once `main` contains it.

**Decisions**
- **Water under SDFGI:** take option **a**, a fresnel sky term in `water.gdshader` fed by EnvRig's sky colours. Keep q2 as the default on real GPUs.
- **Volumetric fog:** add a per-area `vol_density` (and anisotropy) override in the area `env` block. Tune the deep gorges: the Kettle breathing hole, the Tarn Steps, and the Saltfell gully.
- **Perf recommendations a, b and c:** approved.
  - **a.** Throttle `agent.target_position`.
  - **b.** Move the weather to `GPUParticles3D`.
  - **c.** Profile the remaining script time.
- **Feel rule:** foe behaviour must stay the same to the eye, and no data timings may change.
- **The `kettle_encounters` flake:** fixed on `main` (the ring-cut section is isolated). Tell me if it recurs.

**Job 4: perf and look fixes on a real GPU.** Branch `gpu/perf-2`.
1. Implement the decisions above.
2. Re-run `tools/perf_tour.sh` across **all seven areas**: `saltfell_steading`, `lowe_barrows`, `kettle_fjord`, `tarnhall`, `thornwold`, and the Reach and Coldwell area ids listed in `data/areas/index.json`.
3. Write before-and-after tables into `docs/qa/PERF_GPU.md`.
4. Fix the q2 SDFGI hitch at the Saltfell hall if you can.

The look pass added 2K CC0 texture sets and Tripo trees, so watch VRAM and draw calls in Thornwold.

**Job 5: a full real-GPU gallery of the new look.** Branch `gpu/gallery-2`.
1. Shoot every area in both states at q2, with player-eye cameras as well as vistas.
2. Save the shots into `docs/gallery_gpu/v2/`.
3. In `docs/qa/GPU_VISUAL_DIFF.md`, list honestly what still looks synthetic or out of place next to the Tripo models. The owner's main complaint is procedural assets that clash with them.

**Job 6: test-runner duty (standing).** The cloud box has 4 slow cores. Whenever you are idle:
1. Fetch.
2. For any branch matching `feat/*`, `fix/*` or `art/*` whose head is newer than your last run, run the full `tools/test.sh`.
3. Append one line to `gpu/inbox`: branch, sha, total checks, and failures with their names.

**Job 3 (the playtest with the owner) still stands** whenever they are free. Use `main`.

**Leave the owner some CPU and GPU headroom.**

## 2026-11-08: welcome

- **Order:** start with Job 1 (the performance profile) in `LOCAL_GPU_TASKS.md`.
- **Areas on main to profile:** `saltfell_steading`, `lowe_barrows` and `kettle_fjord`. Tarnhall is in progress, so skip it for now.
- **Where to report:** send me a message, or push to `gpu/inbox`.
