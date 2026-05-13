---
description: "Interactive first-time fleet setup. Prompts for Telegram bot token, owner id, owner identity, fleet name. Validates token, writes .env, seeds state, sends a welcome message."
---

# /onboard

Bootstrap a fresh The Next Level Claude fleet on this machine.

This slash command launches the same flow as `bash agents/onboard.sh`.
It is **idempotent** — re-running keeps existing values as defaults
(press Enter to keep, type new to change).

## What it does

1. Validates `.env` template + dependencies (curl, jq, python3).
2. Prompts for Telegram bot token; validates via `getMe`.
3. Prompts for Telegram owner user id (numeric).
4. Prompts for allowed chat id (default: owner id for 1:1 DM).
5. Prompts for owner display name + email (artifact identity).
6. Prompts for fleet name (default: `next-level-claude`).
7. Writes `.env` (chmod 600) and backs up any prior version.
8. Seeds `.state/projects.json`, `.state/identities.json`,
   `.state/active-project.txt`.
9. Rewrites absolute hook paths in `.claude/settings.json`.
10. Registers 8 Telegram slash commands via `setMyCommands`.
11. Sends a "fleet online" welcome message to the chat.
12. Prints next steps.

## Run it

```
Bash("bash agents/onboard.sh")
```

After this finishes, follow the printed next steps. The full
first-time bootstrap procedure is documented at
`/skill fleet-first-time-setup`.

## When NOT to use this

- The fleet is already up and you only want to add a project — use
  `/project_create <name>` instead.
- You want to restart the fleet after a session crash — use
  `/skill fleet-warm-restart` instead.

## Re-run scenarios

- You moved the fleet folder → re-run to rewrite settings.json hook paths.
- You rotated the bot token → re-run, paste new token, keep other values.
- You changed your email or display name → re-run, update those fields.
