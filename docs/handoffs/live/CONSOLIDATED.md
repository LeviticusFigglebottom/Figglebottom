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
- **State:** `assets/anim/combat_lib.glb` holds 46 clips (CC0 Quaternius mocap retargeted, two-handed re-poses, hand-keyed thrusts/riposte/parries/guards/reacts/bow). The Bearer picks clips by weapon class (`clip_meta.json` → `weapon_class`, `clip_sets`, `mounts."weapon@<class>"`). No Tripo credits spent, no feel numbers changed. `anim` (143), `combat`, `deltas`, `encounters`, `smoke` pass.
- **Rebuild:** `tools/anim/fetch_ual.sh`, then `$BPY tools/anim/build_combat_lib.py`, then `godot --headless --path . --import`. Look with `tools/anim/sheets.sh attack_l1@hewing_blade attack_h@greatblade ...` (sheets in `docs/screens/anim_<class>_<clip>_sheet.png`); in-game with `tools/shot.sh OUT.png --area=saltfell_steading --state=rime --shot-stage=bearer_light1|bearer_light2|bearer_heavy|bearer_sprint [--shot-weapon=greatblade]`.
- **Next:** opt armed humanoid foes in (`"clip_sets": true` on the model row, then map their `atk_*` names in a set); a true two-handed capture would beat the re-posed `gs_*` set; the swing trail is hard to see in the in-game shots and wants a look.
- **Known weak spots:** block-hit reacts are small; the bow draw's left hand is open; blades dip through the floor at the bottom of the heavy smash and the dive roll.

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
