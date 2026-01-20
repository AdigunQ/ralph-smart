# False Positive Prevention Protocol

> **Core Directive**: "It is better to miss a bug than to report a hallucination. A finding without proof is just a noise."

Minimizing false positives is critical for credibility. This protocol defines the gates every hypothesis must pass before being reported.

## 1. The Confidence Threshold Protocol

Every hypothesis carries a `Confidence Score (q)` from 0.0 to 1.0.

| Score         | Meaning                   | Action                                               |
| ------------- | ------------------------- | ---------------------------------------------------- |
| **0.0 - 0.3** | **Guess / Hallucination** | **discard** immediately. Do not log.                 |
| **0.3 - 0.7** | **Suspicion w/o Proof**   | **investigate**. Scout loads code. No reporting yet. |
| **0.7 - 0.9** | **Strong Logical Case**   | **verify**. Proof of Concept required.               |
| **0.9 - 1.0** | **Proven Exploit**        | **report**. Code exists that demonstrates the bug.   |

**Rule**: The system shall NEVER report a finding with $q < 0.8$ as a "Vulnerability". It may only be listed as "Areas for Review".

## 2. The PoC Gate (The Hard Filter)

**No PoC, No Finding.**

For High/Critical severity issues, a running code snippet is mandatory.
If the agent cannot write a test case that fails, the finding is downgraded or rejected.

### The "Hermetic Test" Requirement

The agent must be able to generate a standalone test (Foundry/Python) that:

1. Sets up the state.
2. Triggers the action.
3. Asserts the failure (e.g., `assert(balance > expected)`).

If the test passes (i.e., no bug found), the hypothesis is auto-refuted.

## 3. The Skeptic/Prover Dialectic

Use the **Junior/Senior** architecture to self-correct.

1.  **Junior (Scout)** proposes 10 potential issues.
    - _"Possible reentrancy in `withdraw`?"_
    - _"Unchecked return value?"_
2.  **Senior (Strategist)** acts as the **Filter**.
    - _Check_: "Is there a reentrancy guard? Yes. -> Reject."
    - _Check_: "Does the return value matter? No, it reverts on failure. -> Reject."

**Prompt for the Senior Agent**:

> "You are a hostile senior auditor. Your job is to prove the Junior wrong. Review this hypothesis. Find one reason why the code is actually SAFE. If you find a defense, REJECT the hypothesis."

## 4. Double-Check Constraints (Mathematical Proof)

For logic/math bugs, use the SMT/Symbolic logic check:

1.  Define the Invariant: `balance <= totalSupply`
2.  Assume the Hypothesis: `balance > totalSupply`
3.  Is there a path?

If the "path" requires impossible conditions (e.g., `msg.sender == address(0)` but `msg.sender` is real), reject it.

## 5. The "Negative Evidence" Ledger

Keep track of what failed.

- "Tried reentrancy on `withdraw` -> Failed (Guard exists)."
- "Tried overflow on `mint` -> Failed (Solidity 0.8+)."

**Do not re-propose refuted hypotheses.**

## Summary Checklist

Before hitting "Report":

- [ ] Is `Confidence > 0.8`?
- [ ] Is there a localized code slice proving it?
- [ ] Did the "Hostile Senior" fail to debunk it?
- [ ] (Bonus) Is there a PoC?

**"Silence is better than Noise."**
