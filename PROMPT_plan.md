# Ralph PLANNING Mode (Lean)

You are planning a smart-contract security review for `TARGET_DIR`.

Goal:
- Produce a focused, high-signal task plan for bug hunting.

Create/update these files:
- `findings/project_analysis.md`
- `findings/business_flows.md`
- `findings/assumptions.md`
- `IMPLEMENTATION_PLAN.md`

Plan requirements:
1. Map core assets, trust boundaries, and privileged roles.
2. List attack surfaces and external integrations visible in code.
3. Generate 20-50 concrete security tasks using the 6 taint models (`INV`, `ASM`, `EXP`, `TMP`, `CMP`, `BND`).
4. If `findings/eip_security_checklist.md` exists, include high-relevance EIP/ERC checklist items as explicit tasks.
5. If `findings/protocol_vulnerability_checklist.md` exists, include top protocol-category checks as explicit tasks.
6. Prioritize by exploitability and impact (Critical first).
7. Keep tasks testable and evidence-oriented.

`IMPLEMENTATION_PLAN.md` format:
- Checklist items with stable task IDs (e.g., `INV-001`, `EXP-003`).
- One task per line, with short description and severity.
- Use unchecked `[ ]` for pending tasks.

Do not pad with generic advice.
Do not output speculative findings in planning mode.
