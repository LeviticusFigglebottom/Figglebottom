# RIMEHOLT: The Winter That Would Not End

*A third-person action RPG about grief, frost and the songs we owe the dead.*

## 1. Pillars

1. **Every swing is a promise.** Combat is committal, readable and stamina-gated, with tight dodge and parry windows. The feel comes from the source engine 1:1. See `docs/transposition/SURVEY.md`.
2. **Two times, one place.** Every area exists as **THAW**, the last midsummer evening as it is remembered, and as **RIME**, the frozen present. You explore one and fight through the other in the same space.
3. **Letting go is the victory.** Bosses are not conquered. They are *released*. Progress means places are allowed to move on, and the game is honest about what that costs.
4. **Sparse, sincere, specific.** Every item, line and room says something true about the people who lived there. No filler loot, no quest markers, no irony.

## 2. Premise

The highland of **Rimeholt** is a country of fjord-cut mountains, sea-cliff steadings and great timber halls. Its people keep fire in every hearth. They have one rite above all others, the **Outsong**: the night after a burial, the household sings the dead *out*, masked, so the dead do not see who is letting them go.

One midsummer a coughing sickness came up the fjords. It took the old and the very young. Family by family, the steadings could not bear to sing. They kept the dead at the hearth instead: one more night, then one more. The warmth of the world went into keeping them. The frost came in the middle of summer and never left.

The people who refused to let go became **Holdfasts**. Their grief is now a place: frozen and terrible, and stubbornly loving. The unmourned dead, and the living who froze waiting beside them, walk the steadings as the **frost-taken**.

You are **the Bearer**. You were sent down the coast as a child before the sickness reached your steading. You come home grown, carrying the last live coal in Rimeholt in a horn at your hip. At each **Hearthstone**, a cold household hearth, you can set the coal. The stone *remembers*, and the place returns to that last warm evening (THAW). Or you let it lie still, and you face the present (RIME).

To end the winter you must sing the Outsong for each Holdfast's dead. The last Holdfast is the one who stopped the singing first. The game never asks you to hate them.

**Endings (full game).**
- *The Outsong*: sing for the one you yourself could not let go. True spring comes, and the remembered evening dissolves forever. You can never return to THAW.
- *The Hearth Kept*: keep the coal. You stay in the remembered evening, the world stays frozen, and you are the newest Holdfast.

## 3. Tone

Quiet, cold and tender. Long silences. People in THAW are warm, funny and unaware, or half-aware, that they are memories. RIME is not evil. It is *stuck*. There is no grimdark cruelty for its own sake, and no jokes that break the spell. The game is sincere about grief, in the way folk ballads are.

## 4. Art direction (detail in `docs/art/STYLE.md`)

- **Look:** painterly-real northern craft. Adzed timber, turf roofs, dry-stone terraces, carved post-ends, wool, felt, horn, wrought iron, and soapstone.
- **THAW:** a long low amber sun, pollen, woodsmoke, warm wood sheen.
- **RIME:** hoarfrost crust, blue-violet shade, held breath, ice that has *grown* over things.
- **Characters:** heavy layered silhouettes, hooded and cloaked. Everyone of standing wears a **carved wooden mourning mask** in this culture: at the Outsong, at funerals and in war. The frost-taken wear masks rimed white. This is both fiction and pipeline: masks and hoods avoid needing facial animation (Tripo gotcha, `docs/art/STYLE.md`).
- **Mood:** the same as the source, translated. Warm low sun against cold blue, volumetric light and painterly PBR.

## 5. Core loop

```
Hearthstone (rest, level, Gourd refill, set THAW/RIME)
  → explore in THAW (people, keepsakes, routes, lore)
  → first rest locks the area in RIME until its Holdfast is released
  → fight through RIME (frost-taken, shortcuts, the frost veil)
  → die → STILLED → your warmth hangs as a Breathmark → one chance to take it back
  → release the Holdfast (boss) → THAW/RIME toggles freely at that hearth
  → the Keepsakes journal advances; the next steading opens
```

## 6. Lexicon (systems)

Full lexicon: `docs/lore/LEXICON.md`.

| Concept | Rimeholt name |
|---|---|
| world states | **THAW** / **RIME** (toggle verbs: *warm* / *still*) |
| rest site | **Hearthstone** |
| currency | **warmth** |
| dropped currency | **Breathmark** |
| death text | **STILLED** |
| healing | **Gourd** of hot broth (charges) |
| magic | **Songs**, sung on **breath** |
| upgrade material | **bog-iron** |
| boss | **Holdfast** |
| boss gate | **frost veil** |
| hotbar / inventory | **Belt** / **Pack** |
| quest log | **Keepsakes** |
| stats | Heart (HP) · Wind (stamina) · Might · Craft · Kinship (song scaling) · Lungs (breath) |
| difficulty | The Gentle Thaw · **The Long Winter** (default) · The Hard Frost |

## 7. Systems list

These systems come from the survey. Δ marks a change from the source.

1. **Player controller:** run, sprint, roll, backstep, no jump. Numbers are 1:1.
2. **Stamina, poise and stagger:** 1:1. Δ armour adds poise.
3. **Melee:** light/heavy combos, buffering, roll cancel, block, parry, riposte. 1:1. Δ sprint attack. Δ lock-on target switching.
4. **Songs:** a breath pool and a cooldown. 1:1 mechanism, new songs.
5. **Enemy AI:** a state machine, perception, lagged facing, attack types and boss phases. 1:1. Δ frost-breath facing tell.
6. **Death loop:** STILLED, the Breathmark, and enemy reset on rest. 1:1.
7. **Levelling:** the `60·1.22^(L−1)` curve with six stats. 1:1. Δ scaling uses (stat−8).
8. **Two-state world:** layers, dual navmesh, the Hearthstone rule and the shader wave. 1:1 mechanism. Δ a frost/melt wavefront.
9. **Loot:** hand-placed one-time finds and the Pack/Belt UI. Δ four armour slots.
10. **Dialogue:** lines followed by services. 1:1. NPCs exist only in THAW.
11. **Keepsakes journal:** Δ, new. Flag-chain questlines shown as lines of text.
12. **World:** the area graph, the JSON level language, generator scripts and audits. 1:1.
13. **Saves:** three JSON slots. 1:1. Δ a `save_version` field.
14. **UI:** HUD, pause, rest, Pack and dialogue. Layout 1:1, new palette and type.
15. **Camera:** spring-arm shoulder camera and lock-on. 1:1 numbers.
16. **Audio:** buses, crossfade and boss ducking. 1:1. New music.
17. **Rendering:** the `hall.gdshader` family, ACES, volumetric fog and the post stack. 1:1. Δ a frost/hoar branch.
18. **Characters:** Δ a Mixamo-compatible humanoid rig and an AnimationTree, timed by data.

## 8. Scope tiers

| Tier | Content | Exit criteria |
|---|---|---|
| **0: Greybox** | One area (`saltfell_steading`), primitives only, one enemy type, one placeholder Holdfast | Movement, combat, death→Breathmark loop, one level-up and the THAW/RIME flip all work. Tests and screenshots are green. |
| **1: Vertical slice** | **Saltfell**, the Bearer's home steading on a sea-cliff shelf, in 3 areas: *the Strand* (landing), *Saltfell yard*, *the Longhouse*. 3 enemy types, 1 Holdfast (**the Netmender**, who would not let her drowned husband go), 2 NPCs, 1 weapon family, 1 song. Tripo art for all of it. | It looks and plays like a finished 20-minute game. |
| **2: One region** | Saltfell plus **the Lowe** (barrow hills): 6 areas, 2 Holdfasts, 6 enemy types, a smith, upgrades, 2 armour sets. | A full Keepsakes questline and both route states in every area. |
| **3: Full game** | 7 regions, about 18 areas, 7 Holdfasts, both endings. Regions: Saltfell, the Lowe, Kettle Fjord (ice shelf), Tarnhall (the great timber hall), Thornwold (forest), Shepherd's Reach (high pastures), the Coldwell (the glacier's source). | Shippable. |

## 9. Non-goals

No jumping, no open world, no procedural levels, no multiplayer, no crafting tree, no quest markers, and no voice acting before tier 2.
