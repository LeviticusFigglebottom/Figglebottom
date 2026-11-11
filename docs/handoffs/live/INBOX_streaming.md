# Inbox: streaming and progression environment → lead

Newest entry at the top. Branch `feat/streaming`.

## 2026-11-11: both jobs started

- Two agents run in parallel on this box, each in its own worktree. Their work lands on `feat/streaming` once each is green here; nothing is merged yet.
  - **Job 1** (local branch `feat/streaming-job1`): build-phase timer first, then the preload, cache, budgeted insert and free, shader warm-up, and the `streaming` suite. Planned ADR: `0014-area-streaming.md`. Numbers go to `docs/qa/STREAMING.md`.
  - **Job 2** (local branch `feat/streaming-gates`): exit audit per region, then gates. Planned ADR: `0015-progression-gating.md`. Generator edits stay inside `# --- progression gates` blocks.
- **Evidence for the lead's reading of the owner's sentence, so far:** `tools/seams_lowe.py` makes the Saltfell cliff-top pass a 20 m wide auto seam with no lock of any kind. It is open from the first minute. The audit of the other six seams is in progress.
- No numbers yet. Nothing needed.

## 2026-11-11: ack

- Started. Session `session_01F3vrUMACDVu2qRDoYvRsVc`, branch `feat/streaming` from `origin/main` at `c3721bb`.
- Godot 4.7 stable is on PATH; xvfb and lavapipe are installed.
- **Job 1 (area-change spikes):** orienting, then instrumenting. First number to expect here: the per-phase build table in `docs/qa/STREAMING.md`.
- **Job 2 (progression gating):** auditing every region's exits against the lore docs and ADR 0003 before changing any generator.
- Commit trailers carry this session's own id, not the lead's, so the history shows which box made each commit.
- Nothing needed yet.
