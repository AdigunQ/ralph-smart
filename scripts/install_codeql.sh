#!/usr/bin/env bash

set -euo pipefail

VERSION="${1:-latest}"
INSTALL_ROOT="${INSTALL_ROOT:-$PWD/.tools}"
CODEQL_DIR="$INSTALL_ROOT/codeql"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

detect_platform() {
  local os arch
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"

  case "$os" in
    darwin)
      echo "osx64"
      ;;
    linux)
      case "$arch" in
        x86_64|amd64) echo "linux64" ;;
        arm64|aarch64) echo "linux64" ;; # CodeQL currently distributes linux64; use with compatible runtime.
        *)
          echo "unsupported-arch:$arch"
          return 1
          ;;
      esac
      ;;
    *)
      echo "unsupported-os:$os"
      return 1
      ;;
  esac
}

PLATFORM="$(detect_platform)"
if [[ "$PLATFORM" == unsupported-* ]]; then
  echo "$PLATFORM"
  exit 1
fi

if [ "$VERSION" = "latest" ]; then
  DOWNLOAD_URL="https://github.com/github/codeql-cli-binaries/releases/latest/download/codeql-${PLATFORM}.zip"
else
  DOWNLOAD_URL="https://github.com/github/codeql-cli-binaries/releases/download/v${VERSION}/codeql-${PLATFORM}.zip"
fi

ZIP_PATH="$TMP_DIR/codeql.zip"
mkdir -p "$INSTALL_ROOT"

echo "Downloading CodeQL from: $DOWNLOAD_URL"
if ! curl -sL --connect-timeout 20 --max-time 300 --retry 3 --retry-delay 2 "$DOWNLOAD_URL" -o "$ZIP_PATH"; then
  echo "download-failed:$DOWNLOAD_URL"
  echo "hint: check network access or install manually from https://github.com/github/codeql-cli-binaries"
  exit 1
fi

if [ ! -s "$ZIP_PATH" ]; then
  echo "download-failed:$DOWNLOAD_URL"
  exit 1
fi

rm -rf "$CODEQL_DIR"
mkdir -p "$CODEQL_DIR"
unzip -q "$ZIP_PATH" -d "$CODEQL_DIR"

# Most archives unpack as codeql/<contents>; normalize so binary is at $CODEQL_DIR/codeql.
if [ ! -x "$CODEQL_DIR/codeql" ] && [ -x "$CODEQL_DIR/codeql/codeql" ]; then
  mv "$CODEQL_DIR/codeql"/* "$CODEQL_DIR"/
  rmdir "$CODEQL_DIR/codeql" 2>/dev/null || true
fi

if [ ! -x "$CODEQL_DIR/codeql" ]; then
  echo "install-failed:binary-not-found"
  exit 1
fi

echo "installed:$CODEQL_DIR"
echo "add-to-path:export PATH=\"$CODEQL_DIR:\$PATH\""
echo "version:$("$CODEQL_DIR/codeql" version | head -n 1)"
