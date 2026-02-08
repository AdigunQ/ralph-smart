# Composition Taint Model (CMP)

## Definition

Focus on **combinations of operations** that seem safe individually but create vulnerabilities when combined. The whole is often more dangerous than the sum of the parts.

## Core Question

> "What happens when we combine operation A with operation B, or execute them in a specific order within the same transaction? What emergent behaviors appear when multiple contracts or protocols interact?"

## The Verification Harness for Compositional Attacks

### Step 1: Identify Composable Operations

Map operations that can be combined:

```markdown
## Composable Operations Analysis

| Operation | Can Combine With | Risk Level |
|-----------|------------------|------------|
| Flash Loan | Price queries, Swaps, Borrows | CRITICAL |
| Approval | transferFrom, Reentrancy | HIGH |
| Multi-call | Any sequence of operations | MEDIUM |
| Callbacks (ERC777) | Any transfer operation | HIGH |
| Delegation | Storage manipulation | CRITICAL |
```

### Step 2: Generate Attack Combinations

```markdown
## Potential Combinations to Test

### Flash Loan + ...
- [ ] Flash loan + price oracle manipulation
- [ ] Flash loan + governance vote
- [ ] Flash loan + liquidity pool drain
- [ ] Flash loan + collateral manipulation

### Approval + ...
- [ ] Approval + reentrancy attack
- [ ] Approval + front-running
- [ ] Approval + unlimited approval abuse

### Multi-call + ...
- [ ] Multi-call + state inconsistency
- [ ] Multi-call + atomicity violation
- [ ] Multi-call + gas exhaustion

### Callbacks + ...
- [ ] ERC777 callback + reentrancy
- [ ] ERC721 callback + state manipulation
- [ ] ERC1155 callback + batch operation abuse
```

### Step 3: Design Compositional Attack

```solidity
// Flash Loan + Price Manipulation Example

contract CompositionalAttack {
    FlashLoan flashLoan;
    LendingPool lending;
    DEX dex;
    
    function attack() external {
        // Step 1: Flash loan massive capital
        flashLoan.borrow(10000 ether);
        
        // Step 2: Manipulate price oracle
        // Large swap crashes token price
        dex.swap(10000 ether, token);
        
        // Step 3: Exploit manipulated price
        // Borrow at manipulated collateral value
        lending.borrow(usdc, 50000);  // More than should be allowed
        
        // Step 4: Restore price (optional for profit)
        dex.swap(token, 10000 ether);
        
        // Step 5: Repay flash loan
        flashLoan.repay(10000 ether);
        
        // Profit: Borrowed amount - flash loan fee
    }
}
```

### Step 4: Verify Each Component

```markdown
## CMP-001: Flash Loan + Price Manipulation Verification

### Component 1: Flash Loan
- [x] Available (Aave, Balancer, etc.)
- [x] Sufficient liquidity
- [x] Borrower can be contract

### Component 2: Price Manipulation
- [x] Protocol uses spot price
- [x] No TWAP or manipulation resistance
- [x] Sufficient liquidity for manipulation

### Component 3: Exploit Path
- [x] Borrowing allowed in same block
- [x] No price staleness check
- [x] No borrow cooldown

### Combination Result
- [x] Attack possible in single transaction
- [x] Profit > cost (flash loan fee)
- [x] No mitigations prevent combination
```

### Step 5: Quantify Compositional Impact

```markdown
## CMP-001 Impact Assessment

**Individual Operation Impacts**:
- Flash loan: None (just borrowing)
- Price swap: Temporary price movement
- Borrow: Normal protocol operation

**Combined Impact**: Theft of protocol funds

**Maximum Loss**: Limited by available flash loan liquidity
**Exploit Cost**: Flash loan fee (0.09% on Aave)
**Profit**: Can exceed $1M with sufficient capital

**Severity**: CRITICAL
```

### Step 6: Create PoC and Report

```solidity
// PoC: Flash Loan + Price Manipulation
function test_FlashLoanPriceManipulation() public {
    // Setup: Initial state
    assertEq(lending.getCollateralValue(), 100 ether);
    
    // Execute compositional attack
    CompositionalAttack attacker = new CompositionalAttack();
    attacker.attack();
    
    // Verify: Protocol lost funds
    assertLt(lending.getReserves(), expectedReserves);
    assertGt(attacker.profit(), 0);
}
```

## Classic Composition Attacks

### 1. Flash Loan + Price Manipulation

```solidity
// Attack Flow:
// 1. Flash loan ETH
// 2. Swap ETH -> Token (manipulates Token price down)
// 3. Use depressed Token as collateral
// 4. Borrow maximum against collateral
// 5. (Optional) Swap back Token -> ETH
// 6. Repay flash loan

// Vulnerable pattern:
function getTokenPrice() public view returns (uint256) {
    (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
    return reserve1 / reserve0;  // Spot price!
}

function borrow(uint256 amount) external {
    uint256 collateralValue = collateral * getTokenPrice();
    require(collateralValue >= amount * 150 / 100);
    // Lend tokens
}
```

**Mitigation**:
```solidity
// Use TWAP (Time-Weighted Average Price)
function getTokenPrice() public view returns (uint256) {
    uint32[] memory secondsAgo = new uint32[](2);
    secondsAgo[0] = 1800;  // 30 min ago
    secondsAgo[1] = 0;      // now
    
    (int56[] memory tickCumulatives, ) = pool.observe(secondsAgo);
    int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
    int24 avgTick = int24(tickCumulativesDelta / 1800);
    
    return tickToPrice(avgTick);
}
```

### 2. Approval + Reentrancy

```solidity
// Attack Flow:
// 1. User approves contract
// 2. Contract calls transferFrom
// 3. Reentrancy callback allows multiple transferFrom calls

// Vulnerable pattern:
function processWithFee() external {
    // Transfer user's tokens
    token.transferFrom(msg.sender, address(this), amount);
    
    // External call allows reentrancy
    msg.sender.call("");
    
    // In callback, attacker calls transferFrom again
    // Using same approval!
}
```

**Mitigation**:
```solidity
function processWithFee() external nonReentrant {
    // Use checks-effects-interactions
    uint256 amount = approvedAmount[msg.sender];
    approvedAmount[msg.sender] = 0;  // Clear first
    
    token.transferFrom(msg.sender, address(this), amount);
    
    // External call last
    msg.sender.call("");
}
```

### 3. Multiple Inheritance + Function Shadowing

```solidity
// Attack Flow:
// 1. Contract inherits from A (secure) and B (insecure)
// 2. Function shadowing causes insecure version to be used

contract A {
    function withdraw() public onlyOwner {
        // Secure: has access control
    }
}

contract B {
    function withdraw() public {
        // Insecure: no access control
    }
}

contract C is A, B {
    // Which withdraw() is used? B's version!
    // Attacker can call withdraw() without auth
}
```

**Mitigation**:
```solidity
contract C is A, B {
    // Explicitly override and choose secure version
    function withdraw() public override(A, B) onlyOwner {
        A.withdraw();
    }
}
```

### 4. Callback + State Manipulation

```solidity
// Attack Flow (ERC777):
// 1. Attacker has ERC777 token with callback
// 2. Protocol transfers tokens to attacker
// 3. Callback executes before transfer completes
// 4. Callback manipulates protocol state

// Vulnerable pattern:
function distributeRewards() external {
    for (uint i = 0; i < recipients.length; i++) {
        token.transfer(recipients[i], rewards[i]);  // Callback!
        // During callback, attacker can:
        // - Reenter this function
        // - Manipulate recipients array
        // - Change reward amounts
    }
}
```

**Mitigation**:
```solidity
function distributeRewards() external nonReentrant {
    // Use pull over push
    for (uint i = 0; i < recipients.length; i++) {
        pendingRewards[recipients[i]] += rewards[i];
    }
    // Recipients call claim() separately
}
```

### 5. Proxy + Storage Collision

```solidity
// Attack Flow (Proxy pattern):
// 1. Proxy delegates to implementation
// 2. Implementation has different storage layout
// 3. Variables overlap, allowing manipulation

// Proxy
contract Proxy {
    address public implementation;  // Slot 0
    address public owner;           // Slot 1
    
    fallback() external {
        implementation.delegatecall(msg.data);
    }
}

// Malicious Implementation
contract MaliciousImpl {
    address public owner;           // Slot 0 (collision!)
    address public implementation;  // Slot 1
    
    function becomeOwner() external {
        owner = msg.sender;  // Overwrites proxy's implementation!
    }
}
```

**Mitigation**:
```solidity
// Use EIP-1967 storage slots
bytes32 internal constant IMPLEMENTATION_SLOT = 
    bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);

function _getImplementation() internal view returns (address impl) {
    assembly {
        impl := sload(IMPLEMENTATION_SLOT)
    }
}
```

## Detection Strategy

### Combinatorial Analysis

For each operation, check what it can combine with:

```solidity
// Operation: Flash loan available?
if (protocol.integratesWith(FlashLoanProviders)) {
    check(FlashLoanCombinations);
}

// Operation: ERC777/ERC721 tokens?
if (protocol.accepts(tokensWithCallbacks)) {
    check(CallbackCombinations);
}

// Operation: Multi-call support?
if (protocol.has(MultiCall)) {
    check(AtomicityCombinations);
}
```

### Reverse Scan

Assert dangerous combinations exist:

```markdown
- "Flash loans CAN manipulate oracle prices for profit"
- "Multiple contracts CAN be composed to bypass access control"
- "Reentrancy CAN drain funds when combined with approval pattern"
- "Inheritance CAN shadow secure functions with insecure ones"
- "Callbacks CAN manipulate state during token transfers"
```

## Impact Amplification

| Individual Risk | Combined Risk | Amplification |
|----------------|---------------|---------------|
| Low | High | 10-100x |
| Medium | Critical | 5-50x |
| High | Critical | 2-10x |

## Prevention Patterns

### 1. Atomicity Guarantees

```solidity
function multiOperation(bytes[] calldata calls) external {
    uint256 checkpoint = gasleft();
    
    for (uint i = 0; i < calls.length; i++) {
        (bool success, ) = address(this).delegatecall(calls[i]);
        require(success, "Operation failed");
    }
    
    // All succeed or all revert
    require(gasleft() > checkpoint / 2, "Gas manipulation");
}
```

### 2. Reentrancy Locks Across Calls

```solidity
modifier globalLock() {
    require(!globalLocked, "Locked");
    globalLocked = true;
    _;
    globalLocked = false;
}
```

### 3. Price Manipulation Resistance

```solidity
modifier noPriceManipulation() {
    uint256 priceBefore = getPrice();
    _;
    uint256 priceAfter = getPrice();
    require(
        priceAfter >= priceBefore * 95 / 100 &&
        priceAfter <= priceBefore * 105 / 100,
        "Price manipulation detected"
    );
}
```

### 4. Composition-Aware Testing

```solidity
function test_FlashLoanResistance() public {
    // Simulate flash loan attack
    uint256 flashLoanAmount = 10000 ether;
    
    // Attacker uses flash loan
    vm.prank(attacker);
    protocol.operationWithFlashLoan(flashLoanAmount);
    
    // Verify no profit possible
    assertLe(attacker.balance, initialBalance);
}
```

## Real-World Examples

### Example 1: Cream Finance (2021) - Flash Loan + Price

**Combination**: Flash loan + LP token price manipulation

**Impact**: $130M stolen

**Lesson**: Don't use DEX reserves for pricing

### Example 2: Harvest Finance (2020) - Flash Loan + Swap

**Combination**: Flash loan + stablecoin pool manipulation

**Impact**: $34M stolen

**Lesson**: Use TWAP or multiple price sources

### Example 3: Cover Protocol (2021) - Callback + State

**Combination**: ERC1155 callback + memory manipulation

**Impact**: $4M stolen

**Lesson**: Be careful with callbacks in loops

### Example 4: Parity Multisig (2017) - Delegatecall + Init

**Combination**: Delegatecall + unprotected init

**Impact**: $30M frozen

**Lesson**: Protect initialization functions
