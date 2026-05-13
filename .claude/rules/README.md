# Fleet Rules

This directory holds the engineering rules every agent in the fleet
follows. They are project-agnostic — per-project overrides live in
`projects/<name>/.claude/CLAUDE.md`.

| File | Audience | What it covers |
|---|---|---|
| `development-rules.md`     | every agent | Engineering ground-truth (YAGNI/KISS/DRY, file size, security, commits) |
| `orchestration-protocol.md`| project leads | How leads delegate to specialists (context block, parallel safety) |
| `team-coordination-rules.md`| specialists | File ownership, git safety, reports, idle state, conflict resolution |
| `primary-workflow.md`      | project leads | Default loop: Plan → Implement → Test → Review → Integrate → Debug |
| `documentation-management.md`| every agent | `docs/`, `plans/`, `reports/` conventions; what goes where |

These rules are read by leads on spawn (see the read-order in
`.claude/skills/fleet-spawn-lead/SKILL.md`). To soften a rule for one
project, override it in that project's `CLAUDE.md` — do not edit the
fleet rules in-place.

## Adding a new rule file

1. Add `.claude/rules/<name>.md` here.
2. Reference it in the spawn read-order (`fleet-spawn-lead/SKILL.md`) so
   newly-spawned leads pick it up automatically.
3. Add a row to the table above.
4. If it constrains specialist behavior, also add a one-line summary to
   `.claude/agents/roles/_team-comms.md` (template) so role files inherit.
