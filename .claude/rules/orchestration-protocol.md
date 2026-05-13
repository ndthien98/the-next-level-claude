# Orchestration Protocol

When a lead spawns specialists via the `Agent` tool, the prompt MUST carry
enough context for the specialist to act without follow-up questions.

## Delegation context (mandatory)

Every `Agent()` prompt sent from a lead must include:

1. **Work context path.** The absolute path to the project the specialist
   should `cd` into. Specialists never operate outside this directory.
2. **Reports path.** Where the specialist saves its artifacts —
   conventionally `<work_context>/plans/reports/` (or `.claude/reports/`
   if the project prefers that layout).
3. **Plans path.** `<work_context>/plans/` for active implementation plans.
4. **File ownership.** Glob patterns the specialist may edit. Empty for
   read-only roles (reviewer, researcher, debugger).
5. **Reply format.** What the lead expects back — terse text? JSON?
   diff summary? path to a report file?

**Template:**

```
Task: <one-line objective>

Work context: /abs/path/to/project
Reports path: /abs/path/to/project/plans/reports
Plans path:   /abs/path/to/project/plans
File ownership: src/api/* src/models/*
Reply with: 1-paragraph summary + path to the report you wrote.
```

If CWD differs from the work context (i.e. the lead is in a sibling
directory), always use the **work context** path — never CWD.

## Sequential chaining

Chain specialists when there is a real data dependency:

- **Planning → Implementation → Testing → Review** — for feature work where
  later stages consume earlier outputs.
- **Research → Design → Code → Documentation** — for new components.

Each stage completes fully before the next starts. Pass outputs explicitly
in the next prompt (don't assume the next specialist will go read the prior
one's report unprompted — name the file path).

## Parallel execution

Spawn specialists concurrently when they are truly independent:

- Code + Tests + Docs split (different file ownership sets).
- Cross-platform feature work (iOS vs Android, web vs mobile).
- Multi-component features where each component owns its own subtree.

**Critical:** before spawning in parallel, verify file ownership sets are
**disjoint**. Overlapping globs → sequence them; last-write-wins will eat
work otherwise. See `team-coordination-rules.md` → "File Ownership" for the
enforcement convention.

## Anti-patterns

- Lead doing 4+ bulk Bash reads in a row when a specialist could have done
  it (you're working serially when you could be parallel).
- Spawning a specialist for a task the lead could finish in one tool call
  (overhead > work).
- Sending the same prompt to two specialists "to compare answers" without
  declaring it as a deliberate dual-track experiment.

## Agent Teams (advanced)

For multi-session collaboration where teammates persist across user turns
(e.g. a long-running reviewer that watches commits), see Claude Code's
Agent Teams documentation. Default fleet workflow does NOT require Agent
Teams — leads use the simpler `Agent` tool for ephemeral specialists.
