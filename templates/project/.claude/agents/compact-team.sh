#!/usr/bin/env bash
# Trigger interactive /compact in each teammate's tmux pane.
# Uses tmux send-keys to inject the slash command — same effect as the
# owner typing /compact manually in that pane.
#
# Resolves pane → agent by scanning each pane's process cmdline for
# `--agent-name <X>` (or scrollback as fallback).
#
# Usage:
#   compact-team.sh                       # all default shifts
#   compact-team.sh main coder            # subset
#   AGENTS="main coder reviewer" compact-team.sh

set -u
DEFAULT_AGENTS=(main coder reviewer debugger planner)
if [ "$#" -gt 0 ]; then
  TARGETS=("$@")
elif [ -n "${AGENTS:-}" ]; then
  # shellcheck disable=SC2206
  TARGETS=($AGENTS)
else
  TARGETS=("${DEFAULT_AGENTS[@]}")
fi

# Build pane → agent map. Primary: pane process cmdline. Fallback: scrollback.
declare -A PANE_OF
for pid_pane in $(tmux list-panes -a -F '#{pane_pid}|#{pane_id}' 2>/dev/null); do
  pane_pid="${pid_pane%%|*}"
  pane_id="${pid_pane##*|}"
  # Walk descendant pids looking for claude
  for cpid in $(pgrep -P "$pane_pid" 2>/dev/null) $(pgrep -P "$(pgrep -P "$pane_pid" 2>/dev/null | head -1)" 2>/dev/null); do
    cmd=$(tr '\0' ' ' < "/proc/$cpid/cmdline" 2>/dev/null || true)
    for name in "${DEFAULT_AGENTS[@]}"; do
      case "$cmd" in
        *"--agent-name $name "*|*"--agent-name $name") PANE_OF[$name]="$pane_id" ;;
      esac
    done
  done
  # Scrollback fallback for any still-unresolved
  buf=""
  for name in "${DEFAULT_AGENTS[@]}"; do
    [ -n "${PANE_OF[$name]:-}" ] && continue
    [ -z "$buf" ] && buf=$(tmux capture-pane -p -t "$pane_id" -S -1500 2>/dev/null)
    if echo "$buf" | grep -q -- "--agent-name $name"; then
      PANE_OF[$name]="$pane_id"
    fi
  done
done

echo "Resolved panes:"
for name in "${DEFAULT_AGENTS[@]}"; do
  echo "  $name → ${PANE_OF[$name]:-MISSING}"
done
echo

failures=0
for agent in "${TARGETS[@]}"; do
  pane="${PANE_OF[$agent]:-}"
  if [ -z "$pane" ]; then
    echo "✗ $agent: pane not resolved — skip"
    failures=$((failures+1))
    continue
  fi
  echo "→ sending /compact to $agent (pane $pane)..."
  tmux send-keys -t "$pane" '/compact' Enter
  sleep 1
done

echo
[ $failures -gt 0 ] && exit 1
echo "All /compact keystrokes sent. Verify via pane scrollback or stats.sh."
