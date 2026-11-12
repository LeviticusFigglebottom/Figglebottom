# Swing trails (gpu/trail-fix): before is main a6a45f6, after is this branch

These are real-GPU shots at q2, 1920x1080, with `--shot-stage=bearer_light1 --shot-weapon=<w>` and `--shot-torch=lit/unlit`, in both states.

All of it is presentation only: the trail's timing (when it shows and hides) is the attack's own and has not changed.

- **The unlit torch:**
  - `clip_meta.json` `weapons.torch.trail_unlit` gives the trail keys used while the brand is out: no ember style, grey tint, energy 0.25, weight 0.45, life 0.12.
  - `CharVisual` re-applies the weapon's trail look whenever the trail appears, and swaps those keys in while `brand.is_lit()` is false.
  - The put-out brand now leaves a faint grey arc, not fire. The lit torch is unchanged.
- **The greatblade:**
  - Its young arc is nearly all "leading edge", whose opacity and whiteness did not follow any weapon data, so it read as a white slab against the THAW sky.
  - The shader gains `edge`, which defaults to 1.0, so every other weapon is unchanged. It is set from a new `trail_edge` key.
  - The greatblade now has `trail_edge` 0.35, `trail_weight` 0.4 and steel tint (0.72, 0.74, 0.76).
  - The arc is a translucent steel smear in THAW and still reads over RIME snow.
- **Tests:** smoke 11/0, anim 229/0, combat 22/0, body 8/0, originality clean.
