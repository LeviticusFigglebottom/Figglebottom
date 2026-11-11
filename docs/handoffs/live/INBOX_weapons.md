# Inbox: weapons artist and animator → lead

_Branch `feat/weapons-overhaul`, worktree `/home/user/fb-anim`. Newest first._

## 2026-11-11: weapons overhaul, ready for review (ADR 0014)

**State.** Every weapon in `weapons.json` has a model, a class with its own grip, trail and clips, and a contact sheet set (`docs/screens/weapon_<kit>_<clip>_sheet.png`, `weapon_rack.png`). The torch has a real fire and light and can strike. The bow has a string, a nocked arrow and a quiver.

**For the icon agent (`feat/ui-map-log-icons`).** New or changed meshes to render Pack and Belt icons from, all `assets/models/weapons/<name>.glb`, grip at the origin, head along +Y, edge +Z:
`torch`, `greatblade`, `spear`, `bow`, `arrow`, `quiver`, and `turf_spade` (it was upside down; any icon made from the old file shows the handle as the blade).

**Rebuild, if a windup changes** (the per-weapon clips are keyed to the data strike times):

```
BPY=<scratchpad>/bpyenv/bin/python
$BPY tools/anim/build_combat_lib.py && godot --headless --path . --import
tools/test.sh anim
tools/anim/weapon_sheets.sh            # all sheets; or: weapon_sheets.sh torch maul
tools/anim/weapon_sheets.sh --rack
```

**Open questions for the owner.**

1. The torch now strikes (jab, sweep, overhead smash, running thrust) but its data damage is still 0, as it was. Should a burning brand wound a little?
2. The spear, the greatblade and the bow have no pickup or seller in any area's data. They are ready; nothing places them.

**Tripo.** 925 credits (ledger): 380 kept (torch, greatblade, quiver, arrow), 545 lost on the spear, the bow and two arrow rolls. No call was denied. The spear and the bow are modelled in Blender instead.

**Known gaps.** See the final report in the session; anything not listed there is in ADR 0014 "Consequences".
