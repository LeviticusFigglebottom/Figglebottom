# THAW lighting under the cliffs (gpu/thaw-light): before and after

**Before** is main a6a45f6; **after** is this branch. Both are real GPU (RX 9070 XT) at q2, 1920x1080, HUD off, with the gallery v4 cameras. RIME is shot too, to show that it does not change.

## Cause: authored, made worse on the real GPU
- The lavapipe shot of the Kettle road (`docs/screens/poi_kettle_kf_road_turn_after.png`, THAW) is already dark, at mean luma 21/255 against 59 in RIME. So the darkness comes from the data, not the GPU.
- At q2, SDFGI and the volumetric fog make it darker still: 4/255 on the GPU.
- **The data:**
  - The THAW sun stood only 10–22° up over deep north–south cuts.
  - The shadowless sky fill (a steep top-down light, `env_rig.gd` `sky_fill`) sat at 0.95–1.0.
  - The THAW ground palettes are dark (Kettle path 0.11, shingle 0.15).
  - The cut floors got almost no direct light.
- **Thornwold:** the yellow wash is its THAW volumetric fog: density 0.009, in yellow-green (0.66, 0.70, 0.50).

## The change: data only, `data/biomes/<area>.json` `env.thaw`. RIME untouched
| area | key | before | after |
|---|---|---|---|
| kettle_fjord | sun_rot | (area's -13, -96) | -34, -96 |
| kettle_fjord | fill_energy / ambient_energy | 0.95 / 1.15 | 2.0 / 1.6 |
| tarnhall | sun_rot | -22, -110 | -36, -110 |
| tarnhall | fill_energy / ambient_energy | 1.0 / 1.3 | 2.0 / 1.6 |
| thornwold | sun_rot | -22, -75 | -30, -75 |
| thornwold | sun_color | 1.0, 0.89, 0.71 | 1.0, 0.92, 0.80 |
| thornwold | vol_density | 0.009 | 0.0045 |
| thornwold | fog_color | 0.66, 0.70, 0.50 | 0.72, 0.74, 0.68 |

## Mean luma, 0–255
| view | before | after | RIME before → after |
|---|---:|---:|---:|
| biome_kettle_fjord | 118 | 142 | 117 → 117 |
| biome_tarnhall | 90 | 115 | 119 → 119 |
| biome_thornwold (the wash) | 151 | 135 | 116 → 116 |
| poi kettle: the far landing | 31 | 51 | 132 → 132 |
| poi tarnhall: tarnhall | 35 | 43 | 170 → 170 |
| poi tarnhall: tarn causeway | 18 | 29 | 113 → 113 |
| poi thornwold: the notch | 71 | 85 | 114 → 114 |
| poi kettle: the kettle road | 4 | 7 | 88 → 88 |

## Still open
- **The Kettle Road cut is still near-black** in THAW (7/255).
  - Part of that is my generated camera, a metre from a shaded slope.
  - Part is the cut itself: a slope facing away from both the sun and the top-down fill.
  - More global fill would over-brighten the open fjord. This one wants a local fix, either a fill light or a brighter path palette in the cut, or the art/biomes owner's eye.
- **The Tarn Causeway** reads now but is still dim (29/255). One more step of fill (2.0 → 2.5) would lift it, at the cost of flatter cliffs.
- `_sheet_thaw_before_after.jpg` shows every THAW pair side by side.
