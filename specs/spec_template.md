# Audit Specification Template

## Project Overview

**Project Name**: [Project Name]  
**Platform**: [Ethereum / Solana / Aptos / Sui / etc.]  
**Project Type**: [DeFi Lending / NFT Marketplace / DAO / GameFi / etc.]  
**Audit Date**: [Start - End Date]  
**Auditor**: [Your Name/Team]

## Scope

### In-Scope Contracts/Modules

List all files to be audited:

- `contracts/Token.sol` - Main token contract (ERC-20)
- `contracts/LendingPool.sol` - Core lending logic
- `contracts/Oracle.sol` - Price oracle integration
- ...

### Out-of-Scope

Components explicitly excluded:

- Third-party dependencies (OpenZeppelin, etc.)
- Test contracts
- Migration scripts

## Project Description

[2-3 paragraphs describing]:

- What the protocol does
- Who are the users
- What are the main use cases
- What value does it provide

## Key Business Flows

Identify critical user journeys:

### Flow 1: Deposit and Borrow

1. User deposits collateral (ETH)
2. System updates collateral balance
3. User requests loan (USDC)
4. System checks collateral ratio
5. System transfers USDC to user
6. System records debt

### Flow 2: Liquidation

1. Price oracle updates collateral value
2. If collateral < debt \* ratio, position becomes liquidatable
3. Liquidator calls `liquidate(user)`
4. Liquidator repays user's debt
5. Liquidator receives discounted collateral
6. System updates balances

## Critical Assumptions to Verify

What does the project ASSUME to be true?

- **Assumption 1**: Users must deposit before borrowing
  - **Verify**: Is this enforced in code?
- **Assumption 2**: Oracle prices are always fresh (< 1 hour old)
  - **Verify**: Is staleness checked?
- **Assumption 3**: Only admin can upgrade contracts
  - **Verify**: Is access control secure?

## Priority Areas

Rank by importance:

### 1. CRITICAL - Funds Safety

- Lending pool accounting
- Collateral ratio enforcement
- Oracle price manipulation
- Reentrancy protection

### 2. HIGH - Access Control

- Admin privileges
- Upgrade mechanisms
- Emergency pause functions

### 3. MEDIUM - Business Logic

- Interest rate calculations
- Fee distribution
- Reward mechanisms

### 4. LOW - Code Quality

- Gas optimizations
- Code organization
- Best practices

## Known Issues / Accepted Risks

Document intentional design decisions:

- "We use block.timestamp knowing miners can manipulate ±15 seconds"
- "Admin has emergency pause power (centralization risk accepted)"

## Verification Methodology

This audit follows the 6-Step Verification Harness:

1. **Observation** - Identifying anomalous code patterns
2. **Reachability Analysis** - Can the vulnerable code be reached?
3. **Controllability Assessment** - Can an attacker control the inputs?
4. **Impact Quantification** - What's the maximum damage?
5. **PoC Development** - Concrete exploit demonstration
6. **Report Documentation** - Structured finding with fix recommendations

### Pattern Matching Phase

Before deep analysis, run pattern matching against Solodit's 50k+ vulnerability database:

```bash
python scripts/pattern_matcher.py /path/to/project --format report
```

This identifies historically similar vulnerabilities and provides context for findings.

### Taint Model Application

Apply all 6 taint models to each critical function:

| Model | Focus | Key Question |
|-------|-------|--------------|
| **INV** | Invariants | What must always be true? |
| **ASM** | Access Control | Who can call this? |
| **EXP** | Oracle Manipulation | Where does price data come from? |
| **TMP** | Timing/Ordering | Does order of operations matter? |
| **CMP** | Complex Logic | Where are the edge cases? |
| **BND** | Boundary Conditions | What are the limits? |

### 5-Gate Verification

Each finding must pass through 5 verification gates:

1. ✅ **Syntactic** - Code pattern is actually suspicious
2. ✅ **Semantic** - The logic flaw is real
3. ✅ **Impact** - Severity is correctly assessed
4. ✅ **Exploitability** - Attack path is feasible
5. ✅ **Report Quality** - Documentation is complete

## Success Criteria

Audit is considered complete when:

- [ ] All CRITICAL areas thoroughly analyzed
- [ ] 6 taint models applied to all in-scope contracts
- [ ] Pattern matching run and results reviewed
- [ ] CodeQL baseline analysis completed (if applicable)
- [ ] All findings pass 5-gate verification
- [ ] All HIGH/CRITICAL findings have working PoCs
- [ ] Report delivered with severity ratings
- [ ] Recommendations provided for all issues
- [ ] Fix validation completed (if applicable)
