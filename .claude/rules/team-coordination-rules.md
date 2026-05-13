# Team Coordination Rules

> These rules apply to specialists spawned by a project lead. They define how
> peers cooperate without stepping on each other's edits or commits.

## File ownership (CRITICAL)

- Every specialist task MUST declare `File ownership: <glob1> <glob2> ...`
  in its prompt. The lead is responsible for declaring this.
- A specialist MUST NOT edit any file outside its declared ownership. The
  PreToolUse hook at `.claude/hooks/check-file-ownership.sh` emits a stderr
  warning when a specialist crosses the boundary; the lead should treat
  these warnings as critical.
- **Tester rule:** QA/test specialists own test files only. They read
  implementation files but never edit them — bugs caught by tests are
  reported back to the lead, who dispatches a fix.
- If two specialists need the same file: STOP and escalate to the lead. Do
  not race.

## Git safety

- Prefer git worktrees for multi-track implementation work — each specialist
  in its own worktree eliminates conflicts. Pass `isolation: "worktree"` in
  the `Agent()` call.
- Never force-push from a specialist session.
- Commit frequently with descriptive Conventional Commits messages.
- Pull before push.
- **Remote persistence (commit, push, PR creation, Jira writes) ALWAYS
  requires owner approval per `CLAUDE.md` → "Hard rule 1".** Workspace edits
  are fine; pushing them anywhere requires explicit Telegram confirmation.

## Communication

- Use `SendMessage(type: "message")` for direct peer-to-peer notes.
- Use `SendMessage(type: "broadcast")` ONLY for critical blocking issues
  that affect the whole team.
- Mark tasks `completed` via `TaskUpdate` BEFORE notifying the lead — never
  "done" without the status update.
- Plain text only — no embedded JSON status objects, no decorative banners.
  The lead parses prose.

## Reports

- Save reports under `<work_context>/plans/reports/` (or the path the lead
  injected in your prompt).
- File naming: `<role>-<YYYY-MM-DD>-<slug>.md` (e.g.
  `reviewer-2026-05-13-auth-flow.md`).
- Sacrifice grammar for concision. Open with a 1-line verdict
  (`PASS` / `FAIL` / `BLOCKED`), then bullets. List unresolved questions
  at the end so the lead can act on them.
- **No persona / agent-id attribution in the report itself.** Per
  `CLAUDE.md` → "Hard rule 2", the report is an artifact.

## Task claiming (Agent Team mode)

When operating under the Claude Code Agent Teams primitive:

- Claim the lowest-ID unblocked task first (earlier tasks tend to set up
  context for later ones).
- After completing a task, check `TaskList` for newly unblocked work.
- Set status to `in_progress` before starting work; `completed` only after
  the change is on disk and verified.
- If all tasks are blocked, message the lead and offer to help unblock.

## Plan-approval flow

When a specialist needs lead approval before applying changes (large
refactors, ambiguous locations, multi-file rewrites):

1. Research and draft a plan — **read-only**, no file edits.
2. Submit via `ExitPlanMode` (Agent Teams) OR plain message back to lead
   with the plan inline.
3. Wait for the lead's `approve` / `revise` / `reject`.
4. On `revise`: incorporate feedback and re-submit.
5. On `approve`: apply changes; on `reject`: stand down.

## Conflict resolution

- Two specialists need the same file → escalate to lead immediately.
- A specialist's plan rejected twice → lead takes over that task.
- Conflicting findings between reviewers → lead synthesizes and documents
  the disagreement in the report.
- Blocked by another specialist's incomplete work → message them directly
  first; escalate to lead if unresponsive within reasonable time.

## Idle state is normal

- Going idle after sending a reply is NORMAL — not an error or disconnect.
- Idle means "waiting for input" — the next message wakes the specialist.
- Don't treat an idle notification as a completion signal. Check task
  status / file evidence instead.
