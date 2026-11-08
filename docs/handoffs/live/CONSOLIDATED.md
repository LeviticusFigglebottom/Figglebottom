# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State (on main, 456 checks across 11 suites, all green)
- **The vertical slice (Saltfell) is feature-complete:**
  - **The Bearer:** the Tripo model, with real dodge, drink, rest and parry clips.
  - **NPCs:** Ingra and Brede, with their lines verbatim and both Keepsakes threads.
  - **Enemies:** Rimewalkers (ice-club fists), the Oarsman (ice oar), and the Hearthhound (threshold guard, bark, grab).
  - **The Netmender:** a three-phase fight with a frozen-net arena. Her release flow runs flag, then card, then needle, then Long Hearth, then Outsong.
  - **Presentation:** the UI re-skin and the house card, composed music and ambience, foley, and the frost/melt wavefront.
- **The Lowe:**
  - **World:** terrain, the bridge shortcut, and the bog route, with Tripo models placed.
  - **Encounters:** pending, on the branch below.
- **Tripo:** about 4,065 credits spent. The balance was about 20,635 before the regions 3–7 batch; check the ledger.
- **Audio has never been listened to.** The owner should play it and give feedback.

## In flight (worktree → branch)
| Worktree | Branch | Work |
|---|---|---|
| `/home/user/fb-qa` | `fix/slice-qa` | Full-slice end-to-end test, bug fixes, a player-eye screenshot pass, and perf. Notes go in `docs/qa/` |
| `/home/user/fb-enc2` | `feat/lowe-encounters` | `docs/lore/LOWE.md`, the Lowe foes' movesets, the Turfwright's three phases, Hesk and Aud's lines and threads |
| `/home/user/figglebottom` | `feat/lowe-polish-kettle` | Lowe RIME ground cover and sod stacks, then the Kettle Fjord region |
| `/home/user/fb-art3` | `art/regions-3-7` | Remaining Tripo heroes. It stops if the balance falls below 12,000 |
| `/home/user/fb-lead` | `main` | Lead merges here. The owner approved the lead merging reviewed, green branches |

## Next exact step
1. Review and merge each branch above once its tests pass.
2. Then:
   - Kettle Fjord encounters
   - the remaining regions' terrain and encounters (Tarnhall, Thornwold, Shepherd's Reach, the Coldwell)
   - the two endings
   - an export test on real hardware by the owner

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
