#!/usr/bin/env bash
# Send a text message to the configured Telegram chat. Reads token + chat
# from `.env` in the workspace root.
# Usage:
#   send-telegram.sh "message"
#   echo "msg" | send-telegram.sh
# Auto-chunks at 3800 chars (Telegram limit ~4096 with safety margin).

set -u

WORKDIR="$(cd "$(dirname "$0")/../.." && pwd)"
# Load .env
if [ -f "$WORKDIR/.env" ]; then
  set -a; . "$WORKDIR/.env"; set +a
fi

TOKEN="${TG_BOT_TOKEN:-}"
CHAT="${TG_CHAT_ID:-${TG_ALLOWED_CHAT:-}}"
API="https://api.telegram.org/bot${TOKEN}"

[ -z "$TOKEN" ] && { echo "missing TG_BOT_TOKEN" >&2; exit 2; }
[ -z "$CHAT" ]  && { echo "missing TG_ALLOWED_CHAT or TG_CHAT_ID" >&2; exit 2; }

if [ "$#" -ge 1 ]; then MSG="$*"; else MSG="$(cat)"; fi
[ -z "$MSG" ] && { echo "empty"; exit 0; }

MAX=3800
while [ -n "$MSG" ]; do
  CHUNK="${MSG:0:$MAX}"
  MSG="${MSG:$MAX}"
  curl -s -X POST "$API/sendMessage" \
    --data-urlencode "chat_id=$CHAT" \
    --data-urlencode "text=$CHUNK" >/dev/null || true
done
