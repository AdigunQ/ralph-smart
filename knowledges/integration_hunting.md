# External Integration Hunting Guide

This guide captures a high-yield method: **find critical bugs by comparing how a project integrates with external systems versus how those systems are documented to be used.**

## Goal

Identify **integration mismatches** and **missing defenses** by:
1. Mapping external integrations (oracles, DEXes, lending protocols, bridges, keepers).
2. Reading integrator docs/assumptions.
3. Proving the code does *not* implement required protections.

## Outputs (Required Artifacts)

- `findings/external_integrations.md`
- `findings/integration_gaps.md`

## Step 1: Map Integrations

Look for:
- Interfaces or adapters (`IChainlinkAggregator`, `IUniswapV3Pool`, `IAavePool`)
- Address constants and registry lookups
- External calls to off-repo contracts
- Comments like "oracle", "price feed", "router", "bridge", "sequencer"

Record each integration:

```markdown
### Integration: Chainlink Price Feed
Contracts: `Oracle.sol`, `Vault.sol`
Entry Points: `updatePrice()`, `deposit()`
Critical Assumptions: stale checks, decimals alignment, sequencer uptime
```

Be explicit and conservative:
- Confirm the integration is real from code evidence (imports, interfaces, callsites, addresses).
- If uncertain, mark as `UNCONFIRMED` and do not proceed to vulnerability claims.

## Step 2: Read Integrator Docs (Doc-First)

Extract the **required invariants** and **recommended defenses** *only from the official documentation for the integration you found*.

**No generic checklists**. If a requirement is not in the docs, do not assume it.

Doc sourcing rules:
1. Prefer live official docs website for the integrator.
2. Save fetched docs locally under `specs/external_docs/`.
3. Record exact doc URLs and local paths.
4. Quote short requirement excerpts and locations.

## Step 3: Compare to Code (Mismatch Scan)

For each requirement, verify whether the code:
- Implements the check
- Enforces the invariant
- Logs and handles failure

If not, create a **specific hypothesis** grounded in the docs:

```markdown
Hypothesis: `Vault.sol::deposit()` uses Chainlink price without staleness guard.
Impact: stale feed -> mispriced shares -> loss.
Evidence: `Vault.sol:142-185` missing `updatedAt` check.
```

## Step 4: Verification Harness

Each mismatch must pass the standard harness:
- Reachability
- Controllability
- Impact
- PoC for high/critical issues

If uncertain, mark as `PRUNED` or `NEEDS_REVIEW`.

## Evidence Rules (False-Positive Control)

Do not report unless:
- You can point to the exact missing guard
- You can show the external docs require it
- You can show attacker reachability and impact

### Required Evidence Fields

For each integration mismatch:
- Doc URL
- Local doc file path (in `specs/external_docs/`)
- Exact quoted requirement (short excerpt)
- Code reference (file + line range)
- Verdict (`CONFIRMED`, `PRUNED`, `NEEDS_REVIEW`)

## Required Artifact Schema

`findings/external_integrations.md`:

```markdown
integration_status: NONE | FOUND

## Integration: <name>
confidence: CONFIRMED | UNCONFIRMED
official_doc_url: <https://...>
local_doc_path: <specs/external_docs/...>
integrated_component: <what part of integrator is used>
code_reference: <target/path/File.sol:line-range>
```

`findings/integration_gaps.md`:

```markdown
## Gap: <title>
integrator: <name>
doc_requirement_quote: "<short quote>"
doc_reference: <url or local section>
code_reference: <target/path/File.sol:line-range>
mismatch: <what is missing or inconsistent>
verdict: CONFIRMED | PRUNED | NEEDS_REVIEW
```

## Missing Docs Policy

If official docs are not available locally:

1. Record the missing docs in `findings/docs_request.md`
2. Mark related hypotheses as `NEEDS_REVIEW`
3. Do **not** confirm a vulnerability without doc-backed requirements
