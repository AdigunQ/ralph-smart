---
description: Start an Iterative TDD Loop (Ralph Wiggum Protocol)
argument-hint: [feature-description]
---

# /tdd Protocol (Ralph Loop)

**Goal**: Implement "$ARGUMENTS" using strict TDD loops.

## Loop Constraints

1.  **Iterative**: Do not try to solve everything in one turn.
2.  **Tests First**: You MUST write a failing test before writing implementation.
3.  **Complexity**: Max 20 lines/function, 200 lines/file.

## Phase 1: Requirements & Red

1.  Analyze "$ARGUMENTS".
2.  Create test file (or add to existing).
3.  Write test cases that FAIL.
4.  Run tests to PROVE they fail (Red).

## Phase 2: Green & Refactor

1.  Write minimum code to pass tests.
2.  Run tests (Green).
3.  Refactor to meet "20/200" complexity rules.
4.  Lint & Typecheck.

## Phase 3: Loop

If requirements not fully met, repeat Phase 1 for next chunk.
If blocked, stop and ask.

**Start Phase 1 now for: $ARGUMENTS**
