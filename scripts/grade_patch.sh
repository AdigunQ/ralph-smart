#!/bin/bash

set -euo pipefail

PATCH_TEST_DIR="${PATCH_TEST_DIR:-target}"
PATCH_TEST_CMD="${PATCH_TEST_CMD:-forge test -vvv}"
PATCH_EXPLOIT_TEST_CMD="${PATCH_EXPLOIT_TEST_CMD:-}"
PATCH_PROTECTED_REGEX="${PATCH_PROTECTED_REGEX:-}"
OUT_FILE="${PATCH_GRADE_OUT:-findings/eval/patch_grade.md}"
LOG_DIR="${PATCH_GRADE_LOG_DIR:-findings/eval}"

ROOT_DIR="$(pwd)"
if [[ "$LOG_DIR" = /* ]]; then
  ABS_LOG_DIR="$LOG_DIR"
else
  ABS_LOG_DIR="$ROOT_DIR/$LOG_DIR"
fi
if [[ "$OUT_FILE" != /* ]]; then
  OUT_FILE="$ROOT_DIR/$OUT_FILE"
fi

mkdir -p "$ABS_LOG_DIR"
mkdir -p "$(dirname "$OUT_FILE")"

base_log="$ABS_LOG_DIR/patch_base_tests.log"
exploit_log="$ABS_LOG_DIR/patch_exploit_tests.log"

run_in_dir() {
  local cmd="$1"
  local log_file="$2"
  (
    cd "$PATCH_TEST_DIR"
    set +e
    eval "$cmd" >"$log_file" 2>&1
    code=$?
    set -e
    exit "$code"
  )
}

fail() {
  local msg="$1"
  cat > "$OUT_FILE" <<EOF
# Patch Grade

- status: FAIL
- reason: $msg
- base_log: $base_log
- exploit_log: $exploit_log
EOF
  echo "$msg" >&2
  exit 1
}

[ -d "$PATCH_TEST_DIR" ] || fail "Patch test directory not found: $PATCH_TEST_DIR"

if ! run_in_dir "$PATCH_TEST_CMD" "$base_log"; then
  fail "Base test suite failed: $PATCH_TEST_CMD"
fi

if [ -n "$PATCH_EXPLOIT_TEST_CMD" ]; then
  if run_in_dir "$PATCH_EXPLOIT_TEST_CMD" "$exploit_log"; then
    fail "Exploit regression command still succeeds: $PATCH_EXPLOIT_TEST_CMD"
  fi
fi

if [ -n "$PATCH_PROTECTED_REGEX" ] && [ -d "$PATCH_TEST_DIR/.git" ]; then
  changed="$(git -C "$PATCH_TEST_DIR" diff --name-only || true)"
  if [ -n "$changed" ] && echo "$changed" | grep -Eq "$PATCH_PROTECTED_REGEX"; then
    fail "Protected files modified (regex: $PATCH_PROTECTED_REGEX)"
  fi
fi

cat > "$OUT_FILE" <<EOF
# Patch Grade

- status: PASS
- patch_test_dir: $PATCH_TEST_DIR
- base_tests: $PATCH_TEST_CMD
- exploit_regression: ${PATCH_EXPLOIT_TEST_CMD:-not-configured}
- protected_regex: ${PATCH_PROTECTED_REGEX:-not-configured}
- base_log: $base_log
- exploit_log: $exploit_log
EOF

exit 0
