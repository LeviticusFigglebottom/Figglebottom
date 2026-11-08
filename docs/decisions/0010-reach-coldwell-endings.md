# ADR 0010: Shepherd's Reach, the Coldwell, and the ending hook

- **Status:** accepted
- **Date:** 2026-11-08
- **Builds on:** ADR 0006 (seams), ADR 0009 (Thornwold)

## Context

The last two regions (`WORLD.md` §5.6, §5.7) close the line up the water. Thornwold, then Shepherd's Reach, then the Coldwell. The Coldwell must be a long, quiet, climbing approach with the whole country below it. Its arena must serve both endings (SPEC §2: The Outsong, The Hearth Kept). The endings themselves are not built yet.

## Decision

1. **One landform for the high country.**
   - `tools/high_land.py` is carved into the shared north-country heightmap after the wood (`terrain_lowe.height` calls it last), so Thornwold, the Reach and the Coldwell agree on the ground they share.
   - **Fell path:** a cutting runs out of Thornwold's east side.
   - **Reach:** a rounded pasture, with green fells capped about 35 m above it. The concept is a valley, not a gorge.
   - **Beck:** a cut 2.6 m deep across the pasture.
   - **High Fold:** a shoulder for the fold.
   - **The Upwater:**
     - It runs along the mountain's shoulder.
     - The river is on the downhill side, and beyond it the land drops toward the regions below.
     - The uphill side is a ledged wall, capped so it does not read as a gorge.
     - At the top is a level of turf round the spring, under the glacier's lip.
2. **Seams** are defined in `tools/seams_high.py`:
   - thornwold ↔ shepherds_reach is "the fell path";
   - shepherds_reach ↔ coldwell is "the Upwater".
3. **THAW and RIME change the routes, not only the dressing.**
   - **Reach, THAW:** the beck drowns, and the AI's nav is blocked in the cut. The only way over is the plank bridge.
   - **Reach, RIME:** the beck is iced to the brim and is a state floor you can cross anywhere.
     - 70 frozen sheep stand on the slope, all facing the fold. They are colliders, so the rime nav winds between them.
     - Their facing is the kit's local −Z.
   - **Coldwell, RIME:** the river is frozen, with the unsung dead (upwalker and unsung models) standing in it facing upstream.
4. **Foes are stand-ins with roster ids**, as in ADR 0009:
   - drover, frost_ram, and the Fellcaller boss behind the fold's veil;
   - upwalker, unsung, and the Leadvoice boss behind the ring's veil, posed sitting.
   - The climb carries three upwalkers only, which keeps it quiet.
5. **The ending hook.**
   - `src/world/ending_choice.gd` is a `scripted` node in the group `ending_choice` at the spring. It stays dormant until `World.flag(release_flag)` is set; the default flag is `ks_leadvoice_released`.
   - It then offers two interactables:
     - "Lay the coal in the spring" chooses `outsong`.
     - "Keep the horn shut, and sit" chooses `hearth_kept`.
   - `choose()` sets `ending_<id>` once and emits `chosen(ending)`.
   - The cutscenes, credits and post-game hang off that signal. They are not built here.
6. **The THAW sky** changes in `data/state_profiles.json` only:
   - a blue zenith over a warm low-sun horizon, instead of the flat dusk orange;
   - a neutral fog and ambient.
   - The shader's existing cloud deck now reads against it.
   - The Coldwell overrides its THAW to a clear spring morning (the last Melt).
7. **New kit and material.** The `sheep` kit piece and the `M_wool` MaterialLib family (which takes snow). No one-off materials.

## Consequences

- Edits to `high_land.py` change the far terrain of every northern area. Regenerate kettle, tarnhall, thornwold, reach and coldwell together.
- The fell walls above the pasture have strata ledges. A few are walkable, but the edge audit confirms none of them lead out.
- The mountains beyond the fine grid still render as rock. Snow on high ground is left to the terrain material pass.
