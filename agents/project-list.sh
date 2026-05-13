#!/usr/bin/env bash
# List all projects in the fleet with their state.
set -u
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
REG="$FLEET/.state/projects.json"
ACTIVE_FILE="$FLEET/.state/active-project.txt"
ACTIVE="$(cat "$ACTIVE_FILE" 2>/dev/null || echo "")"

[ ! -f "$REG" ] && { echo "📂 No projects yet. Use /project_create <name>."; exit 0; }
COUNT=$(jq -r '.projects | length' "$REG")
[ "$COUNT" = "0" ] && { echo "📂 No projects yet. Use /project_create <name>."; exit 0; }

echo "📂 Projects ($COUNT)"
echo
jq -r --arg active "$ACTIVE" '
  .projects[] |
  ((if .name == $active then "★ " else "  " end) +
   .name +
   "  (" + (.persona // "no persona") + ")")
' "$REG" | while read -r line; do
  echo "$line"
done

echo
echo "★ = active project (default routing target)"
echo "Use /project_switch <name> to change active."
