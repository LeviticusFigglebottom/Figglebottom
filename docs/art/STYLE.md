# Rimeholt art direction

There is one world, and every asset has to look like it was made by the same hands.

## Key phrases (put these into every Tripo prompt)

**Every prompt** ends with this STYLE TAIL, verbatim:

> `painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR`

Add the state tail when the asset only exists in one state:

- **THAW-only:** `warm late-evening sunlit wood, faint woodsmoke patina`
- **RIME-only:** `crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge`

**Exclusions:** Studio has no negative prompts, so state them positively:

- `no text, no lettering`
- `plain background`
- `single object only`
- `no gothic architecture, no stained glass, no candles` (keeps us away from the source's look)
- `not fantasy armour plating` (keeps us away from generic high-fantasy)

## Materials palette

| Material | Look | Colour |
|---|---|---|
| Timber | Adzed and split pine and oak. Carved knotwork post-ends that are abstract, interlaced and **non-runic** (no letters). | Brown-grey, silvered where weathered |
| Turf and stone | Turf roofs. Dry-stone walls of grey-green schist. Soapstone hearths. | Grey-green |
| Textiles | Undyed wool (oat, grey, brown). Woad blue, madder red and lichen yellow are used sparingly, as household colours. | Oat, grey, brown; accents in blue, red, yellow |
| Metal | Black wrought iron and bog-iron with a rust bloom. **No polished steel plate.** | Black, rust |
| Horn and bone | Drinking horns, horn window panes, bone toggles. | Cream |

## Characters

- **Proportions:** grounded and heavy. Layered garments with a big silhouette read: cloaks, hoods, fur collars.
- **Faces are masked.** Every humanoid wears a carved wooden mourning mask or a deep hood with a mask. Masks are smooth, expressive and minimal (two eye holes and a carved brow line), different for each household. This hides the lack of facial animation.
- **Frost-taken** are the same people, frozen. Their masks and shoulders are rimed white, they have icicles at the hems, and ice has grown over their hands, which become weapons. They have *no gore*: they read as sad and stuck, not monstrous.
- **Holdfasts** are big (2.6–4 m). Each is a person fused with the thing they could not let go of. Example: the Netmender is a hunched woman wrapped in a frozen fishing net that holds a drowned figure against her back.
- **Fused parts (Tripo gotcha):** generate weapons, shields and lanterns as **separate assets** and attach them to hand bones. Cloaks are moulded tight to the body so they bend acceptably with the spine.

## Environment kit

- **Grid:** 4 m (the convention carried over from the source). Pieces are named `kit_<family>_<piece>_<size>`. Origins sit at the snap point: bottom centre for floors and walls, base centre for props.
- **Pilot kit (tier 0→1):** longhouse wall 4 m, longhouse wall with door, roof bay, carved post, hearthstone, dry-stone wall 4 m, plank floor 4 m, steps, fish-drying rack, barrel, sea-chest, turf mound.
- **Detail:** silhouette first. Detail comes from the baked normal map after remesh (10k-face quad target).

## Lighting and mood (carried from the source, translated)

| | THAW | RIME |
|---|---|---|
| Sun | Low amber (about 1.0, .78, .52), long shadows | Blue-white (about .74, .84, 1.0) |
| Atmosphere | Golden volumetric haze, pollen motes | Denser cold fog, falling snow and ice glitter |
| Shader branch | Warm sheen on wood | Hoarfrost crust on top-facing surfaces, desaturated |

The silhouette, the mood and how far the fog extends stay the same between the two states, so the player always knows *where* they are.

## UI

- **Palette:** bone-white and coal-ember orange on near-black.
- **Type:** a sturdy humanist serif.
- **Ornament:** frame corners use abstract knot ornaments. Never runes or letters.
