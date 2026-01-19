# Expression Taint Model (EXP)

## Definition

Focus on **specific dangerous code expressions**: external calls, delegatecalls, arithmetic, type casts, array access. Each expression is a potential vulnerability anchor.

## Core Question

> "Is this expression protected by sufficient sanitizers, or can attacker-controlled data reach it unsafely?"

## Taint Framework

| Component     | Description                                                                              |
| ------------- | ---------------------------------------------------------------------------------------- |
| **SOURCE**    | User parameters, external contract returns, storage variables influenced by users        |
| **SINK**      | The expression itself: `.call()`, `delegatecall()`, division, array access, `transfer()` |
| **SANITIZER** | Reentrancy guards, access control, input validation, return value checks, bounds checks  |

## Dangerous Expression Patterns

### 1. External Calls & Reentrancy

```solidity
// SINK: External call with state update after
(bool success, ) = msg.sender.call{value: amount}("");
balances[msg.sender] -= amount;  // ❌ State updated AFTER call
```

**Check for**:

- Reentrancy guard (`nonReentrant`)
- Checks-Effects-Interactions pattern followed
- State updated before external call

### 2. Delegatecall

```solidity
// SINK: Delegatecall to user-controlled address
target.delegatecall(data);  // ❌ User controls 'target'?
```

**Check for**:

- Whitelist of allowed targets
- Admin-only access
- Storage layout conflicts

### 3. Division / Modulo

```solidity
// SINK: Division by user input
uint reward = totalRewards / userSuppliedDenominator;  // ❌ Can be zero
```

**Check for**:

- Zero checks before division
- Precision loss handling
- Rounding direction (favor protocol)

### 4. Array Access

```solidity
// SINK: Unbounded array access
uint value = data[userIndex];  // ❌ Index validated?
```

**Check for**:

- Bounds checking (`require(index < array.length)`)
- DoS via gas limits on large arrays

### 5. Unchecked Arithmetic

```solidity
// SINK: Overflow/underflow
unchecked {
    balance = balance - userAmount;  // ❌ Can underflow
}
```

## Detection (Reverse Scan)

For each dangerous expression:

1. Assert: "This call/operation IS vulnerable"
2. Trace back: Can attacker control inputs?
3. Check forward: Are there adequate sanitizers?

Example:

- Find all `.call()` → Assert each is vulnerable to reentrancy
- Find all divisions → Assert each can divide by zero
- Find all `delegatecall` → Assert each can be exploited

## Common Sinks to Search

```solidity
// Search for these patterns:
.call(              // External calls
.delegatecall(      // Delegatecalls
transfer(           // Token transfers (reentrancy)
[                   // Array access
/ or %              // Division/modulo
unchecked {         // Unchecked arithmetic
abi.encodePacked(   // Hash collision (with dynamic types)
blockhash(          // Predictable randomness
```
