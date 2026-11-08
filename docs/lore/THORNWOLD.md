# Region: Thornwold

*Owner: narrative. Tier 2 per `SPEC.md` §8. Truth and backstory are in `WORLD.md` §5.5; voice rules in `WRITING.md`; the model for this file is `SLICE.md` (and `LOWE.md`, `KETTLE.md`, `TARNHALL.md`). Ids are the data keys in `data/`.*

Old birch and pine, coppice, charcoal clearings, laid hedges along the drove-roads. The player comes down from the Tarnhall basin through a notch onto the drove-road, follows it east between the hedges past the Collier's Clearing, and ends inside three rings of hedge round a grave under the oldest pine. Thirty minutes, one Holdfast, two people.

**What the region must let the player infer, without anyone saying it:** a hedge-layer and a collier were going to marry and could not agree where a gate should go; she died at the clearing; he hedged her grave in so nobody could come and sing her out, and never put the gate in. And somebody small walked up this road before the Bearer did.

---

## 1. Area flow

```
the Tarnhall seam ──> the Drove-Road ──> the Collier's Clearing ──> the drove-road east ──> the Outer Ring ──(the maze)──> the Hedge (the grave)
```

THAW: waist-high laid hedges either side of the road, and three rings of laid hedge round the pine with their gaps lined up on the road: walk straight in to the middle. RIME: every hedge has grown into a wall of frozen thorn twice a man's height. The road is plugged twice past the clearing, and the rings' gaps have moved round, so the way to the grave is the long way between the rings.

Hearthstones (three; the fourth wakes on release):

| id | Name | Where | Notes |
|---|---|---|---|
| `hs_drove_road` | **the Drove-Road** | where the road comes down out of the notch | First hearth. A soapstone ring in the hedge-bottom. |
| `hs_colliers_clearing` | **the Collier's Clearing** | by the clamps | Beside Linnet's water-butt. |
| `hs_outer_ring` | **the Outer Ring** | outside the outermost ring's gap | Nearest hearth to the Holdfast. |
| `hs_the_pine` | **the Pine** | at the grave | Wakes on release (`release_hearth`, `require_flag` `ks_hedgelayer_released`). |

Title cards (first entry to each zone, the UI serif in small caps, no subtitle):

- **THORNWOLD** (the plaque at the road's head reads it in full)
- **THE COLLIER'S CLEARING**
- **THE HEDGE**
- On release: **THE HEDGELAYER — RELEASED** (quiet, bone-white, held 3 s)

---

## 2. The Drove-Road

**Layout.** The road comes down through a notch in the basin wall and runs east under birch and pine, a laid hedge either side of it with field gaps. Pollen and charcoal smoke in the light.

### THAW (first arrival is always THAW)

- The low sun slanting through the trunks. Pollen thick in it.
- Smoke from the clamps further on, and two voices arguing, both enjoying it.
- No enemies.

### RIME

- The hedges are walls of frozen thorn. The road between them is a white lane.
- A Collier on the road, facing down it, its black hands held away from its sides.
- A Rime-stag in the wood south of the road, frozen mid-bound. Another stands; it moves when the Bearer does.
- Pickup: a child's **knucklebone** in the middle of the road, going east (`item_knucklebone`).

---

## 3. The Collier's Clearing

**Layout.** A round clearing on the slope. Four charcoal clamps under turf, stacks of billets, the collier's rakes and creels.

### THAW

- The clamps smoking. **Linnet** on her feet by the nearest clamp, black to the elbows. **Eyvind** with his bill over his shoulder, arguing with her about where the gate goes. Nobody can join in (see §7).
- After the release: they are not here; see §9.

### RIME

- The clamps are cold and white, their turf split.
- Two Colliers at the clamps, raking at nothing.
- Pickup: what the clamp kept (`clamp_cache`, bog-iron).
- Pickup: a **ring of plaited birch** in the ash at the foot of the eastmost clamp, where she was working (`item_birch_ring`).

---

## 4. The Hedge

**Layout.** Three rings of hedge round the grave under the oldest pine, 26, 19 and 12 m out. The innermost has a gap where a gate should be. Inside it, the gate he made and never hung, leaning on the hedge beside the gap.

### THAW

- Laid hedges, the gaps lined up on the road. The pine, and under it a low rise of turf with nothing on it yet.
- After the release, see §9.

### RIME (boss arena)

- The rings are frozen thorn, the gaps moved round: the way in is the long way. A Rime-stag between the rings.
- A frost veil across the gap of the innermost ring.
- **The Hedgelayer** works at the inside of the innermost ring with his back to the gap, laying a stem that is already laid.

---

## 5. Enemies

All frost-taken have the frost-breath facing tell (`SPEC.md` §7). Every move that covers ground shows its area on the floor for the length of the windup, in the region's cold blue (`telegraph`), so what glows is what lands.

### Collier (`collier`)

A charcoal-burner in a soot-black leather apron over oat wool, hood up, mask blackened. Both hands are frozen black ice with ember-dark cores. Slow.

| Move | Telegraph | Notes |
|---|---|---|
| **Rake** (`rake`) | Both hands drawn back low to one side (0.8 s) | A slow sweep along the ground at shin height. |
| **Smother** (`smother`) | Both black hands raised over the head, breath twice (1.2 s) | Brought down together. Heavy. Not parryable. |
| **Cinders** (signature) (`cinders`) | Crouches and scoops at the ground, the cores in its hands brighten (1.1 s); three small circles glow round the Bearer | Throws frozen coals in a spread that land on the circles. |

### Rime-stag (`rime_stag`)

A red deer stag in heavy winter coat, frozen mid-bound, thorn grown through its antlers. A quadruped (QuadRig poses over its one walk clip, like the Hearthhound).

| Move | Telegraph | Notes |
|---|---|---|
| **Gore** (`gore`) | Head down, antlers forward, a stamp (0.6 s) | A short lunge, 3 m. |
| **Bound** (signature) (`bound`) | Rears, forefeet off the ground (0.9 s); a 1.6 × 10 m strip glows | Leaps the length of the strip and comes down at the end. Whoever is under it is knocked down. |
| **Thorn shake** (`thorn_shake`) | Lowers its head and shakes it, frost spraying off the antlers (0.9 s); a 2.6 m circle glows | Thorn from the antlers rakes everything round it. |

---

## 6. The Holdfast: the Hedgelayer (`hedgelayer`)

**Eyvind Brask.** 3.6 m, lean and very tall, woven from laid thorn-stems and hazel binders. His ash mask is half grown over with briar on its left side. Thorn branches fan from his shoulders and back like a laid hedge.

**Arena:** inside the innermost ring, 12 m across to the hedge. The grave and the pine at the middle. Frost veil in the gap.

**Intro (no dialogue).** The player parts the veil. He is at the hedge with his back to the gap, laying a stem that is already laid. When the player is within 7 m or strikes him, he lets the stem go, turns, and the briar on his mask moves. The health bar appears: **THE HEDGELAYER**.

He fights the way he worked: he lays hedge. He cuts the Bearer off, closes him in, and goes through his own hedges as if they were doors.

### Phase 1: laying (100–60%)

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Bill** (`bill`) | The bill-arm drawn back across the body (0.8 s) | A long cut, 3.2 m. Parryable. |
| **Thorn lash** (`thorn_lash`) | The stems on his right arm unwind and trail on the ground (1.1 s); a 1.2 × 9 m strip glows | The lash catches and drags the Bearer in to 2 m (mash to break). Then a Bill. |
| **Raise a wall** (`raise_wall`) | Both hands driven into the ground, the stems on his back stand up (1.4 s); a 1.4 × 9 m strip glows across the floor behind the Bearer | A wall of frozen thorn 3 m high rises along the strip and stays 14 s. Whoever is in it is cut. It cuts the Bearer off from the way he came. |

### Phase 2: the rings (60–25%)

Transition (2.8 s, invulnerable; `raise_wall`): he drives both hands into the ground at the grave. A new ring of thorn rises round the pine, 8 m out, with one gap in it, and stays for the phase. Everything outside it is out of reach. From now on he goes into his hedges.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Into the hedge** (`step_into`) | Walks backward into the nearest thorn, which closes over him (0.9 s) | He is gone. 1.2 s later the stems at another place on the hedge shiver and a 3 m circle glows in front of them. He steps out there with a Bill across the circle. |
| **Raise a wall** | as phase 1, two walls | The second wall rises across the far side of the Bearer: a lane between them. |
| Bill, Thorn lash | as above | |

### Phase 3: the gap (25–0%)

Transition (2.8 s, invulnerable): the ring of phase two closes in to 6 m. He stands in its gap.

| Attack | Telegraph | Behaviour |
|---|---|---|
| **Thorn lash** | as phase 1, twice in a row | |
| **Where it goes** (`where_it_goes`) | The Bearer more than 5 m off: he turns to the gap in the ring and holds his hands up either side of it (1.6 s) | No attack. He measures the gap, steps to the other side of it, measures it again, his back to the Bearer: open. Hits do not stop him. Left alone 5 s, he turns back. |
| Bill, Into the hedge | as above | |

**Release.** At 0 he kneels at the gap in the innermost ring and puts his hands on the ground. The hedge unlays itself stem by stem: every wall he raised sinks back into the ground, the ring round the pine first, then the walls. The frost veil falls as meltwater. Title card. The gate that leaned on the hedge lies down flat across the gap: not hung, laid down, so it can be walked over from either side. At the grave is **Linnet's song-cord**; the prompt is *Take the song-cord*.

**Music cue notes:** phase 1 is the creak of stems bending and the bill. Phase 2 adds the rustle of the hedge as he moves inside it, never where it was. Phase 3 is the gap: nothing in it, the wind.

---

## 7. NPCs

THAW only. Format follows `data/npcs.json`.

### Linnet, collier (`linnet`)

Twenties, in a soot-stained leather apron over oat wool, sleeves rolled, black to both elbows, a birch mask with the hood pushed back, a plaited birch ring on her left hand. Cheerful, quick, and winning. Model: `linnet`.

**lines_first**

1. "Mind the clamp, it's breathing. If it stops breathing, come and get me, I'll be wherever he is."
2. "Linnet. That's Eyvind. He's laying a hedge round a field we haven't got yet."
3. "He wants the gate east for the sun on the latch. The sun's got nothing to do with it. He just doesn't want the west."
4. "We're to be married after the Melt. If he decides about the gate."

**lines_repeat** (default)

- "If the smoke goes blue, it's burning. If it goes white, it's cooking. If it goes black, run."
- "He'll come round. He comes round to everything if you leave him long enough with a bill in his hand."

**lines_repeat** (after `ks_birch_ring`)

- "That's mine. I had it on this morning. He made it. Don't tell him I took it off to work."

**lines_repeat** (after `ks_hedgelayer_released`)

- "He's laid it down. The gate. Across the gap, flat. I said that's not a gate. He said it is, it's just lying down."

**services**

| id | type | cost | label | line_done |
|---|---|---|---|---|
| `give_collier_leathers` | gift `armour_collier`, once | free | Take the spare leathers | "They were my brother's. He grew. Don't stand downwind of the clamps in them." |

### Eyvind (`eyvind`)

Twenties, tall and lean, hedging gloves through his belt, a hedging bill over his shoulder, an ash mask. Careful and slow and good at his work, and he knows she is right. Model: `eyvind_thaw`. He cannot be spoken to (`mute`); within earshot of the two of them, the Bearer overhears (`overhear`, before the release, at the clearing):

> **Eyvind:** "East side. Morning sun on the latch, it won't freeze shut."
> **Linnet:** "East side and the cows come out straight into the bog."
> **Eyvind:** "Cows can learn."
> **Linnet:** "Your cows can. My father's cows are cleverer than that."
> **Eyvind:** "West, then."
> **Linnet:** "West's where the wind comes from. You want the wind in your gate?"
> **Eyvind:** "There's no side you'll have."
> **Linnet:** "There is. I'm just not telling you yet."

**Keepsakes: "Linnet's song-cord"**

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_linnet_met` | First conversation with Linnet | "Linnet and Eyvind cannot agree where the gate goes. Neither of them wants to." |
| 2 | `ks_birch_ring` | Bring Linnet the ring from the clamp's ash (THAW) | "The birch ring was in the ash at the eastmost clamp. Linnet took it off to work." |
| 3 | `ks_song_cord_found` | Take `item_song_cord` from the grave (release) | "At the grave was a knotted cord. Nobody here could read it." |
| 4 | `ks_song_cord_read` | Show the cord to Lusse in Tarnhall (THAW) | "Lusse read Linnet's cord. It is an Outsong, tied by the one it was for." |

**Lusse, carrying the song-cord** (`lines_when` `ks_song_cord_read`, Tarnhall THAW):

- "This is an Outsong. Somebody's tied their own. You don't see that."
- "She starts with the clamps. Then a man with a bill. Then she doesn't know how it ends, so she's left it loose. Here."

**Keepsakes: "Knucklebones"**

One step for now; the thread runs on toward the Bearer's own story (the Coldwell).

| Step | Flag | Set when | Journal line |
|---|---|---|---|
| 1 | `ks_knucklebone_found` | Pick up `item_knucklebone` on the drove-road (RIME) | "There was a knucklebone in the middle of the drove-road, on the side going east." |

---

## 8. Items

Voice per `WRITING.md`: a plain fact, then one human detail. No morals.

**Linnet's Song-cord** (`item_song_cord`, Holdfast release drop)
> A knotted cord of plaited oat and yellow wool with a bone toggle, the knots of all sizes. It is an Outsong, tied by the one it was for, the night before she needed it. The last knot is left loose.

**Ring of Plaited Birch** (`item_birch_ring`)
> A ring of birch bark plaited round on itself, small enough for one finger. It was in the ash at the foot of the eastmost clamp, where it would have been taken off to work. Eyvind plaited it in an evening and spent a week saying it was nothing.

**Knucklebone** (`item_knucklebone`)
> A sheep's knucklebone, worn smooth. It was in the middle of the drove-road, on the side going east. There is a tooth-mark on it.

**Hedging Bill** (`hedging_bill`, weapon)
> A long-handled billhook, a hooked black iron blade with a back spike on a hazel haft, the binding rawhide. It cuts a stem two-thirds through so it bends and lives. The haft is rubbed pale in two places, a hand's width apart.

**Collier's Leathers** (`armour_collier`, body; Linnet's gift)
> A soot-black leather apron and jerkin over oat wool, scorched at the hems, for working the clamps. The leather is cracked at the elbows. It smells of smoke whatever you do to it.

---

## 9. The release beat and what he leaves

- **In the arena, at once:** he kneels at the gap; the ring and the walls he raised sink back stem by stem; the veil melts; the card; the gate lies down flat across the gap.
- **Flag:** `ks_hedgelayer_released` (`release_flag`).
- **Drop:** `item_song_cord` (`release_drop`) on the grave, which raises `ks_song_cord_found`.
- **The gate:** laid down flat across the gap of the innermost ring (`release_gate_laid`, and a landmark gated on the flag so a rebuilt wood keeps it); the gate that leaned on the hedge is gone.
- **Hearth:** `hs_the_pine` wakes at the grave (`release_hearth`).
- **After release, THAW:** Eyvind and Linnet stand at the gap of the innermost ring with the gate lying flat across it. Within earshot:
  > **Linnet:** "Well?"
  > **Eyvind:** "I've thought about it."
  > **Linnet:** "And?"
  > **Eyvind:** "I'm laying it flat. Across the gap. You come in whichever side you like."
  > **Linnet:** "That's not a gate."
  > **Eyvind:** "It's a gate lying down."
  > **Linnet:** "All right."

---

## 10. New names

Added to `LEXICON.md`: Eyvind (THAW), the Outer Ring, the Pine (hearths), Ring of Plaited Birch, Knucklebone, Hedging Bill, Collier's Leathers, Linnet's Song-cord. Checked against `tools/banned_terms.txt` and `docs/transposition/ORIGINALITY.md` §1–5: no bells, candles, wax, bees, choirs, runes or letters; nothing from another game.
