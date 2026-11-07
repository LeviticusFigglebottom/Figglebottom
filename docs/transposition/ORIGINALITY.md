# Originality guardrails

Rimeholt shares its **engine, feel, timing, camera, UI conventions and visual mood** with the owner's earlier game, the source in `LeviticusFigglebottom/Regothiga`. It shares **nothing else**. This file lists what must never appear.

`tools/banned_terms.txt` is the machine-checked list. CI runs `tools/check_originality.sh` on every push and fails on any hit. This file is the human-readable superset: it also covers *ideas* that a grep cannot catch.

## 1. Never reuse: the source's proper nouns

The full lists are in `tools/banned_terms.txt`. They cover:

- **The source title.** "Vespergard".
- **Its lore terms.** The orisons currency, the Remembrance drop, chrism, candleglass, the Wick, the Thirteenth Hour and Bell, the Amend, the Offices of the Hour, the Sun-Creed, the Waxbound, and so on.
- **All 15 areas and their sub-places.**
- **Every NPC.**
- **Every faction.**
- **Every enemy and boss.**
- **Every item, weapon and spell.**

## 2. Never reuse as proper nouns or system names

These are ordinary words, so they stay legal in prose. They are banned as names or as the source's specific concepts, and reviewers enforce this by hand:

- **The source's two-state names.** *Glory* and *ruin* as state names (ours are THAW and RIME), and *kindle* and *gutter* as the toggle verbs (ours are *warm* and *still*).
- **Vigil and lantern** as the rest-site concept (ours is the Hearthstone).
- **Liturgical framing.** Words like *Prime, Matins, Sext, Vespers, Zenith, Nadir, Dawn, Dusk, Noon* used as named concepts. Rimeholt has no liturgical-hours framing at all.
- **The source's UI names.** *Satchel* and *girdle* (ours are Pack and Belt), and *FORGOTTEN* as the death text (ours is STILLED).
- **Its fiction of choirs, chapters and offices.** *Penitent, Ward, Precentor, Chorister, Sexton, Prior* as enemy or NPC titles.

## 3. Never reuse: story beats and motifs

These are the source's identity beats. Rimeholt must not echo them:

- **A fallen holy kingdom, remembered in gold.** Ours is a frozen steading-culture, remembered on one midsummer evening.
- **Bells, candles, wax, chandlers, bees and honeycomb as the central symbols.** Ours are breath, frost, hearth-coals, wool, timber and song.
- **Ringing a final bell to end the world, or turning the world white as an ending.**
- **A pilgrim-latecomer protagonist arriving after the fall.**
- **Defeated bosses returning "radiant" to give penance tasks.**
- **A mirror-knight final boss who adopts black armour and a gold blade after a self-sacrifice reveal.**
- **Twelve trials that unlock a thirteenth thing.**
- **The source's puzzles.** Ring-in-order stations, rotating watcher statues, lights-out rings, Simon-says bells, votive stands lit only in one state.
- **Its visual signature.** Leaded stained-glass windows (Rimeholt uses carved wood and horn-pane windows instead), and the gothic cathedral and cloister architecture kit.

## 4. Never reuse: assets

None of the following may be copied in:

- any `.glb`, texture, icon, font file choice, UI art, music, ambience, voice line, or Blender kit generator output from the source
- the source's synthesized music themes; generic foley *synth code* may be reused only with new tuning

Every Rimeholt art asset is generated fresh and has a provenance row in `assets/PROVENANCE.md`.

Engine and system **code** is reused on purpose, per ADR 0001. When it is copied, every identifier, string, comment and data key carrying a source name is renamed.

## 5. Never recreate other games

Rimeholt is inspired by *genres*: the soulslike action RPG, and the open-structure narrative RPG with sparse, lore-bearing loot. It is not inspired by specific titles. The following never appear:

- names, terms, places, characters or iconic items from **Fallout**, **The Elder Scrolls**, **Dark Souls / Demon's Souls**, **Elden Ring**, **Bloodborne**, **Sekiro**, **Hollow Knight**, **Lords of the Fallen**, **Nioh** or **Zelda**
- a "bonfire" or "site of grace" rest point, "souls", "runes" or "blood echoes" as currency, an "estus"-style name, or a "hollowing" mechanic

Our equivalents are named in our own vocabulary (Hearthstone, warmth, Gourd, Breathmark), and their fiction has to *mean* something in Rimeholt's world, not just rename the original.

Norse and Scandinavian real-world cultural vocabulary (steading, longhouse, fjord, hall, seax) is fine as **generic language**. Specific mythology names (gods, Yggdrasil, Valhalla, Ragnarök) are not used. Rimeholt is its own culture, not a Norse reskin.

## 6. Process

- **Before inventing a name:** search it with `grep -i` here and against `banned_terms.txt`. If it sounds like a famous game term, pick another.
- **New names:** add each one to `docs/lore/LEXICON.md` (owner: lead) so the world stays consistent.
- **When the checker flags a false positive in ordinary prose:** reword the prose. Do not weaken the list.
