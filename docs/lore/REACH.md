# Region: Shepherd's Reach

*Owner: narrative. Tier 3 per `SPEC.md` §8. Truth and backstory are in `WORLD.md` §5.6; voice rules in `WRITING.md`; the model for this file is `SLICE.md` (and `LOWE.md`, `KETTLE.md`, `TARNHALL.md`, `THORNWOLD.md`). Ids are the data keys in `data/`.*

High pasture under the glacier: stone sheilings, a beck off the ice, a dry-stone fold on a shoulder of the fell. The player comes up the fell path out of Thornwold's east side onto the grass, passes the sheilings, crosses the beck, and climbs the trod to the High Fold. Thirty minutes, one Holdfast, two people.

**What the region must let the player infer, without anyone saying it:** an old shepherd with a cough walked up to the high fold in the night, barefoot, so his daughter would not catch it; she followed and found him; she has been calling the flock in to him ever since, as though he would want to count them. And a woman came up this fell at the Melt, before any of it, with a child on her shoulders, singing something the Bearer already knows.

---

## 1. Area flow

```
the Thornwold seam ──> the Fell Path ──> the Sheilings ──(the beck)──> the trod ──> the High Fold
```

THAW: the beck runs deep and cold in its cut and the only way over is the plank bridge. The flock is loose on the grass. RIME: the beck is iced to the brim and can be crossed anywhere, but seventy sheep stand frozen on the slope between it and the fold, every one of them facing the fold, and the way up winds between them.

Hearthstones (two; the third wakes on release):

| id | Name | Where | Notes |
|---|---|---|---|
| `hs_fell_path` | **the Fell Path** | where the path comes out onto the grass | First hearth. |
| `hs_sheilings` | **the Sheilings** | between the lower sheilings | Nearest hearth to the Holdfast. |
| `hs_high_fold` | **the High Fold** | inside the fold, away from the cairn | Wakes on release (`release_hearth`, `require_flag` `ks_fellcaller_released`). |

Title cards (first entry to each zone, the UI serif in small caps, no subtitle):

- **SHEPHERD'S REACH** (the plaque at the path's head reads it in full)
- **THE SHEILINGS**
- **THE HIGH FOLD**
- On release: **THE FELLCALLER — RELEASED** (quiet, bone-white, held 3 s)

---

## 2. The Sheilings

**Layout.** Three stone sheilings on the south side of the beck, turf-roofed, peat stacked against their lee walls.

### THAW (first arrival is always THAW)

- Sheep all over the grass, none of them in a hurry.
- A long rising call from up the fell. Every sheep looks up at once and goes on eating.
- Pickup: the **shepherd's whistle** on its nail at the lower sheiling (`item_shepherd_whistle`).
- No enemies.

### RIME

- The lower sheiling's door is on the latch. Beside it a pair of boots, toes to the wall.
- Pickup: **Calder's boots** (`item_calder_boots`, sets `ks_calder_boots_found`).
- Three Drovers: one on the path, one between the sheilings, one above the bridge, each stood where it stopped with the crook still in both hands.

---

## 3. The trod

**Layout.** Over the beck and up the slope to the gap in the fold wall.

### THAW

- **Sigga** on the slope beside the trod, calling the flock in. Her father is at the wall above her. They count at each other across the slope (see §7).

### RIME

- The seventy. They are obstacles: the path goes between them.
- Three Frost-rams among them. The frozen sheep do not move; the rams do.
- Pickup: what the frost holds below the fold (`fold_cache`, bog-iron).

---

## 4. The High Fold

**Layout.** A ring of dry-stone wall thirteen metres across with one gap, facing down the trod. Inside it the fold cairn.

### THAW

- **Old Calder** at the gap, putting the wall back, talking to the sheep by name.
- After the release, see §9.

### RIME (boss arena)

- A frost veil across the gap.
- **Old Calder** sat against the cairn, rimed over, his feet bare (`calder_rime`: not a foe; nothing to say).
- **The Fellcaller** stood beside him with her back to him, calling out over the wall at the slope.

---

## 5. Enemies

All frost-taken have the frost-breath facing tell (`SPEC.md` §7). Every move that covers ground shows its area on the floor for the length of the windup, in the region's cold blue (`telegraph`), so what glows is what lands.

### Drover (`drover`)

A herd in a fleece coat, long in the arm and leg, a crook of ice grown from both hands as one piece. Keeps a crook's length off (`keep_range`).

| Move | Telegraph | Notes |
|---|---|---|
| **Crook sweep** (`crook_sweep`) | The crook carried back over the left shoulder, both hands (0.7 s) | A long flat sweep, 3 m. Parryable. |
| **Leg hook** (`leg_hook`) | The crook turned over, hook down, slid out along the ground (1.0 s); a 1.0 × 5 m strip glows | Takes the Bearer by the leg and pulls him in to 1.5 m (mash to break). Then a Crook sweep. |
| **Whistle** (signature) (`whistle_in`) | Two fingers to the mask, head back, breath straight up (0.9 s) | No damage. Every idle Frost-ram within 18 m lifts its head and comes. |

### Frost-ram (`frost_ram`)

A fell tup the frost took with its head down. The horns have gone on growing in ice, a full turn more than a ram's should. A quadruped (QuadRig poses over its one walk clip, like the Hearthhound and the Rime-stag). It backs off to charging distance.

| Move | Telegraph | Notes |
|---|---|---|
| **Butt** (`butt`) | A step back, head tucked (0.5 s) | A short drive forward, 2.4 m. |
| **Charge** (signature) (`charge`) | Head right down, one forefoot scraping, breath forward (1.0 s); a 1.5 × 11 m strip glows | It runs the length of the strip. Knocks down. Not blockable. It cannot stop: it overruns and stands shaking its head (1.3 s). |
| **Kick** (`kick`) | Only at whoever is behind it (`behind_only`): the hindquarters drop, a glance back (0.45 s) | Both hind feet, 2.2 m behind. |

---

## 6. The Holdfast: the Fellcaller (`fellcaller`)

**Sigga Calder.** 3.4 m, broad, in a coat of whole fleeces rimed stiff. A ram's horns curl either side of her mask and frame it. A calling horn in her right fist.

**Arena:** the fold, thirteen metres to the wall. The cairn off-centre, her father against it. Frost veil in the gap.

**Intro (no dialogue).** The player parts the veil. She is beside her father with her back to him, calling out over the wall: the long rising call, over and over, to a slope where nothing has moved for fifteen years. When the player is within 8 m or strikes her, the call stops in the middle. She lowers the horn and turns. The health bar appears: **THE FELLCALLER**.

She fights the way she worked: with her voice, and by sending the flock where she wants it.

### Phase 1: calling (100–65%)

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Horn swing** (`horn_swing`) | The calling horn drawn back across the body (0.8 s) | One long backhand, 3.4 m. Parryable. |
| **Rising cry** (`rising_cry`) | The horn to the mask, her head goes back, breath straight up (1.5 s); a 6.5 m circle glows round her | The cry goes up and everything in the circle is staggered. Little damage. Roll through the end of it, or be outside. |
| **Head down** (`head_down`) | She drops her head till the horns point at the Bearer and scrapes one foot back (1.1 s); a 1.9 × 13 m strip glows | She runs the length of it. Knocks down. Not blockable. She overruns (1.4 s). |

### Phase 2: the flock (65–30%)

Transition (3.0 s, invulnerable; `summon`): both arms up, the horn over her head, a call that does not rise. Two Frost-rams come over the fold wall.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Call them in** (`call_them_in`) | One arm out flat to the side, a long level call (1.6 s); a 3.2 × 20 m strip glows across the fold through where the Bearer stands | The flock comes over the wall and down the strip in a rush (`HerdRun`). Whoever the front goes over is knocked flat. Step out of the strip. |
| **Bring tups** (`bring_tups`) | Two short calls, the horn dipped twice (1.2 s) | With fewer than two Frost-rams standing, one more comes over the wall. |
| Horn swing, Rising cry, Head down | as above | |

### Phase 3: the count (30–0%)

Transition (3.0 s, invulnerable): she goes back to her father, however far the fight has gone, and stands over him, between him and the Bearer. From now on she will not go more than 7 m from him (`guard_r`).

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Rising cry** | as phase 1, twice in a row | |
| **Call them in** | as phase 2, and a second strip across the first | A cross. One quarter of it is safe. |
| **Count them** (`count_them`) | The Bearer more than 6 m off: she turns to her father, crouches to his height and calls once, low, the way you call a flock in for somebody else to count (1.6 s) | No attack. Her back is to the Bearer: open. Hits do not stop her. Left alone 5 s, she stands and turns back. |
| Horn swing, Head down | as above | |

**Release.** At 0 she makes one soft call, not rising. Every sheep on the slope lies down at once. The tups go down with them. She kneels beside her father. The frost veil falls as meltwater. Title card. By his hand is the **fold-tally**; the prompt is *Take the fold-tally*.

**Music cue notes:** phase 1 is the call and the wind. Phase 2 adds hooves, far off and then not. Phase 3 is quieter than either: the low call, and after it nothing.

---

## 7. NPCs

THAW only. Format follows `data/npcs.json`.

### Old Calder (`old_calder`)

Seventies, small and bow-legged, a fleece jerkin, a hazel stick through his belt, an oak mask pushed up on his forehead when he is working. Counts everything that moves. Model: `old_calder`. Two audiences (`chapters`).

**First audience** (sets `ks_calder_met`)

1. "Hold still, Brokenhorn. Not you. Her. The one with the torn ear."
2. "Wall comes down every winter and I put it back every summer. The wall and I have an understanding."
3. "That's my lass calling. Sigga. She'll have them in by dark, and then she'll count them, and she'll get forty-three."
4. "It's forty-four. She's left the same one out since she was six. I've never said which."

**Second audience** (sets `ks_calder_hum`; `WORLD.md` §4.6)

1. "Old Leadvoice's lass came up this way at the Melt. She's Leadvoice herself now, they tell me. I still see her with her knees skinned."
2. "Had a little one up on her shoulders. Going up to see the water go."
3. "Singing to it. Not one of the ones for the dead, I know those, I've stood outside enough doors. This went"
4. "Mm. Mm, mm." *(the line carries a sound, `line_sfx`: three hummed notes, A–D–F, pitched down to an old man's chest. They are the three the Bearer hums resting at a Hearthstone, and has since the Strand.)*
5. "No. It's gone. She'd know how it goes on."

**lines_repeat** (default)

- "Forty-one, forty-two. Where's Smudge. There's Smudge."
- "Mind the beck. It's colder than it looks and it looks cold."

**lines_repeat** (shown his own boots; sets `ks_calder_boots_shown`)

- "Those are mine."
- "I've got mine on. Look."
- "Well. Put them by the door. Toes to the wall, or she'll only move them."

**lines_repeat** (after `ks_fellcaller_released`)

- "Wall's done. First time it's been done by dark since I was a young man."
- "I might sit a while."

### Sigga Calder (`sigga`)

Forties, tall, a fleece over one shoulder, a calling horn at her belt she does not need. Brisk. She has run the flock for twenty years and lets her father think he does. Model: `sigga_thaw`.

**lines_first**

1. "Stand there and they'll go round you. Stand anywhere else and they'll go through you."
2. "Sigga. That's my father up at the wall, putting back what he put back last year."
3. "He says forty-four. There are forty-three. I can count. He taught me."
4. "He's had a cough since shearing. He says it's the wool. Before that it was the hay."

**lines_repeat**

- "They come to a call. Dogs are for people who can't call."
- "If he asks, I've had my supper."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `give_fleece` | gift `armour_fleece`, once | free | Take the spare fleece | "It's his old one. He won't wear it, he says it makes him cough. Everything makes him cough." |

Within earshot of her (`overhear`, before the release, across the slope):

> **Sigga:** "Forty-three!"
> **Calder:** "Forty-four!"
> **Sigga:** "Forty-three, Da. I've been round twice."
> **Calder:** "Then you've left her out twice."
> **Sigga:** "Left who out?"
> **Calder:** "Go round again."

**Keepsakes: "Calder's boots"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_calder_met` | First audience with Calder | "Old Calder makes the flock forty-four. Sigga makes it forty-three." |
| 2 | `ks_calder_boots_found` | Take the boots from the sheiling door (RIME) | "A pair of boots stood by the sheiling door, toes to the wall. The door was on the latch." |
| 3 | `ks_fold_tally_found` | Take `item_fold_tally` at the cairn (release) | "The fold-tally was by his hand at the cairn. Forty-three notches, and one cut small." |
| 4 | `ks_calder_boots_shown` | Speak to Calder carrying the boots (THAW) | "Calder says the boots are his. He says he has his on." |

Calder's hum has no journal line. It is not a keepsake of the Reach.

---

## 8. Items

Voice per `WRITING.md`: a plain fact, then one human detail. No morals.

**Fold-Tally** (`item_fold_tally`, Holdfast release drop)
> A hazel stick notched down one edge: forty-three notches, one for every ewe put to the fell. Under them is one more, cut smaller, by a hand thirty years younger. Calder ran his thumb down it every night, and the small one is worn smooth.

**Calder's Boots** (`item_calder_boots`)
> A pair of herd's boots, resoled more than once, the left heel worn down on the outside. They stood by the sheiling door with the toes to the wall, and the door was on the latch. They are dry inside.

**Shepherd's Whistle** (`item_shepherd_whistle`)
> A whistle cut from a ewe's shin-bone, two holes, for working a dog at distance. Calder made it for Sigga when she was eight. She learned to call instead, and the lanyard is still tied for a child's neck.

**Shepherd's Fleece** (`armour_fleece`, body; Sigga's gift)
> A coat of two fleeces sewn skin-side in, the wool left long, belted with rope. It turns sleet, and mostly it turns a tup's horn. One pocket is full of crumbled oatcake, kept for a ewe called Smudge.

---

## 9. The release beat and what she leaves

- **In the arena, at once:** one soft call; every sheep on the slope lies down; the tups go down; she kneels by him; the veil melts; the card.
- **Flag:** `ks_fellcaller_released` (`release_flag`).
- **Drop:** `item_fold_tally` (`release_drop`, `at_point`) by her father's hand, which raises `ks_fold_tally_found`.
- **The flock:** lying, on the slope, in every later RIME (`release_flock` now; the area's own flagged props on rebuild).
- **Hearth:** `hs_high_fold` wakes inside the fold (`release_hearth`).
- **After release, THAW:** Calder is sat on the fold wall, which is finished, his boots off beside him. Sigga stands by him (`sigga_fold`). Within earshot:
  > **Sigga:** "Forty-four."
  > **Calder:** "There. Who was it?"
  > **Sigga:** "Me. You've got me down as a ewe."
  > **Calder:** "You came when you were called. That's all the stick knows."
  > **Sigga:** "Since when?"
  > **Calder:** "Since you were six."
  > **Sigga:** "Put your boots on, Da."
  > **Calder:** "In a bit."

---

## 10. New names

Added to `LEXICON.md`: Sigga Calder (THAW), the Fell Path, the High Fold (hearths), Brokenhorn and Smudge (ewes), Fold-Tally, Calder's Boots, Shepherd's Whistle, Shepherd's Fleece. Checked against `tools/banned_terms.txt` and `docs/transposition/ORIGINALITY.md` §1–5: no bells, candles, wax, bees, choirs, runes or letters; nothing from another game.
