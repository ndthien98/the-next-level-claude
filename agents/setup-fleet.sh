#!/usr/bin/env bash
# Fleet bootstrap. Idempotent.
# 1. Validate .env
# 2. mkdir top-level state dirs
# 3. Initialize projects.json
# 4. Sanity-check bot token + set bot commands
# Exit codes: 0=success, 2=config error, 3=bot API error.

set -euo pipefail
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FLEET"

if [ ! -f .env ]; then
  echo "✗ .env not found. cp .env.example .env and fill in values."
  exit 2
fi
set -a; . "$FLEET/.env"; set +a

REQ=(TG_BOT_TOKEN TG_OWNER_ID TG_ALLOWED_CHAT)
miss=0
for k in "${REQ[@]}"; do
  if [ -z "${!k:-}" ]; then
    echo "✗ $k missing in .env"
    miss=1
  fi
done
[ $miss -eq 1 ] && exit 2

mkdir -p "$FLEET/.state" "$FLEET/projects"
[ -f "$FLEET/.state/projects.json" ] || echo '{"projects":[]}' > "$FLEET/.state/projects.json"
[ -f "$FLEET/.state/active-project.txt" ] || : > "$FLEET/.state/active-project.txt"

echo "→ checking bot..."
API="https://api.telegram.org/bot${TG_BOT_TOKEN}"
ME=$(curl -s --max-time 8 "$API/getMe")
OK=$(echo "$ME" | jq -r '.ok // false')
if [ "$OK" != "true" ]; then
  echo "✗ getMe failed: $ME"; exit 3
fi
BOT_USERNAME=$(echo "$ME" | jq -r '.result.username')
BOT_PRIVACY=$(echo "$ME" | jq -r '.result.can_read_all_group_messages // false')
echo "✓ bot @$BOT_USERNAME — privacy off: $BOT_PRIVACY"
[ "$BOT_PRIVACY" != "true" ] && [ "${TG_ALLOWED_CHAT:0:1}" = "-" ] && \
  echo "  ⚠️  group privacy mode is ON — turn off via @BotFather → $BOT_USERNAME → Bot Settings → Group Privacy"

echo "→ setting bot commands..."
cat > /tmp/_fleet_cmds.json <<'EOF'
{
  "commands": [
    {"command": "project_list",    "description": "List all projects"},
    {"command": "project_current", "description": "Show active project"},
    {"command": "project_switch",  "description": "Switch active project: /project_switch <name>"},
    {"command": "project_create",  "description": "Bootstrap a new project: /project_create <name>"},
    {"command": "stats",           "description": "Fleet stats (cost, queues, contexts)"},
    {"command": "compact",         "description": "Compact every project lead"},
    {"command": "help",            "description": "Show available commands"}
  ]
}
EOF
SET=$(curl -s --max-time 8 -X POST "$API/setMyCommands" -H 'Content-Type: application/json' --data @/tmp/_fleet_cmds.json)
rm /tmp/_fleet_cmds.json
echo "  $(echo "$SET" | jq -c .)"

cat <<EOF

✅ Fleet bootstrap done.

Bot:      @$BOT_USERNAME
Owner:    $TG_OWNER_ID
Chat:     $TG_ALLOWED_CHAT
Model:    ${CLAUDE_MODEL:-claude-sonnet-4-6}
Fleet:    $FLEET

Next steps:
  1. Create a project: bash agents/project-create.sh <name>
  2. Inside Claude Code: spawn the lead teammate (see CLAUDE.md)
  3. Switch active:    bash agents/project-switch.sh <name>
  4. Start poller:     Monitor(persistent=true, "exec python3 agents/tg-poller.py")
EOF
exit 0
