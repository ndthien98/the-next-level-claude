# `.claude/knowledge/` — Compiled knowledge base

A small append-only KB that survives across Claude Code sessions and
compactions. Filled by hooks; read on every session start.

> Pattern inspired by [coleam00/claude-memory-compiler][src] — this is a
> clean-room shell reimplementation. No code was copied.
>
> [src]: https://github.com/coleam00/claude-memory-compiler

## Files

| File                  | Writer                          | Reader (default)            |
|-----------------------|---------------------------------|-----------------------------|
| `sessions.jsonl`      | `hooks/on-session-end.sh`       | `hooks/on-session-start.sh` |
| `recent-context.md`   | `hooks/on-pre-compact.sh`       | `hooks/on-session-start.sh` |
| `daily/YYYY-MM-DD.md` | external (you / cron / make)    | manual `grep` / `index.md`  |
| `index.md`            | you (manual)                    | `hooks/on-session-start.sh` |

## Schemas

### `sessions.jsonl`

One JSON object per line:

```json
{
  "session_id":     "abcd-1234",
  "ended_at":       "2026-05-13T18:50:01Z",
  "reason":         "clear|exit|crash|unspecified",
  "cwd":            "/home/ubuntu/...",
  "tool_use_count": 42,
  "files_edited":   [".claude/hooks/on-session-end.sh"],
  "key_topics":     ["first 6 distinct user prompts, truncated to 120 chars"]
}
```

Auto-rotates at >5000 lines (keeps last 2500).

### `recent-context.md`

Markdown with three sections, all best-effort from the JSONL transcript:

1. **Last user prompts** — up to 15 lines, 240 chars each.
2. **Last assistant turns** — up to 10 lines, 240 chars each.
3. **Recent tool uses** — up to 15 lines, name + truncated arg.

Replaced atomically on every PreCompact event. Not appended — only the
most recent snapshot survives.

### `daily/YYYY-MM-DD.md`

Free-form. Suggested template:

```markdown
# YYYY-MM-DD

## Highlights
- ...

## Sessions
- 09:00–10:15  session_id=...  edited X, Y, Z
- 14:00–14:30  ...

## Decisions / learnings
- ...
```

The fleet does not generate these. Convention only — produce them with
your own `make daily` recipe or a `cron` script that greps
`sessions.jsonl` for that date.

### `index.md`

Hand-maintained list of pointers to the most important sessions, daily
files, and reference notes. Kept short on purpose — this file is read
verbatim on every SessionStart.

## Auto-pipeline

```
                                ┌───────────────┐
                                │ SessionStart  │
   .claude/knowledge/  ───────► │ on-session-   │ ───► stdout
        index.md                │ start.sh      │     (Claude reads)
        recent-context.md       └───────────────┘
        sessions.jsonl (tail 5)

       ┌───────────────┐       ┌─────────────────────┐
       │  PreCompact   │ ───►  │ on-pre-compact.sh   │ ───► recent-context.md
       └───────────────┘       └─────────────────────┘

       ┌───────────────┐       ┌─────────────────────┐
       │  SessionEnd   │ ───►  │ on-session-end.sh   │ ───► sessions.jsonl
       └───────────────┘       └─────────────────────┘
```

## Manual upkeep (the only manual step)

When a session was particularly important (a major bug fix, a big
architectural decision, the first end-to-end run of a new feature),
add a one-line pointer to `index.md`. Everything else is automatic.

## Disabling

Remove the corresponding entries from `.claude/settings.json`. The
folder can stay; nothing else reads it.
