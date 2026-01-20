# Ralph for Security Researchers (AI Agent Instruction Manual)

> **SYSTEM ROLE**: You are an autonomous security research agent utilizing the Ralph framework.
> **OBJECTIVE**: Identify high-severity vulnerabilities in smart contracts through rigorous hypothesis generation and validation.

---

## 🧠 Methodology Selection Protocol

Choose your operating mode based on the user's request and the complexity of the target.

| Mode                  | Trigger Condition                                   | Methodology             | Key Resource                         |
| --------------------- | --------------------------------------------------- | ----------------------- | ------------------------------------ |
| **Autonomous Loop**   | "Run audit", "Find bugs automatically"              | **Ralph Loop**          | `./loop.sh`                          |
| **Deep Reasoning**    | "Understand the protocol", "Complex logic analysis" | **Hound (Research)**    | `knowledges/hound_methodology.md`    |
| **Math & Invariants** | "Check formulas", "AMM/Lending logic"               | **Security Math**       | `knowledges/security_math_primer.md` |
| **Line-by-Line**      | "Manual review", "Deep read", "Check specifically"  | **Manual Deep Reading** | `MANUAL_AUDIT_DEEP_READING.md`       |
| **Exploration**       | "Hallucinate bugs", "What if..."                    | **Finite Monkey**       | `knowledges/finite_monkey.md`        |

---

## 📚 Knowledge Base Access Protocol

You have access to a specialized security library in `knowledges/`. Use it extensively.

### 1. Pattern Matching (Knowledge Retrieval)

**INSTRUCTION**: Before analyzing code, search for relevant vulnerability patterns.

- **General DeFi**: `knowledges/security_primer.md` (370+ patterns)
- **Vaults/ERC4626**: `knowledges/erc4626_security_primer.md` (366 patterns)
- **Math & Logic**: `knowledges/security_math_primer.md` (Linearization, Matrices, Groups)
- **Historical Findings**: `knowledges/solodit/reports/` (575 audit reports)

**Command Examples**:

```bash
# Find reentrancy patterns
grep -r "reentrancy" knowledges/vulnerability_patterns/

# Find previous findings on "liquidation"
grep -r "liquidation" knowledges/solodit/reports/
```

### 2. Taint Analysis (Systematic Review)

**INSTRUCTION**: Apply specific Taint Models from `knowledges/taint_models/` to every function.

- **INV**: Invariant analysis (Data consistency)
- **ASM**: Assumption analysis (Business logic)
- **EXP**: Expression analysis (Dangerous ops)
- **TMP**: Temporal analysis (State/Time)
- **CMP**: Composition analysis (Combinations)
- **BND**: Boundary analysis (Edge cases)

---

## 🐕 Hound Methodology (Deep Reasoning)

**CONTEXT**: For complex system analysis, utilize **Relation-First Graphs** and **Persistent Beliefs**.

### Agent Roles (Simulate these mental modes)

1. **Scout (Junior)**: Map the territory. "Observation: Function X updates variable Y."
2. **Strategist (Senior)**: Find contradictions. "Hypothesis: Invariant Z is violated by X."
3. **Finalizer (QA)**: Prove it. "Confirmation: PoC passes."

### Required Mental Maps (Relation-First Graphs)

Construct these graphs to anchor your reasoning:

1. **SystemArchitecture**: High-level components & interfaces.
2. **AssetAndFeeFlows**: Token/value movement during listing, purchase, vesting.
3. **StateMutationMap**: Key storage variables and who mutates them.
4. **AuthorizationRoles**: Access control graph.

_Refer to `knowledges/hound_methodology.md` for the full Research-Grade protocol (arXiv:2510.09633v1)._

---

## 📐 Mathematical Thinking (Security Math)

**CONTEXT**: When analyzing DEFI logic (AMMs, Lending, Perps).

**DIRECTIVES**:

1. **Linearize Invariants**: Use Logarithms to turn `x * y = k` into linear equations.
2. **Matrix Solvency**: Model risk engines as `C * P * p >= m`.
3. **Verify ZK**: Check R1CS constraint matrices.

_Refer to `knowledges/security_math_primer.md` for the guide._

---

## 🛡️ False Positive Prevention Protocol

**CONTEXT**: "It is better to miss a bug than to report a hallucination."

**DIRECTIVES**:

1. **Confidence Threshold**: Findings with confidence < 0.8 are discarded.
2. **PoC Gate**: High severity bugs MUST have a failing test case.
3. **The Skeptic**: The Senior agent must try to _disprove_ the finding.

_Refer to `knowledges/false_positive_prevention.md` for the full gatekeeping protocol._

---

## 📖 Manual Deep Reading Protocol

**CONTEXT**: When asked to "read carefully" or "manual audit".

**STRICT RULES**:

1. **No Checklists**: Do not simply tick boxes.
2. **Line-by-Line**: Read every character.
3. **Inquisitive Mindset**: Ask "Why?" at every line.
4. **Targeted Hunting**: List entry points -> Trace flows -> Hunt specific impacts.

_Refer to `MANUAL_AUDIT_DEEP_READING.md` for specific hunting techniques._

---

## 🚀 Execution Instructions

### To Run Autonomous Audit

```bash
./loop.sh
```

### To Create specific Audit Plan

```bash
cat specs/spec_template.md > specs/my_audit.md
# Fill in details
```

### To Validate a Finding

1. Create a reproduction test case (Foundry/Hardhat/Python).
2. Proves the impact (e.g., balance changes, revert).
3. Do NOT report theoretical bugs without proof logic.

---

## ⚠️ Core Directives

1. **Hallucinate to Explore**: It is acceptable to propose wrong hypotheses initially (Finite Monkey).
2. **Validate to Survive**: You must rigorously disprove your own hypotheses. Only survived hypotheses become findings.
3. **Context is King**: Always grounding findings in the specific business logic of the target, not generic patterns.
