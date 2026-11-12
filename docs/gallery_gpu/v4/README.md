# Gallery v4: real-GPU re-shoot of main at a6a45f6 (re-shot on a fully imported tree)

These shots were taken on 2026-11-12 (second pass: every .glb imported and every extracted texture present, no script errors) on an RX 9070 XT at quality 2, 1920x1080, with the HUD off for world views, using `tools/gallery_gpu.sh`. Each shot is its own process: 2400 frames with the camera placed 600 frames before capture. Cameras are in `views.txt`, in the gallery_gpu VIEWS format.

| set | files | cameras |
|---|---|---|
| POIs, all 7 regions | `poi_<area>_<place>_{thaw,rime}` | One per wayside board: 6 m from the board towards the area centre, eye height, looking at the board. Generated, not hand-placed. |
| Biome sheets | `biome_<area>_{thaw,rime}` | Each region's v2 vista: 26 m up, behind the start. |
| Saltfell cliff top at the start | `saltfell_cliff_top_start_*` | The v2 eye-start camera. |
| The Strand shore (rowboats, driftwood) | `saltfell_strand_shore_*`, `poi_saltfell_steading_the_strand*` | Hand-placed over the shingle. |
| Journal and Map | `ui_journal`, `ui_map`, `ui_map_zoom` | `--shot-stage=journal / map / map_zoom`, THAW. |
| Weapons in hand | `weapon_{torch_lit,torch_unlit,spear,greatblade,bow}_{thaw,rime}` | `--shot-stage=bearer_light1 --shot-weapon=<w>` (the torch with `--shot-torch=lit/unlit`), and `bearer_bow` for the bow. |

## What looks wrong on real hardware
1. **Very dark in THAW under the cliffs.**
   - `poi_kettle_fjord_the_kettle_road_thaw` is almost black (mean luma 4/255). This matches the note in INBOX_poi_b.
   - `poi_tarnhall_the_tarn_causeway_thaw` is at 18/255. `poi_tarnhall_tarnhall_thaw` and `poi_kettle_fjord_the_far_landing_thaw` are also very dark.
   - The RIME versions of the same places read well.
2. **`biome_thornwold_thaw`** is washed in a strong yellow fog: no depth, and the canopy is lost.
3. **Weapons:**
   - The THAW and RIME stages now work, with no title card.
   - `weapon_torch_unlit_*`: the swing still draws a bright orange streak at the head of the put-out brand. The head flame and its light are gone, as they should be, but the swing trail keeps the lit brand's fire colour, so the swing reads as burning. Compare with `weapon_torch_lit_thaw`.
   - `weapon_greatblade_thaw`: the swing trail is a blown-out white slab against the dusk sky. In RIME it reads as it should.
4. **Fixed in this pass:**
   - The first pass printed `instantiate on a null value` and was missing some hero props, because the tree was only partly imported.
   - This pass is on a fully imported tree. No script errors were printed.
5. **Camera faults (mine, from the generated rule), not game bugs:**
   - `poi_shepherds_reach_shepherd_s_reach` faces a rock wall.
   - `poi_lowe_barrows_the_lowe_thaw` and `poi_thornwold_thornwold_thaw` have grass or a branch against the lens.
