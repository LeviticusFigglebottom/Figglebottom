# Rimeholt writing guide

*Owner: narrative. Applies to every line, item description, title card and design doc that becomes player-facing text.*

## The method

The story is told through things, not explanations. Item descriptions, room layouts, where an enemy stands, half a sentence from someone in THAW. The player puts it together. `WORLD.md` states the truth plainly for the team; the game never does.

- **Concrete and domestic.** What was on the table. Whose boots are by the door. The half-mended net. A name cut under a bench.
- **Grief as behaviour.** Keeping a place set. Telling a story wrong the same way every time. Refusing to finish a task. Cutting the hole open again.
- **People are people.** Funny, petty, stubborn, proud, loving, wrong. They argue about gates and goats. They talk about tomorrow's chores.
- **Plain speech with texture.** Short sentences, regional words (steading, byre, sheiling, fold, strand), no archaic "thee", no speeches.
- **Leave things out.** If a line explains what the previous line meant, cut it. If a room already shows it, no one says it.
- **Holdfasts are understandable.** Each refusal should make the player think they might have done the same. No villain of the week.
- **The Bearer's own grief arrives late and in pieces.** Never summarised, never named by anyone.
- **Endings don't explain themselves.**

## Item descriptions

2 to 4 sentences. First a plain fact about the thing. Then one human detail. Never a moral, never a closing aphorism.

## Quest log voice

The Journal (`data/keepsakes.json`) is the one place the game says plainly what to do. Clarity comes first there. The oblique voice above is for item descriptions, plaques and people, and stays out of the log.

- **An objective says what to do and where.** Name the thing, the person and the place, and say THAW or RIME when it matters. "Find Ingra's missing sack of rye. She thinks a dog took it. Look in the byre, west of the Longhouse in Saltfell yard, in RIME."
- **A done step is a short plain statement of what happened.** "Found the rye sack in the byre, under a frozen dog." Past tense, no subject ("Met…", "Took…", "Gave…").
- **Use the game's own words** as the UI spells them: THAW, RIME, Hearthstone, Holdfast, frost veil, Gourd, bog-iron, warmth. Places by their title-card names.
- **Say what blocks a step.** If something cannot be done until a Holdfast is released, or until the region is back in THAW, the objective says so.
- **Only tell the player what the Bearer has been told or has seen.** If nobody said where a thing is, the objective names the region and how to look, and gives no place (`at`). Do not solve it for them.
- **Facts, not meanings.** The log may say the last knot was tied by someone else. It never says what that adds up to, never names the Bearer's kin, and never explains a Holdfast.
- **No riddles, no poetry, no sentiment, no folksy turns.** No "the hearth remembers". If a line could go on a greeting card, cut it.
- **Rewards and openings are stated.** "She paid one bog-iron and now sells the Deep Gourd at half price."

Before and after:

> *Before:* Ingra said he was a good dog.

> *After:* Gave Ingra the rye. She paid one bog-iron and now sells the Deep Gourd at half price.

The region docs' "Journal line" tables hold the earlier oblique lines; the data file is the source for journal text now (ADR 0014).

## Banned tics

- "It was X, until it wasn't." / "not X, but Y" reversals / "And yet." / "Perhaps…" closers
- Portentous vagueness; capitalised Abstractions (the Silence, the Forgetting); riddles that mean nothing
- Triplets of adjectives
- *whispers, echoes, tapestry, testament, a stark reminder, lingers, haunting, remnants of a bygone*
- Every line ending on an aphorism; characters speaking like greeting cards
- Grief as generic sadness ("she was never the same")
- Tidy morals

Also obey `docs/transposition/ORIGINALITY.md`: no bells, candles, wax, bees, choirs, runes or letters.

## Before and after

**1. Item: a net-float**

> *Before:* A glass float that once held a fisherman's hopes. It whispers of the sea that took him, a haunting testament to love that would not let go.

> *After:* A cork float off a herring net, burned with Brede's knot on one side. He carved a second knot on the other side the year they married, and got it wrong, and never carved a third.

**2. NPC line: Ingra in THAW**

> *Before:* "Ah, traveller. The fire burns bright tonight, but every flame must one day go out. Remember that."

> *After:* "You'll want feeding. Sit there, not there, that's Brede's end and he's particular. He's out at first light, so he says. He said that last year."

**3. Area title card / room**

> *Before:* THE LONGHOUSE: Where Memory Sleeps

> *After:* THE LONGHOUSE. (The room does the rest: a bowl set at the end of the table, frozen full.)

**4. Holdfast release**

> *Before:* As the Netmender falls, she whispers, "I couldn't let him go. But now I understand that love means letting go." Peace returns to Saltfell.

> *After:* No line. The net slides off her shoulders. Brede comes to rest by the long hearth. On the floor is her mending needle; its description says the last net it was used on has the same hole mended fourteen times, each knot a little looser than the one before.

## Checklist before committing text

1. Does any line explain something the player could see?
2. Is there one specific object, name or chore in it?
3. Would a real person say this to someone they know?
4. Search the text for the banned tics above and for `tools/banned_terms.txt`.
