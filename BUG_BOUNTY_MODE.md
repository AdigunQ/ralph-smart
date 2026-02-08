# Ralph Bug Bounty Mode

Use this mode when your goal is maximizing bounty expected value, not full audit completeness.

## Enable

```bash
BOUNTY_MODE=true HARD_ENFORCEMENT=true ./loop.sh
```

## Required Artifacts

- `findings/bounty_program_assessment.md`
- Optional rules snapshot under `findings/rules_snapshot/`

Initialize:

```bash
scripts/init_bounty_context.sh
```

Validate:

```bash
scripts/lint_bounty_assessment.sh findings/bounty_program_assessment.md
```

Archive program rules before disclosure:

```bash
scripts/snapshot_bounty_rules.sh <program-url> <label>
```

## Practical Workflow

1. Assess program fairness and payout risk before deep hunting.
2. Set `go_no_go` (`GO`, `LIMITED`, `NO_GO`).
3. Focus on high-impact, exploitable critical paths.
4. Avoid low-value paths (deprecated, non-deployed, inactive, incompatible).
5. Keep evidence strong: realistic attack path + asset impact quantification.
