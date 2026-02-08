#!/usr/bin/env bash

set -euo pipefail

TASK_ID="${1:-}"
if [ -z "$TASK_ID" ]; then
  echo "usage: scripts/lint_finding_quality.sh <TASK-ID>"
  exit 2
fi

RESULT_FILE="findings/tasks/$TASK_ID/result.md"
REPRO_FILE="findings/tasks/$TASK_ID/repro.md"

if [ ! -f "$RESULT_FILE" ]; then
  echo "missing-file:$RESULT_FILE"
  exit 1
fi
if [ ! -f "$REPRO_FILE" ]; then
  echo "missing-file:$REPRO_FILE"
  exit 1
fi

STATUS="$(grep -i '^status:' "$RESULT_FILE" | head -1 | cut -d':' -f2- | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
CONFIDENCE="$(grep -E '^confidence:' "$RESULT_FILE" | head -1 | cut -d':' -f2- | tr -d '[:space:]')"
REPRO_STATUS="$(grep -E '^reproduction_status:' "$REPRO_FILE" | head -1 | cut -d':' -f2- | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"

is_confirmed="false"
case "$STATUS" in
  CONFIRMED|VULN|VULNERABLE) is_confirmed="true" ;;
esac

if [ "$is_confirmed" = "false" ]; then
  echo "ok:$TASK_ID"
  exit 0
fi

# Confirmed findings must be reproducible and high-confidence.
if [ "$REPRO_STATUS" != "CONFIRMED" ]; then
  echo "invalid-repro-status-for-confirmed:$REPRO_STATUS"
  exit 1
fi

if ! echo "$CONFIDENCE" | grep -Eq '^[0-9]+(\.[0-9]+)?$'; then
  echo "invalid-confidence-format"
  exit 1
fi

if ! awk -v c="$CONFIDENCE" 'BEGIN{exit (c >= 0.75) ? 0 : 1}'; then
  echo "invalid-confidence-threshold:$CONFIDENCE"
  exit 1
fi

echo "ok:$TASK_ID"
