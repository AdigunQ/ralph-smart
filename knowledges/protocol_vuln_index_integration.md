# Protocol Vulnerabilities Index Integration

This repo integrates [kadenzipfel/protocol-vulnerabilities-index](https://github.com/kadenzipfel/protocol-vulnerabilities-index) into Ralph's hunt loop.

## Purpose

- Convert protocol-category findings into target-specific hypothesis seeds.
- Prioritize vulnerability classes that match the current codebase footprint.
- Reduce random exploration and increase high-signal coverage.

## Inputs

- Index source dir: `tools/protocol-vulnerabilities-index`
- Target codebase: `TARGET_DIR` (loop runtime variable)

## Generator

Script:
- `scripts/generate_protocol_vuln_checklist.py`
- `scripts/fetch_protocol_vuln_index.sh`

Outputs:
- `findings/protocol_vulnerability_checklist.md`
- `findings/protocol_vulnerability_checklist.json`

The generator:
1. Parses category markdown files from `categories/**`.
2. Extracts preconditions and detection heuristics.
3. Builds keyword signals from category names + heuristic code tokens.
4. Scores category relevance against the local target code.
5. Produces actionable checklist entries for DETECT/PLANNING/BUILDING modes.

## Loop Hook

`loop.sh` calls checklist generation in bootstrap:
- `DETECT`: CodeQL baseline + EIP checklist + protocol vulnerability checklist
- `PLANNING/BUILDING` (including `AUTO`): preflight + CodeQL baseline + both checklists
- `PATCH/EXPLOIT`: skipped by default

Related env vars:
- `PROTOCOL_VULN_INDEX_DIR` (default: `tools/protocol-vulnerabilities-index`)
- `PROTOCOL_VULN_CHECKLIST_OUT` (default: `findings/protocol_vulnerability_checklist.md`)
- `PROTOCOL_VULN_CHECKLIST_JSON` (default: `findings/protocol_vulnerability_checklist.json`)
- `PROTOCOL_VULN_CHECKLIST_REFRESH` (default: `false`)

## Prompt Behavior

Prompts consume the generated checklist when available:
- `PROMPT_detect.md`
- `PROMPT_plan.md`
- `PROMPT_build.md`

This keeps protocol-specific threat classes tightly coupled to target evidence.
