# Ralph v2 Upgrade: Artifact Schemas, Enforcement, and Migration

This document defines the concrete v2 rollout added to this repository.

## Objectives

1. Enforce strict per-iteration artifacts for BUILDING tasks.
2. Preserve backward compatibility where possible.
3. Provide an explicit migration path for existing `findings/tasks/*`.

## New Required Task Artifacts

For every task `findings/tasks/<TASK-ID>/`, v2 requires:

1. `hypotheses.md`
2. `evidence.md`
3. `repro.md`
4. `rejected.md`
5. `root_cause.md`
6. `result.md`

Templates live in `findings/_templates/task/`.

## v2 Schema Keys

### `hypotheses.md`

- `task_id`
- `deterministic_signal_basis` (`CODEQL|NONE|MIXED`)
- `hypothesis_count`
- `hypotheses` (list)

### `evidence.md`

- `task_id`
- `suspicious_behavior`
- `reachability`
- `controllability`
- `impact`
- `code_references` (list)

### `repro.md`

- `task_id`
- `reproduction_status` (`CONFIRMED|PRUNED|NEEDS_REVIEW|BLOCKED`)
- `environment`
- `steps` (list)
- `assertions` (list)

### `rejected.md`

- `task_id`
- `rejected_count`
- `rejected_hypotheses` (list)

### `result.md` (v2 hard enforcement)

Base:
- `status`
- `confidence`
- `evidence`
- `assumptions`
- `scope_checked`
- `out_of_scope`

v2 additions:
- `reachability`
- `controllability`
- `impact`
- `poc`
- `deterministic_signal_basis` (`CODEQL|NONE|MIXED`)
- `rejected_hypotheses_logged` (`true|false`)
- `root_cause_primary`
- `root_cause_secondary`
- `patch_level`
- `counterfactual_fix`
- `five_whys_present`
- `deterministic_override_approved`
- `deterministic_override_rationale`

### `root_cause.md`

- `task_id`
- `failure_class`
- `trigger_condition`
- `minimal_faulty_decision`
- `why_existing_controls_failed`
- `counterfactual_fix`
- `preventive_control`
- `patch_level` (`local_fix|module_refactor|architecture_change|process_control`)
- `root_cause_primary`
- `root_cause_secondary`
- `why1`..`why5`
- `code_references` (list)

## New/Updated Scripts

1. `scripts/lint_iteration_artifacts.sh`
- Validates all required task artifact files and key fields.

2. `scripts/init_task_workspace.sh <TASK-ID>`
- Creates missing task files from templates.
- Non-destructive: does not overwrite existing files.

3. `scripts/migrate_to_v2.sh`
- Iterates existing `findings/tasks/*` directories.
- Backfills missing v2 artifacts using template scaffolding.

4. `scripts/lint_task_result.sh`
- Now supports `--v2` mode for strict result schema checks.
- Rejects template placeholders/default stubs in `result.md` under `--v2`.
- Blocks confirmed findings with `deterministic_signal_basis: NONE` unless override is explicitly approved with rationale.

5. `scripts/lint_v2_tasks_from_paths.sh`
- Lints changed task paths by deriving task IDs and running both validators.

6. `scripts/lint_root_cause.sh`
- Validates root-cause schema completeness and rejects generic RCA placeholders.

7. `scripts/generate_root_cause_clusters.sh`
- Generates `findings/root_cause_clusters.md` by clustering recurring RCA tags.

## Loop Enforcement Changes

`/Users/qeew/Desktop/ralph-security-agent/loop.sh` now:

1. Auto-initializes task workspace via `scripts/init_task_workspace.sh` when a BUILDING task starts.
2. Runs `scripts/lint_task_result.sh --v2` under `HARD_ENFORCEMENT=true`.
3. Runs `scripts/lint_iteration_artifacts.sh <TASK-ID>` under `HARD_ENFORCEMENT=true`.
4. Refreshes `findings/root_cause_clusters.md` each successful iteration.
5. Marks task `NEEDS_REVIEW` when validators fail.

## Migration Plan

Run once in repo root:

```bash
scripts/migrate_to_v2.sh
```

Then preflight one task manually:

```bash
scripts/lint_iteration_artifacts.sh <TASK-ID>
scripts/lint_root_cause.sh findings/tasks/<TASK-ID>/root_cause.md
scripts/lint_task_result.sh --v2 findings/tasks/<TASK-ID>/result.md
scripts/generate_root_cause_clusters.sh
```

Then run loop:

```bash
HARD_ENFORCEMENT=true ./loop.sh
```

Pre-commit:
- `scripts/install_hooks.sh` installs a hook that runs complexity checks, code index update, and v2 lint for changed task paths.

CI:
- `.github/workflows/v2-task-lint.yml` runs v2 linting for changed task artifacts on push and pull requests.

## Rollback Strategy

1. Keep `HARD_ENFORCEMENT=false` temporarily if you need non-blocking transition.
2. Continue using `scripts/lint_task_result.sh` without `--v2` for legacy outputs.
3. Re-enable hard enforcement once all active tasks pass v2 preflight.
