# Flow State Protocol: "Speed without Fear"

> **Equation**: `dangerously-skip-permissions` + `safety-hooks` = **Flow State**.

Traditional security stops you every 5 seconds to ask "Are you sure?". This kills flow.
Ralph's Flow State Protocol permits **Autonomous Execution** by relying on a strict **Negative Constraint System**.

## 1. The "Green Lane" (Skip Permissions)

By default, the agent is allowed to:

- Read any file in the project.
- Write files in `target/` and `findings/`.
- Run compiler commands (`forge build`, `cargo test`).
- Execute safe scripts (`mkdir`, `touch`, `grep`).

**No approval is requested for these actions.**

## 2. The "Red Hooks" (Safety Barriers)

Before executing _any_ command, the **Safety Hook** (`safety_check.sh`) scans the intent.

**Blocked Actions (The Third Rail):**

- ❌ **Destructive Deletion**: `rm -rf /` or `rm -rf ~` (Project-local deletes are allowed).
- ❌ **Secret Exfiltration**: Reading `.env`, `id_rsa`, or exporting `PRIVATE_KEY`.
- ❌ **System Mutation**: `mkfs`, `dd`, `chmod 777 /`.
- ❌ **Git Destruction**: `git push --force`.

## 3. Implementation

The loop runs with:

```bash
./loop.sh --ask-for-approval never --hook ./safety_check.sh
```

## 4. Why this matters

This allows the agent to iterate 100x faster (Real-Time Feedback Loop) because it doesn't wait for human RTT (Round Trip Time). Use this mode when hunting in a sandboxed environment.
