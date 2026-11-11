# The opening

*Owner: narrative. Voice rules in `WRITING.md`. Every fact here is from `SPEC.md` §2, `WORLD.md` §1–2 or ADR 0013; nothing in `WORLD.md` §3–4 (who stopped the singing, who the Bearer is to them) is said. Data: `data/game.json` `intro`. Code: `src/core/intro_director.gd`.*

Played once, on a new journey, after the winter is chosen and before the Strand. About 85 seconds. It can be let go at any card by holding E (or Enter, Esc, the pad's accept); any key shows *Hold E to skip* in the corner for a few seconds. A loaded journey never plays it (World flag `intro_seen`, carried by the save). A new journey on any hearth does.

It is filmed in Saltfell as the player is about to find it, with a camera of its own. Nothing it shows is kept: the frost wave and the melt it runs are not saved, the hearth it kneels at is not lit, and it ends with Saltfell in THAW and the Bearer standing on the Strand, exactly as a journey began before there was an opening. The HUD is away throughout. The place card (SALTFELL, then THE STRAND) comes after it.

Music is the world's own: Saltfell's THAW theme under the first cards; it dies as the frost wave crosses the hall and the RIME theme comes up; the coal on the stone brings the THAW theme back.

## The cards

Nine, lower third, the body serif in bone on coal. No speaker. Second person from card 6, as `SPEC.md` §2 has it.

| # | id | Where the camera is | Card |
|---|---|---|---|
| 1 | `hearth_law` | The Longhouse in THAW, from inside the door, down the hall past the long tables and the hearth trench. | In Rimeholt a hearth is not let out while one of its household lives. When the last one dies, the neighbours let it go on purpose, with a song. |
| 2 | `outsong` | The same room, closer along the long table. | The song is the Outsong. It is sung the night after a burial, in masks, so the dead cannot find the face they loved best, and go. |
| 3 | `sickness` | The same room, held still. The frost wave comes down the hall from its high end. | One midsummer a coughing sickness came up the fjords. House by house, nobody could bear to start the song. They kept their dead by the fire one more night, then one more. |
| 4 | `frost` | The same room in RIME: the tables shoved to the wall, rime on the floor. | The warmth of the world went into keeping them. The frost came in the middle of summer and has not left. |
| 5 | `holdfasts` | Up the hall in RIME toward the high end, where the Netmender sits mending with her back to the door. | Those who would not let go are the Holdfasts. They have grown into what they kept hold of. To release one is to sing the song they could not, for their dead. |
| 6 | `bearer` | The Salt House hearth in RIME. The Bearer kneels at the cold stone. | You were sent down the coast as a child, before the sickness, with a coal from the hearth in a horn. You kept it fed. It is the last live coal in Rimeholt. |
| 7 | `hearthstone` | The same hearth. The coal takes; the melt goes out from the stone across the yard as the camera rises. | Set the coal on a cold hearthstone and the stone remembers its last warm evening, and whoever sat at it. Leave the stone cold and the place is as the frost left it. |
| 8 | `coldwell` | From above the shelf in THAW, looking up the water, inland. | Every river in Rimeholt starts at one spring under the ice, the Coldwell. The one who stopped the singing first is up there. |
| 9 | `choice` | The Strand. The Bearer stands where the journey begins, looking up at the cliff. | When you reach it you can sing, and the spring comes, and the remembered evening is gone for good. Or you can keep the coal, and the evening, and the winter. |

## What each card is for

- **1–2:** what a hearth is and what the Outsong is (`WORLD.md` §2, hearth law 1; the Outsong).
- **3–4:** what happened, and the two times of the one place: the room is shown warm, then the wave, then the same room frozen (`SPEC.md` §2).
- **5:** what a Holdfast is and what *releasing* one means. The Netmender is the first the player will meet; she is not named.
- **6–7:** who the Bearer is, what they carry, and what a Hearthstone does with it.
- **8–9:** the road, and where it ends: the two endings, as a choice the player will be given (`SPEC.md` §2, ADR 0013). The last Holdfast is "the one who stopped the singing first", which is how `SPEC.md` puts it; nobody is named.

## Checked against WRITING.md

No aphorism closes a card. No reversals, no capitalised abstractions beyond the lexicon's own nouns (Outsong, Holdfasts, Coldwell). Nothing explains what the previous card meant. Card 9 lists three things the Bearer keeps (the coal, the evening, the winter); they are three different things, not three adjectives for one.
