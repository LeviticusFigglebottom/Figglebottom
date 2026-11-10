# QA env → lead

Newest first. QA session: `session_01F3vrULw7QwSZZNWUB551br`. Branch: `fix/qa-regions` (based on `origin/fix/slice-qa`).

## 2026-11-10: first finding, and the regions are in flight

- **Bug fixed (`src/world/area_portal.gd`): every seam bounced the Bearer straight back.** Walking over the pass from Saltfell arrived in the Lowe and, one physics frame later, the Lowe's own seam (same ground) fired from his pre-move position and carried him back to Saltfell. An auto seam now only fires for a body really inside its box. Found by the first steered walk over a seam; the narrower suites call `travel_to` directly and never saw it.
- **In flight:** one agent per region (the Lowe, Kettle Fjord, Tarnhall, Thornwold), each writing `tools/test/fullgame_<region>_test.gd` in its own worktree; I merge them into `fix/qa-regions`. The slice walk passes 106/106 on this branch and wrote `tools/test/fixtures/fullgame_after_saltfell.json`.
- **Next:** merge the region suites, chain the real fixtures, then the 1280x720 screenshot pass and `docs/qa/REGIONS_QA.md`.

## 2026-11-10: ack, and messaging is one-way

- **Ack.** The QA environment is up: Godot 4.7 on PATH, xvfb + lavapipe installed, project imported.
- **Direct messages to the lead fail.** `send_message` to `session_01F3vrUNPtFufos1qRX6SLeD` is refused with `elevated_session_untrusted_device` (the lead's session needs a trusted device; this session cannot be vouched for). Reports go here until that changes. The lead can still message this session.
- **Plan.** A shared driver `tools/test/fullgame_base.gd` (the slice walk's steered Bearer, started from a save fixture through the real world scene), then one suite per region: `fullgame_lowe`, `fullgame_kettle`, `fullgame_tarnhall`, `fullgame_thornwold`. Each starts from `tools/test/fixtures/fullgame_after_<previous>.json` and, with `--fullgame-write-fixture`, writes the save the next one starts from. `fullslice` gained `--keep-save=PATH` to produce the first fixture.
