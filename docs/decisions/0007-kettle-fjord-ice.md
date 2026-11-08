# ADR 0007: Kettle Fjord, open water and ice

- **Status:** accepted
- **Date:** 2026-11-08
- **Builds on:** ADR 0006 (the Lowe, and seams between terrain areas)

## Context

Kettle Fjord (`WORLD.md` §5.3) is the third region: a deep fjord under sheer walls, with fish-houses on stilts. In THAW it is open water. In RIME it is "one sheet of ice wall to wall", with the boats that tried to leave lying under it. It is the first region whose main walking surface changes between states, rather than only parts of it (the Lowe's bog).

## Decision

1. **Same world, one more seam.**
   - The fjord lies north of the Lowe's fell wall. It is carved into the Lowe's heightmap by `terrain_lowe._kettle_carve`, so the Lowe's horizon shows it. `tools/terrain_kettle.py` writes its own grid.
   - The Kettle Road runs down a cleft in the fell wall to the shingle shelf.
   - One seam, defined in `tools/seams_kettle.py`, links the two areas along the road. It is the graph edge "the Kettle Road".
2. **THAW: a shelf and jetties.**
   - The south wall has a flat shingle shelf (`SHELF_Y`), cut by two rock spurs.
   - Jetties go out over the water and round each spur to the fish-houses.
   - Deck tops sit only 0.03 m above the shelf. The player has no step-up, and the navmesh climb is 0.4 m.
   - The open water drowns.
   - The AI is kept off the fjord floor by tall navmesh-only walls built in strips. The strips stop short of the shelf lip and of every deck, so no flat blocker top becomes a walkable plane. (A single low blocker box did exactly that.)
3. **RIME: an ice floor.**
   - A rime-tagged slab spans the fjord at y 0.05. The shelf lip grades down under it, so the player and the navmesh step from the shingle onto the ice.
   - The audit sees the slab as a rime `state_floor`.
   - Frozen boats lie under the surface, with no collision.
4. **Thin ice is a hazard kind.**
   - `HazardVolume` kind `"thin"` works like the bog timer: you drown after `hazard/thin_ice_seconds` (0.7 s), or after a per-volume `"seconds"`.
   - Crevasses, the fishers' cut holes and the floe edge at the fjord mouth use it. The floe edge also stops the ice running off the map.
   - The Breathing Hole uses `"seconds": 0.05`.
   - The AI routes round each crack through rime navmesh-only blockers.
   - The edge audit treats `thin` as a kill.
5. **Foes still in production.** Spawners name the roster ids (`ice_fisher`, `sledge_dog`, `sealer`, `ice_cutter`) and give stand-ins, as in ADR 0006. The Ice-Cutter waits behind the veil in a ring of pressure ridges round the Breathing Hole.

## Consequences

- Any later area that freezes a lake or sea can reuse the pattern: a state floor slab, thin-ice volumes, and strip blockers for the THAW navmesh.
- The Ice-Cutter's moveset ("breaking the floor") will need hole volumes it can spawn at runtime. The `thin` kind is the hook for that.
- The THAW route has no boat ride, only jetties. A boat crossing can be added later as a THAW-only moving platform.
