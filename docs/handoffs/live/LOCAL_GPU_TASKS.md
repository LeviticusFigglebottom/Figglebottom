# Jobs for a session on the owner's own PC (real GPU)

The cloud sessions render with a software Vulkan renderer (lavapipe) on 4 CPU cores. That is slow, and it can't tell you real frame times. A Claude session running on the owner's PC (Remote Control, or Claude Code in the Desktop app) can do the jobs below far faster and more faithfully. Each job is self-contained.

**Setup**
- Clone `LeviticusFigglebottom/Figglebottom`, branch `main`.
- Install Godot 4.7 stable (the official binary).
- Open the project once in the editor, so it imports.
- Read `CLAUDE.md`, then this file.

**Rules**
- Commit to a branch named `gpu/<job>`, never to `main`. The cloud lead reviews and merges.
- Commit-message trailers, and the originality check, are as in `CLAUDE.md`.
- Never commit secrets.

## Job 1: Performance profile (highest value)

Measure real frame times on the owner's GPU and find what costs the most.

1. Build a small profiling runner, `src/debug/perf_tour.gd`, plus a sandbox scene for it. It must:
   - load each area (`saltfell_steading`, `lowe_barrows`, `kettle_fjord`) in both THAW and RIME
   - fly the camera along 4–6 representative viewpoints per area (reuse the `--shot-cam` positions in `tools/test/*` and `src/debug/shot.gd`)
   - record, per viewpoint:
     - average and 1%-low FPS over 5 s
     - draw calls (`Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`)
     - primitives
     - video memory
   - repeat at quality settings 0, 1 and 2, as defined in the pause-menu settings
2. Write `docs/qa/PERF_GPU.md` with:
   - the GPU, CPU and OS model
   - a results table
   - the 5 worst viewpoints, each with its likely cause: MultiMesh grass density, shadows, volumetric fog, SDFGI, particle counts, or Tripo texture sizes
3. Make the cheap fixes, if you're confident, on `gpu/perf`:
   - visibility ranges
   - shadow distance
   - grass density per quality tier
   - texture import compression (VRAM-compressed, mipmaps)

   Re-measure, and show the before/after numbers.

**Target:** 60 FPS at 1080p, quality 1, on a mid-range GPU.

## Job 2: Real-GPU visual gallery

Render the full gallery with the Forward+ renderer on hardware: volumetric fog, SSAO, SSR and SDFGI, which lavapipe skips or approximates.

1. Use `tools/shot.sh` or the editor's `--shot` flags: every `docs/screens/*` viewpoint for the three areas, both states, at quality 2.
2. Save the results in `docs/gallery_gpu/`.
3. Compare them with the lavapipe shots, and note in `docs/qa/GPU_VISUAL_DIFF.md` anything that looks different or broken on real hardware: fog banding, SSR artefacts, GI light leaks, shader compile hitches.

## Job 3: Play-feel capture (with the owner)

Ask the owner to play the slice for 15 minutes with `--perf-overlay` (or the Godot debugger's monitors).

Write their notes verbatim, and your observations, into `docs/qa/PLAYTEST_<date>.md`:
- combat feel: dodge timing, parry window, how readable the Netmender is
- camera
- music
- anything that broke
