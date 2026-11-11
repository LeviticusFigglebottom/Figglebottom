# ADR 0014: a quest log that says what to do, and a map

- **Status:** accepted
- **Date:** 2026-11-11
- **Changes:** SPEC §1 pillar 4 as it applied to the Keepsakes leaf ("no markers, no objectives")
- **Owner feedback (Windows build playtest):** "Add a proper map and quest log with non-cryptic or corny writing (the current one is both)."

## Context

The Keepsakes leaf showed one oblique line per finished step ("Ingra said he was a good dog.") and nothing about what to do next. That was the design: the story is told through things, and the log was written in the item-description voice. In play it read as cryptic, and the player had no way to find a half-remembered errand again. There was no map at all.

## Options

1. **Keep the oblique log, add hints to dialogue.** No UI change. Does not answer the feedback: the log is still unreadable as a log.
2. **A plain quest log and a map, with the story still left to things.** The log states tasks and places in plain words; item texts, plaques and rooms keep the oblique voice. The map is drawn from the real terrain and only shows what has been walked.
3. **Waypoints in the world (compass, floating markers).** Clearest, and it turns exploration into following an arrow.

## Decision

Option 2.

- **The Journal** replaces the Keepsakes leaf (J). `data/keepsakes.json` keeps its threads and flags; every step gains an `objective` (what to do and where, plain) beside its `line` (what was done, plain). A `main` thread, **The Outsong**, carries the journey: one step a region and the choice at the Wellhead. Optional steps (`optional`, with `needs_item`) never block a thread. Finished threads fold under **Done**. A thread or step is data only. `Keepsakes.journal()` still returns the done lines, so the suites that read it are unchanged apart from the text.
- **Voice.** `docs/lore/WRITING.md`, "Quest log voice". Clarity first. The log says what is needed to act and never what a thing means: it will say the float is in the frozen tide, and never why Gunna mends. The oblique voice stays for item descriptions, plaques and people.
- **The pin and the tracker.** One thread is pinned (the Outsong by default). Its objective's first sentence shows top-right on the HUD and can be switched off in the Journal. `World.journal = {pin, tracker}`.
- **The Map** is a new leaf (M). `tools/ui/build_map.py` bakes a dim base of the whole highland and one parchment sheet per region from `data/terrain/*.bin` and the area JSON: height wash, contours, hachured cliffs, water, paths, shingle, woods, hedges, buildings. Nothing on it is invented. Markers are drawn at runtime from the save (`MapState.markers()`): Hearthstones come upon / rested at / last rested, the frost veil once seen and whether its Holdfast is released, the ways on, found places, the pinned objective where the Bearer has been told the place, and the Bearer with facing. A region not walked stays dark.
- **No markers in the world.** Nothing floats over the ground and there is no compass. The map marks an objective only when a step's data gives a place (`at`), and a step is only given one when somebody told the Bearer where to look.
- **Saves.** `save_version` 4 adds `journal` and `map`. A v3 save's map is rebuilt from what it holds: areas with any state, Hearthstones with a `lit_` flag, cleared areas' veils.

## Consequences

- The region docs' §7 "Journal line" columns are the old oblique lines. `data/keepsakes.json` is now the source for journal text; the tables stay as the record of what each step means.
- POI threads and steps (`docs/lore/POI.md`) are already written into `data/keepsakes.json`, marked `poi`. They are silent until something sets their flags. A wayside board added to an area becomes a findable place on the map with no further work (it is named by its first line).
- `tools/ui/build_map.py` must be re-run when a terrain or area generator changes the land. It takes under a minute.
- Icons: the flat silhouettes are replaced by one painted set (`tools/ui/icon_sheets.json`, `tools/ui/build_icons.py`). An item finds its icon by id (`UIIcons`), so a new item needs a tile and no code.
