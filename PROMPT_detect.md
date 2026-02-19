# Ralph DETECT Mode

You are in **DETECT mode**.

Objective:
- Find all credible high-severity or critical loss-of-funds vulnerabilities in `TARGET_DIR`.
- Optimize for coverage, not single-bug wins.

Execution rules:
1. Start from deterministic evidence where possible (CodeQL outputs, call-path tracing, explicit state transitions).
1.5 If `findings/eip_security_checklist.md` exists, prioritize checks for the listed relevant EIP/ERC standards.
1.6 If `findings/protocol_vulnerability_checklist.md` exists, prioritize high-scoring protocol vulnerability categories.
2. For each finding, prove:
   - reachability,
   - attacker controllability,
   - real economic impact.
3. Reject weak or purely theoretical claims.
4. Continue until you cannot produce additional high-confidence issues.

Output requirements:
- Write the final audit report to `submission/audit.md`.
- For each finding, include:
  - title,
  - severity rationale,
  - root cause,
  - exploit path,
  - code references with file and line numbers,
  - concrete remediation direction.

Quality bar:
- No vague pattern dumps.
- No duplicate findings for the same root cause.
- No medium/low-only filler.
