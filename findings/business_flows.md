# Business Flows - Snowbridge Contracts

## Inbound (Polkadot -> Ethereum)

1. Relayer submits `submitV1` or `v2_submit` with message + proofs.
2. Gateway derives commitment root from leaf proof.
3. `Verification` confirms commitment inclusion in finalized parachain header through BEEFY light client.
4. Gateway dispatches command(s) to internal handlers via self-call.
5. Handlers execute upgrades, mode updates, unlocks, mints, foreign token registration, or arbitrary contract call (V2).

## Outbound (Ethereum -> Polkadot)

1. User sends token/message via `sendToken`, `registerToken`, `v2_sendMessage`, or `v2_registerToken`.
2. Gateway validates mode and fee/value requirements.
3. Native assets are moved into AssetHub agent custody or foreign wrapped assets are burned.
4. Outbound nonce increments and payload event is emitted for relayer consumption.

## Core invariants to preserve

- Inbound message cannot be replayed.
- Only authenticated, finalized BridgeHub commitments can trigger privileged handlers.
- Asset unlock/mint only corresponds to legitimate cross-chain state transitions.
- Upgrade path must remain governance-controlled only.
- Outbound fee collection and value custody must be conserved and non-drainable.
