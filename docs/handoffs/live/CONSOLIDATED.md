# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State (on main fd6bf02: 850 checks, all green)
| Region | World | Encounters and writing |
|---|---|---|
| Saltfell (vertical slice) | ✅ | ✅ |
| The Lowe | ✅ | ✅ |
| Kettle Fjord | ✅ | ✅ |
| Tarnhall | ✅ | ✅ (the Host, seated guests, Lusse, Ottar) |
| Thornwold | ✅ (THAW/RIME hedge maze) | ✅ |
| Shepherd's Reach | ✅ | ✅ on `feat/reach-coldwell-endings` |
| The Coldwell | ✅ | ✅ and both endings, on `feat/reach-coldwell-endings` |

- **Tripo balance:** about 14,280, before the look pass.
- **Owner feedback:** procedural assets clash with the Tripo art. The look pass fixes this: CC0 PBR textures, UVs, Tripo-textured buildings, Tripo rocks and trees.
- **Test flake:** `kettle_encounters` ring-cut flaked under load. The test is now isolated: it closes old ice, puts other moves on cooldown, and waits for the ring to open.

## feat/reach-coldwell-endings (2026-11-10): the story is finished
Worktree `/home/user/fb-end`, branched from `feat/integration-1110`. Not merged; CI runs the full suite on push.

- **Shepherd's Reach** (`docs/lore/REACH.md`): Drover, Frost-ram, the Fellcaller (three phases, the flock down a strip), Old Calder and Sigga, the boots, the fold-tally, the slope lying down, the scene after.
- **The Coldwell** (`docs/lore/COLDWELL.md`): Upwalker, the Unsung, the Leadvoice. She has no strike and is sung out in three verses.
- **The endings** (ADR 0011): The Outsong and The Hearth Kept from the choice at the spring; `CreditsUI`; `World.spring()` / `World.kept()`; save_version 3.
- **The seven pieces** of WORLD.md §4 are all placed (COLDWELL.md §8). Three were missing and went in through their generators: the child's mask (Saltfell), the tracks in the ice (Kettle), the wool on the latch (Tarnhall).
- **Suites:** `reach_encounters` (89), `coldwell_encounters` (82), `endings` (83). Also run green here: smoke, reach, coldwell, keepsakes, steading, kettle, tarnhall, audio, release_scenes, anim, encounters, thornwold_encounters.
- **Screens:** `docs/screens/reach_enc_*.png`, `coldwell_enc_*.png`, `ending_*.png`.

**Next exact step:** merge into integration once CI is green, then a full-game QA pass from a fresh save to each ending:
```
tools/test.sh reach_encounters && tools/test.sh coldwell_encounters && tools/test.sh endings
tools/shot.sh docs/screens/ending_strand.png --area=saltfell_steading --state=thaw --flag=ending_outsong --enc-shot=ending_strand
```

**Open questions for the owner**
- A Hearth Kept save cannot be played on: it opens on the Bearer sat at the spring and stays there (SPEC §2 as written). Say if you would rather it offered a way back to the title's "begin anew" from that view.
- After the Outsong the world shows its THAW dressing with nobody in it, under a grey light (ADR 0011, option 3). A true spring dressing would be an art pass.
- Not wired: the Shepherd's Crook weapon (`shepherd_crook.glb`) and the `bearer_fleece` body. The fleece is an armour item only.

**Known breakages**
- `tools/audit_edges.py` reports 160 unclassed grid edges on the Reach's north boundary. It did so before this branch (same count on `feat/integration-1110`).

## In flight (worktree → branch)
| Worktree | Branch | Work |
|---|---|---|
| `/home/user/fb-qa` | `fix/slice-qa` | Merge main in, then body collision, enemy draw calls, title hitch, the tide wall |
| `/home/user/fb-look` | `art/unified-look` | The whole-world material/texture pass, plus trees and hedges |
| `/home/user/figglebottom` | `feat/reach-coldwell` | Shepherd's Reach and the Coldwell worlds, the ending hook, the THAW sky |
| `/home/user/fb-enc5` | `feat/release-scenes` | NPC sit support; the Lowe, Kettle and Tarnhall post-release THAW scenes |
| Owner's PC | `gpu/*` | `LOCAL_GPU_TASKS.md`. Nothing has been received yet |

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
