---
description: Create a structured Pull Request
allowed-tools: run_command
argument-hint: [base-branch]
---

# /pr Protocol

**Goal**: Create a comprehensive PR description and open it.

1.  **Summarize Changes**:

    - Run `git diff main...HEAD --stat` (or target branch)
    - Run `git log main..HEAD --oneline`

2.  **Draft Description**:

    - **Summary**: What/Why.
    - **Changes**: Bullet points.
    - **Testing**: How it was verified.

3.  **Create PR**:
    - Use `gh pr create` (if `gh` CLI available) OR output the text for manual creation.
    - If using `gh`, prompt for title.

_Default branch_: `main` (unless argument provided).
