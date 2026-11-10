# ADR 0012: Foe attack clips cut to their data windups

- **Status:** accepted
- **Date:** 2026-11-10
- **Decider:** combat animation lead (feat/foe-anims)
- **Follows:** ADR 0004, ADR 0011

## Context

Next to the Bearer's new moveset the foes looked weak. Most plain melee was one Tripo chop (`slash`) rate-scaled to windups of 0.35–1.2 s, or a stiff Euler overlay; quadruped wind-up poses sank in slowly over the whole windup. A long telegraph played as slow motion.

## Decision

Every covered attack gets **its own hand-keyed clip, built to that attack's windup** (`tools/anim/foe_clips.py`, read from `data/combat/enemies.json` at build time), so it plays at 1x:

1. a quick rise into a clear anticipation shape (about a quarter second),
2. that shape **held**, creeping a little further, for as long as the telegraph lasts,
3. a 0.09–0.14 s strike landing exactly on the windup,
4. an overshoot, a held follow-through, and a recovery.

A long windup is a long hold, never a slow swing. Clips are archetypes (hook, backhand, overhead, double slam, thrust, throw, plant, low sweep, cross cut, shield rush, scoop, the Keener's sung shapes, the yoke twist, the three oar strokes) with per-foe amplitude, side and posture, solved on the same IK control rig as the Bearer's keyed clips.

Runtime:

- The build writes its own metadata into `clip_meta.json`: clips `f_<foe>_<attack>` with `contact` = the windup, a clip set `foe_<foe>` whose `"@<attack id>"` keys name them, and `models.<foe>.clip_set`.
- `Enemy._begin_attack` passes `"@<attack id>"` as an alternative to `play_timed`; where it resolves, that clip plays under the attack's usual game name (so `current_clip()` and every test that reads it are unchanged).
- Ordinary foes also take `stagger` → `react_front` and `death` → `fall_back` (the library's real fall). Holdfasts keep their own staggers, endings and signature clips; only their plain melee was replaced.
- Quadrupeds: the wind-up pose is now reached in at most 0.18 s and held, instead of easing in over the whole windup.

## Consequences

- No timing data changed. Changing a windup in `enemies.json` means rebuilding the library (the `anim` suite fails until then: it checks every clip's contact against the data).
- Not covered, left on their existing clips: the Netmender (her clips ride her own hunched idle), signature overlays (`door_fall`, `lift_stone`, `tray_spin`, the Holdfasts' prompt clips), and any foe rows that only exist on `feat/reach-coldwell-endings`.
- The clips are authored on the Bearer's proportions and retargeted by the standard frame; very differently built bodies (the Turfwright's back load) can clip a raised arm into their own mesh.
- Sheets: `tools/anim/foe_sheets.sh --all` writes `docs/screens/anim_foe_<id>_<attack>_sheet.png`.
