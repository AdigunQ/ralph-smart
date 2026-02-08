# Ralph Security Agent - Complete Usage Guide

## 🎯 Overview

Ralph is an agentic security research framework that combines:
- **Deterministic analysis** (CodeQL) with **LLM reasoning**
- **50k+ vulnerability patterns** via Solodit API
- **6-step verification harness** for rigorous findings
- **Subagent orchestration** for parallel analysis

---

## 🚀 Quick Start (5 Minutes)

### 1. Install Ralph into Your Project

```bash
# Navigate to your smart contract project
cd /path/to/your/defi-protocol

# Run the installer from Ralph source
bash /path/to/ralph-security-agent/install_agent.sh .
```

### 2. Set Up Environment (if using Solodit)

```bash
# Create .env file with your API key
cat > .env << 'EOF'
SOLODIT_API_KEY=sk_a85ffa506959b614c800ec397388ae1642efc7dda88bcae726f1ee54e87385a4
EOF
```

### 3. Create Audit Spec

```bash
cat > _project_specs/spec.md << 'EOF'
# Audit: DeFi Lending Protocol

## Scope
- src/LendingPool.sol - Core lending logic
- src/Oracle.sol - Price feeds
- src/CollateralManager.sol - Collateral handling

## Priority Areas
1. Reentrancy in deposit/withdraw/liquidate
2. Oracle price manipulation
3. Collateral ratio enforcement
4. Access control on admin functions

## Trust Assumptions
- Chainlink oracle is trusted
- Admin can pause but not steal funds
- No flash loan protection needed (external)

## Out of Scope
- Governance contracts
- Token implementations
EOF
```

### 4. Start the Audit

```bash
# Start the autonomous audit loop
./loop.sh
```

---

## 📋 The Ralph Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 1: PLANNING (1 Iteration)                                │
│  ├── Run CodeQL baseline analysis                               │
│  ├── Run pattern matching against Solodit database              │
│  ├── Map business flows and asset movements                     │
│  └── Generate IMPLEMENTATION_PLAN.md                           │
│                                                                 │
│  ✋ STOPS: Review the plan before proceeding                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 2: BUILDING (Multiple Iterations)                        │
│  ├── Apply 6 taint models to each critical function             │
│  │   └── INV → ASM → EXP → TMP → CMP → BND                     │
│  ├── Run verification harness on each finding                   │
│  │   └── Observe → Reachability → Controllability →           │
│  │       Impact → PoC → Report                                  │
│  └── Document findings in findings/vulnerabilities/             │
│                                                                 │
│  🔄 CONTINUES: Until backpressure limit or completion           │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  PHASE 3: VERIFICATION                                          │
│  ├── Run /verify on critical findings                           │
│  ├── Generate final audit report                                │
│  └── Review and prioritize findings                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Slash Commands (Use During Audit)

| Command | When to Use | What It Does |
|---------|-------------|--------------|
| `/audit` | Start of audit | Full security audit with all taint models |
| `/hound` | Deep analysis needed | Mental map generation + cross-contract analysis |
| `/verify [finding-id]` | After finding suspected bug | 5-gate verification + mutation testing |
| `/pattern-match [keywords]` | During initial analysis | Search Solodit for similar vulnerabilities |
| `/tdd [feature]` | Testing complex logic | Test-driven audit methodology |
| `/status` | Check progress | Context health + audit progress |

---

## 🎬 Usage Scenarios

### Scenario 1: New Protocol Audit (Full)

```bash
# Step 1: Install Ralph
bash /path/to/ralph/install_agent.sh /path/to/new-protocol

# Step 2: Set up spec
cd /path/to/new-protocol
cat > _project_specs/spec.md << 'EOF'
# New Protocol Full Audit

## In Scope
- All contracts in src/
- Focus: Lending/borrowing flows

## Critical Functions
- deposit(), withdraw()
- borrow(), repay()
- liquidate()

## Attack Vectors to Check
- First depositor inflation attack
- Reentrancy through callbacks
- Oracle manipulation via flash loans
- Access control bypass
EOF

# Step 3: Start audit
./loop.sh

# Step 4: During the audit, use commands:
# - /pattern-match "reentrancy deposit" (to check history)
# - /hound (for deep cross-contract analysis)
# - /verify H-01 (when you find a high severity issue)
```

### Scenario 2: Quick Security Scan (PR Review)

```bash
# For a PR with changes to specific files:
cat > _project_specs/spec.md << 'EOF'
# PR Security Review

## Changed Files
- src/LendingPool.sol (lines 150-200 modified)
- src/Oracle.sol (new function added)

## Focus
Only analyze the CHANGED code:
1. New functions in LendingPool
2. Oracle price staleness check
3. External call safety

## Skip
- Existing audited code
- Gas optimizations
- Style issues
EOF

./loop.sh
```

### Scenario 3: Zero-Day Hunt (Integration Bugs)

```bash
# When looking for novel vulnerabilities across contracts:
cat > _project_specs/spec.md << 'EOF'
# Integration Vulnerability Hunt

## Target
Find vulnerabilities that only appear when:
- Contracts interact with each other
- Multiple protocols are composed
- Edge cases in state transitions

## Method
1. Use /hound to generate mental maps
2. Look for callback chains
3. Check flash loan interactions
4. Verify state consistency across calls

## Reference
See knowledges/integration_hunting.md
EOF

# Start with deep analysis
./loop.sh
# Then immediately run: /hound
```

### Scenario 4: Verification-First Audit

When you already suspect specific vulnerabilities:

```bash
# Step 1: Document your suspicion
cat > findings/suspected/H-01_reentrancy.md << 'EOF'
# Suspected: Reentrancy in withdraw()

## Location
LendingPool.sol:156 - withdraw() function

## Suspicion
External call to msg.sender before state update

## Evidence
```solidity
(bool success, ) = msg.sender.call{value: amount}("");  // Line 160
balances[msg.sender] -= amount;  // Line 162 - AFTER external call!
```
EOF

# Step 2: Run verification
# In the audit chat, type: /verify H-01
```

---

## 🔬 Deep Dive: The 6 Taint Models

Use these systematically on each critical function:

### 1. INV (Invariant Model)
**Question**: What must ALWAYS be true?

```markdown
## Check for LendingPool.deposit()

### Invariants
- [ ] totalSupply increases by deposit amount
- [ ] User balance increases by deposit amount
- [ ] Protocol fee ≤ deposit amount

### Violation Scenarios
- First depositor attack (1 wei → large share)
- Rounding errors
- Fee calculation overflow
```

### 2. ASM (Assumption Model)
**Question**: What does the code ASSUME?

```markdown
## Assumptions in withdraw()

### Assumption 1: User has sufficient balance
- **Check**: require(balances[msg.sender] >= amount)
- **Bypass scenario**: Flash loan + reentrancy

### Assumption 2: No reentrancy
- **Check**: nonReentrant modifier present?
- **Bypass**: Check all external call paths
```

### 3. EXP (Expression/Oracle Model)
**Question**: Where does external data come from?

```markdown
## Oracle Dependencies

### Price Feeds
- [ ] Source: ChainlinkAggregator
- [ ] Staleness check: < 1 hour?
- [ ] Manipulation possible via flash loans?

### Calculate impact
- 1% price deviation → $X loss
- Maximum borrowable with manipulated price
```

### 4. TMP (Temporal Model)
**Question**: Does order of operations matter?

```markdown
## State Transitions

### Order Dependency 1: Deposit → Borrow
Correct: Update collateral FIRST, then borrow
Wrong: Borrow succeeds before collateral recorded

### Order Dependency 2: Liquidation
Correct: Seize collateral AFTER debt repayment
Wrong: Seize without repayment

### Time-based: Interest accrual
- [ ] Interest calculated correctly across time
- [ ] No timestamp manipulation
```

### 5. CMP (Composition Model)
**Question**: What happens with multiple operations?

```markdown
## Flash Loan Combinations

### Attack Path 1: Flash Loan → Manipulate Oracle → Liquidate
1. Borrow flash loan
2. Manipulate DEX price
3. Trigger liquidation at bad price
4. Profit from seized collateral
5. Repay flash loan

### Attack Path 2: Cross-contract Reentrancy
1. Callback from Pool A
2. Reenter Pool B
3. State inconsistent
```

### 6. BND (Boundary Model)
**Question**: What are the edge cases?

```markdown
## Boundary Conditions

### Zero Values
- [ ] deposit(0) - should revert or be no-op?
- [ ] withdraw(0) - should not emit events
- [ ] borrow(0) - should revert

### Maximum Values
- [ ] deposit(type(uint256).max) - overflow check
- [ ] Total supply overflow
- [ ] Interest calculation precision loss

### Array Bounds
- [ ] Max collateral tokens
- [ ] Loop gas exhaustion
```

---

## 🔧 Advanced Techniques

### Technique 1: Pattern Matching Before Analysis

```bash
# Before diving into code, check what's been found historically:
python scripts/pattern_matcher.py /path/to/project --format report

# This generates:
# - Top 20 similar vulnerabilities
# - Historical impact data
# - Attack patterns to check
```

### Technique 2: CodeQL Baseline + LLM

```bash
# Run deterministic analysis first:
bash scripts/run_codeql_baseline.sh /path/to/project

# This finds:
# - All external functions (attack surface)
# - Missing access controls
# - Unchecked calls
# - Oracle staleness issues

# Then use LLM to:
# - Verify if issues are exploitable
# - Create PoCs for true positives
# - Assess business impact
```

### Technique 3: Subagent Parallelization

For large codebases, spawn parallel audits:

```markdown
# In audit chat:

"Spawn 3 subagents to analyze:
1. Subagent A: LendingPool.sol (deposit/withdraw)
2. Subagent B: Oracle.sol + Price feeds
3. Subagent C: CollateralManager.sol

Each should:
- Apply 6 taint models
- Generate findings in findings/vulnerabilities/
- Use 1 compute unit each (LOW difficulty)"
```

### Technique 4: Skeptic Pass

Before full verification, do a quick disproof:

```markdown
## Fast Disproof Checklist

For suspected reentrancy:
1. Is there a reentrancy guard? → If yes, lower priority
2. Is the external call the LAST operation? → If yes, safe
3. Are state updates BEFORE the call? → If yes, safe
4. Is the called contract trusted? → If yes, lower priority

Only proceed to full verification if 3+ checks fail.
```

---

## 📊 Audit Quality Checklist

Before finishing an audit, verify:

| Check | Command/Action | Pass Criteria |
|-------|----------------|---------------|
| CodeQL baseline | `bash scripts/run_codeql_baseline.sh .` | All HIGH severity checked |
| Pattern matching | `python scripts/pattern_matcher.py .` | Reviewed top 20 matches |
| 6 taint models | Manual review | Each critical function covered |
| Verification harness | `/verify [finding]` | All HIGH/CRITICAL findings pass |
| PoC completeness | Check `findings/vulnerabilities/` | Each has working PoC |
| False positive rate | Review findings | <20% false positives |

---

## 🚨 Common Pitfalls

### 1. **Scope Creep**
```markdown
❌ BAD: "Audit everything"
✅ GOOD: "Audit LendingPool.deposit() and withdraw() for reentrancy"
```

### 2. **Skipping Pattern Matching**
```markdown
❌ BAD: Jump straight to code analysis
✅ GOOD: Run pattern matching first - saves hours of rediscovery
```

### 3. **Weak-to-Strong Model Usage**
```markdown
❌ BAD: Use GPT-3.5 first, then escalate
✅ GOOD: Use Opus 4.5 or GPT-5.2-Codex immediately for complex logic
```

### 4. **No Verification**
```markdown
❌ BAD: Report every CodeQL finding
✅ GOOD: Run /verify on each finding - 60% will be false positives
```

### 5. **Missing Integration Bugs**
```markdown
❌ BAD: Analyze contracts in isolation
✅ GOOD: Use /hound for cross-contract analysis
```

---

## 💡 Pro Tips

1. **Always run pattern matching first** - It takes 30 seconds and gives you context on what's been found before

2. **Use SOTA models for critical paths** - Don't waste time with weak models on complex math

3. **Document your reasoning** - Write findings as you go, not at the end

4. **Test PoCs immediately** - If you can't write a PoC, it's probably not exploitable

5. **Review aggregate metrics** - If you find 10 MEDIUMs in one function, there's probably a deeper issue

6. **Cache Solodit results** - The API has rate limits; results are cached for 5 minutes

---

## 📚 Learning Path

### Week 1: Basics
- Run Ralph on a simple ERC-20
- Practice /audit and /verify commands
- Learn 6 taint models

### Week 2: Intermediate
- Audit a simple vault
- Use pattern matching
- Create your first PoC

### Week 3: Advanced
- Hunt integration bugs with /hound
- Run CodeQL + LLM workflow
- Verify findings with mutation testing

### Week 4: Expert
- Subagent orchestration
- Zero-day hunting
- Complex multi-step exploits

---

## 🔗 Key Files Reference

| File | Purpose | When to Read |
|------|---------|--------------|
| `AGENTS.md` | Operational guide | Before first audit |
| `PROMPT_plan.md` | Planning phase prompt | During planning |
| `PROMPT_build.md` | Building phase prompt | During analysis |
| `knowledges/agentic_harness.md` | 6-step verification | When verifying findings |
| `knowledges/taint_models/*.md` | Taint model details | During taint analysis |
| `knowledges/integration_hunting.md` | Integration bugs | When using /hound |

---

**Ready to start?** Run `./loop.sh` in your project directory! 🕵️
