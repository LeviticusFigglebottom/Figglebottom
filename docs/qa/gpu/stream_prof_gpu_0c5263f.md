### Crossing into each area, made ready ahead (streamed)

| area | nodes | made ready, cold cache ms | made ready, warm cache ms | black, cold ms | black, warm ms | swap frame ms | worst frame, cold ms | worst frame, warm ms | next worst, warm ms | what the worst frame held (warm) | nav bake thaw/rime, cold ms (background) | nav from cache, warm | sync phases |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| saltfell_steading | 3837 | 17352 | 1961 | 1495 | 460 | 5.1 | 131.4 | 48.7 | 40.4 | graft: what acts 49;  | 196 / 196 | [true, true] | none |
| lowe_barrows | 2267 | 1459 | 1063 | 878 | 373 | 6.9 | 42.3 | 35.3 | 30.4 | graft: what acts 33; free: old area 3;  | 215 / 233 | [true, true] | none |
| kettle_fjord | 2001 | 1922 | 1128 | 624 | 403 | 6.8 | 58.8 | 52.4 | 36.9 | graft: what acts 50; free: old area 3;  | 133 / 163 | [true, true] | none |
| tarnhall | 3093 | 1501 | 1194 | 744 | 470 | 5.7 | 51.8 | 49.3 | 32.0 | graft: what acts 49;  | 127 / 176 | [true, true] | none |
| thornwold | 6487 | 1835 | 1106 | 795 | 393 | 7.7 | 39.7 | 35.7 | 23.9 | graft: what acts 33; free: old area 3;  | 222 / 241 | [true, true] | none |
| shepherds_reach | 2747 | 14793 | 912 | 815 | 790 | 8.0 | 97.9 | 80.6 | 33.2 | graft: what acts 78; free: old area 3;  | 238 / 244 | [false, false] | none |
| coldwell | 1726 | 1211 | 833 | 867 | 326 | 5.6 | 35.2 | 40.1 | 15.3 | graft: what acts 37; free: old area 3;  | 465 / 458 | [true, true] | none |

### Freeing the area left, a rest, the turn to RIME (warm pass): worst main-thread frame, ms of work

| area | foes raised | free: worst frame ms | free: frames | rest: worst frame ms | turn to RIME: worst frame ms | what it held |
|---|---:|---:|---:|---:|---:|---|
| saltfell_steading | 19 | 2.5 | 6 | 5.1 | 6.8 | flip: apply_state 1.7; flip: save 0.7; respawn: foes 4.5;  |
| lowe_barrows | 12 | 2.8 | 17 | 6.1 | 6.8 | flip: apply_state 1.0; flip: save 0.7; respawn: foes 5.2;  |
| kettle_fjord | 15 | 6.6 | 13 | 4.6 | 7.1 | flip: apply_state 1.5; flip: save 0.7; respawn: foes 4.9;  |
| tarnhall | 17 | 2.9 | 6 | 5.5 | 9.4 | flip: apply_state 2.7; flip: save 0.7; respawn: foes 6.1;  |
| thornwold | 10 | 2.8 | 11 | 5.7 | 11.2 | flip: apply_state 3.8; flip: save 0.8; respawn: foes 6.6;  |
| shepherds_reach | 9 | 2.6 | 22 | 7.6 | 8.5 | flip: apply_state 1.9; flip: save 0.8; respawn: foes 5.8;  |
| coldwell | 8 | 6.7 | 13 | 5.6 | 8.4 | flip: apply_state 1.4; flip: save 0.7; respawn: foes 6.3;  |

### The dearest single grafts of what acts, and the dearest single flush, main-thread ms

| area | cold | warm |
|---|---|---|
| saltfell_steading | frost_veil @Node3D@821 131.1; net_floor @Node3D@830 100.0; hearthstone @Node3D@801 99.5; drawbridge @Node3D@833 39.8; drag_furrow @Node3D@832 10.7; (dearest flush of the worker's commands: 92.3 ms, after water, hazards) | frost_veil @Node3D@16813 48.5; drawbridge @Node3D@16825 37.9; shortcut_gate @Node3D@16795 4.7; pickup @Node3D@16835 2.8; hearthstone @Node3D@16794 2.7; (dearest flush of the worker's commands: 5.0 ms, after water, hazards) |
| lowe_barrows | drawbridge @Node3D@2930 37.2; frost_veil @Node3D@2923 34.4; pickup @Node3D@2940 6.7; pickup @Node3D@2931 6.0; pickup @Node3D@2941 5.1; (dearest flush of the worker's commands: 8.2 ms, after houses) | frost_veil @Node3D@18912 32.6; drawbridge @Node3D@18919 25.8; pickup @Node3D@18920 7.1; pickup @Node3D@18930 3.8; hearthstone @Node3D@18891 2.9; (dearest flush of the worker's commands: 2.4 ms, after houses) |
| kettle_fjord | god_rays @Node3D@4982 53.8; frost_veil @Node3D@4974 31.0; pickup @Node3D@4985 10.7; shortcut_gate @Node3D@4847 5.3; hearthstone @Node3D@4845 2.7; (dearest flush of the worker's commands: 7.1 ms, after houses) | god_rays @Node3D@20971 46.8; frost_veil @Node3D@20963 34.2; pickup @Node3D@20974 7.9; shortcut_gate @Node3D@20836 3.9; hearthstone @Node3D@20835 3.5; (dearest flush of the worker's commands: 5.1 ms, after houses) |
| tarnhall | god_rays @Node3D@6714 45.9; frost_veil @Node3D@6705 30.2; pickup @Node3D@6729 4.8; npc @Node3D@6707 4.3; npc @Node3D@6708 3.8; (dearest flush of the worker's commands: 5.4 ms, after houses) | god_rays @Node3D@22703 46.1; frost_veil @Node3D@22694 30.8; pickup @Node3D@22718 4.1; npc @Node3D@22696 3.6; npc @Node3D@22697 3.3; (dearest flush of the worker's commands: 5.7 ms, after water, hazards) |
| thornwold | frost_veil @Node3D@8252 38.6; pickup @Node3D@8262 5.5; hearthstone @Node3D@8235 2.7; hearthstone @Node3D@8236 2.7; hearthstone @Node3D@8237 2.3; (dearest flush of the worker's commands: 5.7 ms, after houses) | frost_veil @Node3D@24241 33.0; pickup @Node3D@24251 5.2; hearthstone @Node3D@24224 3.1; hearthstone @Node3D@24226 2.9; npc @Node3D@24242 2.9; (dearest flush of the worker's commands: 5.8 ms, after forest) |
| shepherds_reach | npc @Node3D@14165 95.4; frost_veil @Node3D@14162 30.2; pickup @Node3D@14171 4.6; pickup @Node3D@14175 3.9; pickup @Node3D@14172 3.5; (dearest flush of the worker's commands: 7.8 ms, after houses) | npc @Node3D@30154 78.0; frost_veil @Node3D@30151 30.5; pickup @Node3D@30164 4.0; pickup @Node3D@30161 3.1; hearthstone @Node3D@30134 2.6; (dearest flush of the worker's commands: 5.2 ms, after houses) |
| coldwell | frost_veil @Node3D@15336 32.5; pickup @Node3D@15348 4.6; hearthstone @Node3D@15328 3.1; hearthstone @Node3D@15327 3.0; hearthstone @Node3D@15329 2.8; (dearest flush of the worker's commands: 6.0 ms, after houses) | frost_veil @Node3D@31325 37.4; pickup @Node3D@31337 4.8; hearthstone @Node3D@31316 3.1; hearthstone @Node3D@31318 3.0; hearthstone @Node3D@31317 2.8; (dearest flush of the worker's commands: 1.3 ms, after houses) |

Main thread waited at most 0.0 ms for a cache a worker build held (BuildLock). Cache: 50 hits, 22 misses.

### Per-phase, cold cache: main-thread ms (+ worker-thread ms)

| phase | saltfell_steading | lowe_barrows | kettle_fjord | tarnhall | thornwold | shepherds_reach | coldwell |
|---|---:|---:|---:|---:|---:|---:|---:|
| def parse | 0 (+1 w) | 0 (+1 w) | 0 (+2 w) | 0 (+1 w) | 0 (+2 w) | 0 (+3 w) | 0 (+1 w) |
| flush: worker's render commands | 1732 | 327 | 576 | 485 | 603 | 381 | 295 |
| terrain setup | 0 (+17 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) |
| terrain mesh | 0 (+607 w) | 0 (+23 w) | 0 (+19 w) | 0 (+24 w) | 0 (+25 w) | 0 (+31 w) | 0 (+28 w) |
| terrain horizon | 0 (+71 w) | 0 (+15 w) | 0 (+15 w) | 0 (+14 w) | 0 (+15 w) | 0 (+14 w) | 0 (+16 w) |
| terrain collider | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain (other) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| water, hazards | 0 (+108 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+104 w) |
| houses | 0 (+1213 w) | 0 (+181 w) | 0 (+202 w) | 0 (+346 w) | 0 | 0 (+46 w) | 0 (+97 w) |
| pieces, props, landmarks | 0 (+993 w) | 0 (+399 w) | 0 (+885 w) | 0 (+455 w) | 0 (+384 w) | 0 (+572 w) | 0 (+483 w) |
| entities, spawners | 0 (+17 w) | 0 (+1 w) | 0 (+36 w) | 0 (+35 w) | 0 (+51 w) | 0 (+25 w) | 0 (+1 w) |
| scatter stones, fences | 0 (+691 w) | 0 (+243 w) | 0 (+67 w) | 0 (+78 w) | 0 (+39 w) | 0 (+72 w) | 0 (+86 w) |
| scatter ground cover | 0 (+12758 w) | 0 (+70 w) | 0 (+38 w) | 0 (+15 w) | 0 (+108 w) | 0 (+13629 w) | 0 (+64 w) |
| forest | 0 | 0 | 0 | 0 | 0 (+387 w) | 0 | 0 |
| weather, traps, wayside | 0 (+8 w) | 0 (+11 w) | 0 (+11 w) | 0 (+56 w) | 0 (+437 w) | 0 (+0 w) | 0 (+16 w) |
| indoor marks, ambient | 0 (+4 w) | 0 (+1 w) | 0 (+2 w) | 0 (+3 w) | 0 | 0 (+3 w) | 0 (+1 w) |
| worker: models read ahead | 0 (+131 w) | 0 (+178 w) | 0 (+190 w) | 0 (+152 w) | 0 (+118 w) | 0 (+112 w) | 0 (+70 w) |
| graft: area root | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| graft: static world | 3 | 2 | 2 | 3 | 6 | 4 | 4 |
| graft: particles, weather (main-thread steps) | 165 | 34 | 156 | 34 | 32 | 37 | 34 |
| warm: collect materials | 4 | 2 | 2 | 3 | 6 | 3 | 2 |
| warm: draw materials | 21 | 10 | 13 | 11 | 10 | 16 | 13 |
| warm: what acts' clips | 41 | 80 | 62 | 54 | 42 | 41 | 55 |
| warm: what acts, unseen | 109 | 7 | 7 | 4 | 4 | 4 | 3 |
| swap | 4 | 7 | 6 | 6 | 7 | 8 | 5 |
| state snap, place Bearer | 22 | 12 | 11 | 13 | 14 | 9 | 10 |
| graft: what acts | 448 | 115 | 119 | 117 | 62 | 152 | 59 |
| graft: deferred (foes raised) | 143 | 22 | 17 | 53 | 32 | 17 | 15 |
| nav fingerprint | 4 | 2 | 2 | 3 | 8 | 2 | 2 |
| nav parse | 207 | 155 | 41 | 89 | 117 | 78 | 72 |
| nav apply | 0.2 | 0.1 | 0.1 | 0.1 | 0.2 | 0.1 | 0.1 |
| save | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| keep: what acts' shaders | 26 | 14 | 24 | 26 | 11 | 11 | 8 |
| **total** | **2931 (+16620 w)** | **790 (+1125 w)** | **1038 (+1470 w)** | **900 (+1180 w)** | **956 (+1567 w)** | **764 (+14507 w)** | **577 (+967 w)** |

### Per-phase, warm cache: main-thread ms (+ worker-thread ms)

| phase | saltfell_steading | lowe_barrows | kettle_fjord | tarnhall | thornwold | shepherds_reach | coldwell |
|---|---:|---:|---:|---:|---:|---:|---:|
| def parse | 0 (+1 w) | 0 (+1 w) | 0 (+2 w) | 0 (+2 w) | 0 (+2 w) | 0 (+3 w) | 0 (+1 w) |
| terrain setup | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) |
| flush: worker's render commands | 648 | 239 | 374 | 381 | 318 | 233 | 196 |
| terrain mesh | 0 (+20 w) | 0 (+19 w) | 0 (+12 w) | 0 (+10 w) | 0 (+10 w) | 0 (+11 w) | 0 (+14 w) |
| terrain horizon | 0 (+14 w) | 0 (+15 w) | 0 (+15 w) | 0 (+14 w) | 0 (+14 w) | 0 (+15 w) | 0 (+17 w) |
| terrain collider | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain (other) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| water, hazards | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 | 0 (+0 w) | 0 (+0 w) |
| houses | 0 (+540 w) | 0 (+176 w) | 0 (+203 w) | 0 (+341 w) | 0 | 0 (+38 w) | 0 (+93 w) |
| pieces, props, landmarks | 0 (+492 w) | 0 (+228 w) | 0 (+366 w) | 0 (+247 w) | 0 (+189 w) | 0 (+343 w) | 0 (+321 w) |
| entities, spawners | 0 (+10 w) | 0 (+1 w) | 0 (+25 w) | 0 (+22 w) | 0 (+13 w) | 0 (+24 w) | 0 (+1 w) |
| scatter stones, fences | 0 (+370 w) | 0 (+145 w) | 0 (+63 w) | 0 (+75 w) | 0 (+38 w) | 0 (+72 w) | 0 (+82 w) |
| scatter ground cover | 0 (+50 w) | 0 (+29 w) | 0 (+3 w) | 0 (+10 w) | 0 (+10 w) | 0 (+43 w) | 0 (+11 w) |
| forest | 0 | 0 | 0 | 0 | 0 (+48 w) | 0 | 0 |
| weather, traps, wayside | 0 (+2 w) | 0 (+2 w) | 0 (+6 w) | 0 (+77 w) | 0 (+434 w) | 0 (+0 w) | 0 (+16 w) |
| indoor marks, ambient | 0 (+3 w) | 0 (+2 w) | 0 (+2 w) | 0 (+3 w) | 0 | 0 (+2 w) | 0 (+1 w) |
| worker: models read ahead | 0 (+162 w) | 0 (+196 w) | 0 (+148 w) | 0 (+117 w) | 0 (+101 w) | 0 (+117 w) | 0 (+68 w) |
| graft: area root | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| graft: static world | 4 | 2 | 2 | 3 | 7 | 3 | 5 |
| graft: particles, weather (main-thread steps) | 56 | 32 | 53 | 34 | 33 | 37 | 35 |
| warm: collect materials | 4 | 2 | 2 | 3 | 6 | 3 | 2 |
| warm: draw materials | 15 | 10 | 12 | 11 | 11 | 15 | 14 |
| warm: what acts' clips | 0.1 | 0.3 | 0.2 | 0.2 | 0.2 | 0.2 | 0.2 |
| warm: what acts, unseen | 5 | 7 | 7 | 5 | 5 | 4 | 3 |
| swap | 5 | 7 | 7 | 6 | 8 | 8 | 6 |
| state snap, place Bearer | 14 | 8 | 12 | 11 | 16 | 8 | 10 |
| graft: what acts | 116 | 93 | 114 | 114 | 59 | 132 | 64 |
| graft: deferred (foes raised) | 26 | 19 | 21 | 59 | 13 | 15 | 17 |
| nav fingerprint | 4 | 3 | 2 | 3 | 9 | 2 | 2 |
| nav apply | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 |
| save | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| keep: what acts' shaders | 23 | 14 | 23 | 26 | 12 | 11 | 9 |
| nav parse | 0 | 0 | 0 | 0 | 0 | 85 | 0 |
| **total** | **920 (+1667 w)** | **438 (+814 w)** | **631 (+846 w)** | **658 (+920 w)** | **499 (+859 w)** | **559 (+670 w)** | **364 (+626 w)** |
