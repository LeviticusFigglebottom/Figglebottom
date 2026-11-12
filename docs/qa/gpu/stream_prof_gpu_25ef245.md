### Crossing into each area, made ready ahead (streamed)

| area | nodes | made ready, cold cache ms | made ready, warm cache ms | black, cold ms | black, warm ms | swap frame ms | worst frame, cold ms | worst frame, warm ms | next worst, warm ms | what the worst frame held (warm) | nav bake thaw/rime, cold ms (background) | nav from cache, warm | sync phases |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---|---|---|
| saltfell_steading | 3916 | 15025 | 1459 | 3373 | 600 | 6.6 | 238.5 | 107.2 | 45.1 | graft: what acts 107;  | 230 / 254 | [true, true] | none |
| lowe_barrows | 2076 | 7990 | 746 | 940 | 422 | 7.0 | 89.7 | 90.8 | 38.0 | graft: what acts 88; free: old area 3;  | 261 / 255 | [true, true] | none |
| kettle_fjord | 1610 | 1130 | 610 | 767 | 480 | 6.9 | 85.1 | 92.9 | 63.0 | graft: what acts 90; free: old area 3;  | 157 / 198 | [true, true] | none |
| tarnhall | 2661 | 962 | 904 | 848 | 393 | 5.9 | 83.8 | 83.3 | 11.3 | graft: what acts 83;  | 154 / 190 | [true, true] | none |
| thornwold | 6081 | 1253 | 850 | 902 | 428 | 8.8 | 101.4 | 96.6 | 18.0 | graft: what acts 94; free: old area 3;  | 215 / 233 | [true, true] | none |
| shepherds_reach | 2406 | 8420 | 643 | 1009 | 863 | 8.7 | 127.0 | 89.3 | 88.8 | graft: what acts 87; free: old area 3;  | 253 / 258 | [false, false] | none |
| coldwell | 1484 | 1492 | 497 | 1177 | 379 | 5.7 | 100.8 | 97.2 | 13.8 | graft: what acts 94; free: old area 3;  | 627 / 628 | [true, true] | none |

### Freeing the area left, a rest, the turn to RIME (warm pass): worst main-thread frame, ms of work

| area | foes raised | free: worst frame ms | free: frames | rest: worst frame ms | turn to RIME: worst frame ms | what it held |
|---|---:|---:|---:|---:|---:|---|
| saltfell_steading | 17 | 2.6 | 8 | 6.4 | 54.0 | flip: pre_transition 4.0; flip: wave particles 50.0;  |
| lowe_barrows | 12 | 3.8 | 13 | 5.7 | 53.1 | flip: pre_transition 3.2; flip: wave particles 49.9;  |
| kettle_fjord | 10 | 3.2 | 9 | 4.7 | 54.9 | flip: pre_transition 3.6; flip: wave particles 51.3;  |
| tarnhall | 15 | 2.7 | 6 | 6.0 | 57.5 | flip: pre_transition 4.3; flip: wave particles 53.2;  |
| thornwold | 10 | 3.0 | 10 | 5.6 | 55.4 | flip: pre_transition 4.7; flip: wave particles 50.6;  |
| shepherds_reach | 8 | 2.7 | 19 | 5.8 | 58.9 | flip: pre_transition 4.1; flip: wave particles 54.8;  |
| coldwell | 8 | 8.8 | 8 | 5.9 | 57.2 | flip: pre_transition 3.4; flip: wave particles 53.8;  |

Main thread waited at most 0.0 ms for a cache a worker build held (BuildLock). Cache: 49 hits, 23 misses.

### Per-phase, cold cache: main-thread ms (+ worker-thread ms)

| phase | saltfell_steading | lowe_barrows | kettle_fjord | tarnhall | thornwold | shepherds_reach | coldwell |
|---|---:|---:|---:|---:|---:|---:|---:|
| def parse | 0 (+1 w) | 0 (+1 w) | 0 (+2 w) | 0 (+1 w) | 0 (+3 w) | 0 (+2 w) | 0 (+1 w) |
| flush: worker's render commands | 1994 | 155 | 287 | 362 | 329 | 143 | 520 |
| terrain setup | 0 (+7 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) |
| terrain mesh | 0 (+621 w) | 0 (+19 w) | 0 (+12 w) | 0 (+9 w) | 0 (+10 w) | 0 (+12 w) | 0 (+13 w) |
| terrain horizon | 0 (+74 w) | 0 (+15 w) | 0 (+16 w) | 0 (+14 w) | 0 (+16 w) | 0 (+16 w) | 0 (+18 w) |
| terrain collider | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain (other) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| water, hazards | 0 (+345 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+4 w) |
| houses | 0 (+1778 w) | 0 (+185 w) | 0 (+171 w) | 0 (+384 w) | 0 | 0 | 0 (+160 w) |
| pieces, props, landmarks | 0 (+503 w) | 0 (+0 w) | 0 (+486 w) | 0 (+227 w) | 0 (+53 w) | 0 (+138 w) | 0 (+527 w) |
| entities, spawners | 0 (+19 w) | 0 (+1 w) | 0 (+13 w) | 0 (+31 w) | 0 (+34 w) | 0 (+3 w) | 0 (+0 w) |
| scatter stones, fences | 0 (+310 w) | 0 (+36 w) | 0 (+24 w) | 0 (+13 w) | 0 (+10 w) | 0 (+11 w) | 0 (+26 w) |
| scatter ground cover | 0 (+10092 w) | 0 (+7317 w) | 0 (+7 w) | 0 (+13 w) | 0 (+20 w) | 0 (+7790 w) | 0 (+34 w) |
| forest | 0 | 0 | 0 | 0 | 0 (+383 w) | 0 | 0 |
| weather, traps, wayside | 0 (+276 w) | 0 (+130 w) | 0 (+7 w) | 0 (+28 w) | 0 (+511 w) | 0 (+230 w) | 0 (+51 w) |
| indoor marks, ambient | 0 (+4 w) | 0 (+2 w) | 0 (+2 w) | 0 (+3 w) | 0 | 0 | 0 (+1 w) |
| worker: models read ahead | 0 (+123 w) | 0 (+182 w) | 0 (+147 w) | 0 (+92 w) | 0 (+80 w) | 0 (+85 w) | 0 (+66 w) |
| graft: area root | 0.1 | 0.0 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 |
| graft: static world | 4 | 2 | 1 | 2 | 7 | 2 | 4 |
| graft: particles, weather (main-thread steps) | 252 | 30 | 157 | 60 | 36 | 33 | 37 |
| warm: collect materials | 5 | 2 | 2 | 3 | 6 | 3 | 2 |
| warm: draw materials | 1 | 0.5 | 1 | 1 | 1 | 1 | 1 |
| swap | 5 | 7 | 5 | 6 | 8 | 9 | 6 |
| state snap, place Bearer | 9 | 5 | 1 | 2 | 3 | 2 | 1 |
| graft: what acts | 596 | 166 | 195 | 180 | 144 | 257 | 143 |
| graft: deferred (foes raised) | 193 | 43 | 35 | 91 | 59 | 50 | 57 |
| nav fingerprint | 5 | 2 | 2 | 2 | 8 | 3 | 2 |
| nav parse | 256 | 125 | 42 | 75 | 125 | 87 | 69 |
| nav apply | 0.2 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 |
| save | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| **total** | **3319 (+14153 w)** | **537 (+7889 w)** | **729 (+889 w)** | **786 (+817 w)** | **727 (+1122 w)** | **590 (+8288 w)** | **842 (+903 w)** |

### Per-phase, warm cache: main-thread ms (+ worker-thread ms)

| phase | saltfell_steading | lowe_barrows | kettle_fjord | tarnhall | thornwold | shepherds_reach | coldwell |
|---|---:|---:|---:|---:|---:|---:|---:|
| def parse | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+2 w) | 0 (+2 w) | 0 (+2 w) | 0 (+1 w) |
| terrain setup | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) | 0 (+1 w) |
| flush: worker's render commands | 519 | 137 | 207 | 335 | 179 | 97 | 118 |
| terrain mesh | 0 (+21 w) | 0 (+18 w) | 0 (+11 w) | 0 (+10 w) | 0 (+10 w) | 0 (+12 w) | 0 (+14 w) |
| terrain horizon | 0 (+15 w) | 0 (+16 w) | 0 (+14 w) | 0 (+17 w) | 0 (+14 w) | 0 (+16 w) | 0 (+18 w) |
| terrain collider | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| terrain (other) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| water, hazards | 0 (+0 w) | 0 (+0 w) | 0 (+1 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) | 0 (+0 w) |
| houses | 0 (+496 w) | 0 (+198 w) | 0 (+151 w) | 0 (+392 w) | 0 | 0 | 0 (+92 w) |
| pieces, props, landmarks | 0 (+196 w) | 0 (+0 w) | 0 (+128 w) | 0 (+155 w) | 0 (+46 w) | 0 (+101 w) | 0 (+126 w) |
| entities, spawners | 0 (+10 w) | 0 (+1 w) | 0 (+14 w) | 0 (+26 w) | 0 (+0 w) | 0 (+3 w) | 0 (+0 w) |
| scatter stones, fences | 0 (+138 w) | 0 (+38 w) | 0 (+22 w) | 0 (+13 w) | 0 (+10 w) | 0 (+12 w) | 0 (+26 w) |
| scatter ground cover | 0 (+48 w) | 0 (+36 w) | 0 (+6 w) | 0 (+12 w) | 0 (+19 w) | 0 (+35 w) | 0 (+30 w) |
| forest | 0 | 0 | 0 | 0 | 0 (+31 w) | 0 | 0 |
| weather, traps, wayside | 0 (+250 w) | 0 (+149 w) | 0 (+8 w) | 0 (+27 w) | 0 (+501 w) | 0 (+209 w) | 0 (+34 w) |
| indoor marks, ambient | 0 (+5 w) | 0 (+2 w) | 0 (+2 w) | 0 (+3 w) | 0 | 0 | 0 (+1 w) |
| worker: models read ahead | 0 (+116 w) | 0 (+182 w) | 0 (+142 w) | 0 (+92 w) | 0 (+88 w) | 0 (+116 w) | 0 (+48 w) |
| graft: area root | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| graft: static world | 4 | 2 | 1 | 2 | 7 | 2 | 4 |
| graft: particles, weather (main-thread steps) | 65 | 34 | 35 | 62 | 32 | 34 | 32 |
| warm: collect materials | 5 | 2 | 2 | 3 | 6 | 3 | 2 |
| warm: draw materials | 1 | 0.4 | 1 | 1 | 1 | 1 | 1 |
| swap | 7 | 7 | 7 | 6 | 9 | 9 | 6 |
| state snap, place Bearer | 2 | 1 | 2 | 2 | 4 | 2 | 1 |
| graft: what acts | 176 | 147 | 175 | 109 | 116 | 191 | 114 |
| graft: deferred (foes raised) | 42 | 18 | 19 | 31 | 14 | 19 | 16 |
| nav fingerprint | 4 | 3 | 2 | 3 | 9 | 2 | 1 |
| nav apply | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 | 0.1 |
| save | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| nav parse | 0 | 0 | 0 | 0 | 0 | 85 | 0 |
| **total** | **825 (+1296 w)** | **351 (+640 w)** | **451 (+502 w)** | **553 (+752 w)** | **378 (+721 w)** | **445 (+508 w)** | **295 (+390 w)** |
