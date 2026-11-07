# Task board

## doing
Format: worktree → branch.

- `/home/user/fb-ui` → `feat/ui-keepsakes`
  - UI re-skin (bone and ember, OFL font), house card, Keepsakes journal
  - Ingra and Brede's lines, verbatim from SLICE.md
- `/home/user/fb-enc` → `feat/slice-encounters`
  - Cast in game: the Bearer, NPCs, the Oarsman and his ice oar, the Hearthhound
  - The Netmender's three-phase fight
  - Death dissolve
- `/home/user/fb-art2` → `art/lowe-heroes`: Tripo heroes for the Lowe (the Turfwright, enemies, NPCs, landmarks)
- `/home/user/figglebottom` → `feat/lowe-world`
  - Living dressing (grass, particles), strata variety
  - The `lowe_barrows` region, linked to Saltfell by the ravine bridge

## todo
1. Frost and hoar branch in `hall.gdshader`. Frost/melt wavefront look (replaces the inherited burning edge).
2. New music and ambience for THAW and RIME. Generic foley.
3. Wire Brede's `give_oilskins` gift once his NPC data lands.
4. Region tier: the Turfwright fight, the Lowe NPCs, the Keepsakes questline.
5. Performance pass: LODs, visibility ranges, MultiMesh, real-GPU profiling by the owner.

## done (merged to main)
- Phase 1 survey, originality guard, ADRs 0001–0003, SPEC, CLAUDE.md, lore and roster
- Engine port and the greybox
- Tripo pilot; slice heroes and 14 region concepts
- ADR 0004: Mixamo animation layer; the Rimewalker strikes with ice-club fists
- Terrain system, the Saltfell landscape (ADR 0005), cliff and ravine polish, procedural turf-roof buildings
- Combat deltas: lock switching, data upgrades, (stat−8) scaling, sprint attack, armour slots, save_version 2
