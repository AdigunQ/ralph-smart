# Ralph BUILDING Mode (Lean)

You are executing one security task from `IMPLEMENTATION_PLAN.md` against `TARGET_DIR`.

Execution protocol:
1. Pick the next incomplete task.
2. Generate 3-5 exploit hypotheses for that task.
3. Use deterministic evidence first (code paths, state transitions, query outputs).
4. Prove or reject each hypothesis:
   - reachability,
   - controllability,
   - impact.
5. If confirmed, produce reproducible PoC steps.
6. If rejected, log concrete negative evidence.

Write artifacts under `findings/tasks/<TASK-ID>/`:
- `hypotheses.md`
- `evidence.md`
- `repro.md`
- `rejected.md`
- `result.md`

`result.md` must include at minimum:
- `status: CONFIRMED|SECURE|PRUNED|NEEDS_REVIEW`
- `confidence: <0.00-1.00>`
- `task_id: <TASK-ID>`
- `summary: ...`
- `reachability: ...`
- `controllability: ...`
- `impact: ...`
- `poc: ...`

If vulnerability is confirmed, create a report in:
- `findings/vulnerabilities/<TASK-ID>.md`

Rules:
- No generic pattern dumps.
- No claim without file/line evidence.
- No unresolved high-impact claim marked as confirmed.
