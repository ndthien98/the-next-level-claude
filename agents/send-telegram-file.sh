#!/usr/bin/env bash
# Send a local file to the configured Telegram chat. Reads creds from .env.
# Auto-detects type via mime → sendPhoto / sendAudio / sendVideo / sendDocument.
# Usage:
#   send-telegram-file.sh <local_path> [caption]
# Exit codes: 0=success, 1=all-retries-failed, 2=config/arg error, 3=file too large.

set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$WORKDIR/.env" ] && { set -a; . "$WORKDIR/.env"; set +a; }

TOKEN="${TG_BOT_TOKEN:-}"
CHAT="${TG_CHAT_ID:-${TG_ALLOWED_CHAT:-}}"
API="https://api.telegram.org/bot${TOKEN}"

[ -z "$TOKEN" ] && { echo "missing TG_BOT_TOKEN" >&2; exit 2; }
[ -z "$CHAT" ]  && { echo "missing chat id" >&2; exit 2; }

FILE="${1:-}"
CAPTION="${2:-}"

[ -z "$FILE" ] || [ ! -f "$FILE" ] && { echo "no such file: $FILE" >&2; exit 2; }

MIME="$(file -b --mime-type "$FILE" 2>/dev/null || echo application/octet-stream)"
SIZE="$(stat -c%s "$FILE" 2>/dev/null || echo 0)"
[ "$SIZE" -gt 49000000 ] && { echo "file too large for bot API: ${SIZE}B" >&2; exit 3; }

case "$MIME" in
  image/jpeg|image/png|image/webp) ENDPOINT=sendPhoto;    FIELD=photo ;;
  image/*)                          ENDPOINT=sendDocument; FIELD=document ;;
  audio/ogg|audio/mpeg|audio/mp3|audio/wav|audio/m4a)
                                    ENDPOINT=sendAudio;    FIELD=audio ;;
  video/mp4|video/quicktime|video/x-matroska)
                                    ENDPOINT=sendVideo;    FIELD=video ;;
  *)                                ENDPOINT=sendDocument; FIELD=document ;;
esac

ERR_LOG="$WORKDIR/.state/tg-send-errors.log"
mkdir -p "$(dirname "$ERR_LOG")"

ARGS=(-s --max-time 30 -X POST "$API/$ENDPOINT" -F "chat_id=$CHAT" -F "${FIELD}=@${FILE}")
[ -n "$CAPTION" ] && ARGS+=(-F "caption=$CAPTION")

for ATTEMPT in 1 2 3; do
  RESP="$(curl "${ARGS[@]}" 2>&1)" || RESP="curl-failed: $RESP"
  OK="$(echo "$RESP" | jq -r '.ok // false' 2>/dev/null || echo false)"
  if [ "$OK" = "true" ]; then
    echo "sent: $(basename "$FILE") via $ENDPOINT (${SIZE}B, $MIME)"
    exit 0
  fi
  DESC="$(echo "$RESP" | jq -r '.description // .' 2>/dev/null || echo "$RESP")"
  echo "send-telegram-file attempt $ATTEMPT failed: $DESC" >&2
  [ "$ATTEMPT" -lt 3 ] && sleep "$(( ATTEMPT * 2 ))"
done

TS="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s | file=%s | size=%s | mime=%s | last_resp=%s\n' \
  "$TS" "$(basename "$FILE")" "$SIZE" "$MIME" "${DESC:0:200}" >> "$ERR_LOG"
echo "send-telegram-file: gave up after 3 attempts. Logged to $ERR_LOG" >&2
exit 1
