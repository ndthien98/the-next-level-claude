---
name: fleet-spawn-lead
description: "Procedure for spawning a new project lead agent in The Next Level Claude fleet. Use when creating a new project lead or re-spawning an existing one."
---

# Spawn a Project Lead

Each project gets one persistent lead. The lead `cd`s into its own
workspace and stays there for the lifetime of the session.

```
Agent(
  description="Lead for project <name>",
  subagent_type="general-purpose",
  model="opus",                          # CLAUDE_LEAD_MODEL
  team_name="$FLEET_NAME",
  name="lead-<name>",
  prompt="Lead for project <name>.

          FIRST: cd ${FLEET_ROOT}/projects/<name>
          Stay in this directory for ALL operations. Never read or
          write files outside it.

          Then read (in order):
            CLAUDE.md
            .claude/persona/IDENTITY.md      (if present)
            .claude/persona/SOUL.md          (if present)
            .claude/persona/USER.md          (if present)
            .claude/agents/roles/lead.md     (if present)
            .claude/agents/roles/_team-comms.md (if present)

          If the project workspace contains an existing repo (a sub-dir
          or symlink with its own .claude/ layout), follow that repo's
          conventions when they conflict with the fleet template.

          HARD RULE: never auto-commit / push / write to remote.
          Workspace edits OK; persistence to git / GitHub / Jira
          requires the owner's explicit approval via Telegram first.

          Ack in persona voice (one sentence), then idle.

          Team-lead will SendMessage inbound [INBOUND]...[/INBOUND]
          blocks. Handle inline OR delegate to specialists via Agent
          tool — always pass the absolute project path as the first
          instruction in each specialist prompt so they cd to it.
          Pick model per role (read from .env CLAUDE_MODEL_<ROLE>).
          Push replies via .claude/agents/send-telegram.sh — chat id
          resolves from fleet .env, don't override."
)
```

Lead is addressable via `SendMessage(to:"lead-<name>")`.

After spawning, save the session ID immediately:
```
Bash("bash agents/save-session.sh lead <name> <returned-agent-id>")
```
