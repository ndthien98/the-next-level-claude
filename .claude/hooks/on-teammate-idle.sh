#!/usr/bin/env bash
# on-teammate-idle.sh — TeammateIdle hook for claudistant fleet.
# Fires the moment a teammate goes idle. Checks if that teammate's
# project still has a non-empty inbound-inflight.txt (i.e. it went
# idle without finishing its task) and pushes a Telegram alert.
#
# Input: common hook JSON on stdin
#   { session_id, transcript_path, cwd, permission_mode,
#     hook_event_name, effort }
#
# Exit 0 always — never block the idle transition.

set -uo pipefail

FLEET_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
STATE_DIR="$FLEET_DIR/.state"
SEND_TG="$FLEET_DIR/agents/send-telegram.sh"
LOG="$STATE_DIR/hook-idle.log"
mkdir -p "$STATE_DIR"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Read stdin — must be consumed even if we do nothing with it
PAYLOAD="$(cat)"

log() { printf '%s | on-teammate-idle | %s\n' "$(ts)" "$*" >> "$LOG"; }

# --- Extract useful fields from payload (best-effort; tolerate missing) ------
SESSION_ID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")"
CWD="$(printf '%s' "$PAYLOAD" | jq -r '.cwd // ""' 2>/dev/null || echo "")"

log "fired session=$SESSION_ID cwd=$CWD"

# --- Derive project name from cwd -------------------------------------------
# cwd for a project lead is expected to be:
#   ${FLEET_ROOT}/projects/<name>/...
# or ${FLEET_ROOT}/projects/<name>/source-code
PROJECT_NAME=""
if printf '%s' "$CWD" | grep -q '/projects/'; then
    PROJECT_NAME="$(printf '%s' "$CWD" | sed 's|.*/projects/||; s|/.*||')"
fi

# Fall back: scan all projects for a stalled inflight file
check_project() {
    local name="$1"
    local inflight="$FLEET_DIR/projects/$name/.claude/state/inbound-inflight.txt"
    if [ -f "$inflight" ] && [ -s "$inflight" ]; then
        local mtime_epoch
        mtime_epoch="$(stat -c %Y "$inflight" 2>/dev/null || stat -f %m "$inflight" 2>/dev/null || echo 0)"
        local now_epoch
        now_epoch="$(date +%s)"
        local age_min=$(( (now_epoch - mtime_epoch) / 60 ))
        local inflight_text
        inflight_text="$(cat "$inflight" 2>/dev/null | head -c 200)"
        printf '%s\n' "$age_min $name $inflight_text"
    fi
}

alert_sent=0

if [ -n "$PROJECT_NAME" ]; then
    # Check only the idled lead's project
    result="$(check_project "$PROJECT_NAME" 2>/dev/null || true)"
    if [ -n "$result" ]; then
        age_min="$(printf '%s' "$result" | awk '{print $1}')"
        msg="⚠️ [fleet] lead-${PROJECT_NAME} went idle but inflight is non-empty (age ${age_min}m). Session: ${SESSION_ID}"
        log "alerting: $msg"
        if [ -x "$SEND_TG" ]; then
            "$SEND_TG" "$msg" 2>>"$LOG" || log "telegram send failed (non-fatal)"
        fi
        alert_sent=1
    fi
fi

if [ "$alert_sent" -eq 0 ] && [ -z "$PROJECT_NAME" ]; then
    # No project derived from cwd — scan all projects
    if [ -f "$STATE_DIR/projects.json" ]; then
        while IFS= read -r pname; do
            [ -z "$pname" ] && continue
            result="$(check_project "$pname" 2>/dev/null || true)"
            if [ -n "$result" ]; then
                age_min="$(printf '%s' "$result" | awk '{print $1}')"
                msg="⚠️ [fleet] lead-${pname} went idle but inflight is non-empty (age ${age_min}m). Session: ${SESSION_ID}"
                log "alerting (scan): $msg"
                if [ -x "$SEND_TG" ]; then
                    "$SEND_TG" "$msg" 2>>"$LOG" || log "telegram send failed (non-fatal)"
                fi
            fi
        done < <(jq -r '.[].name // empty' "$STATE_DIR/projects.json" 2>/dev/null || true)
    fi
fi

log "done"
exit 0
