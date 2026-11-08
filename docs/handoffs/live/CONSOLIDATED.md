# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State (on main)
- **Engine and systems:** ported (ADR 0001).
- **Lore and roster:** done.
- **Tripo pilot:** merged.
- **Mixamo animation layer:** merged (ADR 0004). The Rimewalker and the Netmender use Tripo models in the game, and the Rimewalker attacks with ice-club hands.
- **Terrain system (ADR 0003, 0005):** Saltfell is one continuous sea-cliff landscape, with the Strand → switchback cliff path → yard → Longhouse.
  - There is a gully shortcut to the boat-shed and a frozen-channel route in RIME only.
  - A Lowe vista sits across a lethal ravine.
  - The edge audit passes.
- **Tests:** `tools/test.sh` runs 6 suites, 173 checks, all green.

## In flight (worktree → branch)
| Worktree | Branch | Work |
|---|---|---|
| `/home/user/fb-art` | `art/slice-heroes` | Slice roster through Tripo, 14 concept images, and Tripo feature evaluation (multiview, segment, prompt-animations for roll/block/parry/drink/rest) |
| `/home/user/figglebottom` | `feat/terrain-polish` | Natural cliff and ravine shapes, procedural turf-roof buildings, terrain known issues |
| `/home/user/fb-combat` | `feat/combat-deltas` | Lock-on switching, upgrade data, (stat−8) scaling, sprint attack, armour slots, `save_version` |
| `/home/user/fb-ui` | `feat/ui-keepsakes` | UI re-skin and OFL font, house card, Keepsakes journal, Ingra and Brede lines verbatim from SLICE.md |
| `/home/user/fb-art3` | `art/regions-3-7` | Tripo heroes for Kettle Fjord, Tarnhall, Thornwold, Shepherd's Reach and the Coldwell: 5 Holdfasts (multiview, extreme, 3 prompt clips each), 12 enemies, 6 NPCs, 5 Bearer armour sets, 8 weapons/props, 10 landmarks; 5,300 credits (balance 15,335). Lineups `art_lineup_<region>.tscn`; screens `docs/screens/art_<region>_*`; results in `docs/art/design/roster.md`. Not merged. |
| `/home/user/fb-lead` | `main` | Lead merges here |

## Next exact step
1. Review each branch's screenshots and confirm its tests pass, then merge it.
2. Next wave:
   - Netmender fight per SLICE.md §6: three phases, real moves, a frost-veil arena.
   - The Oarsman and Hearthhound get their Tripo models. The hound needs a quadruped rig and its own AI tuning.
   - Real music.
   - Then the region tier: the Lowe.

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
