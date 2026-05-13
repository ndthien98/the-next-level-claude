# Primary Workflow

This is the default execution loop a lead follows when an inbound task
arrives. Each step has a recommended specialist role; project leads may
deviate when the task obviously doesn't fit.

## 1. Plan

- Before writing code, delegate to a **planner** specialist to produce an
  implementation plan in `plans/<YYYY-MM-DD>-<slug>/`.
- For research-heavy tasks, spawn **researcher** specialists in parallel on
  different sub-topics; the planner consumes their reports.
- Plan deliverable: a `plan.md` overview + per-phase markdown files
  (`phase-01-...`, `phase-02-...`).
- Skip planning ONLY for trivial fixes (single-file, <10 line diff). When in
  doubt, plan.

## 2. Implement

- Lead dispatches **coder** / **backend** / **frontend** / **blockchain** /
  **devops** specialists per the plan's phase ownership.
- Specialists follow the phase's `Todo List` checkbox-by-checkbox.
- **After every file edit**, run the project's compile/typecheck/lint
  command and report the result. Do not stack 10 edits then run lint at
  the end.
- Edit existing files in-place. No `*-v2.ts` parallel files.

## 3. Test

- Delegate to a **qa** specialist to run the project test command on the
  implemented (and simplified) code.
- Tests cover happy path + the explicit edge cases listed in the plan's
  "Risk Assessment" section.
- **Do not** ignore failing tests. Failing tests → fix → re-test loop until
  green. If a test is genuinely wrong, fix the test (with explanation in
  the commit) — never delete it to ship.
- No fake data, mocks-of-mocks, or "TODO: real impl later" stubs just to
  pass CI.

## 4. Review

- After tests pass, delegate to a **reviewer** for a critical pass — code
  quality, security, dead code, test coverage, public API stability.
- Reviewer writes a `reviewer-...md` report; the lead applies the fix loop
  if anything significant comes back.

## 5. Integrate

- Follow the plan's integration phase: API contract checks, backward
  compatibility, doc updates.
- Delegate to a **docs** specialist (or do it inline if minor) to update
  `docs/` and `CHANGELOG.md` per the project's documentation rules.
- **DO NOT commit / push automatically.** Per `CLAUDE.md` → "Hard rule 1",
  remote persistence requires owner approval via Telegram.

## 6. Debug (when reports come in)

- Bug reports / CI failures → delegate to a **debugger** specialist with
  full reproduction details (logs, test output, env info).
- Debugger writes `debugger-...md` with root cause + recommended fix.
- Lead reads the report and dispatches the fix (Step 2 + 3 loop).
- Re-test until clean.

## 7. Visual aids (optional, on request)

- For complex code paths, architecture, or protocol walkthroughs, generate
  a visual explanation (Mermaid + ASCII) and save under the active plan's
  `visuals/` subdirectory.
- Default delivery: image attached via `agents/send-telegram-file.sh`.

## Loop discipline

- Each step's specialist returns a concrete deliverable (file path,
  summary). The lead reads it before moving to the next step.
- If a specialist returns "looks good" without artifacts → ask again with
  specifics, don't assume it ran.
- The lead reports back to the owner via Telegram at meaningful milestones
  (plan ready, implementation done, tests green, review clean, ready for
  approval to commit). Not on every keystroke.
