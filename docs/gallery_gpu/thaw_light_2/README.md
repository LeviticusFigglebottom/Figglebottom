# THAW lighting, second pass (gpu/thaw-light-2): before and after

**Before** is main 86128b6, which already includes the first pass; **after** is this branch. Both are real GPU (RX 9070 XT) at q2, 1920x1080, HUD off, with the gallery v4 cameras, in both states. The lead's rough check is mean luma ≥ 70 and under 5% of pixels below 10.

## What changed
- **`area_builder` `shade_fills`:** a soft, shadowless, non-specular `OmniLight3D` per entry. Attenuation is 0.6, and it fades out between 80 and 100 m. Each is tagged by state and built only into its layer.
- **The generators write them, THAW only:**
  - `gen_kettle.py`: 11 along the Kettle Road (`terrain_lowe.KETTLE_ROAD`, at each bend and between) and 2 at the Far Landing.
  - `gen_tarnhall.py`: 10, on the upper Tarn Steps, the causeway, the hall porch and the board on the shore walk.
  - `gen_lowe.py`: 2, at the Last Mound's door and its board.
  - All are 4 m up, range 18 m, energy 3.0, colour (0.86, 0.90, 1.00).
  - Each generator reproduces its committed file exactly before the change.
- **Biome data, `env.thaw`:**
  - THAW exposure: Kettle 0.98 → 1.10, Tarnhall 1.12 → 1.22.
  - Thornwold: ambient 1.2 → 1.5, fill 0.85 → 1.15.

## Mean luma and % below 10, after (| before)
```
biome_kettle_fjord_rime                      mean  117.3  <10   0.0%   | before  117.3  <10   0.0%
biome_kettle_fjord_thaw                      mean  152.1  <10   0.0%   | before  142.0  <10   0.0%
biome_tarnhall_rime                          mean  119.2  <10   0.0%   | before  119.2  <10   0.0%
biome_tarnhall_thaw                          mean  121.7  <10   0.0%   | before  115.1  <10   0.0%
poi_kettle_fjord_the_far_landing_rime        mean  131.8  <10   0.0%   | before  131.8  <10   0.0%
poi_kettle_fjord_the_far_landing_thaw        mean   75.6  <10   0.0%   | before   51.4  <10   0.0%
poi_kettle_fjord_the_kettle_road_rime        mean   88.2  <10   0.0%   | before   88.3  <10   0.0%
poi_kettle_fjord_the_kettle_road_thaw        mean   66.1  <10   0.1%   | before    7.2  <10  83.9%
poi_lowe_barrows_the_last_mound_rime         mean  138.7  <10   0.0%   | before  138.7  <10   0.0%
poi_lowe_barrows_the_last_mound_thaw         mean   64.4  <10   0.1%   | before   37.8  <10   5.3%
poi_tarnhall_tarnhall_rime                   mean  169.7  <10   0.0%   | before  169.8  <10   0.0%
poi_tarnhall_tarnhall_thaw                   mean   78.6  <10   0.2%   | before   43.3  <10  24.9%
poi_tarnhall_the_tarn_causeway_rime          mean  113.2  <10   0.0%   | before  113.3  <10   0.0%
poi_tarnhall_the_tarn_causeway_thaw          mean   68.2  <10   0.0%   | before   29.1  <10  16.1%
poi_thornwold_the_hedge_rime                 mean  119.6  <10   0.2%   | before  119.6  <10   0.2%
poi_thornwold_the_hedge_thaw                 mean   68.1  <10   6.7%   | before   61.7  <10   8.7%
poi_thornwold_thornwold_rime                 mean  121.3  <10   0.0%   | before  121.2  <10   0.0%
poi_thornwold_thornwold_thaw                 mean   70.6  <10  10.7%   | before   64.4  <10  12.3%
```
- **RIME:** unchanged. Per pixel, after against before differs by no more than two runs of main differ from each other: falling snow lands differently each run. The Kettle Road RIME, for example, has a mean difference of 0.05 in both comparisons.
- **Cost:** Kettle THAW at q1 measured 213/214 FPS on main and 210/206 on the branch. GPU 4.42 → 4.49 ms.
- **Tests:** smoke 11/0, look5 25/0, kettle 34/0, tarnhall 38/0, lowe 25/0.

## Against the target
- **At or over 70:** Far Landing 75.6, Tarnhall 78.6, Thornwold 70.6.
- **Just under:** the Tarn Causeway 68.2, the Kettle Road 66.1 (it was 7.2 with 84% black), the Last Mound 64.4, the Hedge 68.1.
- **Very dark pixels:** every cut view is at 0.2% or less below 10.
- **Thornwold's canopy** keeps 7–11% of pixels below 10. That is leaf shadow under the trees, and in `thornwold_thornwold` my camera has a branch at the lens. To lift it further, its leaves' own shade, or a canopy fill, is the next step.
- **The other regions' THAW under overhangs:**
  - From the gallery v4 THAW set: Saltfell and Coldwell are at 0% below 10 and Shepherd's Reach at 0%, so nothing there needs a fill.
  - Lowe's Last Mound was the one dark spot, and it is fixed above.
