#!/bin/bash

set -euo pipefail

MAX_ITERATIONS=${MAX_ITERATIONS:-50}
CIRCUIT_BREAKER_ERRORS=${CIRCUIT_BREAKER_ERRORS:-3}
RATE_LIMIT_DELAY=${RATE_LIMIT_DELAY:-3}
CODEX_MODEL=${CODEX_MODEL:-"gpt-5.2-codex"}
SANDBOX_MODE=${SANDBOX_MODE:-"workspace-write"}

RALPH_MODE=${RALPH_MODE:-"DETECT"}
STOP_ON_SUCCESS=${STOP_ON_SUCCESS:-"true"}
AUTO_COMMIT=${AUTO_COMMIT:-"false"}

ADAPTIVE_MODE=${ADAPTIVE_MODE:-"true"}
COMPUTE_BUDGET=${COMPUTE_BUDGET:-100}
COMPUTE_USED=0

TARGET_DIR=${TARGET_DIR:-"./target"}
PLAN_FILE=${PLAN_FILE:-"IMPLEMENTATION_PLAN.md"}
LOG_FILE=${LOG_FILE:-"findings/loop.log"}
RUNTIME_CODEX_HOME=${CODEX_HOME:-"$PWD/.codex-runtime"}

ENGINEERING_GUARDRAILS=${ENGINEERING_GUARDRAILS:-"false"}
GUARDRAILS_PROMPT_FILE=${GUARDRAILS_PROMPT_FILE:-"PROMPT_engineering.md"}
HARD_ENFORCEMENT=${HARD_ENFORCEMENT:-"true"}
BOUNTY_MODE=${BOUNTY_MODE:-"false"}

SKIP_PRECHECK=${SKIP_PRECHECK:-"true"}
PRECHECK_REFRESH=${PRECHECK_REFRESH:-"false"}
CODEQL_REFRESH=${CODEQL_REFRESH:-"false"}
CODEQL_OUTPUT_DIR=${CODEQL_OUTPUT_DIR:-"findings/codeql_results"}
EIP_HANDBOOK_DIR=${EIP_HANDBOOK_DIR:-"tools/EIP-Security-Handbook/src"}
EIP_CHECKLIST_OUT=${EIP_CHECKLIST_OUT:-"findings/eip_security_checklist.md"}
EIP_CHECKLIST_JSON=${EIP_CHECKLIST_JSON:-"findings/eip_security_checklist.json"}
EIP_CHECKLIST_REFRESH=${EIP_CHECKLIST_REFRESH:-"false"}
PROTOCOL_VULN_INDEX_DIR=${PROTOCOL_VULN_INDEX_DIR:-"tools/protocol-vulnerabilities-index"}
PROTOCOL_VULN_CHECKLIST_OUT=${PROTOCOL_VULN_CHECKLIST_OUT:-"findings/protocol_vulnerability_checklist.md"}
PROTOCOL_VULN_CHECKLIST_JSON=${PROTOCOL_VULN_CHECKLIST_JSON:-"findings/protocol_vulnerability_checklist.json"}
PROTOCOL_VULN_CHECKLIST_REFRESH=${PROTOCOL_VULN_CHECKLIST_REFRESH:-"false"}

DETECT_GRADER=${DETECT_GRADER:-"scripts/grade_detect.sh"}
PATCH_GRADER=${PATCH_GRADER:-"scripts/grade_patch.sh"}
EXPLOIT_GRADER=${EXPLOIT_GRADER:-"scripts/grade_exploit.sh"}

CONSECUTIVE_ERRORS=0
COMPLETED_ITERATIONS=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
  echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
  echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✓ $1" | tee -a "$LOG_FILE"
}

log_warning() {
  echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠ $1" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✗ $1" | tee -a "$LOG_FILE"
}

log_compute() {
  echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} 💰 $1" | tee -a "$LOG_FILE"
}

normalize_mode() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

mode_from_plan() {
  if [ ! -f "$PLAN_FILE" ]; then
    echo "PLANNING"
    return
  fi

  if grep -Eq "^- \[( |/|\?)\]" "$PLAN_FILE" 2>/dev/null; then
    echo "BUILDING"
  else
    echo "COMPLETE"
  fi
}

resolve_mode() {
  local requested
  requested="$(normalize_mode "$RALPH_MODE")"
  case "$requested" in
    AUTO|"")
      mode_from_plan
      ;;
    PLANNING|BUILDING|DETECT|PATCH|EXPLOIT)
      echo "$requested"
      ;;
    *)
      log_error "Invalid RALPH_MODE=$RALPH_MODE (expected AUTO|PLANNING|BUILDING|DETECT|PATCH|EXPLOIT)"
      exit 1
      ;;
  esac
}

prompt_for_mode() {
  case "$1" in
    PLANNING) echo "PROMPT_plan.md" ;;
    BUILDING) echo "PROMPT_build.md" ;;
    DETECT) echo "PROMPT_detect.md" ;;
    PATCH) echo "PROMPT_patch.md" ;;
    EXPLOIT) echo "PROMPT_exploit.md" ;;
    *)
      log_error "Unsupported mode: $1"
      return 1
      ;;
  esac
}

cost_for_mode() {
  case "$1" in
    DETECT) echo 5 ;;
    PATCH) echo 4 ;;
    EXPLOIT) echo 6 ;;
    BUILDING) echo 3 ;;
    PLANNING) echo 2 ;;
    *) echo 2 ;;
  esac
}

current_task() {
  local line=""
  [ -f "$PLAN_FILE" ] || return 0
  line=$(grep -m1 -E "^- \[ \]" "$PLAN_FILE" || true)
  [ -n "$line" ] || line=$(grep -m1 -E "^- \[/\]" "$PLAN_FILE" || true)
  [ -n "$line" ] || line=$(grep -m1 -E "^- \[\?\]" "$PLAN_FILE" || true)
  [ -n "$line" ] || return 0

  local id=""
  id="$(echo "$line" | sed -nE 's/.*`([^`]+)`.*/\1/p')"
  [ -n "$id" ] || id="$(echo "$line" | sed -nE 's/.*\*\*([^*]+)\*\*.*/\1/p')"
  [ -n "$id" ] || id="$(echo "$line" | sed -nE 's/^- \[[^]]\] ([^[:space:]]+).*/\1/p')"
  echo "$id"
}

update_task_status() {
  local task_id="$1"
  local new_status="$2"
  local note="${3:-}"

  [ -f "$PLAN_FILE" ] || return 0
  local tmp
  tmp="$(mktemp)"
  awk -v id="$task_id" -v st="$new_status" -v note="$note" '
    BEGIN { updated=0 }
    {
      is_match = ($0 ~ ("`" id "`")) || ($0 ~ ("\\*\\*" id "\\*\\*"))
      if (!updated && is_match && $0 ~ /^- \[[^]]\]/) {
        sub(/^- \[[^]]\]/, "- [" st "]")
        print
        if (note != "") print " " note
        updated=1
        next
      }
      print
    }
  ' "$PLAN_FILE" > "$tmp"
  mv "$tmp" "$PLAN_FILE"
}

ensure_target_dir() {
  if [ -d "$TARGET_DIR" ] && [ -n "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
    return
  fi

  if [ -d "target" ] && [ -n "$(ls -A target 2>/dev/null)" ]; then
    TARGET_DIR="./target"
    return
  fi

  if [ -d "contracts" ] || [ -d "src" ]; then
    TARGET_DIR="."
    log_warning "No target folder found, falling back to current directory."
    return
  fi

  log_error "No target project found (expected TARGET_DIR, ./target, ./contracts, or ./src)."
  exit 1
}

ensure_dirs() {
  mkdir -p findings/vulnerabilities findings/tasks findings/triage findings/eval submission "$CODEQL_OUTPUT_DIR"
  [ -f "findings/negative_evidence.md" ] || { echo "# Negative Evidence Ledger" > findings/negative_evidence.md; echo "" >> findings/negative_evidence.md; }
  [ -f "findings/needs_review.md" ] || { echo "# Needs Review Ledger" > findings/needs_review.md; echo "" >> findings/needs_review.md; }
}

record_needs_review() {
  local reason="$1"
  local task_id="${2:-N/A}"
  echo "- [$(date '+%Y-%m-%d %H:%M:%S')] mode=${MODE:-UNKNOWN} task=$task_id reason=$reason" >> findings/needs_review.md
}

run_preflight() {
  [ "$SKIP_PRECHECK" = "true" ] && { log "Skipping preflight (SKIP_PRECHECK=true)."; return 0; }
  command -v python3 >/dev/null 2>&1 || { log_warning "python3 not found, skipping preflight."; return 0; }

  if [ -f "scripts/update_code_index.py" ]; then
    if [ -f "findings/target_code_index.md" ] && [ "$PRECHECK_REFRESH" != "true" ]; then
      log "Code index exists. Skipping."
    else
      log "Generating target code index..."
      python3 scripts/update_code_index.py --root "$TARGET_DIR" --output findings/target_code_index.md || log_warning "Code index generation failed"
    fi
  fi

  if [ -f "scripts/attack_surface.py" ]; then
    if [ -f "findings/attack_surface.md" ] && [ -f "findings/attack_surface.json" ] && [ "$PRECHECK_REFRESH" != "true" ]; then
      log "Attack surface exists. Skipping."
    else
      log "Generating attack surface map..."
      python3 scripts/attack_surface.py --root "$TARGET_DIR" --output findings/attack_surface.md --json findings/attack_surface.json || log_warning "Attack surface generation failed"
    fi
  fi
}

run_codeql_baseline() {
  [ "$ADAPTIVE_MODE" = "true" ] || return 0
  [ -x "scripts/run_codeql_baseline.sh" ] || { log_warning "CodeQL baseline script missing"; return 0; }

  if [ -d "findings/codeql-db" ] && [ "$CODEQL_REFRESH" != "true" ] && [ -d "$CODEQL_OUTPUT_DIR" ] && [ "$(ls -A "$CODEQL_OUTPUT_DIR" 2>/dev/null)" ]; then
    log "CodeQL results already present. Skipping baseline."
    return 0
  fi

  log "Running baseline CodeQL queries..."
  TARGET_DIR="$TARGET_DIR" DB_DIR="findings/codeql-db" OUTPUT_DIR="$CODEQL_OUTPUT_DIR" ./scripts/run_codeql_baseline.sh || log_warning "CodeQL baseline failed, continuing"
  return 0
}

run_eip_checklist() {
  [ -f "scripts/generate_eip_security_checklist.py" ] || return 0
  [ -d "$EIP_HANDBOOK_DIR" ] || { log "EIP handbook not found at $EIP_HANDBOOK_DIR; skipping EIP checklist."; return 0; }
  command -v python3 >/dev/null 2>&1 || { log_warning "python3 not found, skipping EIP checklist."; return 0; }

  if [ -f "$EIP_CHECKLIST_OUT" ] && [ "$EIP_CHECKLIST_REFRESH" != "true" ]; then
    log "EIP checklist exists. Skipping (EIP_CHECKLIST_REFRESH=false)."
    return 0
  fi

  log "Generating EIP security checklist from handbook..."
  python3 scripts/generate_eip_security_checklist.py \
    --target-dir "$TARGET_DIR" \
    --handbook-dir "$EIP_HANDBOOK_DIR" \
    --output "$EIP_CHECKLIST_OUT" \
    --json-output "$EIP_CHECKLIST_JSON" || log_warning "EIP checklist generation failed, continuing"
  return 0
}

run_protocol_vuln_checklist() {
  [ -f "scripts/generate_protocol_vuln_checklist.py" ] || return 0
  [ -d "$PROTOCOL_VULN_INDEX_DIR" ] || { log "Protocol vuln index not found at $PROTOCOL_VULN_INDEX_DIR; skipping protocol checklist."; return 0; }
  command -v python3 >/dev/null 2>&1 || { log_warning "python3 not found, skipping protocol checklist."; return 0; }

  if [ -f "$PROTOCOL_VULN_CHECKLIST_OUT" ] && [ "$PROTOCOL_VULN_CHECKLIST_REFRESH" != "true" ]; then
    log "Protocol checklist exists. Skipping (PROTOCOL_VULN_CHECKLIST_REFRESH=false)."
    return 0
  fi

  log "Generating protocol vulnerability checklist from index..."
  python3 scripts/generate_protocol_vuln_checklist.py \
    --target-dir "$TARGET_DIR" \
    --index-dir "$PROTOCOL_VULN_INDEX_DIR" \
    --output "$PROTOCOL_VULN_CHECKLIST_OUT" \
    --json-output "$PROTOCOL_VULN_CHECKLIST_JSON" || log_warning "Protocol checklist generation failed, continuing"
  return 0
}

bootstrap_for_mode() {
  local mode="$1"
  case "$mode" in
    DETECT)
      run_codeql_baseline
      run_eip_checklist
      run_protocol_vuln_checklist
      ;;
    PATCH|EXPLOIT)
      log "Skipping preflight and CodeQL baseline for mode $mode."
      ;;
    *)
      run_preflight
      run_codeql_baseline
      run_eip_checklist
      run_protocol_vuln_checklist
      ;;
  esac
}

run_codex() {
  local mode="$1"
  local prompt_file
  prompt_file="$(prompt_for_mode "$mode")"
  [ -f "$prompt_file" ] || { log_error "Prompt file missing for mode $mode: $prompt_file"; return 1; }

  log "Executing mode=$mode with prompt=$prompt_file"
  if [ "$ENGINEERING_GUARDRAILS" = "true" ] && [ -f "$GUARDRAILS_PROMPT_FILE" ]; then
    if {
      printf "SCOPE OVERRIDE:\n- Primary audit target is TARGET_DIR=%s\n- Prioritize this target for all outputs.\n\n" "$TARGET_DIR"
      [ "$BOUNTY_MODE" = "true" ] && printf "BOUNTY_MODE=true:\n- Prioritize exploitable high-impact paths and realistic asset loss.\n\n"
      cat "$GUARDRAILS_PROMPT_FILE"
      echo
      cat "$prompt_file"
    } | codex exec --model "$CODEX_MODEL" --sandbox "$SANDBOX_MODE" -; then
      return 0
    fi
    return 1
  fi

  if {
    printf "SCOPE OVERRIDE:\n- Primary audit target is TARGET_DIR=%s\n- Prioritize this target for all outputs.\n\n" "$TARGET_DIR"
    [ "$BOUNTY_MODE" = "true" ] && printf "BOUNTY_MODE=true:\n- Prioritize exploitable high-impact paths and realistic asset loss.\n\n"
    cat "$prompt_file"
  } | codex exec --model "$CODEX_MODEL" --sandbox "$SANDBOX_MODE" -; then
    return 0
  fi
  return 1
}

grade_planning() {
  [ -s "$PLAN_FILE" ] || { echo "missing-plan:$PLAN_FILE"; return 1; }
  return 0
}

grade_building() {
  local task_id="$1"
  local result="findings/tasks/${task_id}/result.md"
  [ -n "$task_id" ] || { echo "missing-task-id"; return 1; }
  [ -s "$result" ] || { echo "missing-result:$result"; return 1; }

  if [ -x "scripts/lint_task_result.sh" ]; then
    if [ "$HARD_ENFORCEMENT" = "true" ]; then
      scripts/lint_task_result.sh --v2 "$result" >/dev/null || return 1
    else
      scripts/lint_task_result.sh "$result" >/dev/null || return 1
    fi
  fi
  return 0
}

grade_mode() {
  local mode="$1"
  local task_id="${2:-}"
  case "$mode" in
    DETECT)
      [ -x "$DETECT_GRADER" ] || { echo "missing-grader:$DETECT_GRADER"; return 1; }
      "$DETECT_GRADER" >/dev/null
      ;;
    PATCH)
      [ -x "$PATCH_GRADER" ] || { echo "missing-grader:$PATCH_GRADER"; return 1; }
      "$PATCH_GRADER" >/dev/null
      ;;
    EXPLOIT)
      [ -x "$EXPLOIT_GRADER" ] || { echo "missing-grader:$EXPLOIT_GRADER"; return 1; }
      "$EXPLOIT_GRADER" >/dev/null
      ;;
    PLANNING)
      grade_planning
      ;;
    BUILDING)
      grade_building "$task_id"
      ;;
    *)
      echo "unsupported-mode:$mode"
      return 1
      ;;
  esac
}

update_building_status_from_result() {
  local task_id="$1"
  local result_file="findings/tasks/${task_id}/result.md"
  [ -f "$result_file" ] || return 0

  local status
  status="$(grep -i '^status:' "$result_file" | head -1 | awk -F: '{print $2}' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')"
  case "$status" in
    CONFIRMED|VULN|VULNERABLE) update_task_status "$task_id" "x" "✓ VULN FOUND - see findings/" ;;
    SECURE) update_task_status "$task_id" "x" "✓ SECURE - No vulnerability found" ;;
    PRUNED) update_task_status "$task_id" "x" "✓ PRUNED - False positive" ;;
    NEEDS_REVIEW) update_task_status "$task_id" "?" "NEEDS_REVIEW: Manual follow-up required" ;;
    *) update_task_status "$task_id" "?" "NEEDS_REVIEW: Unknown result status (${status:-none})" ;;
  esac
}

maybe_autocommit() {
  [ "$AUTO_COMMIT" = "true" ] || return 0
  [ -d ".git" ] || return 0
  git add -A >/dev/null 2>&1 || true
  git commit -m "Ralph iteration ${COMPLETED_ITERATIONS}: ${MODE:-UNKNOWN}" >/dev/null 2>&1 || true
}

print_header() {
  log "🔒 Ralph Security Researcher Loop Starting..."
  log "Configuration:"
  log "  - Ralph Mode: $RALPH_MODE"
  log "  - Max Iterations: $MAX_ITERATIONS"
  log "  - Codex Model: $CODEX_MODEL"
  log "  - Sandbox Mode: $SANDBOX_MODE"
  log "  - Rate Limit Delay: ${RATE_LIMIT_DELAY}s"
  log "  - Circuit Breaker: $CIRCUIT_BREAKER_ERRORS"
  log "  - Adaptive Mode: $ADAPTIVE_MODE"
  log "  - Compute Budget: $COMPUTE_BUDGET"
  log "  - Stop On Success: $STOP_ON_SUCCESS"
  log "  - Auto Commit: $AUTO_COMMIT"
  log "  - Bounty Mode: $BOUNTY_MODE"
  log "  - Skip Precheck: $SKIP_PRECHECK"
  log "  - CODEX_HOME: $RUNTIME_CODEX_HOME"
  log "  - EIP Handbook Dir: $EIP_HANDBOOK_DIR"
  log "  - EIP Checklist Out: $EIP_CHECKLIST_OUT"
  log "  - Protocol Vuln Index Dir: $PROTOCOL_VULN_INDEX_DIR"
  log "  - Protocol Checklist Out: $PROTOCOL_VULN_CHECKLIST_OUT"
}

main() {
  ensure_dirs
  ensure_target_dir
  mkdir -p "$RUNTIME_CODEX_HOME"
  export CODEX_HOME="$RUNTIME_CODEX_HOME"
  export TARGET_DIR

  print_header

  if ! command -v codex >/dev/null 2>&1; then
    log_error "codex CLI not available"
    exit 1
  fi

  BOOT_MODE="$(resolve_mode)"
  bootstrap_for_mode "$BOOT_MODE"

  for ((ITERATION=1; ITERATION<=MAX_ITERATIONS; ITERATION++)); do
    COMPLETED_ITERATIONS=$ITERATION
    MODE="$(resolve_mode)"

    if [ "$(normalize_mode "$RALPH_MODE")" = "AUTO" ] && [ "$MODE" = "COMPLETE" ]; then
      log_success "All tasks complete"
      break
    fi

    if [ "$CONSECUTIVE_ERRORS" -ge "$CIRCUIT_BREAKER_ERRORS" ]; then
      log_error "Circuit breaker triggered ($CONSECUTIVE_ERRORS errors)"
      break
    fi

    COST="$(cost_for_mode "$MODE")"
    if [ "$ADAPTIVE_MODE" = "true" ] && [ $((COMPUTE_USED + COST)) -gt "$COMPUTE_BUDGET" ]; then
      log_warning "Compute budget exhausted ($COMPUTE_USED/$COMPUTE_BUDGET)"
      break
    fi

    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Iteration $ITERATION/$MAX_ITERATIONS - Mode: $MODE"
    [ "$ADAPTIVE_MODE" = "true" ] && log_compute "Compute: $COMPUTE_USED/$COMPUTE_BUDGET"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    CURRENT_TASK=""
    if [ "$MODE" = "BUILDING" ]; then
      CURRENT_TASK="$(current_task)"
      if [ -z "$CURRENT_TASK" ]; then
        log_warning "No current task found for BUILDING mode; skipping iteration."
        continue
      fi
      log "Current task: $CURRENT_TASK"
      update_task_status "$CURRENT_TASK" "/" "In Progress - Iteration $ITERATION"
      [ -x "scripts/init_task_workspace.sh" ] && scripts/init_task_workspace.sh "$CURRENT_TASK" >/dev/null 2>&1 || true
    fi

    if run_codex "$MODE"; then
      if err="$(grade_mode "$MODE" "$CURRENT_TASK" 2>&1)"; then
        CONSECUTIVE_ERRORS=0
        log_success "Mode $MODE passed grading"

        if [ "$MODE" = "BUILDING" ] && [ -n "$CURRENT_TASK" ]; then
          update_building_status_from_result "$CURRENT_TASK"
        fi

        if [ "$ADAPTIVE_MODE" = "true" ]; then
          COMPUTE_USED=$((COMPUTE_USED + COST))
          log_compute "Used $COST units (total: $COMPUTE_USED/$COMPUTE_BUDGET)"
        fi

        maybe_autocommit

        if [ "$STOP_ON_SUCCESS" = "true" ]; then
          case "$MODE" in
            DETECT|PATCH|EXPLOIT)
              log_success "Mode $MODE completed successfully; stopping loop."
              break
              ;;
          esac
        fi
      else
        CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
        log_warning "Mode $MODE grading failed ($err)"
        [ -n "$CURRENT_TASK" ] && update_task_status "$CURRENT_TASK" "?" "NEEDS_REVIEW: $err"
        record_needs_review "$err" "${CURRENT_TASK:-$MODE}"
      fi
    else
      exit_code=$?
      CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
      log_error "Iteration $ITERATION failed (exit $exit_code)"
      log_warning "Codex run failed. Common causes: blocked network/API access, expired auth, or local CODEX_HOME permission issues."
      [ -n "$CURRENT_TASK" ] && update_task_status "$CURRENT_TASK" "?" "ERROR: Iteration failed (exit $exit_code)"
      record_needs_review "iteration-failed:$exit_code" "${CURRENT_TASK:-$MODE}"
    fi

    if [ "$ITERATION" -lt "$MAX_ITERATIONS" ] && [ "$RATE_LIMIT_DELAY" -gt 0 ]; then
      log "Waiting ${RATE_LIMIT_DELAY}s before next iteration..."
      sleep "$RATE_LIMIT_DELAY"
    fi
  done

  log ""
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "🏁 Ralph Loop Completed"
  log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  log "Total Iterations: $COMPLETED_ITERATIONS"
  [ "$ADAPTIVE_MODE" = "true" ] && log_compute "Total Compute Used: $COMPUTE_USED/$COMPUTE_BUDGET"
  log "Findings: findings/vulnerabilities/"
  log "Log: $LOG_FILE"
}

main "$@"
