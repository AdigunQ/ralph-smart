# Integration Gaps - Snowbridge Contracts

## Closed gaps

- V2 nonce ordering mismatch: closed (protocol is intentionally unordered).
- V1 payout field-bound uncertainty: closed (`u128` bounded fields in committed messages).
- V1/V2 digest marker ambiguity at Ethereum verification boundary: closed (marker + kind + route pinning align with Polkadot variant indices).
- Upgrade initializer takeover/reinit concern: closed (proxy selector block + initializer ERC1967 guard + onlySelf upgrade path).

## Remaining gaps

- Origin/auth assumptions for V2 `CallContract` remain dependent on BridgeHub/AssetHub runtime XCM alias/origin-preservation policy and live `AuthorizedAliasers` state; no standalone Ethereum exploit found, but runtime misconfiguration here could still create authorized-on-Ethereum abuse.
- BEEFY proof semantics should still be validated against current deployed runtime configuration and upgrade-era parameters, beyond repository-level static checks.
- Environment blocker: direct live RPC verification from this workspace is currently blocked by DNS resolution failures for public RPC hosts (`Could not resolve host`), so on-chain alias authorization state could not be fetched here.

## Next actions

1. Execute runtime-focused origin-preservation review for V2 (`SB-C-08`/`SB-H-01`) by tracing who can emit `AliasOrigin` patterns that converter accepts.
2. Pull live on-chain `pallet_xcm` alias authorization state for BridgeHub/AssetHub and verify no permissive alias entries can map into privileged Ethereum-origin agent IDs.
3. Validate BEEFY proof assumptions against chain-config reality (light-client constants and runtime feature flags) as a deployment-specific check.

## External verification command (run on unrestricted network)

1. Connect to BridgeHub/AssetHub RPC with polkadot.js and inspect:
   - `polkadotXcm.authorizedAliasers` (all entries)
   - `polkadotXcm.remoteLockedFungibles` (sanity for related cross-chain controls)
2. Confirm no alias entries allow untrusted locations to impersonate bridged Ethereum-origin locations consumed by Snowbridge V2 exporters.
