#!/bin/bash

set -euo pipefail

REPO_URL="${EIP_HANDBOOK_REPO:-https://github.com/BengalCatBalu/EIP-Security-Handbook.git}"
DEST_DIR="${EIP_HANDBOOK_DEST:-tools/EIP-Security-Handbook}"

mkdir -p "$(dirname "$DEST_DIR")"

if [ -d "$DEST_DIR/.git" ]; then
  git -C "$DEST_DIR" pull --ff-only
else
  git clone "$REPO_URL" "$DEST_DIR"
fi

echo "ready: $DEST_DIR"
