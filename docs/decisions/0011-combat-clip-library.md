# ADR 0011: A shared combat clip library and weapon-class clip sets

- **Status:** accepted
- **Date:** 2026-11-10
- **Decider:** combat animation lead (feat/combat-anims)
- **Follows:** ADR 0004 (humanoid animation layer)

## Context

Owner review: movement reads, but the player's combat animation looks very weak. Every Bearer attack reused one Tripo preset (`slash`, an open-hand chop) at different speeds; heavy, block and stagger were procedural overlays; nothing distinguished a blade from a maul or a spear.

## Options

1. **More Tripo text-prompt clips** (20 credits each). Earlier trials: good for dodge, drink and kneel, weak for attacks.
2. **CC0 mocap retargeted onto the Mixamo rig.** The Quaternius Universal Animation Library 1 and 2 (Standard editions, CC0 1.0) hold a sword combo, an overhead cleave, a heavy combo, a dashing cut, shield guard and guard-break, a death fall, a knockdown and a dive roll.
3. **Hand-keyed clips** on the real rig for what no library covers (thrusts, riposte, parries, hit reacts, backstep, bow).

## Decision

**2 and 3 together, no Tripo spend.** One clip-only GLB, `assets/anim/combat_lib.glb`, built by `tools/anim/build_combat_lib.py` (headless Blender):

- **Retarget:** each source bone's world rotation delta from its T rest pose is applied to the matching Mixamo bone's rest; the pelvis offset scales by hips height. Both rigs rest in a T-pose facing the same way, so no per-bone correction table is needed.
- **Edits on retargeted takes** (`tools/anim/anim_pose.py`): cut and concatenate, time-warp (stretch a wind-up to its data windup so playback stays near 1x), and `two_hand`: the left hand is IK'd onto the haft and the chest turns to help it reach, the weapon itself never moving.
- **Hand-keyed clips** (`tools/anim/combat_clips.py`): key poses are *controls* (pelvis offset and turn, chest, head, foot placements, weapon grip point with blade and edge direction, left hand on the haft), interpolated with easing and solved with analytic two-bone IK every frame. Feet therefore stay planted and hands travel in world space.
- **Grips are data** (`tools/anim/grips.json`): where the blade and edge point in the rest hand, per weapon class. `tools/anim/grip.py` writes them to `clip_meta.json` as `mounts."weapon@<class>"`; the Blender build poses hands with the same numbers.

Runtime (all data in `data/anim/clip_meta.json`):

- `libraries`: clip-only models merged into the shared library under their own names (`sw_light_a`, `gs_heavy`, `sp_thrust_a`, `guard_hold`, …). They never shadow an existing clip, so foes are unchanged until they opt in.
- `weapon_class`: weapon kit → class (`onehand`, `twohand`, `polearm`, `spear`, `bow`).
- `clip_sets`: class → game clip name → library clips. `HumanoidLib.candidates()` tries the class set, then `_all`, then the old aliases. Only models with `"clip_sets": true` (the Bearer's outfits) use them; an armed foe opts in with that one key.
- Section rows (`start`/`contact`/`end`) per clip, as before. The `anim` suite asserts that every moveset attack of every class lands its contact within one physics frame of the data windup, at an unclamped rate.
- `polish`: a lean away through the wind-up and a forward dig on a landed hit (held by Juice's hit-stop), added by `CharVisual` on the flinch node. Blend-out to locomotion is eased; blend-in stays linear and short.

Player code changes are small: a `block_hit` react over the guard hold, `stagger_back` when struck from behind, and the mannequin-only mount reset no longer zeroes a humanoid's grip.

## Consequences

- No feel number changed: windups, actives, recoveries and i-frames are untouched; clips were cut to them.
- Tripo's `dodge_roll` is replaced by the library dive roll (it started from a raised-arm pose and sank through the floor); Tripo `drink` and `rest` stay.
- The two-handed and long-haft sets are one-handed mocap re-posed, so the left hand follows rather than drives; they read well but are not true two-handed captures.
- Rebuilding needs `raw/anim_src/` (`tools/anim/fetch_ual.sh`) and the bpy venv. The GLB and its `.import` are committed.
- Contact sheets: `tools/anim/sheets.sh` (pose_sheet sandbox, rig mode) writes `docs/screens/anim_<class>_<clip>_sheet.png`.
