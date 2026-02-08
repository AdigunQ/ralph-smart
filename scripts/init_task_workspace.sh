#!/usr/bin/env bash

set -euo pipefail

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
  echo "usage: scripts/init_task_workspace.sh <TASK-ID>"
  exit 2
fi

TASK_DIR="findings/tasks/$TASK_ID"
TEMPLATE_DIR="findings/_templates/task"

mkdir -p "$TASK_DIR"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "missing-template-dir:$TEMPLATE_DIR"
  exit 1
fi

render_template() {
  local src="$1"
  local dst="$2"
  if [ -f "$dst" ]; then
    return
  fi
  sed "s/__TASK_ID__/$TASK_ID/g" "$src" > "$dst"
}

render_template "$TEMPLATE_DIR/hypotheses.md" "$TASK_DIR/hypotheses.md"
render_template "$TEMPLATE_DIR/evidence.md" "$TASK_DIR/evidence.md"
render_template "$TEMPLATE_DIR/repro.md" "$TASK_DIR/repro.md"
render_template "$TEMPLATE_DIR/rejected.md" "$TASK_DIR/rejected.md"
render_template "$TEMPLATE_DIR/root_cause.md" "$TASK_DIR/root_cause.md"
render_template "$TEMPLATE_DIR/result.md" "$TASK_DIR/result.md"

echo "ok:$TASK_DIR"
