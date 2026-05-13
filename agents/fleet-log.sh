#!/usr/bin/env bash
# Structured JSON logger for every fleet event. NO silent failures.
# Every script in agents/ MUST call this for any non-trivial event.
#
# Usage:
#   fleet-log.sh <level> <component> <event> [detail...]
# Levels: DEBUG | INFO | WARN | ERROR | FATAL
#
# Side effects:
#   - Appends one JSON line to .state/fleet.jsonl
#   - On ERROR or FATAL: also pushes to Telegram (best-effort)
#   - On FATAL: exits 1

set -u
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$FLEET/.state/fleet.jsonl"
mkdir -p "$(dirname "$LOG")"

LEVEL="${1:?level required (DEBUG|INFO|WARN|ERROR|FATAL)}"
COMPONENT="${2:?component required}"
EVENT="${3:?event required}"
shift 3
DETAIL="$*"

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
HOST="$(hostname 2>/dev/null || echo unknown)"

# Build JSON line safely (handle quotes/newlines via python)
LINE=$(python3 - <<PY
import json, sys
print(json.dumps({
    "ts": "$TS",
    "level": "$LEVEL",
    "component": "$COMPONENT",
    "event": "$EVENT",
    "detail": """$DETAIL""",
    "host": "$HOST",
}))
PY
)

echo "$LINE" >> "$LOG" || {
  # Last-resort fallback — can't even write the log
  echo "FATAL: fleet-log cannot write to $LOG" >&2
  exit 2
}

# Echo to stderr so callers see it too
echo "[$LEVEL] $COMPONENT::$EVENT $DETAIL" >&2

# Telegram escalation for ERROR/FATAL
case "$LEVEL" in
  ERROR|FATAL)
    SEND="$FLEET/agents/send-telegram.sh"
    if [ -x "$SEND" ]; then
      MSG="🚨 [$LEVEL] $COMPONENT::$EVENT"
      [ -n "$DETAIL" ] && MSG="$MSG
$DETAIL"
      bash "$SEND" "$MSG" >/dev/null 2>&1 || {
        echo "WARN: fleet-log could not push to Telegram (send-telegram.sh failed)" >&2
      }
    fi
    ;;
esac

[ "$LEVEL" = "FATAL" ] && exit 1
exit 0
