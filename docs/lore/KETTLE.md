# Region: Kettle Fjord

*Owner: narrative. Tier 2 per `SPEC.md` §8. Truth and backstory are in `WORLD.md` §5.3; voice rules in `WRITING.md`; the model for this file is `SLICE.md` (and `LOWE.md`). Ids are the data keys in `data/`.*

A deep fjord under sheer walls. In the Hearth-months it freezes and the fishing moves out onto the ice. The sickness came ashore here. The player comes down the Kettle Road from the Lowe, walks the Landing Ice under the south wall, passes the Fish-Houses on their stilts, and ends at the Breathing Hole out on the ice by the fjord head. Thirty minutes, one Holdfast, three people.

**What the region must let the player infer, without anyone saying it:** a boy went out on new ice to fetch someone and did not come back; an old man has been cutting the same hole ever since; the boat at the jetty brought something besides fish, and one of its crew knows it and keeps apologising.

---

## 1. Area flow

```
the Kettle Road ──(seam)──> the Landing Ice ──(jetties round the spurs)──> the Fish-Houses ──> the ice ──(frost veil)──> the Breathing Hole
      ^
      └── the Lowe
```

THAW: open water. The shelf is cut twice by rock running into the fjord, and the jetties go round the ends. RIME: one sheet of ice wall to wall. The player can walk anywhere, but the crevasses and the thin ice round the cut holes give way underfoot.

Hearthstones:

| id | Name | Where | Notes |
|---|---|---|---|
| `hs_landing_ice` | **the Landing Ice** | the shelf where the road comes down | First hearth. A soapstone ring under an upturned sledge. |
| `hs_fish_houses` | **the Fish-Houses** | the shelf by the westmost house | Beside a fish-kettle's fire ring. Nearest hearth to the Holdfast. |
| `hs_breathing_hole` | **the Breathing Hole** | on the ice, at the hole's south edge | Cold until the Ice-Cutter is released; then it becomes a Hearthstone (`release_hearth`). |

Title cards (first entry to each zone, the UI serif in small caps, no subtitle):

- **KETTLE FJORD** (the plaque at the road's foot reads it in full)
- **THE LANDING ICE**
- **THE FISH-HOUSES**
- **THE BREATHING HOLE**
- On release: **THE ICE-CUTTER — RELEASED** (quiet, bone-white, held 3 s)

---

## 2. The Landing Ice

**Layout.** The road comes down a cleft in the south wall onto a shelf of shingle and rock about 8 m wide. Boats are drawn up on it. A plaque at the road's foot. West of the first spur the shelf narrows, and the jetty runs out round the rock.

### THAW (first arrival is always THAW)

- A warm evening, the water flat. Gulls. Boats out on the water, rowing slowly home.
- Smoke from the fish-kettles further along. The smell reaches the road before the houses do.
- No enemies.

### RIME (after the first rest at the Landing Ice)

- The fjord is a single white floor. The boats that were out are under it, close to the surface, oars still shipped.
- One crevasse runs out from the west spur, a long dark line in the white. Thin ice gives under the Bearer in under a second.
- Enemies:
  - an Ice-fisher kneeling at a cut hole off the shelf, jigging a line that is not there;
  - an Ice-fisher on the road, facing down it;
  - a Sealer at the end of the west jetty, crouched over the ice with its hook ready, waiting.
- Pickup: the **Sealer's Harpoon** (`sealer_harpoon`), frozen into the ice beside a boat that was leaving.

---

## 3. The Fish-Houses

**Layout.** Three houses on stilts over the water between the spurs, each with a plank walk to the shore. The fish-kettles stand on the shelf in their fire rings. The trader's boat ties up at the middle house.

### THAW

- The big iron fish-kettles steam. Somebody is stirring one with a ladle as long as an oar.
- **Ivo** on the shelf by the westmost house with the sledge-dogs, harnessing them and being told he is not going anywhere. Nobody is telling him; he is saying it himself, in someone else's voice.
- The trader's boat at the middle house, its sail half furled. **Halla** on the platform with her knot-cord, counting.
- **Sten** sits on a crate at the foot of the middle walk, coughing into his elbow, apologising to everybody who goes by.
- Inside the westmost house: a pot on the hook over the fire. A bowl and a spoon on the bench beside it.

### RIME

- The houses stand in the ice to the knee of their stilts. The middle house's mooring post has a knot-cord tied round it (`item_halla_cord`).
- In the westmost house the pot is frozen on its hook with the ladle standing up in it (`item_kettle_ladle`; sets `ks_ivo_supper`).
- In the eastmost house, on the bench where the tools were kept, a spare **Ice-Cutter's Auger** (`ice_auger`).
- Enemies:
  - two Sledge-dogs in harness on the ice below Ivo's place, side by side, facing out toward the fjord head;
  - an Ice-fisher at the thin ice by the middle house;
  - a Sealer on the shelf by the east spur;
  - an Ice-fisher at the fjord head, standing where the sledge tracks run out.

---

## 4. The Breathing Hole

**Layout.** Out on the ice by the fjord head, 15 m off the shelf: a round of ice 30 m across ringed with pressure ridges and broken floes, with a gap to the south. In the middle, a hole a little over three metres across, the water in it black and moving. The ice round its rim is cut fresh, the shavings still white.

### THAW

- Open water. Nothing marks the place.

### RIME (boss arena)

- A frost veil across the gap in the ridges.
- **The Ice-Cutter** kneels at the north rim of the hole with his back to the far shore, drilling at the edge. A heap of shavings beside him. The sledge traces that have grown from his waist lie out across the ice behind him.

---

## 5. Enemies

All frost-taken have the frost-breath facing tell (`SPEC.md` §7). Every move that covers ground shows its area on the floor for the length of the windup, in the slice's cold blue (`telegraph`), so what glows is what lands. Ice that breaks shows black water for as long as it stays open (`break_ice`).

### Ice-fisher (`ice_fisher`)

A hunched fisher in layered grey furs and felt hood, plain pine mask. Both hands have grown into long curved ice-picks. Kneels at holes that are not there.

| Move | Telegraph | Notes |
|---|---|---|
| **Pick** (`pick`) | Right pick drawn back to the shoulder (0.5 s) | A quick jab. Parryable. Often followed by a second Pick with the left. |
| **Left pick** (`pick_left`) | Weight forward, left shoulder drops (0.4 s) | Only after a Pick. |
| **Cut a hole** (signature) (`cut_hole`) | Drops to one knee, both picks raised over the head (1.4 s); a 2 m circle glows where the Bearer stands | Hacks the ice. The circle breaks to black water for 6 s. Off it in a second or go under. |

### Sealer (`sealer`)

A heavy hooded hunter in grey hide. The right forearm has fused into a thick ice club, the left hand into a hook.

| Move | Telegraph | Notes |
|---|---|---|
| **Club** (`club`) | Club raised high behind the head, frost-breath puffs (1.0 s) | One heavy overhand. Not parryable. |
| **Backhand** (`backhand`) | Feet shuffle round (0.5 s) | Only after a Club. |
| **Hook** (signature) (`hook`) | Left arm thrown back low, hook turned out, breath held (1.0 s); a 1.2 × 5 m strip glows | The hook catches and drags the Bearer in to 1.5 m (mash to break), then a Club. Roll sideways. |

### Sledge-dog (`sledge_dog`)

A lean cream and grey dog in harness, frozen traces trailing. Comes in pairs. Fast. A quadruped (QuadRig poses over its one walk clip, like the Hearthhound).

| Move | Telegraph | Notes |
|---|---|---|
| **Snap** (`snap`) | Crouches, ears back, snort (0.45 s) | A short lunge bite, 2.5 m. |
| **Run down** (signature) (`run_down`) | Drops low, the traces tighten behind it (0.7 s); a 1.2 × 9 m strip glows | Runs flat out along the strip and through whoever is on it. Knocks down. |
| **Pairs** | | Two dogs share a target from opposite sides (`flank`): one circles while the other comes in. |

---

## 6. The Holdfast: the Ice-Cutter (`ice_cutter`)

**Old Pell.** 3.0 m, tall and bowed, grey furs and a felt hood, a pine mask with a madder band. A long iron ice-auger has grown through his right forearm, pointing down. Frozen sledge traces trail from his waist behind him, the harness empty.

**Arena:** the Breathing Hole. The hole at the centre is a thin-ice volume that takes the Bearer at once. Ridges round the edge. Frost veil at the south gap.

**Intro (no dialogue).** The player parts the veil. He keeps drilling at the rim. The player can walk right round the hole to him. When the player is within 6 m or strikes him, he pulls the auger out of the ice, knocks the shavings off it against his boot, and stands. The health bar appears: **THE ICE-CUTTER**.

He fights to keep the hole open and the Bearer away from it, and in the end he drags them to it.

### Phase 1: the hole (100–60%)

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Auger thrust** (`auger_thrust`) | Auger arm drawn back, the bit turning (0.8 s) | A long downward thrust, 3.4 m. Parryable on the bit. |
| **Drill down** (`drill_down`) | Sets the auger point to the ice and leans on it, breath forward (1.4 s); a 2.4 m circle glows under the Bearer | The ice there breaks to black water for 7 s. Off it in a second or go under. |
| **Trace** (`trace`) | Left hand gathers the traces at his waist, then flings them (1.2 s); a 1.4 × 10 m strip glows | The frozen trace catches and drags the Bearer toward the hole, not toward him, to its rim (mash to break). Then an Auger thrust. |

### Phase 2: the rings (60–25%)

Transition (2.6 s, invulnerable): he stands over the hole and cuts a ring round the whole arena with one turn of the auger. The ice between 9 and 10.5 m from the hole breaks open and stays open for the phase: a band of black water that can only be crossed quickly (a roll, a sprint). From now on he breaks the floor.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Ring cut** (`ring_cut`) | Turns once on the spot, the auger tip trailing on the ice (1.3 s); a ring from 2.5 to 5 m round him glows | That ring drops away for 6 s. The answer is to stand close or stand far. |
| **The team** (`dog_team`) | Whistles through the mask, looks back over his shoulder; a 2.4 × 18 m strip glows past the Bearer (1.6 s) | The dead dog team runs down the ice behind him and on past, in a line, and is gone. Knocks down. |
| Phase 1 attacks | as above | Drill down opens two holes, the second where the Bearer runs to. |

### Phase 3: the hour (25–0%)

Transition (2.8 s, invulnerable): the ring closes over, white. He goes back to the hole and kneels at it. From now on he keeps within 4 m of the hole, slower, and does not follow.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Auger thrust** | as phase 1, slower (1.0 s) | |
| **Trace** | as phase 1 (1.4 s) | |
| **Cut it fresh** (`cut_fresh`) | The Bearer is more than 5 m off: he turns to the hole, kneels, and sets the auger to the rim (2.0 s) | No attack. He drills at the rim, his back to the Bearer: open. Hitting him does not stop him. Left alone for 5 s, he stands. |

**Release.** At 0 he kneels at the rim and lets the auger rest. The hole skins over: black water to grey to white, in about two seconds. The hazard under it is gone, now and in every later visit. The frost veil falls as meltwater. Title card. The Breathing Hole hearth takes from the Bearer's horn by itself. In the middle of the new ice, frozen into it palm up, is **Ivo's mitten**; the prompt is *Chip the mitten free*.

**Music cue notes:** phase 1 is the creak of the ice and the bite of the auger. Phase 2 adds a low drone under the ring cut. Phase 3 is the auger alone, slowing, until it stops.

---

## 7. NPCs

THAW only. Format follows `data/npcs.json`.

### Ivo (`ivo`)

Fourteen, in an oversized grey fur coat that was someone else's first, a small pine mask with a madder band, a sledge harness coiled over his shoulder, mismatched mittens. Clever, impatient, and sure he is right about the ice. Model: `ivo`.

**lines_first**

1. "Hold that one. Not by the collar, she bites."
2. "Grandfather says the ice isn't made yet. It's made. I walked on it this morning, out past the houses."
3. "The healer's across at the far landing. Somebody's got to fetch her. Everybody keeps saying somebody."
4. "Lost a mitten in the dog-pen. This one's Grandfather's. Don't tell him, he'll have me looking for it till dark."

**lines_repeat** (default)

- "I'm not going anywhere. That's what he said to say."
- "The dogs know the way. The dogs always know the way."
- "He's put my supper on. I'll eat it when I'm back. When I'm back from the pen, I mean."

**lines_repeat** (after `ks_ivo_supper`)

- "Fish again. He only knows the one way. You'd think in sixty years."

**lines_repeat** (after `ks_ivo_mitten`)

- "That's mine. Where was it? I had it this morning."
- "There. Both my own. You can give Grandfather his back, I'm not going near him."

**services:** none. *(Ivo has nothing to sell and nothing he would give a stranger.)*

**Keepsakes: "Ivo's mitten"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_ivo_met` | First conversation | "Ivo is harnessing the dogs and says he is not going anywhere." |
| 2 | `ks_ivo_supper` | Take the ladle from the frozen pot in the westmost house (RIME) | "The supper was still on the hook. The ladle was frozen standing up in it." |
| 3 | `ks_ivo_mitten_found` | Chip `item_ivo_mitten` out of the new ice over the hole (release) | "The mitten was in the ice where the hole had been, palm up." |
| 4 | `ks_ivo_mitten` | Talk to Ivo in THAW carrying the mitten | "Ivo put the mitten on. Both of his are his own now." |

### Halla, trader (`halla`)

Fifties, a southerner with a sea-cloak and a weathered face that sees everything as cargo, a knot-cord wound round her wrist. Fair, hard, quick. She sold the fish for the Tarnhall feast this week and is pleased with the price. Mannequin stand-in until a model exists.

**lines_first**

1. "If you're buying, I've salt, needles and a little iron. If you're selling, I've no room."
2. "Halla. That's my boat, and that's my cord, and every knot on it's mine."
3. "Sold the whole catch to the Tarnhall people for their feast. Forty barrels. They'll be eating it till the Melt."
4. "We go on the morning tide. Sten'll be better at sea. It's the land air that's doing it."

**lines_repeat** (default)

- "Forty barrels off, forty barrels paid for. I like a week like that."
- "Don't mind Sten. He's always been a cougher."

**lines_repeat** (after `ks_halla_cord`)

- "That's not my knot. I don't tie it like that. One man, sick."
- "Sten. Come here. No, stay there. Stay there."

**lines_repeat** (after `ks_ice_cutter_released`)

- "I've put him in the end house by the fire. He can come down on the next boat. There's always a next boat."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `buy_bog_iron` | buy `bog_iron` ×1, repeatable ×3 | 140 warmth | Buy a lump of iron | "Southern iron. Better than your bog stuff. Don't tell your smith." |
| `buy_harpoon` | buy `sealer_harpoon`, once | 560 warmth | Buy a sealing harpoon | "Took it off a sealer in a bad year for him. Line's new. Mostly." |
| `buy_deep_gourd` | gourd_up, once | 320 warmth | Trade for a stoppered flask | "Keep the cork in. That's all the advice you get for free." |

**Keepsakes: "Halla's cord"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_halla_met` | First conversation | "Halla keeps her cargo on a knot-cord and says every knot on it is hers." |
| 2 | `ks_halla_cord_found` | Untie `item_halla_cord` from the mooring post at the middle house (RIME) | "Halla's cord was tied to the mooring post. There was a knot at the end in another hand." |
| 3 | `ks_halla_cord` | Talk to Halla in THAW carrying the cord | "Halla read the last knot and called Sten over, and then told him to stay where he was." |
| 4 | `ks_halla_bed` | Talk to Halla after `ks_ice_cutter_released` | "Halla has put Sten by the fire in the end house." |

### Sten, Halla's crewman (`sten`)

Twenties, thin, a good oar. Sits on a crate at the foot of the middle walk and coughs into his elbow and says sorry. He knows. Mannequin stand-in until a model exists.

**lines_first**

1. "Sorry. Don't mind me. It's the crossing, it gets in your chest."
2. "Sten. I row for Halla. When she lets me. She says I cough out of time."
3. "We'll be gone in the morning. Nobody here needs to catch anything off me."
4. "I'd shake your hand. Best not."

**lines_repeat**

- "Sorry."
- "It's nothing. It's the crossing."
- "Hot in here, isn't it. Is it just me."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `give_icefur` | gift, once | free | Take Sten's fur coat | "Have it. I'm roasting. Don't let her see, it's on the cargo cord." |

---

## 8. Items

Voice per `WRITING.md`: a plain fact, then one human detail. No morals.

**Ivo's Mitten** (`item_ivo_mitten`, Holdfast release drop)
> A child's mitten of felted grey wool with a leather palm, the thumb darned in a different grey. It was frozen into the new ice over the hole, palm up. The darn is his grandfather's; the stitches are too big.

**Kettle Ladle** (`item_kettle_ladle`)
> An iron ladle as long as an arm, for the fish-kettles, with a hook at the end to hang it on the pot. It was standing upright in a pot of supper on the hook in the end house. The fire under the pot had been banked up and banked up again.

**Halla's Knot-Cord** (`item_halla_cord`)
> A trader's cargo cord, tarred, a knot for every barrel and bale and passenger, in the trader's own tight hand. The last knot is tied loose, by someone who knew the knots but not well. It says one man, sick.

**Ice-Cutter's Auger** (`ice_auger`, weapon)
> A long iron ice-auger with an oak cross-handle, for cutting fishing holes. Used as a spear it does not care much what it goes through. The leather on the shaft is worn through in two places, where two hands held it every winter.

**Sealer's Harpoon** (`sealer_harpoon`, weapon)
> A barbed bog-iron head on a bone foreshaft and an ash shaft, a coil of rawhide line tied below the head. Sealers wait at a breathing hole for hours to throw it once. The line has been spliced so often that it is mostly splice.

**Ice-Fur Coat** (`armour_icefur`, body; Sten's gift)
> A coat of grey sheepskin worn fleece-in, with a felt hood, made in the south for the crossing. It is too warm for a summer evening. Sten gave it away in one.

---

## 9. The release beat and what he leaves

- **In the arena, at once:** he kneels at the rim and lets the auger rest; the hole skins over, black to grey to white; the ring and every broken patch close; the veil melts; the card; the hearth wakes; the mitten in the new ice.
- **Flag:** `ks_ice_cutter_released` (`release_flag`), which turns both threads.
- **Drop:** `item_ivo_mitten` (`release_drop`), set into the middle of the closed hole, not toward the Bearer, and it raises `ks_ivo_mitten_found`.
- **Seal:** `release_seal` closes the hole's own thin-ice hazard and its water, now and on every rebuild of the area.
- **Hearth:** `hs_breathing_hole` (`release_hearth`).

---

## 10. New names

Added to `LEXICON.md`: Halla, Sten, the Breathing Hole hearth, Ice-Cutter's Auger, Sealer's Harpoon, Ice-Fur Coat. Checked against `tools/banned_terms.txt` and `docs/transposition/ORIGINALITY.md` §1–5: no bells, candles, wax, bees, choirs, runes or letters; nothing from another game.
