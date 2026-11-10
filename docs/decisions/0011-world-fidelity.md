# ADR 0011: World fidelity for generated buildings, interiors and ground

- **Status:** accepted
- **Date:** 2026-11-10
- **Builds on:** ADR 0001 (reuse), ADR 0003 (terrain), `docs/art/LOOK_PASS.md`

## Context

The look pass gave every generated surface a photo material. The owner still read the houses as generated: flat slabs of board, a turf box for a roof, empty rooms lit like a hilltop, and ground that stopped dead at the wall. The Tripo heroes beside them carry modelled relief and baked shade. The brief: buildings, interiors, lighting and terrain close-up must sit in the same world, with collision, door positions, footprints and the `houses` JSON unchanged.

## Options

1. **Decal nodes** for moss, soot, wear and contact shadow. Needs a decal texture set, costs a cluster entry per decal, and decals bleed across unrelated surfaces.
2. **Vertex colour** on the buildings and **footprint uniforms** in the terrain shader. `hall.gdshader` already reads R = wear, G = moss, B = AO from vertex colour. Free at run time, exact, no new textures.
3. **Baked lightmaps** for interiors. Needs UV2 unwraps of generated meshes and a bake step in CI, and cannot follow THAW/RIME.
4. **Fill lights** indoors. Unshadowed omnis leak through walls onto the ground outside; shadowed omnis cost a cube pass each.
5. **A ReflectionProbe per interior** with its own ambient colour. Box-bounded, covers characters and props as well as the room, follows the state by changing one colour.

## Decision

1. **Geometry.** `HouseDetail` builds real construction detail inside 70 m through a new emitter, `MeshBuf` (metre UVs, analytic tangents, vertex colour). `BuildingGen` keeps the collision solids, the far LOD and the functions the look pass shares.
2. **Marks on buildings are vertex colour** (option 2): contact shadow at wall feet and under eaves, moss low on north faces, soot over door heads and round the smoke-hole, wear round doors. No Decal nodes.
3. **Marks on the ground are in the terrain shader** (option 2). `Terrain.add_footprint()` passes up to 16 footprints and 24 doors.
4. **Interior light is a probe** (option 5), `HouseProbe`, with ambient data in `data/game.json` → `render/interior`. Low quality tier skips it.
5. **Snow drifts are geometry**, a rime-only mesh per house. Raising terrain vertices was tried first: a 1 m grid cannot hug a wall, and the bank came up through the floor inside.
6. **Nothing new collides.** Door leaves stand open and can be clipped by a body hugging the wall. Benches stay inside the wall's own collision reach.

## Consequences

- A house is 19k to 74k triangles in 15 to 19 meshes (it was 5k to 13k in 5). Past 70 m five plain meshes draw: wall slabs, a stone band, roof slabs, the corner posts and the gable ends. Small parts drop at 36 m, interiors at 49 m.
- The terrain shader loops over the footprints for every fragment near a house. Areas without houses pay one integer compare.
- Probes capture once at load and once after each state change.
- The shot harness now waits for pipeline compiles to go quiet before quitting. Leaving earlier deadlocks the engine's shutdown under lavapipe.
- New houses get all of this from the same `houses` entry. An optional `"style"` key overrides the id-based guess (`hall`, `store`, `fish`, `byre`, `shed`).
