# EIP Security Handbook Integration

This repo integrates [BengalCatBalu/EIP-Security-Handbook](https://github.com/BengalCatBalu/EIP-Security-Handbook) into Ralph's hunt loop.

## Purpose

- Convert handbook heuristics into target-specific, testable checks.
- Prioritize EIP/ERC attack surfaces actually present in the codebase.
- Reduce generic bug-hunting noise.

## Inputs

- Handbook source dir: `tools/EIP-Security-Handbook/src`
- Target codebase: `TARGET_DIR` (loop runtime variable)

## Generator

Script:
- `scripts/generate_eip_security_checklist.py`
- `scripts/fetch_eip_handbook.sh`

Outputs:
- `findings/eip_security_checklist.md`
- `findings/eip_security_checklist.json`

The generator:
1. Parses handbook markdown files.
2. Extracts `Heuristic:` entries per vulnerability class.
3. Scores standard relevance by scanning target code for standard-linked patterns.
4. Produces an actionable checklist for DETECT/PLANNING/BUILDING modes.

## Loop Hook

`loop.sh` calls checklist generation in bootstrap:
- `DETECT`: CodeQL baseline + EIP checklist
- `PLANNING/BUILDING` (including `AUTO`): preflight + CodeQL baseline + EIP checklist
- `PATCH/EXPLOIT`: skipped by default

Related env vars:
- `EIP_HANDBOOK_DIR` (default: `tools/EIP-Security-Handbook/src`)
- `EIP_CHECKLIST_OUT` (default: `findings/eip_security_checklist.md`)
- `EIP_CHECKLIST_JSON` (default: `findings/eip_security_checklist.json`)
- `EIP_CHECKLIST_REFRESH` (default: `false`)

## Prompt Behavior

Prompts consume the generated checklist when available:
- `PROMPT_detect.md`
- `PROMPT_plan.md`
- `PROMPT_build.md`

This keeps standard-specific checks tightly coupled to actual target context.
