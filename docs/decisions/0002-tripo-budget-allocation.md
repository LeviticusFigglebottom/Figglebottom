# ADR 0002: Spend Tripo on hero assets; make props and decor procedurally

- **Status:** accepted
- **Date:** 2026-11-07

## Context

- **Budget:** the owner set a realistic ceiling of about 100 Tripo assets that can be fully processed into game-ready form. All Studio credits (about 24,700) may be spent.
- **Cost:** a finished humanoid costs about 115 credits (generate, remesh and rig; animation presets are free). A static hero piece costs about 95 credits.
- **Instruction:** "one-shot" the important assets.

## Decision

| Priority | Tripo use | Approx. count (full game) |
|---|---|---|
| 1 | **Bosses (Holdfasts)**: one per region, extreme or detailed texture | 7 (+ re-rolls) |
| 2 | **Enemies (frost-taken)**: about 3 per region, some shared | ~18 |
| 3 | **NPCs and the Bearer**, plus armour-set variants of the Bearer | ~20 |
| 4 | **Signature weapons and shields**, generated separately and bone-attached | ~15 |
| 5 | **Landmark set pieces**: the Hearthstone, the Longhouse door-post, ship prows, standing stones, frost veils | ~20 |
| 6 | **Area concept art**: 2D, if Studio offers image generation. One THAW/RIME pair per region, used as the target for lighting and layout. | 14 images |
| — | **Reserve for re-rolls** | ~10% of credits |

**Procedural** generation (Blender `bpy`, Godot and shaders) covers everything modular or repeated:
- walls, floors, roofs, steps and dry-stone
- barrels, racks, crates, fences
- rocks, terrain, ice formations, snow drifts, foliage cards
- skyline and backdrop rings
- VFX

These generators live in `tools/art/procedural/`. They share the materials in `STYLE.md` (MaterialLib names `M_timber`, `M_stone`, `M_wool`, `M_iron`, `M_horn`, `M_turf`) so procedural and Tripo assets read as one set.

## Consequences

- Each Tripo slot has a design sheet before it is generated (`docs/art/design/`), so most assets need only one roll.
- The balance is checked before every batch, because the account is shared. Every spend goes in `TRIPO_LEDGER.md`.
- Modular kit volume costs nothing in credits, so world size is never limited by the credit budget.
