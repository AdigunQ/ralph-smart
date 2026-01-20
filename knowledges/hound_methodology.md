# Hound Methodology: Relation-First Knowledge Graphs & Belief Systems

> **Based on**: "Hound: Relation-First Knowledge Graphs for Complex-System Reasoning in Security Audits" (Muller, arXiv:2510.09633v1)

This methodology uses **Relation-First Graphs** to improve reasoning across interrelated components and a **Persistent Belief System** to track long-lived hypotheses.

## 🏗️ Core Architecture

### 1. Relation-First Knowledge Graphs

Expert auditors do not keep a frozen view of the system. They use flexible, analyst-defined graphs that capture abstract system aspects, anchored to exact code slices.

**Key Graphs to Model:**

- **SystemArchitecture**: High-level components & interfaces.
- **AuthorizationRoles**: Who can call what (Authentication/Authorization).
- **AssetAndFeeFlows**: Token/value movement during listing, purchase, vesting, claims.
- **StateMutationMap**: Key storage variables and who mutates them.
- **CallGraphs**: Inter-contract invocation paths.

> **Why?** Graphs enable **Exact Retrieval**. Instead of vector search (fuzzy), the agent follows typed edges to load _exactly_ the code needed (often across components).

### 2. Persistent Belief System (Hypothesis Lifecycle)

Hypotheses are not transient thoughts. They are **First-Class Objects** that persist across sessions.

**Hypothesis Fields:**

- **Title/Type**: "Reentrancy in withdraw"
- **Severity**: High/Medium/Low
- **Confidence ($q$)**: $0.0 - 1.0$
- **Status**: `proposed` -> `investigating` -> `supported` -> `refuted` -> `confirmed/rejected`
- **Evidence**: Linked graph nodes & code slices

**Lifecycle:**

1. **Strategies** proposes a hypothesis ($q=0.2$).
2. **Scout** gathers evidence. evidence supports it ($q=0.6$, status=`supported`).
3. **Strategist** realizes a check is missing ($q=0.8$).
4. **Finalizer** (QA) confirms the exploit ($q=1.0$, status=`confirmed`).

### 3. Two-Phase Planning

Audits move through two distinct phases:

**Phase A: Coverage (Sweep)**

- **Goal**: Map components, fill the graph.
- **Strategy**: Systematically visit unvisited nodes. Maximize node/card visitation.
- **Focus**: Medium-granularity components.

**Phase B: Intuition (Saliency)**

- **Goal**: Deep dives on high-impact suspicions.
- **Trigger**: Coverage > 90% ($p^* \approx 0.9$).
- **Strategy**:
  - **Saliency**: Contradictions between _Assumptions_ and _Observations_.
  - **Value at Risk**: Components handling user funds.
  - **Novelty**: Unexplored interaction paths.

## 🤖 Agent Roles

| Role                    | Function                                                                     | Human Equivalent  |
| ----------------------- | ---------------------------------------------------------------------------- | ----------------- |
| **Strategist (Senior)** | Plans investigations. Proposes Hypotheses. Reviews evidence. "Why now?"      | Lead Auditor      |
| **Scout (Junior)**      | Navigates graphs. Loads nodes/code. Annotates observations. "What is this?"  | Junior Auditor    |
| **Finalizer (QA)**      | Reviews full source context of high-confidence hypotheses. Confirms/Rejects. | Quality Assurance |

## 🛠️ Execution Protocol

### Step 1: Graph Discovery

Use the **Scout** to build the initial `SystemArchitecture`. Then define custom "Aspect Graphs" (e.g., `VestingLifecycle`).

### Step 2: Annotation (The "Junior" Loop)

Read code slices and attach typed annotations to nodes:

- **Observation**: Fact about code ("Updates `totalAssets`").
- **Assumption**: Expected invariant ("`totalAssets` should match sum of balances").

### Step 3: Hypothesis Generation (The "Senior" Loop)

The **Strategist** reviews annotations for **Contradictions**.

- _Contradiction_: "Invariant says 'Rate is constant', Observation says 'Rate updated on transfer'."
- _Action_: Propose Hypothesis: "Rate manipulation via transfer."

### Step 4: Verification

**Scout** loads _only_ the specific cards referenced by the Hypothesis.

- Does the code prove the vulnerability?
- Update Confidence ($q$).

### Step 5: Finalization

**Finalizer** reviews confirmed ($q>0.8$) hypotheses with full context.

- Generates PoC if possible.
- Writes final verdict.

## 💡 Practical Prompts for Agents

### "Deep Research" Mode (Graph Building)

```
Act as the Scout.
Build an 'AssetAndFeeFlows' graph for the [Target Component].
Nodes: Functions, State Variables.
Edges: 'modifies', 'transfers_to', 'calculates_fee_for'.
Annotate each node with:
1. Observations (What it does)
2. Assumptions (What must be true)
```

### "Intuition" Mode (Hypothesis Generation)

```
Act as the Strategist.
Review the 'AssetAndFeeFlows' graph.
Look for contradictions between Assumptions and Observations.
Focus on:
1. Value at Risk (User funds)
2. Inconsistent State Updates
3. Missing Checks on Critical Paths

Propose 3 Focused Hypotheses with initial confidence scores.
```
