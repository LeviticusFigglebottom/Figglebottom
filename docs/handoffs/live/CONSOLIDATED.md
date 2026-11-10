# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State (on main fd6bf02: 850 checks, all green)
| Region | World | Encounters and writing |
|---|---|---|
| Saltfell (vertical slice) | ✅ | ✅ |
| The Lowe | ✅ | ✅ |
| Kettle Fjord | ✅ | ✅ |
| Tarnhall | ✅ | ✅ (the Host, seated guests, Lusse, Ottar) |
| Thornwold | ✅ (THAW/RIME hedge maze) | todo |
| Shepherd's Reach | in flight | todo |
| The Coldwell | in flight | todo, plus both endings |

- **Tripo balance:** about 14,280, before the look pass.
- **Owner feedback:** procedural assets clash with the Tripo art. The look pass fixes this: CC0 PBR textures, UVs, Tripo-textured buildings, Tripo rocks and trees.
- **Test flake:** `kettle_encounters` ring-cut flaked under load. The test is now isolated: it closes old ice, puts other moves on cooldown, and waits for the ring to open.

## In flight (worktree → branch)
| Worktree | Branch | Work |
|---|---|---|
| `/home/user/fb-qa` | `fix/slice-qa` | Merge main in, then body collision, enemy draw calls, title hitch, the tide wall |
| `/home/user/fb-look` | `art/unified-look` | The whole-world material/texture pass, plus trees and hedges |
| `/home/user/figglebottom` | `feat/reach-coldwell` | Shepherd's Reach and the Coldwell worlds, the ending hook, the THAW sky |
| `/home/user/fb-enc5` | `feat/release-scenes` | NPC sit support; the Lowe, Kettle and Tarnhall post-release THAW scenes |
| `/home/user/fb-anim` | `feat/combat-anims` | Player combat animation: the shared combat clip library (ADR 0011). Ready to merge; see "Combat animation" below |
| Owner's PC | `gpu/*` | `LOCAL_GPU_TASKS.md`. Nothing has been received yet |

## Combat animation (feat/combat-anims, ADR 0011)
- **State:** `assets/anim/combat_lib.glb` holds 47 clips (CC0 Quaternius mocap retargeted, two-handed re-poses, hand-keyed thrusts/riposte/parries/guards/reacts/bow). The Bearer picks clips by weapon class (`clip_meta.json` → `weapon_class`, `clip_sets`, `mounts."weapon@<class>"`). No Tripo credits spent, no feel numbers changed. `anim` (143), `combat`, `deltas`, `encounters`, `smoke` pass.
- **Rebuild:** `tools/anim/fetch_ual.sh`, then `$BPY tools/anim/build_combat_lib.py`, then `godot --headless --path . --import`. Look with `tools/anim/sheets.sh attack_l1@hewing_blade attack_h@greatblade ...` (sheets in `docs/screens/anim_<kit>_<clip>_sheet.png`); in-game with `tools/shot.sh OUT.png --area=saltfell_steading --state=rime --shot-stage=bearer_light1|bearer_light2|bearer_heavy|bearer_sprint [--shot-weapon=greatblade]`.
- **Swing trail:** it was invisible on every humanoid: the shader wrote its glow to EMISSION, which an unshaded material drops, and it blended additively (lost over snow). It now writes ALBEDO, alpha-blends, samples the pose on the physics tick and starts `polish.trail_lead` before the hit window.
- **Player hitbox:** left as the data box in front of him (moveset `hitbox` reach/width/height). A blade-following volume would hit different foes at the same data timings (the box covers the whole reach for the whole active window; a blade covers a moving slice), so it is a feel change for the owner, not an animation fix.
- **Foes not opted in:** the Oarsman, hall champion, cupbearer and collier are all bare-handed with their own overlays and windups of 0.8–1.2 s (the library clips would play at under half speed); there is no drover row. An armed humanoid foe opts in with `"clip_sets": true` plus a set mapping its `atk_*` names.
- **Known weak spots:** the two-handed sets are one-handed mocap re-posed; the bow loose is small.

## Foe animation (feat/foe-anims, ADR 0012)
- **State:** 36 foe attacks (11 ordinary humanoid foes, plus the plain melee of the Turfwright, Ice-Cutter, Host and Hedgelayer) have their own hand-keyed clip cut to the attack's data windup, in the same `combat_lib.glb`. Ordinary foes also take the library stagger and death fall. Quadruped wind-up poses are held, not eased over the windup.
- **Rebuild after any windup change:** `$BPY tools/anim/build_combat_lib.py && godot --headless --path . --import` (the build rewrites the `f_*` rows and `foe_*` sets in `clip_meta.json`). Look: `tools/anim/foe_sheets.sh --all`.
- **Pass 2:** the retarget import now covers every rigged character (it had only ever been run on seven, so the rest played shared clips a quarter turn off); foes are keyed on their own idle stance (`godot --headless --path . -s tools/anim/dump_idles.gd` before a rebuild if a model changes); 55 attacks covered including the Netmender; per-foe staggers; quadruped load/extension/landing poses (`tools/anim/quad_poses.py`). NPCs went through the same import change and were not looked at one by one.
- **Not done (pass 1 list, see ADR 0012 update for what remains):** signature overlays (`door_fall`, `lift_stone`, `tray_spin`, boss prompt clips); foes that only exist on `feat/reach-coldwell-endings`; new quadruped poses (only their timing changed).

## Next exact step
1. Merge each branch above once its tests pass.
2. Thornwold encounters (the Hedgelayer, Linnet, Eyvind), then Reach and Coldwell encounters.
3. The endings.
4. A full-game QA pass.

## Tripo access (for future sessions)
- **Tool:** the unofficial `Neko-Yukari/tripo-studio-mcp`. Clone it into the scratchpad and run it with `TRIPO_GATEWAY=0` and `TRIPO_STUDIO_STATE=<scratchpad>/tripo/studio-state.json`.
- **Cookie:** the owner's `ory_kratos_session` cookie, from Google Drive file `tripo-session.txt`. Never commit or print it.
- **Balance:** 24,700 credits at the start (premium plan, valid until 2026-12-06). It was 24,185 after the pilot.
- **Studio-state file:** the setup is in `tools/art/README.md`. Fresh sessions also need `bpy` in a Python 3.11 venv and `mesa-vulkan-drivers`.

## Owner decisions
- **Title:** confirmed as "Rimeholt", subtitle "The Winter That Would Not End".
- **House card:** keep the "Figglebottom Productions" house card on boot. Make it sincere and quiet, with no jokes.
- **Story:** it must be genuinely profound about grief and not letting go, told the soulslike way. That means item text, places and fragments, with no AI-writing tics. The rules are in `docs/lore/WRITING.md`.

## Open questions for the owner
- None right now.

## Known breakages
- None yet.
