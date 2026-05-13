#!/usr/bin/env bash
# on-session-end.sh — SessionEnd hook for The Next Level Claude fleet.
# Pattern inspired by coleam00/claude-memory-compiler — clean-room
# reimplementation, no code copied.
#
# Fires:   once when a Claude Code session ends (any reason)
# Purpose: compile a one-line digest of the session into the local
#          knowledge base so the NEXT session can rehydrate quickly
#          without having to re-walk the full transcript.
# Output:  appends one JSONL record to .claude/knowledge/sessions.jsonl
#
# Input: common hook JSON on stdin
#   { session_id, transcript_path, cwd, permission_mode,
#     hook_event_name, reason }
#
# Exit 0 always — never block session shutdown.

set -uo pipefail

FLEET_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
KB_DIR="$FLEET_DIR/.claude/knowledge"
HOOK_LOG="$FLEET_DIR/.state/hook-session-end.log"
mkdir -p "$KB_DIR" "$(dirname "$HOOK_LOG")"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf '%s | on-session-end | %s\n' "$(ts)" "$*" >> "$HOOK_LOG"; }

PAYLOAD="$(cat 2>/dev/null || true)"

# Best-effort field extraction. All keys are optional in the schema.
extract() { printf '%s' "$PAYLOAD" | jq -r "$1 // empty" 2>/dev/null || true; }

SESSION_ID="$(extract '.session_id')"
TRANSCRIPT="$(extract '.transcript_path')"
CWD="$(extract '.cwd')"
REASON="$(extract '.reason')"
[ -z "$SESSION_ID" ] && SESSION_ID="unknown"
[ -z "$REASON" ] && REASON="unspecified"

log "fired session=$SESSION_ID reason=$REASON transcript=$TRANSCRIPT"

# --- Compile digest from transcript (best-effort) ---------------------------
# transcript_path points at a JSONL of conversation events. We only mine
# the cheap fields: tool-use counts and edited file paths.
TOOL_COUNT=0
FILES_EDITED_JSON='[]'
KEY_TOPICS_JSON='[]'

if [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
    # Count tool_use events (one per tool invocation).
    TOOL_COUNT="$(jq -s '
        [ .[]
          | (.message?.content // [])
          | select(type == "array")
          | .[]
          | select(.type? == "tool_use")
        ] | length
    ' "$TRANSCRIPT" 2>/dev/null || echo 0)"
    [ -z "$TOOL_COUNT" ] && TOOL_COUNT=0

    # Collect unique file paths from Edit / Write / NotebookEdit tool inputs.
    FILES_EDITED_JSON="$(jq -sc '
        [ .[]
          | (.message?.content // [])
          | select(type == "array")
          | .[]
          | select(.type? == "tool_use")
          | select(.name? == "Edit" or .name? == "Write" or .name? == "NotebookEdit")
          | (.input.file_path // .input.notebook_path // empty)
        ] | unique | .[:20]
    ' "$TRANSCRIPT" 2>/dev/null || echo '[]')"
    [ -z "$FILES_EDITED_JSON" ] && FILES_EDITED_JSON='[]'

    # Naive key-topic extraction: pull the first 6 distinct user prompts,
    # truncated. Good enough as a recall hint, no LLM call needed.
    KEY_TOPICS_JSON="$(jq -sc '
        [ .[]
          | select(.type? == "user")
          | (.message?.content // "")
          | if type == "array" then
              (.[] | select(.type? == "text") | .text)
            else . end
          | select(type == "string")
          | select(length > 0)
          | .[0:120]
        ] | unique | .[:6]
    ' "$TRANSCRIPT" 2>/dev/null || echo '[]')"
    [ -z "$KEY_TOPICS_JSON" ] && KEY_TOPICS_JSON='[]'
fi

# --- Append JSONL digest ----------------------------------------------------
RECORD="$(jq -nc \
    --arg session_id    "$SESSION_ID" \
    --arg ended_at      "$(ts)" \
    --arg cwd           "$CWD" \
    --arg reason        "$REASON" \
    --argjson tool_count "${TOOL_COUNT:-0}" \
    --argjson files     "$FILES_EDITED_JSON" \
    --argjson topics    "$KEY_TOPICS_JSON" \
    '{
        session_id:     $session_id,
        ended_at:       $ended_at,
        reason:         $reason,
        cwd:            $cwd,
        tool_use_count: $tool_count,
        files_edited:   $files,
        key_topics:     $topics
    }' 2>/dev/null)"

if [ -z "$RECORD" ]; then
    # Fallback if jq composition failed for any reason
    RECORD="{\"session_id\":\"$SESSION_ID\",\"ended_at\":\"$(ts)\",\"error\":\"compile-failed\"}"
fi

printf '%s\n' "$RECORD" >> "$KB_DIR/sessions.jsonl" \
    || log "WARN: could not write to $KB_DIR/sessions.jsonl"

# Rotate sessions.jsonl if it grows past 5000 lines (keep last 2500).
if [ -f "$KB_DIR/sessions.jsonl" ]; then
    LINES="$(wc -l < "$KB_DIR/sessions.jsonl" 2>/dev/null || echo 0)"
    if [ "${LINES:-0}" -gt 5000 ]; then
        tail -n 2500 "$KB_DIR/sessions.jsonl" > "$KB_DIR/sessions.jsonl.tmp" \
            && mv "$KB_DIR/sessions.jsonl.tmp" "$KB_DIR/sessions.jsonl" \
            && log "rotated sessions.jsonl (was $LINES lines)"
    fi
fi

log "appended digest session=$SESSION_ID tools=$TOOL_COUNT"
exit 0
