# Documentation Management

Conventions for project documentation produced by agents in this fleet.

## Living documents

Each project SHOULD maintain (create on first need; not all are required):

| File | Purpose |
|---|---|
| `docs/development-roadmap.md` | Project phases, milestones, progress |
| `docs/project-changelog.md`   | Detailed record of features, fixes, releases |
| `docs/system-architecture.md` | Architecture, components, data flow |
| `docs/code-standards.md`      | Per-project coding conventions |

The owner may rename or merge these. The convention is "where do these
classes of information live" — not "you must have all four files".

## Automatic update triggers

The lead MUST consider docs impact after:

- **Feature implementation** — update roadmap status + changelog entry.
- **Major milestone** — review roadmap phases; update success metrics.
- **Bug fix** — changelog entry with severity + impact.
- **Security update** — record fix + version; flag if user action needed.
- **Breaking change** — explicit changelog notice + migration note.

After any task that produces a non-trivial edit, the lead states:

```
Docs impact: [none | minor | major]
```

If `minor` or `major`, update the docs in the same workflow.

## Update protocol

1. **Before updating:** Read the current state of the doc — do not blindly
   append.
2. **During update:** Preserve formatting, dates, version numbers. Keep
   tense / voice consistent with the rest of the file.
3. **After update:** Verify internal links resolve; verify cross-refs to
   other docs match.
4. **Quality check:** Does the update reflect what actually shipped, or
   what was planned to ship? Be precise.

## Plans directory

Implementation plans live under `plans/` (NOT `docs/`):

```
plans/
└── YYYYMMDD-HHMM-<slug>/
    ├── plan.md                      # 1-page overview + status per phase
    ├── phase-01-<slug>.md           # Detailed phase plan
    ├── phase-02-<slug>.md
    ├── research/                    # Per-researcher reports
    │   └── researcher-<role>-<n>-report.md
    ├── reports/                     # Per-specialist reports during execution
    │   ├── reviewer-YYYY-MM-DD-<slug>.md
    │   └── debugger-YYYY-MM-DD-<slug>.md
    └── visuals/                     # Mermaid / images (if any)
```

### Overview plan (`plan.md`)

- Keep under ~80 lines.
- List each phase with current status (Not Started / In Progress / Done).
- Link to the phase files.
- Capture key dependencies (libraries, env vars, infra prerequisites).

### Phase file (`phase-NN-<slug>.md`)

Sections (sacrifice grammar for concision; omit empty sections):

- **Context links** — related reports, files, docs.
- **Overview** — priority, current status, 2-3 sentence description.
- **Key insights** — findings from research; critical considerations.
- **Requirements** — functional + non-functional.
- **Architecture** — system design, component interactions, data flow.
- **Related code files** — to modify / create / delete.
- **Implementation steps** — numbered, specific.
- **Todo list** — checkbox tracking.
- **Success criteria** — definition of done; how to verify.
- **Risk assessment** — issues + mitigation.
- **Security considerations** — auth/authz, data protection.
- **Next steps** — dependencies, follow-up tasks.

## Reports directory

See `team-coordination-rules.md` → "Reports" for naming + format. In
short: `<role>-<YYYY-MM-DD>-<slug>.md` under `plans/<plan>/reports/` (or
the path the lead injected in the specialist prompt).

## What does NOT go in `docs/`

- Daily scratch notes — those go in the active plan folder.
- Persona definitions — those live in `.claude/persona/`.
- Agent role definitions — those live in `.claude/agents/roles/`.
- Memory bank — `.claude/memory/` (see `.claude/memory/README.md`).
- Throwaway audit output — `.claude/daily-audit/` or `.claude/reports/`.
