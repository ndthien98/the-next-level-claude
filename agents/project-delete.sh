#!/usr/bin/env bash
# Archive a project (never hard-deletes).
# Usage: project-delete.sh <name>
set -u
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
REG="$FLEET/.state/projects.json"
ACTIVE_FILE="$FLEET/.state/active-project.txt"

NAME="${1:-}"
[ -z "$NAME" ] && { echo "usage: project-delete.sh <name>" >&2; exit 2; }

# Validate exists
EXISTS=$(jq -r --arg n "$NAME" '.projects[] | select(.name==$n) | .name' "$REG" 2>/dev/null)
[ -z "$EXISTS" ] && { echo "✗ project '$NAME' not found in registry" >&2; exit 2; }

# Refuse if active
ACTIVE=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
[ "$ACTIVE" = "$NAME" ] && {
  echo "✗ '$NAME' is the active project. Switch away first:"
  echo "  bash agents/project-switch.sh <other-project>"
  exit 2
}

DST="$FLEET/projects/$NAME"
ARCHIVE_BASE="$FLEET/projects/_archived"
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
ARCHIVE="$ARCHIVE_BASE/${NAME}-${TIMESTAMP}"

mkdir -p "$ARCHIVE_BASE"
if [ -d "$DST" ]; then
  mv "$DST" "$ARCHIVE"
  echo "→ archived workspace to $ARCHIVE"
else
  echo "  (workspace dir not found — skipping move)"
fi

# Remove from registry
TMP=$(mktemp)
jq --arg n "$NAME" 'del(.projects[] | select(.name==$n))' "$REG" > "$TMP" && mv "$TMP" "$REG"
echo "→ removed '$NAME' from projects.json"

cat <<EOF

✅ Project '$NAME' archived.

Workspace: $ARCHIVE
To restore: mv $ARCHIVE $DST
            then manually re-add to projects.json

IMPORTANT: Send shutdown_request to lead-$NAME from your Claude session
           if the lead is still running:
  SendMessage(to:"lead-$NAME", message={"type":"shutdown_request",...})
EOF
