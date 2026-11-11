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

## Update: pass 2

- **Root cause of foes striking sideways:** only seven models had ever been through `tools/art/humanoid_import.py`. Every other Mixamo foe and NPC still had an un-retargeted skeleton (rotated a quarter turn under its rig node, rest axes not the profile's), so shared clips and overlays played 90 degrees off their facing. The retarget options are now applied to every rigged character, with `fix_silhouette` on (the bulky bodies are rigged in an A-pose).
- **Each foe is keyed on its own stance:** `tools/anim/dump_idles.gd` writes every model's idle pose from Godot's retargeted skeleton to `tools/anim/foe_idles.json`; the build uses it as the base pose, so the Netmender keeps her hunch and the carrier his stoop.
- **Coverage is now 55 attacks**, including the Netmender (stitches, casts, sea weight, knot, mend), the Holdfasts' ground, throw and sweep moves, the carrier's stone set and toss, and the Cupbearer's whirl. A foe's hand raised above the shoulders is pushed wide and forward where the model carries a load (`clear`).
- **Staggers** are per foe, on its own stance; Holdfasts' are slowed to fill their longer stagger. A foe's own attack clip suppresses the old `hit_anim` follow-up.
- **Quadrupeds:** `tools/anim/quad_poses.py` derives a deeper load, a fuller extension and a new landing pose; `pose_seq` chains extension to landing.
- Still on their old clips: Holdfast transitions, holds and release beats; `door_fall`; `back_drop`, `stack_sod`, `step_into`, `raise_guests`, `tip_horn`, `haul`, `turn_away`, `ring_cut`.

## Update: pass 3

- **Reviewed on sheets** (`tools/anim/foe_sheets.sh --all`, now 113 sheets: every clip in every foe clip set, plus the quadrupeds' poses).
- **Archetypes can now carry more than three poses.** `telegraph` takes a `pre` pose (a reach or gather before the anticipation), a `mid` pose the strike passes through (an elbow that leads), and its own rise, strike, hold and recovery seconds; an archetype marked `.full` returns its whole key list (`tools/anim/foe_beats.py`).
- **Weak clips rekeyed:** the Oarsman's back stroke (the oar now goes from behind his left side right round to his right), the Cupbearer's going-round (side-on with the blades level, then one stepped full turn per cut in the data's `hits`), the champion's shield bash (set behind an upright forearm, mace arm back), the Netmender's stitches (a jab per `hits` entry on her hunch, re-cocked at the ear before the late one), the Turfwright's chops (elbow bent and leading), the carrier's yoke swing (a 190-degree sweep with a step), the Keener's breath note, keen (hands to the mask, rocking twice) and hush (face turned away, shoulders up).
- **Overhead wind-ups keep a bent elbow.** Hands were keyed at 2 m, past the arm's reach, which locked the arm straight.
- **Signature moves hand-keyed**, replacing the text-prompt clips and overlays: `back_drop`, `stack_sod`, `step_into`, `raise_guests`, `tip_horn`, `haul`, `turn_away`, `ring_cut`, and the barrow-sleeper's `door_fall` (a rigid fall about the toes). `drill_down`, `haul_trace`, `table_sweep`, `bench_throw`, `raise_wall` and `thorn_lash` were already keyed in pass 2 and were kept; the trace is now thrown with the left hand, as its tell says.
- **Intro, hold and release beats** are library clips answered by their game clip name in the foe's clip set (`beats` in `FOES`): the Netmender mending, tying off and biting the twine, sitting back down, curling over; the Turfwright pressing the sod to the door, lifting the last turf, laying it; the Ice-cutter drilling, kneeling to cut fresh, resting the auger; the Host pouring along the table, setting the horn down, sitting; the Hedgelayer laying a stem, measuring the gap, kneeling with his hands on the ground. Game code is unchanged: it still plays `sit_mend`, `lay_turf`, and so on.
- **Quadrupeds** (`tools/anim/quad_poses.py`): poses are keyed per joint (upper leg, fore, pastern, thigh, shin, hock, neck, head) instead of scaled from the first art pass. `clip_meta` `models.<id>.strikes` chains load, launch, extension, bite or gore, landing and recover; `QuadRig.strike` times the launch off the attack's data windup. The stag's stray fore-hoof skin weights are rebound by `tools/art/fix_stag_hoof_weights.py`.
- **Not covered: the Shepherd's Reach and Coldwell foes.** `origin/feat/reach-coldwell-endings` adds rows for `frost_ram`, `drover`, `upwalker`, `unsung`, `fellcaller` and `leadvoice`. That branch is not merged here, so they have no `FOES` entries and no strikes. After it lands: add them to `FOES` (and the ram to `quad_poses.py`), rebuild, and render their sheets.
- **Still weak, by eye:** the Hedgelayer's `measure_gap` reads from the side as one raised arm (the camera, and his thin arms); the Netmender's seated beats are hard to read under her net and skirts; the Host's sit has no bench under it in the sheet, so judge it in the hall; the sledge dog's long spine chain keeps its crouch shallower than the hound's.

## Update: pass 4 (feat/anims-4)

- **Real-GPU review** (`origin/gpu/anim-review`, `docs/gallery_gpu/anim/VERDICT.md`), all four findings:
  - Greatblade heavy: `anim_pose.stop_above` keeps the hands up and arrests the blade with its tip half a metre off the ground from the strike on. Section contact 0.77.
  - Bearer light 1: the two-frame cut is spread (`warp`) and the section contact moved onto it (0.33). The data windup is untouched.
  - Rimewalker swipe: its own archetype (`haymaker`).
  - Host table sweep: `table_heave`. The table is skinned to his upper arms, so only the forearms fold (`cbones`, FK in the chest's frame) and the fists stay at the table's edge while his frame winds and heaves.
- **Shepherd's Reach and Coldwell foes are covered:** drover, upwalker and unsung (attacks, stagger, a keyed death each), the Fellcaller (five moves, her `call` loop, `summon` and `kneel_down`), the Leadvoice, and the Frost-ram's butt, charge and kick (`quad_poses.py`: the charge's two scrapes fill the telegraph through `lead`).
- **The Leadvoice** has no stagger clip and no strike. Her beats move her spine, shoulders and head only; her hands are pinned where her stance has them and her legs hang from the pelvis (`legs_fk`), because the ice of her cloak is skinned to her arms, fingers and legs. Sat (phases one and two) the same beats are keyed on her seated stance (`foe_idles.json` `leadvoice#seat`, the first frame of her `rise`) and answered as `@sit_<attack>`; `leadvoice.gd` plays them on the windup.
- **The endings** (ADR 0013): `end_sing`, `end_kneel`, `end_stopper`, `end_sit` in `combat_clips.py`, answered through clip set `_all` as `outsong_sing`, `outsong_kneel`, `press_stopper`, `sit_still`. `game.json` `endings` names them (`sing_clip`, `kneel_clip`, `shut_clip`, `sit_clip`); `EndingDirector._play` lands the coal and the stopper on their beats.
- **Pass 3's weak list:** the Cupbearer's mid-spin arms (one blade high and leading, one low and trailing) and the Hedgelayer's `step_into` (upright, arms travel back with him; they used to stay where he started) are rekeyed. Old Calder's sit is not done: no placement on main sits him (THAW he stands, RIME he lies).
- **Model limits found on the sheets, not fixable in a clip:** the Fellcaller's horn is skinned to her belt (her calls are a cupped hand); the Host's mesh carries a third, rigid left arm at his hip, and his raised-arm clips (`bench_throw`, `raise_guests`) crumple the table.
- **Sheet tool:** `--pose-zoom=<cell>`, `clip@bare`, `POSE_RIG=<outfit>`, `frost_ram@more`, `models.<id>.sheet_h`.

## Update: pass 5 (fix/rig-fixes): the model faults

Pass 4 listed faults "not fixable in a clip". They are fixed in the models, by committed scripts that rewrite the processed GLB in place (`tools/art/glb_skin.py`: skin and triangles as arrays, written back without moving another byte, so clips, rest pose and textures are untouched; the pattern of `fix_stag_hoof_weights.py`). Run each once after `blender_process.py` re-processes its model.

- **Every multiview Holdfast of the last batch grew a spare arm.** Tripo's remesh is one welded shell, so mesh islands do not find them; each is found from its far end and flooded up its own axis to where it widens into the body (`Prim.tube`), cut, and capped with a fan on a reused vertex (`Prim.drop_and_cap`).
  - The Host: a whole sleeve and hand out of the small of his back, bound to the left upper arm (it swung at his left hip). `fix_host_hip_arm.py`.
  - The Fellcaller: a gloved forearm out of the fleece on her back. `fix_fellcaller_back_arm.py`.
  - The Leadvoice: a gloved arm in the cloak behind her right shoulder. `fix_leadvoice_cloak.py`.
- **The Fellcaller's horn** is one surface with her dress along its whole length (a flood from its rim takes in the dress within six rings), so it cannot be lifted off. It stays on her belt, and the existing `fellcaller_horn` prop is put in her right fist for the clips that call or swing: `clip_meta` `models.fellcaller.held` (a `props` row and the library clips that hold it), mount `fellcaller_horn`. `CharVisual._build_held` shows it only while one of those clips owns the rig, scaled in over a few frames. Her arm is short for her bulk, so the mount carries the horn from the fist up to the mask and the hand follows her head back through the cry (`_horn_up`).
- **The Leadvoice's rig is misfitted**, not just her weights: the forearm and hand bones run down the two edges of her cloak to the ground, and her real sleeves and hands are one rigid piece on each upper-arm bone. `fix_leadvoice_cloak.py` moves everything the forearm, hand and finger bones carried to the hips and spine by height (ground ice and lower sheet to the hips alone), and leaves the upper-arm bones only what lies near the real arm, fading out over 0.16 to 0.38 m. Her own clips no longer crumple the cloak at her feet. Her beats are now keyed with the arms in the chest's frame (`cbones`, `LV_CLOSE`), no wrist targets: `shelter` brings both hands up to the swaddle. Each arm is still one piece with no elbow.
  - Sat (her `rise` clip's first frame) the pelvis is on the ground and pitched forward, so the hips-bound ground ice is under the floor: she sits in the hanging cloak without the sheet round her.
- **Clips:** the Cupbearer's skid after the spin (side-on, sunk, one blade across as a guard; it stopped as a T); the Drover's death goes on from his knees to lie flat (`drover_fall`; the Upwalker keeps the kneeling stop).
- **Villagers can have keyed beats:** `foe_clips.NPCS` builds them on the model's own stance into clip set `npc_<model>`. Old Calder has `sit` (hands on his knees, a look along the wall, his thumb down the tally). REACH.md 9 has him stood at the wall after the release, so no placement seats him; `"pose": "sit"` on any placement will.
- Sheets: `docs/screens/anim_foe_*` for the clips above (`foe_sheets.sh` takes a villager: `old_calder@sit`), `docs/screens/rigfix_*` for the models before and after.

