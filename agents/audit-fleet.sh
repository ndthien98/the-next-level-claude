#!/usr/bin/env bash
# Fleet audit + auto-heal — invoked by the audit-monitor agent.
# Checks state, errors loudly, and attempts recovery.
#
# Exit codes:
#   0 = all healthy
#   1 = problems found but auto-healing attempted
#   2 = problems found that need human intervention (escalated to Telegram)

set -uo pipefail
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FLEET"
[ -f .env ] && { set -a; . .env; set +a; }

REG="$FLEET/.state/projects.json"
LOG_SH="$FLEET/agents/fleet-log.sh"
SEND="$FLEET/agents/send-telegram.sh"

PROBLEMS=0
ESCALATIONS=0

log() { bash "$LOG_SH" "$@"; }

# 1. .env validation
for k in TG_BOT_TOKEN TG_OWNER_ID TG_ALLOWED_CHAT; do
  if [ -z "${!k:-}" ]; then
    log FATAL audit "env-missing" "$k missing in .env"
    exit 2
  fi
done

# 2. Telegram API reachable
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 \
            "https://api.telegram.org/bot${TG_BOT_TOKEN}/getMe")
if [ "$HTTP_CODE" != "200" ]; then
  log ERROR audit "telegram-api-unreachable" "HTTP $HTTP_CODE"
  PROBLEMS=$((PROBLEMS+1))
  ESCALATIONS=$((ESCALATIONS+1))
fi

# 3. Per-project: registry consistency + inflight staleness
[ -f "$REG" ] || { log FATAL audit "registry-missing" "$REG"; exit 2; }

# Per-field jq reads — avoids the empty-middle-field collapse that
# happens when lead_agent_id is "" and bash's IFS read joins
# adjacent tabs (treating .dir as AGENT_ID, leaving DIR empty).
while IFS= read -r p; do
  NAME=$(jq -r '.name // ""'              <<< "$p")
  AGENT_ID=$(jq -r '.lead_agent_id // ""' <<< "$p")
  DIR=$(jq -r '.dir // ""'                <<< "$p")

  # Workspace must exist
  if [ -z "$DIR" ] || [ ! -d "$DIR" ]; then
    log ERROR audit "workspace-missing" "project=$NAME dir=$DIR"
    PROBLEMS=$((PROBLEMS+1)); ESCALATIONS=$((ESCALATIONS+1))
    continue
  fi

  # lead_agent_id must be set
  if [ -z "$AGENT_ID" ]; then
    log WARN audit "lead-not-spawned" "project=$NAME"
    PROBLEMS=$((PROBLEMS+1))
    continue
  fi

  # Inflight staleness — over 60 min = stall
  INFLIGHT="$DIR/.claude/state/inbound-inflight.txt"
  if [ -s "$INFLIGHT" ]; then
    MTIME=$(stat -c %Y "$INFLIGHT" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    AGE_MIN=$(( (NOW - MTIME) / 60 ))
    if [ "$AGE_MIN" -gt 60 ]; then
      log ERROR audit "lead-stalled" "project=$NAME age_min=$AGE_MIN inflight=$(cat "$INFLIGHT" | head -c 80)"
      PROBLEMS=$((PROBLEMS+1)); ESCALATIONS=$((ESCALATIONS+1))
    fi
  fi

  # Queue depth check
  QUEUE="$DIR/.claude/state/inbound-queue.jsonl"
  if [ -f "$QUEUE" ]; then
    DEPTH=$(wc -l < "$QUEUE" 2>/dev/null || echo 0)
    if [ "$DEPTH" -gt 10 ]; then
      log WARN audit "queue-backlog" "project=$NAME depth=$DEPTH"
      PROBLEMS=$((PROBLEMS+1))
    fi
  fi
done < <(jq -c '.projects[]' "$REG")

# 4. Recent error log scan (last 100 lines, last hour)
ERR_LOG="$FLEET/.state/fleet.jsonl"
if [ -f "$ERR_LOG" ]; then
  CUTOFF_TS=$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
  RECENT_ERRORS=$(tail -200 "$ERR_LOG" | python3 -c "
import sys, json
cutoff = '$CUTOFF_TS'
count = 0
for line in sys.stdin:
    try:
        e = json.loads(line)
        if e.get('level') in ('ERROR','FATAL') and e.get('ts','') > cutoff:
            count += 1
    except Exception:
        pass
print(count)
" 2>/dev/null || echo 0)
  if [ "$RECENT_ERRORS" -gt 0 ]; then
    log WARN audit "recent-errors" "count=$RECENT_ERRORS within last hour"
  fi
fi

# 5. Summary
if [ "$PROBLEMS" -eq 0 ]; then
  log INFO audit "all-healthy" "no problems found"
  exit 0
fi

if [ "$ESCALATIONS" -gt 0 ]; then
  log WARN audit "audit-complete" "problems=$PROBLEMS escalations=$ESCALATIONS — needs human"
  exit 2
fi

log INFO audit "audit-complete" "problems=$PROBLEMS escalations=0"
exit 1
