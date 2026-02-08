#!/usr/bin/env bash

set -euo pipefail

URL="${1:-}"
LABEL="${2:-}"

if [ -z "$URL" ] || [ -z "$LABEL" ]; then
  echo "usage: scripts/snapshot_bounty_rules.sh <url> <label>"
  exit 2
fi

OUT_DIR="findings/rules_snapshot"
mkdir -p "$OUT_DIR"
STAMP="$(date '+%Y%m%d_%H%M%S')"
OUT_FILE="$OUT_DIR/${LABEL}_${STAMP}.html"

curl -sL "$URL" > "$OUT_FILE"

if [ ! -s "$OUT_FILE" ]; then
  echo "snapshot-failed:$OUT_FILE"
  exit 1
fi

echo "ok:$OUT_FILE"
