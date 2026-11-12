# Task board

## doing
Format: worktree → branch.

- `/home/user/fb-look2` → `art/look-pass-2`: look pass 2 (card grass, hearthstones, sky, gables, fences, ewes); pushed, awaiting merge

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

- `/home/user/fb-audio` → `feat/audio-frost` (ready for review)
  - Frost/melt wavefront in `hall`, `hall_ds` and `terrain` (`shaders/wavefront.gdshaderinc`), snow-crystal and pollen/steam/drip wave particles
  - The score (THAW, RIME, the Outsong, the Netmender, title), ambiences and the foley pass: `docs/audio/MUSIC.md`

- `/home/user/fb-end` → `feat/reach-coldwell-endings` (ready for review)
  - Reach and Coldwell encounters and writing (`REACH.md`, `COLDWELL.md`)
  - Both endings, the credits, the world after each (ADR 0013)
- `/home/user/fb-anim` → `feat/combat-anims` (ready for review)
  - Player combat clips: shared combat library, weapon-class clip sets and grips (ADR 0011)

- cloud streaming env → `feat/streaming` (pushed; ready for review; status in `docs/handoffs/live/INBOX_streaming.md`)
  - Area streaming (ADR 0014): neighbours built on a worker and grafted under a frame budget, disk cache, gradual free, shader warm-up, prompt quit with work in flight. `tools/test.sh streaming`, `tools/qa/quit_check.sh`
  - Progression gating (ADR 0015): one gate on every region's way on, opened by that region's release; tracks worn to each; `way_on` in every area def. `tools/test.sh gates`

## todo
1. Wire Brede's `give_oilskins` gift once his NPC data lands.
2. Region tier: the Turfwright fight, the Lowe NPCs, the Keepsakes questline.
3. Performance pass: LODs, visibility ranges, MultiMesh, real-GPU profiling by the owner.

## done (merged to main)
- Phase 1 survey, originality guard, ADRs 0001–0003, SPEC, CLAUDE.md, lore and roster
- Engine port and the greybox
- Tripo pilot; slice heroes and 14 region concepts
- ADR 0004: Mixamo animation layer; the Rimewalker strikes with ice-club fists
- Terrain system, the Saltfell landscape (ADR 0005), cliff and ravine polish, procedural turf-roof buildings
- Combat deltas: lock switching, data upgrades, (stat−8) scaling, sprint attack, armour slots, save_version 2
