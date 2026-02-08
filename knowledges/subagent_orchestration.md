# Subagent Orchestration: Scout/Strategist/Finalizer Pattern

> **Core Principle**: Orchestrator + Subagents >> Claude Code vanilla. Use subagents way more than you think.

The Scout/Strategist/Finalizer pattern splits vulnerability research into three distinct agentic roles, each with specific goals, actions, and outputs. This decomposition maintains accuracy over longer reasoning chains.

---

## The Three Roles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AGENTIC ROLES ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐                                                        │
│  │    SCOUT     │  Junior / Explorer                                     │
│  │  (Map Code)  │  Goal: Map the territory                               │
│  └──────┬───────┘  Action: Read code line-by-line                        │
│         │          Output: Observations & Assumptions                    │
│         ↓                                                               │
│  ┌──────────────┐                                                        │
│  │  STRATEGIST  │  Senior / Planner                                      │
│  │  (Find Bugs) │  Goal: Find contradictions                             │
│  └──────┬───────┘  Action: Review Scout's notes                          │
│         │          Output: Focused Hypotheses                            │
│         ↓                                                               │
│  ┌──────────────┐                                                        │
│  │  FINALIZER   │  QA / Verifier                                         │
│  │  (Prove It)  │  Goal: Prove/disprove hypothesis                       │
│  └──────────────┘  Action: Write PoC, run tests                          │
│                    Output: CONFIRMED or REJECTED                         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Role 1: The Scout (Junior / Explorer)

### Goal
Map the territory. Read code systematically and document observations without judgment.

### Actions
- Read code line-by-line
- Document observations (facts)
- Document assumptions (what the code seems to assume)
- Build relation-first graphs
- Identify entry points and data flows

### Output Format

```markdown
# Scout Report: [Target Contract]

## Observations (Facts)

OBS-001: Function `withdraw(uint256 amount)` at line 45 is `external`
OBS-002: `withdraw` calls `msg.sender.call{value: amount}("")` at line 52
OBS-003: `balances[msg.sender] -= amount` happens at line 55 (after external call)
OBS-004: No `nonReentrant` modifier on `withdraw`

## Assumptions (What Code Assumes)

ASM-001: Assumes `balances[msg.sender] >= amount` (checked at line 47)
ASM-002: Assumes external call succeeds (no return value check)
ASM-003: Assumes state changes after external call are safe

## Relation-First Graphs

### Call Graph
```
withdraw(amount)
  └─> _checkBalance(msg.sender, amount)
  └─> [EXTERNAL CALL] msg.sender.call{value: amount}("")
  └─> _updateBalance(msg.sender, amount)
```

### State Mutation Map
| Variable | Read At | Written At | Modified By |
|----------|---------|------------|-------------|
| balances | 47, 55 | 55 | withdraw |
| totalSupply | - | - | mint, burn |
```

### Scout Prompt

```markdown
You are a Scout (Junior Security Researcher). Your job is to map the code, not find bugs.

TASK: Read [contract file] and create a Scout Report.

INSTRUCTIONS:
1. Read every function line-by-line
2. Document observations as facts (what IS true)
3. Document assumptions (what the code seems to assume)
4. Build call graphs showing function relationships
5. Identify all state variables and who modifies them
6. DO NOT try to find bugs - just document what you see

OUTPUT FORMAT:
- Observations: OBS-XXX format, one per line
- Assumptions: ASM-XXX format, one per line
- Call graph in Mermaid format
- State mutation table

BE THOROUGH. Don't skip any functions. Document everything.
```

### When to Spawn a Scout

- Initial codebase exploration
- New contract added to scope
- Complex protocol with many contracts
- Need to understand unfamiliar code patterns

---

## Role 2: The Strategist (Senior / Planner)

### Goal
Find contradictions. Review Scout's observations and assumptions to identify where invariants might be violated.

### Actions
- Review Scout reports
- Look for contradictions between observations and assumptions
- Generate focused vulnerability hypotheses
- Identify which hypotheses are worth investigating
- Rank by confidence and impact

### Output Format

```markdown
# Strategist Analysis: [Target Contract]

## Contradictions Found

CON-001: OBS-003 contradicts ASM-003
- Observation: External call happens at line 52
- Observation: State update happens at line 55 (AFTER external call)
- Assumption: Code assumes this is safe
- Contradiction: This is CEI violation - NOT safe!

## Hypotheses Generated

HYP-001: Reentrancy in withdraw()
**Confidence**: HIGH
**Impact**: CRITICAL
**Basis**: CON-001 (CEI violation) + OBS-004 (no reentrancy guard)
**Attack Scenario**:
1. Attacker calls withdraw()
2. External call at line 52 triggers receive()
3. Attacker reenters withdraw() before line 55
4. Balance not yet deducted, so check passes again
5. Multiple withdrawals succeed

HYP-002: Unchecked call return value
**Confidence**: MEDIUM
**Impact**: MEDIUM
**Basis**: OBS-002 + ASM-002
**Attack Scenario**:
1. External call fails silently
2. Balance still deducted
3. User loses funds

## Prioritization

1. HYP-001 (CRITICAL, HIGH confidence) - Investigate first
2. HYP-002 (MEDIUM, MEDIUM confidence) - Investigate second
```

### Strategist Prompt

```markdown
You are a Strategist (Senior Security Researcher). Your job is to find bugs by finding contradictions.

TASK: Review the Scout Report for [contract] and generate vulnerability hypotheses.

INSTRUCTIONS:
1. Read the Scout Report thoroughly
2. Look for contradictions between:
   - What the code DOES vs what it ASSUMES
   - Security best practices vs actual implementation
   - Invariants that should hold vs code that might break them
3. Generate specific, falsifiable hypotheses
4. Rank by confidence and impact
5. For each hypothesis, explain the contradiction that suggests it exists

FOCUS ON:
- CEI pattern violations
- Missing access control
- State inconsistencies
- Trust boundary violations
- Timing assumptions

OUTPUT FORMAT:
- Contradictions: CON-XXX format
- Hypotheses: HYP-XXX format with confidence and impact
- Clear reasoning for each
```

### When to Spawn a Strategist

- After Scout completes mapping
- Have observations but need to prioritize
- Multiple potential issues, need focus
- Complex protocol requiring strategic thinking

---

## Role 3: The Finalizer (QA / Verifier)

### Goal
Prove it. Take hypotheses and either confirm with PoC or reject with evidence.

### Actions
- Take hypothesis from Strategist
- Write PoC code
- Run tests/simulations
- Verify reachability and controllability
- Document CONFIRMED or REJECTED

### Output Format

```markdown
# Finalizer Report: HYP-001

## Hypothesis
Reentrancy in withdraw() allows draining contract

## Verification Steps

### Step 1: Reachability Verified
- [x] Function is external (line 45)
- [x] No access control blocking
- [x] Path: withdraw() → external call → reenter withdraw()

### Step 2: Controllability Verified
- [x] Attacker controls: `amount` parameter
- [x] Attacker receives: external call to attacker contract
- [x] Attacker can: reenter via receive()

### Step 3: PoC Created

```solidity
contract ReentrancyExploit {
    Vulnerable public target;
    uint256 public count;
    
    function attack() external {
        target.deposit{value: 1 ether}();
        target.withdraw(1 ether);
    }
    
    receive() external payable {
        if (count < 5) {
            count++;
            target.withdraw(1 ether);
        }
    }
}
```

### Step 4: Test Results

```bash
$ forge test --match-test testReentrancy -vvvv
[PASS] testReentrancy() (gas: 98765)
Logs:
  Initial balance: 10 ether
  After attack: 5 ether
  Attacker gained: 5 ether
```

## VERDICT: CONFIRMED

**Severity**: CRITICAL
**Impact**: Contract can be drained
**Evidence**: PoC demonstrates 5x withdrawal with 1x deposit
```

### Finalizer Prompt

```markdown
You are a Finalizer (QA Security Researcher). Your job is to prove or disprove hypotheses.

TASK: Verify hypothesis [HYP-XXX]: [description]

INSTRUCTIONS:
1. Verify reachability: Can an external attacker actually reach this code?
2. Verify controllability: Can the attacker control the necessary inputs?
3. Write a complete PoC using Foundry
4. Run the PoC and document results
5. If PoC succeeds, document CONFIRMED with all evidence
6. If PoC fails, document REJECTED with specific reason

REQUIREMENTS:
- PoC must compile without errors
- PoC must demonstrate the claimed impact
- Document exact steps to reproduce
- Quantify the impact (how much can be stolen/drained)

OUTPUT FORMAT:
- Reachability check
- Controllability check
- PoC code
- Test results
- CONFIRMED or REJECTED verdict
```

### When to Spawn a Finalizer

- Have a promising hypothesis to verify
- Need PoC for confirmed vulnerability
- Need to disprove a hypothesis
- Final stage of verification harness

---

## Orchestration Patterns

### Pattern 1: Linear Pipeline

```
Scout → Strategist → Finalizer
```

Best for: Individual contracts, focused analysis

### Pattern 2: Parallel Scout, Sequential Finalize

```
         ┌→ Scout (Contract A) →┐
         ├→ Scout (Contract B) →┤
Orchestrator → Scout (Contract C) → Strategist → Finalizer (each hypothesis)
         ├→ Scout (Contract D) →┤
         └→ Scout (Contract E) →┘
```

Best for: Large protocols with many contracts

### Pattern 3: Hypothesis Parallelization

```
Scout → Strategist → ┌→ Finalizer (HYP-001)
                     ├→ Finalizer (HYP-002)
                     ├→ Finalizer (HYP-003)
                     └→ Finalizer (HYP-004)
```

Best for: Multiple hypotheses from single analysis

### Pattern 4: Iterative Refinement

```
Scout → Strategist → Finalizer (rejects) → Strategist (new hypothesis) → Finalizer
```

Best for: Complex bugs requiring multiple attempts

---

## Integration with Ralph

### In loop.sh

```bash
# Linear pipeline for each task
run_scout() {
    cat PROMPT_scout.md | codex --model claude-sonnet-4 < task_input
}

run_strategist() {
    cat PROMPT_strategist.md | codex --model claude-opus-4.5 < scout_output
}

run_finalizer() {
    cat PROMPT_finalizer.md | codex --model claude-opus-4.5 < hypothesis
}

# Execute pipeline
scout_output=$(run_scout)
strategist_output=$(run_strategist <<< "$scout_output")
for hypothesis in $(extract_hypotheses <<< "$strategist_output"); do
    run_finalizer <<< "$hypothesis" &
done
wait
```

### In IMPLEMENTATION_PLAN.md

```markdown
## Subagent Orchestration

Task INV-001:
- Scout: Map Token.sol state variables
- Strategist: Find invariant violations
- Finalizer: Verify each hypothesis

Compute Allocation:
- Scout: LOW (Sonnet 4.5)
- Strategist: HIGH (Opus 4.5)
- Finalizer: HIGH (Opus 4.5) per hypothesis
```

---

## Model Selection by Role

| Role | Recommended Model | Rationale |
|------|------------------|-----------|
| Scout | Sonnet 4.5 | Fast, good at pattern matching, thorough |
| Strategist | Opus 4.5 (Thinking) | Complex reasoning, contradiction detection |
| Finalizer | Opus 4.5 or GPT-5.2-Codex | Code generation, PoC writing |

---

## Communication Protocol

### Between Scout and Strategist

Scout output must include:
- Complete observations list
- Assumptions documented
- Call graphs
- State mutation maps

### Between Strategist and Finalizer

Strategist output must include:
- Specific hypothesis description
- Line numbers and file references
- Expected attack scenario
- Confidence level

### Finalizer to Orchestrator

Finalizer output must include:
- CONFIRMED or REJECTED verdict
- Evidence (PoC or disproof)
- Quantified impact (if confirmed)
- Root cause analysis

---

## Benefits of This Pattern

1. **Separation of Concerns**: Each role focuses on one task
2. **Verifiable Steps**: Output of each role can be reviewed
3. **Parallelization**: Multiple Scouts/Finalizers can run simultaneously
4. **Fail Fast**: Rejected hypotheses don't waste senior model time
5. **Accuracy**: Decomposed reasoning maintains precision over long chains

---

## Anti-Patterns to Avoid

1. **Scout trying to find bugs**: Let the Strategist do analysis
2. **Strategist writing PoC**: Let the Finalizer handle verification
3. **Finalizer doing exploration**: Should receive focused hypothesis
4. **Skipping roles**: Each role adds value, don't skip for speed
5. **Unclear handoffs**: Define exactly what each role receives and produces
