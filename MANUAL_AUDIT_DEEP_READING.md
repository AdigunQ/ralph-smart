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

## How to Document

Don't write a formal report while reading. Just note:

```
Line 142: Unchecked arithmetic on user input. Could overflow?
Line 256: External call before state update. Reentrancy?
Line 301: Balance check uses < instead of <=. Off-by-one?
```

Review your notes later. Many will be false alarms. Some won't.

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
