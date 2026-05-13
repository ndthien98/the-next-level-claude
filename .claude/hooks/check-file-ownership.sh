#!/usr/bin/env bash
# PreToolUse hook — file ownership soft-check
#
# Reads the Edit/Write tool payload from stdin, extracts the target file path,
# and warns (stderr) if the path falls outside the calling agent's declared
# ownership globs.
#
# Ownership is declared in the specialist prompt via a line of the form:
#   File ownership: <glob1> <glob2> ...
#
# Claude Code injects CLAUDE_FILE_OWNERSHIP into the hook environment when
# the agent prompt contains that declaration — if the env var is absent the
# hook cannot determine ownership and defaults to ALLOW with no warning.
#
# Exit codes used:
#   0  — allow (tool proceeds); warning may appear on stderr if applicable
#   2  — block (tool is cancelled); not used here — we soft-fail only
#
# Payload schema (PreToolUse, Edit tool):
#   { "tool_name": "Edit", "tool_input": { "file_path": "...", ... } }
# Payload schema (PreToolUse, Write tool):
#   { "tool_name": "Write", "tool_input": { "file_path": "...", ... } }

set -euo pipefail

# ── Read payload from stdin ──────────────────────────────────────────────────
PAYLOAD="$(cat)"

# ── Extract target file path via jq ─────────────────────────────────────────
FILE_PATH="$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"

if [[ -z "$FILE_PATH" ]]; then
  # Cannot determine target file — allow silently
  exit 0
fi

# ── Check for declared ownership ────────────────────────────────────────────
# The env var CLAUDE_FILE_OWNERSHIP is expected to be a space-separated list
# of glob patterns, e.g. "src/api/* src/models/*"
OWNERSHIP="${CLAUDE_FILE_OWNERSHIP:-}"

if [[ -z "$OWNERSHIP" ]]; then
  # No ownership declared — allow silently (fail-soft)
  exit 0
fi

# ── Match file path against each declared glob ──────────────────────────────
TOOL_NAME="$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // "Edit"' 2>/dev/null || echo "Edit")"

# Normalise the file path: strip leading ./ for consistent matching
NORM_PATH="${FILE_PATH#./}"

matched=0
for pattern in $OWNERSHIP; do
  # Use bash glob matching (extglob not needed for basic patterns)
  # shellcheck disable=SC2254
  case "$NORM_PATH" in
    $pattern) matched=1; break ;;
  esac
  # Also try matching against the basename for simple filename patterns
  case "$(basename "$NORM_PATH")" in
    $pattern) matched=1; break ;;
  esac
done

if [[ "$matched" -eq 0 ]]; then
  TOOL_NAME_UPPER="${TOOL_NAME^^}"
  echo "[ownership-check] WARNING: ${TOOL_NAME_UPPER} on '${FILE_PATH}' is outside declared ownership '${OWNERSHIP}'. Proceeding (soft-fail). Verify this edit is intentional." >&2
fi

# Always exit 0 — warnings only, never block
exit 0
