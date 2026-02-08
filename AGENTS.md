# AGENTS.md - Security Research Operational Guide

## Mission

Hunt blockchain & smart contract vulnerabilities using Ralph's autonomous loop + finite-monkey's possibility space methodology, augmented with agentic harnesses and deterministic verification.

---

## Allowed Agents

### Model Selection: SOTA-First Principle

**One of the biggest "we changed our mind" outcomes: We are not using smaller models for first-pass generation.**

For current operations, use only:

| Model | Use Case | Notes |
|-------|----------|-------|
| **GPT-5.2-Codex** | Planning, reasoning, code-heavy tasks, tool use | Single approved model for now |

**Key Finding**: The best results came when we paired SOTA models with their native toolchains—then augmented them with our own extended cyber toolset.

- GPT → Codex tooling (gpt-5.2-codex outperforms general gpt-5.2 for this workload)
- Plus our extended toolset, including cyber-specific tools like CodeQL

This isn't cosmetic. Native toolchains tend to align with the model's learned operating style (how it searches, edits, executes, and recovers). Adding cyber-native determinism on top turns that into something you can actually trust under audit pressure.

---

## Workflow Phases

### Phase 1: PLANNING (First iteration)

**Goal**: Understand target, create systematic hunting checklist  
**Input**: Target codebase in `./target/`  
**Output**: `IMPLEMENTATION_PLAN.md` with 20-50 specific vulnerability checks  
**Duration**: Single iteration (~60-90 minutes)

**Key Actions**:

1. Analyze project structure & business flows
2. Map security assumptions & invariants
3. Generate tasks using 6 taint models (INV/ASM/EXP/TMP/CMP/BND)
4. Prioritize by severity (CRITICAL → HIGH → MEDIUM → LOW)
5. **NEW**: Run baseline CodeQL queries to identify high-confidence patterns
6. **NEW**: Generate attack surface map + code index (entrypoints, callsites)

### Phase 2: BUILDING (Remaining iterations)

**Goal**: Execute each check, find bugs, create PoCs  
**Input**: Tasks from `IMPLEMENTATION_PLAN.md`  
**Output**: Findings in `findings/vulnerabilities/`  
**Duration**: Multiple iterations (~20-30 minutes each)

**Key Actions**:

1. Select next incomplete task `[ ]`
2. Generate 3-5 vulnerability hypotheses (reverse scan - assume bug exists)
3. **NEW**: Run targeted CodeQL queries for each hypothesis
4. Validate each hypothesis rigorously (forward scan)
5. **NEW**: Apply the 6-step verification harness for confirmed issues
6. Create PoC for confirmed vulnerabilities
7. Mark task complete `[x]`

---

## Test-Time Compute: Adaptive Allocation

A major pattern we observed is that our system behaves less like a scanner and more like a **search-and-proof engine**:

- **Explore hypotheses** (breadth)
- **Deepen promising lines** (depth)
- **Verify aggressively** (proof)
- **Produce repro artifacts** (trust)

This maps cleanly onto the broader trend of scaling test-time compute: performance increases not only from bigger pretrained models, but from allocating more inference-time work to hard instances.

### Adaptive Compute Strategy

```
┌────────────────────────────────────────────────────────────────┐
│                    ADAPTIVE COMPUTE ALLOCATION                  │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Shallow Triage (Low Compute)                                   │
│  ├── CodeQL baseline queries                                    │
│  ├── Quick pattern matching                                     │
│  └── Surface-level analysis                                     │
│                         ↓ (signals detected)                    │
│  Medium Investigation (Medium Compute)                          │
│  ├── Targeted CodeQL queries                                    │
│  ├── Hypothesis generation (3-5 hypotheses)                     │
│  └── Reachability analysis                                      │
│                         ↓ (promising hypothesis)                │
│  Deep Investigation (High Compute)                              │
│  ├── Full verification harness (all 6 steps)                    │
│  ├── PoC development and testing                                │
│  └── Impact quantification                                      │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Compute Allocation Rules

1. **Not every signal deserves the same spend**
2. **Some repos/components need shallow triage; others need deep multi-tool investigation**
3. **The system improves when it allocates compute adaptively based on "difficulty" and "promise"**, instead of treating all code equally

### Difficulty Indicators

| Indicator | Interpretation | Action |
|-----------|---------------|--------|
| CodeQL finds pattern | High-confidence issue exists | Allocate high compute for PoC |
| Complex DeFi math | High expertise needed | Use GPT-5.2-Codex with security math primer |
| Simple token contract | Lower complexity | Use Codex for fast verification |
| Novel pattern | No prior examples | Deep investigation warranted |
| Known pattern | Well-documented | Shallow verification |

---

## The 6 Taint Models

Every vulnerability is a **SOURCE → SINK** path with missing **SANITIZER**.

| Model | Focus | Example |
| ----- | ----- | ------- |
| INV | Data consistency | `totalSupply != Σbalances` |
| ASM | Business logic flow | Borrow before deposit |
| EXP | Dangerous expressions | Unchecked `.call()` |
| TMP | State machine/timing | Bypass timelock |
| CMP | Attack combinations | Flash loan + price manipulation |
| BND | Edge cases | Zero/MAX values, overflow |

---

## Possibility Space Construction

**Core Philosophy** (from finite-monkey-engine):

- Don't ask "Is there a bug?" → Assert "There IS a bug, find it"
- Generate multiple hypotheses (possibility space is finite)
- Validate to converge on real issues
- Embrace LLM hallucinations, then filter false positives

---

## The Verification Harness

**NEW**: All findings must pass through the 6-step verification harness:

1. **Identify suspicious behavior** or invariant violations
2. **Prove reachability** (call paths, entrypoints, conditions)
3. **Prove controllability** (attacker influence on relevant state/data)
4. **Determine real-world impact** (theft, DoS, privilege escalation, etc.)
5. **Demonstrate** (PoC, simulation, repro, minimized conditions)
6. **Explain clearly** (reporting, remediation guidance)

**If any link is weak, the whole conclusion collapses.**

See `knowledges/agentic_harness.md` for the complete framework.

---

## Determinism Injection with CodeQL

**NEW**: Make as much as possible deterministic, and reserve model reasoning for what can't be deterministic.

| Question | Tool |
|----------|------|
| "Does taint from this input reach that sink?" | CodeQL |
| "Which call paths lead here?" | CodeQL |
| "Where is this state mutated, and under what guards?" | CodeQL |
| "Are there patterns of missing auth checks?" | CodeQL |

See `knowledges/codeql_integration.md` for query library.

---

## Backpressure Mechanisms

Validation criteria for each finding:

- ✅ Concrete attack path exists
- ✅ Preconditions are realistic
- ✅ PoC code can demonstrate impact
- ✅ Code evidence matches claims
- ✅ No defensive measures were missed
- **NEW**: ✅ Passed all 5 verification gates (see `knowledges/verification_protocol.md`)
- **NEW**: ✅ Negative evidence logged for pruned hypotheses (prevents repeats)

---

## Exit Conditions

**Loop stops when**:

1. All tasks in `IMPLEMENTATION_PLAN.md` are complete `[x]`, OR
2. Max iterations reached (default: 50), OR
3. Circuit breaker triggered (3 consecutive errors), OR
4. **NEW**: Compute budget exhausted (adaptive allocation limit)

---

## File Structure Reference

```
ralph-security-researcher/
├── target/                    # Your audit target (link or copy project here)
├── findings/
│   ├── vulnerabilities/       # PoCs for confirmed bugs
│   ├── project_analysis.md   # Initial understanding
│   ├── business_flows.md     # Flow diagrams
│   ├── assumptions.md        # Security assumptions
│   └── codeql-db/            # CodeQL database
├── knowledges/
│   ├── taint_models/         # 6 model templates
│   ├── vulnerability_patterns/ # Common attack patterns
│   ├── agentic_harness.md    # Verification harness framework
│   ├── verification_protocol.md # 5-gate verification
│   └── codeql_integration.md # CodeQL query library
└── IMPLEMENTATION_PLAN.md    # Task checklist (auto-generated)
```

---

## Integration with Testing

**Foundry** (Ethereum/Solidity):

```bash
cd target && forge test --match-contract Exploit -vvvv
```

**Anchor** (Solana/Rust):

```bash
cd target && anchor test
```

**Move** (Aptos/Sui):

```bash
cd target && aptos move test
```

---

## Tips for Success

1. **Start Broad**: In planning, cover all 6 taint models
2. **Think Adversarial**: Always assume attackers find the worst path
3. **Validate Ruthlessly**: Most hypotheses will be false positives - that's expected
4. **Document Everything**: Future iterations need context
5. **Commit Often**: Git tracks your investigation progress
6. **NEW**: Use CodeQL first, reason second
7. **NEW**: Allocate compute based on signal strength
8. **NEW**: Pass all 5 verification gates before reporting
9. **NEW**: For external integrations, compare code against integrator docs and hunt mismatches (doc-first, no generic checklist)

---

## Bug Bounty Mode (NEW)

When hunting for bounty ROI (instead of full audit coverage), enable:

```bash
BOUNTY_MODE=true HARD_ENFORCEMENT=true ./loop.sh
```

Required planning artifact:
- `findings/bounty_program_assessment.md`

Use it to gate effort before deep analysis:
- Program fairness risk (`reputation`, `treasury`, `rules_clarity`)
- Expected-value factors (`complexity`, `innovation`, `optimization`, `integration risk`)
- Explicit `go_no_go` decision

Operational guidance:
- Prioritize exploitable critical paths with realistic asset impact.
- Deprioritize deprecated/inactive/non-deployed paths unless clearly reachable.
- Archive rules before disclosure (`scripts/snapshot_bounty_rules.sh <url> <label>`).

---

## Engineering Guardrails (NEW)

Ralph now supports a global engineering guardrail prompt layer:

- `PROMPT_engineering.md` (prepended to planning/building prompts by default)
- `knowledges/senior_engineering_guardrails.md` (detailed reference)

This layer enforces:
- Explicit assumption surfacing before non-trivial changes
- Stop-and-clarify behavior on conflicting requirements
- Scope discipline and simplicity-first implementation
- Structured post-change summaries and dead-code hygiene
- Framework-first bias (prefer built-ins over custom subsystems)
- Anti-bloat pressure against premature optimization

For design-heavy tasks, use:
- `knowledges/spec_refinement_protocol.md`
- `.agent/workflows/spec.md` (`/spec [requirements-file]`)

The spec protocol uses iterative drafts with an opinionated critic pass:
Draft A → Critic review → Draft B (→ optional Draft C), then pause for human review before implementation.

Toggle with env vars:

```bash
ENGINEERING_GUARDRAILS=true|false
GUARDRAILS_PROMPT_FILE=PROMPT_engineering.md
HARD_ENFORCEMENT=true|false
```

When `HARD_ENFORCEMENT=true`, BUILDING iterations are automatically marked `NEEDS_REVIEW`
if `findings/tasks/<TASK-ID>/result.md` is missing required fields:
`assumptions`, `scope_checked`, and `out_of_scope` (in addition to base result fields).

PLANNING iterations are also marked `NEEDS_REVIEW` if
`findings/clarifications_needed.md` is missing required fields:
`clarification_status`, `assumptions`, and `open_questions`.

Use `scripts/lint_task_result.sh` to preflight task result records before loop completion.

External integration hunting is mandatory in protocol audits:
- Confirm integrations from code evidence first.
- Pull official live docs for the exact integrated feature.
- Compare docs requirements vs implementation with file+line citations.
- Record results in `findings/external_integrations.md` and `findings/integration_gaps.md`.

When `HARD_ENFORCEMENT=true`, PLANNING iterations are marked `NEEDS_REVIEW` if
integration artifacts are missing required evidence fields (`official_doc_url`,
`local_doc_path`, `doc_requirement_quote`, `code_reference`, `verdict` as applicable).

---

## Operational Safety (Flow State)

**Philosophy**: "Speed without Fear."
We run with `dangerously-skip-permissions` enabled, but protected by **Hooks**.

**The Safety Hook (`safety_check.sh`)**:
Before any command execution, the hook validates the intent.

- **Allowed**: `mkdir`, `touch`, `forge`, `grep`.
- **BLOCKED**: `rm -rf /`, `export PRIVATE_KEY`, `git push --force`.

**Agent Directive**:
If the hook blocks your action:

1. **Do NOT bypass it**.
2. **Analyze why**: Am I trying to delete root?
3. **Correct course**: Use a safer command.

---

## Orchestrator Architecture (Subagents)

**Directive**: "Orchestrator + Subagents >> Claude Code vanilla."
**Subagent Rule**: Use subagents way more than you think.

### Scout/Strategist/Finalizer Pattern

**NEW**: Adopt the agentic roles technique:

| Role | Goal | Action | Output |
|------|------|--------|--------|
| **Scout** (Junior) | Map the territory | Read code line-by-line | Observations & Assumptions |
| **Strategist** (Senior) | Find the bugs | Review Scout's notes for contradictions | Focused Hypotheses |
| **Finalizer** (QA) | Prove it | Write the PoC | CONFIRMED or REJECTED |

See `knowledges/subagent_orchestration.md` for detailed patterns.

### When to Spawn a Subagent

1. **Deep Knowledge Retrieval**: "Read all 50 files in `knowledges/` and summarize patterns." → **Use GPT-5.2-Codex**.
2. **Complex Reasoning**: "Build the 4 Hound Graphs for this protocol." → **Use GPT-5.2-Codex**.
3. **CodeQL Analysis**: "Run all security queries and summarize." → **Use GPT-5.2-Codex**.
4. **PoC Development**: "Write Foundry test for this hypothesis." → **Use GPT-5.2-Codex**.
5. **Massive Refactors**: "Rename this variable in 20 files." → **Use GPT-5.2-Codex**.

**The Mindset**:
You are not just a worker; you are a **Manager**. Break the task down, assign it to a subagent (if available in your toolset), and review the output.

---

## Meta-Learning (Failure Analysis)

**"Reconstruct the Input-Output Loop"**: Agentic coding often hides why things fail. To improve, we must expose the failure loop.

**Protocol**:
When something fails (a finding is rejected, a test fails to compile, or the agent gets stuck):

1. **Log the Exact Failure Trigger**:
   - What was the exact prompt?
   - What was the context (files open)?
   - What was the erroneous output?
2. **Categorize the Failure**:
   - `Context Blindness` (Didn't read the file)
   - `Hallucination` (Invented a function)
   - `Logical Fallacy` (Bad math/reasoning)
   - `Tool Misuse` (Wrong grep arguments)
3. **Root Cause Analysis**:
   - Ask: _"What did I do wrong?"_
   - _Self-Correction_: "I should have verified `token.decimals()` before assuming 18."

**Patterns emerge when you log 10+ failures. Use these patterns to update `knowledges/` guidelines.**

---

## References

- Artificial Expert Intelligence through PAC-reasoning - arXiv:2412.02441
- Scaling LLM Test-Time Compute Optimally - arXiv:2408.03314
- Smaller, Weaker, Yet Better: Training LLM Reasoners - arXiv:2408.16737
