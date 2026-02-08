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
COMPUTE_BUDGET=200 DOCS_DISCOVERY=true HARD_ENFORCEMENT=true ./loop.sh
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

If your target is not in `./target/`, Ralph will fall back to current directory if it detects `contracts/` or `src/`.

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
| `./scripts/run_codeql_baseline.sh` | Deterministic baseline queries |
| `python3 scripts/update_code_index.py ...` | Target code index |
| `python3 scripts/attack_surface.py ...` | Attack surface map |
| `scripts/lint_task_result.sh ...` | Validate task result schema |
| `scripts/lint_iteration_artifacts.sh ...` | Validate required task artifact bundle |
| `scripts/init_task_workspace.sh ...` | Create v2 task artifact files from templates |
| `scripts/migrate_to_v2.sh` | Backfill missing v2 artifacts for existing tasks |
| `scripts/lint_v2_tasks_from_paths.sh ...` | Lint v2 artifacts for changed task paths (hooks/CI) |
| `scripts/lint_root_cause.sh ...` | Validate RCA schema and anti-generic quality checks |
| `scripts/generate_root_cause_clusters.sh ...` | Build recurrence report across task RCAs |
| `scripts/lint_finding_quality.sh ...` | Enforce exploitability/repro consistency for confirmed findings |
| `scripts/generate_benchmark_summary.sh ...` | Generate quality/evidence benchmark snapshot |
| `scripts/init_bounty_context.sh` | Initialize bounty program assessment context |
| `scripts/lint_bounty_assessment.sh ...` | Validate bounty ROI/fairness assessment |
| `scripts/snapshot_bounty_rules.sh <url> <label>` | Archive bounty rules before disclosure |

---

## Useful Env Vars

| Variable | Default | Purpose |
|---|---:|---|
| `MAX_ITERATIONS` | `50` | Stop condition |
| `COMPUTE_BUDGET` | `100` | Adaptive budget |
| `ADAPTIVE_MODE` | `true` | Budget-aware execution |
| `DOCS_DISCOVERY` | `false` | Discover/fetch integration docs |
| `DOCS_FETCH` | `false` | Fetch docs from URL list |
| `HARD_ENFORCEMENT` | `true` | Enforce artifact schemas |
| `ENGINEERING_GUARDRAILS` | `true` | Global prompt guardrails |
| `GUARDRAILS_PROMPT_FILE` | `PROMPT_engineering.md` | Guardrails prompt file |
| `BOUNTY_MODE` | `false` | Enable bug-bounty pre-hunt gating/enforcement |
| `SKIP_PRECHECK` | `false` | Skip code index + attack surface regeneration |
| `PRECHECK_REFRESH` | `false` | Force regeneration of precheck artifacts |
| `LEAN_MODE` | `false` | Force high-throughput defaults (skip precheck/docs refresh side-work) |

Key output artifacts:
- `findings/root_cause_clusters.md`
- `findings/benchmark_summary.md`

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
