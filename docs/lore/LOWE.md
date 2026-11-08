# Region: the Lowe

*Owner: narrative. Tier 2 per `SPEC.md` §8. Truth and backstory are in `WORLD.md` §5.2; voice rules in `WRITING.md`; the model for this file is `SLICE.md`. Ids are the data keys in `data/`.*

The Lowe is the barrow hills behind the coast: long turf mounds in heather, a road of standing stones, peat cuttings full of black water. The player comes up from Saltfell over the pass, walks the Barrow Road past the Kin-Mounds, crosses the bog in RIME, and ends in the Open Barrow. Thirty minutes, one Holdfast, two people.

**What the region must let the player infer, without anyone saying it:** a man who closed every barrow on the coast did not close one; there were two girls and there is one barrow; a widow is sure of every mound and wrong about two of them; one barrow on a road of open ones is shut, and someone has been to it lately.

---

## 1. Area flow

```
the pass ──> the Barrow Road ──> the Kin-Mounds ──> the Drying Stacks ──(frost veil)──> the Open Barrow
   ^              |                    |
   |              └── the bridge ──────┘ (lowered from the Lowe side: back to Saltfell yard)
   |                                   |
   └── Saltfell yard          the peat bog (THAW: drowns; RIME: frozen) ── the peat island
```

One area, `lowe_barrows`, on its own terrain in Saltfell's coordinates (ADR 0006, the seams one). Two seams back to Saltfell: the pass and the bridge.

Hearthstones:

| id | Name | Where | Notes |
|---|---|---|---|
| `hs_barrow_road` | **the Barrow Road** | among the first standing stones | First hearth. A ring of soapstone at the foot of a leaning stone that people sit against to take their boots off. |
| `hs_drying_stacks` | **the Drying Stacks** | the road's end, below the Open Barrow | Set in the lee of a stack of cut turf left to dry. Nearest hearth to the Holdfast. |
| `hs_open_barrow` | **the Open Barrow** | in front of the twins' barrow | Cold until the Turfwright is released; then it becomes a Hearthstone (`release_hearth`). |

Title cards (first entry to each zone, the UI serif in small caps, no subtitle):

- **THE LOWE** (the area plaque on the pass reads it in full)
- **THE BARROW ROAD**
- **THE KIN-MOUNDS**
- **THE OPEN BARROW**
- On release: **THE TURFWRIGHT — RELEASED** (quiet, bone-white, held 3 s)

---

## 2. The Barrow Road and the Kin-Mounds

**Layout.** The pass comes off the cliff top onto a long rise of heather. Standing stones run in pairs up the road, northeast, past four long barrows, each with its door facing the road: `kin_a` (the first, below the hearth), `kin_b`, `kin_c` (the closed one, a little off the road) and `kin_d` (the last, where the road bends). The ravine rim runs east to the bridge windlass.

### THAW (first arrival is always THAW)

- Low sun behind the pass. Larks. Turf doors in place on every barrow, the seams cut clean.
- **Aud** on the road between `kin_a` and `kin_b`, a bundle of heather at her hip. She is talking to the mounds as she passes them, by name.
- On `kin_b`, a cloth spread on the turf with the crumbs of bread and cheese on it: a family has eaten on their grandmother's mound and gone home. A cup has been left, upside down, so it won't fill with dew.
- `kin_c` sits a little apart. Its turf is older than the others and has heather grown over the seam.
- No enemies.

### RIME (after the first rest at the Barrow Road)

- Every barrow door stands open on a frozen spade. Inside each passage, the dead have sat up facing the road.
- `kin_c` is shut. Its turf is white like the rest, but the seam is still there. On the turf, a flat stone with a woad-blue thread tied round it. The wool is not frozen stiff (`ks_woad_thread`).
- Enemies:
  - a Barrow-sleeper in the mouth of `kin_a`, `kin_b` and `kin_d`, each sitting up facing the road (`pose: sit_up`). They rise when the Bearer comes into sight.
  - a Keener on the road where Aud stands in THAW, facing her mounds.
  - a Keener kneeling at the closed door of `kin_c`, its back to the road (`pose: kneel`). It is the only frost-taken on the Lowe that faces a barrow.
  - a Keener at the bend by `kin_d`.
  - a Barrow-sleeper at the bridge windlass, facing the ravine.
- Pickups:
  - **Orm's knot-cord**, just inside the door of `kin_a`, across the knees of the one who sat up there (`item_orm_cord`; sets `ks_aud_cord_found`).
  - The **Turf Spade** holding up the door of `kin_d` (`turf_spade`). Taking it does not bring the door down.
  - The grave goods further in at `kin_a` (warmth, already placed).

---

## 3. The peat bog and Hesk's cutting

**Layout.** West of the road the ground drops into a peat cutting: black walls of cut turf, stacks of peat drying along the edge, and below it the bog, a round of black water with an island of cut peat in the middle.

### THAW

- **Hesk** at the edge of the cutting, his furnace dug into the peat wall, the bellows on his pack-frame. The smoke goes everywhere except up the flue. He complains about it.
- The bog is black water. It drags at the Bearer and drowns them after a few seconds. The AI will not path into it.

### RIME

- The bog is frozen and walkable. A cairn-carrier works its way round the rim, carrying its stones uphill to nowhere.
- **Hesk's tongs**, frozen into the bog ice near the cutting, handles up (`item_hesk_tongs`; sets `ks_hesk_tongs_found`). The prompt is *Chip the tongs out of the ice*.
- The peat island: two lumps of bog-iron (already placed).

---

## 4. The Open Barrow

**Layout.** The road's end climbs to a hollow 42 m across, ringed with a wall of stacked sods waist to head high, with a gap to the south for the road. Inside the ring are fourteen more stacks of cut turf, neat, square, waiting. Enough to close every barrow on the Lowe. The north side of the ring is the twins' barrow: a double-width mound with its stone door open and its turf door gone. The Drying Stacks hearth is below the gap.

### THAW

- Before release: the hollow is a turf-cutters' yard. The stacks are fresh and dark. The twins' barrow is not there yet; the mound is a low rise of heather.
- After release, see §8.

### RIME (boss arena)

- A frost veil across the gap in the sod wall.
- The stacks inside the ring are white. Where the turf has been lifted, the ground underneath is cut in long straight strips, the same width as a spade.
- **The Turfwright** stands at the twins' barrow with his back to the road. His right forearm ends in a spade blade; on it is one sod, held up level with the empty doorway. He does not move. If the player waits, the sod tips a little, and he rights it.

---

## 5. Enemies

All frost-taken have the frost-breath facing tell (`SPEC.md` §7). Every move that covers ground shows its area on the floor for the length of the windup, in the same cold blue as the slice (`telegraph`), so what glows is what lands.

### Barrow-sleeper (`barrow_sleeper`)

One of the turf-wrapped dead. Brown burial cloak bound with cord, strips of frozen turf and heather on the shoulders, a carved mourning mask, both hands frozen into heavy fists. Sits in a barrow mouth facing the road. Slow, and it hits like a falling door.

| Move | Telegraph | Notes |
|---|---|---|
| **Hammer-fist** (`hammer_fist`) | Right fist drawn up past the ear, turf flakes shake off the shoulder (0.9 s) | One heavy overhand. Parryable. May follow with a Back-fist. |
| **Back-fist** (`back_fist`) | Weight shifts to the left foot (0.55 s) | Left-hand backhand. Only after a Hammer-fist. |
| **Door-fall** (signature) (`door_fall`) | Both arms rise, it leans back, frost-breath twice (1.3 s); a 1.8 × 3.4 m strip glows in front | It falls forward full length, the way a turf door comes down. Not blockable. Then it lies there and gets up slowly: 2.0 s to punish. |
| **Rising** | | Sitters (`pose: sit_up`) take 2.4 s to stand (`rise_time`). |

### Keener (`keener`)

A masked mourner in a grey and madder-red robe, mask with an open mouth-hole and a plume of breath frozen out of it. It lost the words and only breathes the tune. Keeps its distance (`keep_range` 7 m).

| Move | Telegraph | Notes |
|---|---|---|
| **Breathed note** (`breath_note`) | Head tips back, the mask lifts, a thin held breath (0.9 s) | One slow note of frost, aimed with a little lead. Strafe it. |
| **The keen** (signature) (`keen`) | Both hands to the mask, it rocks forward twice, a long held breath (1.5 s) | Three notes in a fan. Close in or roll through the gap. |
| **Hush** (`hush`) | Turns its face away, shoulders rise (0.7 s); a 2.8 m ring glows round it | Breathes out on whoever is close. Knocks back. Punishes rushing it. |
| **Rouse** (`rouse`) | Straightens, hands drop, breath straight up (0.8 s) | Every idle frost-taken within 16 m turns to the Bearer and comes. No damage. Long cooldown. |

### Cairn-carrier (`cairn_carrier`)

A heavy stooped man in sheepskin, a yoke of frozen grey-green stones grown across both shoulders. It carries them uphill and does not know why. High poise; slow.

| Move | Telegraph | Notes |
|---|---|---|
| **Yoke swing** (`yoke_swing`) | Twists the whole torso away, the stones grind (1.0 s) | The yoke swings round: a 220° sweep at 2.4 m. Roll away, not through. |
| **Set a stone** (signature) (`set_stone`) | Stoops, both hands to the yoke, lifts one stone over its head (1.6 s); a 1.6 m square glows ahead | Drops it in front: heavy, not blockable, and the stone stays as a cairn for 14 s that blocks movement. Two heavy blows knock it down. |
| **Stone toss** (`stone_toss`) | One stone lifted to the shoulder (1.3 s) | When the Bearer keeps more than 6 m off: a slow, heavy lob. |

---

## 6. The Holdfast: the Turfwright (`turfwright`)

**Arne Holm.** 3.4 m, broad, brown wool and a leather cutter's apron, a deep hood, a flat oval board of pale oak for a mask with one carved groove. His back has become a barrow door of stacked frozen turf in a timber frame, hinged at the shoulders, propped open so it stands up behind his head. A flat bog-iron spade blade has grown out of his right forearm in place of a hand. His left hand is a frozen fist.

**Arena:** the Open Barrow. A ring of sod wall, fourteen stacks inside, the twins' door to the north. Frost veil at the south gap.

**Intro (no dialogue).** The player parts the veil. He keeps holding the sod up to the door. The player can walk right up behind him. When the player is within 6 m or strikes him, he lowers the spade, sets the sod down on the threshold stone, square, with both hands, and turns round. The health bar appears: **THE TURFWRIGHT**.

His back is the door. In phases 1 and 2 he will not let anyone stand behind him; in phase 3 he stands with his back to his daughters' door so nobody can.

### Phase 1: the cutting (100–60%)

He cuts the ground from under the Bearer, a line at a time.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Spade chop** (`spade_chop`) | Spade-arm drawn up across his body, left fist braced (0.8 s) | One heavy downward chop. Parryable on the blade. |
| **Ground cut** (`ground_cut`) | Plants his feet, sets the blade to the ground and leans on it, breath forward (1.3 s); a 1 × 12 m strip glows toward the Bearer | The cut runs along the ground. Standing in it hurts. The lifted sod stays as a low wall for 8 s. Half the time he follows with a Cross cut. |
| **Cross cut** (`cross_cut`) | Pulls the blade free and re-aims, one step (0.9 s) | A second cut at the Bearer's new place. Only after a Ground cut. Two cuts box the Bearer in. |
| **Back-drop** (`back_drop`) | The Bearer is behind him for over 1.2 s: he straightens, the door on his back creaks (0.9 s); a 4 × 4.5 m patch behind him glows | He drops his back like a lid onto the ground behind him. Not blockable. Teaches that his back is the thing he keeps. |

### Phase 2: the stacking (60–25%)

Transition (2.6 s, invulnerable): he drives the spade into the ground and pulls, and four walls of stacked sod rise out of the floor in a cross between the centre and the ring, cutting the hollow into four bays. The stacks inside the ring shudder. From now on he builds.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Stack a sod** (`stack_sod`) | Lifts a block of turf from the nearest stack, both arms, over his chest (1.4 s); a 1.4 × 3 m patch glows where the Bearer stands | He lays it there. Heavy if it lands on the Bearer; then it stays as a wall for 12 s. He walls the Bearer in. |
| **Sod throw** (`sod_throw`) | One sod lifted to the shoulder (1.0 s) | When the Bearer is more than 6 m off: a slow heavy lob. |
| **Drag swing** (`drag_swing`) | Spade dragged back along the ground (0.9 s) | A wide 130° sweep. |
| Phase 1 attacks | as above | Ground cut no longer leaves time between cuts: Cross cut always follows. |

### Phase 3: the last turf (25–0%)

Transition (2.8 s, invulnerable): he stops, walks back to the threshold, and picks up the sod he set down. He holds it against his chest in his left arm. The bay walls slump into loose turf. From now on he fights one-handed and slower, and he keeps within 7 m of the door: if the Bearer draws him off, he backs up to it again, facing the Bearer the whole way.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **One-hand chop** (`one_hand_chop`) | Spade drawn up, the sod held tight (0.9 s) | One chop, slower. |
| **Ground cut** | as phase 1, slower (1.5 s) | No Cross cut. |
| **The last turf** (`last_turf`) | The Bearer is more than 6 m off: he turns to the door, kneels, and lifts the sod to the doorway with both hands (2.0 s) | No attack. He holds it there. His back, the door, is to the Bearer, open. This is the moment. Hitting him does not stop him holding it. If the player does nothing for 5 s, he lowers it to his chest and stands. |

**Release.** At 0 he kneels at the door and lays the sod in the doorway. The door on his back comes down over him. The bay walls and every cut sod sink back into the floor. The frost veil falls as meltwater. Title card. The Open Barrow hearth takes from the Bearer's horn by itself. **Arne's tally-stick** lies in front of where he knelt.

**Music cue notes:** phase 1 is room tone and the scrape of the blade. Phase 2 adds a low drone and the thump of laid turf on the beat. Phase 3 drops to one low held note that stops when the sod goes in.

---

## 7. NPCs

THAW only. Format follows `data/npcs.json`: `lines_first`, `lines_repeat`, then `services`. Flags with `ks_` are Keepsakes journal flags.

### Hesk, travelling smith (`hesk`)

Fifties, stocky, scorched leather apron, a soot-marked oak mask, tongs and hammer at his right hip, bellows on a pack-frame. Does the coast twice a year. Grumbles at the weather the way other people say good morning. Good at his work and knows it. Model: `hesk`.

**lines_first**

1. "Don't stand there, you're in my draught. There. No. There."
2. "Hesk. I do the coast twice a year, when the wind lets me. On the Lowe it never lets me."
3. "Bog-iron. You rake it out of the black water and it comes up looking like something the dog left. Give it a day in here and it's a hinge."
4. "Lost my good tongs in the bog this morning, raking. Went in to the elbow after them. I'm not going in to the shoulder for anyone's tongs, not even mine."
5. "If you've iron, I'll put it in that blade. If you've not, sit out of the wind and don't touch anything."

**lines_repeat** (default)

- "Wind's wrong again. It's always wrong on the Lowe."
- "Arne wants his spade edged before the Melt. I told him I'm a smith, not a miracle."
- "These are borrowed tongs. You can tell. They don't like me."

**lines_repeat** (after `ks_hesk_tongs`)

- "Never that good, these. Bent in the rein. I'll have them back all the same."
- "Put your blade on the stone. I'll do it for less. Don't go telling people."

**lines_repeat** (after `ks_turfwright_released`)

- "Wind's come right. First time all summer. I don't trust it."
- "Fire's drawing like a chimney. Pass me that, quick, before it changes its mind."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `fold_iron` | upgrade (1 bog-iron) | 220 warmth | Fold bog-iron into the blade | "There. It'll hold an edge now. Try not to use it on stones." |
| `fold_iron_kin` | upgrade, requires `ks_hesk_tongs` | 140 warmth | Fold bog-iron into the blade | as above |
| `buy_bog_iron` | buy `bog_iron` ×1, repeatable ×2 | 150 warmth | Buy a lump of bog-iron | "Last of what I raked before the tongs went in." |
| `buy_maul` | buy `maul`, once | 600 warmth | Buy the post maul | "Drive posts with it. Or don't. It's yours, I'm not asking." |

No iron: "No iron, no edge. Go and rake some. Mind the black water." Short of warmth: "%d warmth for the fire. Peat doesn't cut itself."

**Keepsakes: "Hesk's tongs"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_hesk_met` | First conversation | "Hesk dropped his good tongs in the bog, raking for iron." |
| 2 | `ks_hesk_tongs_found` | Chip `item_hesk_tongs` out of the frozen bog (RIME) | "The tongs were frozen into the bog, jaws down." |
| 3 | `ks_hesk_tongs` | Talk to Hesk in THAW carrying the tongs | "Hesk said they were never that good, and took them." |
| 4 | `ks_hesk_wind` | Talk to Hesk after `ks_turfwright_released` | "Hesk says the wind has come right." |

Reward at step 3: 1 bog-iron, and `fold_iron_kin` replaces `fold_iron`.

### Aud, barrow-keeper's widow (`aud`)

Seventies, small, a long grey mourning cloak she has worn so long it is just her cloak, a madder-red band on a worn birch mask, heather at her hip. Her husband **Orm** kept the Kin-Mounds forty years. She knows every mound on the Lowe and is wrong about two of them: she thinks Orm is under the last mound on the road (he is under the first), and she thinks `kin_c` is empty. She will not be told. Model: `aud`.

**lines_first**

1. "Keep to the road, love. The turf's soft either side and I'm not pulling you out."
2. "Aud. Orm kept these mounds forty years and I kept Orm, so I know them as well as he did. Better. He'd say so himself."
3. "That's the Holms' lot. That's the miller's people, all eleven, and the miller still owes for three of them. That one's empty, whatever anyone tells you."
4. "Orm's the last one on the road. I tie him a bit of heather every evening. He liked the purple. Bring me white and you can take it back."
5. "His cord went in with him. Every burial on the hill, in knots. His brother wanted the knife put in. I won."

**lines_repeat** (default)

- "Turf goes back the same day. That's the whole of the job. Orm made it sound harder."
- "Arne Holm cut every sod on this hill. You can tell his by the edge. Straight as a shelf."
- "His girls were up here this morning, the pair of them, stealing his spade. He let them."

**lines_repeat** (after `ks_aud_cord`)

- "That's Orm's cord. He tied his knots too tight. You can't read a word of it, so don't try."
- "First on the road. It says a lot of things. He tied it in the dark half the time."
- "You'll want his other cloak. He was buried in the good one."

**lines_repeat** (after `ks_turfwright_released`)

- "I've moved the heather. It was always that one. I don't know why you're looking at me like that."
- "Arne's sat out with his girls again. They'll be on about the window. They always are."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `buy_turf_song` | buy song `turf_song`, once | 240 warmth | Learn the Turf-Laying Song | "It's counting, mostly. Count with the spade, not ahead of it. Orm counted ahead of it." |
| `give_barrow_cloak` | gift, once, requires `ks_aud_cord` | free | Take Orm's working cloak | "He was long in the arm. Turn the cuffs back. Don't cut them." |
| `rest_level` | level_up | — | Sit on the wall with Aud | *(opens the levelling screen; Aud says nothing)* |

**Keepsakes: "Orm's cord"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_aud_met` | First conversation | "Aud ties heather on Orm's mound every evening, the last one on the road." |
| 2 | `ks_aud_cord_found` | Take `item_orm_cord` from the mouth of `kin_a` (RIME) | "Orm's cord was in the first barrow on the road." |
| 3 | `ks_aud_cord` | Talk to Aud in THAW carrying the cord | "Aud says Orm tied his knots too tight to read." |
| 4 | `ks_aud_heather` | Talk to Aud after `ks_turfwright_released` | "Aud has moved her heather to the first mound. She says it was always there." |

---

## 8. The release beat and what he leaves

- **In the arena, at once:** he kneels and lays the sod; the door on his back comes down over him like a lid; the cut lines and the bay walls go back into the ground; the veil melts; the card; the hearth wakes; the tally-stick.
- **Flag:** `ks_turfwright_released` (`release_flag`), which turns both threads to their last line.
- **Drop:** `item_tally_stick` (`release_drop`), set down 2.2 m toward the Bearer.
- **Hearth:** `hs_open_barrow` (`release_hearth`), gated on the flag in the area data so a rebuilt area keeps it.
- **After release, RIME:** the twins' barrow has a turf door, the seam cut clean. On the threshold stone, where he set the sod down at the start, **the twins' spindles** (`item_twin_spindles`).
- **After release, THAW (art pending):** Arne sits outside the barrow on a summer evening with Liv and Asta, arguing with them about which of them gets the window side of the barrow when they are old. Nobody in the scene can be spoken to. This waits on a THAW Arne and the twins; until then the Open Barrow in THAW is the turf-cutters' yard, and Aud's last line carries it.

---

## 9. Items

Voice per `WRITING.md`: a plain fact, then one human detail. No morals.

**Arne's Tally-Stick** (`item_tally_stick`, Holdfast release drop)
> A long hazel stick from Arne Holm's belt, notched down both edges, one notch for every barrow he turfed over on the coast. He could tell you whose each notch was. The last two sit side by side, and both are cut only halfway.

**The Twins' Spindles** (`item_twin_spindles`)
> Two drop-spindles of birch with soapstone whorls, tied together with a bit of yarn. One shaft is grey from handling and its whorl is worn smooth. The other still has the knife marks on it.

**Orm's Knot-Cord** (`item_orm_cord`)
> A barrow-keeper's cord as long as two arms, with a knot for every burial on the Kin-Mounds in the order of the mounds. Orm tied his knots tight and small. The last knot on the cord is looser, and a different knot.

**Hesk's Tongs** (`item_hesk_tongs`)
> Smith's tongs of bog-iron with long reins, one rein bent from being used as a lever. Hesk has punched his mark into both reins, in case anyone on the Lowe was thinking of keeping them.

**Woad Thread** (`ks_woad_thread`)
> A length of woad-blue wool tied round a flat stone on the turf of a closed barrow. It is knotted with a household knot, pulled tight with the teeth. The wool is still soft.

**Turf Spade** (`turf_spade`, weapon)
> A peat-spade with a long narrow blade and one side wing, for cutting turf in strips. The ash handle has gone silver. It was wedged under a barrow door on the Kin-Mounds to hold the door up.

**Post Maul** (`maul`, weapon; sold by Hesk)
> A round of split oak on an ash haft, bound with two iron rings, for driving fence posts. Hesk carries it from steading to steading and sells it when he is short. The leather on the grip is wrapped over an older wrap.

**Orm's Working Cloak** (`armour_barrow_cloak`, body)
> A cloak of fulled brown wool pinned at the right shoulder, worn for cutting turf in the rain. Orm was long in the arm, and Aud never took the sleeves up. The hem is still stiff with Lowe mud.

---

## 10. Song: the Turf-Laying Song (`turf_song`)

- **Breath:** 50. **Type:** ward. **Absorbs:** 60 for 8 s.
- **Use:** a held hum; a skin of warmth that takes the cold first.
- **Taught by:** Aud (`buy_turf_song`).

> Sung by barrow-keepers while the turf goes back, to keep the spades together. Most of it is counting. Aud gets the numbers in the wrong order and finishes on the right one.

---

## 11. New names

Added to `LEXICON.md`: Orm, the Drying Stacks, the Open Barrow (hearth), the Turf-Laying Song, Turf Spade, Post Maul, Orm's Working Cloak, Liv and Asta (already in `WORLD.md`, now in the lexicon). Checked against `tools/banned_terms.txt` and `docs/transposition/ORIGINALITY.md` §1–5: no bells, candles, wax, bees, choirs, runes or letters; nothing from another game.
