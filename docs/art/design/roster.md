# Tripo hero roster

*Owner: art direction. Implements ADR 0002 (`docs/decisions/0002-tripo-budget-allocation.md`). Style rules: `docs/art/STYLE.md`. Story context: `docs/lore/WORLD.md`, `docs/lore/SLICE.md`.*

80 Tripo 3D slots plus 14 concept images (94 slots). The rest of the ~100-asset ceiling is re-roll reserve.

## Generate first: SLICE tier (20 3D + 2 images)

| # | id | kind | rig |
|---|---|---|---|
| 1 | `netmender` | Holdfast | custom |
| 2 | `rimewalker` | enemy | biped |
| 3 | `oarsman` | enemy | biped |
| 4 | `hearthhound` | enemy | quadruped |
| 5 | `bearer_traveller` | the Bearer, start | biped |
| 6 | `bearer_oilskins` | the Bearer, armour | biped |
| 7 | `ingra` | NPC | biped |
| 8 | `brede` | NPC | biped |
| 9 | `hewing_blade` | weapon | none |
| 10 | `saltfell_shield` | shield | none |
| 11 | `fostering_horn` | hip prop | none |
| 12 | `gourd` | hip / hand prop | none |
| 13 | `mending_needle` | weapon (release drop) | none |
| 14 | `lm_hearthstone` | landmark | none |
| 15 | `lm_long_hearth` | landmark (boss arena) | none |
| 16 | `lm_doorpost` | landmark | none |
| 17 | `lm_mask_pegs` | landmark | none |
| 18 | `lm_brede_boat` | landmark | none |
| 19 | `lm_frost_veil_net` | boss gate | none |
| 20 | `lm_tide_wall` | landmark | none |
| — | `concept_saltfell_thaw`, `concept_saltfell_rime` | 2D concept | — |

Order inside the slice: `rimewalker` first (pipeline pilot, per TASKS), then `hewing_blade`, then `netmender`, then the rest.

**Slice cost estimate:** 8 rigged at ~115 (plus the extreme-texture surcharge on the Netmender) and 12 static at ~95, about 2,100 credits. **Full roster estimate:** 45 rigged (~5,200) + 35 static (~3,300) ≈ 8,500 credits before re-rolls and extreme-texture surcharges. That leaves room inside the 24,700 balance for a second roll on every boss and on any slot that fails review. Log every spend in `docs/art/TRIPO_LEDGER.md`.

## Prompt conventions (apply to every slot)

- **Characters (biped):** description, then `single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands`, then the STYLE TAIL, then the state tail where the slot is single-state.
- **Creatures (quadruped):** `single creature only, plain background, standing square on all four legs, side-on neutral pose`.
- **Objects:** `single object only, plain background, no text, no lettering`.
- **Faces:** every humanoid is masked or hooded; each prompt says `no visible face`.
- **Held items are separate assets.** Weapons, shields, tools and the Gourd are never in a character prompt. Hip props named in Bearer prompts (fire-horn left hip, gourd right hip) are belted, not held; if Tripo fuses them badly, re-roll without them and attach `fostering_horn` / `gourd` to hip bones.
- **Holdfast fused parts** (net, turf door, table, auger, fleece, ice swaddle) are body, not held items, and stay in the prompt.
- **Left/right** is the character's own left/right.
- **Bearer variants** share one mask (`birch mask with woad-blue band`) so the silhouette reads as the same person across armour sets. Only `bearer_outsong` changes it (Maren's mask).
- **State:** "both states" slots are generated clean; the frost/hoar branch of `hall.gdshader` adds RIME. Frost-taken and Holdfasts are RIME-only and carry the RIME tail. NPCs exist only in THAW and carry the THAW tail.
- **STYLE TAIL (verbatim):** `painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR`
- **Texture quality:** `extreme` for all seven Holdfasts; `detailed` for everything else.
- Prompts target ~600 characters. The longest (`netmender`) is 628.

## Procedural instead of Tripo (do not spend credits on these)

Per ADR 0002, `tools/art/procedural/` makes these with the shared MaterialLib (`M_timber`, `M_stone`, `M_wool`, `M_iron`, `M_horn`, `M_turf`):

- **Kit:** longhouse walls (plain and door), roof bays, plain posts (only the carved door-post is Tripo), plank floors, steps, dry-stone walls, turf mounds, boat-shed shells, sheilings beyond the one landmark, fold walls, barrow mounds (only the door is Tripo), the Tarnhall hall shell.
- **Props:** fish-drying racks, net racks (and the frozen nets on them, as a cloth-sim bake), barrels, sea-chests, crates, sacks (including the rye sack), benches, the long table (plain sections), bowls, cups, drinking horns, pots, salt pans, washing lines, fences, hurdles, stacked turf sods, charcoal stacks, tally-sticks, knot-cords other than Linnet's, peg boards beyond the mask-peg landmark.
- **Nature:** rocks, scree, terrain, heather and grass cards, birch and pine trees, thorn-hedge walls (spline-swept, the Thornwold maze), ice formations, icicles, snow drifts, the frozen river surface.
- **Effects:** the frost veil's shimmer and melt, the frost/melt wavefront, breath plumes, snowfall, pollen motes, embers, Breathmarks.
- **Frozen sheep slope, seated feast-guests and the Coldwell crowd:** instance the Tripo enemy meshes (`frost_ram`, `feast_guest`, `upwalker`) in static poses with shader variation; no extra slots.
- **Candidates to move to procedural if credits run short:** `lm_tide_wall` (ice sculpt), `lm_charcoal_clamp`, `lm_fold_cairn`, `lm_sledge`.

## Bosses (Holdfasts) (7)

### `netmender` — the Netmender (Gunna)

- **Tier:** slice **(SLICE: generate first)** · **Size:** 3.2 m · **Rig:** custom (biped + net/back-figure bones) · **Texture:** extreme · **State:** RIME-only

```
Huge hunched old woman in grey wool, birch mask with woad-blue band, no visible face. Frozen fishing net wrapped round her shoulders trailing behind; a masked drowned man bound in it on her back, his mask over her left shoulder. Ice needle fingers. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `turfwright` — the Turfwright (Arne Holm)

- **Tier:** region · **Size:** 3.4 m · **Rig:** custom (biped + back-door hinge) · **Texture:** extreme · **State:** RIME-only

```
Massive broad man in brown wool and leather apron, hood, oak mask, no visible face. His back is a barrow door of stacked frozen turf sods hinged at the shoulders, propped open. Peat-spade blade fused to his right forearm. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `ice_cutter` — the Ice-Cutter (Old Pell)

- **Tier:** full · **Size:** 3.0 m · **Rig:** custom (biped + trailing traces) · **Texture:** extreme · **State:** RIME-only

```
Tall bowed old man in grey furs and felt hood, pine mask with madder band, no visible face. Long iron ice-auger grown through his right forearm, pointing down. Frozen sledge harness traces trail from his waist behind. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `host` — the Host (Gaute Haug)

- **Tier:** full · **Size:** 4.0 m · **Rig:** custom (biped + table spine) · **Texture:** extreme · **State:** RIME-only

```
Enormous heavy man in lichen-yellow and brown feast wool, fur collar, broad oak mask, no visible face. A long timber feast table grows from his spine like a ridge, drinking horns frozen to it. Carved seat-posts fused to both hips. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `hedgelayer` — the Hedgelayer (Eyvind Brask)

- **Tier:** full · **Size:** 3.6 m · **Rig:** custom (biped, long limbs) · **Texture:** extreme · **State:** RIME-only

```
Lean very tall man woven from laid thorn-stems and hazel binders, ash mask half grown over with briar on its left side, no visible face. Thorn branches fan from shoulders and back like a laid hedge. Torn felt at the hips. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `fellcaller` — the Fellcaller (Sigga Calder)

- **Tier:** full · **Size:** 3.4 m · **Rig:** biped · **Texture:** extreme · **State:** RIME-only

```
Tall woman cloaked crown to knees in a heavy matted ram fleece, two great curled ram horns framing a smooth birch mask, no visible face. Oat wool dress, sheepskin boots, calling horn fused at her right hip. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `leadvoice` — the Leadvoice (Maren of Saltfell)

- **Tier:** full · **Size:** 4.0 m · **Rig:** custom (biped + spread cloak) · **Texture:** extreme · **State:** RIME-only

```
Very tall woman in grey and woad-blue wool, deep hood, birch mask with woad-blue band, no visible face. A small child in a swaddle of clear ice bound to her chest by a woad-blue sash. Cloak spreads behind into a frozen sheet. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```


## Enemies (frost-taken) (18)

### `rimewalker` — Rimewalker

- **Tier:** slice **(SLICE: generate first)** · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Ordinary villager in undyed oat and grey wool tunic, hood, felt leggings, plain carved mask, no visible face. Both hands grown over with blunt clubs of ice. Icicles at the hem, mask rimed white. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `oarsman` — Oarsman

- **Tier:** slice **(SLICE: generate first)** · **Size:** 1.9 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Broad-backed fisherman in a short oilskin smock and grey hood, plain mask, no visible face. Both hands fused into one long ice oar, held level across his body, blade end to his left, 2.8 m long. Wet hems frozen stiff. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `hearthhound` — Hearthhound

- **Tier:** slice **(SLICE: generate first)** · **Size:** 0.8 m at shoulder · **Rig:** quadruped · **Texture:** detailed · **State:** RIME-only

```
Large shaggy grey steading dog, thick matted coat, rimed muzzle, icicles hanging from belly fur, a woven woad-blue collar. single creature only, plain background, standing square on all four legs, side-on neutral pose. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `barrow_sleeper` — Barrow-sleeper

- **Tier:** region · **Size:** 1.9 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Dead man wrapped in a brown wool burial cloak bound with cord, strips of frozen turf and heather clinging to the shoulders, carved mourning mask, no visible face. Hands frozen into heavy fists of ice. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `keener` — Keener

- **Tier:** region · **Size:** 1.75 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Slender mourner in long grey and madder-red wool robe, deep hood, mask with an open mouth hole, no visible face. A frozen breath plume of ice grows from the mouth hole. Fingers are thin icicles. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `cairn_carrier` — Cairn-carrier

- **Tier:** region · **Size:** 2.2 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Heavy stooped man in brown wool and sheepskin, hood, plain mask, no visible face. A yoke of frozen grey-green schist stones grown across both shoulders and upper back. Forearms thick with ice. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `ice_fisher` — Ice-fisher

- **Tier:** full · **Size:** 1.7 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Hunched fisher in layered grey furs and felt hood, mittens, plain pine mask, no visible face. Both hands grown into long curved ice-picks. Fish-bone toggles on coat. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `sledge_dog` — Sledge-dog

- **Tier:** full · **Size:** 0.7 m at shoulder · **Rig:** quadruped · **Texture:** detailed · **State:** RIME-only

```
Lean thick-furred cream and grey sledge dog with a leather harness and frozen traces trailing behind, rimed muzzle and ears. single creature only, plain background, standing square on all four legs, side-on neutral pose. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `sealer` — Sealer

- **Tier:** full · **Size:** 2.0 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Heavy hooded hunter in sealskin-look grey hide coat and felt, plain mask, no visible face. Right forearm fused into a thick ice club, left hand an ice hook. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `feast_guest` — Feast-guest

- **Tier:** full · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Feast guest in good lichen-yellow and brown wool tunic, fur collar, carved festival mask, no visible face. Rimed spilled drink frozen down the chest. Hands grown into rounded ice fists. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `cupbearer` — Cupbearer

- **Tier:** full · **Size:** 1.7 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Slim young server in short brown tunic and apron, felt cap and hood, small mask, no visible face. Both hands grown into thin straight ice blades. Light quick build. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `hall_champion` — Hall-champion

- **Tier:** full · **Size:** 2.1 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Big hall guard in quilted felt coat over iron mail shirt, fur cape, carved oak war mask, no visible face. A round board shield of ice grown into the left forearm. Right fist frozen into a mace-head of ice. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `collier` — Collier

- **Tier:** full · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Charcoal-burner in soot-black leather apron over oat wool, hood, mask blackened with charcoal, no visible face. Hands frozen black ice with ember-dark cores. Ash-grey hems. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `rime_stag` — Rime-stag

- **Tier:** full · **Size:** 1.4 m at shoulder · **Rig:** quadruped · **Texture:** detailed · **State:** RIME-only

```
Red deer stag, heavy winter coat, wide antlers with frozen thorn branches grown through them, rimed back and muzzle. single creature only, plain background, standing square on all four legs, side-on neutral pose. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `frost_ram` — Frost-ram

- **Tier:** full · **Size:** 1.0 m at shoulder · **Rig:** quadruped · **Texture:** detailed · **State:** RIME-only

```
Heavy horned ram, thick matted fleece, massive curled horns, icicles hanging from belly fleece. single creature only, plain background, standing square on all four legs, side-on neutral pose. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `drover` — Drover

- **Tier:** full · **Size:** 2.1 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Long-limbed herder in sheepskin cape and oat wool, deep hood, smooth birch mask, no visible face. Both hands fused into one long crook of ice, hook end up on his right side. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `upwalker` — Upwalker

- **Tier:** full · **Size:** 1.9 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
One of the dead in a plain undyed burial cloak, hood up, carved mourning mask, no visible face. Body leaning forward as if climbing, cloak frozen to the legs, ice over both hands and feet. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `unsung` — the Unsung

- **Tier:** full · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** RIME-only

```
Thin figure of clear and milky glacier ice in the shape of a hooded cloaked person with a smooth mask, no visible face, translucent, faint blue cracks inside, wool texture frozen in the ice. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```


## NPCs, the Bearer and Bearer armour sets (20)

### `bearer_traveller` — the Bearer: Traveller's coat (start)

- **Tier:** slice **(SLICE: generate first)** · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in a long grey wool coat with horn toggles, deep oat hood, smooth birch mask with woad-blue band, no visible face. Leather belt with a cow-horn fire-horn on the left hip and a gourd on the right hip. Wool leggings, turnshoes. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `bearer_oilskins` — the Bearer: Saltfell Oilskins

- **Tier:** slice **(SLICE: generate first)** · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in a dark oiled oilskin smock over grey wool, hood, smooth birch mask with woad-blue band, no visible face. Belt with cow-horn fire-horn on left hip, gourd on right hip. Wool leggings, sea-boots. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `ingra` — Ingra, Steward of Saltfell

- **Tier:** slice **(SLICE: generate first)** · **Size:** 1.7 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Broad older woman in oat wool dress, brown apron, keys and tally-stick on a belt at her left hip, lichen-yellow mask-band on a carved birch mask, headscarf and hood, no visible face. Rolled sleeves. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `brede` — Brede, fisherman

- **Tier:** slice **(SLICE: generate first)** · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Lean fisherman in a short oilskin smock over grey wool, knitted cap, plain pine mask with a badly tied woad-blue band, no visible face. Sea-boots, net-cord coiled on his left shoulder. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `bearer_barrow` — the Bearer: Barrow-wool

- **Tier:** region · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in heavy brown fulled wool cloak pinned at right shoulder, turf-cutter's leather apron, birch mask with woad band, deep hood, no visible face. Belt with fire-horn left hip, gourd right hip. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `bearer_icefur` — the Bearer: Ice-cutter's furs

- **Tier:** region · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in layered grey furs and felt hood, fur mittens tied on cords, birch mask with woad band, no visible face. Belt with fire-horn left hip, gourd right hip. Felt boots. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `hesk` — Hesk, travelling smith

- **Tier:** region · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Stocky smith in scorched leather apron over brown wool, heavy hood, soot-marked oak mask, no visible face. Bog-iron tongs and hammer hung on belt at right hip, bellows strapped to his back. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `aud` — Aud, barrow-keeper's widow

- **Tier:** region · **Size:** 1.6 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Small old woman in long grey wool mourning cloak, madder-red band on a worn birch mask, hood, no visible face. Bundle of heather tied at her left hip, sheepskin boots. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `ivo` — Ivo, the Ice-Cutter's grandson

- **Tier:** full · **Size:** 1.55 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Teenage boy in an oversized grey fur coat and felt hood, small pine mask with madder band, no visible face. Leather sledge harness coiled over his right shoulder, mismatched mittens. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `lusse` — Lusse, hall-singer

- **Tier:** full · **Size:** 1.7 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Tall woman in lichen-yellow and oat wool festival dress, embroidered belt, fur-trimmed hood, carved festival mask with a wide brow line, no visible face. Many plaited cords hang from her belt. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `linnet` — Linnet, collier

- **Tier:** full · **Size:** 1.65 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Young woman in soot-stained leather apron over oat wool, sleeves rolled, charcoal-black to both elbows, hood pushed back over a birch mask, no visible face. Plaited birch ring on her left hand. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `old_calder` — Old Calder, shepherd

- **Tier:** full · **Size:** 1.75 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Old shepherd in sheepskin cape and oat wool, deep hood, weathered birch mask, no visible face. Leather belt with tally-sticks at left hip, bare feet. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `maren_thaw` — Maren of Saltfell (THAW)

- **Tier:** full · **Size:** 1.75 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Woman in long grey and woad-blue layered wool, hood down over a smooth birch mask with woad-blue band, no visible face. A woad-blue sash across her torso, thrift flowers tucked in her belt. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `wren` — Wren

- **Tier:** full · **Size:** 1.05 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Small child of five in an oat wool smock and woad-blue hood, small birch mask, no visible face. Knucklebone pouch at her right hip, felt shoes. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `sefa` — Sefa, maskwright

- **Tier:** region · **Size:** 1.7 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Wiry travelling carver in brown wool and leather, wide hood, an unpainted mask, no visible face. A wooden frame on his back hung with a dozen blank carved masks, carving knives in a roll at left hip. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `bearer_hall` — the Bearer: Guest-garb of Tarnhall

- **Tier:** full · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in a quilted felt coat over iron mail shirt, lichen-yellow cuffs, fur cape, birch mask with woad band, deep hood, no visible face. Belt with fire-horn left hip, gourd right hip. Not fantasy armour plating. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `bearer_collier` — the Bearer: Collier's leathers

- **Tier:** full · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in soot-stained leather jerkin and apron over oat wool, hood, birch mask with woad band, no visible face. Belt with fire-horn left hip, gourd right hip. Leather gaiters. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `bearer_fleece` — the Bearer: Shepherd's fleece

- **Tier:** full · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in a heavy sheepskin cape fleece-out over oat wool, deep hood, birch mask with woad band, no visible face. Belt with fire-horn left hip, gourd right hip. Wrapped wool leg bindings. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `bearer_outsong` — the Bearer: Outsong robes

- **Tier:** full · **Size:** 1.8 m · **Rig:** biped · **Texture:** detailed · **State:** both states (shader handles frost)

```
Traveller in long undyed oat mourning robe and grey cloak, woad-blue sash, deep hood, Maren's birch mourning mask with woad band, no visible face. Belt with fire-horn left hip. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `bearer_child` — the Bearer as a child (memory)

- **Tier:** full · **Size:** 1.2 m · **Rig:** biped · **Texture:** detailed · **State:** THAW-only

```
Child of eight in a grey wool smock and oat hood, small birch mask with woad band, no visible face. A cow-horn fire-horn on a cord at the left hip, felt shoes. single character only, plain background, A-pose, arms slightly away from body, legs apart, empty hands. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```


## Signature weapons, shields and carried items (15)

### `hewing_blade` — Hewing Blade

- **Tier:** slice **(SLICE: generate first)** · **Size:** blade 0.85 m, total 1.0 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Straight single-edged long blade of black bog-iron with rust bloom and hammer marks, slight taper, short iron crossguard, grip wrapped in an old brown leather belt, iron disc pommel. Lying flat, blade pointing right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `saltfell_shield` — Saltfell Board Shield

- **Tier:** slice **(SLICE: generate first)** · **Size:** 0.8 m diameter · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Round shield of pine boards, faded woad-blue paint worn to bare wood, domed black bog-iron boss, rawhide edge stitched round, front facing camera. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `fostering_horn` — Fostering Horn

- **Tier:** slice **(SLICE: generate first)** · **Size:** 0.3 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Cream cow horn worn smooth, soapstone stopper with a small draught-hole, two black iron bands, braided leather hanging cord. A faint orange glow at the draught-hole. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `gourd` — Gourd

- **Tier:** slice **(SLICE: generate first)** · **Size:** 0.22 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Dried bottle gourd, tan and brown, wooden stopper, wrapped in a knotted cord net with a hanging loop, tally notches cut in the neck. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `mending_needle` — Netmender's Needle

- **Tier:** slice **(SLICE: generate first)** · **Size:** 0.4 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Long flat whalebone net-needle loaded with dark tarred twine, smooth cream bone with a forked tip, used as a short stabbing weapon, lying flat pointing right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `turf_spade` — Turfwright's Spade

- **Tier:** region · **Size:** 1.6 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Long-handled peat spade, ash handle silvered with age, T-grip at top, flat black bog-iron blade with a side wing, turf stains, lying flat blade right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `post_maul` — Post Maul

- **Tier:** region · **Size:** 1.3 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Heavy two-handed post-driving maul, oak head bound with two black iron rings, long ash haft, leather grip wrap, lying flat head right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `ice_auger` — Ice-Cutter's Auger

- **Tier:** full · **Size:** 1.5 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Long iron ice-auger used as a spear, spiral black iron bit, oak T-handle crossbar at the top, leather-wrapped shaft, lying flat bit right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `sealer_harpoon` — Sealer's Harpoon

- **Tier:** full · **Size:** 2.0 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Hunting harpoon, long ash shaft, barbed bog-iron head, bone foreshaft, coiled rawhide line tied below the head, lying flat head right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `feast_cleaver` — Host's Carving Cleaver

- **Tier:** full · **Size:** 0.7 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Broad heavy carving cleaver, black iron rectangular blade, carved oak handle with knotwork, iron ring at butt, lying flat blade right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `tarnhall_shield` — Tarnhall Hall Shield

- **Tier:** full · **Size:** 1.0 m diameter · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Large round hall shield of oak boards, lichen-yellow and brown painted quarters worn away, black iron boss and rim clips, front facing camera. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `hedging_bill` — Hedging Bill

- **Tier:** full · **Size:** 1.9 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Long-handled hedging billhook, hooked black iron blade with a back spike, long hazel haft, rawhide binding, lying flat blade right. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `shepherd_crook` — Fellcaller's Crook

- **Tier:** full · **Size:** 1.8 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Tall shepherd's crook staff, ash shaft, carved ram-horn crook at the top, iron ferrule, a braided wool cord with a small horn whistle tied below the crook. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `fellcaller_horn` — Calling Horn

- **Tier:** full · **Size:** 0.5 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Long curved ram's horn calling trumpet, cream and grey, carved non-letter knot bands, leather shoulder strap, side view. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `song_cord` — Linnet's Song-cord

- **Tier:** full · **Size:** 0.6 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Knotted cord of plaited oat and lichen-yellow wool, many knots of different sizes along its length, bone toggle at one end, laid in a loose coil. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```


## Landmark set pieces (20)

### `lm_hearthstone` — Hearthstone (generic)

- **Tier:** slice **(SLICE: generate first)** · **Size:** 1.6 x 1.0 x 0.5 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Household hearth: a single rectangular block of grey-green soapstone, carved knotwork border, worn hollow in the top, a kerb of dry-stone round it, cold grey ash. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_long_hearth` — the Long Hearth

- **Tier:** slice **(SLICE: generate first)** · **Size:** 12 x 1.4 x 0.6 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Very long household fire trench lined with soapstone kerb slabs, carved knot ends at both ends, an iron pot-crane at one end, cold ash and peat along its length. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_doorpost` — Longhouse door-post

- **Tier:** slice **(SLICE: generate first)** · **Size:** 3.2 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Tall carved oak door-post of a longhouse, deep abstract interlaced knotwork with no letters, a woad-blue painted band near the top, silvered weathered wood, iron hinge pins. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_mask_pegs` — Mask-peg board

- **Tier:** slice **(SLICE: generate first)** · **Size:** 2.4 x 1.2 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Pine wall board with a row of carved wooden pegs, eight adult carved birch masks with woad-blue bands hanging, two lower small pegs, one with a small child mask, one empty. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_brede_boat` — Brede's boat

- **Tier:** slice **(SLICE: generate first)** · **Size:** 7 m long · **Rig:** none · **Texture:** detailed · **State:** THAW-only

```
Clinker-built wooden fishing rowing boat, overlapping pine strakes, iron rivets, upswept carved stem and stern posts, two oars across the thwarts, coiled net in the bow, on log rollers. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `lm_frost_veil_net` — Frost veil (Saltfell)

- **Tier:** slice **(SLICE: generate first)** · **Size:** 4 x 4 m · **Rig:** none · **Texture:** detailed · **State:** RIME-only

```
Hanging curtain of fishing net mesh frozen solid into a flat wall, icicles hanging from every knot, translucent pale blue ice between the cords, cork floats frozen in. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `lm_tide_wall` — Frozen tide wall section

- **Tier:** slice **(SLICE: generate first)** · **Size:** 8 x 3 x 1.5 m · **Rig:** none · **Texture:** detailed · **State:** RIME-only

```
A breaking sea wave frozen solid into clear green-blue glass ice, curling crest, kelp and a lost oar trapped inside, shingle base. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `lm_standing_stone` — Lowe standing stone

- **Tier:** region · **Size:** 3.5 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Tall rough grey-green schist standing stone, lichen patches, a carved abstract interlace knot on one face, heather at the base. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_barrow_door` — Barrow turf door

- **Tier:** region · **Size:** 2.5 x 2.2 m · **Rig:** none · **Texture:** detailed · **State:** RIME-only

```
Entrance to a turf burial barrow, two upright stone jambs and lintel, a door of stacked turf sods propped half-open with a peat spade. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `lm_fish_kettle` — Kettle Fjord fish-kettle

- **Tier:** full · **Size:** 2.0 m · **Rig:** none · **Texture:** detailed · **State:** RIME-only

```
Huge black iron fish-boiling cauldron on three iron legs over a stone fire ring, iron ladle frozen standing upright in it. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `lm_sledge` — Ice sledge

- **Tier:** full · **Size:** 3.0 m long · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Long wooden dog-sledge, bent ash runners, rawhide lashings, a fur bundle tied on, traces trailing forward. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_hall_doors` — Tarnhall great doors

- **Tier:** full · **Size:** 5 x 6 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Pair of massive oak hall doors in a carved timber frame, interlaced knot carving, black iron strap hinges, a heavy oak bar across them. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_high_seat` — Tarnhall high seat

- **Tier:** full · **Size:** 2.5 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Carved oak high-seat chair with two tall carved posts, interlace knotwork, fur thrown over the seat, lichen-yellow painted bands. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_guest_post` — Guest-tally post

- **Tier:** full · **Size:** 3.0 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Oak post wound from top to bottom with hundreds of knots of plaited wool cord, lichen-yellow and oat, the last knots clumped together. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_charcoal_clamp` — Charcoal clamp

- **Tier:** full · **Size:** 4 m diameter · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Dome-shaped charcoal clamp of stacked split logs covered in turf and ash, a vent hole at the top, a ladder leaning on the side. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_hedge_gate` — Hedge gap and grave

- **Tier:** full · **Size:** 4 x 3 m · **Rig:** none · **Texture:** detailed · **State:** RIME-only

```
A gap in a thick laid thorn hedge with no gate, bent pleached stems, in the gap a low grass grave mound with a plaited birch ring. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `lm_sheiling` — Shepherd's sheiling

- **Tier:** full · **Size:** 4 x 3 x 3 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Small dry-stone summer hut with a turf roof, low timber door on the latch, a pair of old leather boots by the door. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_fold_cairn` — High Fold cairn

- **Tier:** full · **Size:** 2.5 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Tall dry-stone cairn by a stone sheep fold, grey-green stones, sheep tally sticks wedged between the top stones. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```

### `lm_wellhead` — the Wellhead stones

- **Tier:** full · **Size:** 8 m ring · **Rig:** none · **Texture:** detailed · **State:** RIME-only

```
Ring of seven old weathered standing stones around a round spring pool under a glacier lip, the pool frozen flat, flowers frozen into the ice. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `lm_maskwright_cart` — Maskwright's handcart

- **Tier:** region · **Size:** 2.2 m · **Rig:** none · **Texture:** detailed · **State:** both states (shader handles frost)

```
Two-wheeled wooden handcart with a pole frame, dozens of blank carved birch masks hung on pegs, wood shavings, a carving bench folded on top. single object only, plain background, no text, no lettering. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR
```


## Concept art: THAW / RIME pairs (14 images)

Image prompts for Studio's 2D generator. Used as lighting and layout targets only, never shipped. Same camera framing for each pair.

### `concept_saltfell_thaw` — Saltfell, THAW

- **Tier:** slice **(SLICE: generate first)** · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, shingle beach below a sea cliff, turf-roofed longhouse on the cliff shelf, boats drawn up on rollers, nets on racks, low amber sun on the horizon, smoke rising. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `concept_saltfell_rime` — Saltfell, RIME

- **Tier:** slice **(SLICE: generate first)** · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, the same beach and cliff, the tide frozen mid-surge into a glass wall, nets rigid with ice, blue-white light, snow falling, no smoke. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `concept_lowe_thaw` — the Lowe, THAW

- **Tier:** region · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, rolling heather hills with long turf barrow mounds, a road of standing stones, turf stacked to dry, larks, low golden sun. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `concept_lowe_rime` — the Lowe, RIME

- **Tier:** region · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, the same hills, every barrow door propped open, frozen white figures seated inside facing the road, cold fog, one barrow closed. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `concept_kettle_fjord_thaw` — Kettle Fjord, THAW

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, deep fjord between sheer cliffs, open water, black iron fish-kettles steaming on the shore, a trader's boat at a timber jetty, warm evening. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `concept_kettle_fjord_rime` — Kettle Fjord, RIME

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, the same fjord frozen wall to wall, boats visible trapped under clear ice, a single dark hole cut in the ice, blue haze. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `concept_tarnhall_thaw` — Tarnhall, THAW

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, a vast timber hall with a turf roof on a mountain tarn, causeway, doors open, firelight and crowd inside, amber evening. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `concept_tarnhall_rime` — Tarnhall, RIME

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, the same hall, doors barred, snow on the roof, inside a laid feast table with frozen seated figures, frost on every cup. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `concept_thornwold_thaw` — Thornwold, THAW

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, birch and pine forest clearing, smoking turf charcoal clamps, laid hedges along a drove-road, pollen in slanting sun. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `concept_thornwold_rime` — Thornwold, RIME

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, the same forest grown into walls of frozen thorn hedge forming a maze, one old pine at the centre, cold violet shade. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `concept_shepherds_reach_thaw` — Shepherd's Reach, THAW

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, high mountain pasture under a glacier, stone sheilings, flocks of sheep on green grass, a woman far off calling. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `concept_shepherds_reach_rime` — Shepherd's Reach, RIME

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, the same slope covered in frozen white sheep all facing one stone fold, glacier above, wind-blown snow. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```

### `concept_coldwell_thaw` — the Coldwell, THAW

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, a loud brown meltwater river under a glacier, flowers in the water, a ring of old standing stones, a woman holding a small child's hand. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, warm late-evening sunlit wood, faint woodsmoke patina
```

### `concept_coldwell_rime` — the Coldwell, RIME

- **Tier:** full · **Size:** 16:9 wide establishing shot · **Rig:** none · **Texture:** n/a (2D)

```
Wide establishing concept art painting, eye-level, the same river frozen solid, crowded with still white hooded figures facing upstream toward the stone ring and a giant seated figure. No people in the foreground, no text, no lettering, no gothic architecture, no stained glass, no candles. painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge
```
