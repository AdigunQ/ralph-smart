# Expression Taint Model (EXP)

## Definition

Focus on **specific dangerous code expressions**: external calls, delegatecalls, arithmetic, type casts, array access. Each expression is a potential vulnerability anchor where attacker-controlled data can trigger unsafe behavior.

## Core Question

> "Is this expression protected by sufficient sanitizers, or can attacker-controlled data reach it unsafely?"

## The Verification Harness for Expressions

### Step 1: Identify Dangerous Expressions

Catalog all potentially dangerous expressions in the codebase:

```markdown
## Contract: Vault.sol - Dangerous Expression Analysis

| Location | Expression | Type | Risk Level |
|----------|------------|------|------------|
| L45 | `msg.sender.call{value: amount}("")` | External Call | CRITICAL |
| L52 | `balances[msg.sender] -= amount` | State Update | HIGH |
| L78 | `totalRewards / userCount` | Division | MEDIUM |
| L92 | `data[uint256(index)]` | Array Access | HIGH |
| L103 | `address(target).delegatecall(data)` | Delegatecall | CRITICAL |
```

### Step 2: Trace Taint Flow

For each dangerous expression, determine if attacker can control inputs:

```markdown
## EXP-001: External Call at L45

**Expression**: `(bool success, ) = msg.sender.call{value: amount}("");`

**Taint Analysis**:
```
Source: msg.value (user controls deposit)
  ↓
Function: deposit() adds to balances[msg.sender]
  ↓
Source: msg.sender (user controls address)
  ↓
Function: withdraw() reads balances[msg.sender]
  ↓
Sink: msg.sender.call{value: amount}("")
```

**Attacker Control**:
- `msg.sender`: User can use any address (including contract with receive())
- `amount`: User controls withdrawal amount (up to their balance)

**Execution Order**:
```solidity
function withdraw(uint256 amount) external {
    // State read (safe)
    require(balances[msg.sender] >= amount);
    
    // SINK: External call BEFORE state update
    (bool success, ) = msg.sender.call{value: amount}("");  // ← REENTRANCY HERE
    require(success);
    
    // State update AFTER external call
    balances[msg.sender] -= amount;
}
```

**Missing Sanitizers**:
- [x] No reentrancy guard
- [x] State updated AFTER external call (CEI violation)
```

### Step 3: Generate Attack Hypotheses

```solidity
// HYPOTHESIS: Reentrancy via EXP-001

contract ReentrancyAttacker {
    Vault target;
    uint256 count;
    
    function attack() external payable {
        // 1. Deposit to get balance
        target.deposit{value: 1 ether}();
        
        // 2. Start withdrawal
        target.withdraw(1 ether);
    }
    
    receive() external payable {
        // 3. Reenter before state update
        if (count < 5) {
            count++;
            target.withdraw(1 ether);  // Reenter!
        }
    }
}
```

### Step 4: Prove Reachability and Controllability

```markdown
## EXP-001 Verification

**Reachability**:
- [x] Function is external
- [x] No access control blocking
- [x] User can deposit (prerequisite)

**Controllability**:
- [x] Attacker controls: msg.sender (their contract address)
- [x] Attacker controls: amount (parameter)
- [x] Attacker receives: external call to their contract

**Preconditions**:
- Attacker must have deposited first
- Attacker must have receive() function
```

### Step 5: Quantify Impact

```markdown
## EXP-001 Impact Assessment

**Vulnerability Type**: Reentrancy
**Maximum Impact**: Contract drainage (all ETH)
**Exploit Cost**: Minimal (gas only)
**Likelihood**: High (simple to execute)
**Severity**: CRITICAL
```

### Step 6: Create PoC and Report

```solidity
// PoC: Reentrancy Exploit
function test_ReentrancyViaExternalCall() public {
    // Setup
    vm.deal(address(vault), 10 ether);
    
    // Deploy attacker
    ReentrancyAttacker attacker = new ReentrancyAttacker(address(vault));
    
    // Attack
    vm.deal(address(attacker), 1 ether);
    attacker.attack{value: 1 ether}();
    
    // Verify impact
    assertEq(address(vault).balance, 0);  // Drained
    assertGt(address(attacker).balance, 10 ether);  // Profit
}
```

## Dangerous Expression Patterns

### 1. External Calls (Highest Priority)

```solidity
// DANGEROUS: All external calls can trigger reentrancy

// Pattern 1: Low-level call
(bool success, bytes memory ret) = target.call{value: amount}(data);

// Pattern 2: Transfer (also vulnerable, though limited gas)
payable(target).transfer(amount);

// Pattern 3: Token transfer (ERC777, ERC721 callbacks)
token.transfer(to, amount);
token.transferFrom(from, to, amount);
token.safeTransfer(to, amount);

// Pattern 4: External contract calls
externalContract.someFunction();
```

**Sanitizers**:
```solidity
// ReentrancyGuard
function withdraw() external nonReentrant { }

// CEI Pattern (Checks-Effects-Interactions)
function withdraw(uint256 amount) external {
    // Checks
    require(balances[msg.sender] >= amount);
    
    // Effects (state update FIRST)
    balances[msg.sender] -= amount;
    
    // Interactions (external call LAST)
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);
}

// Pull over Push pattern
function withdraw() external {
    uint256 amount = pendingWithdrawals[msg.sender];
    pendingWithdrawals[msg.sender] = 0;
    // User calls another function to claim
}
```

### 2. Delegatecall (Critical)

```solidity
// DANGEROUS: delegatecall executes code in current context

// Pattern 1: Direct delegatecall
address(target).delegatecall(data);

// Pattern 2: Proxy patterns
(bool success, ) = implementation.delegatecall(msg.data);
```

**Risks**:
- Storage collision (if target has different layout)
- Selfdestruct in delegate can kill calling contract
- State manipulation

**Sanitizers**:
```solidity
// Whitelist allowed targets
mapping(address => bool) public allowedImplementations;

function upgrade(address newImpl) external onlyOwner {
    require(allowedImplementations[newImpl], "Not allowed");
    implementation = newImpl;
}

// Storage slot protection (EIP-1967)
bytes32 internal constant IMPLEMENTATION_SLOT = 
    bytes32(uint256(keccak256('eip1967.proxy.implementation')) - 1);
```

### 3. Arithmetic Operations

```solidity
// DANGEROUS: Overflow/underflow, division by zero

// Pattern 1: Division
uint256 result = numerator / denominator;

// Pattern 2: Multiplication then division
uint256 result = (a * b) / c;

// Pattern 3: Unchecked arithmetic
unchecked {
    balance = balance - amount;
}

// Pattern 4: Downcasting
uint128 smaller = uint128(largeNumber);
```

**Sanitizers**:
```solidity
// Zero check
require(denominator > 0, "Division by zero");

// Overflow checks (Solidity 0.8+)
// Automatic, but can use unchecked{} for gas optimization

// SafeMath (pre-0.8)
using SafeMath for uint256;
uint256 result = a.mul(b).div(c);

// Precision protection
require((a * b) / b == a, "Overflow");
```

### 4. Array Access

```solidity
// DANGEROUS: Out of bounds access, DoS

// Pattern 1: User-controlled index
uint256 value = array[userIndex];

// Pattern 2: Unbounded iteration
for (uint i = 0; i < array.length; i++) {
    // Gas exhaustion if array is large
}

// Pattern 3: Push without limit
array.push(item);
```

**Sanitizers**:
```solidity
// Bounds check
require(index < array.length, "Out of bounds");

// Gas limit consideration
require(array.length < MAX_ARRAY_SIZE, "Too large");

// Pagination
function getItems(uint256 offset, uint256 limit) external view returns (Item[] memory) {
    require(limit <= 100, "Limit too high");
    // ...
}
```

### 5. Type Casting

```solidity
// DANGEROUS: Overflow on downcast

// Pattern 1: Address casting
address addr = address(uint160(uint256(hash)));

// Pattern 2: Integer downcasting
uint128 smaller = uint128(largeNumber);  // Truncates!

// Pattern 3: Bytes casting
bytes4 selector = bytes4(data);
```

**Sanitizers**:
```solidity
// Use SafeCast
uint128 smaller = SafeCast.toUint128(largeNumber);

// Explicit bounds check
require(largeNumber <= type(uint128).max, "Overflow");
```

### 6. Hash Functions

```solidity
// DANGEROUS: Hash collisions with dynamic types

// Pattern 1: abi.encodePacked collision
keccak256(abi.encodePacked(a, b));  // If a and b are dynamic, collision possible

// Pattern 2: Weak randomness
uint256 random = uint256(keccak256(abi.encodePacked(block.timestamp)));
```

**Sanitizers**:
```solidity
// Use abi.encode
keccak256(abi.encode(a, b));  // No collision

// Chainlink VRF for randomness
uint256 random = VRFConsumerBase(vrf).randomResult();
```

## Detection Strategy

### Code Search Patterns

```bash
# External calls
grep -rn "\.call{value:" contracts/
grep -rn "\.delegatecall" contracts/
grep -rn "\.transfer(" contracts/
grep -rn "\.send(" contracts/

# Arithmetic
grep -rn "/ " contracts/ | grep -v "//"
grep -rn "unchecked {" contracts/
grep -rn "type(.*).max" contracts/

# Array access
grep -rn "\[.*\]" contracts/ | grep -v "//"
grep -rn "\.push(" contracts/

# Type casting
grep -rn "uint.*(" contracts/
grep -rn "address(" contracts/
```

### Reverse Scan Approach

For each dangerous expression type, assert vulnerability:

```solidity
// Assert: "This external call IS vulnerable to reentrancy"
// Assert: "This division CAN divide by zero"
// Assert: "This delegatecall CAN be exploited"
// Assert: "This array access CAN be out of bounds"
// Assert: "This cast CAN overflow"
```

Then verify if sanitizers exist.

## Risk Assessment Matrix

| Expression | Without Sanitizer | With Sanitizer |
|------------|------------------|----------------|
| External Call | CRITICAL | LOW |
| Delegatecall | CRITICAL | MEDIUM |
| Division | MEDIUM | LOW |
| Array Access | HIGH | LOW |
| Type Cast | MEDIUM | LOW |
| Unchecked Arithmetic | HIGH | N/A |

## Real-World Examples

### Example 1: The DAO Hack (2016)

**Expression**: `recipient.call.value(amount)()`

**Missing Sanitizers**:
- No reentrancy guard
- State updated after external call

**Impact**: $60M stolen

### Example 2: Parity Multisig (2017)

**Expression**: `delegatecall(delegateData)`

**Missing Sanitizers**:
- No target whitelist
- Anyone could call init function

**Impact**: $30M frozen

### Example 3: Integer Overflow (Multiple)

**Expression**: `balanceOf[_to] += _value`

**Missing Sanitizers**:
- No overflow protection (pre-0.8)

**Impact**: Infinite token minting

### Example 4: Cover Protocol (2021)

**Expression**: `memoryUsers[receiver].length - 1`

**Missing Sanitizers**:
- No bounds check
- Array could be empty

**Impact**: $4M stolen via array underflow
