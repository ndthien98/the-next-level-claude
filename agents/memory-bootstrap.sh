#!/usr/bin/env bash
# memory-bootstrap.sh — scaffold the memory directories for a project.
#
# Idempotent. Safe to re-run. Creates:
#   projects/<name>/.claude/memory/
#     ├── README.md                     (copy from template)
#     ├── MEMORY.md                     (skeleton index)
#     └── .gitkeep
#   projects/<name>/.claude/agent-memory/<role>/
#     ├── MEMORY.md                     (per-role skeleton)
#     └── .gitkeep
#
# Usage:
#   bash agents/memory-bootstrap.sh <project-name>
#
# Roles bootstrapped by default: lead, coder, reviewer, researcher.
# Add more roles by editing DEFAULT_ROLES below.

set -euo pipefail

# Walk to fleet root (parent of this script's `agents/` dir).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLEET_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$FLEET_ROOT"

DEFAULT_ROLES=(lead coder reviewer researcher planner qa debugger devops)

if [[ $# -lt 1 ]]; then
  echo "Usage: $(basename "$0") <project-name>" >&2
  exit 2
fi

PROJECT_NAME="$1"
PROJECT_DIR="$FLEET_ROOT/projects/$PROJECT_NAME"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Project not found: $PROJECT_DIR" >&2
  echo "Hint: run 'bash agents/project-create.sh $PROJECT_NAME' first." >&2
  exit 1
fi

MEMORY_DIR="$PROJECT_DIR/.claude/memory"
AGENT_MEMORY_DIR="$PROJECT_DIR/.claude/agent-memory"

mkdir -p "$MEMORY_DIR"

# Project-level memory index (only if missing — never clobber owner edits).
if [[ ! -f "$MEMORY_DIR/MEMORY.md" ]]; then
  cat > "$MEMORY_DIR/MEMORY.md" <<EOF
# Memory Index — $PROJECT_NAME

> Replace placeholder lines as the lead and specialists learn facts worth
> keeping. Keep this index ≤30 lines and group by category.

## Project

- &lt;link to project_*.md when added&gt;

## User

- &lt;link to user_*.md when added&gt;

## Feedback

- &lt;link to feedback_*.md when added&gt;

## Reference

- &lt;link to reference_*.md when added&gt;
EOF
  echo "Created $MEMORY_DIR/MEMORY.md"
else
  echo "Kept existing $MEMORY_DIR/MEMORY.md"
fi

# Project-level README (only if missing).
TEMPLATE_README="$FLEET_ROOT/templates/project/.claude/memory/README.md"
if [[ -f "$TEMPLATE_README" && ! -f "$MEMORY_DIR/README.md" ]]; then
  cp "$TEMPLATE_README" "$MEMORY_DIR/README.md"
  echo "Created $MEMORY_DIR/README.md"
fi

touch "$MEMORY_DIR/.gitkeep"

# Per-role agent-memory skeletons.
for role in "${DEFAULT_ROLES[@]}"; do
  role_dir="$AGENT_MEMORY_DIR/$role"
  mkdir -p "$role_dir"
  touch "$role_dir/.gitkeep"

  if [[ ! -f "$role_dir/MEMORY.md" ]]; then
    cat > "$role_dir/MEMORY.md" <<EOF
# $role Agent Memory — $PROJECT_NAME

> One bullet per linked memory file, kept ≤30 lines. Add entries as the
> $role specialist learns durable facts about this project.

- &lt;no entries yet — first run&gt;
EOF
    echo "Created $role_dir/MEMORY.md"
  else
    echo "Kept existing $role_dir/MEMORY.md"
  fi
done

echo ""
echo "Done. Memory scaffolding for project '$PROJECT_NAME' is ready."
