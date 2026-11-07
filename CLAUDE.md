# CLAUDE.md: operating rules for Rimeholt

Rimeholt is a third-person action RPG in **Godot 4.7 (Forward+, GDScript only)**. Read these first:
- `SPEC.md`: what the game is
- `docs/handoffs/live/CONSOLIDATED.md`: where we are right now, and the next exact step
- `docs/TASKS.md`: the task board

## 1. Originality guardrails (non-negotiable)

- This game reuses the engine and system *code* of the owner's earlier game (ADR 0001). It reuses **no** content: names, story, lore, text, areas, characters, enemies, items, music or art.
- **Banned terms:**
  - The list is in `tools/banned_terms.txt`. Run `tools/check_originality.sh --all` before every commit; CI enforces it.
  - Never weaken the list. Reword instead.
  - `docs/transposition/` is the only place allowed to name the source.
- **Before inventing a proper noun,** check it against `docs/transposition/ORIGINALITY.md`, which also lists banned *motifs* and *beats*. Then add it to `docs/lore/LEXICON.md`.
- **Other games:** draw on genres only. Never use names, terms or iconic mechanics from Fallout, Elder Scrolls, Souls games, Elden Ring, Bloodborne, or any other specific game.
- **The source repo is read-only reference.** Never push to it.

## 2. Coding standards (carried over from the source)

- **Combat timing is data, animation is flavour.** All windups, active windows, recoveries, i-frames, costs and hit-stops live in `data/**/*.json` and are read through `DB.tuning("a/b")`. Animation playback is rate-scaled to land on the data. Never hardcode a feel number in a script.
- **The player and enemies are explicit state machines** (`enum S {…}`). Add states; don't bolt on booleans.
- **Two-state areas:** every authored node is tagged `base`, `thaw` or `rime`. Route differences are real collision and navmesh differences.
- **Areas are JSON** compiled by `src/world/area_builder.gd`. Large areas are produced by committed generator scripts (`tools/gen_*.py`), never hand-edited output.
- **GDScript style:**
  - static typing where practical
  - `snake_case`
  - one class per file
  - short comments that say *why*
- **Verification:**
  - No visual work is done blind. Take a screenshot with `tools/shot.sh` and look at it.
  - Logic gets a steered-capsule test in `tools/test/`.
- **Assets:**
  - Every asset has a row in `assets/PROVENANCE.md`.
  - Every processing step is a committed script under `tools/`.
  - Raw Tripo downloads go in `raw/` (gitignored).
  - Spend on Tripo is logged in `docs/art/TRIPO_LEDGER.md`.
  - Never commit secrets: the Tripo cookie lives only in the session scratchpad.

## 3. Commands

```
tools/test.sh [suite]          # audits + import + headless test suites (must pass before merge)
tools/shot.sh OUT.png --area=saltfell_steading --state=rime [--shot-cam=x,y,z,yaw,pitch]
tools/check_originality.sh --all
```

Godot 4.7 is the official binary. CI downloads it, and locally you can put it on `PATH` as `godot`. Headless rendering for screenshots uses `xvfb-run` with lavapipe.

## 4. Task board and handoffs

- **Task board:** `docs/TASKS.md`. Statuses are `todo`, `doing (who/branch)` and `done (commit)`. Pick from the top of `todo`.
- **Decisions:** `docs/decisions/NNNN-title.md` (ADR: context, options, decision, consequences). Decide and record the decision. Ask the owner only about irreversible choices or money (Tripo credits, paid APIs).
- **Live handoff log:** `docs/handoffs/live/CONSOLIDATED.md`. Update it after every milestone with:
  - the current state
  - the next exact step (commands included)
  - open questions for the owner
  - known breakages

  A fresh session must be able to resume from the repo alone.
- **Session summaries:** older ones move to `docs/handoffs/archive/YYYY-MM-DD-*.md`.

## 5. Git workflow

- `main` is always green: tests, originality check and export all pass.
- Work on short branches, `feat/…`, `fix/…`, `art/…` or `docs/…`, and merge to main with a fast-forward or merge commit once green.
- Never force-push and never rewrite published history.
- Commit small, with imperative messages ("Add frost veil to steading yard").
- Push often: `git push -u origin <branch>`.
