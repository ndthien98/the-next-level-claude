#!/usr/bin/env bash
# Switch the fleet's active project.
# Usage: project-switch.sh <name>
set -u
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
REG="$FLEET/.state/projects.json"
ACTIVE_FILE="$FLEET/.state/active-project.txt"

NAME="${1:-}"
[ -z "$NAME" ] && { echo "usage: project-switch.sh <name>" >&2; exit 2; }
[ ! -f "$REG" ] && { echo "✗ no projects registered yet" >&2; exit 2; }

EXISTS=$(jq -r --arg n "$NAME" '.projects | map(.name) | index($n)' "$REG")
if [ "$EXISTS" = "null" ]; then
  echo "✗ project '$NAME' not found. Available:"
  jq -r '.projects[].name' "$REG" | sed 's/^/  - /'
  exit 2
fi

echo "$NAME" > "$ACTIVE_FILE"
echo "✓ active project → $NAME"
