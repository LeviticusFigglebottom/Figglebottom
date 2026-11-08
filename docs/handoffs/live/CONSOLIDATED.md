# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State (on main, 349 checks green)
- **Engine port** (ADR 0001).
- **Mixamo animation layer** (ADR 0004).
- **Combat deltas:** lock switching, sprint attack, armour slots, save_version 2.
- **UI re-skin:** Alegreya, the bone and ember palette, the house card, the Keepsakes journal, and Ingra and Brede's lines word for word.
- **Terrain** (ADR 0003, 0005, 0006):
  - **Saltfell:** the Strand, the cliff path, the yard and the Longhouse.
  - **The Lowe:** the barrow road, the kin-mounds, the bog route and the Open Barrow.
  - **Connections between them:** a pass, plus a drawbridge shortcut.
  - **Living ground cover and weather.**
- **Tripo art** for the slice and the Lowe, plus 14 region concepts.
  - **Credits:** about 4,065 spent; the balance is about 20,635 before the regions 3–7 batch.

## In flight (worktree → branch)
| Worktree | Branch | Work |
|---|---|---|
| `/home/user/fb-enc` | `feat/slice-encounters` | Cast in game (the Bearer, NPCs, the Oarsman, the hound), the Netmender's three phases, death dissolve |
| `/home/user/fb-audio` | `feat/audio-frost` | Music, ambience and foley, plus the frost/melt wavefront |
| `/home/user/fb-art3` | `art/regions-3-7` | Remaining Tripo heroes. Budget about 6,000; it stops if the balance falls below 12,000. |
| `/home/user/figglebottom` | `feat/lowe-polish-kettle` | Lowe RIME polish, then the Kettle Fjord region |
| `/home/user/fb-enc2` | `feat/lowe-encounters` | `docs/lore/LOWE.md`; the Lowe foes' movesets, the Turfwright's three phases and release, Hesk and Aud with their threads; `lowe_encounters` suite; `docs/screens/lowe_enc_*.png`. Touches only the generator's spawner, pickup, npc and hearth lists. |
| `/home/user/fb-lead` | `main` | Lead merges here. The owner has approved the lead merging reviewed, green branches. |

## Next exact step
1. Review each branch's screenshots and confirm its tests pass, then merge.
2. Encounter pass for the Lowe: tune the Turfwright and the Lowe foes' movesets from WORLD.md.
3. Regions 4–7 terrain.
4. A performance pass.

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
