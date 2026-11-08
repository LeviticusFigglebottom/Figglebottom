# ADR 0006: Data-driven encounter moves for the slice foes

- **Status:** accepted
- **Date:** 2026-11-07
- **Decider:** encounter and gameplay engineer (feat/slice-encounters)
- **Follows:** ADR 0004 (humanoid layer), SLICE.md §5 and §6

## Context

SLICE.md gives every slice foe a written moveset with telegraphs, and the Netmender three phases with arena changes. The enemy code had five attack types (melee, ranged, summon, nova, shockwave ring), one boss phase gate at `phase2_at`, one strike per attack and no follow-ups. Several written moves do not fit: a stab that lands three times with the third late, a stroke that only a stroke can lead into, a shockwave that runs in a line, a net that snares and hauls, a floor that drags, ridges that stand and can be mended, a hold that is not an attack. The Hearthhound has a quadruped rig with one clip, and the Oarsman needs a weapon that no model carries.

## Decision

Keep one `Enemy` state machine with data-driven attacks. Add only what the slice needs, as data keys and types. Put behaviour that belongs to one foe in a small subclass, chosen by the existing `"class"` key.

- **Generic data keys on any attack:** `phases`, `by_phase` (per-phase overrides), `hits` (strike offsets after the windup), `chain` / `chain_chance` / `chain_only`, `pick: false` (trigger-only), `min_range`, `weight`, `track` (how hard the windup tracks), `breath` (the frost-breath tell: up, forward, held, twice), `telegraph` (a floor glow over the exact hit area: rect, fan or ring).
- **New types:** `line` (an ice strip, optionally leaving an `IceRidge`), `net`, `haul`, `alert`, plus the Netmender's `mend` and `hold`. `nova` gains `nova_kind: frost`.
- **Per-foe timing:** `phase_speed` replaces the hard-coded 1.35× for any foe that sets it, and `_check_phase()` is the phase hook.
- **Subclasses:**
  - `Oarsman`: a procedural ice oar from the left hand through the right, which is the hit volume.
  - `Hearthhound`: threshold, bark, leash and grab, on `QuadRig`.
  - `Netmender`: intro, three phases, net floor and release.
- **Extra states:** `RETURN`, `GRAB`, `INTRO`, `TRANSITION` and `HOLD` join the enum. Subclasses run them through `_st_extra()`.
- **Holds on the Bearer:** `GrabHold` locks control and counts mashes. The hound's shake and the net snare share it, and `player.gd` is unchanged.

## Consequences

- Every SLICE timing lives in `data/combat/enemies.json`, each move with a `_tell` line that quotes its written telegraph. Retuning the fight is a data change.
- A ground-covering move always shows its area on the floor for the length of the windup. What glows is what lands, so the fight can be learned.
- Quadrupeds and the Netmender's special moves are procedural poses until real clips exist. A real clip of the same name replaces a humanoid overlay with no code change (ADR 0004). A quadruped needs a `pose_alias` entry.
- The `encounters` suite covers each behaviour.
