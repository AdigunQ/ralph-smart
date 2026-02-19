#!/usr/bin/env bash

set -euo pipefail

echo "Bootstrapping Ralph dependencies..."

if [ -x "./scripts/install_codeql.sh" ]; then
  ./scripts/install_codeql.sh || {
    echo "CodeQL install skipped/failed. You can retry with: ./scripts/install_codeql.sh"
    exit 1
  }
else
  echo "missing-script:./scripts/install_codeql.sh"
  exit 1
fi

if [ -x "./scripts/fetch_eip_handbook.sh" ]; then
  ./scripts/fetch_eip_handbook.sh || {
    echo "EIP handbook fetch failed. You can retry with: ./scripts/fetch_eip_handbook.sh"
  }
fi

if [ -x "./scripts/fetch_protocol_vuln_index.sh" ]; then
  ./scripts/fetch_protocol_vuln_index.sh || {
    echo "Protocol vulnerability index fetch failed. You can retry with: ./scripts/fetch_protocol_vuln_index.sh"
  }
fi

echo ""
echo "Bootstrap complete."
echo "Run this in your shell before auditing:"
echo "  export PATH=\"$PWD/.tools/codeql:\$PATH\""
