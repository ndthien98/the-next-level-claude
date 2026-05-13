---
name: fleet-first-time-setup
description: "One-time bootstrap procedure for setting up the claudistant fleet from scratch. Runs 5 steps: bootstrap fleet, create projects, create team and spawn leads, switch active project, start poller and watchdog."
---

# Fleet First-Time Setup

Run once after editing `.env` and creating your first project.

```
# 1) Bootstrap fleet (run once after editing .env)
Bash("bash agents/setup-fleet.sh")

# 2) Create projects
Bash("bash agents/project-create.sh my-first-project")

# 3) Create team + spawn leads
TeamCreate(team_name="${FLEET_NAME:-claudistant}", description="Personal coding fleet")
Bash("bash agents/save-session.sh team ${FLEET_NAME:-claudistant}")
# Spawn leads per skill: /skill fleet-spawn-lead, then:
Bash("bash agents/save-session.sh lead my-first-project <agent-id>")

# 4) Switch active project
Bash("bash agents/project-switch.sh my-first-project")

# 5) Start poller + watchdog inside this Claude session (see .claude/JOBS.md)
Monitor(persistent=true, timeout_ms=3600000,
        description="claudistant Telegram poller — inbound feed",
        command="exec python3 agents/tg-poller.py")
CronCreate(cron="7 * * * *", recurring=true,
           prompt="<watchdog prompt — see .claude/JOBS.md Job 2>")
```
