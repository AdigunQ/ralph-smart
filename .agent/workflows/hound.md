---
description: Generate Research-Grade Hound "Mental Maps" for the target
---

# /hound Methodology

This workflow activates the "Deep Reasoning" mode to map the system architecture.

1.  **Scout Phase (Map the Territory)**
    The goal is to generate the 4 key graphs.

    **Prompt to Agent**:

    > "Act as the Scout. Read the codebase in `target/`. Generate the following Relation-First Graphs in `findings/hound_graphs.md`:
    >
    > 1. **SystemArchitecture**: Components & Interfaces.
    > 2. **AssetAndFeeFlows**: Token movements.
    > 3. **AuthorizationRoles**: Access control.
    > 4. **StateMutationMap**: Who modifies what storage."

2.  **Strategist Phase (Find Contradictions)**
    After the graphs are built:

    **Prompt to Agent**:

    > "Act as the Strategist. Review `findings/hound_graphs.md`.
    > Identify 3 key Contradictions or High-Risk Areas.
    > For each, propose a 'Persistent Belief' hypothesis with a Confidence Score ($q$)."

3.  **Output**:
    - `findings/hound_graphs.md`
    - `findings/hypotheses.md`
