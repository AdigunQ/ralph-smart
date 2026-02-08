# Assumptions - Snowbridge Contracts Hunt

- BridgeHub is the only intended source of valid inbound commitments on Ethereum.
- Relayers are untrusted and may submit malformed calldata, stale data, or adversarial gas settings.
- Any successful exploit must be demonstrable with realistic preconditions under on-chain rules.
- Rust/Polkadot-side behavior may be required to fully prove cross-chain exploitability for some hypotheses.
- No trust is placed in token contract behavior beyond explicit checks; non-standard ERC20 behavior is considered adversarial.
