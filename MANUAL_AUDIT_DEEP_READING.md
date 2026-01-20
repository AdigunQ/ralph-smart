# Deep Reading Manual Audit

> **Philosophy**: Read code like a human auditor. Line by line. Character by character. No shortcuts.

This is not about checklists or pattern matching. It's about **understanding**.

---

## The Mindset

Forget automation. Forget "vulnerability patterns".

You are sitting with a cup of coffee, reading someone else's code as if your reputation depends on understanding every single line. Because it does.

**What matters:**

- How data is born (initialization)
- How data changes (state updates)
- How data is structured (structs, maps, variables)
- How components talk to each other (interfaces, calls)

---

## The Skeptic's Lens

**Be wary of everything. Even when it looks correct.**

The most dangerous bugs are in code that "obviously works". The developer was confident. The tests pass. It looks fine.

But you are not here to confirm it works. You are here to find where it doesn't.

### The Inquisitive Mindset

For **every line**, ask:

- _"Why is it done this way?"_
- _"What assumption is the developer making here?"_
- _"What if that assumption is wrong?"_

Even for simple operations:

```solidity
balance += amount;
```

Ask:

- Why `+=` and not `=`?
- Could `balance` already have a value we don't expect?
- Could `amount` be manipulated before this line?
- Is this the right `balance`? (storage vs memory? which mapping key?)

### Never Trust "Obvious" Code

```solidity
require(msg.sender == owner, "Not owner");
```

This looks correct. But ask:

- How is `owner` set? Can it be changed?
- Could `owner` be address(0)?
- Is there another path that bypasses this check?
- Could someone front-run the owner to become the owner?

### Question Every Action

| Code Pattern    | Inquisitive Questions                           |
| --------------- | ----------------------------------------------- |
| `a = b`         | Is `b` validated? Could it be stale?            |
| `if (x > y)`    | Should it be `>=`? What if `x == y`?            |
| `call external` | Could it revert? Reenter? Return false?         |
| `emit Event`    | Does the event match the actual state change?   |
| `return value`  | Is this the right value? What about edge cases? |

### The Uncomfortable Truth

Most code you read will be correct. But you must treat every line as suspect until proven otherwise.

The bug finder's paradox:

> _"You must believe the code is broken to find the break, but most code isn't broken."_

Stay paranoid. Stay inquisitive.

---

## Targeted Hunting

**Don't dive into a random line of code and hope for the best.**

### Step 1: List Every Entry Point

Before reading any function body, enumerate every way a user can interact with the system:

- Every `external` function
- Every `public` function
- Every callback or hook
- Every receive/fallback handler

Write them down. This is your attack surface map.

### Step 2: Trace Call Flows Systematically

Go through entry points **one at a time**. For each one:

1. Read the function signature
2. Trace the call flow in your head (or use your note-taking system)
3. Follow every internal function call
4. Track every state change
5. Note every external interaction

Don't jump around. Finish one entry point completely before moving to the next.

### Step 3: Hunt with Purpose

**Don't just read for the sake of it.**

Pick a **target impact** first:

- Stealing funds
- Crashing a node (panic, unhandled exception)
- Griefing other users
- Bypassing access control
- Manipulating prices/oracles

Then pick a **mechanism** to achieve it:

- Integer overflow/underflow
- Reentrancy
- Unvalidated input
- Missing access check
- Logic flaw in state transition

As you dissect each entry point, **hunt specifically for those bugs**.

Example hunting targets:

| Impact          | Mechanism to Hunt                                |
| --------------- | ------------------------------------------------ |
| Drain funds     | Reentrancy, rounding errors, unchecked returns   |
| Crash node      | Panic, infinite loop, out of gas, stack overflow |
| Steal NFT       | Missing ownership check, signature replay        |
| Manipulate vote | Flash loan governance, double voting             |

**Reading with intent finds more bugs than passive reading.**

---

## Phase 1: First Contact

### Read the Entry Point

Open the main contract. Don't scan. **Read**.

Start from line 1. Read every import, every comment, every pragma.

Ask yourself:

- What is this contract trying to do?
- Who is supposed to call it?
- What external things does it depend on?

**Don't move on until you can explain the contract's purpose in one sentence.**

---

## Phase 2: The Data Layer

This is where bugs hide.

### Step 1: Find All State Variables

Read every `storage` variable, every `mapping`, every `struct`.

For each one, ask:

- What does this represent in the real world?
- Who can modify it?
- What would happen if it was wrong?

Write it down. Actually write it down.

```
Example:
- `totalSupply` (uint256): Total tokens in existence
  - Modified by: mint(), burn()
  - If wrong: Users could have tokens that don't exist, or lose tokens that do

- `balances` (mapping address => uint256): How many tokens each user has
  - Modified by: transfer(), mint(), burn()
  - If wrong: Theft, loss of funds
```

### Step 2: Trace Initialization

Find the constructor or `initialize` function.

Read it line by line. For each state variable being set:

- Is it being set to a sane default?
- Could it be set to zero or empty when it shouldn't be?
- Could the initializer be called twice?

**The moment of birth is the most vulnerable moment.**

### Step 3: Understand Structs

Structs are how developers think about data. Read every struct definition.

For each field:

- What's the type?
- What are the limits? (uint8 vs uint256 matters)
- Is there implicit ordering or packing?
- Could any field be zero when it shouldn't be?

---

## Phase 3: The Interface Layer

### Step 1: External Functions

These are the attack surface. List every `external` and `public` function.

For each one, read the entire function body. Not the signature. The body.

Ask:

- What can an attacker pass in?
- What happens if they pass zero? Max value? Negative (if signed)?
- What state changes happen?
- Are there any external calls?

### Step 2: Internal Functions

These often contain the real logic. Don't skip them because they're "internal".

Trace how data flows from external → internal.

---

## Phase 4: State Transitions

This is the heart of the audit.

### The Question

For every function that modifies state, ask:

**"What must be true before this runs, and what will be true after?"**

This is not a formal invariant check. It's thinking.

Example:

```
function withdraw(uint amount) {
    // BEFORE: balances[msg.sender] >= amount
    // BEFORE: address(this).balance >= amount

    balances[msg.sender] -= amount;

    // AFTER: balances[msg.sender] decreased by amount

    payable(msg.sender).transfer(amount);

    // AFTER: msg.sender received amount ETH
    // AFTER: contract balance decreased by amount
}
```

Now... what if the external call fails? What if it reenters? What if `amount` is zero?

### The Order

State changes have an order. Read them in order.

- What happens first?
- What happens last?
- Could an attacker exploit the moment between two state changes?

---

## Phase 5: The Slow Read

Pick the most critical function. The one that moves money.

Now read it again. Slower.

**Character by character.**

Look at:

- Every operator (`+`, `-`, `*`, `/`, `%`)
- Every comparison (`<`, `>`, `<=`, `>=`, `==`, `!=`)
- Every assignment (`=`, `+=`, `-=`)

For arithmetic:

- Could it overflow?
- Could it underflow?
- Could it divide by zero?
- Is there precision loss?

For comparisons:

- Is it `<` when it should be `<=`?
- Is it checking the right variable?
- Could the check be bypassed with a specific value?

---

## Phase 6: The Uncomfortable Questions

After you understand the code, ask:

1. **What if I'm a malicious user?**

   - How would I steal funds?
   - How would I grief other users?
   - How would I break the protocol?

2. **What if I'm a malicious admin?**

   - What damage could I do?
   - Are there any unchecked admin powers?

3. **What if external dependencies fail?**

   - Oracle returns zero?
   - External contract reverts?
   - Token doesn't follow ERC20?

4. **What if time behaves strangely?**
   - Block timestamp manipulation?
   - Flash loan in same transaction?
   - Front-running?

---

## Building the Mental Map

Have you ever felt like you understand each contract, but you can't make the bigger picture? You can't see where the money flows, or you don't understand the whole purpose of this protocol?

Worry not. Here is a prompt that will help you build a mental map of the whole protocol in your head so you can remember it easily. 🫡

### The Mental Map Prompt

Use this with your LLM to get a complete end-to-end understanding:

```
Help me build a complete mental map of this protocol so I can visualize it end-to-end.

Do NOT explain contracts in isolation.
Explain the protocol in terms of flows.

Structure the explanation as follows:

1. Actors:
   - Who are the main actors? (users, admins, keepers, bots, external protocols)
   - What each actor is trying to achieve

2. Primary user flows (money-first):
   - Describe the main things a user can do, in chronological order
   - For each flow, follow the user's funds step by step:
     - Where the money starts
     - Which contracts it passes through
     - Where it ends up
     - Who controls it at each step

3. Contract orchestration:
   - For each flow, list which contracts participate
   - Describe each contract's role using one sentence only
   - Emphasize *why* the contract exists in the flow

4. State progression:
   - What high-level protocol state changes as flows execute?
   - How the protocol moves from "before user action" to "after user action"

5. External integrations:
   - Identify all external systems (DEXs, oracles, automation, bridges, ERC standards)
   - Explain:
     - Why the protocol depends on them
     - When they are invoked
     - What assumptions are made about them

6. Full protocol walkthrough:
   - Narrate a complete, realistic scenario:
     - User enters the protocol
     - Uses its core functionality
     - Money moves
     - External systems interact
     - Protocol reaches a stable end state

Focus on helping me *run the protocol in my head* with my eyes closed.
```

### When to Use This

- **Before starting deep reading**: Get the big picture first
- **When you feel lost**: Reset your understanding
- **After reading all contracts**: Verify your mental model is correct
- **Before hunting for bugs**: Know where the money is

---

## Incorporating the Hound Methodology (Research Grade)

While deep reading is about the "how" (line-by-line), the **Hound Methodology** (arXiv:2510.09633v1) gives you the "what" (modeling the system).

### 1. Build "Relation-First Graphs"

Human experts don't view code linearly. They build multiple, overlaying mental maps.
Create these specific graphs in your notes:

| Graph                  | Focus                                                                        |
| ---------------------- | ---------------------------------------------------------------------------- |
| **AssetAndFeeFlows**   | Follow the money. Token movements during listing, purchase, vesting, claims. |
| **AuthorizationRoles** | Who can call what? (Owner, Admin, User, Keeper).                             |
| **StateMutationMap**   | Key storage variables and who mutates them.                                  |
| **SystemArchitecture** | High-level component interactions.                                           |

> **Goal**: Enable "Exact Retrieval". When testing a function, look at these graphs to know _exactly_ which other components matter.

### 2. The Agentic Roles Technique

Split your brain into three distinct modes:

**The Scout (Junior / Explorer)**

- **Goal**: Map the territory.
- **Action**: Read code line-by-line.
- **Output**: Annotations (Observations & Assumptions).
- _"Observation: This function updates `releaseRate`."_

**The Strategist (Senior / Planner)**

- **Goal**: Find the bugs.
- **Action**: Review Scout's notes for **Contradictions**.
- **Output**: **Focused Hypotheses**.
- _"Hypothesis (High Confidence): If I transfer 1 wei, rate rounds to 0."_

**The Finalizer (QA)**

- **Goal**: Prove it.
- **Action**: Write the PoC.
- **Output**: CONFIRMED or REJECTED verdict.

### 3. Persistent Belief System

Treat your hypotheses as long-lived objects, not fleeting thoughts.
Track `Confidence (q)` from 0.0 to 1.0.

1. **Propose**: "I think reentrancy is possible here." ($q=0.2$)
2. **Investigate**: "Found a call before state update." ($q=0.6$)
3. **Confirm**: "PoC crashes the contract." ($q=1.0$)

When you see code that contradicts a belief... **THAT is a bug**.

---

## 4. Mathematical Thinking (Get Math-Pilled)

For complex DeFi (AMMs, Lending, Perps), code reading is not enough. You need **Math**.

> "If you want to see the matrix, you need to get math-pilled." — Bernhard Mueller

**Reference**: `knowledges/security_math_primer.md`

### When to use Math vs Code?

| Scenario              | Tool                | Technique                                                                          |
| --------------------- | ------------------- | ---------------------------------------------------------------------------------- |
| **AMM Invariant**     | Excel / Spreadsheet | **Linearize it**: Transform $x \cdot y = k$ using logs into linear equations.      |
| **Lending Solvency**  | Matrix Operations   | **Matrix Inequality**: $C \cdot (P \cdot p) \ge m$. Check if rounding accumulates. |
| **ZK Circuits**       | Linear Algebra      | **R1CS**: Verify constraint matrices.                                              |
| **Symmetry Breaking** | Group Theory        | **Homomorphisms**: Does $Commit(A) + Commit(B) = Commit(A+B)$ hold?                |

**Actionable Advice**:

- If you see `x * y` or `x / y` in a loop or invariant check -> **Open a Spreadsheet**.
- Don't guess if the math holds. **Prove it**.

---

## Timeline

A proper deep read of 1000 lines of code takes **4-8 hours**.

If you're going faster than that, you're not reading deeply enough.

---

## Summary

1. **Read**, don't scan
2. **Understand** data structures first
3. **Trace** initialization carefully
4. **Question** every state change
5. **Slow down** on critical functions
6. **Ask** uncomfortable questions

No checklists. No automation. Just you and the code.

---

_"The bug is always in the line you didn't read carefully."_
