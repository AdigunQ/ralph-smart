#!/usr/bin/env bash

set -euo pipefail

V2_MODE="false"
if [ "${1:-}" = "--v2" ]; then
  V2_MODE="true"
  shift
fi

RESULT_FILE="${1:-}"

if [ -z "$RESULT_FILE" ]; then
  echo "usage: scripts/lint_task_result.sh [--v2] <result.md>"
  exit 2
fi

if [ ! -f "$RESULT_FILE" ]; then
  echo "missing-file:$RESULT_FILE"
  exit 1
fi

require_field() {
  local key="$1"
  if ! grep -Eq "^${key}:" "$RESULT_FILE"; then
    echo "missing-fields:${key}"
    exit 1
  fi
}

reject_template_defaults_v2() {
  local file="$1"
  if grep -Eq 'Replace with|__TASK_ID__' "$file"; then
    echo "invalid-template-placeholders"
    exit 1
  fi
  if grep -Eq '^evidence:\s*"See evidence\.md and hypotheses\.md\."' "$file"; then
    echo "invalid-template-default:evidence"
    exit 1
  fi
  if grep -Eq '^reachability:\s*"See evidence\.md\."' "$file"; then
    echo "invalid-template-default:reachability"
    exit 1
  fi
  if grep -Eq '^controllability:\s*"See evidence\.md\."' "$file"; then
    echo "invalid-template-default:controllability"
    exit 1
  fi
  if grep -Eq '^impact:\s*"See evidence\.md\."' "$file"; then
    echo "invalid-template-default:impact"
    exit 1
  fi
  if grep -Eq '^poc:\s*"See repro\.md\."' "$file"; then
    echo "invalid-template-default:poc"
    exit 1
  fi
}

require_field "status"
require_field "confidence"
require_field "evidence"
require_field "assumptions"
require_field "scope_checked"
require_field "out_of_scope"

if [ "$V2_MODE" = "true" ]; then
  require_field "reachability"
  require_field "controllability"
  require_field "impact"
  require_field "poc"
  require_field "deterministic_signal_basis"
  require_field "rejected_hypotheses_logged"
  require_field "root_cause_primary"
  require_field "root_cause_secondary"
  require_field "patch_level"
  require_field "counterfactual_fix"
  require_field "five_whys_present"
  require_field "deterministic_override_approved"
  require_field "deterministic_override_rationale"
fi

STATUS_VAL="$(grep -E '^status:' "$RESULT_FILE" | head -1 | cut -d':' -f2- | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
case "$STATUS_VAL" in
  CONFIRMED|SECURE|PRUNED|NEEDS_REVIEW|VULN|VULNERABLE) ;;
  *)
    echo "invalid-status:${STATUS_VAL}"
    exit 1
    ;;
esac

if ! grep -Eq '^scope_checked:\s*(true|false)$' "$RESULT_FILE"; then
  echo "invalid-scope_checked"
  exit 1
fi

if [ "$V2_MODE" = "true" ]; then
  if ! grep -Eq '^deterministic_signal_basis:\s*(CODEQL|NONE|MIXED)$' "$RESULT_FILE"; then
    echo "invalid-deterministic_signal_basis"
    exit 1
  fi
  if ! grep -Eq '^rejected_hypotheses_logged:\s*(true|false)$' "$RESULT_FILE"; then
    echo "invalid-rejected_hypotheses_logged"
    exit 1
  fi
  if ! grep -Eq '^root_cause_primary:\s*(missing_invariant|unsafe_default|trust_boundary_break|state_machine_gap|integration_mismatch|spec_gap|test_gap|monitoring_gap|authorization_gap|input_validation_gap)$' "$RESULT_FILE"; then
    echo "invalid-root_cause_primary"
    exit 1
  fi
  if ! grep -Eq '^root_cause_secondary:\s*(NONE|missing_invariant|unsafe_default|trust_boundary_break|state_machine_gap|integration_mismatch|spec_gap|test_gap|monitoring_gap|authorization_gap|input_validation_gap)$' "$RESULT_FILE"; then
    echo "invalid-root_cause_secondary"
    exit 1
  fi
  if ! grep -Eq '^patch_level:\s*(local_fix|module_refactor|architecture_change|process_control)$' "$RESULT_FILE"; then
    echo "invalid-patch_level"
    exit 1
  fi
  if ! grep -Eq '^five_whys_present:\s*(true|false)$' "$RESULT_FILE"; then
    echo "invalid-five_whys_present"
    exit 1
  fi
  if ! grep -Eq '^deterministic_override_approved:\s*(true|false)$' "$RESULT_FILE"; then
    echo "invalid-deterministic_override_approved"
    exit 1
  fi
  if grep -Eq '^counterfactual_fix:\s*"?(N/A|None|none)?\"?$' "$RESULT_FILE"; then
    echo "invalid-counterfactual_fix"
    exit 1
  fi
  if echo "$STATUS_VAL" | grep -Eq '^(CONFIRMED|VULN|VULNERABLE)$'; then
    if ! grep -Eq '^five_whys_present:\s*true$' "$RESULT_FILE"; then
      echo "invalid-five_whys_present-for-confirmed"
      exit 1
    fi
    basis="$(grep -E '^deterministic_signal_basis:' "$RESULT_FILE" | head -1 | cut -d':' -f2- | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    override="$(grep -E '^deterministic_override_approved:' "$RESULT_FILE" | head -1 | cut -d':' -f2- | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    rationale="$(grep -E '^deterministic_override_rationale:' "$RESULT_FILE" | head -1 | cut -d':' -f2- | sed 's/^ *//')"
    if [ "$basis" = "NONE" ] && [ "$override" != "TRUE" ]; then
      echo "invalid-confirmed-without-determinism-override"
      exit 1
    fi
    if [ "$basis" = "NONE" ] && echo "$rationale" | grep -Eq '^"?\s*(N/A|None|none|not applicable)?\s*"?$'; then
      echo "invalid-determinism-override-rationale"
      exit 1
    fi
  fi
  reject_template_defaults_v2 "$RESULT_FILE"
fi

# Ensure assumptions and out_of_scope include at least one list item each.
if ! awk '
  BEGIN { sec=0; ok=0 }
  /^assumptions:/ { sec=1; next }
  /^[a-zA-Z_]+:/ && sec==1 { sec=0 }
  sec==1 && /^[[:space:]]*-[[:space:]]+[^[:space:]]+/ { ok=1 }
  END { exit ok ? 0 : 1 }
' "$RESULT_FILE"; then
  echo "invalid-assumptions-list"
  exit 1
fi

if ! awk '
  BEGIN { sec=0; ok=0 }
  /^out_of_scope:/ { sec=1; next }
  /^[a-zA-Z_]+:/ && sec==1 { sec=0 }
  sec==1 && /^[[:space:]]*-[[:space:]]+[^[:space:]]+/ { ok=1 }
  END { exit ok ? 0 : 1 }
' "$RESULT_FILE"; then
  echo "invalid-out_of_scope-list"
  exit 1
fi

echo "ok:$RESULT_FILE"
