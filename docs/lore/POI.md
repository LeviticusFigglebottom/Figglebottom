# Points of interest

*Owner: narrative and design lead. Truth is in `WORLD.md`; voice rules are in `WRITING.md`; prop sets are in `docs/art/BIOMES.md`. Ids are suggested data keys. Coordinates are approximate and in each generator's own terms: snap them with the generator's `at()` at build.*

Thirty authored places across the seven regions. Each has something to do, find or read, and each feeds a Keepsakes thread or makes a Holdfast easier to understand. None of them explains anything.

**Conventions used below.**

- **Plaque** means the existing wayside board (`plaques` in the area JSON, kit `plaque`). Nobody in Rimeholt writes. The board carries a carved knot, and the text is the game's caption for the place, in the voice of the plaques already in the generators. A plaque may be tagged `thaw` or `rime`; many here have one of each on the same board.
- **Overheard** uses the `overhear` block in `npcs.json`, THAW only. Speakers marked *unseen* are voices from inside a building, as the two children on the Strand already are. They need no model.
- **Pickups** follow the item voice: a plain fact, then one human detail.
- **Props** named `sf_`, `lw_`, `kf_`, `th_`, `tw_`, `sr_`, `cw_` are from the BIOMES prop sheets. Only two places need a Tripo model of their own; both are marked.
- **Ground.** Nothing here stands on a 2.4 m jetty, on the Tarn Causeway's plank bridge or on the Reach's plank bridge. Where a place needs room, the widening is given with rough dimensions, and section 9 lists them all.

## 1. Count and threads

| Region | Places | Threads fed |
|---|---|---|
| Saltfell | 4 | Brede's float; Ingra's rye (one new step) |
| The Lowe | 5 | Orm's cord; Hesk's tongs (one new step) |
| Kettle Fjord | 5 | Ivo's mitten (two new steps); a shortcut |
| Tarnhall | 4 | Ottar's stick (one new step); the guest-tally |
| Thornwold | 4 | Linnet's song-cord; two shortcuts |
| Shepherd's Reach | 4 | Calder's boots; **a new thread, "Smudge"**; a shortcut |
| The Coldwell | 4 | Knucklebones; the fostering horn; a new one-step thread, "Melt flowers" |

`REGIONS_QA.md` open items 7 and 8 are answered in section 10.

---

## 2. Saltfell

### 2.1 `sf_drag_mark` — the Drag-Mark

- **Zone and place:** the Strand. From where Brede stands in his boat, about (-6, 73), a line running north-west up the shingle to the foot of the cliff path.
- **Purpose:** the player learns that one boat went up the beach, pulled by one person who did not stop to lay rollers.
- **State:** both, and they read differently.
  - THAW: Brede's boat on its rollers, bow to the water. A second run of rollers lies ready beside it for the morning.
  - RIME: the boat is gone. One furrow in the shingle, a keel wide, goes up the beach beside the rollers and never onto them.
- **Plaque** (`rime`, at the low end of the furrow):
  > THE STRAND
  >
  > One boat went up the beach.
  > The rollers were lying beside it the whole way.
- **Pickup** (RIME, in the furrow halfway up; *Pick up the thole pin*): **Thole Pin** (`item_thole_pin`)
  > An ash thole pin, whittled to fit Brede's boat and no other. He went round all four the evening before he rowed out. This one was in the shingle halfway up the beach, where the boat was dragged past its own rollers.
- **Thread:** Brede's float. Brede, shown the pin in THAW: "That's off mine. They don't come out. You'd have to pull her over sideways to get that out."
- **Props:** `sf_roller_run` ×2, `lm_brede_boat` (THAW). The furrow is a terrain decal with a parallax groove, tagged `rime`.
- **Ground:** none needed.

### 2.2 `sf_salt_house` — the Salt House

- **Zone and place:** Saltfell yard, the salt house on the cliff edge, 6 m west of the Salt House hearth (-26, 23.5).
- **Purpose:** the first time the player hears somebody decide not to know about the cough. In RIME, the first fire that was kept up for no reason anyone would say.
- **State:** both.
- **Overheard** (THAW, two salt-boilers *unseen* inside; within 7 m of the door):
  > "Rake it to the edge. It's catching."
  > "It's not catching. Who's that in the byre?"
  > "Nobody. It's the hay."
  > "That's three nights it's been the hay."
  > "Then it's good hay. Are you raking or am I?"
- **Pickup** (RIME, in the split pan; *Lift out the salt*): **Cake of Pan Salt** (`item_pan_salt`)
  > A cake of grey salt the size of a loaf, scorched brown underneath. The pan it came out of had boiled dry and split along the bottom. The firebox under it is packed with ash to the door, from a fire that was fed for days by somebody who never looked in the pan.
- **Thread:** none. It is worth 60 warmth to Ingra ("That's burnt. Who burns salt?").
- **Props:** `salt_pan` (existing; a split variant for RIME), `sf_brine_trough`, `sf_salt_basket` ×2, `woodpile`.
- **Ground:** none needed.

### 2.3 `sf_cliff_graves` — the Cliff Graves

- **Zone and place:** Saltfell yard, the turf terrace to the east, at the small grave, about (41, 16). The knucklebones pickup is already here.
- **Purpose:** the player sees that the small grave was opened with care, by someone who meant to close it again. It is also the best view of the frozen tide.
- **State:** both. Two plaques on one board.
- **Plaque** (`thaw`):
  > THE CLIFF GRAVES
  >
  > Fisherfolk lie here with their feet to the water.
  > The small one is new. The thrift on it was picked today.
- **Plaque** (`rime`):
  > THE CLIFF GRAVES
  >
  > The small one was opened from above, with a spade.
  > The turf was laid to one side, grass up, in the order it came off.
- **Props:** `lw_sod_row` (the one Lowe piece used outside the Lowe, and only in RIME: it is the same turf, laid the way a barrow-keeper would lay it); a turf spade standing in the ground; the Rimewalker already sitting here.
- **Thread:** Knucklebones (it stands beside step 1).
- **Ground:** none needed.

### 2.4 `sf_lookout_stone` — the Lookout Stone

- **Zone and place:** Saltfell yard, the west headland, at the existing `stores_headland` pickup, about (-84, -4). A flat stone at the cliff edge that faces up the coast toward Kettle Fjord.
- **Purpose:** the player learns that Gunna sat out here for the three days Brede was gone, and that Ingra fed her.
- **State:** both.
  - THAW: an empty flat stone with a view. A net-needle case left on it.
  - RIME: three bowls on the stone, one inside the next.
- **Pickup** (RIME; *Take the bowls*): **Three Bowls** (`item_three_bowls`)
  > Three wooden bowls from the Longhouse, frozen one inside the next, each with fish stew in it. They were on the flat stone on the headland, the one that faces Kettle Fjord. Ingra said she was not keeping anyone's supper, and carried it out three evenings running.
- **Thread:** Ingra's rye, one new step.
  - Flag `ks_ingra_bowls`, set by talking to Ingra in THAW with the bowls. Journal: "Ingra was three bowls short. She had known she was three short."
  - Ingra: "Those are mine. Who's had those out on the head?" / "Three short. I knew I was three short. Put them on the end, I'll wash them."
  - It explains her last line in the existing thread, where she counts the bowls and gets eleven, then twelve, then eleven.
- **Props:** three bowls (Blender, one mesh), `sf_net_sinkers` on the wall behind.
- **Ground:** level already. Clear the two wayside groups nearest the stone so the view is open.

---

## 3. The Lowe

### 3.1 `lw_bread_mound` — the Bread Mound

- **Zone and place:** the Kin-Mounds, on top of `kin_b` (-24, -112), reached by its south shoulder.
- **Purpose:** what the Lowe was for, before. The player hears a family be ordinary about their dead.
- **State:** both.
  - THAW: the cloth, the crumbs and the upturned cup already described in `LOWE.md`.
  - RIME: the cloth is gone. The cup is still there.
- **Overheard** (THAW, a man and a woman *unseen*, going home down the road toward the pass; within 12 m of the mound):
  > "You left the cup."
  > "I left it for her."
  > "You left it because you forgot it."
  > "Upside down, so the dew stays out. That's leaving it for her."
  > "She'd have said you forgot it."
  > "She would."
- **Pickup** (RIME; *Prise the cup off the turf*): **Birch Cup** (`item_birch_cup`)
  > A small birch cup, left upside down on a kin-mound so it would not fill with dew. It has frozen to the turf by its rim. Inside, where the frost never got in, the wood is still the colour of bread.
- **Thread:** Orm's cord. Aud, shown the cup in THAW: "That's the miller's lot. They leave something every year and then send a child up for it."
- **Props:** a cloth and a cup (Blender), `lw_kin_post` at the mound's foot.
- **Ground:** none needed.

### 3.2 `lw_last_mound` — the Last Mound

- **Zone and place:** the Kin-Mounds, at the door of `kin_d` (22, -132), where the road bends.
- **Purpose:** Aud ties heather here every evening for a husband who is under a different mound. In RIME the player sees how many evenings.
- **State:** both.
  - THAW: one fresh bunch of purple heather on the door turf.
  - RIME: heather in tied bunches, heaped to the height of the door and spilling down both sides of it.
- **Plaque** (`rime`):
  > THE LAST MOUND
  >
  > Heather in bunches, one for every evening.
  > The ones at the bottom have gone to dust. All of it is purple.
- **Small encounter** (RIME): the Keener already placed at the bend stands with its back to the heap. No new foes.
- **Thread:** Orm's cord. It makes step 4 ("Aud has moved her heather to the first mound") cost something.
- **Props:** `lw_heather_bunches` (one bunch in THAW; about sixty instanced in RIME), `lw_kin_post`.
- **Ground:** none needed.

### 3.3 `lw_hesk_fire` — Hesk's Fire

- **Zone and place:** the peat cutting west of the road, at Hesk (-58, -166). His furnace is dug into the peat wall behind him.
- **Purpose:** the player finds the job Arne was waiting on, half done.
- **State:** both.
  - THAW: the furnace burning and Hesk complaining.
  - RIME: the furnace cold, the bellows frozen to the bank.
- **Pickup** (RIME, on the edging stone beside the furnace; *Take the spade-iron*): **Spade-Iron** (`item_spade_iron`)
  > The blade of a turf spade with no handle in it, left at a smith's fire to be edged. One face is ground bright and the other has not been started. It was wanted before the Melt.
- **Thread:** Hesk's tongs, one new step.
  - Flag `ks_hesk_iron`, set by talking to Hesk in THAW with the iron. Journal: "Hesk said he would have Arne's spade back to him by the morning."
  - Hesk: "That's Arne's. I've one side done." / "He'll have it by the morning. I always have it back to him by the morning."
- **Props:** `lw_bloomery` (replaces whatever stands in for the furnace now), `lw_spade_rack`, `lw_peat_stack` (wall variant) along the cutting's lip.
- **Ground:** none needed. The cutting floor is level.

### 3.4 `lw_cutters_bothy` — the Cutter's Bothy

- **Zone and place:** the Open Barrow zone, 8 m south-west of the Drying Stacks hearth (32, -166), in the lee of the first stacks, about (25, -171).
- **Purpose:** the twins as children, in one object.
- **State:** both.
  - THAW: Arne's dinner cloth on the bench. Three spades by the door: one full size, two small.
  - RIME: the big spade is gone. The two small ones are still by the door.
- **Pickup** (RIME; *Take the small spades*): **Two Small Spades** (`item_small_spades`)
  > Two turf spades with blades a hand wide, on handles cut down from a broken rake. Arne Holm made them so his girls would leave his alone. Each handle has been notched once by one hand and twice by another, and nobody could have said which spade was whose.
- **Thread:** none. It sits beside the twins' spindles in the Pack.
- **Props:** **`lm_cutters_bothy`, new Tripo landmark:** *Turf-cutter's bothy, a low shelter of stacked sods on a drystone footing with a driftwood lintel and a hide door, a plank bench along the front wall.* Also `lw_spade_rack`, `lw_peat_sled`.
- **Ground:** a level pad 6 × 5 m cut into the slope.

### 3.5 `lw_the_rise` — the Rise

- **Zone and place:** on the road between the Drying Stacks hearth and the frost veil, where it tops the lip of the hollow, about (40, -177).
- **Purpose:** a view that sets up the Turfwright. From here the player can count the stacks.
- **State:** both.
- **Plaque** (`base`):
  > THE DRYING STACKS
  >
  > Turf is cut at midsummer and laid by the Melt.
  > There is more turf cut here than the Lowe has barrows.
- **Props:** `lw_peat_stack` in place of every box stack in the hollow; `lw_sod_row` at the roadside.
- **Ground:** none needed. Keep the wayside groups off the sight-line into the hollow.

---

## 4. Kettle Fjord

The shelf is 8 m wide and the jetties are 2.4 m. Every place here is on the road, on new ground, or out on the RIME ice.

### 4.1 `kf_road_turn` — the Turn in the Road

- **Zone and place:** the Landing Ice, on the Kettle Road's last bend above the shelf, uphill of the plaque at `SH(-108)`.
- **Purpose:** a view down the whole fjord that sets up the Ice-Cutter before the player has heard of him.
- **State:** both. Two plaques on one board.
- **Plaque** (`thaw`):
  > THE KETTLE ROAD
  >
  > You can smell the kettles from here.
  > Every boat on the water is coming in.
- **Plaque** (`rime`):
  > THE KETTLE ROAD
  >
  > At the fjord head there is one round of black water with white round its edge.
  > Everything else has skinned over.
- **Props:** a boulder to sit against; `kf_bough_markers` ×3 down the road's outer edge.
- **Ground:** **a bay 5 × 4 m on the outside of the bend,** with a low drystone kerb, so the board and the view are off the road.

### 4.2 `kf_dog_lines` — the Dog Lines

- **Zone and place:** the Fish-Houses, between the Fish-Houses hearth `SH(-58)` and where Ivo stands `SH(-52)`.
- **Purpose:** the player finds the one thing Ivo should have taken.
- **State:** both.
  - THAW: the dogs on their tethers, Ivo harnessing two of them.
  - RIME: the picket rope and six empty tethers. The two Sledge-dogs already placed stand on the ice just below.
- **Pickup** (RIME, leaning on the picket stake; *Take the sounding pole*): **Sounding Pole** (`item_sounding_pole`)
  > An ash pole shod with iron, for knocking on new ice ahead of the sledge. You knock three times and listen. It was leaning at the dog lines, where a boy in a hurry would walk straight past it.
- **Thread:** Ivo's mitten, one new step between the existing steps 1 and 2.
  - Flag `ks_ivo_pole`, set by talking to Ivo in THAW with the pole. Journal: "Ivo says he can hear the ice through his feet."
  - Ivo: "That's Grandfather's. He knocks on everything." / "You don't need it. You can hear ice through your feet, if you're any good."
- **Props:** `kf_dog_picket`, `kf_fish_cord`, the existing `lm_sledge`.
- **Ground:** **a shingle spit 10 × 6 m built out from the shelf between x -64 and x -54,** tagged `base`, at shelf height. It keeps the picket and the trough off the walkway.

### 4.3 `kf_net_cleft` — the Net-Cleft (shortcut)

- **Zone and place:** the east spur, about x -15, at shelf level: a cleft through the rock wide enough for a boat on rollers, where nets are hung out of the wind.
- **Purpose:** Kettle's missing shortcut. It joins the Fish-Houses hearth to the Breathing Hole on rock the whole way.
- **State:** both. In THAW it is a dry way round the east jetty. In RIME it matters.
- **Shortcut:** gate `gate_net_cleft` (flag of the same name).
  - A hurdle of frozen net is lashed across the east mouth. From the west the prompt is *Lashed from the other side*.
  - The first time, the player goes round the spur on the ice, past the thin ice at the middle house, the Ice-fisher at the fjord head and the Sealer on the east shelf.
  - From the east the prompt is *Cut the lashing*. After that the run from the hearth to the frost veil is about 45 m with no thin ice.
- **Pickup** (RIME, on a peg inside): 2 bog-iron (`cleft_cache`; *Take the net-weights*).
- **Props:** `net_frame` ×2 and `rope_coil` (both existing), `kf_tool_rack`.
- **Ground:** **a notch through the east spur, 2.6 m wide and about 9 m long,** floor at shelf height, in the terrain generator. Add it to the navmesh in both states and keep the gate a real collider.

### 4.4 `kf_ice_camp` — the Ice Camp

- **Zone and place:**
  - THAW: four huts drawn up on their runners against the wall foot at the west end of the shelf, about `SH(-122)` to `SH(-112)`, beyond the hearth where nobody walks.
  - RIME: the same four huts out on the ice, 30 m north of the Landing Ice hearth, about (-96, `fz(-96)` - 4), in a rough ring.
- **Purpose:** when the fjord froze in the Long Light, the fishers did what they do when it freezes. The player finds Ivo's line there.
- **State:** both, and the huts move.
- **Small encounter** (RIME): two Ice-fishers kneeling at holes that have skinned over, and one Sealer behind the windbreak. The Sealer does not rise until an Ice-fisher is struck.
- **Pickup** (RIME, in the hut with a madder band on its door; *Take the line-winder*): **Line-Winder** (`item_line_winder`)
  > A notched board wound with forty fathoms of tarred jigging line, the hook bent out of a nail. Old Pell cut the notches for a smaller hand than his. The line is wound on the way he showed, and then a few turns the other way.
- **Thread:** Ivo's mitten, one new step.
  - Flag `ks_ivo_line`, set by talking to Ivo in THAW with the winder. Journal: "Ivo says the line holds either way round."
  - Ivo: "That's mine. He says I wind it backwards. It holds, doesn't it?"
- **Props:** `kf_ice_hut` ×4, `kf_jig_frame` ×5, `kf_windbreak`, `kf_ice_blocks`, `kf_bough_markers` ringing each hole.
- **Ground:** none in THAW (the wall-foot strip west of the hearth is unused). In RIME the camp is on the ice sheet; keep it 12 m clear of the west spur's crevasse.

### 4.5 `kf_far_landing` — the Far Landing

- **Zone and place:** the north shore, at the existing `north_shore_cache`, about (-60, `fz(-60)` - half the fjord's width + 3.5). It can only be reached in RIME, across the ice.
- **Purpose:** the healer Ivo went to fetch was packed to come. The player learns it from a sledge.
- **State:** RIME to reach. In THAW it is seen across the water: a small house with smoke.
- **Plaque** (`rime`):
  > THE FAR LANDING
  >
  > The healer's sledge is packed and the door is shut behind it.
  > She was waiting for the ice to be made.
- **Pickup** (RIME, strapped on the sledge; *Unstrap the pack*): **Healer's Pack** (`item_healer_pack`)
  > A sealskin pack of dried coltsfoot, a horn spoon and clean linen, strapped to a hand-sledge at the far landing. The straps are done up for travelling. Whoever packed it meant to cross as soon as the ice would bear a grown woman.
- **Thread:** none, by design. Ivo is not shown it. It sits in the Pack under the mitten.
- **Props:** **`lm_healer_sledge`, new Tripo landmark:** *Small hand-sledge with a single hauling loop, a sealskin pack strapped on with three leather straps, a folded blanket and a pair of ice-creepers tied on top.* Also one BuildingGen house 6 × 6 m, door shut, no interior.
- **Ground:** **a shingle spit 12 × 7 m on the north shore,** tagged `base`, at shelf height, with a 2 m ramp of shingle down to the ice. The existing cache moves onto it. The far landing is new canon, kept inside what `WORLD.md` §5.3 already says: the healer was on the far shore.

---

## 5. Tarnhall

The island is 72 × 36 m and the hall takes most of it. Two terraces are added.

### 5.1 `th_seven_landings` — the Seven Landings

- **Zone and place:** the Tarn Causeway zone, the south shore at the causeway's land end, beside the Tarn Causeway hearth (124, -331).
- **Purpose:** the guests meant to go home. The first view of the hall, with its doors open or shut.
- **State:** both.
  - THAW: seven boats drawn up, each with a different cut of oar. One has its oars left in.
  - RIME: the boats in the ice to the gunwales. The one with its oars in still has them in.
- **Overheard** (THAW, two late guests at the boat with its oars in; mannequin stand-ins, `mute`):
  > "Is that the goat one? They've not got far."
  > "Ninth verse. I counted from the steps."
  > "Then there's time. Leave the oars in, we're not stopping long."
  > "You said that last year."
  > "Last year there was no fish."
- **View:** the board stands where the hall's west doors are framed between two boat prows.
- **Plaque** (`rime`):
  > THE TARN CAUSEWAY
  >
  > Seven boats. One was left ready to go, with the oars in.
  > Nobody came back down for any of them.
- **Thread:** the guest-tally (it shows seven neighbourhoods before the cord does).
- **Props:** `th_oar_stand`, the existing `boat` ×7, `rope_coil`.
- **Ground:** the shore here is already wide. Keep everything off the causeway itself.

### 5.2 `th_porch` — the Porch

- **Zone and place:** the hall's west porch, the south side of the front doors, opposite the latch wool. About (`HALL_X0` - 1.0, `DOOR_Z` - 1.4).
- **Purpose:** somebody came for Ottar. The player finds what she put down to knock.
- **State:** RIME for the pickup. In THAW the doors are propped open and the porch is full of wet cloaks and sticks.
- **Pickup** (RIME; *Take the stick*): **Rowan Stick** (`item_rowan_stick`)
  > A rowan walking stick with a horn cap, the pair of the one inside the door. It was leaning on the porch against the barred doors, where you put a thing down to knock with both hands. The cap is worn on the other side.
- **Thread:** Ottar's stick, one new step after step 2.
  - Flag `ks_ottar_pair`, set by talking to Ottar in THAW with the rowan stick. Journal: "Ottar says the other stick is his wife's, and that she is at home."
  - Ottar: "That's hers. What's that doing up here?" / "She's at home. She's got the calving. She'd not leave the calving."
- **Props:** the stick reuses the `item_ottar_staff` mesh, mirrored. `th_horn_rack` on the porch wall; cloaks on pegs (THAW).
- **Ground:** none needed. The porch floor exists. Keep 1.2 m clear in front of the doors for the gate.

### 5.3 `th_cook_yard` — the Cook-Yard

- **Zone and place:** the Byres zone by extension: a new terrace on the island's north side, behind the hall's east half, x 198 to 214, z -347 to -340. Reached from the byre yard round the hall's north-east corner.
- **Purpose:** the Host kept sending out for more. The player hears the cooks say so, and then finds the vat scraped dry.
- **State:** both.
  - THAW: the spit turning, the oven lit, two cooks.
  - RIME: the spit with the last roast on it, black. The vat empty.
- **Overheard** (THAW, two cooks at the vat; mannequin stand-ins, `mute`):
  > "He's sent back for more. Again."
  > "There's the forty barrels and that's the lot. I told him."
  > "He said open another."
  > "Half the far bench isn't eating. They're sat there coughing."
  > "Then he'll want it kept hot for them."
- **Small encounter** (RIME): two Cupbearers, one each side of the vat, working as a pair.
- **Pickup** (RIME, hooked on the vat's rim; *Take the dipper*): **Vat Dipper** (`item_vat_dipper`)
  > A long-handled sycamore dipper for the ale vat behind the hall. The vat is dry to the wood. The dipper's lip is worn flat on one side from being scraped along the bottom.
- **Thread:** the guest-tally. Lusse, shown the dipper in THAW: "He's had that vat filled twice since noon. He counts the horns, not the guests."
- **Props:** `th_spit`, `th_ale_vat`, `th_bake_oven`, `th_carving_frame`, `th_trestles`.
- **Ground:** **a drystone terrace 16 × 7 m built out on the island's north side,** floor at `ISLAND_Y`, with a 3 m walk round the hall's north-east corner to the byre yard. Tagged `base`. The tarn ice in RIME meets its foot; no way up from the ice.

### 5.4 `th_south_window` — the South Window

- **Zone and place:** the hall's south wall, about a third of the way along from the front doors, at (190, `HALL_C` z + 7.3). On the way from the porch round to the byres.
- **Purpose:** a view that sets up the Host: the feast seen from outside, before the player can get in.
- **State:** both.
- **View:** a horn-pane window with one pane out, at eye height. The prompt is *Look in*. A four-second look through the gap, then control returns.
  - THAW caption: "They are on the ninth verse. The high seat is empty."
  - RIME caption: "Everyone is sitting down. One man is on his feet, going along the table with a horn."
- **Props:** a horn-pane window (Blender, set into the BuildingGen wall); an upturned pail under it, where somebody short stood to look in; `th_rush_bundles` against the wall.
- **Thread:** none.
- **Ground:** **a turf walk 3 m wide along the hall's south wall** from the porch to the byre yard, where the island allows about 11 m. Level it and keep the wayside groups off it.

---

## 6. Thornwold

### 6.1 `tw_the_notch` — the Notch

- **Zone and place:** the Collier's Clearing zone, on the road as it comes down out of the notch, 10 m before the Drove-Road hearth (318, -315).
- **Purpose:** a view over the wood that sets up the Hedgelayer: three rings round one tree.
- **State:** both. Two plaques on one board.
- **Plaque** (`thaw`):
  > THE NOTCH
  >
  > Four clamps are lit. Blue smoke means burning and white means cooking.
  > All four are white.
- **Plaque** (`rime`):
  > THE NOTCH
  >
  > Three rings of hedge round one pine.
  > A hedge keeps stock in. There is no stock in there.
- **Props:** `tw_hurdle` as a rail at the edge; `tw_cordwood`.
- **Ground:** **a bay 6 × 4 m on the downhill side of the road,** and a cut through the canopy (remove about eight trees from `Forest`) so the pine and the rings can be seen from it.

### 6.2 `tw_linnets_hut` — Linnet's Hut

- **Zone and place:** the Collier's Clearing, on its north edge, about (340, -291), facing the clamps.
- **Purpose:** the night Linnet tied her own Outsong. The player finds what she cut off.
- **State:** both.
  - THAW: one bed, two cups. Eyvind's whetstone on her shelf.
  - RIME: the bed has been slept in and not made. The floor has been swept into one corner.
- **Pickup** (RIME, in the swept corner; *Gather the ends*): **Ends of Wool** (`item_wool_ends`)
  > Short ends of plaited wool, oat and yellow, cut with a billhook and swept into the corner of a collier's hut. A song-cord takes an evening to tie if you know what you want said. There are a great many ends here.
- **Thread:** Linnet's song-cord. Lusse, shown the ends in Tarnhall THAW after step 4: "She's cut and started again, look. Six times. Seven. It's hard, saying it about yourself."
- **Props:** `tw_collier_hut`, `tw_riddle_stand`, `tw_charcoal_sacks`, `tw_clamp_set` (all three stages across the four clamps).
- **Ground:** none needed. The clearing is 34 m across.

### 6.3 `tw_gate_field` — the Field They Haven't Got

- **Zone and place:** the Collier's Clearing zone, north of the drove-road between the clearing and the first road plug, about (372, -302): a square of hedge 14 m a side, laid on three sides.
- **Purpose:** Eyvind could not decide before there was anything to grieve. The player finds gateposts on both sides.
- **State:** both.
  - THAW: a waist-high laid hedge, a pair of gateposts in the east side and a pair in the west, no gate in either.
  - RIME: the three sides are frozen thorn. The fourth is still open.
- **Small encounter** (RIME): one Rime-stag standing inside the square, and the Collier now placed "on the road" moved to its open side.
- **Pickup** (RIME, on top of the east gatepost; *Take the latch*): **Gate Latch** (`item_gate_latch`)
  > A latch and its keeper whittled from holly, oiled and never fitted. They were on the east post of a field with gateposts on two sides. The latch is cut to close from the left, and the keeper is cut for the right.
- **Thread:** Linnet's song-cord. Linnet, shown the latch in THAW: "He's made that for both. Look at it. It won't fit either."
- **Props:** `hd_laid` hedge sections (existing), `hd_thorn3a/b` (RIME), four gateposts (Blender), `tw_stake_bundle`, `tw_shaving_horse`.
- **Ground:** clear a 16 × 16 m square in `FOREST_CLEAR`.

### 6.4 `tw_layers_stiles` — the Layer's Stiles (shortcut)

- **Zone and place:** the Hedge. Two stiles on one bearing, 125° round from the Outer Ring hearth's side: one through the outer ring (26 m) and one through the middle ring (19 m). They line up with the walk from the hearth to the innermost gap.
- **Purpose:** Thornwold's missing shortcut. Also the plainest thing about Eyvind: he could not lay a hedge badly, so he put the stiles in.
- **State:** both.
  - THAW: two plank stiles in the laid hedge. Nobody needs them, because the gaps line up.
  - RIME: thorn has grown over each stile from the outside.
- **Shortcut:** gates `gate_stile_outer` and `gate_stile_inner`.
  - From outside the prompt is *Grown over*.
  - From inside each ring, having come the long way round, the prompt is *Break the thorn off the stile*.
  - With both open, the run from the Outer Ring hearth to the frost veil is two stiles and about 30 m. It passes the Rime-stag between the rings, at a distance.
- **Plaque** (`rime`, at the outer stile, inside):
  > THE HEDGE
  >
  > There is a stile in every ring, built the proper way.
  > Then he let the thorn grow over them.
- **Props:** `tw_stile` ×2; `hd_thorn_heap` cut down to stile width for the plug.
- **Ground:** none needed. Leave a 2 m landing either side of each stile and add both to the RIME navmesh only once their flags are set.

---

## 7. Shepherd's Reach

### 7.1 `sr_counting_stone` — the Counting Stone

- **Zone and place:** the Sheilings, on the south bank of the beck, 5 m short of the plank bridge and 3 m west of the trod, about (615, `beck_z(618)` + 8). **Not on the bridge.**
- **Purpose:** a view up the trod that sets up the Fellcaller. In THAW it is one woman calling. In RIME it is the whole slope looking one way.
- **State:** both. Two plaques on one board.
- **Plaque** (`thaw`):
  > THE COUNTING STONE
  >
  > One pebble in the hollow for every ewe over the bridge.
  > Forty-three pebbles, and room in the hollow for one more.
- **Plaque** (`rime`):
  > THE COUNTING STONE
  >
  > Nothing has come back over the bridge.
  > Every one of them is facing up the hill.
- **Thread:** Calder's boots (it stands beside the forty-three and the forty-four).
- **Props:** `sr_counting_stone`, `sr_slab_gate` at the bridge's south end, off the planks.
- **Ground:** **a level pad 5 × 4 m on the south bank.**

### 7.2 `sr_smudge` — Smudge

- **Zone and place:** the Sheilings, at the door of the lower sheiling `S0` (600, -296), 3 m from Calder's boots.
- **Purpose:** one ewe did not answer the call. It gives the Reach its second thread.
- **State:** both.
  - THAW: a ewe with a dark smear down her nose, grazing by the sheiling door and nowhere else.
  - RIME: the same ewe stood at the door with her back to the fold.
- **Look** (RIME; *Look at the ewe*): "A ewe with a dark smear down her nose. She is the only one on the fell not facing the fold. She is facing the door."
- **New thread, Keepsakes: "Smudge"**

  | Step | Flag | Set when | Journal line |
  |---|---|---|---|
  | 1 | `ks_smudge_named` | Calder's repeat line "Where's Smudge. There's Smudge." is heard (THAW) | "Calder counts a ewe called Smudge last, every time." |
  | 2 | `ks_smudge_found` | Look at the ewe at the sheiling door (RIME) | "One ewe is not facing the fold. She is at the sheiling door." |
  | 3 | `ks_smudge_told` | Talk to Calder in THAW after step 2 | "Calder says Smudge comes to a pocket. She has never once come to a call." |
  | 4 | `ks_smudge_fed` | Stand by the ewe in THAW wearing or carrying the Shepherd's Fleece (*Turn out the pocket*) | "Smudge ate the oatcake and went back to the door." |

- **Calder, at step 3:** "Smudge? She'll be at the door." / "Never come to a call in her life, that one. She comes to a pocket."
- **After the release (RIME):** when every sheep on the slope lies down, Smudge lies down too, where she is, still facing the door. No line.
- **Reward at step 4:** one bog-iron's worth of warmth (90). The oatcake is already in the fleece's description.
- **Props:** `sr_ewe` with a face-smear tint; `sr_crook_rack` by the door.
- **Ground:** none needed.

### 7.3 `sr_lower_sheiling` — the Lower Sheiling

- **Zone and place:** the Sheilings, inside `S0` (600, -296). The door is on the latch, as `REACH.md` says, so it opens.
- **Purpose:** the night Old Calder left. The player reads it from two beds.
- **State:** both.
  - THAW: two heather beds, both a mess. A pot, two bowls, a crook by the door.
  - RIME: one bed made. The other thrown back, with its blankets on the floor.
- **Pickup** (RIME, on the made bed; *Take the blanket*): **Calder's Blanket** (`item_calder_blanket`)
  > A grey wool blanket folded in four on a bed of heather, with the corners squared. The bed across from it was left thrown back and its blankets are on the floor. He was never known to fold a thing in his life.
- **Thread:** Calder's boots. Sigga, shown the blanket in THAW: "That's not his. His is the one on the floor."
- **Props:** `sr_cheese_press`, `sr_shearing_stool`, two heather beds (Blender), `sr_crook_rack`.
- **Ground:** none. If the sheiling has no interior yet, give `S0` one through `house_interior.gd` at 5 × 4 m. Do not move the boots.

### 7.4 `sr_drift_lane` — the Drift Lane (shortcut)

- **Zone and place:** the High Fold zone. A walled lane 3 m wide and about 55 m long, from the beck's north bank at about (634, -340) up the west edge of the slope to the fold wall, 6 m west of its gap.
- **Purpose:** the Reach's missing shortcut. It is how the flock was driven up before Sigga could call.
- **State:** both. In THAW its bottom gate stands open and sheep graze in it.
- **Shortcut:** gate `gate_drift_lane`.
  - At the bottom a slab-and-rail gate is tied shut on the lane side. From the beck the prompt is *Tied from the other side*.
  - The first time, the player climbs through the seventy and the three Frost-rams, enters the lane's top end beside the fold gap, walks down and unties it (*Untie the gate*).
  - After that the run from the Sheilings hearth is: the beck, the lane, the fold gap. No sheep and no rams.
- **Pickup** (RIME, on the wall's coping halfway down): the existing `fold_cache` moves here.
- **Props:** `sr_creep_wall` (one creep hole, so THAW sheep can be seen going through), `sr_slab_gate`, `sr_coping_row` where the wall is down, `sr_wool_frame` at the top.
- **Ground:** **two drystone walls 55 m long, 3 m apart,** real colliders in both states, with the lane floor graded to walking slope. The RIME flock's scatter keeps 2 m off the outer wall.

---

## 8. The Coldwell

The path is 6 m wide with a drop on the river side. Three ledges are cut into the uphill side. THAW here is the last Melt, a spring morning, and nobody is on the path: everyone is up at the water.

### 8.1 `cw_flower_bank` — the Flower Bank

- **Zone and place:** the Upwater, on the uphill side 12 m above the Upwater hearth (between path points 1 and 2).
- **Purpose:** the Melt's custom, in the player's own hands.
- **State:** both.
  - THAW: marsh marigold and lady's smock on a wet bank. A basket somebody has put down.
  - RIME: snow. In the river beside it, one of the standing dead, a small woman, holds a bunch of flowers in both hands.
- **Pickup** (THAW; *Pick a bunch*): **Melt Flowers** (`item_melt_flowers`)
  > Marsh marigold and lady's smock, picked on the way up and tied with a stem of grass. They are thrown in at the wellhead for the year's dead. You are meant to turn round before they are out of sight.
- **New one-step thread, Keepsakes: "Melt flowers"**

  | Step | Flag | Set when | Journal line |
  |---|---|---|---|
  | 1 | `ks_melt_flowers` | At the water's edge beside Maren and Wren, carrying the bunch (THAW; *Throw them in*) | "The flowers went down the water. Wren watched them out of sight." |

  Wren, as they go: "And that one." It is her own repeat line. Maren says nothing new.
- **Props:** `cw_flower_basket`; a hand-held bunch (Blender) for the river figure, which is an existing `upwalker` still.
- **Ground:** **a ledge 6 × 3 m** cut into the uphill bank.

### 8.2 `cw_stick_shelter` — the Shelter at the Ice-Falls

- **Zone and place:** the Upwater, on the uphill side beside the Ice-Falls hearth (path point 4, 0.6 along).
- **Purpose:** people come up, and people go down again. The player sees that the second half stopped.
- **State:** both. Two plaques on one board.
- **Plaque** (`thaw`):
  > THE ICE-FALLS
  >
  > You cut a stick to come up, and leave it here for someone going down.
  > The rack is nearly empty. Everyone is up at the water.
- **Plaque** (`rime`):
  > THE ICE-FALLS
  >
  > The rack is full. There are more against the wall, and more on the ground.
  > Nobody has wanted one going down.
- **Small encounter** (RIME): the `upwalker_falls` already on the path here is moved onto the shelter's bench, seated (`pose: sit`, `rise_time` 2.4 s). It got this far and sat down.
- **Thread:** the fostering horn (the walk it sits on).
- **Props:** `cw_shelter`, `cw_staff_rack` (four sticks in THAW; full, with about forty more instanced in RIME), `cw_rope_rail` along the next steep pitch, `cw_ice_column` on the falls.
- **Ground:** **a ledge 8 × 5 m** cut into the uphill side, floor level with the path.

### 8.3 `cw_sitting_place` — the Sitting Place

- **Zone and place:** the Upwater, on the last rise, 6 m above the Wellhead Steps hearth (path point 8), on the downhill side where the land opens.
- **Purpose:** a view that sets up the Leadvoice, in both directions. Down the water lies every region the player has walked. Up it are the ring and one seated figure. It is also where she sat.
- **State:** both. Two plaques on one board.
- **Plaque** (`thaw`):
  > THE WELLHEAD STEPS
  >
  > You can hear it from here.
  > Children are carried the last part, so they see it all at once.
- **Plaque** (`rime`):
  > THE WELLHEAD STEPS
  >
  > The snow on this bench has been sat in, at the left end only.
  > Something was put down at the right end, and picked up again.
- **Props:** `cw_slab_bench` with a RIME snow variant carrying the two hollows (Blender, one mesh).
- **Thread:** Knucklebones and the fostering horn. No flag. It is the last thing before the Wellhead that the player puts together alone.
- **Ground:** **a ledge 6 × 4 m** on the downhill shoulder, with `cw_rope_rail` on its open side. Check it with `tools/audit_edges.py`: it must not make a new trap.

### 8.4 `cw_thread_post` — the Thread-Post

- **Zone and place:** the Wellhead, on the level between the two turf houses, outside the ring, about (`WX` - 21, `WZ` - 8).
- **Purpose:** how many dead a year used to be. The player gets a number to hold against the river.
- **State:** both. Two plaques on one board.
- **Plaque** (`thaw`):
  > THE WELLHEAD
  >
  > A thread on the post for each one going down the water this year.
  > Blue, red and yellow. Eleven. It was a mild winter.
- **Plaque** (`rime`):
  > THE WELLHEAD
  >
  > The same eleven threads, white with frost.
  > Nobody came up to tie the next year's.
- **Props:** `cw_thread_post`, `cw_dipper_trough` at the spring's overflow.
- **Thread:** the fostering horn.
- **Ground:** none needed. Keep it 10 m from the frost veil.
- **New canon, for the owner to confirm:** tying a thread at the wellhead for each of the year's dead. It does not contradict `WORLD.md` §2. A household thread tied for the dead is already there in the woad thread on the closed barrow.

---

## 9. Ground to be widened

| Region | Where | What | Size |
|---|---|---|---|
| The Lowe | the Cutter's Bothy | level pad cut into the slope | 6 × 5 m |
| Kettle Fjord | the Turn in the Road | bay on the outside of the bend | 5 × 4 m |
| Kettle Fjord | the Dog Lines | shingle spit off the shelf, x -64 to -54 | 10 × 6 m |
| Kettle Fjord | the Net-Cleft | notch through the east spur at shelf height | 2.6 × 9 m |
| Kettle Fjord | the Far Landing | shingle spit on the north shore, with a ramp to the ice | 12 × 7 m |
| Tarnhall | the Cook-Yard | drystone terrace on the island's north side | 16 × 7 m |
| Tarnhall | the South Window | turf walk along the hall's south wall | 3 m wide |
| Thornwold | the Notch | bay on the downhill side of the road; canopy cut | 6 × 4 m |
| Thornwold | the Field | clearing in the wood | 16 × 16 m |
| Shepherd's Reach | the Counting Stone | pad on the beck's south bank | 5 × 4 m |
| Shepherd's Reach | the Drift Lane | two walls and a graded lane | 3 × 55 m |
| The Coldwell | the Flower Bank | ledge, uphill side | 6 × 3 m |
| The Coldwell | the Shelter | ledge, uphill side | 8 × 5 m |
| The Coldwell | the Sitting Place | ledge on the downhill shoulder, railed | 6 × 4 m |

All of it goes into the terrain generators, never into hand-edited output. Run `tools/audit_edges.py` after each: a new ledge is a new place to get stuck.

## 10. What this answers in REGIONS_QA

- **Item 7, three regions with no shortcut.**
  - Kettle Fjord: `gate_net_cleft` (4.3).
  - Thornwold: `gate_stile_outer` and `gate_stile_inner` (6.4).
  - Shepherd's Reach: `gate_drift_lane` (7.4).
- **Item 8, the Reach has one thread.** It now has two: "Calder's boots" and "Smudge" (7.2).
- **Item 13, in passing.** The Collier "on the road" who stands 7 m off it moves to the open side of the Field (6.3), where 7 m off the road is where it should be.

## 11. New items and Tripo models

**Items (15):** Thole Pin, Cake of Pan Salt, Three Bowls, Birch Cup, Spade-Iron, Two Small Spades, Sounding Pole, Line-Winder, Healer's Pack, Rowan Stick, Vat Dipper, Ends of Wool, Gate Latch, Calder's Blanket, Melt Flowers. Each needs an icon from `tools/gen_icons.py` and a small world mesh made in Blender.

**New Tripo models for places (2):** `lm_cutters_bothy` (3.4) and `lm_healer_sledge` (4.5). With the 26 in `BIOMES.md`, the plan asks for 28 Tripo models in all. That is money: ask the owner before generating.

## 12. New names

Added to `LEXICON.md`: the Drag-Mark, the Lookout Stone, the Bread Mound, the Last Mound, the Cutter's Bothy, the Rise, the Dog Lines, the Net-Cleft, the Ice Camp, the Far Landing, the Seven Landings, the Cook-Yard, the South Window, the Notch, the Field They Haven't Got, the Layer's Stiles, the Counting Stone, the Drift Lane, the Flower Bank, the Sitting Place, the Thread-Post, and the fifteen items above. Checked against `tools/banned_terms.txt` and `docs/transposition/ORIGINALITY.md` §1–5: no bells, candles, wax, bees, choirs, runes or letters; nothing from another game. The brief's word for the people who walk up to the Coldwell is not used, because ORIGINALITY §3 keeps that figure for the source: here they are people who come up for the Melt.
