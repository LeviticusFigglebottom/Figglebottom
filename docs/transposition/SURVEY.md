# Survey of the source game, and how it carries over

**Source:** `LeviticusFigglebottom/Regothiga` at commit `a398470` ("Pass 34"). The game inside is called *Vespergard*. It is about 17k lines of GDScript in Godot 4.7, with 84 scripts, 15 areas and 23 headless test suites.

**Target:** *Rimeholt*, in this repo.

This file and `ORIGINALITY.md` are the only files in this repo allowed to name the source's proper nouns. CI excludes `docs/transposition/` from the banned-terms grep for that reason.

How to read the tables:
- **1:1** means the system carries over unchanged in code and tuning.
- **Δ** means it changes, with the reason given.
- **✗** means it is dropped.

---

## 0. Engine, tooling, CI

| Item | Source | Rimeholt |
|---|---|---|
| Engine | Godot 4.7 stable (official binary), Forward+ (Vulkan), GDScript only | **1:1.** |
| Autoloads | `DB, World, Game, StateDirector, AudioDirector, Juice, PauseUI, Shot` | **1:1.** Same roles under the same names. |
| Data | JSON tables for tuning, weapons, movesets, enemies, spells, items, NPCs and areas, read through `DB.tuning("a/b")`. Rule: "combat timing is data, animation is flavour". | **1:1.** This is the backbone of the feel. |
| Level language | `area_builder.gd` compiles area JSON (`fills`, `rows`, `pieces`, `props`, `spawners`, `lanterns`, `fog_gates`, …) at load. Every entry is tagged base, glory or ruin. | **1:1 mechanism, keys renamed** (`hearths`, `frost_veils`, tags `base/thaw/rime`). |
| Asset pipeline | Procedural Blender (`bpy` 4.5) kit generators with a 4 m grid. Vertex colours carry wear, moss and AO. A Godot `MaterialLib` remaps materials by name. | **Δ.** The kit grid, origin and naming conventions and the MaterialLib remap stay. Geometry now comes from greybox, then Tripo AI (approved by the owner; see `docs/art/`). A Blender script now *post-processes* models instead of *authoring* them. |
| Characters | One 17-bone armature with clips written as per-bone Euler deltas in GDScript (`skel_anim.gd`). | **Δ.** Mixamo-compatible 52-bone humanoid skeleton from Tripo's rig, so one animation library drives every humanoid. The data-timed attack windows are kept: animation playback is still rate-scaled so the contact frame lands on the data windup. |
| Tests | `tools/test.sh`: Python audits, then import, then steered-capsule suites `tools/test/*_test.tscn`. About 700 checks. | **1:1 harness.** New suites for new content. |
| Screenshots | `tools/shot.sh` running `xvfb-run` + lavapipe with `--shot`, `--area`, `--state`, `--shot-cam` | **1:1.** |
| CI | `export.yml`: install Godot 4.7, import, export Linux and Windows. **Runs no tests.** | **Δ.** CI also runs the test suites and the originality grep, so main stays green for real. |
| Docs culture | `DECISIONS.md` (D-000…), `ROADMAP.md` with honest ✅/🟡/🩶 grading | **Δ.** Split into ADR files under `docs/decisions/`, plus `SPEC.md` and a live handoff log. The honest-grading habit carries over. |

## 1. Movement

**Source:**
- Run is the default at 5.2 m/s. Sprint is 7.2 (Shift). Strafing while locked on is 4.05.
- Accel 14, turn 11, gravity 22.
- There is **no jump** and no air control.
- A fall failsafe below y = -25 returns you to the last ground position and costs 25% of HP.
- Roll: 24 stamina, 0.46 s, i-frames 0.04–0.32 s, speed eases out over the last 45%.
- Backstep (no direction held): 0.32 s, i-frames 0.03–0.18 s.
- No sprinting while locked on.

**Feel:** heavy, grounded, committal. The dodge carries a recovery tail.

**Rimeholt:**
- **1:1:** every number, plus the no-jump rule. The lack of a jump is part of the posture.
- **Δ:** the unused `walk` tuning key is deleted.
- **Δ (later):** a deliberate *vault* over low walls at marked points may be added. It would be authored, never free-form.

## 2. Stamina

**Source:**
- Pool 80, plus 6 per Endurance point above 8.
- Regen 30/s after a 0.55 s delay. ×0.4 while blocking. None during roll, attack or riposte.
- Any action can start at stamina ≥ 1. Emptying the bar causes a 0.5 s "winded" lockout.

**Rimeholt:** **1:1.** The stat is renamed *Wind*.

## 3. Combat

**Source:**
- **Attacks:** windup, active and recovery come from `movesets.json`. For example, longsword light 1 is 0.26/0.13/0.36, and heavy is 0.50/0.16/0.55 at ×1.7.
  - Input is buffered until `wind + act + rec*chain_from`.
  - A heavy can be cancelled into a roll.
- **Hitboxes:** a hitbox follows the enemy's weapon mesh ("if the sword never touched me, it is never a hit"). Each target is hit once per swing. Arc and wall-occlusion checks apply.
- **Hit resolution order:** immune, then parry, then block, then hit.
- **Block:** front arc of ±66°. Chip damage can never kill.
- **Guard break:** a 0.9 s stagger.
- **Parry:** 0.08 s windup, then a 0.16 s window. A successful parry staggers the enemy (×2.6) and opens a riposte window: ×3.25 damage, unblockable.
- **Bosses:** mostly immune to parry.
- **Player poise:** fixed at 30.
- **Hit-stop:** time scale 0.05 for 0.06–0.14 s. Trauma-based shake. Particles, light flash and swing trails.
- **Flask:** 3 charges, +55 HP, a rooted 1.1 s drink.
- **Difficulty:** three tiers that scale damage dealt and taken (1.25/0.75, 1/1, 0.75/1.25).
- **Spells:** a separate mana pool, 0.7 s cooldown, scaling with Devotion.

**Rimeholt:**
- **1:1:** every timing, the resolution order, the parry and riposte numbers, hit-stop and shake. These *are* the feel.
- **Δ: target switching on lock-on.** The source README promised it but never shipped it. Flicking the stick or mouse past a threshold while locked on moves to the nearest target on that side.
- **Δ: weapon upgrades read `upgrade.per_level` from data.** The source hardcodes 14%.
- **Δ: stat scaling uses `(stat − 8)`.** That way the base build is not secretly +10%.
- **Δ: a real sprint attack.** It gets its own data entry; the source folded it into the light attack.
- **Δ: player poise gains a bonus from worn armour pieces.** Tripo armour is generated as separate pieces, so wearing armour becomes a real choice.
- **Δ: healing is reflavoured as a gourd of hot broth** (*Gourd*). The numbers are unchanged.
- **Δ: spells become *Songs*** sung on *breath* (mana), scaling with *Kinship*. The theme is that songs are kept by remembering people.

## 4. Enemy AI

**Source:**
- **State machine:** `IDLE → ALERT → APPROACH → COMBAT → ATTACK → STAGGER → DEAD`.
- **Aggro:** sight (9–14 m in a 130–170° cone) or hearing (4–8 m), and always line of sight.
  - Taking damage aggros.
  - Enemies ignore a player who is resting.
  - Leash 24–30 m.
- **Movement:** navmesh pathing with 8-ray unstick probes.
- **Facing:** enemies face a lagging target position (about 0.45 s behind), so circling them is rewarded.
- **Positioning:** strafe and reposition every 0.8–1.6 s. Shield users block 45% of the time.
- **Attack choice:** random among attacks that are in range and off cooldown. Tracking stops at 70% of the windup, then the enemy commits.
- **Attack types:** melee, ranged (leads the target by 0.22 s), summon, nova, shockwave (pillars block it).
- **Bosses:**
  - Infinite leash and 360° vision.
  - Phase 2 starts at 50–55% HP, with ×1.35 speed and phase-2-only moves.
- **Mirror boss:** one boss fights like the player. It rolls, blocks, retreats after 3 hits, and punishes flask drinking.

**Rimeholt:**
- **1:1:** the whole state machine and every attack type.
- **Δ:** add an *echo-lag* tell (frost breath streaming from the head bone) that shows where an enemy is facing. It helps readability without changing the timing.
- **Δ:** the "punishes healing" behaviour becomes a reusable flag (`punish_heal`) instead of boss-specific code.

## 5. Death and checkpoint loop

**Source:**
- On death the screen shows "FORGOTTEN". All carried currency is left as one recoverable ghost at the death spot. A new death replaces the old ghost, which is lost.
- Respawn after 2.8 s at the last rest site, with everything restored.
- Enemies respawn on death and on rest, except spawners marked `dead_once`.
- The dropped currency persists across world-state changes.

**Rimeholt:**
- **1:1:** the rules.
- **Δ, theme only:** the death splash reads *STILLED*.
  - The currency is *warmth*.
  - The ghost is a *Breathmark*: your last breath, frozen in the air, which you walk into to take back.

## 6. Levelling and stats

**Source:**
- Level cost is `round(60 × 1.22^(L−1))`. Levelling happens only at rest sites, +1 stat per level.
- Stats: Vigor (+12 HP), Endurance (stamina), Strength, Dexterity, Devotion (scaling), Grace (mana).
- Weapon upgrades go up to +5 using an upgrade material, done by an NPC.

**Rimeholt:**
- **1:1:** the cost curve and the levelling flow.
- **Δ: stats are renamed** Heart, Wind, Might, Craft, Kinship, Lungs.
- **Δ: the upgrade material is *bog-iron*,** handed to a smith NPC.

## 7. The two-state world (the source's signature)

**Source:**
- **Layers:** each area has a Base layer plus a *glory* layer (the remembered radiant past: warm, NPCs, safe) and a *ruin* layer (the present: cold, enemies). Each layer has its own navmesh and collision.
- **Rules:**
  - A first visit is in glory.
  - The first rest forces ruin until the area's boss is dead.
  - After that the player can toggle at will.
- **The flip:** a 6 s shader wavefront driven by global uniforms. It morphs base geometry and dissolves state-only meshes, with 900 particles, a toll sound and a screen shake.
- **Lighting:** per-state profiles. Glory is a warm sun at energy 2.05 with amber fog. Ruin is a cold blue sun with denser fog.

**Rimeholt:**
- **1:1 mechanism:** layers, dual navmesh, the rest-site flip rule and the shader wave all stay. The owner asked that game feel and visual mood carry over, and this mechanic *is* the source's feel.
- **Δ, meaning (the core originality move):** the two states are **THAW** and **RIME**.
  - **THAW** is the last midsummer evening before the frost, remembered: long amber light, the steading full of people.
  - **RIME** is the frozen present: blue, still, and walked by the frost-taken.
  - The source's glory/ruin is about *fallen grandeur*. Rimeholt's thaw/rime is about *grief*. The frost is a refusal to mourn, held in place by the **Holdfasts** (the bosses). A Holdfast is not a monster. It is someone who could not let a person go. Beating one does not "restore" anything. It lets that place *move on*, and after that you may still visit the remembered thaw, but only as memory.
- **Δ, the wave:** the wavefront edge becomes a frost line or a melt line instead of a burning edge. Particles are snow and frost motes, or pollen and warm dust. The sound is the breath and ice-crack of a wind instrument, not a bell.

## 8. Loot and inventory

**Source:**
- A flat `item_id → count` dictionary. A 5-slot hotbar. One attuned spell.
- No armour system. No random drops.
- Hand-placed one-time pickups with lore text.
- A drag-and-drop satchel UI with two leaves.

**Rimeholt:**
- **1:1:** hand-placed, sparse, lore-bearing loot, and the UI flow. The containers are renamed *Pack* and *Belt*.
- **Δ:** add **armour slots**: head, body, hands and legs. Each piece adds poise and absorption with a weight cost. Tripo generates armour as separate pieces, which makes this cheap, and it adds build depth the source lacked.

## 9. Dialogue

**Source:** a bottom-centre panel with a name plate, then lines, then a service menu (upgrade, flask_up, buy, deliver, dig) gated by flags. There are no dialogue trees. Every line was voiced (ElevenLabs).

**Rimeholt:**
- **1:1:** the panel and the line-then-services flow.
- **✗:** voice files. All lines are new and unvoiced at first.
- **Δ:** NPCs exist only in THAW. They are memories, and some *know* it.

## 10. Quests

**Source:** no quest system. Quests are made of flags, service gates and scripted puzzle nodes. The roadmap admits that "questlines [are] still absent".

**Rimeholt:**
- **1:1:** flags and gates, plus the generic scripted-node hook.
- **Δ:** a **Keepsakes journal**. Each questline is a short chain of flag steps shown as journal lines, so threads stay readable without quest markers.
- **✗:** every source-specific puzzle (bell rings, statues, chimes, votive stands, trials, lights-out, Simon-says). New puzzles are designed fresh.

## 11. World structure

**Source:** 15 areas in a graph of compass and up/down links. Shortcuts, fog gates in front of bosses, and a 360° skyline backdrop. Some areas are authored by Python generator scripts. Static wall and prop audits keep areas sealed.

**Rimeholt:**
- **1:1:** the area graph format, generator-script authoring, the audits and the backdrop ring.
- **Δ:** a new world, with mountain steadings, fjord shelves and a great timber hall. The scope is in `SPEC.md`.

## 12. Saves

**Source:** 3 JSON slots holding per-area `{state, cleared, flags}`, global flags, the dropped currency, the last rest site, a player snapshot and slot metadata. Autosaves at rests, transitions, pickups and death.

**Rimeholt:**
- **1:1.**
- **Δ:** a `save_version` field with a migration hook from day one.

## 13. UI and UX

**Source:**
- Gold-on-black serif menus with a ◆ selection marker.
- HUD:
  - top-left: crest, HP, stamina and mana bars
  - bottom-left: flask count
  - bottom-right: currency
  - hotbar
  - boss bar with a damage ghost
  - floating enemy bars
- Area title cards. Pause menu with volume, FOV and quality settings. A three-difficulty picker. A rest menu.
- A joke splash card and a joke credits sequence (troll face, fart audio).

**Rimeholt:**
- **1:1:** HUD layout and menu flow.
- **Δ: palette** is bone-white and ember on near-black, with a hand-cut serif.
- **✗:** joke splash and credits. They clash with a sincere tone.

## 14. Camera

**Source:**
- SpringArm 3.6 m with a 0.45 m probe, pivot at 1.55 m, shoulder offset (0.35, 0.25).
- FOV 62, +6 when sprinting, −26 when aiming. Pitch −1.15…0.55.
- Lock-on: 16 m range in a ±63° cone, scored as `dist + angle·6`, with line of sight. Aims at the chest. Smooth yaw and pitch. A 60 px flick breaks the lock.
- Trauma shake and an FOV punch.

**Rimeholt:**
- **1:1:** every number.
- **Δ:** target switching on lock-on (§3).

## 15. Audio

**Source:**
- Buses: Master, Music, Ambience, SFX and UI.
- Two-player music crossfade with per-state music and ambience. Boss hymns duck the ambience.
- SFX synthesized in pure Python (`synth.py`). Music and voice from ElevenLabs.

**Rimeholt:**
- **1:1:** buses, crossfade and ducking.
- **Δ:** new compositions. THAW gets fiddle, drone and frame-drum colour. RIME gets breath, ice and a low bowed drone. Foley stays synthesized.
- **✗:** all source music and voice.

## 16. Rendering and post-processing

**Source:**
- `gothic.gdshader`: PBR with a toon-ish ramp, triplanar detail, wear/moss/AO from vertex colours, and the state morph plus wavefront.
- Glass, flame, fog-gate, water, trail and sky shaders.
- Post-process: vignette, low-HP pulse, flash and dither.
- ACES tonemap, volumetric fog, glow. SSAO, SSR and SDFGI tiers by quality setting.

**Rimeholt:**
- **1:1:** the pipeline, the tonemap, fog and the post stack.
- **Δ: the shader renames to `hall.gdshader`.** Its *rime* branch adds frost and hoar crust (driven by height and normal) instead of moss and cracks. Its *thaw* branch adds warm wood sheen.
- **Δ: textures are Tripo-baked PBR maps.** The material lookup by name stays.
- **Mood, 1:1 in spirit:** warm low sun against cold blue, painterly PBR, volumetric light.

---

## Known source gaps fixed in transposition

- Lock-on target switching.
- `upgrade.per_level` is ignored in favour of a hardcoded value.
- Raw-stat scaling.
- No sprint attack.
- Fixed player poise.
- No quest journal.
- CI runs no tests.
- A decisions document with stale entries (audio sourcing).
