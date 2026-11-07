# Live handoff: Rimeholt

_Last updated: 2026-11-07 (founding session)_

## State
- **Phase 1 (survey) is done:**
  - `docs/transposition/SURVEY.md`
  - `docs/transposition/ORIGINALITY.md`
  - `tools/banned_terms.txt` and `tools/check_originality.sh`, with the CI workflow `originality.yml`
  - ADR 0001: copy the engine code and strip content
- **Foundation docs are done:** SPEC.md, CLAUDE.md, the task board, STYLE.md and LEXICON.md.
- **In progress:**
  - the engine port and the greybox area `saltfell_steading`
  - the Tripo pilot

## Next exact step
- Land the engine port on main with `tools/test.sh` green, and add screenshots to `docs/screens/`.
- Then run the Tripo pilot (see `docs/art/`).

## Tripo access (for future sessions)
- **Tool:** the unofficial `Neko-Yukari/tripo-studio-mcp`. Clone it into the scratchpad and run it with `TRIPO_GATEWAY=0` and `TRIPO_STUDIO_STATE=<scratchpad>/tripo/studio-state.json`.
- **Cookie:** the owner's `ory_kratos_session` cookie, from Google Drive file `tripo-session.txt`. Never commit or print it.
- **Balance:** 24,700 credits at the start (premium plan, valid until 2026-12-06).

## Owner decisions
- **Title:** confirmed as "Rimeholt", subtitle "The Winter That Would Not End".
- **House card:** keep the "Figglebottom Productions" house card on boot. Make it sincere and quiet, with no jokes.
- **Story:** it must be genuinely profound about grief and not letting go, told the soulslike way. That means item text, places and fragments, with no AI-writing tics. The rules are in `docs/lore/WRITING.md`.

## Open questions for the owner
- None right now.

## Known breakages
- None yet.
