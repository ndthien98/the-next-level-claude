#!/usr/bin/env bash
# Bootstrap a new project from the template.
# Usage: project-create.sh <name> [persona-label]
set -uo pipefail
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$FLEET/templates/project"
REG="$FLEET/.state/projects.json"
ACTIVE_FILE="$FLEET/.state/active-project.txt"

NAME="${1:-}"
PERSONA="${2:-pair-engineer}"
[ -z "$NAME" ] && { echo "usage: project-create.sh <name> [persona-label]" >&2; exit 2; }
[[ ! "$NAME" =~ ^[a-zA-Z0-9_-]+$ ]] && { echo "✗ name must be [a-zA-Z0-9_-] only" >&2; exit 2; }

DST="$FLEET/projects/$NAME"
[ -d "$DST" ] && { echo "✗ project '$NAME' already exists at $DST" >&2; exit 2; }

[ ! -d "$TPL" ] && { echo "✗ template missing at $TPL" >&2; exit 2; }

cp -r "$TPL" "$DST"
echo "→ copied template to $DST"

# Substitute $PROJECT_NAME placeholder in template files
find "$DST" -type f -name "*.md" | while read -r f; do
  sed -i "s/\\\$PROJECT_NAME/$NAME/g" "$f"
done
echo "→ substituted \$PROJECT_NAME → $NAME"

# Gen session UUIDs
mkdir -p "$DST/.claude/sessions" "$DST/.claude/state" "$DST/.claude/tg-state" "$DST/.claude/logs" "$DST/outputs" "$DST/uploads"
# Init empty queue + inflight so helpers don't error on first read
: > "$DST/.claude/state/inbound-queue.jsonl"
: > "$DST/.claude/state/inbound-inflight.txt"
: > "$DST/.claude/logs/inbound-skipped.log"
for shift in lead coder reviewer debugger planner backend frontend blockchain devops qa security; do
  f="$DST/.claude/sessions/$shift.uuid"
  if [ ! -s "$f" ]; then
    if command -v uuidgen >/dev/null; then uuidgen > "$f"; else python3 -c "import uuid; print(uuid.uuid4())" > "$f"; fi
  fi
done
echo "→ generated session uuids"

# Seed empty memory/learnings if absent
seed() {
  local p="$1" h="$2"
  [ -f "$DST/$p" ] || { mkdir -p "$DST/$(dirname "$p")"; printf "%s\n\n_Empty._\n" "$h" > "$DST/$p"; }
}
seed ".claude/memory/policies.md"                   "# Policies (project: $NAME)"
seed ".claude/memory/learnings/INDEX.md"            "# Learnings Index (project: $NAME)"
seed ".claude/memory/learnings/ERRORS.md"           "# Errors Ledger (project: $NAME)"
seed ".claude/memory/learnings/FEATURE_REQUESTS.md" "# Feature Requests (project: $NAME)"
seed ".claude/reminders/REMINDERS.md"               "# Active TODOs (project: $NAME)"
seed ".claude/reminders/SCHEDULE.md"                "# Recurring Schedule (project: $NAME)"

# Bootstrap memory + agent-memory scaffolding (creates MEMORY.md indices for
# lead/coder/reviewer/researcher). Idempotent — safe to skip on failure.
if [ -x "$FLEET/agents/memory-bootstrap.sh" ]; then
  bash "$FLEET/agents/memory-bootstrap.sh" "$NAME" >/dev/null 2>&1 || true
  echo "→ memory scaffolding ready (lead/coder/reviewer/researcher)"
fi

# Register in projects.json
TMP=$(mktemp)
jq --arg n "$NAME" --arg p "$PERSONA" --arg d "$DST" --arg t "$(date '+%Y-%m-%d %H:%M:%S')" '
  .projects += [{name:$n, persona:$p, dir:$d, lead_agent_id:null, created_at:$t}]
' "$REG" > "$TMP" && mv "$TMP" "$REG"
echo "→ registered in projects.json"

# Set as active if none
[ -z "$(cat "$ACTIVE_FILE" 2>/dev/null)" ] && { echo "$NAME" > "$ACTIVE_FILE"; echo "→ set as active (no previous active)"; }

cat <<EOF

✅ Project '$NAME' created at $DST

Next:
  1. Edit persona:  $DST/.claude/persona/IDENTITY.md
                    $DST/.claude/persona/SOUL.md
                    $DST/.claude/persona/USER.md
  2. (Optional) tune $DST/.claude/agents/roles/*.md
  3. Configure MCP for this project: $DST/.claude/.mcp.json
  4. Spawn lead teammate inside Claude Code session:
        Agent(
          name="lead-$NAME",
          team_name=\$FLEET_NAME,
          subagent_type="general-purpose",
          model="\$CLAUDE_MODEL",
          prompt="Lead for project '$NAME'. Workspace: $DST. Init: cd
                  to workspace, read CLAUDE.md + persona + lead.md +
                  _team-comms.md. Ack in persona voice, then idle."
        )
  5. (Optional) Switch active:  bash agents/project-switch.sh $NAME
EOF
