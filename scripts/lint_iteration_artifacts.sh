#!/usr/bin/env bash

set -euo pipefail

TASK_INPUT="${1:-}"

if [ -z "$TASK_INPUT" ]; then
  echo "usage: scripts/lint_iteration_artifacts.sh <TASK-ID|findings/tasks/TASK-ID>"
  exit 2
fi

if [ -d "$TASK_INPUT" ]; then
  TASK_DIR="$TASK_INPUT"
  TASK_ID="$(basename "$TASK_DIR")"
else
  TASK_ID="$TASK_INPUT"
  TASK_DIR="findings/tasks/$TASK_ID"
fi

if [ ! -d "$TASK_DIR" ]; then
  echo "missing-dir:$TASK_DIR"
  exit 1
fi

require_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "missing-file:$file"
    exit 1
  fi
}

require_field() {
  local file="$1"
  local key="$2"
  if ! grep -Eq "^${key}:" "$file"; then
    echo "missing-fields:${file}:${key}"
    exit 1
  fi
}

require_list_item() {
  local file="$1"
  local key="$2"
  if ! awk -v key="$key" '
    BEGIN { sec=0; ok=0 }
    $0 ~ ("^" key ":") { sec=1; next }
    /^[a-zA-Z_]+:/ && sec==1 { sec=0 }
    sec==1 && /^[[:space:]]*-[[:space:]]+[^[:space:]]+/ { ok=1 }
    END { exit ok ? 0 : 1 }
  ' "$file"; then
    echo "invalid-list:${file}:${key}"
    exit 1
  fi
}

HYPOTHESES_FILE="$TASK_DIR/hypotheses.md"
EVIDENCE_FILE="$TASK_DIR/evidence.md"
REPRO_FILE="$TASK_DIR/repro.md"
REJECTED_FILE="$TASK_DIR/rejected.md"
ROOT_CAUSE_FILE="$TASK_DIR/root_cause.md"

require_file "$HYPOTHESES_FILE"
require_file "$EVIDENCE_FILE"
require_file "$REPRO_FILE"
require_file "$REJECTED_FILE"
require_file "$ROOT_CAUSE_FILE"

require_field "$HYPOTHESES_FILE" "task_id"
require_field "$HYPOTHESES_FILE" "deterministic_signal_basis"
require_field "$HYPOTHESES_FILE" "hypothesis_count"
require_field "$HYPOTHESES_FILE" "hypotheses"
require_list_item "$HYPOTHESES_FILE" "hypotheses"

if ! grep -Eq '^deterministic_signal_basis:\s*(CODEQL|NONE|MIXED)$' "$HYPOTHESES_FILE"; then
  echo "invalid-deterministic_signal_basis:$HYPOTHESES_FILE"
  exit 1
fi

require_field "$EVIDENCE_FILE" "task_id"
require_field "$EVIDENCE_FILE" "suspicious_behavior"
require_field "$EVIDENCE_FILE" "reachability"
require_field "$EVIDENCE_FILE" "controllability"
require_field "$EVIDENCE_FILE" "impact"
require_field "$EVIDENCE_FILE" "code_references"
require_list_item "$EVIDENCE_FILE" "code_references"

require_field "$REPRO_FILE" "task_id"
require_field "$REPRO_FILE" "reproduction_status"
require_field "$REPRO_FILE" "environment"
require_field "$REPRO_FILE" "steps"
require_field "$REPRO_FILE" "assertions"
require_list_item "$REPRO_FILE" "steps"
require_list_item "$REPRO_FILE" "assertions"

if ! grep -Eq '^reproduction_status:\s*(CONFIRMED|PRUNED|NEEDS_REVIEW|BLOCKED)$' "$REPRO_FILE"; then
  echo "invalid-reproduction_status:$REPRO_FILE"
  exit 1
fi

require_field "$REJECTED_FILE" "task_id"
require_field "$REJECTED_FILE" "rejected_count"
require_field "$REJECTED_FILE" "rejected_hypotheses"
require_list_item "$REJECTED_FILE" "rejected_hypotheses"

if [ -x "scripts/lint_root_cause.sh" ]; then
  rc_output="$(scripts/lint_root_cause.sh "$ROOT_CAUSE_FILE" 2>&1)" || {
    echo "$rc_output"
    exit 1
  }
else
  require_field "$ROOT_CAUSE_FILE" "task_id"
  require_field "$ROOT_CAUSE_FILE" "root_cause_primary"
  require_field "$ROOT_CAUSE_FILE" "patch_level"
fi

echo "ok:$TASK_DIR"
