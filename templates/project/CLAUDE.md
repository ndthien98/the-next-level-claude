# Project Context — $PROJECT_NAME

This file is auto-loaded by every Claude invocation running in this
project. The **fleet** CLAUDE.md (at the fleet root) defines the global
rules; this file adds **project-specific** context only.

## Persona

Defined under `.claude/persona/` — IDENTITY, SOUL, USER. Read these first
on every shift wake. If you change the persona, surface it to the owner
on next interaction.

## Project memory (canonical state for this project)

- `.claude/memory/policies.md` — durable rules / decisions for this project
- `.claude/memory/learnings/INDEX.md` — distilled lessons
- `.claude/memory/learnings/ERRORS.md` — mistakes / bug log; don't repeat
- `.claude/memory/learnings/FEATURE_REQUESTS.md` — gap log; what tooling /
  knowledge / access is missing
- `.claude/reminders/REMINDERS.md` — active TODOs for this project
- `.claude/reminders/SCHEDULE.md` — recurring rules / cron-like patterns

Update these via the Self-Update Protocol (see fleet CLAUDE.md).

## Project capabilities

- `.claude/.mcp.json` (if present) — MCP servers specific to this project.
  Specialists spawned by the lead should reference this rather than the
  fleet's global MCP set, to keep context lean.
- `.claude/SKILLS.md` — skills relevant for this project's domain (e.g.
  `nestjs-expert`, `react-expert`, `blockchain-engineer`)
- `.claude/TOOLS.md` — Bash command allowlist patterns the lead can pass
  to specialists when spawning them

## Specialists (spawn via `Agent` tool from project lead)

Project-scoped roles at `.claude/agents/roles/<shift>.md`:

| Shift | When to use |
|---|---|
| `coder`      | Write / edit / refactor code; run tests |
| `reviewer`   | Code review, anti-pattern flagging |
| `debugger`   | Error / log / stack trace analysis, root cause |
| `planner`    | Break down work, write implementation plans |
| `backend`    | APIs, DB, server-side logic |
| `frontend`   | UI, components, browser-side |
| `blockchain` | Solidity, contracts, Web3 |
| `devops`     | CI/CD, infra, deployment, observability |
| `qa`         | Testing strategy + suites |
| `security`   | Threat model, vuln scan, hardening |

You may also use the owner's pre-built specialists from
`~/.claude/agents/` (e.g. `backend-engineer`, `frontend-engineer`,
`code-reviewer`, `playwright-control`) by passing `subagent_type=<name>`
to the Agent tool. These are domain experts the owner has tuned
globally.

## Telegram I/O for this project

The fleet poller routes inbound to this project when:
- Text starts with `@$PROJECT_NAME ` (explicit tag), or
- This project is the active one (`.state/active-project.txt` at fleet root)

Reply via:
- `bash $FLEET_ROOT/agents/send-telegram.sh "<text>"` (text)
- `bash $FLEET_ROOT/agents/send-telegram-file.sh "<path>" "[caption]"`

The fleet helpers auto-load credentials from the fleet `.env`. Do not
override them.

## File workflow

- **Inbound files** are downloaded by the fleet poller to
  `$FLEET_ROOT/uploads/<TS>_<user>_<kind><ext>`. They appear in
  `[INBOUND]` blocks under the `files` array.
- **Outbound files** generated here go in `outputs/<TS>_<slug>.<ext>`.
  Send via `send-telegram-file.sh`.
- Don't analyse a file until the owner says what to do with it (per
  SOUL principle).

## Artifact identity (per fleet Hard Rule 2)

All artifacts produced for this project — files, code, commits, docs,
PR bodies — MUST attribute the owner using the per-project identity
registered in `$FLEET_ROOT/.state/identities.json`. NO AI / persona /
agent-id mentions allowed in artifacts. See fleet `CLAUDE.md` →
"Hard rule 2" for full doctrine.

Before any git activity in this project's repo(s), set local config:
```
git -C <repo> config user.name  "<from identities.json>"
git -C <repo> config user.email "<from identities.json>"
```

## Project-specific rules (edit me)

Add anything specific to this project here. Examples:
- _"Use Yarn, not npm — the repo has a yarn.lock"_
- _"Tests must pass before any push to main"_
- _"Default branch is `develop`, not `main`"_
- _"Always run `yarn lint && yarn format` before commit"_

All fleet-level Hard Rules from `$FLEET_ROOT/CLAUDE.md` still apply —
persona compliance, anti-hallucination, OpSec for non-owner users,
honest reporting, master override for owner, never assume user wrong,
NO AI/persona attribution in artifacts (Hard Rule 2).
