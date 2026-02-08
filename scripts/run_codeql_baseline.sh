#!/bin/bash

###############################################################################
# CodeQL Baseline Query Runner
# Runs standard security queries against the target codebase
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
TARGET_DIR="${TARGET_DIR:-./target}"
DB_DIR="${DB_DIR:-findings/codeql-db}"
QUERIES_DIR="${QUERIES_DIR:-knowledges/codeql_queries}"
OUTPUT_DIR="${OUTPUT_DIR:-findings/codeql_results}"

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} ✓ $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} ✗ $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} ⚠ $1"
}

# Check prerequisites
check_prerequisites() {
    if ! command -v codeql &> /dev/null; then
        log_error "CodeQL CLI not found. Please install from https://github.com/github/codeql-cli-binaries"
        exit 1
    fi
    
    if [ ! -d "$TARGET_DIR" ]; then
        log_error "Target directory not found: $TARGET_DIR"
        exit 1
    fi
    
    mkdir -p "$OUTPUT_DIR"
}

# Create or update CodeQL database
create_database() {
    log "Creating CodeQL database..."
    
    if [ -d "$DB_DIR" ]; then
        log "Database exists, updating..."
        rm -rf "$DB_DIR"
    fi
    
    # Try to detect build system and create database
    if [ -f "$TARGET_DIR/foundry.toml" ]; then
        log "Detected Foundry project"
        codeql database create "$DB_DIR" \
            --language=solidity \
            --source-root="$TARGET_DIR" \
            --command="cd $TARGET_DIR && forge build" 2>&1 | tee "$OUTPUT_DIR/db_creation.log" || {
            log_warning "Foundry build failed, trying without build command"
            codeql database create "$DB_DIR" \
                --language=solidity \
                --source-root="$TARGET_DIR" 2>&1 | tee "$OUTPUT_DIR/db_creation.log"
        }
    elif [ -f "$TARGET_DIR/hardhat.config.js" ] || [ -f "$TARGET_DIR/hardhat.config.ts" ]; then
        log "Detected Hardhat project"
        codeql database create "$DB_DIR" \
            --language=solidity \
            --source-root="$TARGET_DIR" \
            --command="cd $TARGET_DIR && npx hardhat compile" 2>&1 | tee "$OUTPUT_DIR/db_creation.log" || {
            log_warning "Hardhat build failed, trying without build command"
            codeql database create "$DB_DIR" \
                --language=solidity \
                --source-root="$TARGET_DIR" 2>&1 | tee "$OUTPUT_DIR/db_creation.log"
        }
    else
        log "Creating database without build command..."
        codeql database create "$DB_DIR" \
            --language=solidity \
            --source-root="$TARGET_DIR" 2>&1 | tee "$OUTPUT_DIR/db_creation.log"
    fi
    
    log_success "Database created at $DB_DIR"
}

# Run a single query
run_query() {
    local query_file=$1
    local query_name=$(basename "$query_file" .ql)
    local output_file="$OUTPUT_DIR/${query_name}.csv"
    local log_file="$OUTPUT_DIR/${query_name}.log"
    
    log "Running query: $query_name"
    
    if codeql query run \
        --database="$DB_DIR" \
        --output="$output_file" \
        --format=csv \
        "$query_file" > "$log_file" 2>&1; then
        
        local result_count=$(wc -l < "$output_file" | tr -d ' ')
        result_count=$((result_count - 1))  # Subtract header
        
        if [ "$result_count" -gt 0 ]; then
            log_success "$query_name: Found $result_count results"
        else
            log "$query_name: No results found"
        fi
    else
        log_error "$query_name: Query failed (see $log_file)"
    fi
}

# Run all queries in the queries directory
run_all_queries() {
    log "Running baseline security queries..."
    
    if [ ! -d "$QUERIES_DIR" ]; then
        log_warning "Queries directory not found: $QUERIES_DIR"
        return
    fi
    
    local query_count=0
    for query in "$QUERIES_DIR"/*.ql; do
        if [ -f "$query" ]; then
            run_query "$query"
            query_count=$((query_count + 1))
        fi
    done
    
    log_success "Completed $query_count queries"
}

# Generate summary report
generate_summary() {
    local summary_file="$OUTPUT_DIR/summary.md"
    
    log "Generating summary report..."
    
    cat > "$summary_file" << EOF
# CodeQL Baseline Analysis Summary

## Overview

This report contains the results of automated CodeQL analysis for common security patterns.

**Generated**: $(date)
**Target**: $TARGET_DIR
**Database**: $DB_DIR

## Results by Category

EOF

    # Add results for each query
    for csv in "$OUTPUT_DIR"/*.csv; do
        if [ -f "$csv" ]; then
            local name=$(basename "$csv" .csv)
            local count=$(wc -l < "$csv" | tr -d ' ')
            count=$((count - 1))
            
            echo "### $name" >> "$summary_file"
            echo "" >> "$summary_file"
            echo "- **Findings**: $count" >> "$summary_file"
            echo "- **Details**: See \`${name}.csv\`" >> "$summary_file"
            echo "" >> "$summary_file"
            
            if [ "$count" -gt 0 ] && [ "$count" -lt 10 ]; then
                echo "**Sample findings**:" >> "$summary_file"
                echo '```' >> "$summary_file"
                head -n 6 "$csv" >> "$summary_file"
                echo '```' >> "$summary_file"
                echo "" >> "$summary_file"
            fi
        fi
    done
    
    cat >> "$summary_file" << EOF
## Next Steps

1. Review findings in detail (see individual .csv files)
2. Prioritize HIGH and CRITICAL severity findings
3. Verify each finding with the 6-step verification harness
4. Run targeted queries for specific vulnerability hypotheses

## Query Reference

| Query | Purpose |
|-------|---------|
| reentrancy.ql | Finds CEI violations |
| unchecked_calls.ql | Finds unchecked low-level calls |
| missing_access_control.ql | Finds sensitive functions without auth |
| oracle_staleness.ql | Finds oracle calls without staleness checks |
| external_functions.ql | Lists attack surface |
| state_mutation.ql | Tracks state variable modifications |

EOF

    log_success "Summary report: $summary_file"
}

# Main execution
main() {
    log "═══════════════════════════════════════════════════════"
    log "  CodeQL Baseline Analysis"
    log "═══════════════════════════════════════════════════════"
    
    check_prerequisites
    create_database
    run_all_queries
    generate_summary
    
    log "═══════════════════════════════════════════════════════"
    log_success "Analysis complete!"
    log "Results: $OUTPUT_DIR/"
    log "Summary: $OUTPUT_DIR/summary.md"
    log "═══════════════════════════════════════════════════════"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
