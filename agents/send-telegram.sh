#!/usr/bin/env bash
# Send a text message to the configured Telegram chat.
# Retries on failure. NEVER silently swallows errors —
# every failure is logged to .state/tg-send-errors.log and stderr.
#
# Usage:
#   send-telegram.sh "message"
#   echo "msg" | send-telegram.sh
# Auto-chunks at 3800 chars.
# Exit codes: 0=success, 1=all-retries-failed, 2=config/env error.

set -uo pipefail

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
ERR_LOG="$WORKDIR/.state/tg-send-errors.log"
mkdir -p "$(dirname "$ERR_LOG")"

if [ -f "$WORKDIR/.env" ]; then
  set -a; . "$WORKDIR/.env"; set +a
else
  echo "send-telegram: $WORKDIR/.env missing" >&2
  exit 2
fi

TOKEN="${TG_BOT_TOKEN:-}"
CHAT="${TG_CHAT_ID:-${TG_ALLOWED_CHAT:-}}"
API="https://api.telegram.org/bot${TOKEN}"

[ -z "$TOKEN" ] && { echo "send-telegram: missing TG_BOT_TOKEN" >&2; exit 2; }
[ -z "$CHAT" ]  && { echo "send-telegram: missing TG_ALLOWED_CHAT/TG_CHAT_ID" >&2; exit 2; }

if [ "$#" -ge 1 ]; then MSG="$*"; else MSG="$(cat)"; fi
[ -z "$MSG" ] && { echo "send-telegram: empty payload — refusing" >&2; exit 2; }

log_fail() {
  local code="$1" body="$2" preview="$3"
  local ts; ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s | http=%s | preview=%q | body=%s\n' \
    "$ts" "$code" "${preview:0:80}" "${body:0:200}" >> "$ERR_LOG"
  echo "send-telegram: HTTP $code; logged to $ERR_LOG" >&2
}

send_chunk() {
  local chunk="$1"
  local attempt body code
  for attempt in 1 2 3; do
    body=$(curl -s -w '\n__HTTP__%{http_code}' -X POST "$API/sendMessage" \
              --max-time 10 \
              --data-urlencode "chat_id=$CHAT" \
              --data-urlencode "text=$chunk" 2>&1) || body="curl-exec-failed: $body"
    code="${body##*__HTTP__}"
    body="${body%__HTTP__*}"
    if [ "$code" = "200" ]; then
      return 0
    fi
    # Backoff: 2s, 4s
    [ "$attempt" -lt 3 ] && sleep "$(( attempt * 2 ))"
  done
  log_fail "$code" "$body" "$chunk"
  return 1
}

MAX=3800
had_error=0
while [ -n "$MSG" ]; do
  CHUNK="${MSG:0:$MAX}"
  MSG="${MSG:$MAX}"
  if ! send_chunk "$CHUNK"; then
    had_error=1
  fi
done
exit "$had_error"
