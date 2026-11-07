# Experiment: can Tripo produce a usable area chunk?

**Verdict: no, not as playable space. It is usable as a backdrop or skyline piece only (distant vistas, a far-cliff set dressing, or a map-table prop).** Build playable areas from to-scale kit pieces (procedural and Tripo heroes) laid out by the JSON area builder.

## What was made

| | Value |
|---|---|
| Prompt | Diorama of a sea-cliff steading yard on a single square base, three-quarter top-down. It includes a turf-roofed longhouse gable end, dry-stone walls, a hearthstone, two fish racks, a path and a cliff edge, plus the STYLE TAIL and exclusions (full prompt in `assets/PROVENANCE.md`). |
| Tripo | text-to-model v3.1, detailed texture. Project `cc0f1689-5d77-4a53-b709-92588b8bfa53`, task `9213a51a-…`, 55 cr. Remesh `4500f764-…`, 40 cr. |
| (a) Tripo quad remesh at the maximum face limit (10k quads) | `assets/models/areas/experiment/area_saltfell_yard_remesh.glb`: 19.4k tris, 3.4 MB, 2K textures |
| (b) Raw 1.9M tris decimated in Blender | `assets/models/areas/experiment/area_saltfell_yard_decim.glb`: 150k tris, 7.7 MB, 2K textures |
| Scale | Both scaled to 30 m wide, with trimesh collision (`-col`). The result is 30 × 30 × 15.3 m. |
| Test scene | `scenes/sandbox/art_area_test.tscn` + `src/debug/art_area_test.gd`. Raycasts a 9×9 grid onto the imported collision, then shoots an overview and a 1.6 m eye view with a 1.8 m rimewalker for scale. |

## Findings

| Check | Result |
|---|---|
| **Collision** | Works. The trimesh hits 81/81 sample rays on both variants. The walkable yard sits on a **3.4–4.2 m high rock plinth** (the diorama base), not at Y=0. The roof ridge is at 13.3 m. The yard surface is lumpy (baked rocks and grass clumps), so it would need a navmesh bake and a lot of cleanup. |
| **Scale coherence** | Fails. At 30 m wide the hearthstone ring is about 5 m across, the door about 4–5 m tall, and the fish racks about 6 m. The 1.8 m rimewalker looks like a doll (`art_area_*_eye.png`). A diorama shrinks the buildings and enlarges the props for readability, so **no single scale is right for everything**. If you scale it so the door is 2 m, the whole yard is only about 12 m wide. |
| **Texel density at eye height** | Poor. One 2K texture spread over about 1,500 m² of surface gives roughly 50 px/m. Compare about 640 px/m on the Tripo hearthstone (1K over 1.6 m) and about 190 px/m on the procedural kit. Up close it is a smear (`art_area_remesh_eye.png`). |
| **(a) remesh vs (b) decimate** | They are visually almost identical at overview distance. (a) is 8× cheaper to render (19k vs 150k tris) and has a baked normal map. (b) keeps slightly better silhouettes (fence rails, roof grass) but is 7.7 MB with no normal detail gain. At eye height, both are limited by the texture, not the geometry. |
| **Two-state world** | A single fused mesh cannot carry the per-node `base/thaw/rime` tags that the area builder needs. Routes cannot differ between states, and nothing can be moved or opened. |
| **Modularity** | Everything is fused: walls, racks and hearth are one mesh. Nothing can be reused, snapped to the 4 m grid, or given a gameplay role (for example, the hearthstone as a rest site). |

## Recommendation

- Spend Tripo credits on **hero assets** (characters, Holdfasts, signature weapons and landmark pieces such as the Hearthstone) and on concept art. Do not spend them on area chunks.
- A diorama is worth about 95 cr only as a **far-distance backdrop** (a neighbouring steading across the fjord, seen at more than 60 m, where texel density does not matter), or as a cheap 3D blockout reference for a level designer.
- Playable space should be built from to-scale kit and assembled by data, as already planned in `src/world/area_builder.gd`.

Screenshots: `docs/screens/art_area_remesh_overview.png`, `art_area_remesh_eye.png`, `art_area_decim_overview.png`, `art_area_decim_eye.png`.
