#!/usr/bin/env node
/**
 * UserPromptSubmit Hook — Inject a terse engineering-rules reminder
 *
 * Fires:   on every user prompt submission
 * Purpose: nudge the lead with the YAGNI / KISS / DRY ground-truth and
 *          surface any active plan files in `./plans/` so the lead doesn't
 *          forget mid-task. Throttled to every 5th prompt to keep noise low.
 * Exit:    0 always (non-blocking, fail-open)
 *
 * Configure in `.claude/settings.json`:
 *   "UserPromptSubmit": [{ "hooks": [{ "type": "command",
 *     "command": "${FLEET_ROOT}/.claude/hooks/dev-rules-reminder.cjs",
 *     "timeout": 5 }] }]
 */

try {
  const fs = require('fs');
  const path = require('path');
  const os = require('os');

  const stdin = fs.readFileSync(0, 'utf-8').trim();
  if (!stdin) process.exit(0);

  // Throttle: only inject once every 5 prompts (tracked via tmp counter).
  const tmpFile = path.join(os.tmpdir(), 'fleet-dev-rules-count.json');
  let count = 0;
  try {
    const data = JSON.parse(fs.readFileSync(tmpFile, 'utf-8'));
    count = (data.count || 0) + 1;
  } catch {
    /* first run */
  }
  fs.writeFileSync(tmpFile, JSON.stringify({ count, ts: Date.now() }));
  if (count % 5 !== 1) process.exit(0);

  // Surface active plans if `./plans/` exists.
  let planContext = '';
  const plansDir = path.join(process.cwd(), 'plans');
  if (fs.existsSync(plansDir)) {
    try {
      const plans = fs
        .readdirSync(plansDir)
        .filter((f) => f.endsWith('.md') || /^\d{8}/.test(f));
      if (plans.length > 0) {
        planContext = `\nActive plans in ./plans/: ${plans.slice(0, 5).join(', ')}${plans.length > 5 ? ` (+${plans.length - 5} more)` : ''}`;
      }
    } catch {
      /* ignore */
    }
  }

  const reminder = `[Dev Rules] YAGNI · KISS · DRY · Files < 200 lines · kebab-case names · Tool-first research · No console.log (use the project logger)${planContext}`;
  console.log(reminder);
  process.exit(0);
} catch {
  process.exit(0); // fail-open
}
