#!/usr/bin/env bash

set -euo pipefail

FILE="${1:-findings/bounty_program_assessment.md}"

if [ ! -f "$FILE" ]; then
  echo "missing-file:$FILE"
  exit 1
fi

require_field() {
  local key="$1"
  if ! grep -Eq "^${key}:" "$FILE"; then
    echo "missing-fields:${key}"
    exit 1
  fi
}

require_field "program_name"
require_field "program_url"
require_field "assessment_date"
require_field "mode"
require_field "target_priority"
require_field "complexity_score"
require_field "innovation_score"
require_field "optimization_risk_score"
require_field "integration_risk_score"
require_field "maturity_penalty_score"
require_field "expected_value_score"
require_field "rules_clarity"
require_field "scope_notes"
require_field "red_flags"
require_field "hunt_focus"
require_field "avoid_focus"
require_field "rules_snapshot_path"
require_field "go_no_go"

if grep -Eq 'Replace with|YYYY-MM-DD' "$FILE"; then
  echo "invalid-template-placeholders"
  exit 1
fi

if ! grep -Eq '^mode:\s*"(SPEEDRUNNER|DIGGER|DIFFER|WATCHMAN|LEAD_HUNTER|SCAVENGER|SCIENTIST)"$' "$FILE"; then
  echo "invalid-mode"
  exit 1
fi

if ! grep -Eq '^target_priority:\s*"(HIGH|MEDIUM|LOW)"$' "$FILE"; then
  echo "invalid-target_priority"
  exit 1
fi

if ! grep -Eq '^rules_clarity:\s*"(CLEAR|PARTIAL|UNCLEAR)"$' "$FILE"; then
  echo "invalid-rules_clarity"
  exit 1
fi

if ! grep -Eq '^go_no_go:\s*"(GO|LIMITED|NO_GO)"$' "$FILE"; then
  echo "invalid-go_no_go"
  exit 1
fi

for key in complexity_score innovation_score optimization_risk_score integration_risk_score maturity_penalty_score expected_value_score; do
  val="$(grep -E "^${key}:" "$FILE" | head -1 | cut -d: -f2- | tr -d '[:space:]')"
  if ! echo "$val" | grep -Eq '^[0-9]+$'; then
    echo "invalid-score:${key}"
    exit 1
  fi
  if [ "$val" -lt 0 ] || [ "$val" -gt 10 ]; then
    echo "invalid-score-range:${key}"
    exit 1
  fi
done

echo "ok:$FILE"
