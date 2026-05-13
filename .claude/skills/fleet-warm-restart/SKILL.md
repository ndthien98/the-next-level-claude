---
name: fleet-warm-restart
description: "Procedure for warm-restarting the claudistant fleet after a session crash or restart. Runs 5 steps: show disk state, re-create team, re-spawn leads, start Telegram poller, arm stall watchdog."
---

# Fleet Warm Restart

Run this sequence when starting a new Claude Code session after a crash or restart.

```
# 1) Show what state is on disk
Bash("bash agents/fleet-restart.sh")

# 2) Re-create the team (required each new Claude Code session)
TeamCreate(team_name="claudistant", description="Personal coding fleet")
Bash("bash agents/save-session.sh team claudistant")

# 3) Re-spawn any leads
Bash("bash agents/respawn-leads.sh")
# → paste each Agent() call (see skill: /skill fleet-spawn-lead), then:
Bash("bash agents/save-session.sh lead <name> <agent-id>")

# 4) Start the Telegram poller (Job 1)
Monitor(
  description="claudistant Telegram poller — inbound feed",
  command="exec python3 agents/tg-poller.py",
  persistent=true,
  timeout_ms=3600000
)

# 5) Arm the hourly stall watchdog (Job 2)
CronCreate(
  cron="7 * * * *",
  recurring=true,
  prompt="Stall watchdog: for each project in .state/projects.json, check projects/<name>/.claude/state/inbound-inflight.txt — if non-empty AND mtime > 60 minutes ago, push a Telegram alert via agents/send-telegram.sh saying lead-<name> may be stalled."
)
```
