# Negative Evidence Ledger


## 2026-02-06 - SB-C-05 (v2_handleCallContract)

- Hypothesis: `v2_handleCallContract` can be called directly by an attacker to move agent funds.
- Result: Rejected. Handler is gated by `onlySelf` in `Gateway.v2_handleCallContract`, preventing direct external invocation.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:509` and `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/test/GatewayV2.t.sol:1139`.

- Hypothesis: An attacker can spoof agent identity in `callContract` and drain arbitrary agent balances from Ethereum side.
- Result: Rejected (Ethereum-side only). Agent is selected from `message.origin` and requires message authenticity from commitment proof path; relayer cannot alter payload after finalization.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/v2/Handlers.sol:67` and `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:422`.

- Hypothesis: `callContract` can bypass internal unlock restrictions to transfer ETH/ERC20 unexpectedly.
- Result: Partially true by design, not standalone vuln. Arbitrary call ability is an intended capability for authenticated origin agents; exploitability depends on cross-chain origin-auth failure, which is outside pure Ethereum proof here.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/AgentExecutor.sol:26` and bounty explicit warning about `message.origin`-class reports.

## 2026-02-06 - SB-C-01 (Upgrade authorization)

- Hypothesis: Arbitrary external caller can trigger upgrade path directly.
- Result: Rejected. Upgrade handlers are `onlySelf` and external direct calls revert with `Unauthorized`.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:57`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:484`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/test/GatewayV2.t.sol:1139`.

- Hypothesis: Proxy can be reinitialized externally to seize control.
- Result: Rejected. Proxy `initialize(bytes)` reverts and logic `initialize` checks ERC1967 slot guard.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/GatewayProxy.sol:25`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Initializer.sol:42`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/upgrade/Gateway202509.sol:14`.

- Hypothesis: Upgrade writes implementation before initializer call, enabling partial upgrade state on initializer revert.
- Result: Rejected (EVM atomicity). Revert from initializer bubbles and reverts prior `ERC1967.store` in same transaction.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Upgrade.sol:30`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Upgrade.sol:35`.

## 2026-02-06 - Cross-chain reassessment (polkadot-sdk Snowbridge)

- Hypothesis: V2 non-sequential nonce handling on Ethereum is an unintended vulnerability.
- Result: Rejected. V2 protocol explicitly defines unordered messaging as intended behavior.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/docs/v2.md:11`.

- Hypothesis: V1 relayer payout arithmetic overflow is reachable via oversized message fields from Polkadot.
- Result: Rejected under canonical message path. Polkadot outbound-queue commits `max_fee_per_gas` and `reward` as `u128`, and bounded conversions are used when building committed messages.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/types.rs:35`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/types.rs:38`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/lib.rs:346`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/lib.rs:350`.

## 2026-02-06 - SB-C-03 (Digest boundary confusion)

- Hypothesis: Commitment verification can be bypassed by mixing V1/V2 digest encodings or digest kind confusion.
- Result: Rejected. Ethereum checks both `DigestItem::Other` kind and a version-specific leading marker byte (`0x00` V1, `0x01` V2), and the call sites hardcode protocol mode (`submitV1` -> `false`, `v2_submit` -> `true`).
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Verification.sol:144`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:162`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:430`.

- Hypothesis: Polkadot runtime emits incompatible digest variant ordering, enabling cross-version acceptance.
- Result: Rejected. Polkadot encodes `Snowbridge` at codec index `0` and `SnowbridgeV2` at codec index `1`, which maps to Ethereum marker-byte parsing.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/primitives/core/src/digest_item.rs:24`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/primitives/core/src/digest_item.rs:27`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:331`.

## 2026-02-06 - SB-C-06 (Upgrade initializer takeover)

- Hypothesis: External actor can reinitialize proxy storage via `initialize(bytes)` selector path.
- Result: Rejected. Proxy defines `initialize(bytes)` and always reverts, so fallback cannot delegate that selector to implementation.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/GatewayProxy.sol:25`.

- Hypothesis: Implementation initializer can be called directly to mutate proxy state without authenticated upgrade flow.
- Result: Rejected. Initializer requires ERC1967 implementation slot to be set; direct calls to implementation revert.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Initializer.sol:42`.

- Hypothesis: `Upgrade.upgrade` can be reached by untrusted caller and used to pivot implementation.
- Result: Rejected (Ethereum-side path). Upgrade library entry is only exposed through `onlySelf` handler dispatch.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:489`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/v2/Handlers.sol:29`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Upgrade.sol:15`.

## 2026-02-06 - SB-C-08/SB-H-01 (V2 origin-preservation cross-chain abuse)

- Hypothesis: Any AssetHub user can spoof `AliasOrigin` and force privileged Ethereum `origin` in V2 `CallContract`.
- Result: Not confirmed. Runtime configs show aliasing is policy-gated (`AliasChildLocation` + `AuthorizedAliasers`) and frontend ingress to BridgeHub is constrained to a specific XCM location. No deterministic spoof path proven from code alone.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/asset-hub-westend-xcm_config.rs:387`, `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/asset-hub-westend-xcm_config.rs:469`, `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-xcm_config.rs:201`, `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-bridge_to_ethereum_config.rs:323`.

- Live-state check status: Blocked in this environment due DNS resolution failures for public RPC hosts, so `pallet_xcm::AuthorizedAliasers` on-chain entries could not be enumerated from this workspace.

## 2026-02-06 - SB-C-04 (cross-command partial failure abuse)

- Hypothesis: Partial command failures are purely observational and cannot create economic exploitation.
- Result: Rejected. Cross-chain settlement logic pays relayer rewards even when Ethereum emits `success=false` and then clears pending order, creating an exploitable grief-profit path for failure-sensitive messages.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:435`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/primitives/outbound-queue/src/v2/delivery_receipt.rs:24`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:464`, `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:468`.
