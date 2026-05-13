# Development Rules

These rules apply to every agent (lead, specialist, audit-monitor) operating
inside this fleet. They are the engineering ground-truth — softened only on
explicit owner approval.

**Core principles:** **YAGNI** (You Aren't Gonna Need It) · **KISS** (Keep It
Simple, Stupid) · **DRY** (Don't Repeat Yourself).

## General

- **File naming.** Use kebab-case with meaningful, descriptive names. Long is
  fine — agents grep by name first, and self-describing names save reads.
- **File size.** Keep individual code files under ~200 lines for context
  efficiency. Split large modules; extract utilities; compose over inherit.
- **Tool-first research.** When you need docs, prefer in this order:
  `Read` (local) → `Bash` (git/CLI) → `Glob`/`Grep` → `WebFetch` → `WebSearch`
  → Context7 MCP (if configured). Never fabricate API signatures from
  training-cutoff knowledge.
- **No simulation.** Implement real code, not stubs that "look right". If a
  dependency is missing, report it — don't mock the dependency away.
- **Read code standards.** Each project may define `docs/code-standards.md`,
  `docs/architecture.md`, or similar. Read these before editing.

## Code Quality

- **Compile / type-check / lint** must pass — that's the floor. Linting nits
  are negotiable; syntax / type errors are not.
- **Readability over micro-style.** Optimize for the next agent that reads
  this code, not for a style guide.
- **Error handling.** Wrap risky operations in try/catch; surface the real
  error; never swallow silently.
- **Security defaults.** Never log secrets. Never commit `.env`, credentials,
  tokens, private keys. Use the logger configured by the project (not
  `console.log` / `print`) for runtime output.
- **Reviewer pass.** After non-trivial changes, the lead should delegate a
  reviewer specialist before declaring done.

## Pre-commit / Pre-push

- Run the project's lint command before committing.
- Run the project's test command before pushing.
- Do **not** ignore failing tests to ship — fix or mark expected-fail with
  explanation.
- Conventional Commits: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`,
  `test:`, `chore:`. Imperative, ≤50 chars.
- **No AI / persona / agent-id attribution** in commit messages, code
  comments, doc headers, or PR descriptions. See `CLAUDE.md` → "Hard rule 2".

## Code Implementation

- Edit existing files directly — do **not** create `enhanced-foo.ts` /
  `foo-v2.ts` parallel files just to avoid touching the original.
- Handle edge cases explicitly (null / empty / out-of-range / network
  failure). Document the choice in a comment if it's non-obvious.
- Match the project's existing architectural patterns. If you disagree with
  a pattern, raise it with the owner — don't silently introduce a third
  pattern.

## Documentation Hygiene

- **No markdown files in the project root** unless they're spec-critical
  (`README.md`, `LICENSE`, `CHANGELOG.md`, top-level `CLAUDE.md`).
- Generated docs (research notes, ADRs, design specs, meeting notes,
  audit reports) go under `<project>/.claude/` or `<project>/docs/`.
- Each project's `.claude/CLAUDE.md` is the source of truth for that
  project's local conventions.
