# Quick Start: Using Ralph on Your Local Codebase

## Step 1: Copy Ralph to Your Project

```bash
# From your target project directory
cd /path/to/your/smart-contract-project

# Copy Ralph files
cp -r /Users/qeew/.gemini/antigravity/scratch/ralph-security-researcher/.ralph .
```

## Step 2: Create Project-Specific Configuration

Create a `spec.md` file in your project root describing what to audit:

```markdown
# Audit Scope

## Target Contracts

- contracts/Vault.sol - Main vault implementation
- contracts/LendingPool.sol - Lending logic
- contracts/Oracle.sol - Price oracle

## Focus Areas

1. Vault share manipulation
2. Reentrancy in deposit/withdraw
3. Oracle price manipulation
4. Access control bypasses

## Known Trust Assumptions

- Admin is trusted
- Oracle is assumed secure
- Using Chainlink price feeds

## Out of Scope

- Governance contracts
- Token contracts
```

## Step 3: Start Ralph

```bash
# Make Ralph executable
chmod +x .ralph/ralph.sh

# Start the autonomous loop
.ralph/ralph.sh
```

## How Ralph Works

### Planning Phase

1. Ralph reads your `spec.md`
2. Analyzes the codebase structure
3. Creates a detailed audit plan in `PLAN.md`
4. **STOPS and waits for your approval**

### Execution Phase (after you approve)

Ralph autonomously:

1. Performs taint analysis on each contract
2. Checks against 600+ vulnerability patterns
3. Creates PoC exploits when vulnerabilities found
4. Writes findings to `FINDINGS.md`
5. Continues until backpressure limits reached

## Example Workflow

```bash
# 1. Set up your project
cd ~/projects/my-defi-protocol
cp -r /Users/qeew/.gemini/antigravity/scratch/ralph-security-researcher/.ralph .

# 2. Create audit scope
cat > spec.md << 'EOF'
# Audit: MyDeFi Vault System

## Contracts
- src/Vault.sol
- src/Strategy.sol
- src/RewardDistributor.sol

## Critical Functions
- deposit()
- withdraw()
- harvest()
- distributeRewards()

## Known Issues to Verify
- Check if first depositor attack is mitigated
- Verify reward accounting is correct
EOF

# 3. Start Ralph
.ralph/ralph.sh

# 4. Review the PLAN.md that Ralph creates
# 5. If plan looks good, respond "proceed" when Ralph asks
# 6. Ralph runs autonomously until done or backpressure limit
```

## Backpressure Mechanisms

Ralph stops and asks for review when:

- **Initial planning** - Always reviews plan before execution
- **Every 30 tool calls** - Prevents runaway execution
- **Found vulnerability** - Lets you review before continuing
- **PoC test fails** - Needs debugging guidance
- **Unclear scope** - Asks for clarification

## Customizing for Your Needs

### Adjust Focus Areas

Edit `.ralph/PROMPT_build.md` to emphasize specific vulnerability types:

```markdown
## Priority Checks

1. CRITICAL: Check for reentrancy in all external calls
2. HIGH: Verify oracle manipulation resistance
3. MEDIUM: Check access control on admin functions
```

### Add Custom Taint Models

Create `.ralph/knowledges/taint_models/custom.md`:

```markdown
# Custom Taint Model: Flash Loan Attack

## Invariant

Flash loan borrowed amount must equal repaid amount within same transaction

## Attack Pattern

1. Borrow from flash loan pool
2. Manipulate state before repay
3. Repay loan
4. State remains manipulated

## Check Points

- All flash loan callbacks
- State changes during callbacks
- Balance checks after repay
```

### Use with CI/CD

```yaml
# .github/workflows/security-audit.yml
name: Ralph Security Scan
on: [pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Run Ralph
        run: |
          # Setup Ralph
          cp -r .ralph .

          # Create minimal spec
          echo "# PR Audit - Check changed files only" > spec.md

          # Run with timeout
          timeout 30m .ralph/ralph.sh

      - name: Upload Findings
        uses: actions/upload-artifact@v2
        with:
          name: security-findings
          path: FINDINGS.md
```

## Advanced Usage

### Multi-Stage Audits

```bash
# Stage 1: Quick scan
echo "# Quick Scan - High severity only" > spec.md
.ralph/ralph.sh

# Stage 2: Deep dive on findings
echo "# Deep Dive - Verify H-01 and H-02" > spec.md
.ralph/ralph.sh

# Stage 3: PoC development
echo "# Develop PoCs for confirmed issues" > spec.md
.ralph/ralph.sh
```

### Combine with Manual Review

1. Ralph finds potential issues → `FINDINGS.md`
2. You manually verify → Keep valid findings
3. Ralph creates PoCs → `test/exploits/`
4. You polish PoCs → Production test suite

## Tips

- **Start small**: First run on a single contract
- **Iterate scope**: Expand as Ralph proves reliable
- **Review plans**: Don't blindly accept auto-generated plans
- **Test PoCs**: Always verify Ralph's exploits work
- **Update knowledge**: Add your findings to `.ralph/knowledges/`

## Troubleshooting

**Ralph gets stuck in loops**

- Reduce scope in `spec.md`
- Add specific acceptance criteria
- Increase backpressure frequency

**Too many false positives**

- Add trust assumptions to `spec.md`
- Update vulnerability patterns to exclude known-safe patterns
- Adjust severity thresholds

**Not finding real bugs**

- Make spec more specific about attack vectors
- Add known vulnerability patterns from past audits
- Review and expand knowledge base

## Next Steps

1. Try Ralph on a simple contract first
2. Review the generated `PLAN.md` carefully
3. Let Ralph run one iteration
4. Review findings and adjust scope
5. Iterate until comfortable with the workflow
