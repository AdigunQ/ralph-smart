#!/bin/bash

###############################################################################
# Ralph Loop for Security Researchers
# Autonomous vulnerability hunting loop combining Ralph methodology 
# with finite-monkey-engine's possibility space construction approach
# and agentic harness framework with adaptive compute allocation
###############################################################################

set -e

# Configuration
MAX_ITERATIONS=${MAX_ITERATIONS:-50}
CIRCUIT_BREAKER_ERRORS=${CIRCUIT_BREAKER_ERRORS:-3}
RATE_LIMIT_DELAY=${RATE_LIMIT_DELAY:-5}
CODEX_MODEL=${CODEX_MODEL:-"gpt-5.2-codex"}
SANDBOX_MODE=${SANDBOX_MODE:-"workspace-write"}
LOG_FILE="findings/loop.log"
ITERATION=0
CONSECUTIVE_ERRORS=0

# Adaptive Compute Allocation
COMPUTE_BUDGET=${COMPUTE_BUDGET:-100}  # Abstract compute units per audit
COMPUTE_USED=0
ADAPTIVE_MODE=${ADAPTIVE_MODE:-"true"}
CODEQL_REFRESH=${CODEQL_REFRESH:-"false"}
CODEQL_OUTPUT_DIR=${CODEQL_OUTPUT_DIR:-"findings/codeql_results"}
TARGET_DIR=${TARGET_DIR:-"./target"}
DOCS_FETCH=${DOCS_FETCH:-"false"}
DOCS_URLS_FILE=${DOCS_URLS_FILE:-"specs/external_docs/urls.txt"}
DOCS_OUT_DIR=${DOCS_OUT_DIR:-"specs/external_docs/raw"}
DOCS_DISCOVERY=${DOCS_DISCOVERY:-"false"}
DOCS_REFRESH=${DOCS_REFRESH:-"false"}
DOCS_MANIFEST=${DOCS_MANIFEST:-"specs/external_docs/manifest.csv"}
ENGINEERING_GUARDRAILS=${ENGINEERING_GUARDRAILS:-"true"}
GUARDRAILS_PROMPT_FILE=${GUARDRAILS_PROMPT_FILE:-"PROMPT_engineering.md"}
HARD_ENFORCEMENT=${HARD_ENFORCEMENT:-"true"}
BOUNTY_MODE=${BOUNTY_MODE:-"false"}
PRECHECK_REFRESH=${PRECHECK_REFRESH:-"false"}
SKIP_PRECHECK=${SKIP_PRECHECK:-"false"}
LEAN_MODE=${LEAN_MODE:-"false"}

# Lean profile: favor throughput by defaulting to cache reuse and less side-work.
if [ "$LEAN_MODE" = "true" ]; then
    SKIP_PRECHECK="true"
    PRECHECK_REFRESH="false"
    CODEQL_REFRESH="false"
    DOCS_DISCOVERY="false"
    DOCS_FETCH="false"
    RATE_LIMIT_DELAY="0"
fi

# Model selection based on task complexity
SCOUT_MODEL=${SCOUT_MODEL:-"gpt-5.2-codex"}
STRATEGIST_MODEL=${STRATEGIST_MODEL:-"gpt-5.2-codex"}
FINALIZER_MODEL=${FINALIZER_MODEL:-"gpt-5.2-codex"}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✓ $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ✗ $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} ⚠ $1" | tee -a "$LOG_FILE"
}

log_compute() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} 💰 $1" | tee -a "$LOG_FILE"
}

# Check if we're in planning or building mode
detect_mode() {
    if [ ! -f "IMPLEMENTATION_PLAN.md" ]; then
        echo "PLANNING"
    else
        # Check if all tasks are complete
        if grep -Eq "^- \\[( |/|\\?)\\]" IMPLEMENTATION_PLAN.md 2>/dev/null; then
            echo "BUILDING"
        else
            echo "COMPLETE"
        fi
    fi
}

# Determine compute level for current task
detect_compute_level() {
    local task_id=$1
    
    # Check if task specifies compute level in IMPLEMENTATION_PLAN.md
    if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        local task_section=$(grep -A 20 "^### $task_id" IMPLEMENTATION_PLAN.md 2>/dev/null)
        
        if echo "$task_section" | grep -q "Compute Level: HIGH"; then
            echo "HIGH"
            return
        elif echo "$task_section" | grep -q "Compute Level: MEDIUM"; then
            echo "MEDIUM"
            return
        elif echo "$task_section" | grep -q "Compute Level: LOW"; then
            echo "LOW"
            return
        fi
    fi
    
    # Default based on task type
    if [[ "$task_id" == CMP-* ]] || [[ "$task_id" == INV-* ]]; then
        echo "HIGH"  # Complex analysis tasks
    elif [[ "$task_id" == EXP-* ]] || [[ "$task_id" == ASM-* ]]; then
        echo "MEDIUM"  # Standard vulnerability checks
    else
        echo "LOW"  # Boundary checks and edge cases
    fi
}

adjust_compute_level_with_signals() {
    local task_id=$1
    local current_level=$2
    local boosted_level="$current_level"
    local signal_reason=""
    local task_section=""

    if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        task_section="$(grep -A 40 "^### $task_id" IMPLEMENTATION_PLAN.md 2>/dev/null || true)"
    fi

    if echo "$task_section" | grep -Eqi "Severity:\s*CRITICAL"; then
        boosted_level="HIGH"
        signal_reason="plan-severity:CRITICAL"
    elif echo "$task_section" | grep -Eqi "Severity:\s*HIGH" && [ "$current_level" = "LOW" ]; then
        boosted_level="MEDIUM"
        signal_reason="plan-severity:HIGH"
    fi

    # Deterministic hint escalation from baseline summary.
    if [ -f "findings/codeql_results/summary.md" ]; then
        local pattern=""
        case "$task_id" in
            INV-*) pattern="invariant|balance|supply" ;;
            ASM-*) pattern="access control|auth|permission|role|owner" ;;
            EXP-*) pattern="unchecked|external call|unsafe cast|overflow|underflow|delegatecall" ;;
            TMP-*) pattern="timelock|timestamp|stale|sequencer|delay" ;;
            CMP-*) pattern="flash loan|oracle|reentrancy|compos|cross-contract" ;;
            BND-*) pattern="zero|max|min|boundary|edge case" ;;
        esac
        if [ -n "$pattern" ] && grep -Eqi "$pattern" findings/codeql_results/summary.md; then
            boosted_level="HIGH"
            if [ -n "$signal_reason" ]; then
                signal_reason="${signal_reason},codeql-summary-signal"
            else
                signal_reason="codeql-summary-signal"
            fi
        fi
    fi

    if [ "$boosted_level" != "$current_level" ]; then
        log "Adaptive escalation for $task_id: $current_level -> $boosted_level ($signal_reason)"
    fi
    echo "$boosted_level"
}

# Select model based on compute level and role
select_model() {
    local compute_level=$1
    local role=$2
    
    case "$role" in
        "scout")
            echo "$SCOUT_MODEL"
            ;;
        "strategist")
            echo "$STRATEGIST_MODEL"
            ;;
        "finalizer")
            echo "$FINALIZER_MODEL"
            ;;
        *)
            # Default based on compute level
            case "$compute_level" in
                "HIGH")
                    echo "gpt-5.2-codex"
                    ;;
                "MEDIUM")
                    echo "gpt-5.2-codex"
                    ;;
                "LOW")
                    echo "gpt-5.2-codex"
                    ;;
                *)
                    echo "$CODEX_MODEL"
                    ;;
            esac
            ;;
    esac
}

# Calculate compute cost
calculate_compute_cost() {
    local compute_level=$1
    
    case "$compute_level" in
        "HIGH")
            echo "5"
            ;;
        "MEDIUM")
            echo "3"
            ;;
        "LOW")
            echo "1"
            ;;
        *)
            echo "2"
            ;;
    esac
}

# Run CodeQL baseline queries if not already done
run_codeql_baseline() {
    if [ -d "findings/codeql-db" ] && [ "$CODEQL_REFRESH" != "true" ] && [ -d "$CODEQL_OUTPUT_DIR" ] && [ "$(ls -A "$CODEQL_OUTPUT_DIR" 2>/dev/null)" ]; then
        log "CodeQL results already present. Skipping baseline (set CODEQL_REFRESH=true to rebuild)."
        return
    fi

    if [ -x "scripts/run_codeql_baseline.sh" ]; then
        log "Running baseline CodeQL queries (scripts/run_codeql_baseline.sh)..."
        TARGET_DIR="$TARGET_DIR" DB_DIR="findings/codeql-db" OUTPUT_DIR="$CODEQL_OUTPUT_DIR" \
            ./scripts/run_codeql_baseline.sh || log_warning "CodeQL baseline script failed, continuing without"
    else
        log_warning "CodeQL baseline script not found, skipping deterministic analysis"
    fi
}

# Exit conditions check
should_exit() {
    local mode=$1
    
    # Check max iterations
    if [ $ITERATION -ge $MAX_ITERATIONS ]; then
        log_warning "Max iterations ($MAX_ITERATIONS) reached"
        return 0
    fi
    
    # Check compute budget
    if [ "$ADAPTIVE_MODE" = "true" ] && [ $COMPUTE_USED -ge $COMPUTE_BUDGET ]; then
        log_warning "Compute budget exhausted ($COMPUTE_USED/$COMPUTE_BUDGET)"
        return 0
    fi
    
    # Check circuit breaker
    if [ $CONSECUTIVE_ERRORS -ge $CIRCUIT_BREAKER_ERRORS ]; then
        log_error "Circuit breaker triggered: $CONSECUTIVE_ERRORS consecutive errors"
        return 0
    fi
    
    # Check if work is complete
    if [ "$mode" = "COMPLETE" ]; then
        log_success "All tasks complete!"
        return 0
    fi
    
    return 1
}

# Get current task from implementation plan
current_task() {
    if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        local line=""
        line=$(grep -m1 -E "^- \\[ \\]" IMPLEMENTATION_PLAN.md)
        if [ -z "$line" ]; then
            line=$(grep -m1 -E "^- \\[/\\]" IMPLEMENTATION_PLAN.md)
        fi
        if [ -z "$line" ]; then
            line=$(grep -m1 -E "^- \\[\\?\\]" IMPLEMENTATION_PLAN.md)
        fi
        if [ -n "$line" ]; then
            echo "$line" | sed -E 's/.*\\*\\*([^:*]+)\\*\\*.*/\\1/'
        fi
    fi
}

# Update task status in implementation plan
update_task_status() {
    local task_id=$1
    local new_status=$2
    local note=$3
    
    if [ -f "IMPLEMENTATION_PLAN.md" ]; then
        # Update status marker
        sed -i.bak -E "s/^(- )\\[[^\\]]\\]( \\*\\*$task_id\\*\\*)/\\1[$new_status]\\2/" IMPLEMENTATION_PLAN.md
        
        # Add note if provided
        if [ -n "$note" ]; then
            sed -i.bak -E "\\|^- \\[$new_status\\] \\*\\*$task_id\\*\\*|a\\ $note" IMPLEMENTATION_PLAN.md
        fi
        
        rm -f IMPLEMENTATION_PLAN.md.bak
    fi
}

ensure_findings_dirs() {
    mkdir -p findings/vulnerabilities
    mkdir -p findings/tasks
    mkdir -p findings/triage
    mkdir -p "$CODEQL_OUTPUT_DIR"
    if [ ! -f "findings/negative_evidence.md" ]; then
        echo "# Negative Evidence Ledger" > findings/negative_evidence.md
        echo "" >> findings/negative_evidence.md
    fi
    if [ ! -f "findings/needs_review.md" ]; then
        echo "# Needs Review Ledger" > findings/needs_review.md
        echo "" >> findings/needs_review.md
    fi
}

record_needs_review() {
    local reason="$1"
    local task_id="${2:-}"
    local stamp
    stamp="$(date '+%Y-%m-%d %H:%M:%S')"
    {
        echo "- [$stamp] iteration=$ITERATION mode=${MODE:-UNKNOWN} task=${task_id:-N/A} reason=$reason"
    } >> findings/needs_review.md
}

validate_planning_clarifications() {
    local file="findings/clarifications_needed.md"

    if [ ! -f "$file" ]; then
        echo "missing-file:$file"
        return 1
    fi

    if ! grep -Eq "^clarification_status:" "$file"; then
        echo "missing-fields:clarification_status"
        return 1
    fi

    if ! grep -Eq "^assumptions:" "$file"; then
        echo "missing-fields:assumptions"
        return 1
    fi

    if ! grep -Eq "^open_questions:" "$file"; then
        echo "missing-fields:open_questions"
        return 1
    fi

    return 0
}

validate_external_integration_artifacts() {
    local integrations_file="findings/external_integrations.md"
    local gaps_file="findings/integration_gaps.md"

    if [ ! -f "$integrations_file" ]; then
        echo "missing-file:$integrations_file"
        return 1
    fi

    if ! grep -Eq "^integration_status:\s*(NONE|FOUND)$" "$integrations_file"; then
        echo "missing-fields:integration_status"
        return 1
    fi

    if grep -Eq "^integration_status:\s*FOUND$" "$integrations_file"; then
        if ! grep -Eq "^official_doc_url:" "$integrations_file"; then
            echo "missing-fields:official_doc_url"
            return 1
        fi
        if ! grep -Eq "^local_doc_path:" "$integrations_file"; then
            echo "missing-fields:local_doc_path"
            return 1
        fi
        if ! grep -Eq "^code_reference:" "$integrations_file"; then
            echo "missing-fields:code_reference"
            return 1
        fi

        if [ ! -f "$gaps_file" ]; then
            echo "missing-file:$gaps_file"
            return 1
        fi
        if ! grep -Eq "^doc_requirement_quote:" "$gaps_file"; then
            echo "missing-fields:doc_requirement_quote"
            return 1
        fi
        if ! grep -Eq "^code_reference:" "$gaps_file"; then
            echo "missing-fields:code_reference"
            return 1
        fi
        if ! grep -Eq "^verdict:\s*(CONFIRMED|PRUNED|NEEDS_REVIEW)$" "$gaps_file"; then
            echo "missing-fields:verdict"
            return 1
        fi
    fi

    return 0
}

validate_bounty_assessment() {
    local file="findings/bounty_program_assessment.md"
    if [ "$BOUNTY_MODE" != "true" ]; then
        return 0
    fi
    if [ -x "scripts/lint_bounty_assessment.sh" ]; then
        local lint_output
        if ! lint_output=$(scripts/lint_bounty_assessment.sh "$file" 2>&1); then
            echo "$lint_output"
            return 1
        fi
    elif [ ! -f "$file" ]; then
        echo "missing-file:$file"
        return 1
    fi
    return 0
}

validate_task_result_schema() {
    local task_id="$1"
    local result_file="findings/tasks/${task_id}/result.md"
    if [ ! -f "$result_file" ]; then
        echo "missing-file:$result_file"
        return 1
    fi

    if [ -x "scripts/lint_task_result.sh" ]; then
        local lint_output
        if [ "$HARD_ENFORCEMENT" = "true" ]; then
            if ! lint_output=$(scripts/lint_task_result.sh --v2 "$result_file" 2>&1); then
                echo "$lint_output"
                return 1
            fi
        elif ! lint_output=$(scripts/lint_task_result.sh "$result_file" 2>&1); then
            echo "$lint_output"
            return 1
        fi
    else
        # Minimal fallback when linter script is unavailable.
        if ! grep -Eq '^status:' "$result_file"; then
            echo "missing-fields:status"
            return 1
        fi
        if ! grep -Eq '^confidence:' "$result_file"; then
            echo "missing-fields:confidence"
            return 1
        fi
    fi

    return 0
}

validate_task_artifact_bundle() {
    local task_id="$1"
    if [ "$HARD_ENFORCEMENT" != "true" ]; then
        return 0
    fi
    if [ ! -x "scripts/lint_iteration_artifacts.sh" ]; then
        return 0
    fi

    local lint_output
    if ! lint_output=$(scripts/lint_iteration_artifacts.sh "$task_id" 2>&1); then
        echo "$lint_output"
        return 1
    fi
    return 0
}

validate_finding_quality_chain() {
    local task_id="$1"
    local result_file="findings/tasks/${task_id}/result.md"
    local repro_file="findings/tasks/${task_id}/repro.md"

    if [ "$HARD_ENFORCEMENT" != "true" ]; then
        return 0
    fi
    if [ ! -x "scripts/lint_finding_quality.sh" ]; then
        return 0
    fi
    if [ ! -f "$result_file" ] || [ ! -f "$repro_file" ]; then
        echo "missing-quality-inputs"
        return 1
    fi

    local lint_output
    if ! lint_output=$(scripts/lint_finding_quality.sh "$task_id" 2>&1); then
        echo "$lint_output"
        return 1
    fi
    return 0
}

refresh_root_cause_clusters() {
    if [ -x "scripts/generate_root_cause_clusters.sh" ]; then
        scripts/generate_root_cause_clusters.sh findings/root_cause_clusters.md >/dev/null 2>&1 \
            || log_warning "Root cause clustering generation failed"
    fi
}

refresh_benchmark_summary() {
    if [ -x "scripts/generate_benchmark_summary.sh" ]; then
        scripts/generate_benchmark_summary.sh findings/benchmark_summary.md >/dev/null 2>&1 \
            || log_warning "Benchmark summary generation failed"
    fi
}

run_preflight_indexes() {
    if [ "$SKIP_PRECHECK" = "true" ]; then
        log "Skipping preflight index generation (SKIP_PRECHECK=true)."
        return
    fi
    if command -v python3 &> /dev/null; then
        if [ -f "scripts/update_code_index.py" ]; then
            if [ -f "findings/target_code_index.md" ] && [ "$PRECHECK_REFRESH" != "true" ]; then
                log "Code index already present. Skipping (set PRECHECK_REFRESH=true to rebuild)."
            else
                log "Generating target code index..."
                python3 scripts/update_code_index.py --root "$TARGET_DIR" --output findings/target_code_index.md \
                    || log_warning "Code index generation failed"
            fi
        fi
        if [ -f "scripts/attack_surface.py" ]; then
            if [ -f "findings/attack_surface.md" ] && [ -f "findings/attack_surface.json" ] && [ "$PRECHECK_REFRESH" != "true" ]; then
                log "Attack surface already present. Skipping (set PRECHECK_REFRESH=true to rebuild)."
            else
                log "Generating attack surface map..."
                python3 scripts/attack_surface.py --root "$TARGET_DIR" \
                    --output findings/attack_surface.md \
                    --json findings/attack_surface.json \
                    || log_warning "Attack surface generation failed"
            fi
        fi
    else
        log_warning "python3 not found, skipping code index and attack surface generation"
    fi
}

discover_and_fetch_docs() {
    if [ "$DOCS_DISCOVERY" != "true" ]; then
        return
    fi
    if [ ! -f "findings/external_integrations.md" ]; then
        log_warning "External integrations map not found, skipping docs discovery."
        return
    fi
    if [ -f "$DOCS_MANIFEST" ] && [ "$DOCS_REFRESH" != "true" ]; then
        log "Docs manifest exists. Skipping discovery (set DOCS_REFRESH=true to refetch)."
        return
    fi
    if command -v python3 &> /dev/null && [ -x "scripts/discover_docs.py" ]; then
        log "Discovering documentation URLs for integrations..."
        python3 scripts/discover_docs.py \
            --integrations-file findings/external_integrations.md \
            --urls-file "$DOCS_URLS_FILE" \
            --log specs/external_docs/discovery.log \
            $( [ "$DOCS_REFRESH" = "true" ] && echo "--refresh" ) \
            || log_warning "Docs discovery failed."
    else
        log_warning "Docs discovery script not available, skipping."
        return
    fi
    if [ -f "$DOCS_URLS_FILE" ]; then
        URLS_FILE="$DOCS_URLS_FILE" OUT_DIR="$DOCS_OUT_DIR" ./scripts/fetch_docs.sh \
            || log_warning "Docs fetch failed (network or URL error)."
    fi
}

# Main loop
main() {
    log "🔒 Ralph Security Researcher Loop Starting..."
    log "Configuration:"
    log "  - Max Iterations: $MAX_ITERATIONS"
    log "  - Codex Model: $CODEX_MODEL"
    log "  - Sandbox Mode: $SANDBOX_MODE"
    log "  - Rate Limit Delay: ${RATE_LIMIT_DELAY}s"
    log "  - Circuit Breaker: $CIRCUIT_BREAKER_ERRORS errors"
    log "  - Adaptive Mode: $ADAPTIVE_MODE"
    log "  - Compute Budget: $COMPUTE_BUDGET units"
    log "  - Docs Fetch: $DOCS_FETCH"
    log "  - Docs Discovery: $DOCS_DISCOVERY"
    log "  - Hard Enforcement: $HARD_ENFORCEMENT"
    log "  - Bounty Mode: $BOUNTY_MODE"
    log "  - Lean Mode: $LEAN_MODE"
    log "  - Skip Precheck: $SKIP_PRECHECK"
    log "  - Precheck Refresh: $PRECHECK_REFRESH"
    echo ""
    
    # Ensure we have a target
    if [ ! -d "target" ] || [ -z "$(ls -A target 2>/dev/null)" ]; then
        if [ -d "contracts" ] || [ -d "src" ]; then
            log_warning "No ./target/ directory found, but detected source code in current directory."
            log "Running in INJECTED MODE (Auditing self)."
            TARGET_DIR="."
        else
            log_error "No target project found. Expected ./target/, ./contracts/, or ./src/"
            exit 1
        fi
    else
        TARGET_DIR="./target"
    fi
    export TARGET_DIR
    
    # Create findings directories
    ensure_findings_dirs
    mkdir -p findings/codeql-db 2>/dev/null || true
    if [ "$BOUNTY_MODE" = "true" ] && [ -x "scripts/init_bounty_context.sh" ]; then
        scripts/init_bounty_context.sh >/dev/null 2>&1 || true
    fi

    # Generate indexes for better targeting
    run_preflight_indexes
    
    # Run CodeQL baseline before starting
    if [ "$ADAPTIVE_MODE" = "true" ]; then
        run_codeql_baseline
    fi
    
    # Main loop
    while true; do
        MODE=$(detect_mode)

        # Check exit conditions before starting the next iteration.
        if should_exit "$MODE"; then
            break
        fi

        ITERATION=$((ITERATION + 1))
        
        log ""
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "Iteration $ITERATION/$MAX_ITERATIONS - Mode: $MODE"
        if [ "$ADAPTIVE_MODE" = "true" ]; then
            log_compute "Compute: $COMPUTE_USED/$COMPUTE_BUDGET units used"
        fi
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Determine task and compute level for BUILDING mode
        if [ "$MODE" = "BUILDING" ]; then
            CURRENT_TASK=$(current_task)
            if [ -n "$CURRENT_TASK" ]; then
                COMPUTE_LEVEL=$(detect_compute_level "$CURRENT_TASK")
                COMPUTE_LEVEL=$(adjust_compute_level_with_signals "$CURRENT_TASK" "$COMPUTE_LEVEL")
                SELECTED_MODEL=$(select_model "$COMPUTE_LEVEL" "default")
                COMPUTE_COST=$(calculate_compute_cost "$COMPUTE_LEVEL")
                
                log "Current Task: $CURRENT_TASK"
                log "Compute Level: $COMPUTE_LEVEL (cost: $COMPUTE_COST units)"
                log "Selected Model: $SELECTED_MODEL"
                
                # Update task to in-progress
                update_task_status "$CURRENT_TASK" "/" "In Progress - Iteration $ITERATION"

                # Ensure task workspace has v2 artifact files.
                if [ -x "scripts/init_task_workspace.sh" ]; then
                    scripts/init_task_workspace.sh "$CURRENT_TASK" >/dev/null 2>&1 || true
                fi
                
                # Check if we have budget for this task
                if [ "$ADAPTIVE_MODE" = "true" ]; then
                    REMAINING=$((COMPUTE_BUDGET - COMPUTE_USED))
                    if [ $COMPUTE_COST -gt $REMAINING ]; then
                        log_warning "Insufficient compute budget for $COMPUTE_LEVEL task ($COMPUTE_COST > $REMAINING)"
                        log "Skipping to next task or reducing compute level..."
                        
                        # Try to downgrade
                        if [ "$COMPUTE_LEVEL" = "HIGH" ]; then
                            COMPUTE_LEVEL="MEDIUM"
                            COMPUTE_COST=$(calculate_compute_cost "$COMPUTE_LEVEL")
                            log "Downgraded to $COMPUTE_LEVEL (cost: $COMPUTE_COST)"
                        elif [ "$COMPUTE_LEVEL" = "MEDIUM" ]; then
                            COMPUTE_LEVEL="LOW"
                            COMPUTE_COST=$(calculate_compute_cost "$COMPUTE_LEVEL")
                            log "Downgraded to $COMPUTE_LEVEL (cost: $COMPUTE_COST)"
                        else
                            log_warning "Cannot downgrade further, marking task for manual review"
                            update_task_status "$CURRENT_TASK" "?" "NEEDS_REVIEW: Insufficient compute budget"
                            continue
                        fi
                    fi
                fi
            fi
        fi
        
        # Select appropriate prompt
        if [ "$MODE" = "PLANNING" ]; then
            PROMPT_FILE="PROMPT_plan.md"
            log "📋 Running PLANNING mode..."
            USE_MODEL="$STRATEGIST_MODEL"  # Use best model for planning
        else
            PROMPT_FILE="PROMPT_build.md"
            log "🔨 Running BUILDING mode..."
            USE_MODEL="${SELECTED_MODEL:-$CODEX_MODEL}"
        fi
        
        # Build prompt stack (global engineering guardrails + mode prompt)
        PROMPT_STACK=("$PROMPT_FILE")
        if [ "$ENGINEERING_GUARDRAILS" = "true" ] && [ -f "$GUARDRAILS_PROMPT_FILE" ]; then
            PROMPT_STACK=("$GUARDRAILS_PROMPT_FILE" "$PROMPT_FILE")
        fi

        # Run Codex with the prompt stack
        log "Executing: codex --model $USE_MODEL --sandbox $SANDBOX_MODE"
        log "Prompt stack: ${PROMPT_STACK[*]}"
        
        if cat "${PROMPT_STACK[@]}" | codex --model "$USE_MODEL" --sandbox "$SANDBOX_MODE" --ask-for-approval never; then
            log_success "Iteration $ITERATION completed successfully"
            CONSECUTIVE_ERRORS=0
            ENFORCEMENT_BLOCKED="false"

            # Planning artifact enforcement
            if [ "$MODE" = "PLANNING" ] && [ "$HARD_ENFORCEMENT" = "true" ]; then
                PLAN_ENFORCEMENT_ERROR=""
                if ! PLAN_ENFORCEMENT_ERROR=$(validate_planning_clarifications); then
                    log_warning "Hard enforcement failed for PLANNING ($PLAN_ENFORCEMENT_ERROR)"
                    record_needs_review "$PLAN_ENFORCEMENT_ERROR"
                    ENFORCEMENT_BLOCKED="true"
                fi

                INTEGRATION_ENFORCEMENT_ERROR=""
                if ! INTEGRATION_ENFORCEMENT_ERROR=$(validate_external_integration_artifacts); then
                    log_warning "Integration enforcement failed for PLANNING ($INTEGRATION_ENFORCEMENT_ERROR)"
                    record_needs_review "$INTEGRATION_ENFORCEMENT_ERROR"
                    ENFORCEMENT_BLOCKED="true"
                fi

                BOUNTY_ENFORCEMENT_ERROR=""
                if ! BOUNTY_ENFORCEMENT_ERROR=$(validate_bounty_assessment); then
                    log_warning "Bounty assessment enforcement failed for PLANNING ($BOUNTY_ENFORCEMENT_ERROR)"
                    record_needs_review "$BOUNTY_ENFORCEMENT_ERROR"
                    ENFORCEMENT_BLOCKED="true"
                fi
            fi

            # Optional docs discovery after planning/build (requires external access)
            discover_and_fetch_docs

            # Refresh cross-task root cause recurrence map.
            refresh_root_cause_clusters
            refresh_benchmark_summary
            
            # Update compute tracking
            if [ "$ADAPTIVE_MODE" = "true" ] && [ "$MODE" = "BUILDING" ] && [ -n "$COMPUTE_COST" ]; then
                COMPUTE_USED=$((COMPUTE_USED + COMPUTE_COST))
                log_compute "Used $COMPUTE_COST units (total: $COMPUTE_USED)"
            fi
            
            # Update task status if in BUILDING mode
            if [ "$MODE" = "BUILDING" ] && [ -n "$CURRENT_TASK" ]; then
                TASK_RESULT="findings/tasks/${CURRENT_TASK}/result.md"
                if [ -f "$TASK_RESULT" ]; then
                    ENFORCEMENT_ERROR=""
                    if ! ENFORCEMENT_ERROR=$(validate_task_result_schema "$CURRENT_TASK"); then
                        log_warning "Hard enforcement failed for $CURRENT_TASK ($ENFORCEMENT_ERROR)"
                        update_task_status "$CURRENT_TASK" "?" "NEEDS_REVIEW: ${ENFORCEMENT_ERROR}"
                    elif ! ENFORCEMENT_ERROR=$(validate_task_artifact_bundle "$CURRENT_TASK"); then
                        log_warning "Artifact bundle enforcement failed for $CURRENT_TASK ($ENFORCEMENT_ERROR)"
                        update_task_status "$CURRENT_TASK" "?" "NEEDS_REVIEW: ${ENFORCEMENT_ERROR}"
                    elif ! ENFORCEMENT_ERROR=$(validate_finding_quality_chain "$CURRENT_TASK"); then
                        log_warning "Finding quality gate failed for $CURRENT_TASK ($ENFORCEMENT_ERROR)"
                        update_task_status "$CURRENT_TASK" "?" "NEEDS_REVIEW: ${ENFORCEMENT_ERROR}"
                    else
                    STATUS=$(grep -i "^status:" "$TASK_RESULT" | head -1 | awk -F: '{print $2}' | tr -d '[:space:]' | tr '[:lower:]' '[:upper:]')
                    case "$STATUS" in
                        CONFIRMED|VULN|VULNERABLE)
                            update_task_status "$CURRENT_TASK" "x" "✓ VULN FOUND - see findings/"
                            ;;
                        SECURE)
                            update_task_status "$CURRENT_TASK" "x" "✓ SECURE - No vulnerability found"
                            ;;
                        PRUNED)
                            update_task_status "$CURRENT_TASK" "x" "✓ PRUNED - False positive"
                            ;;
                        NEEDS_REVIEW)
                            update_task_status "$CURRENT_TASK" "?" "NEEDS_REVIEW: Manual follow-up required"
                            ;;
                        *)
                            log_warning "Task result status unrecognized for $CURRENT_TASK"
                            ;;
                    esac
                    fi
                else
                    if [ "$HARD_ENFORCEMENT" = "true" ]; then
                        log_warning "Hard enforcement failed for $CURRENT_TASK (missing result.md)"
                        update_task_status "$CURRENT_TASK" "?" "NEEDS_REVIEW: missing result.md"
                    else
                        # Check if finding was created
                        if find findings/vulnerabilities -name "*${CURRENT_TASK}*" -type f 2>/dev/null | grep -q .; then
                            update_task_status "$CURRENT_TASK" "x" "✓ VULN FOUND - see findings/"
                        else
                            update_task_status "$CURRENT_TASK" "x" "✓ SECURE - No vulnerability found"
                        fi
                    fi
                fi
            fi

            if [ "$ENFORCEMENT_BLOCKED" = "true" ]; then
                CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
                log_warning "Iteration $ITERATION marked NEEDS_REVIEW due to hard enforcement"
                continue
            fi
            
            # Commit progress (if git repo)
            if [ -d ".git" ]; then
                git add -A 2>/dev/null || true
                git commit -m "Ralph iteration $ITERATION: $MODE mode" 2>/dev/null || true
            fi
        else
            EXIT_CODE=$?
            log_error "Iteration $ITERATION failed with exit code $EXIT_CODE"
            CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
            
            # Mark task as needing review if in BUILDING mode
            if [ "$MODE" = "BUILDING" ] && [ -n "$CURRENT_TASK" ]; then
                update_task_status "$CURRENT_TASK" "?" "⚠ ERROR: Iteration failed (exit $EXIT_CODE)"
            fi
        fi
        
        # Rate limiting
        if [ $ITERATION -lt $MAX_ITERATIONS ]; then
            log "Waiting ${RATE_LIMIT_DELAY}s before next iteration..."
            sleep $RATE_LIMIT_DELAY
        fi
    done
    
    # Final summary
    log ""
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "🏁 Ralph Loop Completed"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Total Iterations: $ITERATION"
    if [ "$ADAPTIVE_MODE" = "true" ]; then
        log_compute "Total Compute Used: $COMPUTE_USED/$COMPUTE_BUDGET units"
    fi
    log "Findings saved to: findings/vulnerabilities/"
    log "Full log: $LOG_FILE"
    
    # Count findings
    if [ -d "findings/vulnerabilities" ]; then
        FINDING_COUNT=$(find findings/vulnerabilities -type f -name "*.md" | wc -l | tr -d ' ')
        log "Total Findings: $FINDING_COUNT"
    fi
    
    # Count CodeQL findings
    if [ -d "findings" ]; then
        CODEQL_COUNT=$(find findings -name "codeql_*.txt" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$CODEQL_COUNT" -gt 0 ]; then
            log "CodeQL Analysis Files: $CODEQL_COUNT"
        fi
    fi
    if [ -f "findings/root_cause_clusters.md" ]; then
        log "Root Cause Clusters: findings/root_cause_clusters.md"
    fi
    if [ -f "findings/benchmark_summary.md" ]; then
        log "Benchmark Summary: findings/benchmark_summary.md"
    fi
}

# Run main function
main "$@"
