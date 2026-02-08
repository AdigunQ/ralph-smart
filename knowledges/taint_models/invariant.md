# Invariant Taint Model (INV)

## Definition

**Invariants** are data relationships that MUST hold true in any logically valid system state. If an invariant is violated, the system's data integrity is compromised, potentially leading to theft, insolvency, or complete protocol failure.

## Core Question

> "Can any operation cause a state where critical data relationships break?"

## The Verification Harness for Invariants

### Step 1: Identify Invariants

For each contract, document the invariants that should hold:

```markdown
## Contract: Token.sol

| Invariant ID | Relationship | Criticality |
|--------------|--------------|-------------|
| INV-001 | totalSupply == Σ(balances[user]) | CRITICAL |
| INV-002 | address(this).balance >= totalDeposits | CRITICAL |
| INV-003 | allowance[owner][spender] <= balances[owner] | HIGH |
```

### Step 2: Map State Modifiers

For each invariant, identify all functions that modify involved state:

```markdown
## INV-001: totalSupply == Σ(balances)

**Variables**:
- `totalSupply`: uint256, modified by mint/burn
- `balances[address]`: mapping, modified by mint/burn/transfer

**Modifying Functions**:
| Function | Modifies | Line | Atomic with? |
|----------|----------|------|--------------|
| mint() | totalSupply++, balances[to]++ | 45-48 | Yes ✓ |
| burn() | totalSupply--, balances[from]-- | 52-55 | Yes ✓ |
| transfer() | balances[from]--, balances[to]++ | 60-63 | Yes ✓ |
| adminSetBalance() | balances[user] only | 78 | No ✗ |
```

### Step 3: Find Violations

```solidity
// VIOLATION: adminSetBalance breaks INV-001
function adminSetBalance(address user, uint256 amount) external onlyAdmin {
    balances[user] = amount;  // Only modifies balances, not totalSupply!
    // Missing: Synchronize totalSupply
}
```

### Step 4: Prove Exploitability

```solidity
// PoC for INV-001 violation
function test_InflationAttack() public {
    // Initial state
    token.mint(user1, 1000 ether);
    assertEq(token.totalSupply(), 1000 ether);
    assertEq(token.balanceOf(user1), 1000 ether);
    
    // Admin directly sets balance (breaks invariant)
    vm.prank(admin);
    token.adminSetBalance(user1, 2000 ether);
    
    // Invariant broken
    assertEq(token.totalSupply(), 1000 ether);  // Unchanged
    assertEq(token.balanceOf(user1), 2000 ether);  // Changed!
    
    // Impact: User can now withdraw more than they should
    vm.prank(user1);
    token.transfer(attacker, 1500 ether);  // More than totalSupply!
}
```

### Step 5: Quantify Impact

- **Scope**: All token holders
- **Maximum Loss**: Unlimited (can inflate arbitrarily)
- **Attack Cost**: Zero (if admin is compromised or function lacks access control)
- **Severity**: CRITICAL

### Step 6: Report and Remediate

```solidity
// REMEDIATION: Remove direct balance setting or synchronize
function adminSetBalance(address user, uint256 newAmount) external onlyAdmin {
    uint256 oldAmount = balances[user];
    balances[user] = newAmount;
    
    // Synchronize totalSupply
    if (newAmount > oldAmount) {
        totalSupply += (newAmount - oldAmount);
    } else {
        totalSupply -= (oldAmount - newAmount);
    }
    
    // Or simply emit event for off-chain tracking
    emit BalanceAdjusted(user, oldAmount, newAmount);
}
```

## Taint Framework

### SOURCE

Operations that modify state variables involved in invariants:

```solidity
// Sources for INV-001 (totalSupply/balances)
function mint(address to, uint256 amount) {
    totalSupply += amount;        // SOURCE
    balances[to] += amount;       // SOURCE
}

function transfer(address to, uint256 amount) {
    balances[msg.sender] -= amount;  // SOURCE
    balances[to] += amount;          // SOURCE
}

// External sources (oracle updates, etc.)
function updatePrice(uint256 newPrice) {
    price = newPrice;  // SOURCE for price-related invariants
}
```

### SINK

Invariant violation detected when:

```solidity
// SINK: totalSupply != sum(balances)
totalSupply != sum(all balances)

// SINK: Pool insolvency
poolTokenBalance < totalDeposits

// SINK: Negative collateral
collateralValue < debtValue * collateralRatio
```

### SANITIZER

Checks that prevent invariant violations:

```solidity
// Automatic sanitizers (design-level)
function mint(address to, uint256 amount) {
    // Atomic update ensures both change together
    _totalSupply += amount;
    _balances[to] += amount;
}

// Explicit sanitizers (require statements)
function withdraw(uint256 amount) external {
    uint256 newBalance = balances[msg.sender] - amount;
    require(newBalance >= 0, "Underflow");  // SANITIZER
    balances[msg.sender] = newBalance;
}

// Post-condition sanitizers
function complexOperation() external {
    uint256 totalSupplyBefore = totalSupply;
    
    // ... complex logic ...
    
    // Post-condition check
    require(totalSupply == totalSupplyBefore, "Supply changed");  // SANITIZER
}
```

## Common Invariants by Contract Type

### ERC20 Tokens

```solidity
// INV-001: Supply conservation
assert(totalSupply == Σ(balances[user]));

// INV-002: Allowance bound
assert(allowance[owner][spender] <= balances[owner]);

// INV-003: Balance non-negative
assert(balances[user] >= 0);
```

### Lending Protocols

```solidity
// INV-101: Solvency
assert(totalDeposits >= totalBorrows);

// INV-102: Collateralization
assert(userCollateral[user] * price >= userDebt[user] * collateralRatio);

// INV-103: Interest consistency
assert(totalDebt == Σ(userDebt[user]));

// INV-104: Reserve ratio
assert(liquidityReserves >= totalDeposits * reserveRatio);
```

### AMM/DEX (Constant Product)

```solidity
// INV-201: K invariant (within rounding)
assert(reserveX * reserveY >= k * 0.9999);

// INV-202: Reserve backing
assert(token.balanceOf(pool) >= reserveX);
```

### Staking/Vaults

```solidity
// INV-301: Share backing
assert(totalShares * sharePrice == totalAssets);

// INV-302: Share conservation
assert(totalShares == Σ(userShares[user]));

// INV-303: Reward pool sufficiency
assert(rewardToken.balanceOf(contract) >= totalPendingRewards);
```

### Governance

```solidity
// INV-401: Vote integrity
assert(totalVotes == Σ(userVotes[user]));

// INV-402: Proposal state machine
assert(proposal.state in [Pending, Active, Canceled, Defeated, Succeeded, Executed]);

// INV-403: Quorum
assert(executedProposal.forVotes >= quorum);
```

## Detection Strategy

### Automated Detection (CodeQL)

```ql
// Find functions that modify one variable but not related ones
from Function f, StateVariable v1, StateVariable v2
where
  f.modifies(v1) and
  not f.modifies(v2) and
  invariantInvolves(v1, v2)
select f, "Function modifies one invariant variable but not the other"
```

### Manual Review Checklist

For each state variable, ask:
1. What invariants involve this variable?
2. What functions modify this variable?
3. Do all modifying functions preserve the invariant?
4. Are updates atomic (both sides together)?
5. Can partial updates occur (reentrancy, exceptions)?

### Reverse Scan (Assertive)

> "There EXISTS a function that breaks invariant X. Find it."

Generate hypotheses:
- "Function Y modifies A but not B"
- "Function Y can be interrupted between A and B updates"
- "External call allows reentrancy between updates"
- "Exception in middle leaves partial update"

## False Positive Patterns

### Temporary Violations (OK)

```solidity
// Uniswap V2: K temporarily decreases during swap
function swap(uint amount0Out, uint amount1Out, ...) {
    // ... calculate amounts ...
    
    // Transfer out (K decreases)
    _safeTransfer(_token0, to, amount0Out);
    _safeTransfer(_token1, to, amount1Out);
    
    // Transfer in (K increases)
    uint balance0Adjusted = balance0 * 1000 - amount0In * 3;
    uint balance1Adjusted = balance1 * 1000 - amount1In * 3;
    
    // Invariant checked at end
    require(balance0Adjusted * balance1Adjusted >= k * 1000^2);
}
```

**Rule**: Check invariants at transaction boundaries, not mid-execution.

### Rounding Errors (OK if bounded)

```solidity
// Staking rewards: totalRewards != sum(userRewards) by dust amounts
// OK if difference < 1e9 (negligible)
```

**Rule**: Check if deviation is bounded and economically insignificant.

## Validation Checklist

When you find a potential invariant violation:

- [ ] **Existence**: Does the code actually modify the claimed variables?
- [ ] **Attacker Control**: Can an external caller trigger this path?
- [ ] **Impact**: What's the maximum deviation possible?
- [ ] **Corrective Mechanism**: Is there rebalancing elsewhere?
- [ ] **Exploitability**: Can this be used for profit or DoS?
- [ ] **Atomicity**: Can partial updates occur?

## Real-World Examples

### Example 1: Compound Fork (Inflation Attack)

```solidity
// Vulnerable: Direct balance modification
function _setAccountBalance(address account, uint256 balance) external {
    accountBalances[account] = balance;  // Breaks total supply invariant
}
```

**Impact**: Attacker inflated balances, withdrew more than deposited.

### Example 2: Lending Protocol (Solvency Break)

```solidity
// Vulnerable: Liquidation doesn't reduce total debt
function liquidate(address borrower) external {
    uint256 debt = userDebt[borrower];
    userDebt[borrower] = 0;  // User debt cleared
    // Missing: totalDebt -= debt
}
```

**Impact**: totalDebt > sum(userDebt), protocol insolvency.

### Example 3: Vault (Share Price Manipulation)

```solidity
// Vulnerable: Donation attack inflates share price
function deposit() external payable {
    uint256 shares = msg.value * totalShares / address(this).balance;
    // Attacker donates ETH first, inflating balance, reducing shares for victim
}
```

**Impact**: First depositor can steal from subsequent depositors.
