# AGENTS.md - Security Research Operational Guide

## Mission

Hunt blockchain & smart contract vulnerabilities using Ralph's autonomous loop + finite-monkey's possibility space methodology.

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

### Phase 2: BUILDING (Remaining iterations)

**Goal**: Execute each check, find bugs, create PoCs  
**Input**: Tasks from `IMPLEMENTATION_PLAN.md`  
**Output**: Findings in `findings/vulnerabilities/`  
**Duration**: Multiple iterations (~20-30 minutes each)

**Key Actions**:

1. Select next incomplete task `[ ]`
2. Generate 3-5 vulnerability hypotheses (reverse scan - assume bug exists)
3. Validate each hypothesis rigorously (forward scan)
4. Create PoC for confirmed vulnerabilities
5. Mark task complete `[x]`

## The 6 Taint Models

Every vulnerability is a **SOURCE → SINK** path with missing **SANITIZER**.

| Model | Focus                 | Example                         |
| ----- | --------------------- | ------------------------------- |
| INV   | Data consistency      | `totalSupply != Σbalances`      |
| ASM   | Business logic flow   | Borrow before deposit           |
| EXP   | Dangerous expressions | Unchecked `.call()`             |
| TMP   | State machine/timing  | Bypass timelock                 |
| CMP   | Attack combinations   | Flash loan + price manipulation |
| BND   | Edge cases            | Zero/MAX values, overflow       |

## Possibility Space Construction

**Core Philosophy** (from finite-monkey-engine):

- Don't ask "Is there a bug?" → Assert "There IS a bug, find it"
- Generate multiple hypotheses (possibility space is finite)
- Validate to converge on real issues
- Embrace LLM hallucinations, then filter false positives

## Backpressure Mechanisms

Validation criteria for each finding:

- ✅ Concrete attack path exists
- ✅ Preconditions are realistic
- ✅ PoC code can demonstrate impact
- ✅ Code evidence matches claims
- ✅ No defensive measures were missed

## Exit Conditions

**Loop stops when**:

1. All tasks in `IMPLEMENTATION_PLAN.md` are complete `[x]`, OR
2. Max iterations reached (default: 50), OR
3. Circuit breaker triggered (3 consecutive errors)

## File Structure Reference

```
ralph-security-researcher/
├── target/                    # Your audit target (link or copy project here)
├── findings/
│   ├── vulnerabilities/       # PoCs for confirmed bugs
│   ├── project_analysis.md   # Initial understanding
│   ├── business_flows.md     # Flow diagrams
│   └── assumptions.md        # Security assumptions
├── knowledges/
│   ├── taint_models/         # 6 model templates
│   └── vulnerability_patterns/ # Common attack patterns
└── IMPLEMENTATION_PLAN.md    # Task checklist (auto-generated)
```

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

## Tips for Success

1. **Start Broad**: In planning, cover all 6 taint models
2. **Think Adversarial**: Always assume attackers find the worst path
3. **Validate Ruthlessly**: Most hypotheses will be false positives - that's expected
4. **Document Everything**: Future iterations need context
5. **Commit Often**: Git tracks your investigation progress
