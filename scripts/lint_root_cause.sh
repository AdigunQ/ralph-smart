#!/usr/bin/env bash

set -euo pipefail

ROOT_CAUSE_FILE="${1:-}"

if [ -z "$ROOT_CAUSE_FILE" ]; then
  echo "usage: scripts/lint_root_cause.sh <root_cause.md>"
  exit 2
fi

if [ ! -f "$ROOT_CAUSE_FILE" ]; then
  echo "missing-file:$ROOT_CAUSE_FILE"
  exit 1
fi

require_field() {
  local key="$1"
  if ! grep -Eq "^${key}:" "$ROOT_CAUSE_FILE"; then
    echo "missing-fields:${key}"
    exit 1
  fi
}

require_list_item() {
  local key="$1"
  if ! awk -v key="$key" '
    BEGIN { sec=0; ok=0 }
    $0 ~ ("^" key ":") { sec=1; next }
    /^[a-zA-Z_]+:/ && sec==1 { sec=0 }
    sec==1 && /^[[:space:]]*-[[:space:]]+[^[:space:]]+/ { ok=1 }
    END { exit ok ? 0 : 1 }
  ' "$ROOT_CAUSE_FILE"; then
    echo "invalid-list:${key}"
    exit 1
  fi
}

require_field "task_id"
require_field "failure_class"
require_field "trigger_condition"
require_field "minimal_faulty_decision"
require_field "why_existing_controls_failed"
require_field "counterfactual_fix"
require_field "preventive_control"
require_field "patch_level"
require_field "root_cause_primary"
require_field "root_cause_secondary"
require_field "why1"
require_field "why2"
require_field "why3"
require_field "why4"
require_field "why5"
require_field "code_references"

if grep -Eq 'Replace with|__TASK_ID__' "$ROOT_CAUSE_FILE"; then
  echo "invalid-template-placeholders"
  exit 1
fi

if ! grep -Eq '^patch_level:\s*(local_fix|module_refactor|architecture_change|process_control)$' "$ROOT_CAUSE_FILE"; then
  echo "invalid-patch_level"
  exit 1
fi

if ! grep -Eq '^root_cause_primary:\s*(missing_invariant|unsafe_default|trust_boundary_break|state_machine_gap|integration_mismatch|spec_gap|test_gap|monitoring_gap|authorization_gap|input_validation_gap)$' "$ROOT_CAUSE_FILE"; then
  echo "invalid-root_cause_primary"
  exit 1
fi

if ! grep -Eq '^root_cause_secondary:\s*(NONE|missing_invariant|unsafe_default|trust_boundary_break|state_machine_gap|integration_mismatch|spec_gap|test_gap|monitoring_gap|authorization_gap|input_validation_gap)$' "$ROOT_CAUSE_FILE"; then
  echo "invalid-root_cause_secondary"
  exit 1
fi

if grep -Eqi '^(minimal_faulty_decision|why_existing_controls_failed):\s*"?\s*(developer mistake|human error|missing check|bug)\s*"?$' "$ROOT_CAUSE_FILE"; then
  echo "invalid-generic-rca"
  exit 1
fi

require_list_item "code_references"

echo "ok:$ROOT_CAUSE_FILE"
