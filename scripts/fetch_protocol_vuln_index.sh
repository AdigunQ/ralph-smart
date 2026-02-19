#!/usr/bin/env bash

set -euo pipefail

REPO_URL="https://github.com/kadenzipfel/protocol-vulnerabilities-index.git"
DEST_DIR="${1:-tools/protocol-vulnerabilities-index}"

if [ -d "$DEST_DIR/.git" ]; then
  git -C "$DEST_DIR" pull --ff-only
else
  mkdir -p "$(dirname "$DEST_DIR")"
  git clone "$REPO_URL" "$DEST_DIR"
fi
