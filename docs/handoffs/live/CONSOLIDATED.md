# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State (on main)
- **Phase 1** is done: the survey, originality guard and CI, and ADRs 0001–0003.
- **Engine port** is merged.
  - It contains all systems, renamed, plus the greybox `saltfell_steading`.
  - `tools/test.sh` passes 5 suites with 102 checks.
- **Lore** is done: `docs/lore/WORLD.md`, `SLICE.md`, `WRITING.md` (the story quality bar) and `docs/art/design/roster.md` (about 94 Tripo slots).
- **Tripo pilot** is merged.
  - Assets: the Netmender (boss, rigged), the Rimewalker (enemy, rigged, 6 clips), the hewing blade and the hearthstone.
  - Procedural pieces: walls and a drying rack.
  - Pipeline: `tools/art/`.
  - Spend: 515 credits; the balance is 24,185.
  - The area-diorama experiment concluded: backdrop only.

## In flight (branches)
- `feat/terrain-saltfell` (ready for review): the ADR 0003 terrain system and Saltfell rebuilt as one continuous sea-cliff landscape (ADR 0005).
  - It adds terrain, scatter, hazards and zone titles.
  - `tools/audit_edges.py` replaces `audit_walls.py`.
  - `tools/test.sh` passes 5 suites with 128 checks.
  - Screens: `docs/screens/terrain_*`, `strand`, `cliff_path`, `yard_*`, `longhouse_boss`, `rime_channel`.
  - Regenerate the area with `python3 tools/gen_steading.py`, which also rewrites `data/terrain/*.bin`.
- `art/slice-heroes`: the slice-tier roster through Tripo, plus 14 region concept images. Budget: about 3,500 credits.
- `feat/characters`: ADR 0004, the Mixamo humanoid animation layer. It puts the Tripo models on the enemy and boss, with data-timed contact frames.

## Next exact step
1. Review each branch's screenshots and confirm its tests pass.
2. Merge the branches into main in this order: terrain, then characters, then art.
3. Then build the vertical slice proper:
   - the slice NPC dialogue from SLICE.md goes into `data/npcs.json`
   - the Keepsakes journal
   - armour slots
   - lock-on switching
   - the UI re-skin and house card

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
