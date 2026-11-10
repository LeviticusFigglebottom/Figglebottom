# ADR 0013: the endings, and what the world is afterwards

- **Status:** accepted
- **Date:** 2026-11-10
- **Builds on:** ADR 0010 (the `ending_choice` hook), ADR 0006 (data-driven moves)
- **Lore:** `docs/lore/COLDWELL.md` §6, §10; `docs/lore/REACH.md`

## Context

SPEC §2 and WORLD.md §6 give two endings. ADR 0010 left a hook at the spring that sets `ending_<id>` and emits a signal. The endings themselves, the credits, and the world after either of them were not built. The engine has two world states per area, THAW and RIME, and nothing else.

## Options

1. **A third world state** (`SPRING`) with its own layer tag, navmesh and authored dressing in every area. Honest, and far too much: seven generators and the art pass would have to author it.
2. **RIME with hearths that refuse to warm.** Cheap, but the world would still be white and the dead still standing in the river. The Outsong would change nothing the player can see.
3. **The unfrozen ground, lit differently, with nobody in it.** After the Outsong every area presents its THAW layer (open water, no ice, no frost-taken), under a third light profile, with every remembered person left unbuilt.

## Decision

Option 3, and the same idea turned over for the other ending.

- **Flags, nothing else.** `ending_outsong` and `ending_hearth_kept` are World flags, set once by `ending_choice.choose()`. `World.ended()`, `World.spring()` and `World.kept()` read them. A save carries them as it carries every flag; `meta.ending` (save_version 3) puts it on the slot ledger.
- **`World.get_area_state()` answers for the ending.**
  - After the Outsong: THAW everywhere. `set_area_state()` is a no-op.
  - After the Hearth Kept: THAW at the Coldwell, RIME everywhere else.
  - `Game.toggle_free()` is false, and `hearth_flow()` only rests.
- **Spring is a light profile and an absence.**
  - `data/state_profiles.json` gains `spring`; `EnvRig` uses it in place of `thaw` while `World.spring()` is true.
  - `AreaBuilder` does not build THAW people while `World.spring()` is true.
  - RIME spawners and veils are on the RIME layer, which is off.
  - The Rest menu offers *Warm the stone* and answers *The horn is empty.*
- **`EndingDirector`** (`src/core/ending_director.gd`) runs each ending as a list of timed beats. The times are `game.json` `endings`. It takes its own camera, and gives it back.
  - The wave is the existing melt wave, run with `force` because the flag has already changed what `World` answers.
  - `fast` makes every wait one frame, for the suite.
- **The Hearth Kept does not end.** The director stays, the Bearer stays sat, and a kept save resumes there (`EndingDirector.resume_kept`, called from `world_root`). The pause menu works. Nothing else does.
- **The Leadvoice is released by singing.** Her last quarter ignores blades (`p3_blade`); an `Interactable` on her offers *Sing*. That is a new verb on a boss, kept in her subclass.
- **Credits** are `CreditsUI`, a column over the world; the lines are `game.json` `credits`.

## Consequences

- After the Outsong the player walks a world whose THAW dressing (boats drawn up, a feast laid) is still there with nobody at it. That reads as intended: the things are real, the evening is gone. If the art pass wants a true spring dressing later, it has one place to hang it: a `spring` tag in `Area.attach`.
- THAW sheep graze on the Reach after the Outsong. Left as it is.
- A kept save cannot be played on. That is the ending as written in SPEC §2. The other two slots are unaffected.
- The sky shader is not touched: in spring it takes the THAW sky with the `spring` colours.
- `World.set_area_state()` silently refusing after an ending is a trap for tools. The shot harness sets flags before the area builds, so `--flag=ending_outsong` shows spring in any area.
