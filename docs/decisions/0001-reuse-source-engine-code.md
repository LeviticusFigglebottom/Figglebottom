# ADR 0001: Copy the source's engine and system code, strip all content

- **Status:** accepted
- **Date:** 2026-11-07
- **Decider:** founding lead

## Context

The owner wants Rimeholt to keep the source game's engine, mechanics, game feel, camera, combat timing, progression structure, UI/UX conventions and visual mood more or less 1:1. Everything authored (story, world, names, text, music, art) must be new.

The survey (`docs/transposition/SURVEY.md`) shows where the source's feel lives:

1. **In data and code, not in animation or art.** Attack windup, active and recovery windows, i-frames, stamina costs, hit-stop durations and camera constants are JSON tuning read by one explicit player state machine. Animation playback is *scaled to the data*.
2. **In a small number of tightly coupled systems.** The player state machine, the hurtbox resolution order, the enemy state machine with lagged facing and commit-at-70% tracking, the juice autoload, the camera rig, and the two-state area system with its shader wave all fit together.
3. **In a headless test and screenshot harness** that steers a capsule through the real game.

## Options

- **A. Rebuild clean** from the survey's numbers. This risks losing the dozens of small interactions that are not written down: buffered input timing, the one-frame dialogue release, stuck-probe heuristics, stagger refills, the order of hit resolution. It would take weeks to re-tune by feel, with no ground truth.
- **B. Copy the engine and system code, strip content, rename.** It preserves the feel exactly, because it *is* the same code running the same numbers. The cost is a careful content strip and rename, and an originality grep to keep it honest.

## Decision

**Option B.**

**Copied:**
- `src/` systems: core, player, combat, enemies, world framework, UI framework, debug.
- `shaders/`.
- The data *schemas* and the *combat tuning*: movesets and generic weapon numbers.
- The test and screenshot harness.
- The audit scripts.

**Rewritten or renamed:**
- every identifier, string, comment and data key carrying a source name, following the lexicon in `SPEC.md` (glory→thaw, ruin→rime, vg_→rh_, and so on)
- area JSON files, which are all new
- NPCs, items and lore, which are all new

**Dropped:**
- the source's areas, NPCs, quests and puzzles
- all audio except generic foley synthesis code
- the procedural gothic Blender kit
- painted icons
- voice lines
- the joke splash and credits

**Replaced:** greybox primitives first, then Tripo-generated assets processed by committed scripts under `tools/`.

## Consequences

- Rimeholt plays like the source on day one. Changes to feel become deliberate, reviewable diffs against known numbers. Each one is recorded in SURVEY.md's Δ rows or in a later ADR.
- The originality guard (`tools/check_originality.sh`, CI) is mandatory: copied code is exactly where stray source names hide.
- Character animation moves from the source's 17-bone Euler clips to a Mixamo-compatible 52-bone rig. This needs a new animation layer (`AnimationTree` + humanoid retarget) under the unchanged "timing is data" rule. That rule is the one place the port is not 1:1 in code, and it gets its own ADR when built.
- Future fixes to the source do not flow here automatically. That is fine, because the two games diverge from this commit on.
