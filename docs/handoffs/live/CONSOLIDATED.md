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

## Open questions for the owner
1. **Title:** "Rimeholt", subtitle "The Winter That Would Not End". Change it if you prefer something else.
2. **House card:** keep a "Figglebottom Productions" house card on boot (your studio name), or none?

## Known breakages
- None yet.
