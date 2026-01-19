# Example: DeFi Lending Protocol Audit Specification

## Project Overview

**Project Name**: ExampleLend  
**Platform**: Ethereum (Solidity 0.8.19)  
**Project Type**: DeFi Over-Collateralized Lending  
**Audit Date**: 2026-01-19

## Scope

### In-Scope

- `contracts/LendingPool.sol` - Core lending logic (deposit, borrow, repay, liquidate)
- `contracts/InterestRateModel.sol` - Interest rate calculation
- `contracts/PriceOracle.sol` - Chainlink price aggregator
- `contracts/LPToken.sol` - Liquidity provider token (ERC-20)

### Out-of-Scope

- OpenZeppelin imports
- Frontend code
- Deployment scripts

## Project Description

ExampleLend is an over-collateralized lending protocol similar to Aave/Compound. Users can:

1. Deposit supported assets (ETH, WBTC, USDC) to earn interest
2. Borrow against their deposits (up to 75% collateral ratio)
3. Earn LP tokens representing their deposit share
4. Liquidators can liquidate undercollateralized positions for a 5% bonus

## Key Business Flows

### Flow 1: Deposit

User → `deposit(USDC, 1000)` → receive LP tokens → earn interest

### Flow 2: Borrow

User → `borrow(ETH, 0.5)` → check collateral ratio → transfer ETH → accrue interest debt

### Flow 3: Repay

User → `repay(ETH, 0.5 + interest)` → reduce debt → potentially unlock collateral

### Flow 4: Liquidation

Liquidator → `liquidate(undercollateralizedUser)` → repay debt → receive collateral + 5% bonus

## Critical Assumptions

1. **Collateral ratio always enforced**: Users cannot borrow if collateral < debt \* 1.33
2. **Oracle prices are fresh**: Price staleness checked (< 1 hour)
3. **Interest compounds correctly**: `totalDebt = principal * (1 + rate)^time`
4. **LP tokens proportional to deposits**: `lpTokens / totalLP = userDeposit / totalDeposits`
5. **Liquidation is always profitable**: 5% bonus > gas costs

## Priority Areas

### CRITICAL

- **INV-001**: Verify `totalDeposits == Σ(user deposits)` invariant
- **INV-002**: Verify `totalBorrowed <= totalDeposits * utilizationCap`
- **ASM-001**: Verify collateral ratio check in `borrow()`
- **EXP-001**: Check reentrancy on `withdraw()`
- **CMP-001**: Flash loan + price manipulation attack vector

### HIGH

- **EXP-002**: Oracle price staleness validation
- **TMP-001**: Interest accrual state machine
- **BND-001**: Zero amount handling in all functions

### MEDIUM

- **BND-002**: MAX_UINT overflow in interest calculations
- Access control on admin functions

## Known Risks

- Admin can pause the protocol (centralization risk)
- Chainlink oracle dependency (if Chainlink fails, protocol freezes)
- ETH price volatility can cause mass liquidations

## Success Criteria

- [ ] All invariants verified to hold
- [ ] No reentrancy vulnerabilities
- [ ] Oracle manipulation not possible
- [ ] Collateral ratio always enforced
- [ ] Interest calculations correct
- [ ] No fund drainage attack vectors
