#!/usr/bin/env bash
# on-session-start.sh — SessionStart hook for The Next Level Claude fleet.
# Pattern inspired by coleam00/claude-memory-compiler — clean-room
# reimplementation, no code copied.
#
# Fires:   once per Claude Code session (startup, resume, clear, compact)
# Purpose: re-inject the compiled knowledge base into the new session by
#          printing index.md and recent-context.md to stdout. Claude Code
#          picks up hook stdout as session-start context.
#
# Companion to session-init.cjs — that hook reports environment facts,
# this hook surfaces compiled knowledge. Both are wired via additive
# matcher entries in settings.json so they don't conflict.
#
# Exit 0 always — never block session startup.

set -uo pipefail

FLEET_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
KB_DIR="$FLEET_DIR/.claude/knowledge"
HOOK_LOG="$FLEET_DIR/.state/hook-session-start.log"
mkdir -p "$KB_DIR" "$(dirname "$HOOK_LOG")"

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { printf '%s | on-session-start | %s\n' "$(ts)" "$*" >> "$HOOK_LOG"; }

# Consume stdin (hook payload) even if we don't use it ----------------------
PAYLOAD="$(cat 2>/dev/null || true)"
SOURCE="$(printf '%s' "$PAYLOAD" | jq -r '.source // "unknown"' 2>/dev/null || echo "unknown")"

log "fired source=$SOURCE"

INDEX="$KB_DIR/index.md"
RECENT="$KB_DIR/recent-context.md"
SESSIONS="$KB_DIR/sessions.jsonl"

emitted=0

if [ -f "$INDEX" ] && [ -s "$INDEX" ]; then
    printf '\n=== KB index (.claude/knowledge/index.md) ===\n'
    # Cap at 80 lines so we don't flood the session
    head -n 80 "$INDEX"
    emitted=1
fi

if [ -f "$RECENT" ] && [ -s "$RECENT" ]; then
    printf '\n=== Recent context (.claude/knowledge/recent-context.md) ===\n'
    head -n 120 "$RECENT"
    emitted=1
fi

# Surface the 5 most recent session digests as a compact summary -------------
if [ -f "$SESSIONS" ] && [ -s "$SESSIONS" ]; then
    printf '\n=== Last 5 session digests ===\n'
    tail -n 5 "$SESSIONS" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        printf '%s\n' "$line" | jq -r '
            "- " + (.ended_at // "?")
            + "  tools=" + ((.tool_use_count // 0) | tostring)
            + "  files=" + (((.files_edited // []) | length) | tostring)
            + "  reason=" + (.reason // "?")
        ' 2>/dev/null || printf '- (malformed digest line)\n'
    done
    emitted=1
fi

if [ "$emitted" -eq 0 ]; then
    # First-run: tell the lead the KB is empty, point at the docs.
    printf '\n=== KB empty ===\n'
    printf 'No compiled knowledge yet. Hooks will populate .claude/knowledge/\n'
    printf 'after the first SessionEnd or PreCompact event.\n'
fi

log "done emitted=$emitted source=$SOURCE"
exit 0
