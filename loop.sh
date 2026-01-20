#!/bin/bash

###############################################################################
# Ralph Loop for Security Researchers
# Autonomous vulnerability hunting loop combining Ralph methodology 
# with finite-monkey-engine's possibility space construction approach
###############################################################################

set -e

# Configuration
MAX_ITERATIONS=${MAX_ITERATIONS:-50}
CIRCUIT_BREAKER_ERRORS=${CIRCUIT_BREAKER_ERRORS:-3}
RATE_LIMIT_DELAY=${RATE_LIMIT_DELAY:-5}
CODEX_MODEL=${CODEX_MODEL:-"claude-sonnet-4"}
LOG_FILE="findings/loop.log"
ITERATION=0
CONSECUTIVE_ERRORS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Check if we're in planning or building mode
detect_mode() {
    if [ ! -f "IMPLEMENTATION_PLAN.md" ]; then
        echo "PLANNING"
    else
        # Check if all tasks are complete
        if grep -q "\[ \]" IMPLEMENTATION_PLAN.md 2>/dev/null; then
            echo "BUILDING"
        else
            echo "COMPLETE"
        fi
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

# Main loop
main() {
    log "🔒 Ralph Security Researcher Loop Starting..."
    log "Configuration:"
    log "  - Max Iterations: $MAX_ITERATIONS"
    log "  - Codex Model: $CODEX_MODEL"
    log "  - Rate Limit Delay: ${RATE_LIMIT_DELAY}s"
    log "  - Circuit Breaker: $CIRCUIT_BREAKER_ERRORS errors"
    echo ""
    
    # Ensure we have a target
    if [ ! -d "target" ] || [ -z "$(ls -A target 2>/dev/null)" ]; then
        if [ -d "contracts" ] || [ -d "src" ]; then
            log_warning "No ./target/ directory found, but detected source code in current directory."
            log "Running in INJECTED MODE (Auditing self)."
        else
            log_error "No target project found. Expected ./target/, ./contracts/, or ./src/"
            exit 1
        fi
    fi
    
    # Main loop
    while true; do
        ITERATION=$((ITERATION + 1))
        MODE=$(detect_mode)
        
        log ""
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log "Iteration $ITERATION/$MAX_ITERATIONS - Mode: $MODE"
        log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check exit conditions
        if should_exit "$MODE"; then
            break
        fi
        
        # Select appropriate prompt
        if [ "$MODE" = "PLANNING" ]; then
            PROMPT_FILE="PROMPT_plan.md"
            log "📋 Running PLANNING mode..."
        else
            PROMPT_FILE="PROMPT_build.md"
            log "🔨 Running BUILDING mode..."
        fi
        
        # Run Codex with the appropriate prompt
        log "Executing: codex --model $CODEX_MODEL < $PROMPT_FILE"
        
        if cat "$PROMPT_FILE" | codex --model "$CODEX_MODEL" --sandbox read-only --ask-for-approval never; then
            log_success "Iteration $ITERATION completed successfully"
            CONSECUTIVE_ERRORS=0
            
            # Commit progress (if git repo)
            if [ -d ".git" ]; then
                git add -A 2>/dev/null || true
                git commit -m "Ralph iteration $ITERATION: $MODE mode" 2>/dev/null || true
            fi
        else
            EXIT_CODE=$?
            log_error "Iteration $ITERATION failed with exit code $EXIT_CODE"
            CONSECUTIVE_ERRORS=$((CONSECUTIVE_ERRORS + 1))
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
    log "Findings saved to: findings/vulnerabilities/"
    log "Full log: $LOG_FILE"
    
    # Count findings
    if [ -d "findings/vulnerabilities" ]; then
        FINDING_COUNT=$(find findings/vulnerabilities -type f -name "*.md" | wc -l | tr -d ' ')
        log "Total Findings: $FINDING_COUNT"
    fi
}

# Run main function
main "$@"
