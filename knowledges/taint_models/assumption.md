# Assumption Taint Model (ASM)

## Definition

**Assumptions** are business logic prerequisites developers believe will always hold - but code may not fully enforce. These concern **workflow order, roles, and scenarios** rather than pure data equations.

## Core Question

> "Can an attacker violate the business flow assumptions by executing operations out of order, bypassing prerequisites, or exploiting race conditions?"

## Taint Framework

| Component     | Description                                                                                                      |
| ------------- | ---------------------------------------------------------------------------------------------------------------- |
| **SOURCE**    | External calls, cross-transaction state, time/block conditions, multi-role interactions                          |
| **SINK**      | Dangerous operation executes despite assumption violation (borrow without collateral, withdraw without approval) |
| **SANITIZER** | Access control (`onlyOwner`), state checks (`require(deposited)`), timelocks, multi-sig                          |

## Real-World Examples

### Example 1: Borrow Before Deposit

**Assumption**: "Users must deposit collateral before borrowing"

```solidity
contract LendingPool {
function deposit(uint amount) external {
        userCollateral[msg.sender] += amount;
    }

    function borrow(uint amount) external {
        // ❌ Missing: require(userCollateral[msg.sender] >= amount * collateralRatio)
        token.transfer(msg.sender, amount);
        userDebt[msg.sender] += amount;
    }
}
```

**Attack**: Call `borrow()` directly without depositing → uncollateralized loan

**Fix**: `require(userCollateral[msg.sender] * price >= amount * collateralRatio);`

### Example 2: Timelock Bypass

**Assumption**: "Proposals can only execute after 3-day delay"

```solidity
function executeProposal(uint proposalId) external {
    Proposal storage p = proposals[proposalId];
    // ❌ Missing: require(block.timestamp >= p.createdAt + 3 days)
    p.action.call(p.data);
}
```

## Detection Strategy (Reverse Scan)

Assert assumptions are violated, then find proof:

- "Users CAN borrow without depositing" → find the bypass
- "Proposals CAN execute immediately" → find the path
- "Non-admins CAN call admin functions" → find access control gaps

## Common Assumptions to Test

**Workflow Order**

- Deposit → Borrow → Repay → Withdraw
- Approve → Transfer From
- Initialize → Use → Finalize

**Access Control**

- "Only owner can mint/pause/upgrade"
- "Only whitelisted addresses can participate"
- "Only authorized contracts can callback"

**Time/Sequence**

- "Voting ends before execution"
- "Cooldown enforced between actions"
- "Emergency pause prevents all operations"

**External Dependencies**

- "Oracle price is always fresh"
- "External contract is trusted"
- "Tokens are not malicious"
