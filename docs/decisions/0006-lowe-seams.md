# ADR 0006: The Lowe, and seams between terrain areas

- **Status:** accepted
- **Date:** 2026-11-07
- **Builds on:** ADR 0003 (natural, interconnected level design), ADR 0005 (Saltfell is one area)

## Context

The Lowe (`WORLD.md` §5.2) is the second region. ADR 0003 asks for area seams on continuous terrain with no loading-corridor feel, several links per area, and a loop opened from the far side. Saltfell already shows the Lowe's barrow hills across its ravine.

## Decision

1. **Shared coordinates.** `lowe_barrows` is its own area with its own heightmap (`tools/terrain_lowe.py`). It uses Saltfell's world coordinates and Saltfell's landform function. The Lowe adds its own features only north of the ravine. The land seen across the ravine from either side is therefore the same land.
2. **Seams are auto portals.** An `AreaPortal` with `"auto": true` covers the whole width of the passage with a trigger box, and walking in carries you to the same ground in the next area. Each seam is defined once, in `tools/seams_lowe.py`, and both generators read it, so the two sides agree. The edge audit counts the seam as a classed edge (`seam`) and stops its flood there.
3. **Two links:**
   - **The pass (main route).** The ravine heads out short of the west sea cliffs, leaving a strip of cliff top. From the yard, you walk west and north along the cliff top to the pass.
   - **The drawbridge (shortcut).** A plank bridge on ropes spans the ravine behind the Longhouse. Only the Lowe side has the windlass, and lowering it sets the world flag `lowe_bridge_down`, so the bridge stays down in both areas. From Saltfell it stands raised on the far side.
4. **THAW and RIME routes.**
   - The peat bog drags at the Bearer and drowns them after a few seconds in THAW. It is frozen and walkable in RIME.
   - Per-state navmesh-only blockers (physics layers 10 and 11) keep the AI out of THAW bog water, without stopping the player from wading in.
5. **Foes still in production.** Spawners name the roster ids (`turfwright`, `barrow_sleeper`, `keener`, `cairn_carrier`) and give a `stand_in`. Until the art branch adds a row to `enemies.json`, the stand-in fights in its place. Once the row exists, the real enemy spawns with no change to the area.

## Consequences

- Every new region joins the world the same way: shared coordinates, a shared seam module, and auto portals.
- Each area still builds and bakes only its own grid, in about 2 s per area.
- Barrows are a `building_gen` variant (`"kind": "barrow"`): a stone facade and passage under a turf mound. Their turf doors are in during THAW and open in RIME.
