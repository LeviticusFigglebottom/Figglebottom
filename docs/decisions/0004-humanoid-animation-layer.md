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
  - `start`, `contact` and `end` (seconds into the source clip; Tripo presets carry long idle lead-ins). Without them a clip plays whole.
  - a separate `procedural` block with the overlay's own timing, used only while the overlay is what plays
  - aliases from the game's clip vocabulary (`atk_r`, `attack_l1`, `stagger`, `gourd`, `kneel`, …), each a best-first list (`atk_over` → `heavy` → `slash`)

  `CharVisual.play_timed(clip, contact_at)` plays the section from `start` at the rate `(contact - start) / contact_at`, so the contact frame lands exactly on the data windup. If the rate would pass `max_rate`, the lead-in is trimmed instead, so the hit is never late. The mannequin's contact table, which used to be hard-coded in `enemy.gd` and `player.gd`, moves to the same file under `mannequin_contact`. The rig advances on the physics tick, as the combat state machines do, so contact lands within a tick of the windup (asserted by the `anim` suite).
- **Drop-in real clips.** Whether a clip is real or procedural is never declared; it is *derived*. An animation of that name in a rig's GLB is real, and the overlays mark their own clips. Resolution tries the game name first, then its aliases. For each name it takes the model's own real clip, then the shared real clip, then any procedural overlay. So when the art pass delivers Tripo `roll`, `block`, `parry`, `drink`, `rest`, `heavy` or `stagger` clips, the steps are:
  1. add the clip to the manifest's `anims`
  2. rerun `blender_process.py` and `humanoid_import.py`
  3. optionally add top-level `start`/`contact`/`end`

  It replaces the fallback with **no code change**. The `anim` suite proves this by injecting real `roll` and `stagger` clips at runtime.
- **Gear:**
  - Weapons attach by `BoneAttachment3D` to `mixamorig_RightHand`, and shields or off-hand items to `mixamorig_LeftHand` or `mixamorig_LeftForeArm`. The grip offset (position and Euler) is data in `clip_meta.json` → `mounts`.
  - A weapon kit with a Tripo GLB (`weapons` map) loads that GLB; others fall back to the KitLib greybox.
  - Mannequin bone names (`hand_r`, `farm_l`, …) are aliased, so player code that mounts by name keeps working.
- **Blade hitbox:** `Enemy._build_blade_hitbox` still merges the mounted weapon's mesh extents. It now takes its scale from the mount's real global scale rather than the `vis_scale` key, so it is right for both paths.
- **Unarmed humanoids:** weapons are optional per model. A model's `unarmed` block in `clip_meta.json` gives each hand a sphere hit volume: bone, radius, and a bone-local offset. One `Hitbox` carries both spheres, so a two-handed blow still lands once. The volumes are re-placed from the skeleton's current pose every tick, carry no mesh, and are armed only during a swing. An attack's `"hands"` list in `enemies.json` chooses which hands strike; the default is `["right"]`. The rimewalker's grown ice-club hands use this (SLICE.md: it carries no weapon), and its two-handed `flail` (the double fall) strikes with both. Armed humanoids keep the blade path, ready for the Bearer.

### Which clips are real and which are procedural

| state | humanoid clip | source |
|---|---|---|
| idle / walk / run | `idle`, `walk`, `run` | real (Netmender run borrowed from rimewalker) |
| attack (all `atk_*`, `attack_*`) | `slash` section | real |
| heavy (`atk_over`, `attack_h`, `riposte`, 2h cleave) | `heavy`, falling back to `slash` | real (`heavy` awaited) |
| hit / stagger | `stagger`, falling back to `hit` | real (`stagger` awaited) |
| death | `death` | **procedural** (Tripo `defeat` is a standing slump; kept as `defeat`) |
| roll / backstep | `roll`, `backstep` | **procedural** |
| block / parry | `block`, `parry` | **procedural** |
| drink (gourd) | `drink` | **procedural** |
| rest (kneel at a hearth) | `rest` | **procedural** |
| cast (songs) | `cast` | **procedural** |

This is the state on 2026-11-07. `tools/test/anim_test.gd` prints the derived split on every run and asserts that each state resolves to one or the other.

### Integration

- **Enemies:** `"model"` in `enemies.json`. The rimewalker uses `rimewalker` and is unarmed (ice-club fist volumes). `netmender` (renamed from `holdfast_of_saltfell`) uses `netmender`. Her hands are bare needles, so the model's `bare_hands` flag skips the data maul, and she strikes with the body hitbox.
- **Player:** `game.json` → `player.model` is read but left unset. The Bearer stays a mannequin until that model exists.
- **Orientation:** Tripo meshes face +Z after the manifest's -90° yaw. Godot characters face -Z, so each model's `yaw_deg: 180` is applied on a child of the flinch node.

## Consequences

- A new Tripo humanoid needs:
  1. a manifest row
  2. `humanoid_import.py`
  3. a `models` entry in `clip_meta.json`

  It then inherits every state.
- Procedural states read clearly but are stiffer than the presets. Buying Tripo presets for roll, block and parry (or adding hand-keyed clips) is a data-and-asset change only.
- `slash` is a single overhead-diagonal preset. Every attack id shares it, differing only in rate. Attack variety waits on more presets.
- The Tripo materials are `StandardMaterial3D`, so the death dissolve shader does not apply. Humanoid foes are freed after the fade timer instead of dissolving.
- Screenshots come from the staged shots in `src/debug/shot.gd`: `--shot-stage=swing`, `foe_death` and `boss`. Each one freezes the tree on its gameplay beat before capturing, because headless frames render slower than physics ticks. The resulting images are `docs/screens/chars_*.png`.
