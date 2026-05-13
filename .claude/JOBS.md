# The Next Level Claude — Background Jobs

All background work runs **inside the Claude Code session**. No pm2, no
systemd, no external daemons. Three mechanisms are used:

1. **`Monitor` tool** — long-running process that streams stdout as
   notifications (each line becomes an event the fleet team-lead acts on).
2. **`CronCreate` tool** — scheduled prompt firing on a cron expression.
3. **`Bash run_in_background`** — fire-and-forget one-off tasks.

When the Claude Code session ends, **all jobs end**. Resuming the fleet
means re-starting these jobs at the top of every new session — see
`agents/fleet-restart.sh` for the checklist.

---

## Job 1 — Telegram poller (Monitor, persistent)

**What:** Long-polls Telegram for inbound messages from the bot's chat.

**How:**
```
Monitor(
  description="The Next Level Claude Telegram poller — inbound feed",
  command="exec python3 ${FLEET_ROOT}/agents/tg-poller.py",
  persistent=true,
  timeout_ms=3600000
)
```

**Behaviour:**
- Each Telegram message becomes a stdout line (JSON).
- Each line surfaces in the conversation as a `[Monitor]` event.
- The fleet team-lead reads each event and routes it:
  - `/<command>` → run the matching script in `agents/`, push result.
  - `@<project> <text>` → SendMessage to `lead-<project>`.
  - plain text → SendMessage to lead of active project.

**Lifetime:** session lifetime. Re-start every new session.

---

## Job 2 — Lead stall watchdog (CronCreate, hourly)

**What:** Every hour, check each project's `inbound-inflight.txt` mtime.
If a lead has been "in-flight" for >60 minutes the lead is likely
stalled — push an alert to Telegram.

**How:**
```
CronCreate(
  cron="7 * * * *",
  prompt="Run the stall watchdog: for each project in .state/projects.json, check projects/<name>/.claude/state/inbound-inflight.txt — if non-empty AND mtime > 60 minutes ago, push a Telegram alert via agents/send-telegram.sh: ⚠️ lead-<name> may be stalled (in-flight since <time>). Report nothing if all leads are healthy.",
  recurring=true
)
```

**Behaviour:**
- Fires on minute 7 of every hour (off the round-minute to avoid
  thundering-herd patterns).
- Only sends a Telegram alert when a stall is detected.
- Reads only disk state — never disturbs a running agent.

**Lifetime:** auto-expires after 7 days; re-create if needed.

---

## Job 4 — Daily fleet audit (CronCreate, daily at 06:07)

**What:** Every day at 06:07 local time, spawn one Opus agent to audit
the entire fleet (state, sub-agents, working dirs, tool-call history, git
activity, system resources) for the previous 24h and propose optimizations.

**How:**
```
CronCreate(
  cron="7 6 * * *",
  recurring=true,
  prompt="DAILY FLEET AUDIT (06:07 local time). Spawn ONE general-purpose
          agent with model=opus and the prompt from
          `${FLEET_ROOT}/agents/daily-audit-prompt.txt`. The agent
          writes the report to `.claude/daily-audit/YYYY-MM-DD.md` and pushes
          a short summary to Telegram via `agents/send-telegram.sh`.
          Read-only audit, no commits or destructive ops."
)
```

**Behaviour:**
- Fires at 06:07 of every day (off the round-minute, off :00).
- Spawns one Opus agent that reads:
  - `.state/*` (projects, identities, fleet.jsonl audit log, send errors)
  - `projects/<name>/.claude/state|logs|plans|research/` (per project)
  - `/tmp/claude-1000/.../tasks/*.output` (tool-call transcripts)
  - `~/.claude/teams|projects|agents|skills|memory/` (global config)
  - Git activity for each repo under `projects/<name>/`
  - System: disk, /tmp, log sizes
- Output: `.claude/daily-audit/YYYY-MM-DD.md` (sections: TL;DR /
  Activity / Findings sev-sorted / Optimization Recommendations /
  Open Questions / Appendices) — the owner Nguyen attribution, no
  AI/persona/agent-id mentions.
- Telegram: short short summary with top-3 findings + top-3
  recommendations.

**Lifetime:** session-only (CronCreate `durable=true` is not persisted
to disk in this environment per the runtime). Auto-expires after 7 days
regardless. **Must be re-armed on every fleet session restart** — see
"Session restart procedure" below.

---

## Job 5 — TeammateIdle hook (settings.json, persistent)

**What:** Fires the instant a project lead goes idle. Checks whether that
lead's `inbound-inflight.txt` is still non-empty — which means it idled
without completing its task — and pushes an immediate Telegram alert.

**How:** Wired in `.claude/settings.json` at fleet scope (not the owner's
global `~/.claude/settings.json`):

```json
{
  "hooks": {
    "TeammateIdle": [{
      "type": "command",
      "command": "${FLEET_ROOT}/.claude/hooks/on-teammate-idle.sh",
      "timeout": 10,
      "async": true
    }]
  }
}
```

**Script:** `.claude/hooks/on-teammate-idle.sh`  
**Logs to:** `.state/hook-idle.log`

**Behaviour:**
- Reads stdin JSON (common hook payload: `session_id`, `cwd`, etc.).
- Derives project name from `cwd` path.
- If `projects/<name>/.claude/state/inbound-inflight.txt` is non-empty
  → pushes `⚠️ [fleet] lead-<name> went idle but inflight is non-empty`
  via `agents/send-telegram.sh`.
- Always exits 0 — never blocks the idle transition.
- Fail-soft: Telegram failures logged to `.state/hook-idle.log`, not fatal.

**Relationship to Job 2 (hourly watchdog):** Complementary. Job 5 catches
stalls within seconds; Job 2 is the backup that catches cases where the
hook itself was not running (e.g. session restart gap). The hourly cron
can remain as a safety net but is no longer the primary stall detector.

**Lifetime:** Persistent — wired into settings.json, fires automatically
for the lifetime of the Claude Code session. No re-arm required per restart.

---

## Job 6 — TaskCompleted hook (settings.json, persistent)

**What:** Appends a JSONL audit record to `.state/fleet.jsonl` every time
any task is marked complete anywhere in the fleet session.

**How:** Wired alongside Job 5 in `.claude/settings.json`:

```json
{
  "hooks": {
    "TaskCompleted": [{
      "type": "command",
      "command": "${FLEET_ROOT}/.claude/hooks/on-task-completed.sh",
      "timeout": 10,
      "async": true
    }]
  }
}
```

**Script:** `.claude/hooks/on-task-completed.sh`  
**Appends to:** `.state/fleet.jsonl`  
**Logs to:** `.state/hook-task-completed.log`

**Record format (JSONL):**
```json
{
  "timestamp": "2026-05-13T00:00:00Z",
  "event": "TaskCompleted",
  "session_id": "<uuid>",
  "project": "<name or unknown>",
  "cwd": "/path/to/project",
  "permission_mode": "default"
}
```

**Behaviour:**
- Reads stdin JSON payload, extracts common hook fields.
- Derives project name from `cwd`.
- Appends one JSONL record to `.state/fleet.jsonl` (same file used by
  the team-lead for general audit events).
- Always exits 0 — never blocks task completion.
- Fail-soft: if `jq` fails, writes a minimal fallback record; never crashes.

**Relationship to Job 4 (daily audit):** The daily audit agent reads
`.state/fleet.jsonl` — Job 6 enriches that feed with task-level
completion events for finer-grained activity history.

**Lifetime:** Persistent — same as Job 5. No re-arm required per restart.

---

## Job 3 — One-off scheduled reminders (CronCreate, recurring=false)

**What:** Ad-hoc "remind me at X" requests.

**How:**
```
CronCreate(
  cron="<minute> <hour> <dom> <month> *",
  prompt="<the reminder content>",
  recurring=false
)
```

**Lifetime:** fires once, then auto-deletes.

---

## Session restart procedure

When a new Claude Code session starts, the fleet team-lead must:

```
# 1. Run the restart checklist (informational)
Bash("bash agents/fleet-restart.sh")

# 2. Re-create the Agent Team
TeamCreate(team_name="next-level-claude", description="Personal coding fleet")
Bash("bash agents/save-session.sh team next-level-claude")

# 3. Re-spawn each lead (see agents/respawn-leads.sh for snippets)
Agent(name="lead-<name>", model="opus", team_name="next-level-claude", ...)
Bash("bash agents/save-session.sh lead <name> <agent-id>")

# 4. Start the Telegram poller (Job 1)
Monitor(persistent=true, timeout_ms=3600000,
        command="exec python3 agents/tg-poller.py",
        description="The Next Level Claude Telegram poller — inbound feed")

# 5. Re-arm the stall watchdog (Job 2)
CronCreate(cron="7 * * * *",
           prompt="<see Job 2 prompt above>",
           recurring=true)

# 6. Re-arm the daily fleet audit (Job 4)
CronCreate(cron="7 6 * * *",
           prompt="<see Job 4 prompt above>",
           recurring=true)
```

---

## File ownership enforcement (hook + convention)

**What:** Warns when a specialist agent edits a file outside its declared
`File ownership:` globs. This surfaces races without blocking work.

**How it works:**

1. **Convention (mandatory):** Every specialist prompt must include a
   `File ownership: <glob patterns>` line. The lead verifies disjoint
   ownership before any parallel dispatch. See fleet `CLAUDE.md` →
   "File ownership — parallel dispatch safety" and `lead.md` →
   "Parallel dispatch — file ownership" for full protocol.

2. **Hook (soft-fail warning):** A `PreToolUse` hook fires before every
   Edit/Write call. If the environment variable `CLAUDE_FILE_OWNERSHIP`
   is set (to the space-separated globs declared in the specialist prompt)
   and the target file path does not match any of those globs, the hook
   emits a warning to stderr. The edit is never blocked — exit code is
   always 0.

   If `CLAUDE_FILE_OWNERSHIP` is absent the hook is a no-op (fail-soft).

**Hook script:** `.claude/hooks/check-file-ownership.sh`

**Wired in** `.claude/settings.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${FLEET_ROOT}/.claude/hooks/check-file-ownership.sh",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

**Hook event used:** `PreToolUse` with matcher `Edit|Write`.

**Payload fields used by the hook:**
- `tool_input.file_path` — the file being edited (from `jq`)
- `tool_name` — `Edit` or `Write` (for the warning message)
- `CLAUDE_FILE_OWNERSHIP` env var — space-separated glob list declared
  by the specialist; absent → hook allows silently

**Lifecycle:** Passive background enforcement — no session startup or
restart action required. The hook fires automatically for every
Edit/Write in any Claude session running under the fleet project dir.

---

## Why no pm2?

Earlier versions used pm2 to keep the poller alive across Claude sessions.
That created two control planes (pm2 process state + Claude session state)
and the operator had to remember both. By moving everything inside Claude:

- One restart procedure (the snippet above)
- One log stream (Claude's notification feed)
- One stop signal (closing the Claude session)
- No external dependency to install

Trade-off: if the Claude session dies for any reason, all jobs die with it.
Acceptable here because routing requires the Claude session anyway —
without it, slash commands and inbound forwarding stall regardless.
