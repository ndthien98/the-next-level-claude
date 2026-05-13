# Compiled KB — index

> Hand-maintained pointer to the most important sessions, daily roll-ups,
> and reference notes in this knowledge base. The auto-pipeline (hooks)
> never edits this file — you do. Keep it short and useful.

## How this folder is used

- `sessions.jsonl`  — one JSONL line per ended session (auto-written by
  `on-session-end.sh`). Cheap to grep, capped at ~5000 lines.
- `recent-context.md` — last-25-turn snapshot taken just before each
  compaction (auto-written by `on-pre-compact.sh`).
- `daily/YYYY-MM-DD.md` — optional daily roll-ups. Not auto-generated;
  produce them by hand or by a cron job you control (see README).
- `index.md` (this file) — manual pointers to the entries above worth
  remembering long-term.

## Pinned sessions

<!-- Add entries like:
- 2026-05-12  — first end-to-end run of the fleet poller. session_id=abc123
-->

(none yet)

## Pinned daily roll-ups

<!-- Add entries like:
- daily/2026-05-12.md  — bootstrap + first project lead spawn
-->

(none yet)

## Reference notes

<!-- External docs or links worth keeping at fingertip distance:
- Claude Code hooks reference: https://docs.claude.com/en/docs/claude-code/hooks
-->

(none yet)
