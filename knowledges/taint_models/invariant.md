# Invariant Taint Model (INV)

## Definition

**Invariants** are **data relationships** that MUST hold true in any logically valid system state. If an invariant is violated, the system's data integrity is compromised.

## Core Question

> "Can any operation cause a state where critical data relationships break?"

## Taint Framework

### SOURCE

Any operation that **modifies state variables**:

- Token transfers (mint, burn, transfer)
- Balance updates
- Supply adjustments
- Collateral/debt modifications
- Reward distribution

### SINK

**Invariant violation** - when the mathematical relationship breaks:

- `totalSupply != sum(all balances)`
- `totalBorrowed > totalDeposits`
- `userCollateral * price < userDebt * collateralRatio`
- `reserves != actualTokenBalance`
- `sum(shares) != totalShares`

### SANITIZER

**Checks that enforce invariants**:

- `require()` statements validating relationships
- Automatic balancing logic (e.g., mint adjusts both balance AND totalSupply)
- Accounting systems that make violations impossible by design
- Post-condition checks after state changes

## Real-World Examples

### Example 1: Token Supply Mismatch

**Scenario**: Admin can directly modify `balances[user]` without updating `totalSupply`

```solidity
function adminSetBalance(address user, uint256 amount) external onlyAdmin {
    balances[user] = amount;  // ❌ No totalSupply update
}
```

**Taint Path**:

- SOURCE: `adminSetBalance()` modifies `balances[user]`
- SINK: `totalSupply != sum(balances)` invariant broken
- MISSING SANITIZER: No synchronization between balance and supply

**Impact**: System accounting breaks, can lead to inflation/deflation attacks

**Fix**:

```solidity
function adminSetBalance(address user, uint256 amount) external onlyAdmin {
    uint256 oldBalance = balances[user];
    balances[user] = amount;

    if (amount > oldBalance) {
        totalSupply += (amount - oldBalance);  // Mint difference
    } else {
        totalSupply -= (oldBalance - amount);  // Burn difference
    }
}
```

### Example 2: Lending Pool Solvency

**Scenario**: Liquidation doesn't properly update debt and collateral

```solidity
function liquidate(address user) external {
    uint256 collateral = userCollateral[user];
    token.transfer(msg.sender, collateral);  // Send collateral to liquidator
    userCollateral[user] = 0;
    // ❌ Forgot to reduce userDebt[user]
}
```

**Taint Path**:

- SOURCE: `liquidate()` modifies `userCollateral`
- SINK: `sum(userDebt) > sum(userCollateral * collateralRatio)` - system becomes insolvent
- MISSING SANITIZER: Debt not reduced proportionally

**Impact**: Protocol becomes insolvent, can't service all withdrawals

## Detection Strategy

### Forward Scan (Questioning Approach)

"List all state-modifying functions and check if they maintain invariant X"

### Reverse Scan (Assertive Approach)

**Use this for Ralph Building mode!**

> "There EXISTS a function that violates the invariant `totalSupply == sum(balances)`. Find it."

Generate hypotheses:

- "The mint function DOES update totalSupply but NOT user balance"
- "The transfer function DOES update balances but NOT totalSupply"
- "The burn function CAN be called with amount > balance, breaking accounting"

Then validate each hypothesis against the actual code.

## Common Invariants to Check

### Token Contracts

- `totalSupply == sum(all balances)`
- `address(this).balance == internalAccountingBalance`

### Lending/DeFi

- `totalBorrowed <= totalDeposited * utilizationCap`
- `sum(userCollateral * price) >= sum(userDebt * collateralRatio)`
- `lpTokenSupply * pricePerToken == pooledAssetValue`

### Staking/Rewards

- `totalStaked == sum(userStaked)`
- `pendingRewards <= rewardPool`
- `share[user] / totalShares == user's percentage ownership`

### AMM/DEX

- `k = reserveX * reserveY` (constant product)
- `reserveX == actualBalanceX` (no hidden drain)

## False Positive Patterns

❌ **Temporary invariant violation within transaction**  
Example: Uniswap temporarily breaks `k` during swap, but restores it before transaction end.  
→ Check if invariant holds at transaction boundaries, not mid-execution.

❌ **Intentional rounding errors**  
Example: Reward distribution rounds down, causing `totalRewards != sum(userRewards)` by dust amounts.  
→ Check if deviation is bounded and benign.

## Validation Checklist

When you find a potential invariant violation:

- [ ] Does the code actually modify the claimed variables without synchronization?
- [ ] Can the attacker trigger this path?
- [ ] What is the maximum deviation possible? (1 wei vs total drainage)
- [ ] Is there a corrective mechanism elsewhere (e.g., rebalancing function)?
- [ ] Can this be exploited for profit or DoS?
