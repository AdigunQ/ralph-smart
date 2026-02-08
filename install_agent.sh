#!/bin/bash

###############################################################################
# Ralph Security Agent Installer
# Installs the complete agentic security research framework
###############################################################################

set -e

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[INSTALL]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_info() {
    echo -e "${PURPLE}[INFO]${NC} $1"
}

# Header
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          🕵️  Ralph Security Agent Installer                  ║"
echo "║     Agentic Infrastructure for Zero-Day Vulnerability Research ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

log "Installing Ralph Security Agent into: $TARGET_DIR"

# Check prerequisites
log "Checking prerequisites..."

if [ ! -d "$TARGET_DIR" ]; then
    log_error "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/knowledges" ]; then
    log_error "Source directory missing critical files: $SOURCE_DIR/knowledges"
    exit 1
fi

# Git repository check
if [ ! -d "$TARGET_DIR/.git" ]; then
    log_warning "Target directory is not a git repository"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Copy critical files
log "📦 Installing Ralph Security Agent components..."

# Core knowledge base
cp -r "$SOURCE_DIR/knowledges" "$TARGET_DIR/" 2>/dev/null || {
    log_error "Failed to copy knowledge base"
    exit 1
}
log_success "Knowledge base installed"

# Agent workflows
cp -r "$SOURCE_DIR/.agent" "$TARGET_DIR/" 2>/dev/null || {
    log_warning "Agent workflows not found, skipping"
}

# Scripts
cp -r "$SOURCE_DIR/scripts" "$TARGET_DIR/" 2>/dev/null || {
    log_warning "Scripts not found, skipping"
}

# Core documentation
cp "$SOURCE_DIR/CLAUDE.md" "$TARGET_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR/AGENTS.md" "$TARGET_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR/PROMPT_plan.md" "$TARGET_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR/PROMPT_build.md" "$TARGET_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR/MANUAL_AUDIT_DEEP_READING.md" "$TARGET_DIR/" 2>/dev/null || true
cp "$SOURCE_DIR/IMPROVEMENTS_SUMMARY.md" "$TARGET_DIR/" 2>/dev/null || true

# Main loop script
cp "$SOURCE_DIR/loop.sh" "$TARGET_DIR/" 2>/dev/null || {
    log_warning "loop.sh not found, skipping"
}

# Safety check
cp "$SOURCE_DIR/safety_check.sh" "$TARGET_DIR/" 2>/dev/null || true

log_success "Core components installed"

# Setup scaffolding
log "🏗️  Setting up project structure..."

mkdir -p "$TARGET_DIR/_project_specs/features"
mkdir -p "$TARGET_DIR/_project_specs/todos"
mkdir -p "$TARGET_DIR/_project_specs/session"
mkdir -p "$TARGET_DIR/findings/vulnerabilities"
mkdir -p "$TARGET_DIR/findings/hound"
mkdir -p "$TARGET_DIR/findings/codeql_results"
mkdir -p "$TARGET_DIR/target"

# Create active todos file
cat > "$TARGET_DIR/_project_specs/todos/active.md" << 'EOF'
# Active Tasks

## Security Audit Tasks

### Planning Phase
- [ ] Run CodeQL baseline analysis
- [ ] Run pattern matching against Solodit database
- [ ] Create project analysis document
- [ ] Map business flows
- [ ] Document security assumptions
- [ ] Generate IMPLEMENTATION_PLAN.md

### Building Phase
- [ ] Execute invariant checks (INV)
- [ ] Execute assumption checks (ASM)
- [ ] Execute expression checks (EXP)
- [ ] Execute temporal checks (TMP)
- [ ] Execute composition checks (CMP)
- [ ] Execute boundary checks (BND)

### Verification Phase
- [ ] Verify critical findings with /verify
- [ ] Generate final audit report
- [ ] Review and prioritize findings

---

Last updated: $(date)
EOF

log_success "Project structure created"

# Install hooks
log "🛡️  Installing guardrails..."

cd "$TARGET_DIR"

# Make scripts executable
chmod +x "$TARGET_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$TARGET_DIR/scripts/"*.py 2>/dev/null || true
chmod +x "$TARGET_DIR/loop.sh" 2>/dev/null || true
chmod +x "$TARGET_DIR/safety_check.sh" 2>/dev/null || true

# Install Python dependencies
log "🐍 Installing Python dependencies..."

if command -v python3 &> /dev/null && [ -f "$SOURCE_DIR/requirements.txt" ]; then
    cp "$SOURCE_DIR/requirements.txt" "$TARGET_DIR/"
    pip3 install -q -r "$TARGET_DIR/requirements.txt" 2>/dev/null || {
        log_warning "pip install failed, you may need to install manually: pip install -r requirements.txt"
    }
    log_success "Python dependencies installed"
else
    log_warning "Python3 or requirements.txt not found, skipping Python setup"
fi

# Initialize git hooks if git repo
if [ -d ".git" ]; then
    # Pre-commit hook for complexity checks
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Ralph Security Agent - Pre-commit Hook

echo "🔍 Running complexity checks..."

# Check Python files
if command -v python3 &> /dev/null; then
    if [ -f "scripts/enforce_complexity.py" ]; then
        python3 scripts/enforce_complexity.py || {
            echo "❌ Complexity check failed"
            exit 1
        }
    fi
fi

# Check for large files
LARGE_FILES=$(git diff --cached --name-only | xargs -I {} find {} -size +1M 2>/dev/null)
if [ -n "$LARGE_FILES" ]; then
    echo "⚠️  Large files detected:"
    echo "$LARGE_FILES"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "✅ Pre-commit checks passed"
EOF
    chmod +x .git/hooks/pre-commit
    log_success "Git hooks installed"
fi

# Generate initial code index
log "🧠 Generating initial code index..."

if command -v python3 &> /dev/null; then
    if [ -f "scripts/update_code_index.py" ]; then
        python3 scripts/update_code_index.py 2>/dev/null || {
            log_warning "Code index generation failed, continuing..."
        }
    fi
else
    log_warning "Python3 not found, skipping code index"
fi

# Create IMPLEMENTATION_PLAN template if it doesn't exist
if [ ! -f "IMPLEMENTATION_PLAN.md" ]; then
    cat > "IMPLEMENTATION_PLAN.md" << 'EOF'
# IMPLEMENTATION_PLAN

## Status

- Total Tasks: TBD
- Completed: 0
- In Progress: 0
- Remaining: TBD
- CodeQL Findings: 0

## Planning Phase

- [ ] PROJ-001: Analyze project structure and architecture
- [ ] PROJ-002: Map business flows and asset movements
- [ ] PROJ-003: Document security assumptions
- [ ] PROJ-004: Run CodeQL baseline analysis

## Invariant Checks (INV)

- [ ] INV-001: Verify token supply invariants
- [ ] INV-002: Verify lending pool solvency
- [ ] INV-003: Verify collateral ratios

## Assumption Checks (ASM)

- [ ] ASM-001: Verify deposit-before-borrow enforcement
- [ ] ASM-002: Verify access control on privileged functions
- [ ] ASM-003: Verify timelock enforcement

## Expression Checks (EXP)

- [ ] EXP-001: Check reentrancy protection
- [ ] EXP-002: Check unchecked external calls
- [ ] EXP-003: Check arithmetic safety

## Temporal Checks (TMP)

- [ ] TMP-001: Verify state machine transitions
- [ ] TMP-002: Verify time-based restrictions

## Composition Checks (CMP)

- [ ] CMP-001: Test flash loan combinations
- [ ] CMP-002: Test callback interactions

## Boundary Checks (BND)

- [ ] BND-001: Test zero value handling
- [ ] BND-002: Test maximum value handling
- [ ] BND-003: Test array bounds

---

Generated by Ralph Security Agent Installer
Run `./loop.sh` to begin the audit
EOF
    log_success "IMPLEMENTATION_PLAN.md template created"
fi

# Final summary
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              ✅ Installation Complete!                        ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
log_info "Installed Components:"
echo "  📚 Knowledge Base:     ./knowledges/"
echo "  🤖 Agent Workflows:   ./.agent/workflows/"
echo "  📋 Project Specs:     ./_project_specs/"
echo "  🔍 Scripts:           ./scripts/"
echo "  📄 Documentation:     ./AGENTS.md"
echo ""
log_info "Quick Start Commands:"
echo "  ./loop.sh              # Start autonomous audit"
echo "  /hound                 # Deep reasoning analysis"
echo "  /verify [finding-id]   # Verify a finding"
echo "  /tdd [feature]         # Test-driven development"
echo ""
log_info "Workflow Integration:"
echo "  Run the agent in the target directory and use slash commands:"
echo "    /audit   - Full security audit"
echo "    /hound   - Generate mental maps"
echo "    /verify  - Mutation testing"
echo ""
log_success "Ralph Security Agent is ready! 🕵️"
echo ""
