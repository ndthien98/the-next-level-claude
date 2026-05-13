# Memory & Continuity

Each project carries two complementary memory stores so that leads and
specialists keep their context across sessions, restarts, and compactions.

## Tier 1 — Auto-memory (Claude Code managed)

Claude Code maintains a per-project memory bank at:

```
~/.claude/projects/-<encoded-path>/memory/
├── MEMORY.md              ← index file with one link per topic
├── project_<topic>.md     ← project facts (stack, architecture, recent changes)
├── user_<topic>.md        ← owner profile (preferences, time zone, comms style)
├── feedback_<topic>.md    ← owner feedback / corrections worth keeping
└── reference_<topic>.md   ← external references (URLs, doc snippets)
```

The encoded path replaces `/` with `-` — for example, the project
`/home/owner/work/my-project` lives under
`~/.claude/projects/-home-owner-work-my-project/memory/`.

**What goes there (and what does NOT).** Auto-memory is for facts the agent
should re-discover automatically on the next session — not for transient
scratch work.

| File-name prefix | Contents | Examples |
|---|---|---|
| `project_*.md`   | Stable project facts | tech stack, schema, key endpoints, recent decisions |
| `user_*.md`      | Owner preferences    | comms style, working hours, package manager, env conventions |
| `feedback_*.md`  | Owner corrections    | "stop summarizing X", "always run lint before push" |
| `reference_*.md` | External refs        | API URLs, docs links, third-party constraints |

Avoid: daily scratch, transient debug notes, plan-specific TODOs (those go
in `plans/<plan>/`).

**How agents use it.** A lead reading the project's memory at spawn time
walks `MEMORY.md` and pulls the linked files on demand. The index is what
they read first; it should be ≤30 lines and group entries by category.

## Tier 2 — Per-agent memory bank (`.claude/agent-memory/`)

This directory is **inside the project** (committed or gitignored at
owner's discretion). Each long-lived role gets its own subfolder:

```
.claude/agent-memory/
├── coder/
│   ├── MEMORY.md
│   └── reference_<topic>.md
├── reviewer/
│   ├── MEMORY.md
│   └── project_<topic>.md
└── researcher/
    ├── MEMORY.md
    ├── reference_<topic>.md
    └── feedback_<topic>.md
```

Use this when a specific role accumulates expertise that should persist
even if the auto-memory is cleared — e.g. a `reviewer` that remembers the
project's pet style guides, or a `researcher` that built up a personal
bibliography.

Specialists read their own `MEMORY.md` on first run inside a project and
update it at the end of substantive sessions.

## Naming convention (both tiers)

- `MEMORY.md` — the index file (one bullet per linked file, ≤30 lines).
- `<category>_<slug>.md` — the actual content.
- `<category>` is one of: `project`, `user`, `feedback`, `reference`.
- `<slug>` is kebab-case, descriptive.

Example: `project_auth-flow.md`, `user_comms-style.md`,
`feedback_no-emoji-in-replies.md`, `reference_typeorm-migrations.md`.

## Bootstrap

A fresh project starts with empty `MEMORY.md` skeletons. Use
`bash agents/memory-bootstrap.sh <project-name>` (run from the fleet root)
to scaffold the memory directories + index files for a new project. The
script is idempotent — safe to run more than once.

## When to write vs not

**Write to memory when:**

- The owner gives a durable instruction ("always use yarn", "this project
  uses pnpm", "never edit `legacy/` without asking").
- You learn a project fact that's expensive to re-discover (DB port,
  custom build flag, atypical folder layout).
- You finalize an architectural decision worth carrying into next session.

**Do NOT write when:**

- The fact is already in `docs/` or `README.md` — link to that instead.
- The fact is transient ("the build is failing right now").
- The fact is sensitive (tokens, credentials, private keys — never).

## Compaction note

When the session is compacted (context summarized), `MEMORY.md` is one of
the first things the lead should re-read. The `session-init.cjs` hook
fires on `source=compact` and reminds the lead to re-confirm any pending
approvals — extend that hook if you need stronger memory-rehydration
behavior.
