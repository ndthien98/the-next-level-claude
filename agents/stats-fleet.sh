#!/usr/bin/env bash
# Fleet-level stats. Mobile-friendly Telegram output.
set -uo pipefail
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$FLEET/.env" ] && { set -a; . "$FLEET/.env"; set +a; }
NAME="${FLEET_NAME:-next-level-claude}"
REG="$FLEET/.state/projects.json"
ACTIVE="$(cat "$FLEET/.state/active-project.txt" 2>/dev/null || echo "")"

echo "📊 $NAME fleet — $(date '+%H:%M %d/%m')"
echo
echo "★ active: ${ACTIVE:-(none)}"
echo

echo "📂 Projects"
if [ -f "$REG" ]; then
  jq -r '.projects[] | .name + "|" + .dir' "$REG" 2>/dev/null | while IFS='|' read -r n d; do
    [ -z "$n" ] && continue
    if=$(cat "$d/.claude/state/inbound-inflight.txt" 2>/dev/null)
    [ -z "$if" ] && if="idle"
    ql=$(wc -l < "$d/.claude/state/inbound-queue.jsonl" 2>/dev/null || echo 0)
    marker="  "; [ "$n" = "$ACTIVE" ] && marker="★ "
    echo "$marker$n  queue=$if/$ql"
  done
fi

echo
echo "💰 Claude Code"
if command -v npx >/dev/null 2>&1; then
  JSON=$(npx -y ccusage daily --json 2>/dev/null)
  T=$(echo "$JSON" | jq -r '.daily | sort_by(.date) | reverse | .[0] // {}' 2>/dev/null)
  TC=$(echo "$T" | jq -r '.totalCost // 0'); TT=$(echo "$T" | jq -r '.totalTokens // 0')
  AC=$(echo "$JSON" | jq -r '.totals.totalCost // 0')
  TTH=$(printf "%'d" "${TT:-0}" 2>/dev/null || echo "$TT")
  printf "• Today: \$%.2f (%st)\n" "$TC" "$TTH"
  printf "• All-time: \$%.2f\n" "$AC"
else
  echo "• ccusage unavailable"
fi

echo
echo "🛰 Poller"
if pgrep -f tg-poller.py >/dev/null; then
  UP=$(ps -o etime= -p "$(pgrep -f tg-poller.py | head -1)" 2>/dev/null | tr -d ' ')
  echo "• ✅ alive, uptime $UP"
else
  echo "• ⚠️ DOWN"
fi
SKIP=0
[ -f "$FLEET/.claude/logs/inbound-skipped.log" ] && SKIP=$(wc -l < "$FLEET/.claude/logs/inbound-skipped.log")
# Per-project skip logs aggregate
for d in "$FLEET"/projects/*/.claude/logs/inbound-skipped.log; do
  [ -f "$d" ] && SKIP=$((SKIP + $(wc -l < "$d")))
done
echo "• Skipped: $SKIP"
