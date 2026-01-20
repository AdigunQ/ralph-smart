---
description: Create a semantic commit with conventional format
allowed-tools: run_command
---

# /commit Protocol

**Goal**: Analyze staged changes and commit with Conventional Commits format.

1.  **Analyze**:

    - Run `git diff --cached`
    - Run `git status`

2.  **Generate Message**:
    Format: `type(scope): brief description`
    Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`.

3.  **Confirm & Commit**:
    - Show the message to the user.
    - If approved, run `git commit -m "..."`.

_Note: If nothing staged, ask user to stage files first._
