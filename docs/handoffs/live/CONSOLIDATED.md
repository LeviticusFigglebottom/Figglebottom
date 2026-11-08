# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State (on main f3d7b88: 714 checks, all green)
| Region | World | Encounters and writing |
|---|---|---|
| Saltfell (vertical slice) | ✅ | ✅ |
| The Lowe | ✅ | ✅ |
| Kettle Fjord | ✅ (walls, dressing, see-through ice) | ✅ |
| Tarnhall | ✅ | in flight |
| Thornwold | in flight | todo |
| Shepherd's Reach | todo | todo |
| The Coldwell | todo | todo |

- **Tripo:** every region's hero art is on main. The balance is 15,335.
- **Controller:** the Bearer now steps up to 0.35 m and snaps down stairs.
- **Disk:** keep it clean. Remove the worktrees of merged branches with `git worktree remove --force`. Raw downloads can be fetched again by Tripo project id.

## In flight (worktree → branch)
| Worktree | Branch | Work |
|---|---|---|
| `/home/user/fb-qa` | `fix/slice-qa` | Full-slice end-to-end test, fixes, perf |
| `/home/user/figglebottom` | `feat/thornwold` | Tarnhall light and a second seam, then the Thornwold region |
| `/home/user/fb-enc4` | `feat/tarnhall-encounters` | `TARNHALL.md`, the Host's three phases, the hall doors |
| `/home/user/fb-art4` | `art/npcs-release-scenes` | THAW NPC models (Halla, Sten, Arne and the twins, Pell and Ivo, the child Bearer) |
| Owner's PC | `gpu/*` | Jobs in `LOCAL_GPU_TASKS.md`. Replies go via `LOCAL_OUTBOX.md`; the worker writes to `LOCAL_INBOX.md` on `gpu/inbox` |

## Next exact step
1. Review and merge branches as they land.
2. Then Shepherd's Reach and the Coldwell, world first, then encounters.
3. The endings: the Outsong and the Hearth Kept.
4. Release-scene staging using the new NPC models.

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
