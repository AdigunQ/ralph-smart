# Composition Taint Model (CMP)

## Definition

Focus on **combinations of operations** that seem safe individually but create vulnerabilities when combined. The whole is more dangerous than the parts.

## Core Question

> "What happens when we combine operation A with operation B, or execute them in a specific order within the same transaction?"

## Taint Framework

| Component     | Description                                                                               |
| ------------- | ----------------------------------------------------------------------------------------- |
| **SOURCE**    | Multi-step transactions, flash loans + normal ops, inheritance chains, callback sequences |
| **SINK**      | Unexpected state from combination (price manipulation, privilege escalation, reentrancy)  |
| **SANITIZER** | Atomicity guarantees, pre/post-condition checks, execution order constraints              |

## Classic Composition Attacks

### 1. Flash Loan + Price Manipulation

```solidity
// Step 1: Flash loan huge amount
flashLoan(10000 ETH)
// Step 2: Swap in DEX (manipulates price)
dex.swap(10000 ETH → USDC)
// Step 3: Exploit manipulated oracle price
lending.borrow(using_manipulated_price)
// Step 4: Repay flash loan
repayFlashLoan()
```

**Pattern**: Borrow → Manipulate → Exploit → Repay (all in one transaction)

### 2. Approval + TransferFrom Reentrancy

```solidity
// User approves contract
token.approve(contract, 100)

// Contract's function with reentrancy:
function process() external {
    token.transferFrom(msg.sender, address(this), 100);
    // ❌ External call here allows reentrancy
    msg.sender.call("");
    // Attacker re-enters and calls transferFrom again with same approval
}
```

### 3. Multiple Inheritance Shadowing

```solidity
contract A {
    function withdraw() public onlyOwner { }
}

contract B {
    function withdraw() public { }  // ❌ No access control
}

contract C is A, B {
    // Which withdraw() is used? B's version (no access control!)
}
```

## Detection (Reverse Scan)

Assert complex attacks exist:

- "Flash loans CAN manipulate oracle prices for profit"
- "Multiple contracts CAN be composed to bypass access control"
- "Reentrancy CAN drain funds when combined with approval pattern"
- "Inheritance CAN shadow secure functions with insecure ones"

## Combinations to Test

**Flash Loan + ...**

- Price oracle manipulation
- Governance vote weight
- Liquidity pool draining

**Reentrancy + ...**

- Approval mechanisms
- Callback patterns
- State updates after external calls

**Multi-Contract + ...**

- Circular dependencies
- Proxy patterns
- Delegatecall chains
