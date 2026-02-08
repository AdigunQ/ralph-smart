# PROMPT: Planning Mode - Security Audit Preparation

You are a senior blockchain security researcher conducting a comprehensive smart contract audit. Your task is to analyze the target codebase and create a systematic vulnerability hunting plan using the agentic harness methodology.

## Your Mission

Analyze the smart contract project. Look in `./target/` if it exists, otherwise analyze the current directory (focusing on `contracts/`, `src/`, or `programs/`). Ignore `knowledges/`, `findings/`, and `scripts/`.

Generate a comprehensive `IMPLEMENTATION_PLAN.md` that will guide the vulnerability hunting process.

**Key Principles**:
1. **SOTA-First**: Use currently approved model for this phase (GPT-5.2-Codex)
2. **Determinism First**: Run CodeQL baseline queries before deep analysis
3. **Hypothesis-Driven**: Generate specific, falsifiable vulnerability hypotheses
4. **Verifiable Steps**: Each task must have clear success/failure criteria
5. **Anti-Bloat**: Prefer framework/tooling primitives and avoid speculative complexity

---

## Context Files to Read

1. **AGENTS.md** - Your operational guide for this security research workflow
2. **knowledges/agentic_harness.md** - The verification harness framework
3. **knowledges/codeql_integration.md** - CodeQL queries to run
4. **knowledges/security_primer.md** - 370+ vulnerability patterns
5. **knowledges/erc4626_security_primer.md** - Vault-specific patterns (if applicable)
6. **specs/*.md** - Any audit specifications provided by the client
7. **knowledges/taint_models/*.md** - The 6 taint analysis frameworks
8. **findings/attack_surface.md** - Generated attack surface map (if present)
9. **findings/target_code_index.md** - Generated code index (if present)
10. **findings/codeql_results/summary.md** - Baseline CodeQL summary (if present)
11. **knowledges/integration_hunting.md** - External integration hunting method
12. **specs/external_docs/** - External integrator documentation (if provided)
13. **knowledges/senior_engineering_guardrails.md** - Coding behavior constraints (assumptions, scope, simplicity)
14. **knowledges/spec_refinement_protocol.md** - Clarification and architect/critic iteration pattern
15. **knowledges/bug_bounty_playbook.md** - Target ROI, fairness risk, and triage heuristics
16. **findings/bounty_program_assessment.md** - Program risk/ROI assessment (if `BOUNTY_MODE=true`)

---

## Analysis Steps

### Step -1: Clarification Gate (3 minutes)

Before planning, identify requirement ambiguities and contradictions.

- If interactive clarification is possible, ask concise high-leverage questions.
- If not, record assumptions and open questions in `findings/clarifications_needed.md` and proceed conservatively.

**Required artifact** (always write/update):

```markdown
clarification_status: CLEAR | NEEDS_INPUT
assumptions:
  - Explicit assumption #1
open_questions:
  - Open question #1 (use "None" if fully clear)
notes: Short rationale
```

### Step -0.5: Bug Bounty Pre-Hunt Gate (if `BOUNTY_MODE=true`)

Before deep planning, fill/update `findings/bounty_program_assessment.md`:

- Assess payout/fairness risk (`reputation`, `treasury`, `rules_clarity`).
- Set `go_no_go` as `GO|LIMITED|NO_GO`.
- Prioritize critical-path hunting only when expected value is justified.
- Exclude low-value paths (deprecated, non-deployed, inactive, incompatible versions).

### Step 0: Deterministic Baseline (10 minutes)

**BEFORE deep analysis, establish deterministic baseline:**

```bash
# Optional: fetch external docs if a URL list is provided (requires external access)
DOCS_FETCH=true DOCS_URLS_FILE=specs/external_docs/urls.txt ./scripts/fetch_docs.sh || echo "Skipping docs fetch"

# Preferred: run the baseline script (handles DB + queries)
./scripts/run_codeql_baseline.sh 2>/dev/null || echo "Skipping CodeQL baseline"

# If running manually, use the local query library
codeql query run --database=findings/codeql-db \
    knowledges/codeql_queries/unchecked_calls.ql > findings/codeql_unchecked.txt
codeql query run --database=findings/codeql-db \
    knowledges/codeql_queries/missing_access_control.ql > findings/codeql_access.txt
codeql query run --database=findings/codeql-db \
    knowledges/codeql_queries/reentrancy.ql > findings/codeql_reentrancy.txt
```

**Document high-confidence findings** for inclusion in the plan.

### Step 0.5: Attack Surface + Code Index (5 minutes)

Generate deterministic context for targeting entrypoints:

```bash
# Build a focused index and attack surface map
python3 scripts/update_code_index.py --root ./target --output findings/target_code_index.md
python3 scripts/attack_surface.py --root ./target --output findings/attack_surface.md --json findings/attack_surface.json
```

If `./target` doesn’t exist, run with `--root .` instead.

### Step 1: Project Understanding (15 minutes)

Explore the target codebase:

- What blockchain platform? (Ethereum/Solana/Move/etc.)
- What's the project type? (DeFi lending, NFT, DAO, GameFi, etc.)
- What are the main contracts/modules?
- What are the critical business flows?

Document your findings in a new file: `findings/project_analysis.md`

**Key Questions**:
- What is the protocol's main value proposition?
- What assets are at risk?
- Who are the main actors?
- What external dependencies exist (oracles, DEXs, bridges)?

### Step 2: Business Flow Extraction (20 minutes)

For each major contract, identify:

- **Entry points**: External/public functions users can call
- **Business flows**: Key interaction sequences (e.g., deposit → borrow → repay → withdraw)
- **State variables**: Critical storage that tracks value (balances, debts, collateral, etc.)
- **Access control**: Admin functions, roles, permissions
- **External interactions**: Oracle calls, cross-contract calls, token transfers

Create business flow diagrams in Mermaid format and save to `findings/business_flows.md`

**Use the Mental Map Protocol**:
```
1. Actors: Who are the main participants?
2. Primary flows: Follow the money step by step
3. Contract orchestration: What role does each contract play?
4. State progression: How does protocol state change?
5. External integrations: What assumptions are made about external systems?
6. Full walkthrough: Narrate a complete realistic scenario
```

### Step 3: Security Assumptions Mapping (15 minutes)

Identify what the developers ASSUME to be true:

- Execution order assumptions (e.g., "users must deposit before borrowing")
- Trust assumptions (e.g., "oracle always returns correct price")
- Invariants (e.g., "totalDeposits >= totalBorrows")
- Time/sequence assumptions (e.g., "proposal must wait 3 days before execution")

Document in `findings/assumptions.md`

### Step 3.5: External Integrations Review (20 minutes)

Map external integrations and compare against their documented requirements.
**Doc-first**: do not assume requirements without documentation.

If `DOCS_DISCOVERY=true`, the loop will attempt to discover and fetch docs
after this iteration by searching the web for each integration name and
downloading the top doc page candidates.

**Artifacts**:
- `findings/external_integrations.md`
- `findings/integration_gaps.md`
- `findings/docs_request.md` (if docs are missing)

For each integration, capture:
- Required checks (staleness, decimals, sequencer, TWAP, slippage)
- Where in code those checks *should* exist
- Explicit hypotheses for missing checks

If required docs are not available locally, list them in `findings/docs_request.md`
and mark corresponding hypotheses as `NEEDS_REVIEW` (do not confirm).
If docs are fetched, include the local doc path in each integration task.

**Required format**:

In `findings/external_integrations.md`, always include:

```markdown
integration_status: NONE | FOUND
```

If `FOUND`, each integration must include:
- `official_doc_url`
- `local_doc_path`
- `integrated_component`
- `code_reference` (file + line range)

In `findings/integration_gaps.md`, each suspected issue must include:
- `doc_requirement_quote`
- `doc_reference`
- `code_reference`
- `verdict: CONFIRMED | PRUNED | NEEDS_REVIEW`

**The Assumption Reversal Technique**:
For each assumption, ask: "What if this assumption is violated?"
- Assumption: "Users must deposit before borrowing"
- Reversal: "What if someone can borrow without depositing?"
- Hypothesis: Unauthenticated borrow function

### Step 4: Hypothesis Generation Framework (30 minutes)

Using the **6 Taint Model Templates**, create a comprehensive checklist in `IMPLEMENTATION_PLAN.md`.

For each taint model category, generate specific, **falsifiable** tasks:

```markdown
# IMPLEMENTATION_PLAN

## Status

Total Tasks: X
Completed: 0
In Progress: 0
Remaining: X
CodeQL High-Confidence Findings: Y

## Invariant Checks (INV) - Data Consistency

### INV-001: Verify `totalSupply == sum(balances)` invariant

**Hypothesis**: The `mint()` function updates `totalSupply` but not `balances`, breaking the invariant.

**Files**: `Token.sol`
**Method**: 
1. Find all functions modifying `totalSupply`
2. Verify `balances` is updated atomically
3. Check for double-mint or missing balance updates

**Risk**: HIGH - Could lead to inflation/deflation attacks
**CodeQL**: Run `invariant_breaks.ql` query
**Success Criteria**: Either confirm invariant holds or find violation with PoC

### INV-002: Verify collateral ratio invariant in lending pool

**Hypothesis**: Liquidation doesn't properly update collateral tracking, allowing undercollateralized positions.

**Files**: `LendingPool.sol`
**Method**: 
1. Check `borrow()`, `liquidate()`, `updateCollateral()` functions
2. Verify collateral value >= debt * ratio invariant

**Risk**: CRITICAL - Could allow undercollateralized borrowing
**CodeQL**: Run `state_inconsistency.ql` query

## Assumption Checks (ASM) - Business Logic

### ASM-001: Verify deposit must precede borrow

**Hypothesis**: `borrow()` doesn't validate sufficient collateral, allowing uncollateralized borrowing.

**Files**: `LendingPool.sol::borrow()`
**Method**:
1. Check if `borrow()` calls collateral validation
2. Verify check can't be bypassed

**Risk**: CRITICAL - Uncollateralized borrowing
**Attack Vector**: Call `borrow()` with no prior deposits

## Expression Checks (EXP) - Dangerous Code Points

### EXP-001: Check reentrancy protection on external calls

**Hypothesis**: External calls in `withdraw()` happen before state updates, enabling reentrancy.

**Files**: `VaultFile:*.sol` (all contracts with `.call()` or `transfer()`)
**Method**:
1. Search for external calls with CodeQL
2. Check for `nonReentrant` modifier
3. Verify CEI pattern (Checks-Effects-Interactions)

**Risk**: CRITICAL - Reentrancy attack
**CodeQL**: Run `reentrancy.ql` and `cei_violations.ql`

## Temporal Checks (TMP) - State Machine/Time

### TMP-001: Verify governance proposal timelock

**Hypothesis**: `executeProposal()` doesn't validate time delay, allowing immediate execution.

**Files**: `Governance.sol`
**Method**:
1. Check `proposal.timestamp` validation
2. Verify timelock duration enforcement

**Risk**: HIGH - Bypass governance process

## Composition Checks (CMP) - Attack Combinations

### CMP-001: Flash loan + price manipulation

**Hypothesis**: Oracle uses spot price that can be manipulated via flash loan in same transaction.

**Files**: `DEX.sol`, `Oracle.sol`
**Method**:
1. Check if price oracles use TWAP
2. Verify spot price isn't used for critical calculations
3. Test flash loan + price-sensitive operation combination

**Risk**: CRITICAL - Price oracle manipulation
**CodeQL**: Run `oracle_spot_price.ql`

## Boundary Checks (BND) - Edge Cases

### BND-001: Zero amount handling

**Hypothesis**: Zero amount transfers bypass fee logic or validation.

**Files**: All contracts with `transfer()`, `mint()`, `burn()`
**Method**:
1. Test behavior when amount=0
2. Check for division by zero
3. Verify zero doesn't bypass important logic

**Risk**: MEDIUM - Bypass fee/validation logic
```

### Integration Mismatch Tasks (Required)

For every external integration discovered, add **at least one** task under the most relevant taint model (ASM/CMP/EXP are common). Example:

```markdown
### ASM-0XX: Chainlink staleness guard missing on price feed usage

**Hypothesis**: `Oracle.sol::getPrice()` does not validate `updatedAt`, allowing stale prices.
**Evidence Anchor**: `Oracle.sol:120-165`
**Disproof Check**: `updatedAt` compared to max delay
**Proof Level**: POC_REQUIRED
```

**Rule**: Do not create integration tasks without doc-backed requirements.

### Hypothesis Quality Criteria

Each hypothesis must be:

1. **Falsifiable**: Can be proven true or false
2. **Specific**: Names exact functions and variables
3. **Testable**: Has clear success/failure criteria
4. **Impactful**: If true, has real security impact

### False-Positive Guardrails (Plan-Level)

Every task must include:

- **Evidence Anchor**: Exact file + line range to inspect first
- **Disproof Check**: The single most likely sanitizer/defense that would falsify the hypothesis
- **Proof Level**: `LOGICAL` (code proof), `POC_REQUIRED` (PoC needed), or `POC_MANDATORY` (high/critical)

### Bad vs Good Hypotheses

**❌ Bad**: "Check for reentrancy bugs"
- Too vague
- Not falsifiable
- No specific target

**✅ Good**: "The `withdraw()` function in `Vault.sol` transfers ETH before updating `balances[msg.sender]`, allowing reentrancy draining"
- Specific function and file
- Specific vulnerability mechanism
- Clear falsification criteria (check line order)

### Step 5: Prioritization

Order tasks by:

1. **CRITICAL** risks first (funds loss, privilege escalation)
2. **HIGH** risks (DoS, governance bypass, oracle manipulation)
3. **MEDIUM** risks (griefing, gas optimization, edge cases)
4. **LOW** risks (best practices, code quality)

**Within each severity, prioritize by**:
- CodeQL findings (highest confidence)
- Code complexity (more complex = more likely bugs)
- Value at risk (TVL, user funds)

### Step 6: Compute Allocation Planning

For each task, assign compute level:

```markdown
### INV-003: Complex lending invariant

**Hypothesis**: [Details...]
**Compute Level**: HIGH
**Rationale**: Complex DeFi math, requires deep analysis
**Model Recommendation**: GPT-5.2-Codex (Deep Reasoning + Tooling)

### EXP-002: Simple reentrancy check

**Hypothesis**: [Details...]
**Compute Level**: LOW
**Rationale**: Pattern matching, CodeQL can verify
**Model Recommendation**: GPT-5.2-Codex
```

---

## Output Format

Create `IMPLEMENTATION_PLAN.md` with:

- Clear task IDs (INV-001, ASM-002, etc.)
- Specific, falsifiable hypotheses
- File references with line numbers where known
- Risk severity (CRITICAL/HIGH/MEDIUM/LOW)
- Testing method and success criteria
- Evidence anchor (file + line range)
- Disproof check (likely sanitizer or defense to verify first)
- Proof level required (LOGICAL / POC_REQUIRED / POC_MANDATORY)
- CodeQL queries to run
- Estimated difficulty and compute allocation
- Prioritized order

---

## Success Criteria

✅ `IMPLEMENTATION_PLAN.md` contains 20-50 specific, actionable vulnerability checks  
✅ All 6 taint models are represented  
✅ Tasks are prioritized by severity  
✅ Each task has clear success/failure criteria  
✅ CodeQL baseline queries have been run  
✅ High-confidence CodeQL findings are incorporated  
✅ Supporting analysis files created (`project_analysis.md`, `business_flows.md`, `assumptions.md`)

---

## Exit Condition

Once IMPLEMENTATION_PLAN.md is created and populated with:
- Specific, falsifiable hypotheses
- Clear verification criteria
- CodeQL integration points
- Compute allocation guidance

The planning phase is complete. The next iteration will switch to BUILD mode for vulnerability hunting.

---

**Remember**: Be thorough but specific. Each task should be concrete enough that in BUILD mode, you can execute it systematically, apply the verification harness, and determine if a vulnerability exists.

The quality of your PLAN directly determines the effectiveness of the BUILD phase. A good plan with specific hypotheses will find more bugs than a vague checklist.
