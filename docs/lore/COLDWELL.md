# Region: the Coldwell

*Owner: narrative. Tier 3 per `SPEC.md` §8. Truth and backstory are in `WORLD.md` §3, §4, §5.7 and §6; voice rules in `WRITING.md`; the model for this file is `SLICE.md` (and the five regions after it). Ids are the data keys in `data/`.*

The river's source. From the High Fold's corner of the Reach a path climbs along the shoulder of the mountain beside the river, up past its ice-falls, to a level of turf under the glacier's lip: two old houses, a ring of standing stones, the spring. Every region the Bearer has walked through lies below, back the way he came. Forty minutes, most of it walking. One Holdfast, two people, two endings.

**What the region must let the player infer, without anyone saying it:** the Leadvoice did not begin the song for her own youngest; she dug the child up and carried her here, the long way, to have longer; she sat down with her at the spring and the spring froze round them. The Leadvoice is the Bearer's mother. The child is the sister the Bearer carried round the yard on one hip. Nobody in the game says either thing. The player has seven pieces (§8) and a walk to put them together on.

---

## 1. Area flow

```
the Reach seam ──> the Upwater ──(the ice-falls)──> the Wellhead Steps ──> the Wellhead (the ring, the spring)
```

THAW here is not the midsummer evening. It is the last Melt before the sickness: a clear spring morning, the river loud and brown with flowers turning in it. RIME: the river is frozen, and every unsung dead of Rimeholt stands in it facing up the water.

Hearthstones (three, none at the spring):

| id | Name | Where |
|---|---|---|
| `hs_upwater` | **the Upwater** | the foot of the climb |
| `hs_ice_falls` | **the Ice-Falls** | half-way |
| `hs_wellhead_steps` | **the Wellhead Steps** | the last rise below the level. Nearest hearth to the Holdfast. |

Title cards:

- **THE COLDWELL** (the plaque at the foot reads it in full)
- **THE UPWATER**
- **THE WELLHEAD**
- On release: **MAREN — RELEASED**. Every other Holdfast's card carries the office. Hers carries her name: the office is what is let go.

---

## 2. The Upwater

**Layout.** One path, climbing, the river on the downhill side, the land falling away beyond it.

### THAW

- Nobody on the path. The water is too loud to hear anything else.
- No enemies.

### RIME

- The dead stand in the frozen river, knee-deep, at every few paces, facing up the water. They do not turn. They are not foes. There are a great many of them.
- Three Upwalkers on the path itself, far apart. The climb is quiet on purpose.
- Pickup: what the ice holds (`upwater_cache`, bog-iron).

---

## 3. The Wellhead

**Layout.** A level of turf. Two turf houses either side of the way in. Fourteen standing stones in a ring twenty metres across, a gap on the river side. The spring in the middle under a low stone well-housing.

### THAW

- **Maren** and **Wren** at the edge of the water, outside the ring. Maren has the child by the hand. Wren is watching the flowers go.
- Arriving at the Wellhead, in either state, raises `ks_horn_wellhead`: the fostering horn reads differently from here on (§8). The toast is the Keepsakes one; nothing says to look.

### RIME (boss arena)

- Two of the Unsung on the level.
- A frost veil across the ring's gap.
- **The Leadvoice** sat on the far side of the spring, facing the gap, bent over what she has against her chest.

---

## 4. The choice

After the release, at the near side of the spring, two places to stand (`ending_choice`):

- *Lay the coal in the spring*
- *Keep the horn shut, and sit*

They are a pace apart. There is no confirmation and no description. See §10.

---

## 5. Enemies

All frost-taken have the frost-breath facing tell. Every move that covers ground shows its area on the floor for the length of the windup (`telegraph`).

### Upwalker (`upwalker`)

One of the dead of the lower steadings, on its way up the water to wait for a spring. It got this far. Heavy, rimed thick, slow. It stands in the way with a shoulder turned (`block_arc`, `block_chance`).

| Move | Telegraph | Notes |
|---|---|---|
| **Shoulder** (`shoulder`) | Turns side-on and drops the near shoulder, one slow step (0.9 s); a short fan glows | A shove with the whole body. Little damage. It puts the Bearer back 3 m, down the path. |
| **The fall** (signature) (`fall_forward`) | Stops, sways back on its heels, breath twice (1.3 s); a 1.4 × 3.6 m strip glows | It goes over on its face like a climber letting go. Heavy. Not blockable. It lies there 2.2 s before it gets its knees under it: open. |

### The Unsung (`unsung`)

Someone nobody sang for. Thin, the ice gone clear, very little left in it. Quick, in twos.

| Move | Telegraph | Notes |
|---|---|---|
| **Reach** (`reach`) | The right hand out, palm up, as if to be given something (0.5 s) | Parryable. Often the left after it (`reach_left`). |
| **Breath in** (signature) (`breath_in`) | The mask tips back and it draws a long breath, as before a first note (1.0 s); a 2.4 m circle glows | No note comes. The cold does. |

Any Song breaks one outright (`breaks_to`): a singer who has learned anything on the way up clears them with a breath. Nobody tells the player this. The first one they sing at tells them.

---

## 6. The Holdfast: the Leadvoice (`leadvoice`)

**Maren of Saltfell.** Larger than a person, sat, her cloak spread into the ice of the spring. A birch mask with no band. Against her chest a swaddle of clear ice bound three times round with woad-blue wool, and inside it a small mask.

**She must never read as a monster.** The rules the data and the script keep:

- **She has no strike.** No attack of hers opens a hand volume. The suite checks it.
- **She does not come for the Bearer.** She does not move from where she sits. In phase three she stands, and still does not move.
- **What hurts is her voice and the cold round her**, and both are aimed away: at the air between them, at the ground a long way off.
- **Close to her is the safest place in the arena**, until the Bearer is close enough to touch the child. Then she folds down over it and the cold puts the Bearer out of reach. It hardly hurts.
- **Killing her gives nothing.** No warmth. No Outsong plays when she is released. There is no boss music: when her bar comes up the world's music stops, and nothing replaces it.
- **The last quarter of her cannot be struck off.** It has to be sung.

**Arena:** the ring, ten metres to the stones, the well-housing in the middle. She is on the far side of it from the gap.

**Intro (no dialogue).** The player parts the veil. She is bent right over the child and does not look up. Within 10 m, or struck, she lifts her head. The bar appears: **THE LEADVOICE**. The music stops.

### Phase 1: sat (100–60%)

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Held note** (`held_note`) | Her mask comes up off the child and stays up, a thin breath, held (1.4 s); a 1.8 × 12 m strip glows from her toward the Bearer | The air along it freezes and stands, a wall of rime as high as a door, for 9 s. Two blows break it. The walls are what the fight is made of: she is putting things between them. |
| **Shelter** (`shelter`) | The Bearer within reach of the child: she folds herself down over it, both arms round (0.9 s); a 3.8 m circle glows | The cold comes off her back and puts the Bearer out to the edge of it. Hardly any damage. |
| **Not yet** (`not_yet`) | She breathes in as if to begin, and holds it, and does not begin (1.8 s) | With fewer than two of the Unsung standing, two stand up out of the ice between her and the Bearer. |

### Phase 2: her head up (60–25%)

Transition (2.4 s, invulnerable): her head comes right up, and her shoulders with it. Two of the Unsung stand.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Long note** (`long_note`) | She draws herself up and the breath goes on and on (2.0 s); a band glows from 4.6 m out to 13 m, all the way round | Everything in the band is frozen through. Close to her there is nothing: stand inside it. |
| **Come up** (`come_up`) | Her head turns to the gap in the stones and stays there (1.6 s) | An Upwalker comes in up the river and stands in the way. One at a time. |
| Held note (wider), Shelter, Not yet | as above | |

### Phase 3: on her feet (25–0%)

Transition (4.0 s, invulnerable; `rise`): she stands up, for the first time in fifteen years, the cloak tearing out of the ice of the spring. She is very tall. She does not step forward.

From here a blade does nothing (`p3_blade`). Within 4.4 m of her the prompt is one word: ***Sing***.

| | |
|---|---|
| **A verse** | The Bearer stands with his hands down and sings for 2.4 s. Three notes and what comes after them (the hum, `sfx_verse`). Any blow breaks it and it must be begun again. |
| **What a verse does** | Takes a third of what is left of her. Breaks every one of the Unsung near enough to hear. She bows her head over the child and is still for 2 s, and then she wants the Bearer further off (Shelter). |
| **Three verses** | and it is done. |
| Held note, Long note (twice), Shelter, Not yet, Come up | as above, all the while |

So the last of the fight is this: get inside the long note, stay outside her arms, keep the Unsung off for the length of a breath, and sing. It is what the neighbours came to her door to do, and what she could not start.

**Release.** After the third verse she sits down again, slowly, as she was. The walls of rime fall. The Unsung go. The veil falls as meltwater. Title card: **MAREN — RELEASED**. Nothing plays. On the ground in front of her, side by side: the **band** and the **mask** (§8). The prompts are *Take the band* and *Take the mask*.

She stays where she is sat. The choice (§4) opens beside the spring, a few steps from her.

**Sound notes:** there is no music from the intro to the choice. Her notes are breath, not pitch: the frost-breath tell, long. The only sung pitches in the fight are the Bearer's.

---

## 7. NPCs

THAW only: the last Melt. Format follows `data/npcs.json`.

### Maren (`maren`)

Thirties, here. A woad-blue mask-band, the mask pushed back; an oat-wool dress kilted up for the climb; a child's small cloak over one arm, in case. Easy with strangers, as a Leadvoice has to be. She does not know the Bearer. Model: `maren_thaw`. Two audiences (`chapters`).

**First audience**

1. "Have you come far? You look like you've come far."
2. "We came up to see the water go. She's never seen it go."
3. "Don't watch them out of sight, love. Turn round. Turn round when everyone else does."

**Second audience**

1. "I've an older one, down the water. Fostered, with boat-builders. Went off with a coal in a horn and wouldn't let me carry it as far as the boat."
2. "I said, keep it fed. As if anyone needs telling."
3. "Have you far to go?"

**lines_repeat**

- "It's loud, isn't it. It's always this loud the first day."
- "Have you far to go?"

### Wren (`wren`)

Five. A small mask on a cord round her neck, not on. Model: `wren`.

**lines_first**

1. "That one's going to the sea."
2. "And that one."

**lines_repeat**

- "And that one."

**lines_repeat** (shown all five knucklebones; sets `ks_knucklebones_shown`; she does not take them)

- "I've got some like that."
- "Mine have a bite in one. I did it. It didn't taste of anything."

**Keepsakes: "Knucklebones"** (begun at Saltfell, `THORNWOLD.md` §7)

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 3 | `ks_knucklebones_shown` | Speak to Wren carrying all five (THAW) | "Wren has a set like it. One of hers has a bite in it. She says she did it." |

**Keepsakes: "The fostering horn"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_horn_wellhead` | Arrive at the Wellhead | "The coal is still alight." |

---

## 8. Items, and the seven pieces

**Wren's Band** (`item_wren_band`, release drop)
> A mask-band of woad-blue wool, the nap worn off where it sat on wood. It was tied round the swaddle with a household knot, pulled tight with the teeth. It is far too long for what it went round, and was wrapped three times.

**Maren's Mask** (`item_maren_mask`, release drop)
> A mourning mask of pale birch, smooth, the brow cut the Saltfell way. The band is gone and the wood is darker where it sat. A mask is carved for one burial and burned on the hearth before morning. This one is fifteen winters old.

**Fostering Horn** (`fostering_horn`; its text from the Wellhead on, `desc_when`)
> The horn a child carries down the water. The coal inside has been fed for twenty years. It was given with an instruction, and the instruction was followed.

**Fostering Horn** (after the Outsong)
> A cow's horn with a soapstone stopper and a draught-hole, worn at the hip. It is empty. The inside is black to the lip.

### The seven pieces (`WORLD.md` §4), and where each is placed

All seven are findable before the Leadvoice. The `endings` suite checks each placement.

| # | Region | What | How it is found |
|---|---|---|---|
| 1 | Saltfell | the small mask on the low peg | `ks_child_mask`, inside the Longhouse door (*Take the small mask down*) |
| 2 | the Lowe | woad thread tied to a stone on the one closed barrow | `ks_woad_thread`, RIME (*Untie the thread*). Its knot is "pulled tight with the teeth", as the band's is. |
| 3 | Kettle Fjord | one set of footprints frozen into the ice | `ice_tracks`, RIME, out on the open ice (*Look at the tracks*): looked at, not taken. "The left stride is longer than the right. They do not go round anything." |
| 4 | Tarnhall | a scrap of woad wool on the latch of the barred door | `item_latch_wool`, RIME, outside (*Take the wool off the latch*) |
| 5 | Thornwold | the fifth knucklebone, on the drove-road, going east | `item_knucklebone`, RIME |
| 6 | Shepherd's Reach | Old Calder hums three notes of what she was singing | his second audience (`REACH.md` §7). The three notes are the Bearer's own, hummed at every Hearthstone since the Strand (`data/audio.json` `hum`). |
| 7 | the Coldwell | the fostering horn's text changes | arriving at the Wellhead; and Maren's second audience says what the instruction was |

Pieces 1, 3 and 4 were written in `WORLD.md` but not placed. They are placed now through their regions' generators.

---

## 9. The release beat and what she leaves

- **In the arena:** the third verse; she sits; the rime walls fall; the Unsung go; the veil melts; **MAREN — RELEASED**; silence.
- **Flag:** `ks_leadvoice_released`.
- **Drops:** `item_wren_band` (`release_drop`, raises `ks_wren_band_found`) and `item_maren_mask` (`release_drop2`), side by side in front of her.
- **Warmth:** none.
- **Music:** none (`release_outsong` false). The Outsong has been sung for six Holdfasts by nobody in particular. This one waits to see whether the Bearer will.
- **No hearth wakes here.**
- **The choice** opens at the spring.

---

## 10. The endings

Both run from the `ending_choice` hook through `EndingDirector` (ADR 0011). Every beat's time is data (`game.json` `endings`). **Nothing is said in either.** No narration, no title, no line of text until the credits.

### The Outsong (`ending_outsong`)

1. The Bearer stands at the spring, facing his mother across it. The HUD goes.
2. He puts the mask on. (The body changes to the Outsong robes, `bearer_outsong`; his hands are empty.)
3. He sings. This is the audio director's Outsong, the whole rite, and for once it has a Leadvoice: the voice that starts alone is his.
4. Under the first phrase the camera comes in, slowly, from behind his shoulder.
5. He kneels and opens the horn. A small warm light goes down into the water and out.
6. The melt goes out from the spring and does not stop at the stones. Maren and the child go with the frost. The dead in the river are gone. The light that comes up is not amber: it is the grey of a real spring morning.
7. Control comes back, with no HUD. The song is still going. The way out is the way he came in.
8. When he has walked out past the stones, the credits roll over the walk, and he can keep walking.
9. After the credits: the Strand at Saltfell, in spring. Grey and green and empty.

**The world after** (`World.spring()`): every area is its unfrozen ground under the grey light (the `spring` profile), with open water, nobody in it and nothing frost-taken. No area has a remembered evening to turn to. At any Hearthstone the Bearer can rest, and can ask it for more: *Warm the stone*. The answer is four words, *The horn is empty.* Inside the Longhouse door there are two masks on the low pegs.

### The Hearth Kept (`ending_hearth_kept`)

1. The Bearer stands at the spring. The HUD goes.
2. The stopper is pressed home. One small sound.
3. The remembered Melt comes back over the Coldwell, from the spring outward: brown water, loud, flowers in it. His mother is gone from where she sat. Down at the water's edge a woman has a small child by the hand.
4. He sits down by the spring, facing them.
5. The camera goes back and up, for a long time.
6. The credits roll over it. There is no music. There is the river.
7. While they roll, the frost comes onto his shoulders.

**The world after** (`World.kept()`): the Coldwell is the Melt. Every other area is RIME and no hearth will turn it. A kept save opens on the Bearer, sat, at the spring, and he does not get up. The pause menu still works. That is the whole of it: there is a newest Holdfast, and the player is looking at them.

### Credits

One column in the house type on a soft dark band, rolling up once, slowly (`CreditsUI`, `game.json` `credits`). The game's name, the house, the tools. A knot at the foot. No dedication, no last line.

---

## 11. New names

Added to `LEXICON.md`: the Ice-Falls, the Wellhead Steps (hearths), Wren's Band, Maren's Mask, Scrap of Woad Wool, the verse (the Bearer's singing at the wellhead). Checked against `tools/banned_terms.txt` and `docs/transposition/ORIGINALITY.md` §1–5: no bells, candles, wax, bees, choirs, runes or letters; nothing from another game.
