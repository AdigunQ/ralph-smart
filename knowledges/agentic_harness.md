# Agentic Harness Framework for Vulnerability Research

> **Core Principle**: Harnesses beat vibes. The difference between occasional brilliance and repeatable expert-grade output is the harness—the set of constraints, scaffolding, and checks that forces an agent to generate hypotheses explicitly, collect evidence before escalating confidence, use deterministic tools when possible, fail fast, and produce artifacts a reviewer can trust.

---

## What is a Harness?

A harness is the set of constraints, scaffolding, and checks that forces an agent to:

- **Generate hypotheses explicitly** (not implicitly)
- **Collect evidence before escalating confidence**
- **Use deterministic tools when possible**
- **Fail fast and prune dead ends**
- **Produce artifacts a reviewer can trust**

If you want systems that resemble an expert rather than "confident autocomplete," harnesses are the bridge: they turn model skill into expert-like reliability.

---

## The 6-Step Verification Harness

Real vulnerability research is not a one-shot classification task. It's long-form reasoning with compounding error: every step depends on earlier assumptions that might be incomplete, subtly wrong, or context-dependent.

```
Step 1: Identify suspicious behavior or invariant violations
    ↓ [Checkpoint: Document the observation with code evidence]
Step 2: Prove reachability (call paths, entrypoints, conditions)
    ↓ [Checkpoint: Provide complete call graph from entry to sink]
Step 3: Prove controllability (attacker influence on relevant state/data)
    ↓ [Checkpoint: Identify all attacker-controlled inputs]
Step 4: Determine real-world impact (theft, DoS, privilege escalation, etc.)
    ↓ [Checkpoint: Quantify impact with specific numbers/scenarios]
Step 5: Demonstrate (PoC, simulation, repro, minimized conditions)
    ↓ [Checkpoint: Working exploit code or proof of concept]
Step 6: Explain clearly (reporting, remediation guidance)
    ↓ [Checkpoint: Clear remediation with code example]
```

**If any link is weak, the whole conclusion collapses.**

---

## Checkpoint Requirements

Each step MUST produce verifiable artifacts:

### Step 1: Observation Checkpoint

```markdown
## Observation Record

**Observation**: [What suspicious behavior was noticed]
**Location**: [File.sol:Line-Range]
**Code Evidence**:
```solidity
[paste exact code]
```
**Invariant Violated**: [Which expected invariant is broken]
**Initial Confidence**: [0.0-1.0]
```

### Step 2: Reachability Checkpoint

```markdown
## Reachability Proof

**Entry Point**: [Function that external callers can invoke]
**Call Path**:
```
entryFunction() → internalA() → internalB() → vulnerableFunction()
```
**Conditions Required**:
- [Condition 1: e.g., `msg.value > 0`]
- [Condition 2: e.g., `!isPaused`]

**CodeQL Query** (if applicable):
```ql
[Deterministic reachability query]
```
**Reachability Confidence**: [0.0-1.0]
```

### Step 3: Controllability Checkpoint

```markdown
## Controllability Analysis

**Attacker-Controlled Inputs**:
| Input | Type | Source | Constraints |
|-------|------|--------|-------------|
| amount | uint256 | msg.value | > 0 |
| recipient | address | msg.data | none |

**State Variables Affected**:
- `balances[recipient]` (can increase)
- `totalSupply` (can increase)

**Sanitizers Missing**:
- [ ] No access control check
- [ ] No input validation
- [ ] No rate limiting

**Controllability Confidence**: [0.0-1.0]
```

### Step 4: Impact Assessment Checkpoint

```markdown
## Impact Assessment

**Impact Type**: [Theft / DoS / Privilege Escalation / Data Corruption]
**Financial Impact**: [e.g., "Up to $500M TVL at risk"]
**Exploit Cost**: [Gas cost + required capital]
**Probability**: [Likelihood of successful exploit]
**Risk Score**: [Critical/High/Medium/Low with justification]
```

### Step 5: PoC Checkpoint

```markdown
## Proof of Concept

**PoC Code**:
```solidity
[Working exploit code]
```
**Simulation Results**:
```
[Foundry/Hardhat test output showing exploit]
```
**Minimized Conditions**:
- [Minimum steps to reproduce]
```

### Step 6: Report Checkpoint

```markdown
## Finding Report

**Summary**: [2-3 sentences]
**Detailed Explanation**: [Technical explanation]
**Remediation**: [Specific fix with code]
**References**: [Similar vulnerabilities]
```

---

## Verifiable Subtasks vs Monolithic Reasoning

### ❌ Wrong: Monolithic Reasoning

```
"I think there's a reentrancy bug in this contract because it makes 
external calls before updating state. Let me write a PoC..."
```

Problems:
- Single point of failure
- No way to verify intermediate steps
- Compounding errors
- Unreviewable process

### ✅ Right: Verifiable Subtasks

```
Step 1: Identify all external calls in the contract
Step 2: Check state dependencies for each call
Step 3: Verify reentrancy protection mechanisms
Step 4: Generate specific attack hypothesis
Step 5: Validate with PoC
```

Advantages:
- Each step can be verified independently
- Errors caught early
- Deterministic tools can validate specific steps
- Reviewable process

---

## Fail-Fast Pruning

The harness must prune dead ends quickly:

### Pruning Rules

1. **No Entry Point**: If the function is not callable externally → PRUNE
2. **Access Control**: If proper auth checks exist → PRUNE  
3. **Already Protected**: If reentrancy guard exists on vulnerable path → PRUNE
4. **Unreachable State**: If preconditions cannot be satisfied → PRUNE
5. **Low Impact**: If maximum impact is < $1K or non-exploitable → PRUNE

### Pruning Documentation

Every pruned hypothesis must be documented:

```markdown
## Pruned Hypothesis: [Name]

**Pruned At**: Step [1-6]
**Reason**: [Specific rule triggered]
**Evidence**: [Why the pruning decision was made]
**Confidence**: High (pruning was correct)
```

---

## Determinism Injection

Make as much as possible deterministic, and reserve model reasoning for what can't be deterministic.

### Deterministic Tools to Use

| Question | Deterministic Tool |
|----------|-------------------|
| "Does taint from this input reach that sink?" | CodeQL taint tracking |
| "Which call paths lead here?" | CodeQL call graph |
| "Where is this state mutated?" | CodeQL data flow |
| "Are there missing auth checks?" | CodeQL pattern matching |
| "What functions are external?" | AST parsing |
| "Is this variable read before written?" | Static analysis |

### Tool Integration Protocol

1. **Query First**: Run deterministic query before reasoning
2. **Interpret Results**: Use model reasoning to interpret query output
3. **Reason on Gaps**: Use model reasoning where tools can't help
4. **Verify with Tools**: Validate conclusions with additional queries

---

## Confidence Tracking

Track confidence at each checkpoint using Bayesian updating:

```
Initial Confidence: q₀ = 0.2 (suspicious pattern spotted)
After Reachability: q₁ = q₀ + (1 - q₀) * evidence_strength
After Controllability: q₂ = q₁ + (1 - q₁) * evidence_strength
After Impact: q₃ = q₂ + (1 - q₂) * evidence_strength
After PoC: q₄ = 1.0 (proven) or 0.0 (disproven)
```

### Confidence Thresholds

- **q < 0.3**: Discard - insufficient evidence
- **0.3 ≤ q < 0.6**: Needs more investigation
- **0.6 ≤ q < 0.8**: Promising - continue verification
- **q ≥ 0.8**: Report as finding (but still needs PoC)

---

## The Auditor-Shaped Workflow

Mimic an experienced auditor, end-to-end:

```
01. Map the system
    └── assets, trust boundaries, invariants
    
02. Identify attack surfaces
    └── entrypoints, privileged flows
    
03. Generate hypotheses
    └── "If X controllable, does Y break?"
    
04. Verify aggressively
    └── deterministic tools to confirm
    
05. Prove impact
    └── exploit or simulate
    
06. Report cleanly
    └── explanation, repro, remediation
```

---

## Artifact Requirements

Every finding must produce these artifacts:

1. **observation.md**: Initial observation with code evidence
2. **reachability.md**: Call graph and path analysis
3. **controllability.md**: Attacker control analysis
4. **impact.md**: Quantified impact assessment
5. **poc.sol**: Working proof of concept
6. **finding.md**: Final report with remediation

---

## Usage in Ralph

### During Planning

Use harness to structure hypothesis generation:

```markdown
## Hypothesis: [ID]

**Based On**: [Observation from Step 1]
**Reachability Hypothesis**: [Predicted path from Step 2]
**Controllability Hypothesis**: [Predicted attacker control from Step 3]
**Impact Prediction**: [Predicted impact from Step 4]
**Validation Plan**: [How to prove/disprove]
```

### During Building

Execute harness for each hypothesis:

```bash
# Run verification harness
./scripts/harness_check.sh [hypothesis-id]

# This will:
# 1. Check if observation is valid
# 2. Verify reachability with CodeQL
# 3. Check controllability
# 4. Assess impact
# 5. Run PoC if available
```

---

## References

- Artificial Expert Intelligence through PAC-reasoning - arXiv:2412.02441
- Certified Reasoning with Language Models - arXiv:2305.20050
- Scaling LLM Test-Time Compute Optimally - arXiv:2408.03314
