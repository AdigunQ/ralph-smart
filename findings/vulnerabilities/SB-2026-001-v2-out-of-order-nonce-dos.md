# SB-2026-001 - Reclassified (Not a Vulnerability)

## Final status

- Rejected after cross-chain verification.

## Why it was reclassified

- Ethereum-side observation was correct: `v2_submit` accepts non-sequential nonces.
- Polkadot-side V2 architecture explicitly specifies **unordered messaging** as intended behavior.
- Source: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/docs/v2.md:11`.

## Implication

- Out-of-order relay causing dependency breakage is a protocol/application design consideration, not a contract bug by itself.
- Dependent operations should be batched in one message or designed to be order-independent.

## Local PoC

- Test remains useful to demonstrate behavior:
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/test/GatewayV2.t.sol:568`
- It demonstrates intended unordered semantics, not exploitability beyond protocol expectations.
