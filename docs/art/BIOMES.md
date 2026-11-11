# Biomes: seven regions, seven looks

*Owner: design lead. Read with `docs/art/STYLE.md`, `docs/art/LOOK_PASS.md` and `docs/qa/GPU_VISUAL_DIFF.md`. The points of interest that use these prop sets are in `docs/lore/POI.md`.*

**The requirement.** Each region must be recognisable from one screenshot with the HUD off.

**Where we are.** In `docs/gallery_gpu/v2/` every THAW shot is the same orange and every RIME shot is the same blue-white. All seven regions share one turf, one heather, one rock treatment, one grass card set and the same dozen props. Crop the buildings out of a Lowe shot and a Reach shot and they cannot be told apart.

**The fix, in order of how much it buys:**

1. **Ground.** Each region gets its own two or three photo sets and its own palette. The ground is half of every frame.
2. **Light.** Each region gets its own sun colour, fog and weather, inside a narrow range (see "Light rules").
3. **Plants.** Each region gets species the others do not have. Ling heather stays on the Lowe and leaves everywhere else.
4. **Rock.** Seven rock characters in place of one banded schist.
5. **Props.** Each region gets a set of its own, made for the work done there.

## 1. Identity lines

| Region | The one-screenshot read |
|---|---|
| **Saltfell** | Grey shingle, tarred boats and sea-pink on a cliff shelf. Everything has salt on it. |
| **The Lowe** | Red-brown heather over black peat. Long low mounds, and nothing upright but stones. |
| **Kettle Fjord** | A slot of black water between pale granite walls, with iron and steam on a narrow shelf. In RIME, one blue-green floor. |
| **Tarnhall** | One great roof on a dark tarn. Blue slate, rushes, trodden mud and yellow wool. |
| **Thornwold** | White birch trunks on a rust needle floor. Black ground round the clamps, and smoke between the trees. |
| **Shepherd's Reach** | Short bright grass on pale limestone, walls on every skyline, and more sky than land. |
| **The Coldwell** | Bare gravel and brown meltwater under blue ice. The only place in Rimeholt with flowers. |

## 2. The table

Reading notes:

- **Texture sets.** Poly Haven ids were checked against the Poly Haven texture list on 2026-11-11 and all exist. Their look was not checked: view the thumbnail before adding each to `MANIFEST` in `tools/art/fetch_textures.py`, and swap for a neighbour if it is wrong. ambientCG ids are candidates and must be confirmed at fetch. Use 1K unless the surface is seen from under 2 m. Each set needs a PROVENANCE row.
- **Palettes** are the layer means the shader re-tints to (`turf_a`, `rock_col` and so on). The photo supplies detail only, as in look pass 1.
- **Plants.** *(new card)* means a new alpha card for `Scatter`. *(new model)* means a small mesh, made in Blender unless marked Tripo.
- **Props.** **T** is a new Tripo model; its prompt is in section 3. **B** is modelled in Blender under `tools/art/procedural/`, on `proc_common`, as in look pass 5.
- **Stand-ins** are quoted from `GPU_VISUAL_DIFF.md` job 5. *(fixed, LP5)* marks those that look pass 5 says it replaced; they still need a look on the GPU.

| Region | 1. Ground palette and texture sets | 2. Ground cover and plants | 3. Rock and cliff character | 4. Own prop set | 5. Weather and light | 6. Stand-ins to replace |
|---|---|---|---|---|---|---|
| **Saltfell** *salt and boats* | **Sets:** coastal shingle `large_pebbles`; wrack-line sand and stones `coast_sand_rocks_02`; tide shelf `low_tide_rocks`; salt turf on the cliff top `aerial_grass_rock`. The shared `ganges_river_pebbles` moves to Kettle.<br>**THAW:** shingle `#8C8779`, wrack `#5B4A38`, salt turf `#6F7A4E`, thrift `#C58A9A`.<br>**RIME:** snow `#DDE4EA`, sea ice `#9FB2C2`, shade `#6E7F8C`, wet schist `#4C5A63`. | Thrift in cushions *(new card, new model for the cushion)*. Sea campion *(new card)*. Marram on the cliff edge *(new card)*. Scurvy-grass at wall feet *(new card)*. Bladderwrack and kelp along the wrack line *(new model, lies flat)*. Orange lichen on rock, in the rock texture. No heather. | Layered grey-green schist, beds dipping seaward. Two or three sea-stacks off the Strand. Wave-cut ledges with rock pools. Rock set `seaside_rock`. Keep the strata level, as now, but break the even banding with two ledge meshes. | `sf_capstan` T<br>`sf_salt_basket` T<br>`sf_gutting_bench` T<br>`sf_tar_pot` T<br>`sf_brine_trough` B<br>`sf_roller_run` B<br>`sf_oar_rack` B<br>`sf_net_sinkers` B<br>`sf_kelp_rick` B | **THAW:** sun low over the water, 12° up, `#FFD9A8`. Thin sea haze. Steam off the salt pans, drifting inland. A few gulls. No pollen.<br>**RIME:** pearl overcast, sun a pale disc at 30°, `#DCE6F5`. Light sea fret. Fine spindrift blowing onshore, sideways. | Box slab in the boat-shed and box salt blocks *(fixed, LP5; check)*. White cone flame *(fixed, LP5)*. Diamond-lattice frost floor and door veil. Featureless snow and the one smooth cone drift. Banded cliffs. |
| **The Lowe** *peat and the dead* | **Sets:** wet black peat `brown_mud_03`; cut peat face `mud_cracked_dry_03`; heather litter `brown_mud_leaves_01` (already in, now used only here); bog grass `withered_grass`.<br>**THAW:** heather `#7A4E55`, peat `#2B221D`, bog grass `#8A7B45`, moss `#5E6B3A`.<br>**RIME:** hoar `#E6E3E0`, frosted heather `#B7A9B0`, peat `#3A3136`, shade `#8C8FA0`. | Ling heather (the existing card, regraded redder, **kept here and removed from the other six**). Cotton-grass *(new card)*. Bog asphodel, yellow spikes at the water *(new card)*. Sphagnum hummocks *(new model)*. Soft rush round the bog *(card shared with Tarnhall)*. | Almost no bare rock. Rounded turf over everything. Peat hags: undercut black banks a metre high with a turf lip. Standing stones of pale sandstone with grey lichen. Matt, never glossy. Rock set `lichen_rock`, roughness raised. | `lw_peat_stack` B (3 variants)<br>`lw_peat_sled` T<br>`lw_bier` T<br>`lw_kin_post` T<br>`lw_bloomery` T<br>`lw_spade_rack` B<br>`lw_heather_bunches` B<br>`lw_sod_row` B | **THAW:** hazy gold through thin high cloud, sun 10° up, `#FFD6A6`. Blue peat smoke lying in the hollows. Midges over the bog. Larks.<br>**RIME:** lilac-grey sky, sun `#E2E0F0` at 28°. Ground fog in the cuttings, knee-deep. Still air. Hoar needles falling slowly, no flakes. | Peat drying stacks as black untextured boxes (worst in region). Polygon cloud shards. Glassy boulder at the Drying Stacks. Flat white ground with pebbles. |
| **Kettle Fjord** *ice fishing* | **Sets:** shelf shingle `ganges_river_pebbles` (moved from Saltfell, graded colder); wet shore `damp_sand`; granite walls `cliff_side`; blue ice ambientCG `Ice004` (candidate) over the existing `Ice003`.<br>**THAW:** granite `#A39E97`, water `#1F2A30`, shingle `#6C6F70`, rust `#7A4A32`.<br>**RIME:** ice `#8FC4C9`, deep ice `#3E7C8C`, snow `#E3EEF2`, granite shade `#5C6B78`. | Very little, on purpose. Roseroot and sea plantain in cracks *(new card)*. Crowberry mats on ledges *(new model, flat)*. Black and grey lichen in the rock texture.<br>RIME only: frost flowers on the ice *(new card)*; wind-scoured bare ice with thin snow ribbons. | Pale granite walls, near vertical, jointed top to bottom. Dark water stains. Hanging ice-falls in RIME *(new model, shared with the Coldwell)*. The spires must read as rock, not extrusions: break each face with three or four joint-block meshes. | `kf_ice_hut` T<br>`kf_tool_rack` T<br>`kf_dog_picket` T<br>`kf_windbreak` T<br>`kf_jig_frame` B<br>`kf_fish_cord` B<br>`kf_ice_blocks` B<br>`kf_bough_markers` B | **THAW:** sun straight down the fjord, 13° up, `#FFDDB0`. One wall lit, the other in shade, **lifted with a cool sky fill `#8FA3B5`** so it never goes black. Kettle steam. No haze toward the sun (anisotropy down from 0.66 to about 0.3).<br>**RIME:** clear and cold, sun `#D6ECF2` at 24°. No snowfall. Ice glitter. A thin frost-smoke along the foot of the walls. | Fjord walls as huge flat facets (worst in region). White triangular shard at the start and the landing. Frost veil as a flat card edge-on *(fixed, LP5; check)*. THAW blow-out toward the sun and crushed gorge shadow. |
| **Tarnhall** *feasting* | **Sets:** trodden mud `muddy_tracks`; slate scree on the shore `slate_driveway`; planked yard `wood_planks_dirt`; worn grass `grass_path_2`.<br>**THAW:** slate `#56606B`, mud `#5A4A3A`, rush `#7C8448`, lichen yellow `#C9A545`.<br>**RIME:** snow `#ECEDED`, slate `#6B7480`, tarn ice `#A9B4BC`, frosted yellow `#CFC08A`. | Soft rush in clumps round the tarn *(new card)*. Water horsetail standing in the shallows *(new card)*. Dock and nettle against the byre walls *(new card)*. Bare trodden earth for ten metres round every door. No heather, no flowers. | Blue-grey slate, cleaved flat. Slabs dip into the tarn like tilted tables. Slate scree in fans at the foot of the basin walls. Rock set `rock_face_03`, graded blue. The causeway kerbs become slate on edge. | `th_spit` T<br>`th_ale_vat` T<br>`th_bake_oven` T<br>`th_carving_frame` T<br>`th_horn_rack` B<br>`th_trestles` B<br>`th_oar_stand` B<br>`th_rush_bundles` B | **THAW:** the latest light of the seven. Sun 18° up, rose-gold `#FFD2AE`. Firelight in the doorway. Hearth smoke lying flat over the water. Midges over the tarn.<br>**RIME:** flat white overcast, no visible sun, light `#E4E8EE`. Big soft flakes falling straight down. No wind at all. | The perfect granite cube on the causeway *(fixed, LP5; it was the primitive hearthstone)*. White cone fire, box benches, white-cube horns *(fixed, LP5)*. Striated gorge walls. Brown smog at the Tarn Steps in THAW *(density fixed)*. |
| **Thornwold** *charcoal and hedging* | **Sets:** pine-needle litter `forest_ground_04`; birch leaf litter `forest_leaves_02`; charcoal ground `burned_ground_01`; root mat `roots`; drove-road mud `mud_forest`.<br>**THAW:** needles `#8A5A36`, charcoal `#1E1C1B`, birch bark `#D9D4C6`, moss `#55693A`.<br>**RIME:** shade `#8E8BB0`, hoar `#E8E6F0`, charcoal `#25232A`, birch `#CFCBD6`. | Bracken *(new card)*. Bilberry *(new card)*. Moss cushions on stones *(new model)*. Hazel coppice stools *(new model)*. Birch saplings *(new model)*. Pine cones and fallen twigs in the litter texture. No grass cards under the canopy. | Mossy boulders, rounded, half sunk. Root plates of two or three windthrown pines, with the pit beside each *(new model)*. No cliffs inside the wood. Rock set `mossy_rock`. | `tw_collier_hut` T<br>`tw_shaving_horse` T<br>`tw_riddle_stand` T<br>`tw_clamp_set` B (3 stages)<br>`tw_cordwood` B<br>`tw_hurdle` B<br>`tw_stake_bundle` B<br>`tw_stile` B<br>`tw_charcoal_sacks` B | **THAW:** green-gold under the canopy, sun 22° up, `#FFE2B4`. Thin shafts only. Pollen thick. Blue charcoal smoke at head height. **Forest floor fill raised** so it never reads black.<br>**RIME:** violet shade, sun `#DCD8F0` at 28°. Fog between the trunks. Hoar sifting off the branches in small falls, not from the sky. | Frozen thorn as flat glassy shards (worst in the game) *(fixed, LP5; check on GPU)*. RIME hedges as stacked card strips *(fixed, LP5)*. Orange box fence posts in THAW. Charcoal clamp as a dome with green dots. Low-res birch trunk with a dark band. Black forest floor in THAW. |
| **Shepherd's Reach** *sheep and folds* | **Sets:** sheep-cropped turf `sparse_grass`; limestone pavement `rock_surface`; thin soil over rock `aerial_ground_rock`; scree `rocky_gravel`.<br>**THAW:** turf `#7E9A4A`, limestone `#C9C6B8`, wall `#9A9A90`, cotton-white `#EDE8D8`.<br>**RIME:** snow `#F2F4F5`, limestone `#BFC6CC`, fleece `#DAD3C2`, shade `#93A6BA`. | Short fescue, half the height of the shared grass card *(new card)*. Mountain avens, white *(new card)*. Thistles by the walls *(new card)*. Mat-grass tussocks *(new card)*. Prostrate juniper on the ledges *(new model)*. Wool caught on thistle and wall *(new card)*. | Pale limestone pavement: flat clints with dark grykes between. Low scars in steps. Drystone everywhere, pale, with through-stones and a coping. Rock set `marble_rock_01`, graded grey-white. The fell flanks need a top-down projection on the smear. | `sr_ewe` T (rigged)<br>`sr_shearing_stool` T<br>`sr_cheese_press` T<br>`sr_wool_frame` T<br>`sr_creep_wall` B<br>`sr_slab_gate` B<br>`sr_crook_rack` B<br>`sr_counting_stone` B<br>`sr_coping_row` B | **THAW:** high and clear, the palest sun, 18° up, `#FFEBCB`. Long views. Cloud shadows moving over the grass. Wind in the grass cards. Thistledown.<br>**RIME:** bright thin overcast, sun `#E8EEF6` at 26°. Wind. Spindrift running low along the ground. No falling snow. | The sheep as eggs on sticks (worst in region) *(LP5 swapped the mesh and added a head swing; still unrigged)*. Smeared fell flanks. Polygon cloud shards. Faceted box ledges. |
| **The Coldwell** *the spring and those who walk up to it* | **Sets:** glacial gravel `gravelly_sand`; river cobble `river_small_rocks`; flowered gravel for the Melt `flower_scattered_gravel`; spring moss `rock_pitted_mossy`; moraine `dry_riverbed_rock`.<br>**THAW (the Melt):** meltwater `#7B5F45`, gravel `#8F9092`, spring moss `#6FA046`, marigold `#E2B93B`.<br>**RIME:** blue ice `#5FA8D0`, shade `#2F4E7A`, snow `#EAF2F8`, bare rock `#4A5058`. | THAW only: marsh marigold *(new card)*, lady's smock *(new card)*, purple saxifrage cushions *(new model)*, star moss round the spring *(new model, flat)*.<br>RIME: nothing grows. Hoar feathers on the stones *(new card)*. | Moraine: heaps of unsorted grey boulders and grit. Ice-polished bedrock with scratch lines. Blue ice at the glacier's lip, and ice-falls beside the path *(the model shared with Kettle)*. The peak needs a ridge and two shoulders, not a pyramid. | `cw_thread_post` T<br>`cw_flower_basket` T<br>`cw_dipper_trough` T<br>`cw_shelter` B<br>`cw_staff_rack` B<br>`cw_rope_rail` B<br>`cw_slab_bench` B<br>`cw_ice_column` B | **THAW:** a spring morning, the only cool-white sun. 34° up, `#FFF2DC`. Spray mist over the river. Flower heads on the water.<br>**RIME:** clear, still, deep blue shade under the ice, sun `#CFE4F5` at 20°. Ice glitter. Nothing falls. | Hard flat horizon planes (worst in region). The Upwater as a flat ribbon with white streaks. The peak as a smooth pyramid. Dark ring round the RIME sun. Box rock at the frame edge. |

### Light rules (all regions)

The owner found the light overdone. The differences above are in colour, fog and weather. They are not in contrast.

- **Sun energy** in THAW comes down from 2.3–2.6 to **1.6–1.8** everywhere. RIME stays at or under 1.4.
- **Sun to shade.** A grey card in full sun is at most **2.2 times** as bright as the same card in open shade in THAW, and at most **1.8 times** in RIME. Check it with `tools/shot.sh` at each hearth. Raise the ambient or the sky fill to hold the ratio. Do not lower the sun further.
- **No frame is more than 1% pure black or pure white** at eye height. The Kettle start and the Thornwold floor fail this today.
- **Sun colours stay close.** THAW suns run from `#FFD2AE` (Tarnhall) to `#FFF2DC` (the Coldwell). RIME suns run from `#CFE4F5` to `#E8EEF6`. A region is told apart by its ground, fog colour and weather before its sun.
- **Fog distance does not change between states**, as STYLE.md already says.
- **One particle weather per region and state.** Seven in THAW and seven in RIME, none repeated. It is the cheapest tell there is.

## 3. Prop sheets

Every Tripo prompt ends with the STYLE TAIL from `STYLE.md`, then `single object only, plain background, no text, no lettering`. Props exist in both states; the shader lays the frost. Log the spend in `docs/art/TRIPO_LEDGER.md`. Ask the owner before spending: this is 26 models, plus 2 in `POI.md`.

### Saltfell

| id | Make | What |
|---|---|---|
| `sf_capstan` | T | *Hand capstan for hauling boats up a beach: a squat oak drum on a timber frame, four worn ash bars, a coil of tarred hawser, set on beach stones.* |
| `sf_salt_basket` | T | *Three conical wicker draining baskets on a driftwood stand, each heaped with wet grey salt, a crust of salt down the stand's legs.* |
| `sf_gutting_bench` | T | *Long fish-gutting bench of salt-bleached planks on trestles, knife-scarred top, a tub underneath, a whalebone knife and a heap of split cod.* |
| `sf_tar_pot` | T | *Black iron tar pot on a three-legged stand over a ring of beach stones, a tarred brush of tied bristle laid across the rim, drips down the side.* |
| `sf_brine_trough` | B | Hollowed pine log, 3 m, salt crust at the waterline, a wooden scoop. |
| `sf_roller_run` | B | Six log rollers and two keel blocks laid up the shingle. |
| `sf_oar_rack` | B | Two posts and pegs holding six oars; thole pins in a bored block. |
| `sf_net_sinkers` | B | A cord of holed beach stones and bog-iron rings, hung on a peg rail. |
| `sf_kelp_rick` | B | Kelp laid to dry over a low drystone wall, 3 m. |

### The Lowe

| id | Make | What |
|---|---|---|
| `lw_peat_stack` | B | Cut peats stacked herringbone to dry. Three variants: a low row, a round-topped stack 1.4 m high, and a wall. Replaces the black boxes. |
| `lw_peat_sled` | T | *Low wooden peat sled with slatted sides and a rope trace, half loaded with dark cut peats, runners caked in black mud.* |
| `lw_bier` | T | *Burial bier of two long ash poles joined by woven wool bands, undyed, leaning against a turf bank, one band newly mended.* |
| `lw_kin_post` | T | *Waist-high oak post at the foot of a grave mound, the top carved with one abstract interlaced household knot, grey and split with weather, lichen on the north side.* |
| `lw_bloomery` | T | *Small clay bloomery furnace built into a bank of cut peat, a leather-and-board bellows on a pack-frame beside it, slag and charcoal at its mouth.* |
| `lw_spade_rack` | B | A rail with four peat spades and a turf knife. |
| `lw_heather_bunches` | B | Tied bunches of heather, single and heaped. |
| `lw_sod_row` | B | Lifted sods laid in a row, grass up, with the cut strip beside them. |

### Kettle Fjord

| id | Make | What |
|---|---|---|
| `kf_ice_hut` | T | *Small ice-fishing hut on two wooden sledge runners, plank walls, hide roof weighted with stones, a low door, a smoke pipe of rolled bark.* |
| `kf_tool_rack` | T | *Ice-cutter's tool rack of driftwood: a long-toothed ice saw, iron ice tongs, a skimming ladle of bent wood and a coil of line, all hung on pegs.* |
| `kf_dog_picket` | T | *Sledge-dog picket line: a heavy rope pegged between two stakes with six short tethers, a split-log feed trough, a harness of leather and bone toggles hung on one stake.* |
| `kf_windbreak` | T | *Windbreak for the ice: three poles lashed as a frame with a stitched sealskin stretched across, weighted with ice blocks at the foot, a three-legged stool behind it.* |
| `kf_jig_frame` | B | A tip-up frame over a fishing hole: a forked stick, a balanced arm, a line. |
| `kf_fish_cord` | B | Frozen cod stacked like cordwood between two stakes. |
| `kf_ice_blocks` | B | Sawn ice blocks, stacked three high; reads as blue-green glass in RIME. |
| `kf_bough_markers` | B | Spruce boughs stuck upright to mark holes and safe ice. |

### Tarnhall

| id | Make | What |
|---|---|---|
| `th_spit` | T | *Long iron roasting spit on two forked iron stands over a stone-lined fire trench, a crank handle, a dripping trough of soapstone under it.* |
| `th_ale_vat` | T | *Big coopered ale vat, chest high, oak staves and withy hoops, a plank lid half off, a step-block beside it.* |
| `th_bake_oven` | T | *Outdoor bake oven: a clay dome on a drystone plinth, soot round the mouth, a wooden peel and a board of round flat loaves beside it.* |
| `th_carving_frame` | T | *Butcher's hanging frame of three stout poles with iron hooks and a gambrel, beside a scarred chopping block.* |
| `th_horn_rack` | B | A peg-board of drinking horns, forty pegs. |
| `th_trestles` | B | Trestle tables and stacked benches for the overflow outside. |
| `th_oar_stand` | B | A stand of oars in seven different cuts of blade. |
| `th_rush_bundles` | B | Tied bundles of cut rushes for the hall floor. |

### Thornwold

| id | Make | What |
|---|---|---|
| `tw_collier_hut` | T | *Charcoal-burner's hut: a low cone of poles covered in turf sods, a hide door flap, a stool and a water pail outside, soot on everything.* |
| `tw_shaving_horse` | T | *Shaving horse of split oak with a foot-clamp, a drawknife left on the seat, curled hazel shavings on the ground.* |
| `tw_riddle_stand` | T | *Collier's riddle: a wide round sieve of woven hazel on a three-legged stand, a long-handled wooden rake leaning on it, charcoal dust underneath.* |
| `tw_clamp_set` | B | The charcoal clamp in three stages: stacked billets round a centre stake; turfed and smoking; opened and raked out. Replaces the dome with green dots. |
| `tw_cordwood` | B | Billets corded between two stakes, 2.4 m. |
| `tw_hurdle` | B | Woven hazel hurdle, 1.8 m. Replaces the orange posts. |
| `tw_stake_bundle` | B | Hazel stakes and binders, tied. |
| `tw_stile` | B | A two-step plank stile built through a laid hedge. |
| `tw_charcoal_sacks` | B | Sacks of charcoal, stacked and one spilled. |

### Shepherd's Reach

| id | Make | What |
|---|---|---|
| `sr_ewe` | T | *Northern short-tailed ewe, thick cream fleece, dark legs and face, small curved horns, standing square.* Rigged quadruped. This is the model look pass 5 asked for. |
| `sr_shearing_stool` | T | *Low three-legged shearing stool with iron hand-shears on it and a rolled cream fleece tied with twine beside it.* |
| `sr_cheese_press` | T | *Stone-weighted cheese press of oak, a wooden pail and two round cheeses wrapped in cloth on the board.* |
| `sr_wool_frame` | T | *Tall pole frame holding a long hanging wool sack half filled with fleece, a ladder against it.* |
| `sr_creep_wall` | B | A drystone wall section with a creep hole and its slab door. |
| `sr_slab_gate` | B | Two limestone slabs on edge as gateposts, with three slip-rails. |
| `sr_crook_rack` | B | Crooks and a hazel stick on pegs by a door. |
| `sr_counting_stone` | B | A flat stone with a worn hollow and a heap of pebbles. |
| `sr_coping_row` | B | Wall stones laid out on the grass in the order they go back. |

### The Coldwell

| id | Make | What |
|---|---|---|
| `cw_thread_post` | T | *Tall weathered pine post set in a small cairn, wound from head to foot with hundreds of short wool threads in faded blue, red and yellow.* |
| `cw_flower_basket` | T | *Shallow willow basket of fresh marsh flowers, yellow and pale lilac, a few tied in small bunches with grass.* |
| `cw_dipper_trough` | T | *Stone drinking trough fed by a split-log spout, a cow-horn dipper on a cord, moss on the stone.* |
| `cw_shelter` | B | An open-fronted turf-and-stone shelter, 6 × 3 m, a sleeping bench along the back. |
| `cw_staff_rack` | B | A rail of walking sticks, each cut differently. |
| `cw_rope_rail` | B | Stakes and a rope handrail for the steep parts. |
| `cw_slab_bench` | B | A stone slab bench facing down the valley. |
| `cw_ice_column` | B | Ice-fall columns in three sizes (also used on the Kettle walls). |

## 4. Still shared across regions, on purpose

- **The house kit:** turf roofs, adzed timber, carved gables, plank floors. One people built all of it.
- **The Hearthstone.** The player must know it on sight anywhere.
- **Masks, and the three household colours.** Woad blue is Saltfell's, and it is seen in other regions only where Maren went.
- **Drystone technique.** The stone changes colour by region; the way it is laid does not.
- **Standing stones.** The Barrow Road and the Wellhead ring use the same stone on purpose. The dead go from one to the other.
- **The clinker boat,** at Saltfell, Kettle and Tarnhall. The oars differ.
- **Barrels, crates, sacks and the woodpile.** Trade goods travel.
- **The frost itself:** the hoar shader, the frost veil's body, the frost-taken's rime. RIME is one event that happened to seven places.
- **The base snow set.** Each region tints it and lays its own weather over it.
