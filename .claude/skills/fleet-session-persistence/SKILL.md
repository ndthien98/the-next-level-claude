---
name: fleet-session-persistence
description: "Reference for where fleet session IDs are stored and how to save them after spawning agents or creating teams. Call immediately after any Agent() or TeamCreate() call."
---

# Fleet Session ID Persistence

Every agent's ID must be saved immediately after spawn. This enables
fleet restart without losing state.

## Save commands

```
# After spawning any lead:
Bash("bash agents/save-session.sh lead <name> <returned-agent-id>")

# After TeamCreate:
Bash("bash agents/save-session.sh team claudistant")
```

## Storage locations

| File | Contents |
|---|---|
| `.state/main-session.id` | This Claude Code session ID |
| `.state/team.id` | Agent Team ID |
| `.state/projects.json` | `lead_agent_id` per project |
| `projects/<name>/.claude/sessions/lead.uuid` | Lead session file |
| `projects/<name>/.claude/sessions/<role>.uuid` | Specialist session files |
