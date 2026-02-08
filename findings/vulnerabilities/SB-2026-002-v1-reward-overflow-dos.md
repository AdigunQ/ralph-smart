# SB-2026-002 - Reclassified (Not Exploitable Under Real Message Bounds)

## Final status

- Rejected after cross-chain verification.

## Why it was reclassified

- Initial PoC used synthetic `uint256`-max values directly at Ethereum contract boundary.
- Real V1 committed messages on Polkadot encode both fields as `u128`:
  - `max_fee_per_gas: u128`
  - `reward: u128`
  - Source: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/types.rs:35` and `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/types.rs:38`.
- Conversion into committed message is explicitly bounded to `u128`:
  - Source: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/lib.rs:346` and `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/lib.rs:350`.

## Implication

- The demonstrated overflow path is not reachable through canonical Polkadot->Ethereum message production.
- Remaining risk would require non-canonical message forging that bypasses the authenticated Snowbridge commitment path.

## Local PoC note

- Test still demonstrates arithmetic sensitivity under unrealistic input:
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/test/GatewayV1.t.sol:584`
- It should not be used as a bounty submission in current protocol assumptions.
