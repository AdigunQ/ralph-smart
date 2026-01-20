---
description: Run Mutation Testing on a Proof of Concept to prevent False Positives
---

# /verify (Mutation Test)

This workflow validates a specific PoC by attempting to disprove it (The Skeptic Protocol).

1.  **Prerequisites**:

    - Identify the passing PoC test file (e.g., `test/Exploit.t.sol`).
    - Identify the target contract file.

2.  **Mutation Step 1: Fix the Bug**
    **Instruction**:
    "Go to the target contract. Apply a fix that should prevent the exploit. Run the PoC test."

    - **Expected Result**: The test should **PASS** (exploit fails).
    - _If the test still FAILS (exploit works despite fix), the PoC is invalid/testing the wrong thing._

3.  **Mutation Step 2: Break the Assertion**
    **Instruction**:
    "Revert the code fix. Go to the PoC test. Change the final assertion/condition to something easy (e.g., `assert(true)`)."

    - **Expected Result**: The test should **PASS**.
    - _If it fails, the test setup is broken._

4.  **Final Verdict**:
    - If both mutations behave as expected -> **CONFIRMED**.
    - Otherwise -> **FALSE POSITIVE**.
