# SB-2026-003 - V2 Relayer Reward Paid Even When Ethereum Dispatch Fails

## Severity

- High

## Summary

In Snowbridge V2, the relayer reward on BridgeHub is paid and the pending order is finalized even if Ethereum reports `success = false` for message dispatch.

This creates an incentive-compatible grief path: a malicious relayer can force a target command batch to fail (for failure-sensitive calls) and still collect the full reward.

## Code Evidence

- Ethereum emits success/failure explicitly:
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:435`
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/v2/IGateway.sol:33`
- Delivery receipt carries `success`:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/primitives/outbound-queue/src/v2/delivery_receipt.rs:24`
- BridgeHub reward logic ignores `success` and always pays if pending order exists:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:464`
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:468`
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:475`

## Exploit Path

1. User message enters V2 outbound queue with fee `r` in `PendingOrders[nonce]`.
2. Malicious relayer prepares Ethereum state so target command batch fails (e.g. failure-sensitive `CallContract` path).
3. Relayer submits `v2_submit` first, setting reward address to attacker-controlled account.
4. Gateway emits `InboundMessageDispatched(nonce, topic, success=false, rewardAddress=attacker)`.
5. Relayer submits delivery receipt proof on BridgeHub.
6. BridgeHub pays reward and removes pending order without checking `success`.
7. User operation fails and cannot be retried under same nonce; attacker still captures reward.

## Impact

- Fee theft / reward extraction for failed deliveries.
- Incentivized censorship/griefing on failure-sensitive messages.
- Degrades user trust: paying for non-delivery outcome.

## PoC Artifact

- Added deterministic unit-test PoC to show current behavior:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/test.rs`
  - test name: `delivery_receipt_with_failed_dispatch_still_pays_reward`
- Local execution in this workspace is blocked by sparse checkout workspace manifest gap (missing non-sparse workspace members), but test logic is self-contained for maintainers to run in full repo.

## Recommended Remediation

1. Gate reward payment on `receipt.success == true` by default.
2. If compensating failed deliveries is desired, separate it into a distinct reduced compensation path with explicit policy and caps.
3. Include `topic` consistency checks against stored pending message metadata before reward settlement.
