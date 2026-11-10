# Team board: who works where, and how we talk

Rimeholt is built by several Claude sessions at once. This file is the shared base. Read it after `CLAUDE.md` and `CONSOLIDATED.md`.

## Roster

| Name | Where it runs | Session | Owns |
|---|---|---|---|
| **Lead** | cloud | `session_01F3vrUNPtFufos1qRX6SLeD` | `main`, merges, direction, Tripo credits; subagents on its box (art look pass, animation, encounters and endings) |
| **GPU worker** | owner's PC (RX 9070 XT) | `session_01F3vrULYKUDQFNtUuJaVFi3` | real-GPU perf, galleries, full-suite test runs; branches `gpu/*` |
| **QA env** | cloud | see `CONSOLIDATED.md` | full-game end-to-end tests and bug fixes; branches `fix/qa-*` |
| **World-fidelity env** | cloud | see `CONSOLIDATED.md` | building geometry, interiors and lighting, terrain close-up; branches `art/world-*` |

## File ownership

Ownership avoids merge fights. Ask the lead before crossing a line.

| Area | Owner |
|---|---|
| `src/world/building_gen.gd`, interiors, light and reflection probes, `shaders/terrain.gdshader` close-up detail, decals | World-fidelity env |
| Grass and foliage, sky, hearthstone visuals, Tripo props and gables, `src/world/forest.gd`, `scatter.gd` meshes, `material_lib.gd` families | Lead's look-pass agent (`art/look-pass-2`) |
| `src/chars/*`, `data/anim/*`, `tools/anim/*`, player combat clips | Lead's animation agent (`feat/combat-anims`) |
| Shepherd's Reach and Coldwell encounters, endings, credits | Lead's endings agent (`feat/reach-coldwell-endings`) |
| `water.gdshader`, volumetric fog overrides, enemy nav throttle, weather particles | GPU worker (`gpu/perf-2`) |
| `tools/test/*` end-to-end suites, bug fixes anywhere (small, targeted) | QA env |
| Tripo generation (the cookie exists only on the lead's box) | Lead |

## Rules for everyone

- **Branches:** work on your own branch, based on `origin/main` (or the branch the lead names). Never push to `main`; the lead merges.
- **Before every commit:** run `tools/check_originality.sh --all`.
- **Commits:** small and imperative, with the trailers your session was given.
- **Tests:** run the suites you touch, plus `smoke`. The full suite runs in GitHub CI on every push to `feat/**`, `fix/**` and `art/**`. Check it with `gh api repos/LeviticusFigglebottom/Figglebottom/actions/runs?branch=<branch>`.
- **Visual work:** look at your own screenshots before reporting. Renders here are software (lavapipe), so keep them at 1280x720.
- **Writing:** it must meet `docs/lore/WRITING.md`.
- **Money:** only the lead spends Tripo credits.

## Talking to each other

1. **Direct:** send a message to the lead's session id above. Do this when a job is done, when you are blocked, or when you need a decision. Keep it short: the branch, the sha, what changed, what you need.
2. **Durable:** append to `docs/handoffs/live/INBOX_<yourname>.md` on your own branch and push. The lead answers in `docs/handoffs/live/LOCAL_OUTBOX.md` on `main` (one outbox for everyone, newest first, addressed by name).
3. **Before starting each job:** `git fetch`, then re-read `LOCAL_OUTBOX.md` and this file on `origin/main`.
