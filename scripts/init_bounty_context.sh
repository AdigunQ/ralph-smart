#!/usr/bin/env bash

set -euo pipefail

OUT_FILE="findings/bounty_program_assessment.md"
TEMPLATE_FILE="findings/_templates/bounty_program_assessment.md"

mkdir -p findings/rules_snapshot

if [ ! -f "$OUT_FILE" ]; then
  if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "missing-template:$TEMPLATE_FILE"
    exit 1
  fi
  cp "$TEMPLATE_FILE" "$OUT_FILE"
fi

echo "ok:$OUT_FILE"
