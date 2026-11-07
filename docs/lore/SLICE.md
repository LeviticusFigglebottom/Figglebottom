# Vertical slice: Saltfell

*Owner: narrative. Tier 1 per `SPEC.md` §8. Truth and backstory are in `WORLD.md` §5.1; voice rules in `WRITING.md`. Ids are suggested data keys.*

Saltfell is a turf-and-stone steading on a cliff shelf above a shingle beach. The player lands on the Strand, climbs to the yard, and ends in the Longhouse. Twenty minutes, one Holdfast, two people.

**What the slice must let the player infer, without anyone saying it:** a man went out in a boat and did not come back right; his wife is somewhere just out of sight in THAW and enormous in RIME; there is a child's mask on a peg that the player will assume is their own; a place is set at the table every night.

---

## 1. Area flow

```
saltfell_strand  ──(cliff path)──>  saltfell_steading (yard)  ──(Longhouse door, frost veil)──>  saltfell_longhouse
      ^                                    |
      └──── shortcut: net-loft ladder ─────┘   (opened from the yard side, RIME)
```

Hearthstones:

| id | Name | Area | Notes |
|---|---|---|---|
| `hs_boat_shed` | **the Boat-Shed** | Strand | First hearth. Set into the floor of the boat-shed, a ring of soapstone under an upturned keel. |
| `hs_salt_house` | **the Salt House** | Saltfell yard | Beside the salt pans' firebox. Nearest hearth to the Holdfast. |
| `hs_long_hearth` | **the Long Hearth** | the Longhouse | Cold and inert until the Netmender is released; then it becomes a Hearthstone. |

Title cards (shown on first entry, in the UI serif, small caps, no subtitle):

- **THE STRAND**
- **SALTFELL**
- **THE LONGHOUSE**
- On release: **THE NETMENDER — RELEASED** (replaces any "victory" banner; quiet, bone-white, held 3 s)

---

## 2. The Strand (`saltfell_strand`)

**Layout.** A crescent of shingle about 120 m long under a 30 m cliff. The player's borrowed boat grounds at the south end. North along the beach: three boat-sheds, the salt pans' lower drying frames, a line of net racks, the cliff path switchbacking up at the north end. A tidal rock shelf below the sheds hides a side route.

### THAW (first arrival is always THAW)

- Low amber sun over the water, almost on the horizon. Gulls. Smoke from the yard above.
- Boats are drawn up on rollers. One, Brede's (`lm_brede_boat` landmark), is nearer the water than the rest, oars laid ready across the thwarts. **Brede** stands in it, checking the thole pins.
- Nets are spread over the racks to dry. One has a fresh tear, the size of a man.
- Two children's voices further up the beach, never seen, being told to get off the racks.
- No enemies.

### RIME (after the first rest at the Boat-Shed)

- The tide froze mid-surge. A glass wall, three metres high, runs the length of the beach where the waterline was. Inside it, close to the surface: kelp, a gull, an oar.
- Brede's boat is gone. Where it stood, rollers and a long drag-mark frozen into the shingle *up* the beach, toward the path. (It was dragged home.)
- The nets on the racks are rigid. The torn one has been mended, roughly, with ice.
- Enemies: 4 Rimewalkers along the racks (two of them are sitting on upturned buckets, mending nothing), 1 Oarsman at the waterline facing the sea, 2 more Oarsmen inside the second boat-shed, seated in a row as though in a boat.
- Pickup: **Brede's net-float**, frozen into the face of the glass wall at chest height. Chipping it free takes a heavy attack.
- The tide-shelf side route leads under the cliff to a frozen rock pool and a **bog-iron** lump.

---

## 3. Saltfell yard (`saltfell_steading`)

**Layout.** A cliff shelf roughly 80 × 60 m. Dry-stone walls divide it into: the yard proper (well, fish racks, a byre), the salt house and pans along the cliff edge, the net-loft (two storeys, ladder down to the Strand), the cliff graves on a turf terrace to the east, and the Longhouse closing the north side.

### THAW

- Fish racks hung with split cod. A cat. Washing on a line.
- **Ingra** in the yard, outside the store-house with a tally-stick, counting sacks and getting a different number.
- From the byre, a cough. Then louder talking from inside the salt house.
- The net-loft: Gunna's mending stool by the window, still warm (the seat is drawn with a warmer albedo tint). Her needle on the sill. A net over the beam with a hole in it, half-mended. She is never seen in THAW. If the player waits in the loft, Ingra calls up from the yard: *"Gunna? Your supper's going on the table, I'm not keeping it."*
- Cliff graves: old, grassed over. One fresh one, small, with a bunch of thrift on it. No marker. (Wren's. It is empty in RIME.)
- Longhouse door open, light and voices inside, but the threshold is a THAW-only invisible stop: Ingra won't let you in until you've eaten (see her lines). After her first conversation, it opens. Inside in THAW: the long table laid, the long hearth burning, nobody home yet.

### RIME

- Everything white. The washing froze on the line.
- The cat is on the wall, frozen mid-step. It is not an enemy.
- Enemies: 3 Rimewalkers in the yard (one stands in the store-house doorway, counting on its fingers, slowly), 1 Hearthhound lying across the Longhouse threshold, 1 Hearthhound in the byre, 2 Oarsmen at the cliff edge, 1 Rimewalker sitting by the small grave.
- The small grave is open and empty. There is nothing to pick up.
- The net-loft ladder can be kicked down to the Strand (shortcut `gate_netloft`).
- The Hearthhound in the byre is lying on a rye sack (Ingra's missing sack, `item_rye_sack`).
- The Longhouse door is iced shut. A **frost veil** stands in front of it (`lm_frost_veil_net`: a curtain of frozen net mesh). The veil opens only in RIME.

---

## 4. The Longhouse (`saltfell_longhouse`)

**Layout.** One long room, 32 × 10 m, roof on two rows of carved posts. Door at the south end. The long hearth runs down the middle, 12 m of soapstone kerb. Benches both sides. Sleeping alcoves behind the posts. At the north end, the high end, the household's mask-pegs on the end wall.

### THAW (accessible after Ingra's first conversation; and freely after release)

- The table laid for eleven. Bread, a crock of butter, a pot of fish stew on the hearth. At the far end, one bowl, one spoon, placed carefully; it has a folded cloth on it to keep the dust off.
- Mask-pegs: adult masks in a row, woad-blue bands. Two small pegs at the end. One has a child's mask (`ks_child_mask`). One is empty.
- Nobody is in the room until the player has spoken to Ingra twice; then Ingra comes in to put more peat on.

### RIME (boss arena)

- The long hearth is a trench of grey ash and ice. The table has been dragged to the walls. The floor is a net: the whole floor, wall to wall, frozen mesh with the boards visible underneath.
- The pot is on the hearth. The bowl at the far end is full, frozen over, the spoon standing in it.
- The Netmender is at the high end with her back to the door, sitting on the floor. She is mending.

---

## 5. Enemies

All frost-taken have the Δ frost-breath facing tell from `SPEC.md` §7: a plume of breath from the mask shows where they are facing a beat before they turn.

### Rimewalker (`rimewalker`)

A villager frozen where they stood. Undyed wool, rimed mask, ice grown over both hands into blunt clubs. Slow, sad, dangerous in groups.

| Move | Telegraph | Notes |
|---|---|---|
| **Swing** | Shoulder dips, right ice-hand drawn back past the hip (0.6 s) | Single horizontal swing. Rollable, parryable. |
| **Double fall** | Both arms rise overhead, frost-breath puffs twice (0.9 s) | Two-handed downward smash. Heavy poise damage. Not parryable. |
| **Lean** | Body tilts forward, feet stay planted (0.4 s) | A short push with the shoulder. Interrupts healing. |
| **Idle behaviour** | | Some sit and repeat a chore (mending, counting). They rise slowly when the player enters perception. |

### Oarsman (`oarsman`)

A rower frozen mid-stroke. Broad back, hood, an ice oar grown from both hands as one piece. Longer reach, slow recovery.

| Move | Telegraph | Notes |
|---|---|---|
| **Stroke** | Oar drawn back to the left side, torso coils (0.8 s) | Wide right-to-left sweep, 3 m reach. Roll through toward him. |
| **Back-stroke** | Pauses at end of Stroke, feet shuffle (0.5 s) | Follow-up left-to-right. Only after Stroke. |
| **Ship oars** | Oar raised vertical, held, frost-breath rises straight up (1.2 s) | Downward slam with the blade end, short ice shockwave line 4 m forward. |
| **Recovery** | | 1.4 s open window after Ship oars while he drags the oar back up. Riposte opportunity. |

### Hearthhound (`hearthhound`)

A household dog that froze waiting at a door. Thick coat matted with frost, rimed muzzle, icicles on its belly fur. No mask (dogs don't). It guards a threshold and will not leave it.

| Move | Telegraph | Notes |
|---|---|---|
| **Lunge bite** | Crouches, ears flatten, frost-breath snort (0.5 s) | Fast forward lunge, 2.5 m. |
| **Shake** | Grabs on a hit; camera nudge | If the Lunge bite connects from behind, it holds and shakes (a grab; mash to break). |
| **Guard bark** | Sits up, chest swells (0.7 s) | A bark that alerts all frost-taken in 15 m. No damage. |
| **Leash** | | Will not chase more than 8 m from its threshold. Returns and lies down again. |

---

## 6. The Holdfast: the Netmender (`netmender`)

**Gunna of Saltfell.** 3.2 m hunched. Grey and oat wool, a woad-blue mask-band, her mourning mask rimed white. A fishing net, frozen, wrapped round her shoulders and trailing to the floor in a train; bound into it against her back, Brede, drowned and frozen, his own mask turned to look over her left shoulder. Her hands are free; her fingers have grown long needle-points of ice.

**Arena:** the Longhouse floor, a net. Kerb of the long hearth splits the room lengthwise and is waist-high cover. Frost veil at the south door.

**Intro (no dialogue).** The player enters. She keeps mending. The player can walk right up to her. When the player is within 4 m or attacks, she stops, ties off the knot, cuts it with her teeth (a sound, not seen under the mask), and stands. The health bar appears: **THE NETMENDER**.

### Phase 1: the mending (100–60%)

She fights to keep the Bearer away from her back.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Needle stitch** | Right hand draws back to the ear, fingers together (0.6 s) | Three quick stabs, the third a beat late. Parryable. |
| **Cast** | Turns half away, gathers the net train into her left arm, frost-breath held (1.1 s) | Throws the net in a fan, 8 m. On hit: the Bearer is snared (rooted 1.5 s; mash to break) and she hauls them in to Needle stitch range. Roll sideways. |
| **Turn away** | Player is behind her for > 1.5 s; she hunches, Brede's mask swings into view | She spins with the net train low, a 360° sweep that knocks down. Teaches that her back is what she protects. |
| **Knot** | Kneels, both hands to the floor, the floor-net glows faint blue along a line toward the player (1.4 s) | A line of ice-knots erupts along the floor-net. Leaves a frozen ridge for 10 s that blocks movement. She uses it to cut the room in half. |

### Phase 2: the hauling (60–25%)

Transition: she grabs the floor-net with both hands and pulls. The whole floor slides 2 m toward her; the table and benches at the walls slam over. From now on she uses the floor itself.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Haul** | Leans back, both arms crossed over her chest, a creak of rope through the room (1.0 s) | The floor-net drags everything toward her 3 m. Combine with a Needle stitch. Sprint away to hold position. |
| **Sea-weight** | Rises to full height, net train lifted over her head like a sail, Brede's figure visible (1.6 s) | She brings the whole net down in front of her: a long rectangle, 10 × 4 m, heavy damage. The tell is unmistakable; the window to punish after is long (2 s). |
| **Mend the floor** | Kneels at a Knot ridge she made earlier (0.8 s) | Re-freezes all existing Knot ridges, extending their lifetime. If the room is too cut up, the player must break ridges (2 heavy hits). |
| Phase 1 attacks | as above | Needle stitch gains a fourth stab. |

### Phase 3: the hole (25–0%)

Transition: she stops. She puts her hand through the net at her back, through the hole Brede came home through, and holds his hand. From now on she fights one-handed (left hand stays behind her) and slower, and will not turn her back at all.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **One-hand stitch** | Right hand to the ear (0.7 s) | Two stabs. |
| **Last cast** | Same as Cast but she does not turn away; the net comes from over her shoulder (1.3 s) | Wider fan, 10 m. |
| **Hold** | Crouches over, curls around Brede (2.0 s) | No attack. Frost-breath slows. She is open; this is the moment. If the player does nothing for 6 s, she stands and resumes. |

**Release.** At 0 she sits back down. The net slides off her shoulders and Brede settles by the hearth trench. The frost veil falls as meltwater. Title card. The long hearth catches from the Bearer's horn by itself (the Hearthstone activation). The **mending needle** lies where she sat.

**Music cue notes:** no melody in phase 1, only the room tone and rope creak. A low drone enters at phase 2. Phase 3 drops everything except a single sustained low note that stops on release.

---

## 7. NPCs

NPCs exist only in THAW. Format follows `data/npcs.json`: `lines_first`, `lines_repeat`, then `services`. Flags with `ks_` are Keepsakes journal flags; the journal shows the line in quotes after each.

### Ingra, Steward of Saltfell (`steward_ingra`)

Sixties, broad, a lichen-yellow mask-band because she married in from Tarnhall forty years ago and never let anyone forget it. Counts everything. Mothers everyone. She half-recognises the Bearer's walk and keeps not quite saying so.

**lines_first**

1. "You'll be off a boat. You've got the walk. Sit down before you fall down."
2. "I'm Ingra. I keep the stores and the hearth and most of the people in this house, whether they like it or not."
3. "There's stew. You're not having any till you've washed, mind. Well's in the yard."
4. "We're short a sack of rye. I've counted it four times. Somebody's dog has had it, and I know whose dog."
5. "If you see it, you bring it back. I'll not have folk saying Saltfell can't feed a guest."

**lines_repeat** (default)

- "Three nights you're household. After that you're either kin or gone, and you don't look like gone."
- "Gunna's up in the loft. Don't go up. She bites."
- "That end of the table's Brede's. He's particular about his end."

**lines_repeat** (after `ks_ingra_rye` is set)

- "Found it in the byre, did you. Under that dog. Well. He's a good dog."
- "You've got a look of someone. Don't mind me. Everyone's got a look of someone."

**lines_repeat** (after `ks_netmender_released`)

- "Eleven. Twelve. Eleven." *(she is counting the bowls on the table)*
- "Sit down. You've been on your feet all day."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `buy_mend` | buy song `mend` | 200 warmth | Learn the Mending Song | "Hum it over the cut, not at it. And don't look so pleased with yourself, everyone knows it." |
| `deep_gourd` | gourd_up, once | 300 warmth | Trade for a Deep Gourd | "That was my mother's. It leaks if you hold it wrong. Don't hold it wrong." |
| `rest_level` | level_up | — | Sit by the fire | *(opens the levelling screen; Ingra says nothing)* |

**Keepsakes: "Ingra's rye"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_ingra_met` | First conversation | "Ingra is a sack of rye short and blames a dog." |
| 2 | `ks_ingra_rye_found` | Pick up `item_rye_sack` from under the byre Hearthhound (RIME) | "The rye was in the byre, under the dog. It had been his bed." |
| 3 | `ks_ingra_rye` | Talk to Ingra in THAW carrying the sack | "Ingra said he was a good dog." |
| 4 | `ks_ingra_count` | Talk to Ingra after `ks_netmender_released` | "Ingra is counting bowls." |

Reward at step 3: 1 **bog-iron**, and Ingra's next service list adds `deep_gourd` at 150 warmth instead of 300.

### Brede (`brede`)

Forties, lean, a fisherman's hands and a woad-blue mask-band tied badly, because Gunna usually ties it. Cheerful, a bit of a talker, not as brave as he is pretending to be about the morning. Found on the Strand, in his boat.

**lines_first**

1. "Mind the oars. No, the other way. Thank you."
2. "Brede. I'd shake your hand but I've had it in fish guts all afternoon."
3. "Off to Kettle Fjord at first light. They've a healer there, a good one. There's a few coughing up at the house. Nothing much. Children, mostly."
4. "Gunna says I'm not to go. Gunna says a lot of things. She's mending the big net, so she's not speaking to anyone anyway."
5. "Lost my float off the herring net this morning. Cork, my knot burned on it. If the tide brings it in, I'd thank you for it. She'll notice it's gone and I'll never hear the end of it."

**lines_repeat** (default)

- "Tide's right at first light. I'll be back before she's finished being cross."
- "Ever been to Kettle Fjord? They boil the fish in kettles the size of this boat. You can smell it a day out."
- "Don't tell Gunna I said she was cross."

**lines_repeat** (after `ks_brede_float`)

- "That's it. That's my knot. The one on the back's wrong, I did it the year we married. She says it makes it lucky."
- "You've done me a kindness. If you're ever in a boat, take the oilskins. I've another set."

**lines_repeat** (after `ks_netmender_released`; Brede is now found sitting on the boat's gunwale, mending a net, badly)

- "She does this faster. I don't know how she does it."
- "Pass us that. No. Yes. Thank you."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `give_oilskins` | gift, once, requires `ks_brede_float` | free | Take Brede's spare oilskins | "They've been in salt water more than I have. Keep 'em that way round." |
| `buy_bog_iron` | buy `bog_iron` ×1, repeatable ×3 | 120 warmth | Buy a lump of bog-iron | "Raked it up for sinkers. You'll do better with it." |

**Keepsakes: "Brede's float"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_brede_met` | First conversation | "Brede lost a cork float off the herring net." |
| 2 | `ks_brede_float_found` | Chip `item_net_float` out of the frozen tide wall (RIME) | "The float was in the ice, where the tide stopped." |
| 3 | `ks_brede_float` | Give the float to Brede in THAW | "Brede says the wrong knot on the back makes it lucky." |
| 4 | `ks_brede_mending` | Talk to Brede after `ks_netmender_released` | "Brede is mending the net himself." |

---

## 8. Items and keepsakes

Voice per `WRITING.md`: a plain fact, then one human detail. No morals.

**Hewing Blade** (`hewing_blade`, starting weapon)
> A long blade of bog-iron, ground for clearing gorse off the fold walls. The Bearer's foster-father lent it for the voyage and said to bring it back. The grip is wrapped in his old belt.

**Saltfell Board Shield** (`saltfell_shield`)
> A round shield of pine boards with a bog-iron boss, painted woad blue long ago. It hung over the boat-shed door and was used mostly to keep the rain off the door.

**Fostering Horn** (`fostering_horn`, key item, not droppable)
> A cow's horn with a soapstone stopper and a draught-hole, worn at the hip. Children of Saltfell carry a coal from the home hearth in one when they are sent down the water. The coal inside has been fed every evening since you were small.

**Gourd** (`gourd`)
> A stoppered gourd of hot broth. Rest at a Hearthstone and it is full again. Somebody has cut a small notch in the neck for every time it has been refilled, and then given up.

**Brede's Net-Float** (`item_net_float`)
> A cork float off a herring net, with Brede's knot burned on one side. He burned a second knot on the other side the year they married, got it wrong, and never burned a third.

**Child's Mask** (`ks_child_mask`)
> A small mourning mask of birch with a woad-blue band, hung on the low peg by the Longhouse door. Children are given one to grow into. The band has been retied to fit a smaller head.

**Knucklebones** (`ks_knucklebones`, 4 of 5)
> Four sheep's knucklebones, the fifth missing, worn smooth in a small pocket. The game is to throw one up and snatch the rest before it lands. One of them has a tooth-mark.

**Rye Sack** (`item_rye_sack`)
> A sack of rye from the Saltfell store-house, chewed at one corner. It was under the byre dog, flattened into the shape of a dog. Ingra will want it back.

**Saltfell Oilskins** (`armour_saltfell_oilskins`, body)
> Brede's spare oilskin smock, dressed with fish oil and smelling of it. It turns sea-spray and some of the cold. The left cuff has been let down and re-hemmed by someone who did it properly.

**Mending Needle** (`item_mending_needle`, Holdfast release drop)
> A net-needle of whalebone, loaded with tarred twine, from the Netmender's lap. The last net it worked has one hole mended fourteen times over. Each knot is a little looser than the one before it.

---

## 9. Song: the Mending Song (`mend`)

- **Breath:** 35. **Type:** heal. **Scales with:** Kinship.
- **Use:** a 1.2 s hum, interruptible; restores 35% Heart plus Kinship scaling.
- **Taught by:** Ingra (`buy_mend`).

> A low hum sung over cuts and chilblains, mostly to children, until they stop crying out of embarrassment. Every household on the coast sings it slightly differently. Ingra sings it flat and says that is how it goes.

---

## 10. Starting loadout

- Right hand: Hewing Blade. Left hand: Saltfell Board Shield (found in the boat-shed on the Strand, 20 m from the landing; the Bearer starts with empty left hand).
- Body: Traveller's coat (`armour_traveller_coat`): *"A long coat of grey southern wool, wrong for the north, warm enough on a boat. The toggles are horn. One is a replacement and does not match."*
- Belt: Gourd ×3, Fostering Horn (fixed).
- 0 warmth, Heart 10, Wind 10, Might 10, Craft 9, Kinship 11, Lungs 9.
