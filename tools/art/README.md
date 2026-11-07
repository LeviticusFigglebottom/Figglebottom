# tools/art: the Rimeholt art pipeline

Every step from a Tripo project to a game-ready GLB is a script in this directory. The asset list is `manifest.json`. The design intent (sizes, prompts, acceptance) is in `docs/art/design/pilot.md`.

## Setup (once per session)

```bash
S=<session scratchpad>
uv venv -p 3.11 $S/bpyenv && uv pip install -p $S/bpyenv bpy==4.5.11   # headless Blender
BPY=$S/bpyenv/bin/python
apt-get install -y mesa-vulkan-drivers   # lavapipe, needed for Forward+ headless screenshots
```

The Tripo client (`client.mjs`) and its cookie live only in the session scratchpad. Never copy them into the repo.

## Flow

| Step | Command | Notes |
|---|---|---|
| 1. Concept/reference image | `node client.mjs tripo_image '{"prompt":..., "t_pose":true, "multiview":true}'` | Free on the Studio plan. Look at the image **before** spending on 3D. For characters, image-to-model is far more controllable than text. |
| 2. Generate | `tripo_generate_text` / `tripo_generate_image` / `tripo_generate_multiview` | 55 cr (detailed texture). The output is a ~1.9M-tri GLB at ~1 m, 4K base colour. It faces **+X**, so the manifest uses `yaw_deg: -90`. |
| 3. Preview | `tools/art/decompress.sh raw/x/raw.glb` then `$BPY tools/art/preview_render.py raw/x/raw_dec.glb out.png` | Cycles CPU, 4 views. Check fidelity before remesh. |
| 4. Remesh | `tripo_remesh {face_limit:10000, quad:true}` | 40 cr, gives ~18–20k tris with a baked normal map. Afterwards the project **only** downloads as FBX. |
| 5. Rig (characters) | `tripo_rig {check_only:true}` (free) then `tripo_rig {rig_type:"biped", spec:"mixamo"}` | 20 cr, 65 `mixamorig:` bones. |
| 6. Animate | `tripo_animate {preset:"walk"}` | 0 cr. `tripo_list_motions` lists presets. |
| 7. Fetch | `TRIPO_CLIENT=$S/tripo/client.mjs python3 tools/art/fetch_tripo.py` | Pulls `remesh.fbx`, `rigged.fbx` and `anims/*.fbx`. Animated GLB merging fails after a quad remesh ("not GLB"), so animations are merged in Blender instead. |
| 8. Process | `$BPY tools/art/blender_process.py [--only name]` | Manifest-driven. Scale to the design size; set origin and yaw; rename materials to `M_<name>` and textures to `T_<name>_<map>`; downscale textures; make walk/run clips in place; export a GLB with JPEG textures. |
| 9. Procedural kit | `$BPY tools/art/procedural/kit_procedural.py --out assets/models/kit` | Plain modular pieces (owner decision: Tripo is for hero assets only). Seeded and deterministic. |
| 10. Import + look | `godot --headless --path . --import`, then `xvfb-run ... res://scenes/sandbox/art_pilot.tscn -- --shots` | Writes `docs/screens/art_pilot_*.png`. |

## Conventions the scripts enforce

- **Scale:** `target.height` (characters), `target.width` (walls, props, areas) or `target.length` (weapons), in metres.
- **Origin:** bottom centre for kit, props and characters. For weapons, the **grip centre** is at the origin, the blade points +Y and the edge faces +Z. `blender_process.py` finds this with PCA: the long axis, the grip as the thick end, the guard as the widest slice, and the edge as the thin side.
- **Characters:** scale, yaw and the floor offset live on the armature object, not applied to it. Applying them would break the root-motion keys. Every clip is one NLA track, and that becomes one glTF animation (`idle`, `walk`, `run`, `slash`, `hit`, `defeat`). Clips listed in `in_place` have the horizontal Hips drift and offset removed.
- **Per-asset overrides (manifest):** `grip_from_pommel` (m) for guardless blades, where the widest slice is the pommel cap; `target.fit {x,y,z}` for set pieces whose generated proportions miss the design sheet (the Long Hearth, the boat, the tide wall); `origin: "center"` for strapped items such as the shield; `root_bone` for non-mixamo rigs (the quadruped roots at `tripo::Root`).
- **Quadruped clips** key the armature object's own transform; `merge_anims` strips those keys so the armature keeps the scale and yaw set here.
- **Masks:** steer reference images with `gpt_image_2.5_sunburst` and "a perfectly flat oval board of pale birch wood like a small shield ... two small round eye holes and one carved horizontal groove ... no nose, no mouth". gemini_3_pro keeps drifting to carved faces.
- **Bone names:** Godot sanitises `mixamorig:RightHand` to `mixamorig_RightHand`, so match bones by suffix. See `src/debug/art_pilot.gd` `_attach_blade()`, which also builds the grip frame from the rest pose (hand→Middle1 = fingers, Thumb1 = blade direction).

## Collision (made on import)

`blender_process.py` and `kit_procedural.py` name the exported mesh node with a Godot import suffix:

| Manifest `collision` | Node name | Godot builds |
|---|---|---|
| `trimesh` | `<name>-col` | StaticBody3D + ConcavePolygonShape3D (walls, area chunks) |
| `convex` | `<name>-convcol` | StaticBody3D + ConvexPolygonShape3D (props, hearthstone) |
| `null` | `<name>` | nothing (characters use gameplay capsules) |

No hand-edited `.import` files are needed. Godot also generates LODs on import by default (`meshes/generate_lods`), so there is no separate LOD1 export.

## Gotchas found in the pilot

- Tripo GLBs use `EXT_meshopt_compression`, so run `decompress.sh` (gltf-transform) before Blender.
- The Blender FBX operator can fail headless. `blender_common.import_any()` calls `io_scene_fbx.import_fbx.load()` directly with a stub operator.
- Never name a bpy script after a stdlib module (`inspect.py`). bpy initialises twice and aborts.
- Godot's glTF importer ignores `COLOR_0` for albedo, so procedural vertex tints are baked into a texture (Cycles EMIT bake).
- Without `mesa-vulkan-drivers`, Godot silently falls back to the Compatibility renderer, which has no volumetric fog or SSAO.
- The image content filter rejects words like "drowned body"; phrase it gently ("pale sleeping man, her husband").
- `raw/.gdignore` keeps Godot from importing multi-million-tri raw files.
