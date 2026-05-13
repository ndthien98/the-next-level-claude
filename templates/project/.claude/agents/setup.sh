#!/usr/bin/env bash
# One-shot bootstrap for The Next Level Claude. Idempotent — safe to re-run.
#
# What it does:
#   1. Validate .env (required keys present)
#   2. mkdir runtime state directories
#   3. Generate session UUIDs for each shift (skip if existing)
#   4. Sanity-check bot token via getMe
#   5. Register Telegram slash commands (/stats, /compact) via setMyCommands
#   6. Seed empty memory/learnings files
#   7. Print next-steps for spawning the team inside Claude Code

set -u
WORKDIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$WORKDIR"

if [ ! -f .env ]; then
  echo "✗ .env not found. Copy .env.example to .env and fill in real values."
  exit 2
fi

set -a; . "$WORKDIR/.env"; set +a

REQ=(TG_BOT_TOKEN TG_OWNER_ID TG_ALLOWED_CHAT)
missing=0
for k in "${REQ[@]}"; do
  if [ -z "${!k:-}" ] || [[ "${!k}" == *"replace"* ]] || [[ "${!k}" == "1234567890" ]]; then
    echo "✗ $k missing or still placeholder"
    missing=1
  fi
done
[ "$missing" -eq 1 ] && exit 2

ASSISTANT_NAME="${ASSISTANT_NAME:-Classy}"
DEFAULT_SHIFTS=(main coder reviewer debugger planner)

# 2. mkdir runtime state
for d in .claude/state .claude/tg-state .claude/logs .claude/sessions outputs uploads; do
  mkdir -p "$WORKDIR/$d"
  touch "$WORKDIR/$d/.gitkeep"
done

# 3. session UUIDs (one per shift)
have_uuidgen=$(command -v uuidgen >/dev/null && echo yes || echo no)
for shift in "${DEFAULT_SHIFTS[@]}"; do
  f="$WORKDIR/.claude/sessions/$shift.uuid"
  if [ ! -s "$f" ]; then
    if [ "$have_uuidgen" = "yes" ]; then
      uuidgen > "$f"
    else
      python3 -c "import uuid; print(uuid.uuid4())" > "$f"
    fi
    echo "→ generated session uuid for $shift: $(cat "$f")"
  else
    echo "✓ session uuid for $shift already exists"
  fi
done

# 4. sanity-check bot token
echo
echo "→ checking bot token..."
API="https://api.telegram.org/bot${TG_BOT_TOKEN}"
ME=$(curl -s --max-time 8 "$API/getMe")
OK=$(echo "$ME" | jq -r '.ok // false')
if [ "$OK" != "true" ]; then
  echo "✗ getMe failed: $ME"
  exit 3
fi
BOT_USERNAME=$(echo "$ME" | jq -r '.result.username')
BOT_PRIVACY=$(echo "$ME" | jq -r '.result.can_read_all_group_messages // false')
echo "✓ bot @$BOT_USERNAME — privacy off: $BOT_PRIVACY"
if [ "$BOT_PRIVACY" != "true" ] && [ "${TG_ALLOWED_CHAT:0:1}" = "-" ]; then
  echo "  ⚠️  privacy mode is ON. In a group, the bot will only see commands"
  echo "      and replies, not free-form messages. Turn off via @BotFather:"
  echo "      /mybots → $BOT_USERNAME → Bot Settings → Group Privacy → Turn off"
fi

# 5. register slash commands
echo
echo "→ setting bot commands..."
cat > /tmp/_next_level_claude_cmds.json <<'EOF'
{
  "commands": [
    {"command": "stats", "description": "Usage + context per session"},
    {"command": "compact", "description": "Compact memory across all shifts"}
  ]
}
EOF
SET=$(curl -s --max-time 8 -X POST "$API/setMyCommands" -H 'Content-Type: application/json' --data @/tmp/_next_level_claude_cmds.json)
rm /tmp/_next_level_claude_cmds.json
echo "  $(echo "$SET" | jq -c .)"

# 6. seed memory + learnings if absent
seed_if_absent() {
  local path="$1" header="$2"
  if [ ! -f "$WORKDIR/$path" ]; then
    mkdir -p "$WORKDIR/$(dirname "$path")"
    printf "%s\n\n_Empty. Will be populated as the assistant runs._\n" "$header" > "$WORKDIR/$path"
    echo "→ seeded $path"
  fi
}
seed_if_absent ".claude/memory/policies.md"                   "# Policies"
seed_if_absent ".claude/memory/learnings/INDEX.md"            "# Learnings Index"
seed_if_absent ".claude/memory/learnings/ERRORS.md"           "# Errors Ledger"
seed_if_absent ".claude/memory/learnings/FEATURE_REQUESTS.md" "# Feature Requests"
seed_if_absent ".claude/reminders/REMINDERS.md"               "# Active TODOs"
seed_if_absent ".claude/reminders/SCHEDULE.md"                "# Recurring Schedule"

# 7. next steps
cat <<EOF

✅ The Next Level Claude bootstrap done.

Bot:        @${BOT_USERNAME}
Owner:      ${TG_OWNER_ID}
Chat:       ${TG_ALLOWED_CHAT}
Model:      ${CLAUDE_MODEL:-claude-sonnet-4-6}
Workspace:  $WORKDIR

Next:

1. Edit .claude/persona/IDENTITY.md, SOUL.md, USER.md — start with the
   BOOTSTRAP.md walkthrough if this is a fresh persona.

2. Open Claude Code in this dir (Opus = team-lead):
       cd $WORKDIR && claude

3. In that session, create the team and spawn 5 shifts. See the snippet
   in CLAUDE.md "Team setup snippet" at the bottom.

4. Start the Telegram poller via the Monitor tool:
       Monitor(persistent=true, command="exec python3 .claude/agents/tg-poller.py")

5. Send a message to your bot from the configured chat — you should see
   it as a tg-inbound event in the team-lead session.

EOF
