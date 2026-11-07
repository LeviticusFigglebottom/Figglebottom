# Art pilot: design sheet

**Status:** pilot (tier 0 to 1). **Owner:** art pipeline. **Ledger:** `docs/art/TRIPO_LEDGER.md`. **Provenance:** `assets/PROVENANCE.md`.

**Owner update during the pilot:** Tripo is reserved for **hero assets**: characters, enemies, Holdfasts, signature weapons, landmark set-pieces such as the Hearthstone, and area concept art. Plain kit pieces (walls, dry-stone and racks) are **procedural**: `tools/art/procedural/kit_procedural.py` is a Blender bpy script with the same naming, origins and grid as Tripo pieces.

## Conventions (apply to every asset)

| Item | Rule |
|---|---|
| Units | 1 Godot unit = 1 m. Y up, character faces +Z (glTF/Godot forward). |
| Origin | Walls and floors: bottom centre of the snap edge. Props: base centre. Characters: between the feet. |
| Weapon origin | The grip centre (where the fist closes) is at the origin. The blade points **+Y** and the edge faces **+Z**. Attach under a `BoneAttachment3D` on `mixamorig:RightHand`. Any per-rig correction lives on a child `Node3D` offset, not in the GLB. |
| Size | Rescale exactly to the design size in `tools/art/manifest.json`, using height for characters and width for walls. |
| Budget | Hero characters: about 18–20k tris after a 10k-quad remesh, 2K textures. Props: 10k-quad remesh, 1K textures. Each GLB must be no more than about 8 MB. |
| Materials | Rename to `M_<asset>` (with `_0`, `_1` suffixes if there are more than one). |
| Collision | Created on import by `tools/art/godot_import/`: a generated `.import` sets `physics/shape_type` (trimesh for walls, convex for props). Characters have no mesh collision; gameplay uses capsules. |
| Prompt tails | The STYLE TAIL is added verbatim to every prompt, plus a state tail where one applies, plus the positive exclusions from `STYLE.md`. |

**STYLE TAIL:** `painterly realistic northern folk craft, hand-adzed timber, dry-stone, wool and felt, wrought iron, horn and soapstone, weathered and lived-in, muted earthy palette, game asset, PBR`

**EXCL:** `no text, no lettering, plain background, single object only, no gothic architecture, no stained glass, no candles, not fantasy armour plating`

## Concept art (Tripo text-to-image)

| id | Purpose | Prompt summary | Acceptance |
|---|---|---|---|
| concept_saltfell_yard_thaw | Mood target for Saltfell yard in THAW | A turf-roofed stave longhouse steading on a sea-cliff shelf above a fjord, with dry-stone walls, fish racks and a soapstone hearth, at the last midsummer evening under a low amber sun. Full text is in the ledger and provenance. | 16:9. Reads as northern folk craft, not gothic. No text or runes. |
| concept_saltfell_yard_rime | The same yard in RIME | The same composition, frozen, with hoarfrost, blue-violet fog and still masked figures. | It is recognisably the same place: same silhouette, different mood. |

## Environment kit

| Asset | Source | Real size (m) | Origin | Collision | Acceptance |
|---|---|---|---|---|---|
| `kit_hearthstone` | **Tripo** (landmark, rest site) | 1.6 W × ~1.1 H × ~1.2 D | base centre | convex | Reads as a household hearth ring of soapstone with an upright stone back slab. Low and wide. No candles, letters or altar look. Lies flat on Y=0. |
| `kit_longhouse_wall_4m` | procedural | 4.0 W × 3.0 H × 0.25 D | bottom centre | trimesh | Vertical split-timber staves on a sill beam with a head beam. Silvered brown-grey. Tiles seamlessly at 4 m. |
| `kit_drystone_wall_4m` | procedural | 4.0 W × 1.4 H × ~0.7 D (tapered) | bottom centre | trimesh | Grey-green stacked flat schist stones, battered profile, capstones. Tiles at 4 m. |
| `kit_drying_rack` | procedural | 3.0 W × ~2.2 H × ~1.2 D | base centre | convex | A-frame poles, crossbars and hanging split fish. Silhouette first. |

**kit_hearthstone prompt:**
`a low round household hearth ring built of fitted grey-green soapstone blocks around a shallow ash pit, with one tall flat upright soapstone back slab behind it carved with a simple abstract interlaced knot border, cold grey ash and a few charred logs inside, wide and low, sitting on flat ground, ` + STYLE TAIL + `, ` + EXCL

## Characters

### Rimewalker (enemy, frost-taken)

| Item | Value |
|---|---|
| Purpose | The base Saltfell enemy: an ordinary villager who froze waiting by the dead. Sad, stuck and heavy. |
| Size | 1.80 m standing height (the rigged bind pose is scaled to this). |
| Pipeline | concept T-pose image (tripo_image, `t_pose`) → image-to-model (v3.1, detailed) → remesh (quad 10k) → rig (biped, mixamo) → animate presets `idle`, `walk`, `run`, `slash`, `hit_to_body_01`, `defeat_02` → download animated GLB with all clips → `blender_process.py` → `assets/models/enemies/rimewalker.glb` |
| Prompt | `full body game character of a frost-taken villager standing in a T-pose, arms straight out to the sides, a hooded undyed oat-grey wool cloak moulded close to the body, belted wool tunic, wool leg wraps and turnshoes, face covered by a smooth carved wooden mourning mask with two eye holes and a carved brow line, mask and shoulders rimed white, both hands encased in thick grown blue-white ice like clubs, short icicles hanging from the cloak hem, empty hands holding nothing, sad and still not monstrous, ` + STYLE TAIL + `, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge, ` + EXCL |
| Acceptance | Separate legs and arms, clear in T/A-pose. Mask, not face. Ice hands. Nothing held. Rig pre-check passes as biped. Walk plays without the cloak tearing badly. No more than ~20k tris. GLB no more than 8 MB. |

### The Netmender (Holdfast, Saltfell)

| Item | Value |
|---|---|
| Purpose | The tier-1 Holdfast: an old netmaker who would not let her drowned husband go. Huge, hunched, sorrowful. |
| Size | 3.2 m standing height, hunched. |
| Pipeline | concept T/A-pose image → image-to-model (v3.1, `extreme` texture if it clearly helps) → remesh 10k → **rig check_only (free)** → if biped is ok: rig + animate `idle`, `walk`, `slash`, `hit_to_body_01`, `defeat_02`. Otherwise she stays static. |
| Prompt | `full body game character of a giant hunched old woman standing in an A-pose, arms held out and down from the body, layered heavy undyed wool shawls and skirts in grey and brown, face covered by a smooth carved wooden mourning mask, a huge frozen fishing net wrapped around her shoulders and back, the net holding the pale curled figure of a drowned man against her back, long bony hands, all rimed with white frost and icicles, sorrowful and heavy not monstrous, ` + STYLE TAIL + `, crusted with white hoarfrost and grown ice, frozen solid, pale blue-white rime on every edge, ` + EXCL |
| Acceptance | It reads at a glance as a hunched woman with a figure bound to her back. Legs are separable for a rig (or the check fails gracefully). Mask, no gore. No more than ~20k tris. GLB no more than 8 MB. |

## Weapon

### hewing_blade

| Item | Value |
|---|---|
| Purpose | The first weapon family: a long single-edged seax. Used as a test attachment on the rimewalker's right hand. |
| Size | 0.95 m overall: blade about 0.68 m, grip and pommel about 0.27 m. |
| Orientation | The grip centre is at the origin, the blade points +Y and the edge faces +Z (the processing script handles this; see Conventions). |
| Prompt | `a single long single-edged iron seax-style hewing blade lying straight, broken-back blade of black wrought iron with a faint pattern-welded sheen and rust bloom, straight spine, a short iron guard plate, a grip of dark wood with banded horn and a cream horn pommel cap, simple and heavy, ` + STYLE TAIL + `, ` + EXCL |
| Acceptance | Single-edged. No crossguard-sword look. Horn and wood grip visible. Long axis is detectable for auto-orient. No more than ~10k tris, 1K textures. |

## Results (2026-11-07)

| Asset | Size (m) | Tris | GLB | Textures | Acceptance |
|---|---|---|---|---|---|
| kit_hearthstone | 1.60 × 1.60 × 1.19 | 20,145 | 1.4 MB | 1K | Pass. A soapstone ring with an iron band and an upright slab with an abstract interlace border. The slab leans slightly. |
| kit_longhouse_wall_4m (proc) | 4.0 × 3.0 × 0.29 | 1,156 | 0.2 MB | 1K baked | Pass |
| kit_drystone_wall_4m (proc) | 4.0 × 1.41 × 0.78 | 9,384 | 0.9 MB | 1K baked | Pass |
| kit_drying_rack (proc) | 3.2 × 2.3 × 1.19 | 2,476 | 0.4 MB | 1K baked | Pass. The fish are stylised. |
| hewing_blade | 0.95 long, grip at origin, +Y | 10,263 | 0.8 MB | 1K | Mostly. It is single-edged with a horn pommel, but has a round disc guard (less seax-like). |
| rimewalker | 1.80 tall | 18,350 | 4.9 MB | 2K | Pass. It has 6 clips (idle, walk, run, slash, hit, defeat), with walk and run in place. The mask is a carved face-mask, a bit naturalistic. |
| netmender | 3.20 tall | 19,500 | 5.4 MB | 2K | Pass. The husband is carried in the net on her back. The rig check passed and she has 5 clips. Her mask reads more as an old face than as carved wood. |

Screens: `docs/screens/art_pilot_{overview,yard_eye,hearthstone,rimewalker,blade,netmender,kit}.png`. Area experiment: `area_experiment.md`.
