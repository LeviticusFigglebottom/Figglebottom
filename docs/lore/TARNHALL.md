# Region: Tarnhall

*Owner: narrative. Tier 2 per `SPEC.md` §8. Truth and backstory are in `WORLD.md` §5.4; voice rules in `WRITING.md`; the model for this file is `SLICE.md` (and `LOWE.md`, `KETTLE.md`). Ids are the data keys in `data/`.*

The great timber hall on an island in a mountain tarn, where seven neighbourhoods came up the water every Long Light to feast. The player climbs the Tarn Steps from Kettle Fjord, crosses the Tarn Causeway to the island, finds the hall's front doors barred from inside, goes round by the Byres, and comes into the hall through the cattle end. Thirty minutes, one Holdfast, two people.

**What the region must let the player infer, without anyone saying it:** the fish for the feast came from the trader's boat at Kettle; the guests started coughing; the Host barred the doors so nobody would carry it home, and then could not open them; he kept pouring. Nobody left. One guest meant to.

---

## 1. Area flow

```
the Tarn Steps ──> the Tarn Causeway ──(bridge)──> the island ──> the porch (doors barred)
                                                        │
                                                        └──> the Byres ──(frost veil)──> the Long Table
      ^
      └── Kettle Fjord
```

THAW: the tarn is open water and the causeway is the only way over. RIME: the tarn is frozen, and the island can be walked to across the ice, but the hall's front doors stay barred until the Host is released. The bar lifts on release (`gate_hall_doors`), and from then on the front door is the short way in from the causeway hearth.

Hearthstones (three; the third wakes on release):

| id | Name | Where | Notes |
|---|---|---|---|
| `hs_tarn_steps` | **the Tarn Steps** | beside the steps, two-thirds of the way up | First hearth. A soapstone ring under a turf shelter for rowers. |
| `hs_tarn_causeway` | **the Tarn Causeway** | the causeway's land end | Where the boats were drawn up for the feast. |
| `hs_byres` | **the Byres** | the byre yard, by the cattle door | Nearest hearth to the Holdfast. A trough turned over, the ring under it. |
| `hs_long_table` | **the Long Table** | the cold fire in the middle of the hall | Wakes on release (`release_hearth`, `require_flag` `ks_host_released`). |

Title cards (first entry to each zone, the UI serif in small caps, no subtitle):

- **TARNHALL** (the plaque at the causeway's end reads it in full)
- **THE TARN CAUSEWAY**
- **THE BYRES**
- **THE LONG TABLE**
- On release: **THE HOST — RELEASED** (quiet, bone-white, held 3 s)

---

## 2. The Tarn Causeway

**Layout.** The steps come up out of the Kettle side in turns and level out at the tarn's south shore. A dry-stone causeway runs out across the water to the island, kerbed both sides, broken once by a channel with a plank bridge over it. The hall stands on the island with its porch facing the causeway.

### THAW (first arrival is always THAW)

- A long evening. Boats drawn up at the causeway's land end, seven different kinds of oar.
- Noise from the hall carries the whole length of the causeway: a song, and a lot of people coming in late on the chorus.
- The doors stand propped open for the air, leaves back against the porch posts.
- No enemies.

### RIME (after the first rest)

- The tarn is white and the boats are in it to the gunwales.
- Enemies:
  - a Feast-guest on the steps, facing down them, a horn frozen to its fist;
  - a Hall-champion on the far side of the plank bridge, square to it (`champion_bridge`, once);
  - a Feast-guest on the porch before the barred doors;
  - a Feast-guest on the island's south shore, looking at the water.
- The doors are shut. The prompt is *Barred from the inside*.
- Pickup: a guest's horn on the porch (`tarn_horn`, warmth).

---

## 3. The Byres

**Layout.** A lower turf-roofed building against the hall's east gable, joined to it by a door. Stalls along the north wall, mangers under them. A cattle door in the south wall opens on the yard. The feast's fish came up in barrels, and the barrels are stacked in the yard.

### THAW

- Empty stalls; the cattle are out on the summer grazing. Barrels in the yard, most of them open. A smell of brine and smoke.
- Nobody here. Through the far door, the feast.

### RIME

- The barrels are frozen together in their stack. One head is half off, the nails half drawn (`item_barrel_head`).
- On the chopping block by the stack, the **Host's Carving Cleaver** (`feast_cleaver`).
- Enemies:
  - a Feast-guest sitting on an upturned barrel in the yard, its back to the cattle door; it stands when the Bearer passes (`pose` `sit`);
  - a Hall-champion at the cattle door, facing out (`champion_byre_door`);
  - two Cupbearers in the byre between the stalls, one each side, with nothing in their hands to carry.
- The door through to the hall has a frost veil across it.

---

## 4. The Long Table

**Layout.** The hall: 36 m long, 14 m wide, timber walls under a turf roof on two rows of posts. The long table runs most of its length on the north side with a bench either side of it. The high seat stands across the east end. A fire trench down the middle of the floor. The front doors at the west end, and the guest-post just inside them, wound with the tally cord.

### THAW

- The feast at full roar. The benches packed. Horns going hand to hand.
- **Lusse** standing on the open floor by the fire, conducting the chorus with a horn.
- **Ottar** just inside the front door with his boots on.
- The **Host** is not seen. His place at the high seat is empty, and his horn is going round.

### RIME (boss arena)

- The feast is still laid. Every horn on the table is full and skinned over with ice, set in front of someone.
- The guests are in their seats, white. When the Holdfast calls them, some of them stand.
- The fire trench is cold.
- **The Host** walks the length of the table with a horn, filling the horns in front of the guests one after another.
- Pickup, inside the barred door: **Ottar's Stick** (`item_ottar_staff`; sets `ks_ottar_staff_found`).

---

## 5. Enemies

All frost-taken have the frost-breath facing tell (`SPEC.md` §7). Every move that covers ground shows its area on the floor for the length of the windup, in the region's cold blue (`telegraph`), so what glows is what lands.

### Feast-guest (`feast_guest`)

A guest in good lichen-yellow and brown wool with a fur collar and a carved festival mask, drink frozen down its chest. Both hands are rounded fists of ice. Sits on benches and barrels (`pose` `sit`), and stands when the Bearer passes close (`rise_time` 1.6 s).

| Move | Telegraph | Notes |
|---|---|---|
| **Cuff** (`cuff`) | Right fist swung round flat, shoulder first (0.6 s) | Parryable. Often followed by the left. |
| **Left cuff** (`cuff_left`) | Weight goes over, the left fist low (0.45 s) | Only after a Cuff. |
| **The toast** (signature) (`toast`) | Both fists lifted together over the head, as if raising a horn; breath twice (1.2 s); a 2.2 m circle glows round it | Both fists come down on the floor. Everything in the circle is hit. Step out. |

### Cupbearer (`cupbearer`)

A slim young server in a short brown tunic and apron, felt cap, small mask. Both hands have grown into thin straight blades of ice. Quick. Comes in pairs and works from both sides (`flank`).

| Move | Telegraph | Notes |
|---|---|---|
| **Slice** (`slice`) | Blades crossed at the chest, a step in (0.35 s) | Two quick cuts. Parryable. |
| **Lunge** (`lunge`) | Right shoulder drops, the left blade goes back (0.6 s); a 1.0 × 5 m strip glows | Runs the strip blade first. |
| **Going round** (signature) (`going_round`) | Turns side-on with both blades out low like a tray (0.8 s); a 2.4 m circle glows | Three turns on the spot, a cut each turn. |

### Hall-champion (`hall_champion`)

A big hall guard in a quilted felt coat over a mail shirt, fur cape, carved oak war mask. A round board shield of ice has grown into the left forearm; the right fist is a mace-head of ice. Holds the shield up while it circles (`block_arc` 120°): strike it from the side or after it swings.

| Move | Telegraph | Notes |
|---|---|---|
| **Mace** (`mace`) | The ice fist raised behind the shield rim (0.9 s) | One heavy overhand. |
| **Shield bash** (`shield_bash`) | Shield squared, a short step (0.5 s) | Little damage, a lot of poise. Often followed by a Mace. |
| **Shield rush** (signature) (`shield_rush`) | Sets the shield and puts its head down behind it, breath held (1.0 s); a 1.6 × 7 m strip glows | Runs the strip behind the shield and knocks down whatever is on it. Cannot be blocked. Roll sideways. |

---

## 6. The Holdfast: the Host (`host`)

**Gaute Haug.** 4.0 m, an enormous heavy man in lichen-yellow and brown feast wool with a fur collar, a broad oak mask. The long timber feast table has grown from his spine like a ridge, drinking horns frozen to it. Carved seat-posts have fused to both hips.

**Arena:** the Long Table. The table and both benches are solid; the open floor south of them is where he fights. Frost veil at the byre door.

**Intro (no dialogue).** The player parts the veil. He is walking the table, filling horns. He does not look up. When the player is within 7 m or strikes him, he sets the horn down on the table in front of a guest and turns round. The health bar appears: **THE HOST**.

He fights the way a host keeps a guest: he blocks the way, he brings more people, he fills the floor.

### Phase 1: the feast (100–60%)

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Horn fist** (`horn_fist`) | Right fist, a horn frozen in it, drawn back across the body (0.9 s) | A heavy backhand, 3.8 m. Parryable. |
| **Table sweep** (`table_sweep`) | Turns his shoulder; the long table on his back swings round behind it (1.4 s); a fan of 160° glows from 1.8 to 7.5 m | The table end comes round through the fan. Whoever is in it is hit and slid 3 m outward; against a wall or a bench they are pinned there under the table edge (0.9 s, mash to break). Inside 1.8 m it passes overhead. |
| **Bench throw** (`bench_throw`) | Wrenches a bench up off the floor with both hands, over his head (1.3 s); a 2.2 m circle glows where the Bearer stands | The bench lands 0.5 s after it leaves his hands, on the circle, and breaks. Knocks down. |

### Phase 2: the second sitting (60–25%)

Transition (3.0 s, invulnerable; `raise_guests`): he spreads both arms over the table. Along the benches, two of the white guests stand up out of their places. Every horn in front of an empty place fills again, dark, and skins over. From now on he brings more guests and fills the floor.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Raise the guests** (`raise_guests`) | Both arms out over the table, palms up (1.6 s) | With fewer than two guests standing, two more stand up from the benches where they sat (at most three up). The horns in front of their places fill. |
| **Tip the horn** (`tip_horn`) | Lifts a great horn off the table at his back and tips it out ahead of him (1.2 s); a 1.2 m circle glows where it pours | Where it lands, frost spreads across the floor: 1.2 m to 6 m across over 3 s, and it stays 8 s. Its edge glows as it spreads. On the pool, frost bites every half second. |
| **Bench throw** | as phase 1 | Two benches, the second where the Bearer is running to. |
| Horn fist, Table sweep | as above | |

### Phase 3: the last round (25–0%)

Transition (2.8 s, invulnerable): the frost on the floor goes grey. He walks back to the table and stands at it, and the table on his back settles level with the one on the floor. From now on he keeps to the table.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Table sweep** | turns right round (1.6 s); a full ring from 1.8 to 7.5 m glows | as phase 1, all the way round. |
| **Pour** (`pour`) | The Bearer more than 6 m off: he turns to the table and lifts a horn (1.6 s) | No attack. He fills the horns along the table, his back to the Bearer: open. Hits do not stop him. Every guest standing is mended. Left alone 5 s, a guest stands at an empty place and he turns back. |
| Horn fist, Tip the horn, Raise the guests | as above | |

**Release.** At 0 he sets the horn down on the table and sits on the end of the bench, the table on his back settled along the one on the floor. The guests still standing sit down where they are. Across the hall the bar on the front doors lifts and the doors swing open by themselves (`gate_hall_doors`). The frost veil at the byre door falls as meltwater. Title card. On the end of the table where he sat is his own horn, the only empty one; the prompt is *Take the Host's cup*. On the inside of the door-post the guest-tally can now be untied.

**Music cue notes:** phase 1 is the hall noise with no song in it, benches scraping. Phase 2 adds the guests' feet on the boards and a low hum under the pour. Phase 3 is the pour alone, a horn filling, again, and again.

---

## 7. NPCs

THAW only. Format follows `data/npcs.json`.

### Lusse, hall-singer (`lusse`)

Tall, in a lichen-yellow and oat festival dress with an embroidered belt, a carved festival mask with a wide brow line. Many plaited cords hang from her belt; she plaits while she sings. Bossy about the chorus, generous with everything else. Model: `lusse`.

**lines_first**

1. "You came up the steps in time. Sit. No, there, by the post. We're on the ninth verse."
2. "The goat ate the sail. Then the mast. Then the man who said it couldn't. That's where you come in."
3. "Gaute had me plait him a tally cord for the door. Seven neighbourhoods. My fingers are raw and he still says it's short."
4. "Fish from the trader's boat. Good fish. Nobody's cooked so much fish since my wedding."

**lines_repeat** (default)

- "Again, from the goat. Louder."
- "Somebody's coughing on the far bench. Pass him a horn, it'll settle him."
- "You're flat. Everybody's flat. Gaute's flattest and he's the host, so that's how it goes now."

**lines_repeat** (after `ks_goat_song`)

- "There. Now you'll have it in your head till the Melt. I'm not sorry."

**lines_repeat** (after `ks_host_released`)

- "Somebody's opened the doors. Good. You could stand a spoon in the air in here."

**lines_repeat** (after `ks_guest_tally`)

- "Forty-one. Forty-two. Hold it still. Forty-one."
- "From the goat, then. From the start. Everybody."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `sing_goat_song` | gift `goat_song`, once (sets `ks_goat_song`) | free | Sing the chorus | "Not bad. Again, and this time come in when I point." |
| `buy_long_note` | buy `long_note`, once | 300 warmth | Learn the Long Note | "From the belly. Not the throat. Gaute holds it from the throat, and listen to him." |

**Keepsakes: "The guest-tally"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_lusse_met` | First conversation | "Lusse is on the ninth verse of the goat song and wants the chorus from everyone." |
| 2 | `ks_goat_song` | Sing the chorus with her | "Lusse had the chorus out of you. She said it was nearly right." |
| 3 | `ks_guest_tally_found` | Untie `item_guest_tally` from the door-post (RIME, after release) | "The guest-tally was on the inside of the door-post. The last knots were one knot, tied over and over." |
| 4 | `ks_guest_tally` | Talk to Lusse in THAW carrying the tally | "Lusse counted the tally twice and got two numbers, and started the goat song again from the first verse." |

### Ottar (`ottar`)

Fifties, a farmer from the far end of the water, past the falls, broad and weather-red, a plain felt hood and a short pine mask pushed up on his head. Boots on, coat on, horn in his hand. He has been going home since noon. Mannequin stand-in until a model exists.

**lines_first**

1. "I'm away. Boots are on. It's a long row and I want to be home before the light goes."
2. "Ottar. Up the far end, past the falls. The wife's on her own with the calving."
3. "Gaute says one more horn. He's been saying one more horn since noon."
4. "I've left my stick by the door so I don't forget it. Don't let me forget it."

**lines_repeat** (default)

- "Any minute now."
- "Hear the far bench barking? It's the smoke. He never could build a fire."
- "One more and I'm away."

**lines_repeat** (after `ks_ottar_staff`)

- "That's my stick. Where was that? I left it by the door."
- "Well. I'll sit for the end of the song, then."

**lines_repeat** (after `ks_host_released`)

- "Who's opened the doors? Feel that. You can smell the tarn."

**services:** none. *(Everything he has is packed to go.)*

**Keepsakes: "Ottar's stick"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_ottar_met` | First conversation | "Ottar has his boots on to row home before dark. He has had them on since noon." |
| 2 | `ks_ottar_staff_found` | Take `item_ottar_staff` from inside the barred door (RIME) | "Ottar's stick was leaning inside the barred door, where he left it so as not to forget it." |
| 3 | `ks_ottar_staff` | Talk to Ottar in THAW carrying the stick | "Ottar took his stick back and sat down again for the end of the song." |
| 4 | `ks_ottar_air` | Talk to Ottar after `ks_host_released` | "Somebody opened the doors, and Ottar went and stood in them." |

---

## 8. Items

Voice per `WRITING.md`: a plain fact, then one human detail. No morals.

**The Host's Cup** (`item_host_cup`, Holdfast release drop)
> A big ox-horn on a turned birch foot, banded in tin at the rim, from the high seat of Tarnhall. Every horn on the long table was full and frozen over. This one was dry, with a skin of dust inside it.

**Guest-Tally** (`item_guest_tally`)
> A long plaited cord of yellow and oat wool, knotted once for each guest let in at the door. Lusse plaited it; the knots are the Host's, big and careful. Near the end the knots are all one knot, untied and tied again until the wool has felted.

**The Goat Song** (`goat_song`, song)
> A hall song about a goat that ate a sail, then the mast, then the man who said it couldn't. Thirty-one verses and one chorus. Lusse sings the verses. Anyone in earshot is the chorus, and she stops the song until they are.

**Host's Carving Cleaver** (`feast_cleaver`, weapon)
> A broad black-iron cleaver with a knotwork oak handle and a ring at the butt, for carving at the feast. It goes through the joint and into the board under it. The ring is for hanging it by the high seat, on a nail he drove in himself, crooked.

**Ottar's Stick** (`item_ottar_staff`)
> A rowan walking stick with a horn cap, the bark left on for the grip. It was leaning inside the barred door, where you put a thing so you will see it on your way out. The mud on the tip is from the steps coming up.

**Fish-Barrel Head** (`item_barrel_head`)
> The round pine head of a fish barrel, branded with a trader's mark: a knot inside a ring. Forty barrels came up the water for the feast. This one had only been started on; the nails are half drawn.

---

## 9. The release beat and what he leaves

- **In the arena, at once:** he sets the horn down and sits on the bench end; the guests still up sit where they are; his frost pools go grey and are gone; the veil melts; the card.
- **The doors:** the bar lifts and the front doors swing open (`release_gates`: `hall_doors` sets the area flag `gate_hall_doors` and swings the leaves now; the rebuilt area builds them open).
- **Flag:** `ks_host_released` (`release_flag`), which turns both threads and shows the tally.
- **Drop:** `item_host_cup` (`release_drop`), set on the table end beside where he sat.
- **The tally:** the guest-tally pickup on the door-post (`appear_flag` `ks_host_released`), which raises `ks_guest_tally_found`.
- **Hearth:** `hs_long_table` wakes at the cold fire (`release_hearth`).

---

## 10. New names

Added to `LEXICON.md`: Ottar, the Goat Song, Guest-Tally, Host's Cup, Host's Carving Cleaver, the Byres hearth, the Long Table hearth. Checked against `tools/banned_terms.txt` and `docs/transposition/ORIGINALITY.md` §1–5: no bells, candles, wax, bees, choirs, runes or letters; nothing from another game.
