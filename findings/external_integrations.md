# External Integrations - Snowbridge Contracts

## Confirmed integrations from code

- Polkadot BEEFY protocol assumptions via `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/BeefyClient.sol` and `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Verification.sol`.
- BridgeHub/AssetHub routing and agent model via `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Constants.sol`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Initializer.sol`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/v1/*`, `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/v2/*`.

## Cross-chain doc/code comparison completed

- Official docs/code base used: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge` at commit `21d020f29cdca81d78563c200874822cc9674671`.

### Check A: V2 nonce ordering expectations

- Doc requirement: V2 is explicitly unordered.
- Evidence: `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/docs/v2.md:11`.
- Ethereum behavior parity: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:418`.
- Verdict: Match (design-intended behavior).

### Check B: V1 payout field bounds reaching Ethereum

- Polkadot committed message fields are bounded to `u128`:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/types.rs:35`
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/types.rs:38`
- Polkadot builder enforces bounded conversion into committed message:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/lib.rs:346`
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue/src/lib.rs:350`
- Governance control on pricing parameter updates:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/system/src/lib.rs:321`
- Verdict: Ethereum overflow PoC based on `uint256::MAX` fields is non-canonical and not reachable via normal authenticated message flow.

### Check C: V1/V2 digest-item compatibility at verification boundary

- Ethereum digest parser requires:
  - `DigestItem::Other` kind
  - exact 33-byte payload
  - version marker byte (`0x00` V1, `0x01` V2)
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Verification.sol:149`
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Verification.sol:151`
- Ethereum route pins protocol version per entrypoint:
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:162`
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:430`
- Polkadot digest variant encoding:
  - `Snowbridge` index `0`, `SnowbridgeV2` index `1`
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/primitives/core/src/digest_item.rs:24`
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/primitives/core/src/digest_item.rs:27`
- Verdict: Match (no cross-version digest confusion path identified).

### Check D: Runtime origin-aliasing policy for V2 `AliasOrigin` path

- BridgeHub Westend runtime config:
  - `Aliasers` is `TrustedAliasers = (AliasChildLocation, AuthorizedAliasers<Runtime>)`
  - Snowbridge V2 exporter is active in `MessageExporter`
  - Evidence:
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-xcm_config.rs:201`
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-xcm_config.rs:240`
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-xcm_config.rs:248`
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-bridge_to_ethereum_config.rs:69`

- AssetHub Westend runtime config:
  - `Aliasers` is also `TrustedAliasers = (AliasChildLocation, AuthorizedAliasers<Runtime>)`
  - Ethereum V2 export table uses `XcmForSnowbridgeV2` filter and universal alias mappings for inbound bridge locations.
  - Evidence:
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/asset-hub-westend-xcm_config.rs:387`
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/asset-hub-westend-xcm_config.rs:469`
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/asset-hub-westend-xcm_config.rs:742`
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/asset-hub-westend-xcm_config.rs:769`

- Frontend gating (BridgeHub side):
  - V2 frontend origin must come from AssetHub frontend pallet location (`EnsureXcm<AllowFromEthereumFrontend>`).
  - Evidence:
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-bridge_to_ethereum_config.rs:307`
    - `/Users/qeew/Desktop/ralph-security-agent/findings/external_docs/polkadot-sdk-master/bridge-hub-westend-bridge_to_ethereum_config.rs:323`

- Interim verdict:
  - No direct Ethereum-side bypass found.
  - Residual risk remains configuration-sensitive: any incorrect `AuthorizedAliasers` governance state could potentially shift effective origin control.

### Check E: Delivery receipt semantics vs reward settlement

- Ethereum side emits explicit dispatch result in event:
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/Gateway.sol:435`
  - `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts/src/v2/IGateway.sol:33`
- Polkadot receipt parser preserves `success` bit:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/primitives/outbound-queue/src/v2/delivery_receipt.rs:24`
- Outbound queue V2 reward settlement does not use `success` and settles reward if nonce exists:
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:464`
  - `/Users/qeew/Desktop/ralph-security-agent/target/polkadot-sdk-snowbridge/bridges/snowbridge/pallets/outbound-queue-v2/src/lib.rs:468`
- Verdict: Mismatch with exploitable incentive implications (see `SB-2026-003`).
