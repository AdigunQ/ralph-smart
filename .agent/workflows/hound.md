---
description: Generate Research-Grade Hound Mental Maps with Agentic Harness
trigger: /hound
---

# /hound - Deep Reasoning with Agentic Harness

This workflow activates "Deep Reasoning" mode to build comprehensive mental maps of the target system, then applies the verification harness to identify contradictions and vulnerabilities.

## Overview

The Hound methodology (arXiv:2510.09633v1) uses **Relation-First Graphs** and **Persistent Beliefs** to systematically analyze complex systems. Combined with the agentic harness, it provides research-grade vulnerability discovery.

## Phase 1: Scout - Map the Territory (Junior Role)

**Goal**: Build comprehensive mental maps without judgment

### Instructions to Agent:

> You are the **Scout** (Junior Security Researcher). Read the codebase in `target/` systematically and generate the following artifacts in `findings/hound/`:
> 
> **Required Outputs**:
> 
> 1. **`scout_observations.md`** - Facts only
>    - OBS-XXX: "Function X at line Y is external"
>    - OBS-XXX: "Variable Z is modified by functions A, B, C"
>    - OBS-XXX: "External call to contract W at line V"
> 
> 2. **`system_architecture.md`** - Component graph (Mermaid)
>    ```mermaid
>    graph TD
>        A[User] -->|deposit| B[Vault]
>        B -->|mint| C[Token]
>        B -->|invest| D[Strategy]
>    ```
> 
> 3. **`asset_flows.md`** - Money movement diagram
>    - Entry points (where funds enter)
>    - Internal flows (between contracts)
>    - Exit points (where funds leave)
>    - Fee extraction points
> 
> 4. **`state_mutation_map.md`** - Table format
>    | Variable | Type | Read By | Written By | Invariant |
>    |----------|------|---------|------------|-----------|
>    | totalSupply | uint256 | balanceOf | mint, burn | == sum(balances) |
> 
> 5. **`authorization_graph.md`** - Access control
>    - All roles (owner, admin, keeper, user)
>    - What each role can do
>    - How roles are assigned/changed
> 
> **Rules**:
> - Document facts, don't analyze yet
> - Read every external/public function
> - Don't skip internal functions that modify state
> - Note all external contract interactions

**Model Recommendation**: `claude-sonnet-4.5` (thorough, fast)

## Phase 2: Strategist - Find Contradictions (Senior Role)

**Goal**: Identify vulnerabilities by finding contradictions in the Scout's observations

### Instructions to Agent:

> You are the **Strategist** (Senior Security Researcher). Review all Scout outputs in `findings/hound/` and identify contradictions that suggest vulnerabilities.
> 
> **Required Outputs**:
> 
> 1. **`strategist_contradictions.md`**
>    - CON-XXX: "Observation A contradicts Observation B"
>    - Evidence: Specific lines and code
>    - Hypothesis: What vulnerability this suggests
>    - Confidence: 0.0-1.0
> 
> 2. **`hypotheses.md`** - Prioritized vulnerability hypotheses
>    ```markdown
>    ## HYP-001: Reentrancy in withdraw()
>    **Confidence**: 0.85
>    **Severity**: CRITICAL
>    **Basis**: CON-003 (external call before state update)
>    **Attack Scenario**:
>    1. Attacker calls withdraw()
>    2. External call at line 45 triggers receive()
>    3. Reenter before state update at line 48
>    4. Drain contract
>    
>    **Verification Plan**:
>    - [ ] Step 1: Confirm observation accuracy
>    - [ ] Step 2: Prove reachability
>    - [ ] Step 3: Prove controllability
>    - [ ] Step 4: Quantify impact
>    - [ ] Step 5: Create PoC
>    ```
> 
> 3. **`risk_areas.md`** - High-risk code regions
>    - Complex state transitions
>    - External calls without guards
>    - Privileged operations
>    - Novel/untested patterns
> 
> **Contradiction Patterns to Look For**:
> - External call before state update (vs CEI pattern)
> - Privileged function without access control (vs security assumption)
> - Price usage without staleness check (vs oracle assumption)
> - State change without invariant validation (vs data consistency)

**Model Recommendation**: `claude-opus-4.5` (complex reasoning)

## Phase 3: Finalizer - Prove with Harness (QA Role)

**Goal**: Apply the 6-step verification harness to each hypothesis

### Instructions to Agent:

> You are the **Finalizer** (QA Security Researcher). For each hypothesis in `hypotheses.md`, apply the full verification harness.
> 
> **Process per Hypothesis**:
> 
> ### Step 1: Observation Checkpoint
> Verify the Scout's observations are accurate:
> - Check line numbers match actual code
> - Confirm function visibility (external/public)
> - Validate state variable relationships
> 
> ### Step 2: Reachability Proof
> ```markdown
> ## HYP-001 Reachability
> - Entry: withdraw() is external ✓
> - Path: withdraw() → external call (line 45) ✓
> - No blocking modifiers ✓
> - Confidence: 1.0 (externally callable)
> ```
> 
> ### Step 3: Controllability Analysis
> ```markdown
> ## HYP-001 Controllability
> - Attacker controls: amount parameter
> - Attacker receives: external call to their contract
> - Attacker can: reenter via receive/fallback
> - Missing sanitizers: nonReentrant guard, CEI violation
> ```
> 
> ### Step 4: Impact Quantification
> ```markdown
> ## HYP-001 Impact
> - Type: Theft
> - Maximum: Contract balance (~$X TVL)
> - Exploit cost: Gas only
> - Likelihood: High
> - Severity: CRITICAL
> ```
> 
> ### Step 5: PoC Creation
> Create Foundry test in `findings/vulnerabilities/`:
> ```solidity
> function testExploitReentrancy() public {
>     // Setup
>     vm.deal(address(vulnerable), 100 ether);
>     
>     // Attack
>     attacker.attack{value: 1 ether}();
>     
>     // Verify
>     assertEq(address(vulnerable).balance, 0);
> }
> ```
> 
> ### Step 6: Report Generation
> Create `findings/vulnerabilities/HYP-001-reentrancy.md` with full finding details.
> 
> **Verdict**: CONFIRMED / REJECTED / NEEDS_REVIEW

**Model Recommendation**: `claude-opus-4.5` or `gpt-5.2-codex` (PoC writing)

## Orchestration Patterns

### Pattern A: Linear (Small Codebases)
```
Scout → Strategist → Finalizer (sequential)
```

### Pattern B: Parallel Scout (Large Codebases)
```
         ┌→ Scout (Contract A) →┐
         ├→ Scout (Contract B) →┤
Orchestrator → Scout (Contract C) →├→ Strategist → Finalizer
         ├→ Scout (Contract D) →┤
         └→ Scout (Contract E) →┘
```

### Pattern C: Parallel Finalizer (Many Hypotheses)
```
Scout → Strategist → ┌→ Finalizer (HYP-001)
                     ├→ Finalizer (HYP-002)
                     ├→ Finalizer (HYP-003)
                     └→ Finalizer (HYP-004)
```

## Output Files

| File | Description |
|------|-------------|
| `findings/hound/scout_observations.md` | Raw facts from codebase |
| `findings/hound/system_architecture.md` | Component diagram |
| `findings/hound/asset_flows.md` | Money movement flows |
| `findings/hound/state_mutation_map.md` | State variable tracking |
| `findings/hound/authorization_graph.md` | Access control mapping |
| `findings/hound/strategist_contradictions.md` | Identified contradictions |
| `findings/hound/hypotheses.md` | Prioritized vulnerability hypotheses |
| `findings/hound/risk_areas.md` | High-risk code regions |
| `findings/vulnerabilities/*.md` | Confirmed findings with PoCs |

## Integration with /audit

The `/hound` workflow can be called standalone for deep analysis or is automatically used by `/audit` for:
- Complex DeFi protocols
- Novel/unfamiliar patterns
- High-value targets requiring extra scrutiny

## Success Metrics

- [ ] All 4 mental maps generated
- [ ] 3-10 contradictions identified
- [ ] Each contradiction has a hypothesis
- [ ] High-confidence hypotheses pass verification harness
- [ ] PoCs created for confirmed vulnerabilities
