---
description: Execute TDD Loop with Security-Focused Testing
trigger: /tdd [feature-description]
---

# /tdd - Test-Driven Development with Security Focus

Implements the Ralph Wiggum iterative TDD protocol with additional security considerations for smart contract development.

## Overview

Traditional TDD: Red → Green → Refactor

**Security TDD**: Red → Green → Refactor → **Attack**

The additional "Attack" phase verifies the implementation withstands common attack vectors.

## Phase 1: Red - Write Failing Tests

### 1.1 Functional Tests

```solidity
function test_DepositIncreasesBalance() public {
    // Arrange
    uint256 depositAmount = 1 ether;
    
    // Act
    vault.deposit{value: depositAmount}();
    
    // Assert
    assertEq(vault.balanceOf(address(this)), depositAmount);
}
```

### 1.2 Security Tests (Crucial)

For every functional test, write corresponding security tests:

```solidity
function test_DepositRevertsWithZeroAmount() public {
    // Boundary: Zero value
    vm.expectRevert("Zero deposit");
    vault.deposit{value: 0}();
}

function test_DepositHandlesMaxValue() public {
    // Boundary: Maximum value
    uint256 maxDeposit = type(uint256).max;
    // Test behavior at limits
}

function test_DepositReentrancyProtection() public {
    // Security: Reentrancy
    ReentrancyAttacker attacker = new ReentrancyAttacker(vault);
    
    vm.expectRevert("ReentrancyGuard");
    attacker.attack{value: 1 ether}();
}
```

### 1.3 Invariant Tests

```solidity
function testInvariant_TotalSupplyEqualsSumOfBalances() public {
    // Invariant that must always hold
    assertEq(
        vault.totalSupply(),
        vault.balanceOf(user1) + vault.balanceOf(user2) + ...
    );
}
```

### Complexity Constraints

- Max 20 lines per function
- Max 200 lines per file
- Max 3 parameters per function
- Max 2 levels of nesting

## Phase 2: Green - Minimum Implementation

### Security-First Implementation

```solidity
contract Vault is ReentrancyGuard {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;
    
    function deposit() external payable nonReentrant {
        // Checks
        require(msg.value > 0, "Zero deposit");
        
        // Effects
        balances[msg.sender] += msg.value;
        totalSupply += msg.value;
        
        // Interactions (none in this case)
    }
}
```

### Security Checklist During Implementation

- [ ] ReentrancyGuard on functions with external calls
- [ ] Checks-Effects-Interactions pattern
- [ ] Input validation (zero, max, boundary)
- [ ] Access control on privileged functions
- [ ] Overflow/underflow protection (Solidity 0.8+ or SafeMath)
- [ ] Event emission for state changes

## Phase 3: Refactor - Clean Code

### Refactoring Security Checklist

- [ ] Extract complex conditions into well-named functions
- [ ] Reduce nesting (early returns)
- [ ] Remove code duplication
- [ ] Add NatSpec documentation
- [ ] Ensure consistent error messages

### Example Refactor

```solidity
// Before: Nested, unclear
function withdraw(uint256 amount) external {
    if (balances[msg.sender] >= amount) {
        if (!paused) {
            balances[msg.sender] -= amount;
            (bool success, ) = msg.sender.call{value: amount}("");
            require(success);
        } else {
            revert("Paused");
        }
    } else {
        revert("Insufficient");
    }
}

// After: Flat, clear
function withdraw(uint256 amount) external nonReentrant whenNotPaused {
    _validateWithdrawal(msg.sender, amount);
    _executeWithdrawal(msg.sender, amount);
}

function _validateWithdrawal(address user, uint256 amount) internal view {
    require(balances[user] >= amount, "Insufficient balance");
    require(amount > 0, "Zero amount");
}

function _executeWithdrawal(address user, uint256 amount) internal {
    balances[user] -= amount;
    totalSupply -= amount;
    
    (bool success, ) = user.call{value: amount}("");
    require(success, "Transfer failed");
    
    emit Withdrawal(user, amount);
}
```

## Phase 4: Attack - Security Verification

### 4.1 Run Static Analysis

```bash
# Slither
slither . --config-file slither.config.json

# Mythril (symbolic execution)
myth analyze contracts/Vault.sol

# CodeQL
./scripts/run_codeql_baseline.sh
```

### 4.2 Manual Security Review

For each function, verify:

```markdown
## Security Review: Function [name]

### Access Control
- [ ] Function has appropriate modifier
- [ ] Modifier correctly implemented
- [ ] No bypass paths

### Input Validation
- [ ] All parameters validated
- [ ] Zero values handled
- [ ] Max values handled
- [ ] Array bounds checked

### State Consistency
- [ ] All state updates atomic
- [ ] Invariants maintained
- [ ] No partial updates possible

### External Interactions
- [ ] CEI pattern followed
- [ ] Return values checked
- [ ] Reentrancy protection

### Economic Security
- [ ] No flash loan vulnerabilities
- [ ] No price manipulation vectors
- [ ] Fee calculations correct
```

### 4.3 Fuzz Testing

```solidity
function testFuzz_Deposit(uint256 amount) public {
    vm.assume(amount > 0);
    vm.assume(amount <= address(this).balance);
    
    uint256 balanceBefore = vault.balanceOf(address(this));
    
    vault.deposit{value: amount}();
    
    assertEq(vault.balanceOf(address(this)), balanceBefore + amount);
}
```

### 4.4 Formal Verification (Advanced)

```solidity
// Certora or similar
rule totalSupplyEqualsSumOfBalances {
    uint256 sum = 0;
    address[] memory users = getAllUsers();
    
    for (uint i = 0; i < users.length; i++) {
        sum += balanceOf(users[i]);
    }
    
    assert sum == totalSupply();
}
```

## The Security TDD Loop

```
┌─────────────────────────────────────────────────────────────┐
│                    SECURITY TDD CYCLE                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│   1. WRITE TESTS                                            │
│      ├── Functional test (Red)                              │
│      ├── Security test (Red)                                │
│      └── Invariant test (Red)                               │
│                     ↓                                       │
│   2. IMPLEMENT                                              │
│      ├── Minimum code (Green)                               │
│      └── Security checks                                    │
│                     ↓                                       │
│   3. REFACTOR                                               │
│      ├── Clean code                                         │
│      └── Maintain security                                  │
│                     ↓                                       │
│   4. ATTACK                                                 │
│      ├── Static analysis                                    │
│      ├── Manual review                                      │
│      ├── Fuzz testing                                       │
│      └── Formal verification (optional)                     │
│                     ↓                                       │
│   5. VALIDATE                                               │
│      └── All security checks pass?                          │
│            ↓ NO                                             │
│            └── Return to step 1 with new attack vectors     │
│            ↓ YES                                            │
│            └── Feature complete and secure                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Common Security Test Patterns

### Reentrancy Test

```solidity
contract ReentrancyAttacker {
    Vault target;
    uint256 count;
    
    constructor(address _target) {
        target = Vault(_target);
    }
    
    function attack() external payable {
        target.deposit{value: msg.value}();
        target.withdraw(msg.value);
    }
    
    receive() external payable {
        if (count < 5) {
            count++;
            target.withdraw(msg.value);
        }
    }
}

function test_ReentrancyProtection() public {
    ReentrancyAttacker attacker = new ReentrancyAttacker(address(vault));
    
    vm.expectRevert();
    attacker.attack{value: 1 ether}();
}
```

### Access Control Test

```solidity
function test_OnlyOwnerCanMint() public {
    address nonOwner = address(0x1234);
    
    vm.prank(nonOwner);
    vm.expectRevert("Ownable: caller is not the owner");
    token.mint(nonOwner, 1000);
}
```

### Integer Overflow/Underflow Test

```solidity
function test_NoUnderflowOnWithdraw() public {
    // Try to withdraw more than balance
    vm.expectRevert();
    vault.withdraw(type(uint256).max);
}
```

### Oracle Manipulation Test

```solidity
function test_TwapResistantToFlashLoan() public {
    // Simulate flash loan manipulation
    // TWAP price should remain stable
}
```

## Integration with Ralph

The `/tdd` workflow is used when:
- Implementing fixes for reported vulnerabilities
- Creating new protocol features
- Refactoring existing code
- Developing test suites

It ensures security is built in from the start, not bolted on at the end.

## Success Metrics

- [ ] 100% of functions have unit tests
- [ ] 100% of external functions have security tests
- [ ] All invariants have invariant tests
- [ ] Static analysis passes (Slither: no high/critical)
- [ ] Fuzz testing runs without finding bugs (30+ minutes)
- [ ] Manual security review completed
