# Temporal Taint Model (TMP)

## Definition

Focus on **state machine transitions** and **time-based logic**. Can the system enter illegal states, skip required stages, or allow time manipulation?

## Core Question

> "Can an attacker force the system into a state it shouldn't be in, or bypass time-based restrictions?"

## Taint Framework

| Component     | Description                                                                   |
| ------------- | ----------------------------------------------------------------------------- |
| **SOURCE**    | State transitions, time checks (`block.timestamp`), phase flags, status enums |
| **SINK**      | Illegal state reached, required phase skipped, time constraint bypassed       |
| **SANITIZER** | State transition guards, immutable phase progression, time validation         |

## Common Patterns

### 1. State Machine Violations

```solidity
enum Status { Pending, Active, Completed }

function finalize() external {
    // ❌ Missing: require(status == Active)
    status = Status.Completed;
}
```

**Attack**: Jump from Pending directly to Completed

### 2. Time Manipulation

```solidity
// ❌ Using block.timestamp for critical logic
require(block.timestamp > deadline);  // Miner can manipulate ±15 seconds
```

**Better**: Use `block.number` for rough time, or accept manipulation margin

### 3. Phase Skipping

```solidity
// Whitelist phase → Public phase
function mint() external {
    // ❌ Missing: require(block.timestamp > whitelistEndTime)
    _mint(msg.sender, 1);
}
```

## Detection (Reverse Scan)

Assert temporal violations exist:

- "Users CAN mint during whitelist phase even if not whitelisted"
- "Auctions CAN be finalized before end time"
- "Locked tokens CAN be withdrawn early"
- "Paused contracts CAN still execute functions"

## State Machines to Map

- Crowdfunding: Funding → Success/Failed → Claimed
- Auctions: Open → Bidding → Finalized
- Vesting: Locked → Vesting → Fully Unlocked
- Governance: Proposed → Voting → Queued → Executed
