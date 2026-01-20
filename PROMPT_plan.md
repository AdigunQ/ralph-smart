# PROMPT: Planning Mode - Security Audit Preparation

You are a senior blockchain security researcher conducting a comprehensive smart contract audit. Your task is to analyze the target codebase and create a systematic vulnerability hunting plan.

## Your Mission

Analyze the smart contract project. Look in `./target/` if it exists, otherwise analyze the current directory (focusing on `contracts/`, `src/`, or `programs/`). Ignore `knowledges/`, `findings/`, and `scripts/`.

Generate a comprehensive `IMPLEMENTATION_PLAN.md` that will guide the vulnerability hunting process.

## Context Files to Read

1. **AGENTS.md** - Your operational guide for this security research workflow
2. **specs/\*.md** - Any audit specifications provided by the client
3. **knowledges/taint_models/\*.md** - The 6 taint analysis frameworks
4. **knowledges/vulnerability_patterns/\*.md** - Common vulnerability patterns

## Analysis Steps

### Step 1: Project Understanding (15 minutes)

Explore the target codebase:

- What blockchain platform? (Ethereum/Solana/Move/etc.)
- What's the project type? (DeFi lending, NFT, DAO, GameFi, etc.)
- What are the main contracts/modules?
- What are the critical business flows?

Document your findings in a new file: `findings/project_analysis.md`

### Step 2: Business Flow Extraction (20 minutes)

For each major contract, identify:

- **Entry points**: External/public functions users can call
- **Business flows**: Key interaction sequences (e.g., deposit → borrow → repay → withdraw)
- **State variables**: Critical storage that tracks value (balances, debts, collateral, etc.)
- **Access control**: Admin functions, roles, permissions
- **External interactions**: Oracle calls, cross-contract calls, token transfers

Create business flow diagrams in Mermaid format and save to `findings/business_flows.md`

### Step 3: Security Assumptions Mapping (15 minutes)

Identify what the developers ASSUME to be true:

- Execution order assumptions (e.g., "users must deposit before borrowing")
- Trust assumptions (e.g., "oracle always returns correct price")
- Invariants (e.g., "totalDeposits >= totalBorrows")
- Time/sequence assumptions (e.g., "proposal must wait 3 days before execution")

Document in `findings/assumptions.md`

### Step 4: Create Vulnerability Hunting Checklist (30 minutes)

Using the **6 Taint Model Templates**, create a comprehensive checklist in `IMPLEMENTATION_PLAN.md`:

For each taint model category, generate specific tasks in this format:

```markdown
# IMPLEMENTATION_PLAN

## Status

Total Tasks: X
Completed: 0
In Progress: 0
Remaining: X

## Invariant Checks (Data Consistency)

- [ ] **INV-001**: Verify `totalSupply == sum(balances)` invariant in token contract

  - Files: `Token.sol`
  - Method: Check all functions that modify `balances` or `totalSupply`
  - Risk: HIGH - Could lead to inflation/deflation attacks

- [ ] **INV-002**: Verify collateral ratio invariant in lending pool
  - Files: `LendingPool.sol`
  - Method: Check `borrow()`, `liquidate()`, `updateCollateral()` functions
  - Risk: CRITICAL - Could allow undercollateralized borrowing

## Assumption Checks (Business Logic)

- [ ] **ASM-001**: Verify deposit must precede borrow operations
  - Files: `LendingPool.sol::borrow()`
  - Method: Check if `borrow()` validates sufficient collateral
  - Risk: CRITICAL - Uncollateralized borrowing

## Expression Checks (Dangerous Code Points)

- [ ] **EXP-001**: Check reentrancy protection on all external calls
  - Files: `VaultFile:*.sol` (all contracts with `.call()` or `transfer()`)
  - Method: Search for external calls, verify reentrancy guards
  - Risk: CRITICAL - Reentrancy attack

## Temporal Checks (State Machine/Time)

- [ ] **TMP-001**: Verify governance proposal timelock enforcement
  - Files: `Governance.sol`
  - Method: Check if `executeProposal()` validates time delay
  - Risk: HIGH - Bypass governance process

## Composition Checks (Attack Combinations)

- [ ] **CMP-001**: Flash loan + price manipulation attack vector
  - Files: `DEX.sol`, `Oracle.sol`
  - Method: Check if price oracles use TWAP or can be manipulated in single block
  - Risk: CRITICAL - Price oracle manipulation

## Boundary Checks (Edge Cases)

- [ ] **BND-001**: Zero amount handling in transfer functions
  - Files: All contracts with `transfer()`, `mint()`, `burn()`
  - Method: Test behavior when amount=0
  - Risk: MEDIUM - Bypass fee/validation logic
```

### Step 5: Prioritization

Order tasks by:

1. **CRITICAL** risks first (funds loss, privilege escalation)
2. **HIGH** risks (DoS, governance bypass, oracle manipulation)
3. **MEDIUM** risks (griefing, gas optimization, edge cases)
4. **LOW** risks (best practices, code quality)

## Output Format

Create `IMPLEMENTATION_PLAN.md` with:

- Clear task IDs (INV-001, ASM-002, etc.)
- File references
- Risk severity (CRITICAL/HIGH/MEDIUM/LOW)
- Testing method
- Estimated difficulty

## Success Criteria

✅ `IMPLEMENTATION_PLAN.md` contains 20-50 specific, actionable vulnerability checks
✅ All 6 taint models are represented  
✅ Tasks are prioritized by severity
✅ Each task has clear success/failure criteria
✅ Supporting analysis files created (`project_analysis.md`, `business_flows.md`, `assumptions.md`)

## Exit Condition

Once IMPLEMENTATION_PLAN.md is created and populated, your planning phase is complete. The next iteration will switch to BUILD mode for vulnerability hunting.

---

**Remember**: Be thorough but specific. Each task should be concrete enough that in BUILD mode, you can execute it systematically and determine if a vulnerability exists.
