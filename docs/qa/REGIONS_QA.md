# Regions 2–7 and the endings: QA (2026-11-10/11, branch `fix/qa-regions`)

**Goal:** every region after Saltfell, and both endings, play end to end the way the slice does, verified through the real game with a steered Bearer.

**Not done: the screenshot pass.** No `docs/screens/qa_<region>_*.png` exist. The runner (`tools/qa/fullgame_shots.sh <region>`) and the `_shot()` calls along every route are in, and the driver now walks the real front door when it has a window, but the first full run under lavapipe was stopped at the lead's request for a clean stopping point. Nothing in this file was judged by eye: clipping, floating objects, holes, telegraph readability and UI overlap are **unreviewed**. Everything below comes from the walks, the code and the data.

## The walks

`tools/test/fullgame_base.gd` is the shared driver: the slice walk's capsule-steered Bearer, started from a save through the real world scene and its load path. Each region suite starts from the save the previous one ends on (`tools/test/fixtures/fullgame_after_<region>.json`) and, with `--fullgame-write-fixture`, writes the next. `fullslice --keep-save=PATH` writes the first.

Every region walk covers: the seam in, the place cards, the NPCs' lines in order, the first rest forcing RIME, fighting through, the Keepsakes threads, the shortcut (or the nearest designed thing), the state-only route, one death and its Breathmark, the frost veil and the Holdfast through all three phases with its AI running, the release (flag, card, drop, hearth, Outsong), the post-release THAW scene, and Pause → Return to the Title → Resume with everything checked. A walk fails if a Breathmark is left lying behind.

Run one with `tools/test.sh fullgame_<region>` (a quarter of an hour headless). They are not part of the default `tools/test.sh` run; CI runs them as the `fullgame` matrix job, one job per walk.

RESULTS_TABLE

## Fixed

| # | Where | Bug | Fix |
|---|---|---|---|
| 1 | every seam | **The Bearer was carried straight back** to the area he had just left: the new area's seam, on the same ground, fired from where he stood before the move. | An auto seam only takes a body really inside its box (`area_portal.gd`). |
| 2 | every region past a seam | **Two worlds stacked after Return to the Title → Resume.** The title return freed a stale area reference; Resume built a second copy on top and hearths acted on the old one. | The area that stands is put away (`world_root.gd`). |
| 3 | every region | **Post-release THAW scenes did not appear in the same visit** (Arne and the twins; Pell and Ivo; Linnet and Eyvind at the gap; Calder and Sigga at the fold): flag-gated souls and finds were only placed at area build. | Re-read at the release, at a rest and when the memory turns, through one path (`AreaBuilder.sync_flagged`). |
| 4 | every region | **A fallen frost veil came back as an unseen wall** on the next turn to RIME or navmesh rebake. | The veil keeps the area's remembered layer in step (`frost_veil.gd`). |
| 5 | Lowe, Kettle, Thornwold, Reach | **Release drops were lost for good on save-and-resume before pickup** (the tally-stick, Ivo's mitten, the song-cord, the fold-tally), ending a Keepsakes thread. | Each is also area data gated on the release flag, as the mending needle is. |
| 6 | the Lowe | **The bog took the Bearer on the dry road in THAW.** Its hazard was a square box round a round pool; the corner covered the road between Hesk and the Drying Stacks where the heather dips. | The bog hazard has a radius (`hazard_volume.gd`, `gen_lowe.py`). |
| 7 | the Lowe | The lowered drawbridge did not meet the Saltfell lip; ravine and deep-water volumes took a body merely near them; a veil's step-through set the Bearer at the wrong height; the Turfwright wedged on his own bay walls; a foe's swing on a cairn raised a script error. | Small fixes in `drawbridge.gd`, `hazard_volume.gd`, `frost_veil.gd`, `turfwright.gd`, `enemy.gd`. |
| 8 | Kettle Fjord | **The fish-houses could not be entered**: each walk met a wall, and the ladle and the auger were only reachable through the floor from the ice below. | The walks run to the doors (`gen_kettle.py`). |
| 9 | Kettle Fjord | New ice over the sealed hole, and the mitten in it, showed in THAW over open water (by code reading; not seen). | Both belong to the RIME layer. |
| 10 | Tarnhall | **The door between the Long Table and the Byres was not a door**: the two gables' doorways were 2 m apart, and the veil's step-through carried the Bearer through two walls. | Door specs take a shift along the wall; the veil hangs in the doorway (`building_gen.gd`, `gen_tarnhall.py`). **Not looked at.** |
| 11 | Tarnhall | **Resting after the Host's release re-seated his five guests** as live enemies. | The spawner honours `absent_flag` on respawn. |
| 12 | Thornwold | The laid-down gate vanished in THAW; overheard lines played over a talk with the same speaker. | The gate lies on the base layer; overhearing waits for a talk to end. |
| 13 | Shepherd's Reach | The Fellcaller called once and then stood idle; Calder's boots step closed without its lines if the Bearer had rested before meeting him. | She keeps calling; an errand closed in a talk is answered before a chaptered tale goes on (`dialogue_ui.gd`). |
| 14 | the Coldwell | **The released Leadvoice was gone after any resume**, so both endings played to nobody; she could be pushed off her seat; her veil could be parted after her release, locking the arena with nobody to fight. | `release_stays`; she is pinned to her seat; the veil falls on her release either way. |
| 15 | both endings | Foes could attack through the ending; the melt wave cut the Outsong off 17 s into a 115 s song; a kept save could not open the pause sheet; Return to the Title mid-ending left it rolling over the title; credits could not be skipped; the title-card layer did not follow the HUD's visibility. | The director stills the frost-taken and keeps the music; the sheet opens from the seat; `EndingDirector.stop()` on the title return; Enter ends the credits; the card layer follows the HUD. |
| 16 | tests | `Game.test_boss_dmg_mult` only worked on the Netmender; the `tarnhall_encounters` second-bench check depended on where the Host had drifted. | Every Holdfast honours the seam; the bench check re-seats him, runs a clear lane and waits for the throw. |

**The two bugs from the real-GPU review.** (1) Credits rendered from under the terrain: the staged shot only (`enc_shots.gd` never placed its camera); the live credits camera is asserted above ground and upright through both endings. The staged fix is **not looked at**. (2) HUD on screen through the Outsong beats: **not reproduced**; in the live path the HUD is hidden at every beat and through the credits, now asserted. If it still shows on a GPU, the exact command that made the shot is needed.

## Remaining issues (ranked)

1. **The Wellhead ring is open on every side in RIME.** All 13 gaps between the stones are walkable and the navmesh routes round the veil: a player can start the last duel unsealed or walk out of it. Needs RIME blockers between the stones or `seals` on the veil (`gen_coldwell.py`); left because it needs geometry that must be looked at.
2. **The Ice-Cutter's hole is certain death if the Bearer is on the disc when it opens.** The break's poise damage equals base poise: 0.7 s of stagger in a 1.0 s sink. KETTLE.md says "off it in a second".
3. **The Host's hall doors can probably be unbarred from inside during the duel** (that veil has no aux seals). From reading the code; not tried.
4. **Calder's first audience after the release, for a Bearer who rested first, is the pre-release one** ("she'll get forty-three") with Sigga beside him saying "Forty-four"; Sigga's lines and the fleece are then unreachable. Needs gated lines.
5. **The Knucklebones thread cannot close in the chained run**: the slice walk never takes the four at Saltfell. The walks assert the branch they get. A test gap, and a reminder that the thread spans three regions with nothing pointing back.
6. **Release drops are still runtime-only in Tarnhall and the Coldwell** (the Host's drop; the band and the mask): lost if the area rebuilds before pickup.
7. **Three regions define no shortcut**: Kettle Fjord, Thornwold and Shepherd's Reach have no gate and no flag. The walks prove the nearest thing (the RIME ice between the hearths; the laid gate; the gap after the release).
8. **Shepherd's Reach has one Keepsakes thread**, not two.
9. **The Byres hearth wakes the Bearer 3 m from a Hall-champion**, with three more joining.
10. **"Tip the horn" frost is 6 m in radius** for 8 s in a 14 m hall; TARNHALL.md says 6 m across. Hugging the Host inside 1.8 m avoids nearly everything he does.
11. **Kettle's navmesh climbs decks from the side (0.5 m); the Bearer cannot (0.35 m).** In THAW a player pushing at a walk's side slides into the water; frost-taken may stall at deck edges.
12. **Moves the real duels never showed** (the melee bot stays close): the Hedgelayer's lash and gap-measure, the Fellcaller's Count them, the Leadvoice's Held note and Long note. Covered only by the sandbox encounter suites.
13. **Smaller:** the Collier "on the road" stands 7 m off it; Sten stays on his crate after Halla says he is in the end house; Maren and Wren stand 1 m apart so the prompt picks Maren; Lusse's "Somebody's opened the doors" is unreachable with the tally in hand; the yard guest on its barrel plays the Netmender's mending loop; the Fellcaller may kneel overlapping the High Fold hearth; her rams may land on the fold wall; on a resumed save the RIME theme plays at the Wellhead where COLDWELL.md asks for silence; a kept save replays the sit-down on every Resume.
14. **The chained saves are an easy game**: The Gentle Thaw, the weapon never raised, levels bought with everything carried. Every fight here was judged on gentle.
