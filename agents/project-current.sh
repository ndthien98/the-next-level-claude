#!/usr/bin/env bash
# Print the active project + brief state.
set -euo pipefail
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
ACTIVE_FILE="$FLEET/.state/active-project.txt"
REG="$FLEET/.state/projects.json"
ACTIVE="$(cat "$ACTIVE_FILE" 2>/dev/null || echo "")"

if [ -z "$ACTIVE" ]; then
  echo "🤷 No active project. Use /project_switch <name>."
  exit 0
fi

PROJ_DIR="$FLEET/projects/$ACTIVE"
[ ! -d "$PROJ_DIR" ] && { echo "⚠️ active=$ACTIVE but workspace missing: $PROJ_DIR"; exit 1; }

echo "★ active: $ACTIVE"
echo
INFLIGHT=$(cat "$PROJ_DIR/.claude/state/inbound-inflight.txt" 2>/dev/null)
QLEN=$(wc -l < "$PROJ_DIR/.claude/state/inbound-queue.jsonl" 2>/dev/null || echo 0)
[ -z "$INFLIGHT" ] && INFLIGHT="idle"
echo "queue:    $INFLIGHT / $QLEN pending"

if [ -f "$REG" ]; then
  PERSONA=$(jq -r --arg n "$ACTIVE" '.projects[] | select(.name==$n) | .persona // "—"' "$REG")
  echo "persona:  $PERSONA"
fi
echo "dir:      $PROJ_DIR"
