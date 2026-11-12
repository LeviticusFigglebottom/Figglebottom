# ADR 0015: Every weapon gets its own model, grip and strikes; the torch is a fire

- **Status:** accepted
- **Date:** 2026-11-11
- **Decider:** weapons artist and animator (feat/weapons-overhaul)
- **Follows:** ADR 0004 (humanoid layer), ADR 0011 (combat library and class sets)

## Context

Owner playtest: "the torch, and (if other weapons exist yet, likely them too) need full graphical/animation overhauls."

What was there, weapon by weapon, judged on contact sheets (`tools/anim/weapon_sheets.sh`) and a rack of the bare meshes (`--rack`):

- **Torch, spear, greatblade, bow:** greybox primitives. The torch was swung with the sword set, carried head-down, had one static light, a flame that the RIME state switched off, and could not strike at all (`no_attack`).
- **Turf spade:** exported upside down. The blade was in the fist and the T-handle was the "tip".
- **Maul:** not marked two-handed, so the shield rode the forearm while both hands were on the haft.
- **Class sets:** the cleaver cut like a sword; the maul, spade and bill used the greatsword's cuts with the left hand placed past the end of the haft; every two-handed carry held the weapon upright in front of the face (it was keyed on the fighting crouch and played on the upright idle).
- **Trails:** one pale steel ribbon for everything, drawn along the whole haft of a polearm.

## Decision

### Models

| Weapon | Source |
|---|---|
| Torch, greatblade, quiver, arrow | Tripo (reference image, image-to-model, quad remesh), through the manifest |
| Spear, bow | Modelled in Blender (`tools/art/procedural/ash_spear.py`, `self_bow.py`). Tripo turned both, twice or three times, into doubled or flattened shapes (ledger). Not a denial: the paid calls ran. |
| Turf spade | Same Tripo project, re-processed with the T-handle as the grip |

`blender_process.py` gains `keep_one` (the arrow roll held two arrows; the second is deleted).

### Clips cut to the data

`tools/anim/weapon_clips.py` keys the clips a weapon needs because of what it is, on the ADR 0011 control rig. Each strike's contact frame **is** the strike time the player state machine uses (`windup + 0.45 * active` from `movesets.json`), read at build time, so the clip plays at 1x. **No timing data changed.** The build writes the section rows; the `anim` suite checks every one against the data.

| Class | Weapons | Own clips |
|---|---|---|
| `brand` | torch | carried aloft (right arm only, over idle, walk and run), jab, sweeping strike, overhead smash, running thrust |
| `chopper` | cleaver | forehand and backhand hacks, a joint-splitting heavy, a running hack |
| `maul` | post maul | swing, heave-and-smash, a dragged rising blow; guard, parry, riposte and a low hanging carry |
| `polearm` | spade, bill | hooking cut, falling cut, couched charge; guard, parry, riposte, port-arms carry. Hands spread: the left is 0.55 m up the haft |
| `twohand` | greatblade | the mocap cuts stay; new carry on the shoulder |
| `spear` | spear, auger, harpoon | the keyed thrusts stay; new couched carry |

Carries are keyed on the Bearer's own idle, because that is the body they play on.

### The torch

- **`BrandFire`** rides the head of the model: two flame-card tongues (the look-pass shader, `keep_in_rime`), embers, smoke (`shaders/smoke_puff.gdshader`), a glowing coal, and the light.
- The flame burns **upward** whatever way the haft points, and is dragged behind a moving head, so a swung brand trails fire.
- **Gutter:** gusts lean and shrink it; RIME adds a stronger wind (the one the snow falls on) and short hisses; under a roof it is nearly still. Looks only: the light never drops under `light_floor` of its data energy.
- **The light is the gameplay value.** Range, energy and colour moved from a constant in `player.gd` to `weapons.json` → `torch.light`, unchanged (8 m, 1.8). There is no warmth mechanic in data, and none was added.
- **Lit when drawn, a coal when put away.** Out of the hand it hangs unlit at the belt; kneeling at a hearth stows it.
- **Strikes.** `no_attack` is removed, so the torch uses the moveset its row already named (`longsword`, timings untouched). Its damage stays **0** (the `deltas` suite pins it): it staggers a little, throws sparks and an ember trail, and wounds nothing. *Open question for the owner: should a burning brand do a little damage?*

### Everything else in the hand

- **Bow:** the stave is a model in the left fist (thumb up; the hand used to be palm-down with the bow rotated through it). `BowRig` draws the string from the nocks to the drawing fingers and lays the arrow model from the string across the grip; on the loose the string snaps forward and rings. The quiver rides the right hip. The arrow in flight is the same model.
- **Per-weapon seat** (`clip_meta weapons.<kit>.seat`) and **trail** (`trail` from/to along the head only, `trail_tint`, `trail_life`, `trail_weight`, `trail_style: ember`).
- **Stow:** `mounts.stow@<class>`: hip for one-hand weapons, across the back for long ones; used while kneeling.
- **Pickups** with a weapon item show that weapon's own model.
- **Maul:** `two_handed: true` (a looks flag: it only hides the shield).

## Consequences

- Changing a windup in `movesets.json` now also means rebuilding the library (`build_combat_lib.py`, about two minutes), as it already did for foes.
- Player hitboxes are still the moveset's data boxes; a torch jab and a sword cut share one.
- The torch's fire is three CPU particle systems and one unshadowed light per Bearer: nothing on foes or NPCs carries one yet. An NPC torch would reuse `BrandFire`.
- Weapons the Bearer cannot find yet (spear, greatblade, bow have no pickup or seller in the area data) are ready when they are placed.
- New Pack and Belt icons can be rendered from: `torch`, `greatblade`, `spear`, `bow`, `arrow`, `quiver` and the corrected `turf_spade` (`assets/models/weapons/*.glb`, grip at origin, head +Y).

## Verification

- **Suites:** `anim` (229 checks; it now checks every per-weapon strike against its data strike time, the torch's light, gutter, stow and strikes, the bow string and the quiver), `combat`, `deltas`, `smoke`, `body`, `encounters`: all pass.
- **Contact sheets:** `docs/screens/weapon_<kit>_<clip>_sheet.png` for all eleven weapons (72 sheets) and `weapon_rack.png`. Re-render: `tools/anim/weapon_sheets.sh`, `tools/anim/weapon_sheets.sh --rack`.
- **In-game shots:** `docs/screens/weapons_{torch_rime,torch_strike,greatblade_heavy,spear_thrust,bow_draw,maul_smash}.png`, taken with the real Player and a real foe through `tools/shot.sh` stages (`bearer_hold`, `bearer_bow`, `bearer_light1/2`, `bearer_heavy`).
  - They are in the **arena sandbox in its RIME dusk mode** (`--sandbox=arena --state=rime`: frosted kit, low blue sun, snowfall), not on the Strand. A full area needs about 5 GB to render in software and this box was shared with other sessions' renders; it was killed for memory or timed out on most tries.
  - Two full-area shots did finish during the work (a torch heavy and a greatblade heavy on the Strand in RIME) and were looked at: the light pool on snow and the blade read as in the arena. They were taken before the last fixes and are not committed. **Not yet seen on a real GPU.**
  - Command: `SHOT_RES=1280x720 tools/shot.sh OUT.png --area=saltfell_steading --state=rime --shot-nohud --shot-stage=bearer_heavy --shot-weapon=torch --shot-beat=0.06 --shot-frames=300`.

## Follow-up (2026-11-12, `feat/weapon-finds`): the three are placed

One a third of the way through the game each, none in Saltfell, all a short step off the route, in both states (the pickup's `pose` stands or hangs the model instead of laying it down; `also` gives the arrows with the bow):

| Weapon | Region (order) | Find | Where |
|---|---|---|---|
| Spear | the Lowe (2 of 7) | `kin_spear` | against the kin-post at `kin_a`'s door, beside the bier, about 4.5 m off the Barrow Road (`gen_lowe.py`) |
| Greatblade | Tarnhall (4 of 7) | `oar_greatblade` | at the oar-stand on the Seven Landings shore, about 10 m off the causeway's land end (`gen_tarnhall.py`; the shore rush keeps off a trodden way to it, `data/veg/tarnhall.json`) |
| Bow, 20 arrows | Shepherd's Reach (6 of 7) | `sheiling_bow` | on the lower sheiling's north wall, the side facing the Sheilings hearth, about 8 m from it (`gen_reach.py`) |

No Journal step and no Map marker: none of them belongs to a thread, and ADR 0014 marks only places, hearths, veils and ways on. Their `desc` texts say where each was left. No combat number changed; the torch's damage is still 0. Test: `tools/test.sh weapon_finds`.
