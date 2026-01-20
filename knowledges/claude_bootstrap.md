# Claude Bootstrap: Security & TDD Patterns

**Core Philosophy**: "The bottleneck has moved from code generation to code comprehension."
We adopt the [Claude Bootstrap](https://github.com/alinaqi/claude-bootstrap) methodology: **TDD-first, Iterative Loops, Security-First.**

## 1. Complexity Enforcers (The "20/200" Rule)

Complexity is the enemy of security. We enforce specific limits:

- **Max 20 lines per function**: Decompose immediately if longer.
- **Max 200 lines per file**: Split by responsibility if longer.
- **Max 3 parameters**: Use objects for more.
- **Max 2 levels nesting**: Flatten with early returns.

**Enforcement**: During `/review`, flag any violations.

## 2. Iterative TDD Loops (The "Ralph Wiggum" Protocol)

We do not write code one-shot. We loop until tests pass.

**The Loop:**

1.  **Requirements**: Extract specific, testable requirements.
2.  **RED**: Write failing tests _first_. Run them to prove they fail.
3.  **GREEN**: Write minimum code to pass.
4.  **REFACTOR**: Clean up, satisfying complexity rules.
5.  **VALIDATE**: Lint, Typecheck, Coverage > 80%.

**Use `/tdd` workflow to automate this.**

## 3. Atomic Todos

All work is tracked in `task.md` (or `_project_specs/todos/`) using this format:

```markdown
## [TODO-001] Feature Name

**Status**: in-progress
**Priority**: high

### Acceptance Criteria

- [ ] Criterion 1
- [ ] Criterion 2

### Test Cases

| Input | Expected |
| ----- | -------- |
| ...   | ...      |
```

## 4. Code Deduplication ("Check Before Write")

AI tends to reimplement things. We prevent this by maintaining a `CODE_INDEX.md` (conceptually or physically).

**Before writing a new function:**

1.  **Search**: `grep` codebase for similar names/logic.
2.  **Evaluating**: Can existing code be extended?
3.  **Implement**: Only create new if truly distinct.

**Use `/dedup` workflow to check.**

## 5. Security & Credentials

- **No Secrets in Code**: Even comments.
- **No .env in git**: Validated by hooks.
- **Centralized Credentials**: Access keys read from secure local storage, never hardcoded.
