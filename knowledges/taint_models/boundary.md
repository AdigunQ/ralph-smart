# Boundary Taint Model (BND)

## Definition

Focus on **edge cases** and **boundary conditions**: zero values, maximum values, empty arrays, first/last elements, overflow/underflow. These often bypass validation logic or trigger unexpected behavior.

## Core Question

> "What happens when inputs are at their extremes? Zero? Maximum? Empty? First user? Overflowed?"

## The Verification Harness for Boundary Conditions

### Step 1: Identify Boundary Points

For each function, identify boundary values for all inputs:

```markdown
## Contract: Token.sol - Boundary Analysis

Function: `transfer(address to, uint256 amount)`

| Parameter | Type | Boundary Values to Test |
|-----------|------|------------------------|
| to | address | address(0), address(this), random, contract |
| amount | uint256 | 0, 1, balance-1, balance, balance+1, MAX_UINT |

Function: `mint(address to, uint256 amount)` (onlyOwner)

| Parameter | Type | Boundary Values to Test |
|-----------|------|------------------------|
| to | address | address(0), address(this) |
| amount | uint256 | 0, 1, MAX_UINT - totalSupply, MAX_UINT |

Function: `distribute(address[] recipients, uint256[] amounts)`

| Parameter | Type | Boundary Values to Test |
|-----------|------|------------------------|
| recipients | address[] | [], [single], [max_length] |
| amounts | uint256[] | [], mismatched length, [0,0,0], [MAX,MAX,MAX] |
```

### Step 2: Test Each Boundary

```solidity
// Test Zero Amount
function test_TransferZeroAmount() public {
    // Zero should be rejected or handled correctly
    vm.expectRevert("Zero amount");
    token.transfer(user2, 0);
}

// Test Maximum Amount
function test_TransferMaxAmount() public {
    // Should not overflow
    token.transfer(user2, type(uint256).max);
    // Check balances are correct
}

// Test Empty Array
function test_DistributeEmptyArray() public {
    // Should handle gracefully
    address[] memory recipients = new address[](0);
    uint256[] memory amounts = new uint256[](0);
    
    token.distribute(recipients, amounts);
    // Should not revert, should do nothing
}

// Test Mismatched Array Lengths
function test_DistributeMismatchedArrays() public {
    address[] memory recipients = new address[](3);
    uint256[] memory amounts = new uint256[](2);
    
    vm.expectRevert("Length mismatch");
    token.distribute(recipients, amounts);
}
```

### Step 3: Find Boundary Violations

```solidity
// VIOLATION: Zero amount bypasses fee
function transfer(address to, uint256 amount) external {
    uint256 fee = amount / 100;  // 1% fee
    // If amount = 0, fee = 0
    // If amount = 99, fee = 0 (integer division)
    
    balances[msg.sender] -= amount;
    balances[to] += (amount - fee);
    balances[owner] += fee;
}

// VIOLATION: First depositor can manipulate share price
function deposit(uint256 amount) external {
    uint256 shares;
    if (totalShares == 0) {
        shares = amount;  // First depositor
    } else {
        shares = amount * totalShares / totalAssets;
    }
    // Attacker can deposit 1 wei, then donate large amount
    // Next depositor gets 0 shares due to rounding
}
```

### Step 4: Prove Exploitability

```solidity
// PoC: First Depositor Attack
function test_FirstDepositorAttack() public {
    // Attacker is first depositor
    vm.startPrank(attacker);
    
    // Step 1: Deposit minimum
    vault.deposit(1);
    assertEq(vault.balanceOf(attacker), 1);
    
    // Step 2: Donate large amount (direct transfer)
    vm.deal(address(vault), 10000 ether);
    
    // Victim tries to deposit
    vm.stopPrank();
    vm.deal(victim, 1000 ether);
    vm.prank(victim);
    
    // Victim gets 0 shares due to rounding
    // shares = 1000 ether * 1 / 10000 ether = 0
    vault.deposit{value: 1000 ether}();
    assertEq(vault.balanceOf(victim), 0);  // Lost 1000 ether!
}
```

### Step 5: Quantify Impact

```markdown
## BND-001: First Depositor Manipulation

**Boundary**: First user (totalSupply == 0)
**Vulnerability**: Share price manipulation
**Maximum Loss**: All subsequent deposits
**Attack Cost**: Minimal (1 wei + donation)
**Severity**: HIGH

## BND-002: Zero Fee Bypass

**Boundary**: Zero amount (amount == 0)
**Vulnerability**: Fee bypass
**Impact**: Can spam zero transfers, griefing
**Severity**: LOW-MEDIUM
```

### Step 6: Report and Remediate

```solidity
// BND-001 Fix: First deposit minimum
function deposit(uint256 amount) external {
    require(amount > 0, "Zero deposit");
    
    uint256 shares;
    if (totalShares == 0) {
        shares = amount;
        // Prevent manipulation
        require(shares >= MINIMUM_SHARES, "Deposit too small");
    } else {
        shares = amount * totalShares / totalAssets;
    }
    
    _mint(msg.sender, shares);
}

// BND-002 Fix: Minimum amount check
function transfer(address to, uint256 amount) external {
    require(amount > MIN_TRANSFER, "Amount too small");
    // ... rest of logic
}
```

## Taint Framework

### SOURCE

User-controlled boundary inputs:

```solidity
// Zero value
0

// Small values
1, 2, 10

// Large values
type(uint256).max
type(uint256).max - 1
type(int256).max
type(int256).min

// Empty data structures
new address[](0)
""
bytes("")

// Boundary addresses
address(0)
address(this)
address(uint160(type(uint256).max))

// Time boundaries
block.timestamp (early in block)
block.timestamp (late in block)
```

### SINK

Operations that fail or behave unexpectedly at boundaries:

```solidity
// Division by zero
uint256 result = numerator / denominator;  // denominator = 0

// Overflow/underflow
balance = balance - amount;  // amount > balance

// Array out of bounds
uint256 value = array[index];  // index >= array.length

// Rounding to zero
uint256 shares = amount * totalShares / totalAssets;  // rounds to 0

// Gas exhaustion
for (uint i = 0; i < hugeArray.length; i++) { }  // Out of gas
```

### SANITIZER

Bounds checks and validation:

```solidity
// Zero checks
require(amount > 0, "Zero amount");
require(denominator != 0, "Division by zero");

// Maximum checks
require(amount <= MAX_AMOUNT, "Too large");
require(array.length <= MAX_LENGTH, "Array too large");

// Array bounds
require(index < array.length, "Out of bounds");

// Rounding protection
require(shares > 0, "Zero shares");
require((a * b) / b == a, "Overflow check");

// Minimum thresholds
require(amount >= MINIMUM, "Below minimum");
```

## Critical Boundary Values

### Numbers

```solidity
// Absolute boundaries
type(uint256).max    // 2^256 - 1
type(uint256).min    // 0
type(int256).max     // 2^255 - 1
type(int256).min     // -2^255

// Near-zero boundaries
0
1
2
10
100

// Power of 10 boundaries
1e0   // 1
1e6   // 1 million (USDC decimals)
1e8   // 100 million (WBTC decimals)
1e18  // 1 ether
1e27  // Large number

// Decimal boundaries (token amounts)
0.000001 ether  // Small ETH amount
1 wei
1 gwei (1e9 wei)
```

### Arrays

```solidity
// Empty
[]
new uint256[](0)

// Single element
[element]

// Maximum reasonable
new address[](1000)  // Consider gas limits

// Extreme (likely DoS)
new address[](1000000)
```

### Addresses

```solidity
// Zero address
address(0)

// Burn address (often used)
0x000000000000000000000000000000000000dEaD

// This contract
address(this)

// Maximum address
address(type(uint160).max)

// Precompiles (1-9)
address(1)  // ecrecover
address(2)  // SHA256
// ...
```

### Time

```solidity
// Zero timestamp
0

// Unix epoch start
0

// Large timestamp
type(uint256).max  // Year 1.07e58

// Common durations
1 minutes
1 hours
1 days
30 days
365 days
```

## Boundary Attack Patterns

### 1. Zero Value Bypass

```solidity
// Vulnerable
function transferWithFee(address to, uint256 amount) external {
    uint256 fee = amount * feeRate / 10000;
    balances[msg.sender] -= amount;
    balances[to] += amount - fee;
}

// Attack: amount = 0
// fee = 0, no transfer but event emitted (griefing)
```

### 2. Integer Overflow/Underflow

```solidity
// Vulnerable (pre-0.8)
function subtract(uint256 a, uint256 b) external returns (uint256) {
    return a - b;  // Underflows if b > a
}

// Attack: subtract(0, 1) = type(uint256).max
```

### 3. First User/Edge Case Manipulation

```solidity
// Vulnerable
function getPrice() external view returns (uint256) {
    if (totalSupply == 0) return 0;
    return totalValue / totalSupply;
}

// Attack: Be first, manipulate initial ratio
```

### 4. Array Manipulation

```solidity
// Vulnerable
function processBatch(uint256[] calldata ids) external {
    for (uint i = 0; i < ids.length; i++) {
        process(ids[i]);  // Gas exhaustion with large array
    }
}
```

### 5. Precision Loss

```solidity
// Vulnerable
function calculateShares(uint256 deposit) external view returns (uint256) {
    return deposit * totalShares / totalAssets;
    // If deposit * totalShares < totalAsset, returns 0
}
```

## Detection Strategy

### Reverse Scan

Assert boundary violations:

```markdown
- "Zero amounts CAN bypass fee logic"
- "MAX_UINT additions CAN cause overflow"
- "Empty arrays CAN bypass validation logic"
- "Large arrays CAN DoS the contract"
- "First user CAN manipulate initial state"
```

### Boundary Testing Matrix

| Input Type | Test Values | Expected Behavior |
|------------|-------------|-------------------|
| uint256 | 0, 1, MAX | Proper handling |
| address | 0, this, random | Validation |
| array | [], [1], [MAX] | Bounds checking |
| string | "", "a", long | Length limits |
| bytes | 0x, 0x00..., long | Size limits |

## Prevention Patterns

### 1. Minimum Thresholds

```solidity
uint256 constant MINIMUM_DEPOSIT = 1000;

function deposit(uint256 amount) external {
    require(amount >= MINIMUM_DEPOSIT, "Below minimum");
    // ...
}
```

### 2. Maximum Limits

```solidity
uint256 constant MAX_ARRAY_LENGTH = 100;

function batchProcess(uint256[] calldata items) external {
    require(items.length <= MAX_ARRAY_LENGTH, "Too many items");
    // ...
}
```

### 3. Zero Checks

```solidity
function transfer(address to, uint256 amount) external {
    require(amount > 0, "Zero amount");
    require(to != address(0), "Zero address");
    // ...
}
```

### 4. Overflow Protection

```solidity
// Solidity 0.8+ has built-in protection
// For pre-0.8, use SafeMath
using SafeMath for uint256;

uint256 result = a.add(b);  // Reverts on overflow
```

### 5. Rounding Protection

```solidity
function calculateShares(uint256 amount) external view returns (uint256) {
    uint256 shares = amount * totalShares / totalAssets;
    require(shares > 0, "Zero shares");
    return shares;
}
```

## Real-World Examples

### Example 1: IC0 Token (2021) - Zero Transfer

**Issue**: Zero transfer bypassed balance check

```solidity
function transfer(address to, uint amount) external {
    require(balances[msg.sender] >= amount);  // 0 >= 0 passes
    // Transfer 0 tokens
}
```

**Impact**: Spam events, confusion

### Example 2: Various Vaults - First Depositor

**Issue**: Share price manipulation on empty vault

```solidity
// Attacker deposits 1 wei
// Attacker donates 10000 ether
// Victim deposits 1000 ether, gets 0 shares
```

**Impact**: Loss of user funds

### Example 3: Integer Underflow (Multiple)

**Issue**: Pre-Solidity 0.8 underflows

```solidity
balance = balance - amount;  // Underflows if amount > balance
```

**Impact**: Infinite token balances
