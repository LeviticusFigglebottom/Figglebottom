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

## Update: the Lowe (feat/lowe-encounters)

- **New generic keys:**
  - `aim: "back"` strikes behind the body (the Turfwright's Back-drop).
  - `at_target: true` lays a `line` strike centred on the Bearer at commit (Stack a sod).
  - `ridge.style` dresses a ridge: `ice` (knots), `sod` (cut turf in courses) or `stone` (a cairn).
- **Floor tells drape** over the ground they cover. On the Lowe's slopes a flat glow sank into the turf. They are also a little stronger, so they read on RIME snow.
- **Subclass:** `Turfwright` (`src/enemies/turfwright.gd`) runs the intro, the three phases, the bay walls (`arena_walls`), the guard of the door (`guard_r`), the last turf (`hold`) and the release.
- **Idle poses:** `sit_up` (the barrow dead) and `kneel` (a keener at a closed door) join `sit`.
- The `lowe_encounters` suite covers each behaviour.

## Update: Kettle Fjord (feat/kettle-encounters)

- **`break_ice`** opens a disc (centred on the Bearer with `at_target`) or a ring round the body. The floor becomes black water for `life` seconds. It is a `BrokenIce` node (`src/enemies/broken_ice.gd`) that holds runtime `HazardVolume` kind `"thin"` volumes, so standing on it for `sink` seconds takes the Bearer. `lead` opens a second hole ahead of a running Bearer.
- **`hook`** catches whatever stands in a strip, holds it (`snare`, mash to break, a `GrabHold`), drags it to `haul_to` metres from `_hook_anchor()` (the body by default; the Ice-Cutter's hole), then queues `then`. The Netmender's net predates it and keeps its own code.
- **`flank`** keeps a pair of foes strafing to opposite sides.
- **Floor tells** gain an `annulus` shape.
- **Release:**
  - `release_seal` closes the Holdfast's own hole: its thin volumes and water go, and new ice is laid over. A rebuilt area's spawner re-seals it.
  - `release_drop.at_seal` sets the drop in the middle of that hole.
  - `release_drop.set_flag` raises a Keepsakes flag on taking it.
- **Subclass:** `IceCutter` (`src/enemies/ice_cutter.gd`). Base `Enemy` serves the quadruped Sledge-dog, as `QuadRig` poses with no subclass.

## Update: Tarnhall (feat/tarnhall-encounters)

- **Cracks before ice breaks** (lead feedback on Kettle): every `break_ice` attack lays an `IceCrack` (`src/enemies/ice_crack.gd`) `crack_lead` seconds (default 1.0) before the strike. Dark cracks spread out from where it will open, and follow the aim until it commits. The sink time is unchanged.
- **`sweep`** hits whatever stands in a fan round the committed aim (`"sweep": {"radius", "arc", "inner"}`; arc 360 is a ring). `shove` slides the Bearer outward. If a wall or bench stops the slide, he is pinned (`pin` seconds, mash to break, a `GrabHold`). Fan telegraphs take an inner radius as a third size.
- **`lob`** throws something that lands `flight` seconds after the strike on the committed spot (`at_target`). The ring tell holds through the flight. `lead` throws a second where the Bearer has actually been running during the windup.
- **`pool`** pours a `FrostPool` (`src/enemies/frost_pool.gd`). It spreads `from`→`to` metres over `grow` seconds, its edge glowing as it spreads, and lasts `life`. Frost bites every `tick`.
- **`block_chance`** tunes how often a foe with a `block_arc` keeps its shield up while circling.
- **Release:** `release_gates` lifts the named shortcut bars (`ShortcutGate.lift_bar()`) and sets their area flags, so a rebuilt area builds them open. An opened gate on a state layer keeps zero collision across layer toggles.
- **Subclass:** `Host` (`src/enemies/host.gd`). His adds are the seated feast-guest stills the area already lays: he raises them out of their places (a `sit_feast` pose that rises), and he refills the horns in front of the empty seats. `hold` is reused for Pour.
