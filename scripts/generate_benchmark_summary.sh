#!/usr/bin/env bash

set -euo pipefail

OUT_FILE="${1:-findings/benchmark_summary.md}"
TASK_ROOT="findings/tasks"

mkdir -p "$(dirname "$OUT_FILE")"

total=0
confirmed=0
pruned=0
needs_review=0
quality_pass=0

if [ -d "$TASK_ROOT" ]; then
  for result in "$TASK_ROOT"/*/result.md; do
    [ -f "$result" ] || continue
    total=$((total + 1))
    task_id="$(basename "$(dirname "$result")")"
    status="$(grep -i '^status:' "$result" | head -1 | cut -d':' -f2- | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
    case "$status" in
      CONFIRMED|VULN|VULNERABLE) confirmed=$((confirmed + 1)) ;;
      PRUNED|SECURE) pruned=$((pruned + 1)) ;;
      NEEDS_REVIEW) needs_review=$((needs_review + 1)) ;;
    esac
    if [ -x "scripts/lint_finding_quality.sh" ] && scripts/lint_finding_quality.sh "$task_id" >/dev/null 2>&1; then
      quality_pass=$((quality_pass + 1))
    fi
  done
fi

cat > "$OUT_FILE" << EOF
# Benchmark Summary

Generated: $(date '+%Y-%m-%d %H:%M:%S')

total_tasks: $total
confirmed_findings: $confirmed
pruned_or_secure: $pruned
needs_review: $needs_review
quality_gate_passed: $quality_pass
EOF

echo "ok:$OUT_FILE"
