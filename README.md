# Ralph Security Agent

Ralph is an autonomous smart-contract security auditing loop built for **hypothesis generation + deterministic verification + PoC-backed findings**.

## What Ralph Does

- Plans a full protocol audit (`IMPLEMENTATION_PLAN.md`)
- Hunts vulnerabilities task-by-task with taint models
- Runs deterministic checks first (CodeQL, attack surface, code index)
- Applies strict verification harness before reporting
- Enforces anti-hallucination output schemas and review gates

---

## Quick Start

```bash
chmod +x loop.sh scripts/*.sh
./loop.sh
```

Recommended:

```bash
COMPUTE_BUDGET=200 HARD_ENFORCEMENT=true ./loop.sh
```

Bug bounty mode:

```bash
BOUNTY_MODE=true HARD_ENFORCEMENT=true ./loop.sh
```

Lean/fast mode (reuse existing artifacts):

```bash
SKIP_PRECHECK=true CODEQL_REFRESH=false PRECHECK_REFRESH=false ./loop.sh
```

Preset lean mode:

```bash
LEAN_MODE=true ./loop.sh
```

EVMbench-style explicit task modes:

```bash
RALPH_MODE=DETECT ./loop.sh
RALPH_MODE=PATCH PATCH_TEST_CMD="forge test -vvv" PATCH_EXPLOIT_TEST_CMD="forge test --match-contract Exploit -vvv" ./loop.sh
RALPH_MODE=EXPLOIT EXPLOIT_CHECK_CMD="./scripts/check_exploit_state.sh" ./loop.sh
```

Default mode is `DETECT` (high-signal bug hunting).

Fast wrappers:

```bash
./scripts/run_detect.sh
./scripts/run_patch.sh
./scripts/run_exploit.sh
```

If Codex fails with repeated `stream disconnected` errors, verify outbound network access/auth for the Codex CLI environment.

If your target is not in `./target/`, Ralph will fall back to current directory if it detects `contracts/` or `src/`.

### Install CodeQL (once per machine/workspace)

```bash
./scripts/install_codeql.sh
export PATH="$PWD/.tools/codeql:$PATH"
```

For a cloned repo on a fresh machine, run the same two commands once.

One-command bootstrap for GitHub clones:

```bash
./scripts/bootstrap.sh
export PATH="$PWD/.tools/codeql:$PATH"
```

`bootstrap.sh` installs CodeQL and also attempts to fetch/update both optional knowledge repos (EIP handbook + protocol vulnerabilities index).

### EIP Handbook Integration (Optional, Recommended)

Ralph can import EIP/ERC heuristic checks from the EIP Security Handbook.

```bash
./scripts/fetch_eip_handbook.sh
python3 scripts/generate_eip_security_checklist.py \
  --target-dir ./target \
  --handbook-dir tools/EIP-Security-Handbook/src \
  --output findings/eip_security_checklist.md \
  --json-output findings/eip_security_checklist.json
```

### Protocol Vulnerabilities Index Integration (Optional, Recommended)

Ralph can also import protocol-specific vulnerability categories from the Protocol Vulnerabilities Index.

```bash
./scripts/fetch_protocol_vuln_index.sh
python3 scripts/generate_protocol_vuln_checklist.py \
  --target-dir ./target \
  --index-dir tools/protocol-vulnerabilities-index \
  --output findings/protocol_vulnerability_checklist.md \
  --json-output findings/protocol_vulnerability_checklist.json
```

---

## Core Methodology

### 1) Planning Phase

Ralph creates:
- `findings/project_analysis.md`
- `findings/business_flows.md`
- `findings/assumptions.md`
- `findings/external_integrations.md`
- `findings/integration_gaps.md`
- `IMPLEMENTATION_PLAN.md`

Planning is expected to include:
- Clarification gate (ambiguities and assumptions)
- Deterministic baseline
- External integration doc-first analysis

### 2) Building Phase

For each incomplete task:
1. Deterministic analysis first
2. Hypothesis generation (reverse scan)
3. Skeptic pass (fast disproof)
4. 6-step verification harness
5. PoC (for high/critical impact)
6. Task result artifact + status update

---

## Security Frameworks Used

- **6 Taint Models**: `INV`, `ASM`, `EXP`, `TMP`, `CMP`, `BND`
- **6-step Harness**: Observe → Reachability → Controllability → Impact → Demonstrate → Report
- **5-Gate Verification**: syntax, semantics, impact, exploitability, report quality
- **Adaptive Compute**: spend more on high-signal hypotheses
- **Scout/Strategist/Finalizer** orchestration pattern

See:
- `AGENTS.md`
- `knowledges/agentic_harness.md`
- `knowledges/verification_protocol.md`
- `knowledges/subagent_orchestration.md`

---

## External Integration Hunting (Mandatory)

Ralph explicitly hunts **integration mismatches**:

1. Confirm integration exists from protocol code
2. Pull official live docs for the exact integrated component
3. Compare required safeguards vs implemented code
4. Cite doc quote + protocol line references
5. Confirm only if reachability + controllability + impact are proven

Required artifacts:
- `findings/external_integrations.md`
- `findings/integration_gaps.md`
- `findings/docs_request.md` (if docs missing)

Reference:
- `knowledges/integration_hunting.md`

---

## Hard Enforcement

With `HARD_ENFORCEMENT=true` (default), Ralph auto-marks `NEEDS_REVIEW` when required artifacts are incomplete.

### Planning enforcement

Requires `findings/clarifications_needed.md` with:
- `clarification_status`
- `assumptions`
- `open_questions`

Also validates integration artifacts and evidence fields.

If `BOUNTY_MODE=true`, planning also requires:
- `findings/bounty_program_assessment.md` passing `scripts/lint_bounty_assessment.sh`

### Building enforcement

Requires `findings/tasks/<TASK-ID>/result.md` fields:
- `status`
- `confidence`
- `evidence`
- `assumptions`
- `scope_checked`
- `out_of_scope`
- `reachability`
- `controllability`
- `impact`
- `poc`
- `deterministic_signal_basis`
- `rejected_hypotheses_logged`
- `root_cause_primary`
- `root_cause_secondary`
- `patch_level`
- `counterfactual_fix`
- `five_whys_present`
- `deterministic_override_approved`
- `deterministic_override_rationale`

Also requires per-task artifact bundle:
- `findings/tasks/<TASK-ID>/hypotheses.md`
- `findings/tasks/<TASK-ID>/evidence.md`
- `findings/tasks/<TASK-ID>/repro.md`
- `findings/tasks/<TASK-ID>/rejected.md`
- `findings/tasks/<TASK-ID>/root_cause.md`

Preflight helper:

```bash
scripts/lint_task_result.sh findings/tasks/<TASK-ID>/result.md
scripts/lint_task_result.sh --v2 findings/tasks/<TASK-ID>/result.md
scripts/lint_iteration_artifacts.sh <TASK-ID>
scripts/lint_root_cause.sh findings/tasks/<TASK-ID>/root_cause.md
scripts/init_task_workspace.sh <TASK-ID>
scripts/migrate_to_v2.sh
```

Needs-review ledger:
- `findings/needs_review.md`

---

## Key Commands

| Command | Purpose |
|---|---|
| `./loop.sh` | Full autonomous audit loop |
| `RALPH_MODE=DETECT ./loop.sh` | Detection-only run with detect grader gate |
| `RALPH_MODE=PATCH ./loop.sh` | Patch-only run with test/exploit regression gate |
| `RALPH_MODE=EXPLOIT ./loop.sh` | Exploit-only run with tx/state gate |
| `./scripts/run_detect.sh` | Fast detect wrapper (recommended default) |
| `./scripts/run_patch.sh` | Fast patch wrapper |
| `./scripts/run_exploit.sh` | Fast exploit wrapper |
| `./scripts/fetch_eip_handbook.sh` | Clone/pull EIP Security Handbook into `tools/` |
| `./scripts/fetch_protocol_vuln_index.sh` | Clone/pull Protocol Vulnerabilities Index into `tools/` |
| `./scripts/run_codeql_baseline.sh` | Deterministic baseline queries |
| `./scripts/grade_detect.sh` | Deterministic detect grading |
| `./scripts/grade_patch.sh` | Deterministic patch grading |
| `./scripts/grade_exploit.sh` | Deterministic exploit grading |
| `python3 scripts/generate_eip_security_checklist.py ...` | Generate EIP/ERC heuristic checklist from handbook |
| `python3 scripts/generate_protocol_vuln_checklist.py ...` | Generate protocol-category checklist from index |
| `python3 scripts/rpc_gatekeeper.py --upstream <rpc>` | Block unsafe local-chain RPC methods |
| `python3 scripts/update_code_index.py ...` | Target code index |
| `python3 scripts/attack_surface.py ...` | Attack surface map |
| `scripts/lint_task_result.sh ...` | Validate task result schema |
| `scripts/lint_iteration_artifacts.sh ...` | Validate required task artifact bundle |
| `scripts/init_task_workspace.sh ...` | Create v2 task artifact files from templates |
| `scripts/migrate_to_v2.sh` | Backfill missing v2 artifacts for existing tasks |
| `scripts/lint_v2_tasks_from_paths.sh ...` | Lint v2 artifacts for changed task paths (hooks/CI) |
| `scripts/lint_root_cause.sh ...` | Validate RCA schema and anti-generic quality checks |
| `scripts/lint_finding_quality.sh ...` | Enforce exploitability/repro consistency for confirmed findings |
| `scripts/init_bounty_context.sh` | Initialize bounty program assessment context |
| `scripts/lint_bounty_assessment.sh ...` | Validate bounty ROI/fairness assessment |
| `scripts/snapshot_bounty_rules.sh <url> <label>` | Archive bounty rules before disclosure |

---

## Useful Env Vars

| Variable | Default | Purpose |
|---|---:|---|
| `MAX_ITERATIONS` | `50` | Stop condition |
| `RALPH_MODE` | `DETECT` | `AUTO`, `PLANNING`, `BUILDING`, `DETECT`, `PATCH`, `EXPLOIT` |
| `STOP_ON_SUCCESS` | `true` | Stop immediately when explicit mode passes its grader |
| `AUTO_COMMIT` | `false` | Auto-commit each iteration when set true |
| `COMPUTE_BUDGET` | `100` | Adaptive budget |
| `ADAPTIVE_MODE` | `true` | Budget-aware execution |
| `CODEX_HOME` | `./.codex-runtime` | Codex session/runtime directory (workspace-local by default in loop) |
| `HARD_ENFORCEMENT` | `true` | Enforce artifact schemas |
| `ENGINEERING_GUARDRAILS` | `false` | Global prompt guardrails |
| `GUARDRAILS_PROMPT_FILE` | `PROMPT_engineering.md` | Guardrails prompt file |
| `BOUNTY_MODE` | `false` | Enable bug-bounty pre-hunt gating/enforcement |
| `SKIP_PRECHECK` | `true` | Skip code index + attack surface regeneration |
| `PRECHECK_REFRESH` | `false` | Force regeneration of precheck artifacts |
| `EIP_HANDBOOK_DIR` | `tools/EIP-Security-Handbook/src` | Source directory for EIP handbook heuristics |
| `EIP_CHECKLIST_OUT` | `findings/eip_security_checklist.md` | Markdown output path for EIP checklist |
| `EIP_CHECKLIST_JSON` | `findings/eip_security_checklist.json` | JSON output path for EIP checklist |
| `EIP_CHECKLIST_REFRESH` | `false` | Force regeneration of EIP checklist |
| `PROTOCOL_VULN_INDEX_DIR` | `tools/protocol-vulnerabilities-index` | Source directory for protocol vulnerability index |
| `PROTOCOL_VULN_CHECKLIST_OUT` | `findings/protocol_vulnerability_checklist.md` | Markdown output path for protocol checklist |
| `PROTOCOL_VULN_CHECKLIST_JSON` | `findings/protocol_vulnerability_checklist.json` | JSON output path for protocol checklist |
| `PROTOCOL_VULN_CHECKLIST_REFRESH` | `false` | Force regeneration of protocol checklist |
| `LEAN_MODE` | `false` | Force high-throughput defaults |
| `DETECT_GROUND_TRUTH` | _(unset)_ | Ground-truth vulnerability list for detect recall grading |
| `DETECT_MIN_RECALL` | `0.80` | Minimum recall threshold for detect pass |
| `PATCH_TEST_CMD` | `forge test -vvv` | Baseline patch verification test command |
| `PATCH_EXPLOIT_TEST_CMD` | _(unset)_ | Exploit regression command (must fail post-patch) |
| `EXPLOIT_REPLAY_CMD` | _(unset)_ | Replay command used by exploit grader |
| `EXPLOIT_CHECK_CMD` | _(unset)_ | Exploit success check command |

Primary output artifacts:
- `submission/audit.md`
- `submission/patch.md`
- `submission/txs.md`
- `submission/exploit.md`

---

## Workflows

See `.agent/workflows/`:

- `/audit` – full autonomous audit
- `/hound` – deep relation-first reasoning
- `/verify` – skeptic/mutation-style verification
- `/tdd` – security-focused TDD loop
- `/spec [requirements-file]` – architect/critic spec refinement

CI:
- `.github/workflows/v2-task-lint.yml` lints changed `findings/tasks/*` artifacts on push/PR.

RCA taxonomy:
- `knowledges/root_cause_taxonomy.md`

---

## Recommended Reading

- `USAGE_GUIDE.md` (best onboarding doc)
- `BUG_BOUNTY_MODE.md` (bounty-specific workflow)
- `AGENTS.md` (operational doctrine)
- `PROMPT_plan.md` / `PROMPT_build.md` (agent behavior per phase)
- `knowledges/codeql_integration.md`
- `knowledges/spec_refinement_protocol.md`
- `knowledges/bug_bounty_playbook.md`

---

## One-Line Mission

Find real bugs, prove them rigorously, and never ship hallucinated findings.
