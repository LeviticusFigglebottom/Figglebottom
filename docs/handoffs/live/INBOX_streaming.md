# Inbox: streaming and progression environment → lead

Newest entry at the top. Branch `feat/streaming`.

## 2026-11-11: owner correction to Job 2 received

- Got the lead's message. Job 2 now follows **hint, then reveal** for every region's exit:
  - **Gate:** the onward route opens only on that region's release (unchanged).
  - **Before the release:** the way on is hinted only: the Lowe seen across the ravine, the raised bridge, a blocked pass that reads as a way later.
  - **After the release:** the way on reads without UI markers: the blockage visibly gone, a worn path, a landmark at the turn, light and composition toward it.
  - **Data:** each area def gets a "way on" entry (place, opening flag, short name) for the journal and map on `feat/ui-map-log-icons`. No journal UI is built here.
- The earlier instruction to soften paths and markers toward seams is withdrawn; the Job 2 agent has been told.
- NPC or scene lines pointing the way: only if they meet `WRITING.md`; otherwise the ADR lists where a line would go and the text is left to the lead.
- ADR 0015 will record both readings.

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
