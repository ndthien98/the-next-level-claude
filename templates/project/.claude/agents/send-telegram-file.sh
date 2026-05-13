#!/usr/bin/env bash
# Send a local file to the configured Telegram chat. Reads creds from .env.
# Auto-detects type via mime → sendPhoto / sendAudio / sendVideo / sendDocument.
# Usage:
#   send-telegram-file.sh <local_path> [caption]
# Exit 0 on success.

set -u

WORKDIR="$(cd "$(dirname "$0")/../.." && pwd)"
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

ARGS=(-s -X POST "$API/$ENDPOINT" -F "chat_id=$CHAT" -F "${FIELD}=@${FILE}")
[ -n "$CAPTION" ] && ARGS+=(-F "caption=$CAPTION")

RESP="$(curl "${ARGS[@]}")"
OK="$(echo "$RESP" | jq -r '.ok // false' 2>/dev/null)"
if [ "$OK" = "true" ]; then
  echo "sent: $(basename "$FILE") via $ENDPOINT (${SIZE}B, $MIME)"
  exit 0
fi
echo "telegram error: $(echo "$RESP" | jq -r '.description // .')" >&2
exit 1
