# Hound Methodology: Deep Logic Bug Hunting

> **Core Philosophy**: "Shallow reasoning misses bugs no matter how many guesses you make; deep reasoning turns a few steps into the right ones." — Bernhard Mueller

This methodology focuses on simulating the cognitive processes of human experts: building flexible mental maps, tracking assumptions, and refining understanding as new evidence emerges.

## 🧠Key Concepts

### 1. Dynamic Knowledge Graphs (Mental Maps)

Human experts don't read code linearly. They build mental maps of:

- Components & call hierarchies
- State & value flows
- Authorization boundaries
- Assumptions & Invariants

**Action**: Model the system as a "living knowledge graph" rather than a flat file.

- **Node**: A function, role, or concept (e.g., "Vesting Lifecycle")
- **Edge**: Relationships (calls, modifies, checks)
- **Annotation**: "Fee <= 1000 bps", "Only owner can delist"

### 2. Hypothesis-Driven Auditing

Better to generate **focused hypotheses** with deep reasoning than to spray thousands of shallow checks.

- **Annotation**: Working assumptions based on evidence (cheap, easy to revise).
  - _Example_: "releaseRate = amount / duration"
- **Hypothesis**: Targeted, falsifiable claim about a vulnerability (expensive, high value).
  - _Example_: "Transferring a vesting position recalculates releaseRate inconsistently, leading to token loss."

### 3. The Junior/Senior Agent Model

- **Junior (Agent)**:
  - Navigates the graph & selects code slices.
  - Annotates nodes with observations ("This function updates `totalAssets`").
  - Escalates questions when stuck.
- **Senior (Guidance)**:
  - periodically reviews Junior's work.
  - **Owns vulnerability hypothesis generation**.
  - Proposes high-quality hypotheses based on contradictions in the graph.

## 🛠️ Execution Workflow

### Phase 1: Knowledge Graph Construction

Before hunting bugs, build the maps.

1. **System Architecture Graph**: High-level component view.
2. **Aspect Graphs**: Custom views for specific concerns (e.g., "Vesting Position Management", "Authorization Roles").

### Phase 2: Exploration & Annotation (The "Junior" Role)

- **Investigate**: Pick a graph (e.g., Authorization).
- **Annotate**: Attach observations to nodes.
  - _Invariant_: "Step duration must divide total duration cleanly."
  - _Assumption_: "Oracles never return 0."
- **Contradiction Hunting**: When an observation conflicts with an invariant (e.g., a path that violates "releaseRate is stable"), a bug is likely hiding there.

### Phase 3: Hypothesis Formation (The "Senior" Role)

- Review the annotated graph.
- Formulate a **Hypothesis**:
  - **Root Cause**: What logic is broken?
  - **Attack Vector**: How to trigger it?
  - **Impact**: What happens?
  - **Code References**: Exact lines.
- **Confidence Rating**: distinct from annotations.

### Phase 4: Quality Assurance

- **Filter**: Remove out-of-scope (gas, admin powers).
- **Verify**: Does the code, as written, expose an exploitable path?
  - _Proof_: Visible attack path.
  - _Rejection_: Effective guard detected.

## 💡 Practical Prompts

### "Mental Map" Construction

```
Help me build a mental map of [Component/Flow].
Do not explain code in isolation.
Identify:
1. Actors & Goals
2. Primary Money Flows (Step-by-step)
3. Contract Orchestration (Roles & "Why")
4. State Progression (Before -> After)
5. External Assumptions
```

### Invariant Annotation

```
Analyze this slice for invariants related to [Topic, e.g., Vesting].
Note any:
- Mathematical relationships (e.g., rate = amt/time)
- State consistency rules
- Access control assumptions
Annotate the code with these observations.
```

### Hypothesis Generation

```
Review the annotations and code for [Component].
Look for contradictions between:
- The stated invariant "X"
- The implementation of path "Y"
Propose a falsifiable vulnerability hypothesis if a conflict exists.
```
