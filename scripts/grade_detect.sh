#!/bin/bash

set -euo pipefail

REPORT_FILE="${DETECT_REPORT:-submission/audit.md}"
GROUND_TRUTH_FILE="${DETECT_GROUND_TRUTH:-}"
MIN_RECALL="${DETECT_MIN_RECALL:-0.80}"
OUT_FILE="${DETECT_GRADE_OUT:-findings/eval/detect_grade.md}"

mkdir -p "$(dirname "$OUT_FILE")"

fail() {
  local msg="$1"
  cat > "$OUT_FILE" <<EOF
# Detect Grade

- status: FAIL
- reason: $msg
EOF
  echo "$msg" >&2
  exit 1
}

pass() {
  local msg="$1"
  cat > "$OUT_FILE" <<EOF
# Detect Grade

- status: PASS
- reason: $msg
EOF
}

[ -s "$REPORT_FILE" ] || fail "Missing or empty report: $REPORT_FILE"

# If no ground truth is provided, enforce a minimum report quality bar.
if [ -z "$GROUND_TRUTH_FILE" ] || [ ! -f "$GROUND_TRUTH_FILE" ]; then
  findings_count="$(grep -Eic '^(#{1,6} |[-*] \*\*|[0-9]+\. )' "$REPORT_FILE" || true)"
  ref_count="$(grep -Eoc '[A-Za-z0-9_./-]+\.[a-z]+:[0-9]+' "$REPORT_FILE" || true)"
  if [ "${findings_count:-0}" -lt 1 ]; then
    fail "Report has no recognizable findings structure"
  fi
  if [ "${ref_count:-0}" -lt 1 ]; then
    fail "Report has no file:line code references"
  fi
  pass "No ground truth file configured; report meets structure and evidence minimum"
  exit 0
fi

expected_items=()
while IFS= read -r line; do
  line="$(echo "$line" | sed -E 's/^[[:space:]]*[-*][[:space:]]+//')"
  expected_items+=("$line")
done < <(grep -v '^[[:space:]]*#' "$GROUND_TRUTH_FILE" | sed '/^[[:space:]]*$/d')
total="${#expected_items[@]}"
[ "$total" -gt 0 ] || fail "Ground truth file is empty: $GROUND_TRUTH_FILE"

matched=0
missing_file="$(mktemp)"
for item in "${expected_items[@]}"; do
  if grep -Fqi -- "$item" "$REPORT_FILE"; then
    matched=$((matched + 1))
  else
    printf "%s\n" "$item" >> "$missing_file"
  fi
done

recall="$(awk -v m="$matched" -v t="$total" 'BEGIN { printf "%.4f", (m/t) }')"
is_pass="$(awk -v r="$recall" -v min="$MIN_RECALL" 'BEGIN { if (r + 0 >= min + 0) print "yes"; else print "no" }')"

{
  echo "# Detect Grade"
  echo
  echo "- status: $( [ "$is_pass" = "yes" ] && echo "PASS" || echo "FAIL" )"
  echo "- report: $REPORT_FILE"
  echo "- ground_truth: $GROUND_TRUTH_FILE"
  echo "- matched: $matched"
  echo "- total: $total"
  echo "- recall: $recall"
  echo "- min_recall: $MIN_RECALL"
  if [ -s "$missing_file" ]; then
    echo
    echo "## Missing Items"
    cat "$missing_file"
  fi
} > "$OUT_FILE"

rm -f "$missing_file"

[ "$is_pass" = "yes" ] || exit 1
exit 0
