# Snowbridge Contracts Security Implementation Plan

- Target: `/Users/qeew/Desktop/ralph-security-agent/target/snowbridge-contracts/contracts`
- Commit: `1cf39a26edf24bca92c3c330f6708a806cd142e6`
- Date: 2026-02-06
- Mode: Bug bounty ROI + high-confidence exploitability

## Scope and constraints

- In scope (from program brief): on-chain Solidity and Rust paths with demonstrable impact.
- Priority impact classes: theft/loss of funds, unauthorized transactions, transaction manipulation, logic attacks, reentrancy, reordering, over/underflow.
- Out of scope to avoid: style/gas-only issues, theoretical-only reports, front-run-only claims, known invalid class (`message.origin` checks for V2 handlers), off-chain code-only issues.
- Cross-chain requirement: where exploitability depends on Polkadot side assumptions, include that dependency in verification and PoC notes.

## Deterministic triage status

- `codeql` binary is not available in this environment (`command not found`), so baseline CodeQL pass is blocked.
- Planning below is created from direct static analysis of Solidity sources and will use Foundry-based repros for confirmation.

## Attack surface map (contracts)

- Core entrypoints: `Gateway.submitV1`, `Gateway.v2_submit`, `Gateway.sendToken`, `Gateway.v2_sendMessage`, `Gateway.v2_registerToken`, `Gateway.v2_createAgent`.
- Privileged execution pivots: `v1_handle*`, `v2_handle*`, `Upgrade.upgrade`, `Functions.invokeOnAgent` -> `Agent.invoke` -> `delegatecall` into `AgentExecutor`.
- Consensus verification boundary: `Verification.verifyCommitment` + `BeefyClient.verifyMMRLeafProof`.
- Value-bearing flows: gateway ETH balance refunds/rewards, asset-hub agent custody, ERC20 pull/burn/mint paths.
- Upgrade boundary: `GatewayProxy` (ERC1967 slot), `Gateway.initialize`, `Gateway202509.initialize`.

## Checklist (Phase 2 tasks)

### CRITICAL

- [x] `SB-C-01` [ASM] Checked. No Ethereum-side unauthorized upgrade path found; `onlySelf` + initializer/proxy guards hold in reviewed paths.
- [x] `SB-C-02` [ASM] Reassessed with Polkadot-side docs: V2 unordered delivery is intentional protocol behavior, so this is not treated as a vulnerability by itself.
- [x] `SB-C-03` [EXP] Checked. No digest-kind confusion found: V1/V2 routes pin different marker bytes and Polkadot digest variant indices match Ethereum parser expectations.
- [x] `SB-C-04` [CMP] Confirmed candidate: reward-settlement mismatch allows relayer reward payout even when Ethereum dispatch reports `success=false` (grief/profit path on failure-sensitive commands). See `SB-2026-003`.
- [x] `SB-C-05` [ASM] Checked. No standalone Ethereum-side unauthorized movement found; arbitrary call behavior is origin-auth dependent and appears intentional.
- [x] `SB-C-06` [TMP] Checked. No external proxy reinitialization or initializer takeover path found; upgrade remains reachable only through authenticated inbound handler flow.
- [x] `SB-C-07` [INV] Reassessed with Polkadot-side encoding: `max_fee_per_gas` and `reward` are bounded to `u128` in committed V1 messages, removing practical overflow path on Ethereum payout arithmetic.
- [ ] `SB-C-08` [CMP] BridgeHub/AssetHub trust-boundary mismatch: prove/disprove exploit where valid Ethereum-side proof + compromised/incorrect origin semantics enables unauthorized token unlock.

### HIGH

- [ ] `SB-H-01` [ASM] Validate `onlySelf` boundary cannot be bypassed by internal/external call shape tricks for all `v1_handle*` and `v2_handle*` handlers.
- [ ] `SB-H-02` [EXP] Reentrancy stress on `submitV1` and `v2_submit` through external calls (native transfer refunds, agent delegate paths, token callbacks).
- [ ] `SB-H-03` [INV] Verify SparseBitmap nonce marking in `v2_submit` is safe against griefing through invalid proof spam and does not brick valid later submissions.
- [ ] `SB-H-04` [BND] Validate gas-limit checks (`63/64` rule + overhead constants) cannot be exploited for selective command skipping with payout side-effects.
- [ ] `SB-H-05` [ASM] Test unauthorized foreign token mint route (`HandlersV1.mintForeignToken`, `HandlersV2.mintForeignToken`) for missing origin/channel guard.
- [ ] `SB-H-06` [ASM] Validate `v2_createAgent` cannot be abused to front-run expected agent IDs and hijack trust assumptions for downstream call flows.
- [ ] `SB-H-07` [INV] Check token registration invariants to prevent native/foreign registry collision or state poisoning via repeated registration attempts.
- [ ] `SB-H-08` [EXP] Analyze `Agent.invoke` delegatecall surface for unexpected execution gadgets beyond `AgentExecutor` assumptions.
- [ ] `SB-H-09` [CMP] Verify unlocking native token from wrong agent cannot occur in v1/v2 unlock handlers under crafted payloads.
- [ ] `SB-H-10` [TMP] Validate operational-mode controls (`CoreStorage.mode`, channel mode) cannot be bypassed for outbound sends while rejected.
- [ ] `SB-H-11` [BND] Check `msg.value` handling in `CallsV2._sendMessage` for overflow/truncation/fee under-reservation edge cases at uint128 boundaries.
- [ ] `SB-H-12` [ASM] Ensure `GatewayProxy` fallback/receive behavior cannot trap or redirect funds in a way that violates bridge accounting.

### MEDIUM

- [ ] `SB-M-01` [INV] Audit fee conversion math (`_convertToNative`, multiplier/exchange rate) for rounding exploits that underpay required fees.
- [ ] `SB-M-02` [BND] Edge-case check for `dustThreshold` logic causing systematic refund withholding or forced dust accumulation.
- [ ] `SB-M-03` [INV] Validate max destination fee controls (`maxDestinationFee`) cannot be bypassed via destination or encoding edge cases.
- [ ] `SB-M-04` [ASM] Verify `registerToken` + outbound ticket construction cannot be abused for repeated fee extraction without meaningful state change.
- [ ] `SB-M-05` [EXP] Check ERC20 interaction assumptions in `SafeTransfer` paths against non-standard tokens (false return, revert behavior).
- [ ] `SB-M-06` [INV] Assess foreign token `Token` contract correctness (`permit`, nonce progression, allowance semantics) for mint/burn misuse.
- [ ] `SB-M-07` [TMP] Analyze BEEFY interactive ticket lifecycle (`submitInitial` -> `commitPrevRandao` -> `submitFinal`) for expiration and reuse race conditions.
- [ ] `SB-M-08` [BND] Validate bitfield padding/length checks in BeefyClient to avoid malformed proof acceptance.
- [ ] `SB-M-09` [EXP] Verify MMR proof order/index handling cannot be manipulated for false membership acceptance.
- [ ] `SB-M-10` [ASM] Check `registerForeignToken` metadata inputs (name/symbol/decimals) for storage/event abuse and downstream integration breakage.
- [ ] `SB-M-11` [CMP] Validate mixed asset batches in V2 cannot create imbalance between burned/moved assets and emitted outbound payload.
- [ ] `SB-M-12` [INV] Confirm event-level accountability fields (`rewardAddress`, nonce/topic) cannot misattribute relayer rewards or processing state.

### LOW

- [ ] `SB-L-01` [BND] Review extreme calldata sizes for inbound proof handling to detect gas bombs leading to practical DoS.
- [ ] `SB-L-02` [TMP] Check sequencing assumptions between V1 and V2 APIs during migration/parallel operation.
- [ ] `SB-L-03` [INV] Validate initialization defaults in `Initializer` and `Gateway202509` do not produce unsafe operational parameters.
- [ ] `SB-L-04` [EXP] Confirm no unexpected behavior from deprecated V1 command variants still present for compatibility.

## Execution protocol per task

- Generate 3-5 hypotheses per task (assume bug exists first).
- Prove reachability and controllability from real entrypoints.
- Produce PoC (Foundry test preferred) for any confirmed issue.
- Record negative evidence for rejected hypotheses to prevent repeats.
- Mark `[x]` only after verification harness is fully satisfied.

## Priority start order (first 6 tasks)

1. `SB-C-02` replay/nonce desync on inbound processing
2. `SB-C-05` arbitrary call-contract abuse via agent executor
3. `SB-C-01` upgrade authorization boundary
4. `SB-C-07` reward/refund drain path
5. `SB-H-05` unauthorized mint route v1/v2
6. `SB-H-03` v2 nonce bitmap griefing/lockout

## Confirmed findings so far

- `SB-2026-003`: V2 relayer rewards can be paid on failed Ethereum dispatch outcomes (`success=false`), enabling grief-profit behavior.
- `SB-2026-001` and `SB-2026-002` were reclassified after reviewing Polkadot-side implementation/docs (`findings/negative_evidence.md`).
