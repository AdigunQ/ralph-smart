#!/usr/bin/env bash

set -euo pipefail

TASK_ROOT="findings/tasks"
INIT_SCRIPT="scripts/init_task_workspace.sh"

if [ ! -x "$INIT_SCRIPT" ]; then
  echo "missing-executable:$INIT_SCRIPT"
  exit 1
fi

mkdir -p "$TASK_ROOT"

found_any="false"
for task_dir in "$TASK_ROOT"/*; do
  if [ ! -d "$task_dir" ]; then
    continue
  fi
  task_id="$(basename "$task_dir")"
  "$INIT_SCRIPT" "$task_id" >/dev/null
  found_any="true"
  echo "migrated:$task_id"
done

if [ "$found_any" = "false" ]; then
  echo "no-task-directories-found:$TASK_ROOT"
fi
