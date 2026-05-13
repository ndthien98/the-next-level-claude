#!/usr/bin/env bash
# Fleet cold-start / warm-restart assistant.
# Run this at the start of every new Claude Code session — it audits
# disk state and prints the Claude Code commands needed to bring
# the fleet back to full operation (TeamCreate, Agent spawns, Monitor,
# CronCreate).
#
# All background work lives INSIDE the Claude Code session — see
# .claude/JOBS.md. No pm2, no daemons.

set -u
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FLEET"
[ -f .env ] && { set -a; . .env; set +a; }
FLEET_NAME="${FLEET_NAME:-claudistant}"

echo "=== $FLEET_NAME fleet-restart — $(date '+%Y-%m-%d %H:%M:%S') ==="
echo ""

# 1. Validate .env
REQ=(TG_BOT_TOKEN TG_OWNER_ID TG_ALLOWED_CHAT)
miss=0
for k in "${REQ[@]}"; do
  [ -z "${!k:-}" ] && { echo "✗ $k missing in .env"; miss=1; }
done
[ $miss -eq 1 ] && exit 2
echo "✓ .env validated"

# 2. State files
MAIN_ID_FILE="$FLEET/.state/main-session.id"
TEAM_ID_FILE="$FLEET/.state/team.id"
[ -f "$MAIN_ID_FILE" ] && echo "✓ main session: $(cat "$MAIN_ID_FILE")" || \
  echo "  (no main-session.id — set after TeamCreate)"
[ -f "$TEAM_ID_FILE" ] && echo "✓ team id: $(cat "$TEAM_ID_FILE")" || \
  echo "  (no team.id — run TeamCreate, then save-session.sh team <fleet-name>)"

# 3. Lead status
echo ""
echo "=== leads (from projects.json) ==="
bash "$FLEET/agents/respawn-leads.sh" 2>/dev/null | grep -E '^[✓✗]|^==='

# 4. Bot commands
echo ""
echo "=== Telegram bot ==="
CMD_COUNT=$(curl -s --max-time 5 "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMyCommands" 2>/dev/null \
  | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('result',[])))" 2>/dev/null || echo "?")
echo "✓ bot @${BOT_USERNAME:-(unknown)} — $CMD_COUNT commands registered"

# 5. Next steps inside Claude Code session
cat <<'EOF'

=== Inside Claude Code, run these in order ===

# 1. Re-create the Agent Team
TeamCreate(team_name="<fleet-name>", description="Personal coding fleet")
Bash("bash agents/save-session.sh team <fleet-name>")

# 2. Re-spawn leads — copy Agent() snippets from respawn-leads.sh output above
#    After each spawn:
Bash("bash agents/save-session.sh lead <name> <returned-agent-id>")

# 3. Start the Telegram poller (Job 1 — see .claude/JOBS.md)
Monitor(
  description="Telegram poller — inbound feed",
  command="exec python3 agents/tg-poller.py",
  persistent=true,
  timeout_ms=3600000
)

# 4. Arm the stall watchdog (Job 2 — fires hourly)
CronCreate(
  cron="7 * * * *",
  recurring=true,
  prompt="Stall watchdog: for each project in .state/projects.json, check projects/<name>/.claude/state/inbound-inflight.txt — if non-empty AND mtime > 60 minutes ago, push a Telegram alert via agents/send-telegram.sh saying lead-<name> may be stalled."
)

# 5. Arm the daily fleet audit (Job 4 — fires 06:07 local time)
CronCreate(
  cron="7 6 * * *",
  recurring=true,
  prompt="DAILY FLEET AUDIT (06:07 local time). Spawn ONE general-purpose agent with model=opus and the prompt from ${FLEET_ROOT}/agents/daily-audit-prompt.txt. The agent writes the report to .claude/daily-audit/YYYY-MM-DD.md and pushes a short summary to Telegram via agents/send-telegram.sh. Read-only audit — no commits or destructive ops."
)

Done. Fleet ready.
EOF
