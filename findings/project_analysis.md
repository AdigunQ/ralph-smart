# Project Analysis - Snowbridge Contracts

## Target

- Repository: `Snowfork/snowbridge`
- Commit: `1cf39a26edf24bca92c3c330f6708a806cd142e6`
- Focused subtree: `contracts/`

## Architecture summary

- `Gateway` is the Ethereum bridge core handling inbound verification, dispatch, outbound message acceptance, fee and custody interactions.
- `BeefyClient` is the consensus anchor used by `Verification` to validate finalized BridgeHub commitments.
- `Agent` contracts are per-origin execution/custody proxies controlled by gateway logic.
- `AgentExecutor` is shared delegatecall code for transfers and contract calls from agent context.
- `GatewayProxy` + `Upgrade` implement ERC1967-style upgradeability.

## High-value trust boundaries

- Polkadot finality proof -> Ethereum execution (`Verification` + `BeefyClient`).
- Inbound command dispatch -> privileged handlers (`onlySelf` + `v1_handle*`/`v2_handle*`).
- Agent delegatecall boundary (`Functions.invokeOnAgent` -> `Agent.invoke`).
- Funds custody boundaries: gateway balance, asset-hub agent balances, minted/burned foreign token supply.

## Initial risk view

- Highest technical risk: message verification/dispatch correctness and privileged command gating.
- Highest economic risk: fee/refund/reward arithmetic and custody transfer paths.
- Highest integration risk: assumptions about BridgeHub/AssetHub origin semantics and command authenticity.
