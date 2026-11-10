# Saltfell performance pass (slice QA, 2026-11-08)

## How it was measured

- **Route log.** `tools/qa/fullslice_shots.sh` runs the full-slice test (`tools/test/fullslice_test.gd`) with a renderer (xvfb + Vulkan on llvmpipe, 1280x720, auto quality = High). With `--perf=PATH` it writes one row per route leg: the frame count, average and worst process time, the lowest FPS, the peak draw calls and where the camera stood for them, the peak objects, and the MultiMesh node count.
- **Probe.** `tools/qa/perf_probe.tscn` builds Saltfell with no characters, stands a camera at the route's six worst spots in THAW and in RIME, and prints the draw calls, objects and primitives at each. It is the before/after yardstick, because the poses are fixed.

```
xvfb-run -a godot --path . --rendering-driver vulkan --resolution 1280x720 \
  -- --scene=res://tools/qa/perf_probe.tscn --perf-out=/tmp/probe.json
```

**Caveat.** This machine has no GPU. llvmpipe draws about 1 frame a second at 720p, and other agents share the CPU, so the milliseconds below only rank the spots against each other. They are not frame budgets. Draw calls and primitives do not depend on the device, so those are the numbers to compare.

## Worst spots on the route (route log, before the prop ranges)

| Leg | Peak draw calls | Where (camera) | Peak objects |
|---|---|---|---|
| first rest (yard, at Ingra) | 2245 | (13, 22, -5), looking east over the yard and the cliff edge | 2697 |
| cliff path (from the boats, looking up) | 2181 | (-7, 1, 74), yaw 37 | 2507 |
| toggle (the Strand in THAW, end of route) | 1606 | (-5, 1, 74) | 2036 |
| gully (from the Salt House) | 1451 | (-26, 22, 21) | 2550 |
| release (in the hall) | 1267 | (1, 22, -31) | 1457 |
| boss fight | 994 | (2, 22, -31) | 1083 |

These peaks include the characters (the Bearer, Ingra, Brede, the frost-taken), their swing trails and the HUD. The worst views are wide views across the yard, where the houses, the racks, the turf veg chunks and the far terrain are all in frame together.

## Fixed (cheap wins)

| Change | Commit | Effect (probe) |
|---|---|---|
| Scatter MultiMeshes chunked into 32 m cells, each with its own origin and range (`src/world/scatter.gd`). Before this there was one area-wide MultiMesh per kind: it was never frustum-culled, and its 70 m range was measured from the middle of the area, so the Strand's rocks blinked out as you walked the beach. | ba04378 | Primitives drop by roughly half: yard at Ingra (THAW) 1.85 M → 0.68 M; the hall 1.90 M → 0.80 M; the cliff top 1.07 M → 0.41 M. Draw calls rise 2–8 % (more, smaller batches). MultiMesh nodes go from 225 to 390. |
| Sun shadow reach tiered by quality, `render/shadow_distance` 70 / 100 / 135 m (it was 135 m on every tier) (`src/world/env_rig.gd`) | b86b006 | The four splits spend their texels nearer the camera. Fewer far casters on Low and High. |
| Small kit props get a visibility range by footprint, `render/prop_ranges` (≤1.6 m out at 60 m; ≤4.5 m out at 120 m) | b7ef74a | −1 to −4 % draws at the boats and the Salt House. Saltfell has only 43 props, so this is mostly insurance for denser areas. |

Probe, draw calls / primitives (THAW):

| Pose | main (68e1fa6) | after |
|---|---|---|
| strand_landing | 88 / 475 k | 108 / 386 k |
| strand_boats | 632 / 618 k | 602 / 528 k |
| cliff_path_top | 213 / 1067 k | 229 / 412 k |
| yard_ingra | 556 / 1854 k | 600 / 684 k |
| yard_salt_house | 969 / 1369 k | 1001 / 936 k |
| longhouse_hall | 922 / 1905 k | 947 / 796 k |

RIME follows the same pattern; for example, longhouse_hall goes from 895 / 2258 k to 841 / 1071 k.

## Not done (next)

Where Saltfell's mesh instances come from, measured per owning script in RIME:

| Owner | Meshes | Visible at rest |
|---|---|---|
| Kit props and pieces (no script; primitive boxes and cylinders) | 261 | 214 |
| Terrain chunks (two LODs per chunk; one is drawn) | 161 | 161 |
| Spawners (16 frost-taken) | 96 | 21 |
| Hearthstones (3) | 18 | 18 |
| The boat-shed gate | 16 | 16 |
| The tide wall | 19 | 19 |

**Correction to the first pass:** the frost-taken are cheap. Each one is a single skinned mesh (the Oarsman has a second, for his oar) with no lights. Its HP bar and hit-flash quads stay hidden until they are used. The frost-shatter material is now shared per source material.

1. **Merge KitLib primitive pieces** into one mesh per material once their collision is built. A drying rack is 13 meshes, a hearth 6, a gate 16. This is the biggest draw-call lever left.
2. **Turf veg chunks** are 24 m with a 55 m range. In the open yard about 60 chunks are in view, and each costs a colour draw and a depth pre-pass draw. A 32 m chunk would cut the count by about 40 % with the same number of instances.
3. **Boss VFX.** The Netmender fight adds net VFX quads and ice ridges on every cast. Pool them if the boss frame shows up on real hardware.
4. **Measure on a GPU.** Run the same two tools on a real card before setting a frame budget. llvmpipe numbers cannot do that.
