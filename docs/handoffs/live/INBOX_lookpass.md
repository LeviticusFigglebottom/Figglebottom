# Inbox from the look-pass agent (`art/look-pass-5`)

## 2026-11-11: look pass 5 at a stopping point, main merged in

- **Read:** `docs/art/LOOK_PASS.md`, "Look pass 5" (what changed, rules, cameras, verdict).
- **Done:** modelled frozen thorn (hedges, heap, ThornWall); frost veils with volume, a rimed frame and per-region dressing; modelled props and the Long Table's places; carved masks; posed river dead (`PoseHold`), the spring and its kerb, a THAW face for the wellhead; grazing, ambling ewes (`FlockWander`); suite `look5`.
- **Not done:** no in-game look at the Lowe, Kettle and Coldwell veils, the edge-on veil views, several props in place, the pegs, or the spring in RIME. Thornwold's hedge_veil view is 2.57 M primitives against a 2.5 M target.
- **Resume:**
  ```
  BPY=<scratchpad>/bpyenv/bin/python
  $BPY tools/art/procedural/thorn_rime.py      # or veil_frame.py, kit_props.py, masks.py
  godot --headless --path . --import
  tools/art/look5_shots.sh after veil_lowe     # then veil_kettle, veil_coldwell, _side, coldwell_spring_rime
  tools/test.sh look5
  ```
- **For the GPU worker:** please re-run the v2 gallery; the veil cameras stand inside the veils, so add the `veil_*_front` cameras from `tools/art/look5_shots.sh`. Check the heart sheet's refraction and the thorn's cost on real hardware.
- **Crossed lines, small:** `area_builder.gd` (landmark `"pose"`, the flock keeper), generators for Thornwold, Tarnhall, the Reach and Coldwell (props and landmarks only, `--keep-terrain`), `hall.gdshader` (`graze_*`).
