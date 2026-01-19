# Boundary Taint Model (BND)

## Definition

Focus on **edge cases** and **boundary conditions**: zero values, maximum values, empty arrays, first/last elements, overflow/underflow.

## Core Question

> "What happens when inputs are at their extremes? Zero? Maximum? Empty? Overflowed?"

## Taint Framework

| Component     | Description                                                                  |
| ------------- | ---------------------------------------------------------------------------- |
| **SOURCE**    | User-controlled numbers, array lengths, loop bounds, timestamps              |
| **SINK**      | Division by zero, overflow/underflow, array bounds violation, gas exhaustion |
| **SANITIZER** | Bounds checks, SafeMath, array length validation, gas limit considerations   |

## Critical Boundaries to Test

### 1. Zero Values

```solidity
function transfer(uint amount) external {
    uint fee = amount / 100;  // If amount < 100, fee = 0
    // ❌ Can bypass minimum fee requirement
}

function setPrice(uint price) external {
    // ❌ Missing: require(price > 0)
    pricePerToken = price;  // Now division by zero possible elsewhere
}
```

**Test**: What if `amount = 0`? Can fees be bypassed?

### 2. Maximum Values

```solidity
function mint(uint amount) external {
    totalSupply += amount;  // ❌ Can overflow if totalSupply + amount > type(uint256).max
}

unchecked {
    balances[user] = balances[user] - amount;  // ❌ Can underflow
}
```

**Test**: What if `amount = type(uint256).max`?

### 3. Empty Arrays

```solidity
function distribute(address[] memory users) external {
    for (uint i = 0; i < users.length; i++) {
        // Logic here
    }
    // ❌ If users.length == 0, loop never runs - is that OK?
}
```

**Test**: Does empty array bypass required initialization?

### 4. Array Length Attacks

```solidity
function batchTransfer(address[] memory recipients, uint[] memory amounts) external {
    // ❌ No gas limit consideration
    for (uint i = 0; i < recipients.length; i++) {
        transfer(recipients[i], amounts[i]);
    }
}
```

**Test**: What if array has 10,000 elements? DoS via gas exhaustion?

## Detection (Reverse Scan)

Assert boundary violations exist:

- "Zero amounts CAN bypass fee calculations"
- "MAX_UINT additions CAN cause overflow"
- "Empty arrays CAN bypass validation logic"
- "Large arrays CAN DoS the contract"

## Common Boundary Values to Test

```solidity
// Numbers
0
1
type(uint256).max
type(uint256).max - 1
type(int256).min
type(int256).max

// Arrays
[]                  // Empty
[single element]
[MAX_LENGTH array]  // Gas limit test

// Strings/Bytes
""                  // Empty string
Very long string    // Gas limit

// Addresses
address(0)
address(this)
```

## Checklist

- [ ] All arithmetic operations checked for overflow/underflow
- [ ] All divisions checked for zero denominator
- [ ] All array access checked for bounds
- [ ] All loops checked for gas limits
- [ ] All zero-value inputs tested
- [ ] All maximum-value inputs tested
