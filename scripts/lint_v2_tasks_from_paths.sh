#!/usr/bin/env bash

set -euo pipefail

if [ $# -eq 0 ]; then
  echo "usage: scripts/lint_v2_tasks_from_paths.sh <path> [path ...]"
  exit 2
fi

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

for path in "$@"; do
  case "$path" in
    findings/tasks/*)
      task_id="$(echo "$path" | cut -d'/' -f3)"
      if [ -n "$task_id" ]; then
        echo "$task_id" >> "$TMP_FILE"
      fi
      ;;
  esac
done

if [ ! -s "$TMP_FILE" ]; then
  echo "ok:no-task-paths"
  exit 0
fi

COUNT=0
for task_id in $(sort -u "$TMP_FILE"); do
  if [ ! -d "findings/tasks/$task_id" ]; then
    continue
  fi
  scripts/lint_iteration_artifacts.sh "$task_id"
  scripts/lint_task_result.sh --v2 "findings/tasks/$task_id/result.md"
  if [ -x "scripts/lint_finding_quality.sh" ]; then
    scripts/lint_finding_quality.sh "$task_id"
  fi
  COUNT=$((COUNT + 1))
done

echo "ok:linted-${COUNT}-task(s)"
