# ADR 0009: Thornwold, the wood, and hedges as walls

- **Status:** accepted
- **Date:** 2026-11-08
- **Builds on:** ADR 0006 (seams), ADR 0008 (Tarnhall)

## Context

Thornwold (`WORLD.md` §5.5) is the fifth region: old birch and pine, a charcoal clearing, laid hedges along the drove-roads, and the Hedgelayer's rings round a grave. Two things it needs are new:

- a wood, made of trees, rather than a landform with props on it;
- hedges that are the level's walls, and that change between THAW and RIME.

Tarnhall also needed a second link (ADR 0003).

## Decision

1. **The second Tarnhall link is the drove-road to Thornwold.**
   - The road leaves the tarn's east shore through a notch in the basin wall. The landform is in `tools/thorn_land.py`, carved after the tarn into the shared heightmap.
   - One seam in the notch, defined in `tools/seams_thornwold.py`. The graph edge is "the drove-road".
   - In THAW you reach it round the tarn's shore. In RIME you can also go straight across the ice.
   - This keeps WORLD.md's "up the water" order (fjord, then tarn, then wood). The Lowe fells route was left for a later loop.
2. **`Forest` (`src/world/forest.gd`) builds the wood from an area's `"forest"` block:**
   - Pine and birch are built from primitive meshes (cylinders, cones, spheres), so they keep their own UVs, and use MaterialLib families only: `M_bark_pine`, `M_bark_birch`, `M_needles`, `M_leaves`, `M_thorn`, plus `M_rime` for frozen thorn. The new families take RIME snow.
   - Trees are chunked MultiMeshes with visibility ranges. Each trunk has a cylinder collider.
   - Geometry is kept simple, so the shared materials (the art/unified-look branch) carry the look.
   - There is no wind sway on trees. That would need a per-family shader, which is left to the material pass.
3. **Hedges are lines of stems** laid at a lean and crossing, round a dense core, with a box collider every ~2 m. There are three styles:
   - `laid`: THAW, 1.35 m.
   - `thorn`: RIME frozen thorn, 3–3.2 m.
   - `thicket`: the wood's edge, 2.6 m wide.
   - The audit sees every hedge as tagged thicket polygons. The edge audit now rasterizes thickets per state, blocks the flood with them, and classes them as `thicket` edges.
4. **Route differences:**
   - **THAW:** the rings' gaps all face the road, so the way to the grave is straight.
   - **RIME:**
     - The THAW gaps have grown shut, and the new gaps stand at 70° (outer ring) and 295° (middle ring).
     - Thorn spokes between the rings force the long way round.
     - The drove-road is plugged twice past the clearing.
     - The result is a maze to the veil in the innermost gap. That gap stays at 180° in both states: he never decided where the gate went.
   - The Tripo gate (`lm_hedge_gate`) leans unhung on the inside of the ring, beside the gap.
5. **Long paths:** the RIME maze is longer than the navigation server's default polygon search allows. Tests ask with `path_search_max_polygons` raised. Enemies only path locally.

## Consequences

- Shepherd's Reach and the Coldwell can reuse `Forest` and the hedge styles: fold walls are a hedge style away.
- When the material pass lands, the tree and hedge families pick up its textures with no geometry change.
