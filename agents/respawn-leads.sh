#!/usr/bin/env bash
# Read projects.json and report which leads are registered.
# Outputs the exact Agent() call needed for any lead missing a live agent_id.
# Run this at the start of every new Claude Code session.
#
# Usage: bash agents/respawn-leads.sh

set -u
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
REG="$FLEET/.state/projects.json"

[ -f "$FLEET/.env" ] && { set -a; . "$FLEET/.env"; set +a; }
FLEET_NAME="${FLEET_NAME:-claudistant}"

[ ! -f "$REG" ] && { echo "✗ projects.json not found"; exit 2; }

PROJECTS=$(jq -r '.projects[] | [.name, (.lead_agent_id // "null"), .dir] | @tsv' "$REG")

if [ -z "$PROJECTS" ]; then
  echo "No projects registered. Run: bash agents/project-create.sh <name>"
  exit 0
fi

echo "=== Lead Status ==="
echo ""

NEED_SPAWN=()
while IFS=$'\t' read -r NAME AGENT_ID DIR; do
  SESSION_FILE="$DIR/.claude/sessions/lead.uuid"
  SAVED_ID=$(cat "$SESSION_FILE" 2>/dev/null | tr -d '[:space:]')

  if [ "$AGENT_ID" != "null" ]; then
    echo "✓ lead-$NAME  agent_id=$AGENT_ID"
    [ -n "$SAVED_ID" ] && echo "           session=$SAVED_ID"
  else
    echo "✗ lead-$NAME  NOT SPAWNED"
    NEED_SPAWN+=("$NAME")
  fi
done <<< "$PROJECTS"

if [ ${#NEED_SPAWN[@]} -eq 0 ]; then
  echo ""
  echo "All leads registered. Verify they are alive by sending a ping via SendMessage."
  echo "If any lead is unresponsive, re-spawn with:"
else
  echo ""
  echo "=== Spawn required for: ${NEED_SPAWN[*]} ==="
fi

echo ""
echo "--- Agent() spawn snippets (copy into Claude session) ---"
echo ""
while IFS=$'\t' read -r NAME AGENT_ID DIR; do
  cat <<SNIPPET
Agent(
  description="Lead for project $NAME",
  subagent_type="general-purpose",
  model="opus",
  name="lead-$NAME",
  team_name="$FLEET_NAME",
  run_in_background=True,
  prompt=\"\"\"Lead for project $NAME.

FIRST: cd $DIR
Stay in this directory for ALL operations.

Then read: CLAUDE.md, .claude/persona/IDENTITY.md, SOUL.md, USER.md,
.claude/agents/roles/lead.md, .claude/agents/roles/_team-comms.md

Ack in persona voice (one sentence), then idle.\"\"\"
)
# After spawn: bash agents/save-session.sh lead $NAME <returned-agent-id>

SNIPPET
done <<< "$PROJECTS"
