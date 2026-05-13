#!/usr/bin/env bash
# Fleet compact: inject /compact into every project lead's tmux pane.
# Resolves pane by scanning each pane's process cmdline for
# `--agent-name <lead-name>`.
#
# Lead-name resolution:
#  - Default: `lead-<project-name>` (single-lead-per-project convention).
#  - Sub-leads: if `projects.json` has a `leads` dict for a project, each
#    sub-key produces `lead-<project-name>-<sub-key>` (e.g. project
#    "foo" with leads.api + leads.web → `lead-foo-api` and `lead-foo-web`).

set -uo pipefail
FLEET="$(cd "$(dirname "$0")/.." && pwd)"
REG="$FLEET/.state/projects.json"

[ ! -f "$REG" ] && { echo "no projects registered"; exit 0; }

# Build LEAD_NAMES — one entry per addressable lead.
LEAD_NAMES=$(jq -r '
  .projects[]
  | .name as $p
  | (if (.leads // {}) | length > 0
       then (.leads | keys[] | "lead-\($p)-\(.)")
       else "lead-\($p)"
     end)
' "$REG")

[ -z "$LEAD_NAMES" ] && { echo "no leads to compact"; exit 0; }

declare -A PANE_OF
for pid_pane in $(tmux list-panes -a -F '#{pane_pid}|#{pane_id}' 2>/dev/null); do
  pane_pid="${pid_pane%%|*}"
  pane_id="${pid_pane##*|}"
  child_pids=$(pgrep -P "$pane_pid" 2>/dev/null)
  grand_pids=""
  for cp in $child_pids; do
    grand_pids="$grand_pids $(pgrep -P "$cp" 2>/dev/null)"
  done
  for cpid in $child_pids $grand_pids; do
    [ -z "$cpid" ] && continue
    cmd=$(tr '\0' ' ' < "/proc/$cpid/cmdline" 2>/dev/null || true)
    for n in $LEAD_NAMES; do
      case "$cmd" in
        *"--agent-name $n "*|*"--agent-name $n") PANE_OF[$n]="$pane_id" ;;
      esac
    done
  done
done

echo "Resolved:"
for n in $LEAD_NAMES; do echo "  $n → ${PANE_OF[$n]:-MISSING}"; done
echo

fail=0
for n in $LEAD_NAMES; do
  pane="${PANE_OF[$n]:-}"
  if [ -z "$pane" ]; then echo "✗ $n: no pane"; fail=$((fail+1)); continue; fi
  echo "→ /compact → $n ($pane)"
  tmux send-keys -t "$pane" '/compact' Enter
  sleep 0.5
done
[ $fail -gt 0 ] && exit 1
echo "All /compact keystrokes sent."
