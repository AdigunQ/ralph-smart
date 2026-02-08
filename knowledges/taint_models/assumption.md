# Assumption Taint Model (ASM)

## Definition

**Assumptions** are business logic prerequisites that developers believe will always hold—but code may not fully enforce. These concern workflow order, roles, timing, and trust relationships rather than pure data equations.

## Core Question

> "Can an attacker violate the business flow assumptions by executing operations out of order, bypassing prerequisites, or exploiting race conditions?"

## The Verification Harness for Assumptions

### Step 1: Identify Assumptions

Document all implicit and explicit assumptions:

```markdown
## Contract: LendingPool.sol

| Assumption ID | Assumption | Enforcement | Criticality |
|--------------|------------|-------------|-------------|
| ASM-001 | Users deposit before borrowing | Explicit check | CRITICAL |
| ASM-002 | Only owner can set interest rate | onlyOwner modifier | HIGH |
| ASM-003 | Proposals wait 3 days before execution | ??? | HIGH |
| ASM-004 | Oracle price is always fresh | ??? | CRITICAL |
```

### Step 2: Test Assumption Violations

For each assumption, try to violate it:

```solidity
// ASM-001: "Users must deposit before borrowing"
// Test: Call borrow() without deposit()

function test_BorrowWithoutDeposit() public {
    // Don't deposit
    
    // Try to borrow
    vm.prank(attacker);
    
    // If this doesn't revert, ASM-001 is violated
    lendingPool.borrow(1000 ether);
    
    // Check if we got the loan
    assertEq(loanToken.balanceOf(attacker), 1000 ether);
}
```

### Step 3: Prove Reachability

```markdown
## ASM-001 Violation Analysis

**Assumption**: Users must deposit collateral before borrowing

**Entry Point**: borrow() is external ✓

**Path Analysis**:
```
borrow(uint256 amount)
  └─> _checkCollateral(msg.sender, amount) ???
       └─> If missing: assumption violated
```

**Missing Check**:
```solidity
function borrow(uint256 amount) external {
    // MISSING: require(collateral[msg.sender] >= amount * ratio);
    token.transfer(msg.sender, amount);
    debt[msg.sender] += amount;
}
```

**Attacker Control**: 
- Controls: amount parameter
- Can call: borrow() directly
- No prerequisites enforced
```

### Step 4: Determine Impact

| Violation | Impact | Severity |
|-----------|--------|----------|
| Borrow without deposit | Uncollateralized loans | CRITICAL |
| Execute proposal early | Governance bypass | CRITICAL |
| Mint without auth | Infinite token supply | CRITICAL |
| Skip whitelist phase | Unfair token distribution | HIGH |
| Use stale oracle | Incorrect liquidations | HIGH |

### Step 5: Create PoC

```solidity
contract AssumptionExploit is Test {
    LendingPool pool;
    
    function test_UncollateralizedBorrow() public {
        // Setup: Pool has liquidity
        deal(address(loanToken), address(pool), 10000 ether);
        
        // Attack: Borrow without deposit
        uint256 borrowAmount = 5000 ether;
        pool.borrow(borrowAmount);
        
        // Verify: We got the loan with no collateral
        assertEq(loanToken.balanceOf(address(this)), borrowAmount);
        assertEq(pool.collateral(address(this)), 0);
        
        // Impact: Free money
    }
}
```

### Step 6: Report with Remediation

```solidity
// Vulnerable
function borrow(uint256 amount) external {
    token.transfer(msg.sender, amount);
    debt[msg.sender] += amount;
}

// Fixed
function borrow(uint256 amount) external {
    require(
        collateral[msg.sender] * price >= amount * collateralRatio,
        "Insufficient collateral"
    );
    token.transfer(msg.sender, amount);
    debt[msg.sender] += amount;
}
```

## Taint Framework

### SOURCE

Points where assumption control enters:

| Source Type | Examples |
|-------------|----------|
| External calls | User transactions, function calls |
| Cross-transaction state | Previous deposits, accrued interest |
| Time/Block conditions | block.timestamp, block.number |
| Multi-role interactions | Admin actions, oracle updates |
| Cross-contract calls | External protocol interactions |

### SINK

Dangerous operation executes despite assumption violation:

```solidity
// SINK: Borrow executes without collateral check
token.transfer(msg.sender, amount);

// SINK: Proposal executes without timelock
proposal.action.call{value: amount}(data);

// SINK: Mint executes without authorization
_mint(to, amount);
```

### SANITIZER

Checks that enforce assumptions:

```solidity
// State check sanitizers
require(deposited[msg.sender], "Must deposit first");
require(block.timestamp >= proposal.createdAt + 3 days, "Too early");
require(collateral[msg.sender] >= amount * ratio, "Insufficient collateral");

// Access control sanitizers
onlyOwner        // Role-based
onlyRole(MINTER) // RBAC
onlyWhitelisted  // List-based

// Time lock sanitizers
require(block.number >= unlockBlock, "Locked");
require(block.timestamp >= vestingEnd, "Not vested");

// Precondition sanitizers
require(initialized, "Not initialized");
require(!paused, "Paused");
require(phase == Phase.Public, "Not public phase");
```

## Common Assumption Categories

### Workflow Order Assumptions

```solidity
// Assumption: Deposit → Borrow → Repay → Withdraw

// Deposit
function deposit() external payable {
    collateral[msg.sender] += msg.value;
}

// Borrow (should check deposit first)
function borrow(uint256 amount) external {
    // SANITIZER: require(collateral[msg.sender] > 0, "No collateral");
    // SANITIZER: require(
    //     collateral[msg.sender] * price >= amount * ratio,
    //     "Insufficient collateral"
    // );
    
    debt[msg.sender] += amount;
    token.transfer(msg.sender, amount);
}

// Repay (should check borrow first)
function repay() external {
    // SANITIZER: require(debt[msg.sender] > 0, "No debt");
    
    debt[msg.sender] = 0;
    token.transferFrom(msg.sender, address(this), amount);
}

// Withdraw (should check no debt)
function withdraw() external {
    // SANITIZER: require(debt[msg.sender] == 0, "Has debt");
    
    uint256 amount = collateral[msg.sender];
    collateral[msg.sender] = 0;
    payable(msg.sender).transfer(amount);
}
```

**Common Violations**:
- Borrow without deposit
- Withdraw with outstanding debt
- Double withdrawal
- Repay non-existent debt

### Access Control Assumptions

```solidity
// Assumption: Only owner can perform admin actions

// ❌ Violation: Missing modifier
function setInterestRate(uint256 newRate) external {
    interestRate = newRate;
}

// ✓ Sanitized
function setInterestRate(uint256 newRate) external onlyOwner {
    interestRate = newRate;
}

// Assumption: Only minters can create tokens

// ❌ Violation: Public mint
function mint(address to, uint256 amount) external {
    _mint(to, amount);
}

// ✓ Sanitized
function mint(address to, uint256 amount) external onlyRole(MINTER) {
    _mint(to, amount);
}
```

### Time/Sequence Assumptions

```solidity
// Assumption: Proposals wait 3 days before execution

// ❌ Violation: Immediate execution
function executeProposal(uint256 id) external {
    Proposal storage p = proposals[id];
    // Missing: require(block.timestamp >= p.createdAt + 3 days);
    (bool success, ) = p.target.call(p.data);
    require(success);
}

// ✓ Sanitized
function executeProposal(uint256 id) external {
    Proposal storage p = proposals[id];
    require(
        block.timestamp >= p.createdAt + 3 days,
        "Timelock active"
    );
    require(!p.executed, "Already executed");
    require(p.forVotes > p.againstVotes, "Not passed");
    
    p.executed = true;
    (bool success, ) = p.target.call(p.data);
    require(success);
}
```

### External Dependency Assumptions

```solidity
// Assumption: Oracle price is always fresh

// ❌ Violation: No staleness check
function getPrice() external view returns (uint256) {
    (, int256 price, , , ) = oracle.latestRoundData();
    return uint256(price);
}

// ✓ Sanitized
function getPrice() external view returns (uint256) {
    (, int256 price, , uint256 updatedAt, ) = oracle.latestRoundData();
    require(
        block.timestamp - updatedAt < HEARTBEAT,
        "Stale price"
    );
    return uint256(price);
}

// Assumption: External contract is trusted

// ❌ Violation: Arbitrary call
function execute(address target, bytes calldata data) external {
    target.call(data);  // Can call ANY contract
}

// ✓ Sanitized
function execute(bytes calldata data) external {
    // Only whitelisted targets
    require(allowedTargets[msg.sender], "Not allowed");
    target.call(data);
}
```

## Detection Strategy

### Reverse Scan (Assertive)

For each assumption, assert it can be violated:

| Assumption | Violation Hypothesis |
|------------|---------------------|
| "Users deposit before borrowing" | "Users CAN borrow without depositing" |
| "Only owner can mint" | "Anyone CAN mint tokens" |
| "Proposals wait 3 days" | "Proposals CAN execute immediately" |
| "Oracle is fresh" | "Stale prices CAN be used" |
| "Contract is initialized" | "Functions CAN be called before init" |

### Checklist for Each Function

- [ ] Does this function have prerequisites?
- [ ] Are prerequisites explicitly checked?
- [ ] Can prerequisites be bypassed?
- [ ] What happens if prerequisites aren't met?
- [ ] Is there a time-based prerequisite?
- [ ] Is there a state-based prerequisite?
- [ ] Is there a role-based prerequisite?

## Real-World Examples

### Example 1: Cream Finance (2021)

**Assumption**: "Users can't borrow without collateral"

**Violation**: Missing collateral check in `borrow()` for certain markets

```solidity
function borrow(address token, uint256 amount) external {
    // Missing: require(accountCollateral[msg.sender] >= amount);
    transferTokens(msg.sender, amount);
}
```

**Impact**: $130M stolen through uncollateralized borrows

### Example 2: Cover Protocol (2020)

**Assumption**: "Only depositor can withdraw"

**Violation**: No check that withdrawal matches deposit

```solidity
function withdraw(uint256 amount) external {
    // Missing: require(deposits[msg.sender] >= amount);
    transfer(msg.sender, amount);
}
```

**Impact**: Attacker withdrew from protocol, not their own deposit

### Example 3: Poly Network (2021)

**Assumption**: "Only authorized keepers can update cross-chain data"

**Violation**: Missing access control on keeper functions

**Impact**: $611M stolen (largest DeFi hack at the time)

### Example 4: Beanstalk (2022)

**Assumption**: "Governance proposals wait for voting period"

**Violation**: Flash loan allowed immediate governance takeover

```solidity
function executeProposal(uint256 id) external {
    // No check for flash loan voting
    require(governanceToken.balanceOf(msg.sender) > threshold);
    // Execute immediately
}
```

**Impact**: $182M stolen through governance attack

## Prevention Patterns

### 1. Explicit Preconditions

```solidity
modifier whenDepositRequired() {
    require(collateral[msg.sender] > 0, "Deposit first");
    _;
}

modifier whenTimelockPassed(uint256 proposalId) {
    require(
        block.timestamp >= proposals[proposalId].createdAt + 3 days,
        "Timelock"
    );
    _;
}
```

### 2. State Machine Pattern

```solidity
enum Phase { Setup, Whitelist, Public, Ended }

Phase public currentPhase;

modifier onlyPhase(Phase phase) {
    require(currentPhase == phase, "Wrong phase");
    _;
}

function advancePhase() external onlyOwner {
    require(block.timestamp >= phaseEndTime, "Too early");
    currentPhase = Phase(uint256(currentPhase) + 1);
}

function mint() external onlyPhase(Phase.Public) {
    // Only callable in public phase
}
```

### 3. Initialization Pattern

```solidity
bool public initialized;

modifier whenInitialized() {
    require(initialized, "Not initialized");
    _;
}

function initialize(address _owner) external {
    require(!initialized, "Already initialized");
    owner = _owner;
    initialized = true;
}

function criticalFunction() external whenInitialized {
    // Safe to execute
}
```

### 4. Two-Step Ownership

```solidity
address public pendingOwner;

function transferOwnership(address newOwner) external onlyOwner {
    pendingOwner = newOwner;
}

function acceptOwnership() external {
    require(msg.sender == pendingOwner, "Not pending owner");
    owner = pendingOwner;
    pendingOwner = address(0);
}
```
