---
description: Code Quality & Security Review (Bootstrap Gates)
allowed-tools: list_dir, read_url_content
argument-hint: [file-or-dir]
---

# /review Protocol

**Goal**: Enforce "Claude Bootstrap" Quality Gates on "$ARGUMENTS".

## 1. Complexity Check (The 20/200 Rule)

**Action**: Running automated enforcement script...

```bash
python3 scripts/enforce_complexity.py
```

_(If this script fails, you MUST refactor before proceeding.)_

## 2. Security Check

- [ ] Secrets in code/comments?
- [ ] `.env` patterns?
- [ ] Unsanitized inputs (SQL/Shell)?

## 3. TDD Check

- [ ] Are there tests for this code?
- [ ] Do tests cover the business logic?

**Output Report**:

- **Status**: 🟢 PASS / 🔴 FAIL
- **Violations**: [List specific lines]
- **Fixes**: [Suggested refactors]
