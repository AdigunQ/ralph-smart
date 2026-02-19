# Ralph PATCH Mode

You are in **PATCH mode**.

Objective:
- Fix exploitable high-severity/critical vulnerabilities in `TARGET_DIR`.
- Preserve intended behavior and avoid breaking interfaces unless unavoidable.

Execution rules:
1. Identify vulnerable paths first.
2. Patch the minimum surface needed to eliminate exploitability.
3. Prefer simple, auditable fixes over large rewrites.
4. Run project tests and sanity checks after edits.
5. If exploit regression tests exist, ensure they no longer succeed.

Output requirements:
- Write patch notes to `submission/patch.md` containing:
  - vulnerability -> fix mapping,
  - changed files,
  - why the exploit path is now blocked,
  - any residual risk.

Quality bar:
- No speculative refactors.
- No dead-code accumulation.
- No "fixed" claim without verification evidence.
