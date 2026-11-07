# ADR 0003: Natural, interconnected level design (no corridor walls)

- **Status:** accepted
- **Date:** 2026-11-07
- **Trigger:** owner review of the first greybox

## Context

The first greybox, `saltfell_steading`, was a flat courtyard ringed by tall synthetic walls, with the outside world visible but fenced off. The source game had the same weakness: walls guiding the player to the next room, and gating that reads as *the designer* stopping you, not the world.

The owner wants spaces that feel natural and somewhat open-ended, interconnected the way the best soulslikes are: loops, shortcuts, vistas of places you will reach later, and the world folding back on itself.

## Decision

**1. Terrain first.** Areas are built on a heightmap terrain (`terrain` block in the area JSON), shaped by committed generator scripts. Cliffs, slopes, shelves, ravines, shore and sea are the primary space. Buildings sit *on* the land; they are not the land.

**2. Bounds are diegetic, and never a straight synthetic wall.** Allowed boundaries:
- sea and deep water
- sheer cliffs (both up and down)
- slopes too steep to climb (over 45°, with no stamina-based climbing)
- scree and boulder fields
- dense thorn or spruce thickets
- glacier ice walls
- deep snow drifts in RIME
- a building's own fabric

Fall-off edges kill or hurt, which gives the cliffs real stakes. Invisible walls are a last resort, and only where the terrain already reads as impassable.

**3. Gating is topological or diegetic.** Progress is held back by:
- a locked door seen from the wrong side, which later becomes a shortcut
- a gate barred from the inside
- a ladder to kick down
- a rope bridge to lower
- ice that only melts in THAW, or a snowdrift path that only exists in RIME
- a boat
- a frost veil (boss only)

A wall built only to stop you is not allowed.

**4. Interconnection rules.**
- Every area has **at least one loop** back to its Hearthstone, opened from the far side.
- Every region has **at least one vista** that shows a place reachable later, and one that shows a place visited earlier from a new angle.
- Area seams are **continuous terrain**, with no loading-corridor feel. The graph allows several links per area, including vertical ones.
- THAW and RIME change routes, not just mood. Examples: a frozen fjord you can walk across in RIME is open water in THAW. A bridge stands in THAW and has collapsed in RIME.

**5. Organic dressing.** Procedural scatter places rocks, turf hummocks, driftwood, stacked peat, fence lines that *follow* the contour, and paths worn into the turf. Nothing is axis-aligned unless people built it so.

**6. Audits change too.** `audit_walls.py` currently checks for sealed perimeters. It becomes an **edge audit**: every walkable edge must be classed as a cliff, water, a steep slope, a building or a thicket. An unclassified open edge fails.

## Consequences

- `area_builder.gd` gains a `terrain` block: a heightmap image or a generator, with splat material layers and HeightMapShape3D collision. Areas also gain a `scatter` block and an `edges` metadata block.
- `saltfell_steading` is rebuilt as the slice's continuous sea-cliff shelf, following `docs/lore/SLICE.md`: the Strand → a cliff path → Saltfell yard → the Longhouse, with a loop back down to the Strand through the boat-shed.
- Navmesh baking must handle terrain. Enemies keep to slopes they can walk.
