# Animation review on a real GPU (2026-11-10)

**Reviewed:** `feat/foe-anims` `717cce7`, with `main` `7e82c0d` merged in. The NPC pass was repeated on `feat/integration-all` `1229a93`, with the same result.

**Setup:** RX 9070 XT, q2. NPCs are shot in place in THAW, 3.2 m in front of each body at its authored `rot`. The seated release scenes use their release flags. Cameras come from `tools/anim_review_views.py`.

## NPCs: no character is twisted, sideways or floating after the retarget

| NPC | where | verdict |
|---|---|---|
| Ingra | Saltfell | pass |
| Brede | Saltfell | pass |
| Aud | Lowe | pass |
| Hesk | Lowe | pass |
| Arne, Liv, Asta (released, seated) | Lowe | pass |
| Ivo (standing) | Kettle | pass |
| Pell and Ivo (released, seated) | Kettle | pass |
| Halla | Kettle | pass |
| Sten | Kettle | pass |
| Lusse | Tarnhall | pass |
| Linnet (both placements) | Thornwold | pass |
| Eyvind, Eyvind at the gate | Thornwold | pass |
| **Ottar** | Tarnhall | **fail: fallback mannequin** (no model in `data/npcs.json`, and no glb) |
| **Old Calder** | Shepherd's Reach | **fail: fallback mannequin** (`old_calder.glb` exists but is not wired) |
| **Maren** | Coldwell | **fail: fallback mannequin** (`maren_thaw.glb` exists but is not wired) |
| **Wren** | Coldwell | **fail: fallback mannequin** (`wren.glb` exists but is not wired) |
| Feast guests | Tarnhall hall | fallback mannequins (red tabards) |

For the passes: bodies are upright, feet are on the ground, the facing suits the scene, and the masks are intact. The four failures are a wiring gap that is the same on `main`, not a retarget fault.

## The Bearer

- **Registered rigs:** only `bearer_traveller` and `bearer_oilskins` are registered (`data/anim/clip_meta.json` "models"). Both play the light attack cleanly (`outfit_*_attack_l1_sheet.jpg`).
- **Other outfits:** armour items change stats and icons only. The other six `bearer_*.glb` outfits (barrow, collier, fleece, hall, icefur, outsong) are never shown in game, and the pose tool cannot build them.

| clip (hewing blade unless noted) | verdict |
|---|---|
| light 1 (`attack_l1`) | pass. The big sweep runs 0.31 → 0.36 s, just after the data contact |
| light 2 (`attack_l2`) | pass |
| heavy (`attack_h`) | pass |
| sprint attack (`attack_sprint`) | pass |
| roll | pass |
| block-hit | pass |
| parry | pass |
| riposte | pass |
| two-hand heavy (`attack_h@greatblade`) | **note:** the blade lies flat on or into the ground through contact (0.80–0.94 s) |

## Foes

| clip | verdict |
|---|---|
| rimewalker swipe | pass (a small motion) |
| sealer hook | pass |
| netmender knot | pass (kneels at contact) |
| **host table sweep** | **fail:** the arms stay stiffly spread for the whole clip and never hold the table |

## Files

`npc_<area>_<id>.jpg`, `anim_<kit>_<clip>_sheet.jpg`, `anim_foe_<foe>_<attack>_sheet.jpg`, `outfit_<set>_attack_l1_sheet.jpg`.
