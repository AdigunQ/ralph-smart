---
description: Run a full autonomous audit using the Ralph Loop
---

# /audit Check

This workflow triggers the main autonomous auditing loop.

1.  **Check Prerequisites**: Ensure `loop.sh` is executable.

    ```bash
    chmod +x loop.sh
    ```

2.  **Run Planning Phase (if needed)**:
    If `IMPLEMENTATION_PLAN.md` does not exist, the loop will start in PLANNING mode.

    ```bash
    ./loop.sh
    ```

3.  **Monitor Progress**:
    The loop will generate `IMPLEMENTATION_PLAN.md` and start executing checks.
    Tail the progress:
    ```bash
    tail -f findings/audit_progress.log
    ```
