# ADR 0015: Progression gating: the way on is hinted, earned, then plain

- **Status:** accepted
- **Date:** 2026-11-11
- **Builds on:** ADR 0003 (natural, interconnected level design), ADR 0006 (seams), SPEC §5 ("release the Holdfast … the next steading opens")
- **Trigger:** owner playtest of the Windows build: *"Very obvious you can, and where to, go to the next area at first."*

## Context

### What the owner's sentence was taken to mean, twice

1. **The lead's first reading:** the way out of Saltfell is plainly open and signposted from the first minute, so progress is handed over, not earned. Fix: gate it, and take the signposts away.
2. **The owner's correction (relayed):** it is **not obvious enough** that you can cross to the next region by the side route, the cliff-top pass round the ravine head. Players see the raised drawbridge and never learn the pass is there. The owner also confirmed that the ways on must be boss-gated regardless.

### What the game showed

Both readings turned out to describe a real fault. They are two halves of one.

- **Nothing was gated, anywhere.** No seam in any generator had a lock, a gate or a blocker (`tools/seams_*.py`, every `tools/gen_*.py`). `Game.travel_to` finds an unvisited area in THAW, and THAW has no frost-taken in it. A new journey could walk from the Strand to the foot of the Wellhead Steps in THAW without drawing a blade or meeting a Holdfast. The only held doors in the game were the Longhouse veil, the boat-shed's back door and Tarnhall's hall doors, none of them on the way on.
- **Nothing showed the way on either.** Screenshots from the yard (`docs/screens/gates_before_*`):
  - The raised drawbridge is the tallest thing on the north skyline and reads at once as "the way over".
  - The pass is twenty metres of unmarked turf between the sea cliff and the ravine head. No track is painted to it. `terrain_saltfell.PATHS` held six paths and none went north of the Longhouse door.
  - The same was true further on. The Lowe painted no track to the Kettle Road. Kettle did not paint the Tarn Steps. Tarnhall painted nothing from the island to the notch. Thornwold's drove-road stopped at the outer ring, the far side of the wood from the fell path. The Reach painted nothing to the Upwater.

So the pass was open and invisible at once: handed over, and still not found.

## Options

1. **Lock the seams** (`AreaPortal.locked_flag`, which already takes `cleared:<area>`). An auto seam has no door: the Bearer would walk into a trigger box and be told "Sealed". That is the invisible wall ADR 0003 forbids.
2. **Per-state blockers and `absent_flag` pieces.** Real collision, but they are read when the area is built. A release would open nothing until the area was left and rebuilt, and a gate that is a different object in each state can be walked round by turning the memory.
3. **`FlagGate`.** Stands until a world flag turns, then sinks. No way to open it from the far side, so a journey set down beyond one (a harness spawn, a save from an older build) is shut out of the region behind it.
4. **`ShortcutGate`, opened by the release.** Already the game's "barred from the other side" door: real collision on the base layer (so the same in THAW and RIME), it splits the navmesh, it can be undone from its far side, and its state is kept in the save. Tarnhall's hall doors already open on a release through it.

## Decision

**Option 4.** Every region's way on is shut by one `ShortcutGate` until that region's Holdfast is released. The pattern for every exit is **hint, earn, reveal**.

### The rule for what stands in the gap

Each gate is the thing that region's Holdfast keeps, set across the road out. It is the same object in both memories; the frost shader does the rest. The ground either side of the opening is closed with the region's own fabric (a dyke, stacked peat, boulders, hedge), run out to where the land can no longer be walked. Nothing is an invisible wall, and nothing is a wall with no other reason to be there.

### Per region

| Region | Exit | Before | After: gate | Opens on | Why this thing |
|---|---|---|---|---|---|
| **Saltfell** | the cliff-top pass → the Lowe | 20 m of open turf, no track, open in THAW at minute one | A head-dyke across the 12 m neck between the sea cliff and the ravine head, two stones for gateposts, and a net hung across the 3.6 m gap (`pass_net`, kit `net_frame`). *Tied off on the far side.* | `ks_netmender_released` | WORLD.md 5.1: in RIME "nets stand stiff as fences"; on release "the net falls open". It is Gunna's net. |
| Saltfell | the drawbridge → the Lowe | raised; windlass on the Lowe side | unchanged | `lowe_bridge_down` (the Lowe's windlass) | Already earned. It stays the shortcut home. |
| **The Lowe** | the Kettle Road → Kettle Fjord | an open cutting; no track to it across the moor | Sods stacked two courses high across the 2.5 m cutting (`kettle_sods`), a stack either side. *Stacked from the other side.* | `ks_turfwright_released` | WORLD.md 5.2: Arne has cut "enough to close every barrow on the Lowe, stacked neat". |
| **Kettle Fjord** | the Tarn Steps → Tarnhall | open gully; the steps unpainted | The landing's crates and barrels stacked across the gully between the gorge walls (`steps_stack`), boulders closing the rest, rime spikes on it in RIME. *Stacked from the other side.* | `ks_ice_cutter_released` | The weakest fit of the six (see Consequences). |
| **Tarnhall** | the drove-road → Thornwold | open notch; no track from the island | A dyke across the mouth of the notch with a plank gate in it (`drove_gate`). *Barred from the other side.* | `ks_host_released` | TARNHALL.md 9: Gaute barred every door so nobody would carry it home, and his release lifts the bar. This is one more of his doors. |
| Tarnhall | the hall's front doors | barred in RIME until the release | unchanged | `ks_host_released` (`release_gates`) | Already earned. |
| **Thornwold** | the fell path → Shepherd's Reach | an 11 m opening in the wood's edge; the drove-road ends the other side of the rings | His hedge laid straight across the fell path with no gate in it (`fell_hedge`): laid hedge in THAW, frozen thorn in RIME, wings of the same hedge out to the edge thicket. *Laid shut from the other side.* | `ks_hedgelayer_released` | THORNWOLD.md 6: "the hedge unlays itself stem by stem". And he never did decide where a gate goes. |
| **Shepherd's Reach** | the Upwater → the Coldwell | open pasture corner; no trod to it | A head-dyke across the 11 m neck with two wattle hurdles tied in the gap (`upwater_hurdle`); in RIME three of her ewes stand frozen against them, facing the fold. A cairn beside the gap. *Tied from the other side.* | `ks_fellcaller_released` | REACH.md 9: one soft call and the flock lies down. The ewes at the hurdles lie down with the rest. |
| **The Coldwell** | none | — | — | — | The way on is the Wellhead. |

### Hint, earn, reveal

- **Hint (before the release).** The track is worn into the turf right up to the thing in the gap, so the gap is plainly somewhere people went. The far country shows over it: the Lowe's stones over the dyke, the gorge above the stack, the wood through the notch gate. The prompt says which side it is fastened from. At Saltfell the raised bridge still stands on the skyline; the dyke and the net are now a second answer to "how do I get over there".
- **Earn.** The gate's `open_flag` is the Holdfast's `release_flag`. The gate polls it, so it opens while the Bearer is still in the arena: what stood in the gap comes down (1.4 s), the body's collision goes, and the navmesh is rebaked. An area built after the release builds the gate open.
- **Reveal (after the release).** No marker and no UI. The gap is empty and a little of what was in it lies beside it (a coil of rope, a sod, a crate, the hurdles swung back, the ewes lying down). The worn track now runs through. New tracks are painted from where the player stands after each release to the gap:
  - Saltfell: Longhouse door → behind the byre → the pass; and a spur from the head of the cliff path round the yard dyke (`terrain_saltfell.PATHS`).
  - The Lowe: from the Open Barrow north of the bog, and off the bog path west of it, both to the head of the Kettle Road, with two standing stones where the track turns into the cutting (`KETTLE_TRACK_*`).
  - Kettle Fjord: the Tarn Steps' tread from the fjord head.
  - Tarnhall: byre yard → the tarn's south-east shore → the notch (`DROVE_OUT`).
  - Thornwold: round the outside of the outer ring from the drove-road's end, past the Outer Ring hearth, to the fell path.
  - Shepherd's Reach: the fold gap → the foot of the Upwater, and up it.

### The way on, in data

Each area def carries `way_on`: a list (one entry today) of

```json
{"id": "pass_net", "name": "the cliff-top pass", "to": "lowe_barrows",
 "at": [-89.0, 22.32, -75.5], "seam": [-89.0, 23.15, -85.5],
 "open_flag": "ks_netmender_released", "gate": "pass_net"}
```

`at` is the gap, `seam` the seam beyond it, `open_flag` the world flag that opens it, `gate` the `ShortcutGate` id (its area flag is `gate_<id>`). The journal and map (`feat/ui-map-log-icons`) can name the main-thread objective from it. Nothing reads it in the game yet except the test suites.

### Code

- `src/world/shortcut_gate.gd`: `open_flag` (polled; also read at build), `unbar_prompt`, `open_toast`, `plank_leaves`, `body_depth`, and `dress()`: the gate's look as a list of pieces (kit, scene, scatter mesh or hedge section; per-state pieces go on that state's layer; `"when": "open"` pieces are set out once it is undone).
- `src/world/area_builder.gd`, the `gates` block only: reads the new keys and calls `dress()`.
- `tools/progress_gates.py`: `gate()` measures the walkable neck on the committed heightmap, lays the flanks, seats the dressing and returns the `way_on` block; `install()` puts it in the area def. Each generator calls it inside one marked block, `# --- progression gates` … `# --- end progression gates`. The painted tracks are in the terrain modules, in the same marked blocks.
- `enemies.json` is not touched. No combat number changes.

### No softlocks

- **Any hearth, any state.** Every hearth is on the near side of its region's gate. The gate's body is on the base layer, so turning the memory changes nothing about it.
- **The far side.** A `ShortcutGate` is undone from its far side with one prompt, release or no release, and that is kept as an area flag. Someone set down beyond a gate (`--area=`, an old save, a seam walked from the next region) can always come back through it. `tools/test/gates_test.gd` stands the capsule there in both states and does it.
- **Going back.** Gates are only ever on the way on. The seam behind is never held.
- **Old saves.** A save made before this change has the release flags and no `gate_*` flags. The gate reads the release flag when it is built, so those journeys find every earned gate open.
- **After the endings.** The Coldwell cannot be reached without all six releases, so every gate is already open in spring and in the kept winter.

### Tests

- `tools/test/gates_test.gd` (`tools/test.sh gates`): for each of the six gates, in THAW and RIME: no navmesh route from the start to the far side, and a capsule steered at every metre of the neck does not get through; the release's flag opens it where the Bearer stands; it is built open after a rebuild and after a save and load; from the far side it is undone with no release, and that survives a rebuild. The drawbridge is checked raised.
- `fullslice`: the pass is shut in THAW at the start and at the first rest, open at the release, and the yard's navmesh then reaches the seam.
- `fullgame_base._cross`: every crossing to the next region first checks that the way on stands open and that its flag is the release.

## Consequences

- **The order is now enforced.** Saltfell → the Lowe → Kettle → Tarnhall → Thornwold → the Reach → the Coldwell cannot be walked out of turn. A player who wanted to see the Lowe in THAW before the Netmender cannot.
- **The THAW half of each gate is a claim about that evening.** The net, the sods, the stack, the barred drove gate, the gateless hedge and the tied hurdles all stand in the remembered midsummer evening, and are gone from it once the Holdfast is released. The game already lets a release change the memory (Arne and his daughters, Pell and Ivo at the kettle). Nobody says why they were there. If narrative wants a reason on the page, each is one overheard line.
- **Kettle's gate is the least rooted.** Crates and barrels across the Tarn Steps are plausible (the feast's fish went up from here in barrels) and nothing more. A better one would be Pell's: the sledge he would not let Ivo take, stood across the steps. `lm_sledge.glb` exists; it wants an art pass to sit right, and a line in KETTLE.md.
- **The gates open at once, at the release.** If the Bearer can see the gap from the arena (the Tarn Steps from the Breathing Hole, about 28 m) the stack sinks in view. It reads as coming down. It has not been looked at on a real GPU.
- **Where a line would go** (none written here; text is the lead's): Ingra in THAW after the release, on the net being off the dyke; Aud on the Kettle Road; Lusse on the drove gate; Linnet or Eyvind at the gap; Old Calder on the hurdles. `docs/lore/*` has no such lines today.
- **`audit_edges.py` does not model these gates.** Its flood treats the gap as open (the after state), which is the larger of the two worlds, so traps and unclassed edges are still found. That the gate holds is checked in the engine by `gates_test`.
- **In RIME the tracks are under snow.** The terrain shader packs the snow on a painted path and no more, so after a release (which leaves the region in RIME until the Bearer warms it) the reveal is the emptied gap, the gateposts or stones beside it, and what was left lying. The worn track does the leading in THAW. From the release spot itself the gap is out of sight in every region but Saltfell and Kettle (the Open Barrow is walled with sods, the Host is indoors, the grave is inside three rings); the track starts at the arena's mouth, not in it.
- **Painting a track moves the scatter.** Scatter rules keep stones off painted paths (`path_max`), so every new track reshuffles that region's rocks and boulders, and with them the navmesh's fine shape. On the Lowe that tipped the walk's route from the Open Barrow to the Kettle Road onto a fault that was already there: the THAW bog's nav-only blocker was one square box whose top (W + 2.5) baked as walkable ground level with the moor, a bridge over the pool. `gen_lowe.py` now blocks an octagon out to the bog hazard's rim and stands it sixteen metres up.
- **Three more ewes.** REACH.md has seventy sheep frozen on the slope. The three at the Upwater hurdles are extra, and are the gate's (`gate_piece` meta; the walk counts the slope's seventy without them). If seventy is meant to be every sheep on the Reach, take the three `sheep` pieces out of the gate's dressing in `gen_reach.py`: the hurdles stand without them.
- **Merging.** The six splat bins changed (`data/terrain/*_splat.bin`); the height bins did not. A branch that also repaints a splat must rerun the generator after merging, not pick a side.
- A navmesh query to a point beyond a shut gate prints the engine's "most reachable polygons" error. It is the same message any cut-off navmesh island already gives.

## Screens

`docs/screens/gates_*` (1280x720, HUD off, lavapipe; none seen on a real GPU):

- `gates_before_saltfell_pass_thaw`, `…_pass_far_thaw`, `…_bridge_thaw`: the pass as it was (bare turf), and the raised bridge on the skyline.
- `gates_shut_saltfell_pass_thaw` / `_rime`, `gates_shut_saltfell_pass_far_thaw`: the dyke, the stones, the net, the track.
- `gates_open_saltfell_pass_thaw`, `gates_open_saltfell_from_longhouse_door_thaw`: after the release.
- `gates_shut_<region>_*` and `gates_open_<region>_*` for the Lowe, Kettle, Tarnhall, Thornwold and the Reach. The Kettle shots predate pulling its two outermost flank boulders down off the gorge walls.
