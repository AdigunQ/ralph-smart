---
description: Run a full autonomous audit using the Ralph Loop with Verification Harness
trigger: /audit
---

# /audit - Full Autonomous Security Audit

This workflow triggers the complete autonomous auditing loop with verification harness, adaptive compute allocation, and deterministic analysis.

## Prerequisites Check

```bash
# Ensure executables
chmod +x loop.sh
chmod +x scripts/*.sh

# Check for CodeQL (optional but recommended)
which codeql || echo "⚠️ CodeQL not found - deterministic analysis disabled"

# Verify target exists
ls -la target/ 2>/dev/null || echo "⚠️ No target/ directory found"
```

## Phase 1: Planning (If Needed)

If `IMPLEMENTATION_PLAN.md` does not exist:

1. **Run Baseline CodeQL Analysis**
   ```bash
   ./scripts/run_codeql_baseline.sh 2>/dev/null || echo "Skipping CodeQL"
   ```

2. **Generate Audit Plan**
   ```bash
   # The loop will automatically start in PLANNING mode
   ./loop.sh
   ```

   This creates:
   - `findings/project_analysis.md` - Protocol understanding
   - `findings/business_flows.md` - Asset flow diagrams
   - `findings/assumptions.md` - Security assumptions
   - `IMPLEMENTATION_PLAN.md` - Systematic task checklist

## Phase 2: Building (Vulnerability Hunting)

The loop automatically switches to BUILDING mode:

```bash
# Run with default settings (100 compute units)
./loop.sh

# Or with custom settings
COMPUTE_BUDGET=200 CODEX_MODEL=claude-opus-4.5 ./loop.sh
```

### What Happens During Building

For each task in `IMPLEMENTATION_PLAN.md`:

1. **Deterministic Analysis** (CodeQL)
   - Run targeted queries for the task category
   - Document high-confidence patterns

2. **Hypothesis Generation** (Scout/Strategist)
   - Generate 3-5 vulnerability hypotheses
   - Apply reverse-scan methodology

3. **Verification Harness** (All 6 Steps)
   - Step 1: Observation checkpoint
   - Step 2: Reachability proof
   - Step 3: Controllability analysis
   - Step 4: Impact quantification
   - Step 5: PoC creation and testing
   - Step 6: Report generation

4. **5-Gate Verification**
   - Gate 1: Syntactic validity
   - Gate 2: Semantic analysis
   - Gate 3: Impact assessment
   - Gate 4: Exploitability proof
   - Gate 5: Report quality

## Monitoring Progress

```bash
# Watch the audit log
tail -f findings/loop.log

# Check findings so far
ls -la findings/vulnerabilities/

# Check compute usage
grep "Compute:" findings/loop.log | tail -5
```

## Expected Outputs

| File/Directory | Contents |
|---------------|----------|
| `findings/vulnerabilities/` | Confirmed vulnerability reports with PoCs |
| `findings/codeql_results/` | Deterministic analysis results |
| `findings/*.md` | Analysis documents (project, flows, assumptions) |
| `IMPLEMENTATION_PLAN.md` | Completed task checklist |
| `findings/loop.log` | Full audit execution log |

## Early Termination

The loop stops when any of these conditions are met:
- All tasks complete ✅
- Max iterations reached (default: 50)
- Circuit breaker triggered (3 consecutive errors)
- Compute budget exhausted

## Post-Audit

```bash
# Generate summary report
./scripts/generate_audit_report.sh

# Review findings
ls findings/vulnerabilities/*.md

# Validate critical findings
./scripts/validate_findings.sh
```

## Best Practices

1. **Start with CodeQL**: Ensures deterministic baseline
2. **Monitor Compute**: Adjust COMPUTE_BUDGET based on codebase size
3. **Review Early**: Check findings/vulnerabilities/ as they appear
4. **Validate Critical**: Run `/verify` on CRITICAL findings
5. **Iterate**: Re-run on updated codebases
