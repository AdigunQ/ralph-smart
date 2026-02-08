#!/usr/bin/env bash

set -euo pipefail

OUT_FILE="${1:-findings/root_cause_clusters.md}"
TASK_ROOT="findings/tasks"

mkdir -p "$(dirname "$OUT_FILE")"

TMP_PRIMARY="$(mktemp)"
TMP_SECONDARY="$(mktemp)"
trap 'rm -f "$TMP_PRIMARY" "$TMP_SECONDARY"' EXIT

{
  echo "# Root Cause Clusters"
  echo ""
  echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
} > "$OUT_FILE"

if [ ! -d "$TASK_ROOT" ]; then
  {
    echo "## Summary"
    echo ""
    echo "No task directories found."
  } >> "$OUT_FILE"
  echo "ok:$OUT_FILE"
  exit 0
fi

for root_cause in "$TASK_ROOT"/*/root_cause.md; do
  [ -f "$root_cause" ] || continue
  task_id="$(basename "$(dirname "$root_cause")")"
  primary="$(grep -E '^root_cause_primary:' "$root_cause" | head -1 | cut -d':' -f2- | xargs || true)"
  secondary="$(grep -E '^root_cause_secondary:' "$root_cause" | head -1 | cut -d':' -f2- | xargs || true)"
  [ -n "$primary" ] && echo "$primary|$task_id" >> "$TMP_PRIMARY"
  [ -n "$secondary" ] && [ "$secondary" != "NONE" ] && echo "$secondary|$task_id" >> "$TMP_SECONDARY"
done

{
  echo "## Primary Clusters"
  echo ""
  if [ -s "$TMP_PRIMARY" ]; then
    while IFS='|' read -r tag count; do
      tasks="$(grep -E "^${tag}\|" "$TMP_PRIMARY" | cut -d'|' -f2 | sort -u | tr '\n' ',' | sed 's/,$//')"
      severity="isolated"
      if [ "$count" -ge 2 ]; then
        severity="systemic"
      fi
      echo "- tag: \`$tag\` | count: $count | class: $severity | tasks: $tasks"
    done < <(cut -d'|' -f1 "$TMP_PRIMARY" | sort | uniq -c | awk '{print $2 "|" $1}')
  else
    echo "No primary root-cause data."
  fi
  echo ""
  echo "## Secondary Clusters"
  echo ""
  if [ -s "$TMP_SECONDARY" ]; then
    while IFS='|' read -r tag count; do
      tasks="$(grep -E "^${tag}\|" "$TMP_SECONDARY" | cut -d'|' -f2 | sort -u | tr '\n' ',' | sed 's/,$//')"
      echo "- tag: \`$tag\` | count: $count | tasks: $tasks"
    done < <(cut -d'|' -f1 "$TMP_SECONDARY" | sort | uniq -c | awk '{print $2 "|" $1}')
  else
    echo "No secondary root-cause data."
  fi
} >> "$OUT_FILE"

echo "ok:$OUT_FILE"
