#!/usr/bin/env bash
# Save a session/agent ID to the correct location.
# Usage:
#   save-session.sh main <session-id>
#   save-session.sh lead <project-name> <agent-id>
#   save-session.sh specialist <project-name> <role> <agent-id>
#   save-session.sh team <team-id>

set -euo pipefail
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
REG="$FLEET/.state/projects.json"

TYPE="${1:-}"
case "$TYPE" in
  main)
    ID="${2:-}"
    [ -z "$ID" ] && { echo "usage: save-session.sh main <session-id>" >&2; exit 2; }
    echo "$ID" > "$FLEET/.state/main-session.id"
    echo "✓ main session → $FLEET/.state/main-session.id"
    ;;
  team)
    ID="${2:-}"
    [ -z "$ID" ] && { echo "usage: save-session.sh team <team-id>" >&2; exit 2; }
    echo "$ID" > "$FLEET/.state/team.id"
    echo "✓ team id → $FLEET/.state/team.id"
    ;;
  lead)
    NAME="${2:-}"; AGENT_ID="${3:-}"
    [ -z "$NAME" ] || [ -z "$AGENT_ID" ] && {
      echo "usage: save-session.sh lead <project-name> <agent-id>" >&2; exit 2
    }
    # Write to sessions file
    PROJ_DIR=$(jq -r --arg n "$NAME" '.projects[] | select(.name==$n) | .dir' "$REG" 2>/dev/null)
    [ -z "$PROJ_DIR" ] && { echo "✗ project '$NAME' not in registry" >&2; exit 2; }
    mkdir -p "$PROJ_DIR/.claude/sessions"
    echo "$AGENT_ID" > "$PROJ_DIR/.claude/sessions/lead.uuid"
    # Also persist to projects.json
    TMP=$(mktemp)
    jq --arg n "$NAME" --arg id "$AGENT_ID" \
      '(.projects[] | select(.name==$n)).lead_agent_id = $id' "$REG" > "$TMP" && mv "$TMP" "$REG"
    echo "✓ lead-$NAME agent_id → $PROJ_DIR/.claude/sessions/lead.uuid + projects.json"
    ;;
  specialist)
    NAME="${2:-}"; ROLE="${3:-}"; AGENT_ID="${4:-}"
    [ -z "$NAME" ] || [ -z "$ROLE" ] || [ -z "$AGENT_ID" ] && {
      echo "usage: save-session.sh specialist <project-name> <role> <agent-id>" >&2; exit 2
    }
    PROJ_DIR=$(jq -r --arg n "$NAME" '.projects[] | select(.name==$n) | .dir' "$REG" 2>/dev/null)
    [ -z "$PROJ_DIR" ] && { echo "✗ project '$NAME' not in registry" >&2; exit 2; }
    mkdir -p "$PROJ_DIR/.claude/sessions"
    echo "$AGENT_ID" > "$PROJ_DIR/.claude/sessions/$ROLE.uuid"
    echo "✓ $ROLE specialist for $NAME → $PROJ_DIR/.claude/sessions/$ROLE.uuid"
    ;;
  *)
    echo "usage: save-session.sh <main|team|lead|specialist> ..." >&2
    exit 2
    ;;
esac
