# ADR 0004: Humanoid animation layer for Mixamo-rigged characters

- **Status:** accepted
- **Date:** 2026-11-07
- **Decider:** gameplay-animation engineer (feat/characters)
- **Follows:** ADR 0001 (the one place the port is not 1:1 in code), SURVEY.md "Characters" row

## Context

The source drives every character with one 17-bone mannequin whose clips are per-bone Euler deltas written in GDScript (`src/chars/skel_anim.gd`). Combat code rate-scales each action clip so that its contact frame lands on the attack's data windup: "combat timing is data, animation is flavour".

The Tripo pilot (`tools/art/manifest.json`, `docs/art/design/pilot.md`) produced two characters on Tripo's Mixamo-compatible biped rig: the rimewalker (1.8 m) and the Netmender (3.2 m). Each has 65 `mixamorig_*` bones and a handful of merged preset clips:

| model | idle | walk | run | slash | hit | defeat |
|---|---|---|---|---|---|---|
| rimewalker | yes | yes | yes | yes | yes | yes |
| netmender | yes | yes | no | yes | yes | yes |

There are no roll, block, parry, drink, rest or death-fall presets. Measured on import, `defeat` (Tripo `defeat_02`) is a standing slump: the hips never drop. It cannot serve as a death.

The game needs, per character: a locomotion blend by ground speed, one-shot actions (attack, hit, death, roll, block, parry, drink, rest), data-timed contact frames, weapons on hand bones, and a blade hitbox that follows the weapon mesh. The player must stay on the mannequin until the Bearer model exists, but must already be able to take a model.

## Options

1. **Keep `SkelAnim` and remap its tables to Mixamo bone names.** Cheap, but it throws away Tripo's real clips, which are the point of buying rigged models.
2. **Per-model AnimationPlayer with each model's own clips.** Simple, but a model with a missing clip (the Netmender has no run) has nothing to play, and every new model repeats the work.
3. **A shared humanoid library.** Godot's import retargeting (`BoneMap` + `SkeletonProfileHumanoid`, rest fixer) normalises every rig's bone axes, so one model's clips drive another. Each model's own clips take precedence. Procedural overlays fill states that no preset covers. An `AnimationTree` does the blending.

## Decision

**Option 3.**

### Import (retarget)

- `tools/art/humanoid_import.py` writes `assets/anim/mixamo_bone_map.tres` (profile bone → `mixamorig_*` bone) and sets the retarget options on each rigged character's `.import`:
  - The bone map, with **rename off**. Bones keep their `mixamorig_*` names, so attachment targets and track paths read the same on every Tripo rig.
  - `rest_fixer/overwrite_axis` and `apply_node_transforms` on. Every bone's rest becomes the profile's standard frame, and the Tripo rig node's -90° yaw and scale are baked into the skeleton. A rotation key now means the same pose on any rig.
  - Loop flags for the locomotion clips.
- **Godot limitation:** `normalize_position_tracks` keys on the *profile* bone name (`Hips`), so it does nothing on an unrenamed rig. `HumanoidLib` therefore does the same normalisation itself: it divides hips position keys by the source rig's hips rest height and multiplies them by the target's height.

### Runtime

- **`HumanoidLib`** (`src/chars/humanoid_lib.gd`):
  - Builds **one shared `AnimationLibrary`**, cached for the whole process, from the donor model's real clips (`clip_meta.json` → `donor`, the rimewalker) plus the procedural overlays.
  - Builds a per-model library of that model's own clips, which shadows the shared one. The Netmender keeps her hunched idle, walk and slash, and borrows the donor's run.
  - Track paths are normalised to `Skeleton3D:<bone>`, so one library fits every model.
- **`HumanoidOverlays`** (`src/chars/humanoid_overlays.gd`) ports `SkelAnim`'s idea: eased Euler deltas in degrees.
  - The deltas are authored in **body space** (X = the character's left, Y = up, Z = forward) and composed onto the donor idle's first frame at each bone's pivot. The tables therefore never depend on a rig's bone rolls.
  - Hips offsets are in hips-heights, so they scale to any body.
- **`CharVisual`** gains a humanoid mode, selected by a `"model"` key. The mannequin path is untouched, and when `"model"` is absent the mannequin is still the fallback. In humanoid mode an `AnimationTree` is built:
  - `BlendSpace1D` (idle 0, walk 1, run 2), driven by ground speed against the data `stride`
  - a `TimeScale` that matches stride
  - two action slots (`Animation` → `TimeSeek` → `TimeScale`), so one action can cross-fade into the next
  - `Blend2` nodes mixing loco ↔ action, with weights eased in `_process`
- **Timing stays data.** `data/anim/clip_meta.json` holds, per clip:
  - `start`, `contact` and `end` (seconds into the source clip; Tripo presets carry long idle lead-ins)
  - `source: real|procedural`
  - aliases from the game's clip vocabulary (`atk_r`, `attack_l1`, `stagger`, `gourd`, `kneel`, …) to humanoid clips

  `CharVisual.play_timed(clip, contact_at)` plays the section from `start` at the rate `(contact - start) / contact_at`, so the contact frame lands exactly on the data windup. The mannequin's contact table, which used to be hard-coded in `enemy.gd` and `player.gd`, moves to the same file under `mannequin_contact`.
- **Gear:**
  - Weapons attach by `BoneAttachment3D` to `mixamorig_RightHand`, and shields or off-hand items to `mixamorig_LeftHand` or `mixamorig_LeftForeArm`. The grip offset (position and Euler) is data in `clip_meta.json` → `mounts`.
  - A weapon kit with a Tripo GLB (`weapons` map) loads that GLB; others fall back to the KitLib greybox.
  - Mannequin bone names (`hand_r`, `farm_l`, …) are aliased, so player code that mounts by name keeps working.
- **Blade hitbox:** `Enemy._build_blade_hitbox` still merges the mounted weapon's mesh extents. It now takes its scale from the mount's real global scale rather than the `vis_scale` key, so it is right for both paths.

### Which clips are real and which are procedural

| state | humanoid clip | source |
|---|---|---|
| idle / walk / run | `idle`, `walk`, `run` | real (Netmender run borrowed from rimewalker) |
| attack (all `atk_*`, `attack_*`, `riposte`) | `slash` section | real |
| hit / stagger | `hit` | real |
| death | `death` | **procedural** (Tripo `defeat` is a standing slump; kept as `defeat`) |
| roll / backstep | `roll`, `backstep` | **procedural** |
| block / parry | `block`, `parry` | **procedural** |
| drink (gourd) | `drink` | **procedural** |
| rest (kneel at a hearth) | `rest` | **procedural** |
| cast (songs) | `cast` | **procedural** |

`tools/test/anim_test.gd` asserts this table against `clip_meta.json`, so the doc and the data cannot drift apart.

### Integration

- **Enemies:** `"model"` in `enemies.json`. The rimewalker uses `rimewalker` and now carries the `hewing_blade`. `holdfast_of_saltfell` (the Netmender in SLICE.md) uses `netmender`. Her hands are bare needles, so the model's `bare_hands` flag skips the data weapon.
- **Player:** `game.json` → `player.model` is read but left unset. The Bearer stays a mannequin until that model exists.
- **Orientation:** Tripo meshes face +Z after the manifest's -90° yaw. Godot characters face -Z, so each model's `yaw_deg: 180` is applied on a child of the flinch node.

## Consequences

- A new Tripo humanoid needs:
  1. a manifest row
  2. `humanoid_import.py`
  3. a `models` entry in `clip_meta.json`

  It then inherits every state.
- Procedural states read clearly but are stiffer than the presets. Buying Tripo presets for roll, block and parry (or adding hand-keyed clips) only means swapping `source` to `real`.
- `slash` is a single overhead-diagonal preset. Every attack id shares it, differing only in rate. Attack variety waits on more presets.
- The Tripo materials are `StandardMaterial3D`, so the death dissolve shader does not apply. Humanoid foes are freed after the fade timer instead of dissolving.
