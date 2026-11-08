# ADR 0008: Tarnhall, the controller's step-up, and stand-ins without a story

- **Status:** accepted
- **Date:** 2026-11-08
- **Builds on:** ADR 0006 (seams between terrain areas), ADR 0007 (Kettle Fjord, open water and ice)

## Context

Tarnhall (`WORLD.md` §5.4) is the fourth region: a great timber hall on a mountain tarn, "up the water" from Kettle Fjord. Three things came up while building it:

- **The controller.** Kettle's jetty decks had to sit flush with the shingle, because the Bearer's capsule on `move_and_slide` stops dead at any ledge taller than its own rounding. Tarnhall's porch, causeway and bridge need natural heights.
- **Borrowed bosses.** Foes whose art is in flight fight as stand-ins (ADR 0006). For a holdfast, the stand-in borrowed the whole row, including the release flag and card. A Kettle or Tarnhall kill would therefore have "released" the Netmender.
- **Gates.** A barred door that exists in one state only must not block the other state's navmesh.

## Decision

1. **Step-up and stair snapping** (`player.gd`, `game.json` `player/move`):
   - **Step-up:**
     - Skip if nothing ahead, or only floor or a walkable slope.
     - Otherwise check there is headroom to rise by `step_height` (0.35 m).
     - Check the way ahead is free at that height.
     - Check there is walkable ground under that point.
     - Then lift the body by the measured rise.
   - **Stair snapping:**
     - Floor snap uses `snap_down`.
     - After leaving the floor, a ray snap sets the Bearer onto walkable ground below.
     - It only fires once the capsule clears a step's nosing, the place where the built-in snap lets go.
   - Flat-ground feel numbers are unchanged.
   - The `controller` suite tests a deck edge, a ledge too tall to step, and four stairs up and down.
   - Kettle's jetty decks now stand 0.32 m above the shingle.
2. **Tarnhall's landform** (`tools/tarn_land.py`):
   - It is carved into the shared north-country heightmap, as Kettle is, so all three areas agree on the land they share.
   - A gorge, the Tarn Steps, climbs from Kettle's shelf at the fjord head. It runs beside the tarn's outflow, which falls into the fjord (running in THAW, frozen in RIME), up to a basin with the tarn.
   - The hall stands on an island, reached by a stone causeway with a plank bridge over its channel.
   - One seam on the Steps (`tools/seams_tarnhall.py`). The graph edge is "the Tarn Steps".
3. **Routes:**
   - **THAW:** the tarn drowns, so the causeway is the way over. The doors are propped open, and you walk in off the porch.
   - **RIME:** the doors are barred from inside. This is a one-state `gate` with the Tripo `lm_hall_doors` as its dressing. The audit sees it through `state_walls`.
   - In RIME the tarn is ice; its cracks are `thin` hazards.
   - The way in is round the hall to the byres' cattle door, through the byres, and past the veil into the Long Table.
   - From inside, the bar lifts: a shortcut back to the causeway.
4. **Stand-ins carry no story:**
   - A spawner standing in for a roster id strips the release flag, card, drop and hearth from its borrowed row.
   - It names itself after the roster id, and keeps that id as `roster_id` meta.
5. **One-state gates** take that state's collision layer, so the other state's navmesh is not cut by them.

## Consequences

- Thresholds, porches, decks and kerbs up to 0.35 m can now sit at natural heights everywhere.
- The Host's moves (table slide, bench throw, raising the guests, the freezing pool) and the release are for the encounters agent. They use the roster ids `feast_guest`, `cupbearer`, `hall_champion` and `host`, and the release (bar lifts, doors swing, guest-tally on the inside door-post) can hook onto `gate_hall_doors`.
- Shared terrain functions must not let `strata()` add height at depth 0 (it can go negative or positive there). `tarn_land._rise` is the safe form.
