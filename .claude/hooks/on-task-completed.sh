#!/usr/bin/env bash
# on-task-completed.sh — TaskCompleted hook for claudistant fleet.
# Appends a JSONL audit record to .state/fleet.jsonl every time a task
# is marked complete. Fast, non-blocking, fail-soft.
#
# Input: common hook JSON on stdin
#   { session_id, transcript_path, cwd, permission_mode,
#     hook_event_name, effort }
#
# Output: one JSONL record appended to $FLEET_DIR/.state/fleet.jsonl
#
# Exit 0 always — never block task completion.

set -uo pipefail

FLEET_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
STATE_DIR="$FLEET_DIR/.state"
AUDIT_LOG="$STATE_DIR/fleet.jsonl"
HOOK_LOG="$STATE_DIR/hook-task-completed.log"
mkdir -p "$STATE_DIR"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# Read stdin in full
PAYLOAD="$(cat)"

log() { printf '%s | on-task-completed | %s\n' "$(ts)" "$*" >> "$HOOK_LOG"; }

# --- Extract fields (best-effort; tolerate missing keys) --------------------
extract() { printf '%s' "$PAYLOAD" | jq -r "$1 // \"unknown\"" 2>/dev/null || echo "unknown"; }

SESSION_ID="$(extract '.session_id')"
CWD="$(extract '.cwd')"
HOOK_EVENT="$(extract '.hook_event_name')"
PERMISSION_MODE="$(extract '.permission_mode')"

log "fired session=$SESSION_ID event=$HOOK_EVENT cwd=$CWD"

# --- Derive project name from cwd -------------------------------------------
PROJECT_NAME="unknown"
if printf '%s' "$CWD" | grep -q '/projects/'; then
    PROJECT_NAME="$(printf '%s' "$CWD" | sed 's|.*/projects/||; s|/.*||')"
fi

# --- Build and append JSONL record ------------------------------------------
TIMESTAMP="$(ts)"
RECORD="$(jq -nc \
    --arg ts         "$TIMESTAMP" \
    --arg event      "$HOOK_EVENT" \
    --arg session    "$SESSION_ID" \
    --arg project    "$PROJECT_NAME" \
    --arg cwd        "$CWD" \
    --arg perm_mode  "$PERMISSION_MODE" \
    '{
        timestamp:        $ts,
        event:            $event,
        session_id:       $session,
        project:          $project,
        cwd:              $cwd,
        permission_mode:  $perm_mode
    }' 2>/dev/null)" || {
    # jq failed — write a minimal fallback record
    RECORD="{\"timestamp\":\"$TIMESTAMP\",\"event\":\"TaskCompleted\",\"session_id\":\"$SESSION_ID\",\"project\":\"$PROJECT_NAME\",\"error\":\"jq-failed\"}"
}

printf '%s\n' "$RECORD" >> "$AUDIT_LOG" || log "WARN: could not write to $AUDIT_LOG"

log "appended to fleet.jsonl project=$PROJECT_NAME"
exit 0
