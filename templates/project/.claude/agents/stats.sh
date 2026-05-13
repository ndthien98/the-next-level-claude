#!/usr/bin/env bash
# claudistant stats — mobile-friendly Telegram output.
# Sections separated by blank lines + emoji prefix (no --- or ━━ which
# break on Telegram mobile).

set -u
WORKDIR="$(cd "$(dirname "$0")/../.." && pwd)"
[ -f "$WORKDIR/.env" ] && { set -a; . "$WORKDIR/.env"; set +a; }

ASSISTANT="${ASSISTANT_NAME:-assistant}"
PROJ_REL="$(echo "$WORKDIR" | sed 's|/|-|g')"
PROJ="$HOME/.claude/projects/${PROJ_REL}"

echo "📊 $ASSISTANT stats — $(date '+%H:%M %d/%m')"
echo

echo "🧠 Context per session"
ls -1tS "$PROJ"/*.jsonl 2>/dev/null | head -5 | while read -r f; do
  uuid=$(basename "$f" .jsonl | cut -c1-8)
  info=$(jq -s 'map(select(.type=="assistant" and .message.usage)) | last
         | {ctx: ((.message.usage.input_tokens // 0)
                  + (.message.usage.cache_read_input_tokens // 0)
                  + (.message.usage.cache_creation_input_tokens // 0)),
            model: (.message.model // "?")}
        ' "$f" 2>/dev/null)
  ctx=$(echo "$info" | jq -r '.ctx // 0')
  model=$(echo "$info" | jq -r '.model // "?"')
  case "$model" in
    *opus*1m*|*opus-4-7*|*opus-4.7*|*[1m]*) lim=1000000; tag="opus" ;;
    *opus*) lim=200000; tag="opus" ;;
    *sonnet*) lim=200000; tag="son" ;;
    *haiku*) lim=200000; tag="hai" ;;
    *) lim=200000; tag="?" ;;
  esac
  pct=$(( ctx * 100 / lim ))
  ctx_h=$(printf "%'d" "$ctx" 2>/dev/null || echo "$ctx")
  printf "• %s %3s %8st %d%%\n" "$uuid" "$tag" "$ctx_h" "$pct"
done

echo

echo "💰 Claude Code"
if command -v npx >/dev/null 2>&1; then
  COST_JSON=$(npx -y ccusage daily --json 2>/dev/null)
  TODAY=$(echo "$COST_JSON" | jq -r '.daily | sort_by(.date) | reverse | .[0] // {}' 2>/dev/null)
  TODAY_COST=$(echo "$TODAY" | jq -r '.totalCost // 0' 2>/dev/null)
  TODAY_TOK=$(echo "$TODAY" | jq -r '.totalTokens // 0' 2>/dev/null)
  ALL_COST=$(echo "$COST_JSON" | jq -r '.totals.totalCost // 0' 2>/dev/null)
  TODAY_TOK_H=$(printf "%'d" "${TODAY_TOK:-0}" 2>/dev/null || echo "${TODAY_TOK:-0}")
  printf "• Today: \$%.2f (%st)\n" "${TODAY_COST:-0}" "$TODAY_TOK_H"
  printf "• All-time: \$%.2f\n" "${ALL_COST:-0}"
else
  echo "• ccusage not available (no npx)"
fi

echo

echo "📨 Telegram"
SKIPLOG="$WORKDIR/.claude/logs/inbound-skipped.log"
SKIPS=0; [ -f "$SKIPLOG" ] && SKIPS=$(wc -l < "$SKIPLOG")
INFLIGHT=$(cat "$WORKDIR/.claude/state/inbound-inflight.txt" 2>/dev/null)
QLEN=$(wc -l < "$WORKDIR/.claude/state/inbound-queue.jsonl" 2>/dev/null || echo 0)
[ -z "$INFLIGHT" ] && INFLIGHT="idle"
echo "• Queue: $INFLIGHT / $QLEN pending"
echo "• Skipped: $SKIPS"
if pgrep -f tg-poller.py >/dev/null; then
  UPTIME=$(ps -o etime= -p "$(pgrep -f tg-poller.py | head -1)" 2>/dev/null | tr -d ' ')
  echo "• Poller: ✅ ${UPTIME}"
else
  echo "• Poller: ⚠️ DOWN"
fi
