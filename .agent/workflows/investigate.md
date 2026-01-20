---
description: Deep dive investigation into a specific bug or generic issue
argument-hint: [issue-description]
---

# /investigate Protocol

**Goal**: Systematically analyze a bug/issue without making changes yet.

## Phase 1: Understand

- **Prompt**: "What is the expected vs actual behavior?"
- **Action**: Read relevant issue descriptions or logs.

## Phase 2: Locate & Map

- **Action**: Use grep/find to locate relevant code.
- **Action**: Trace the execution path from entry to failure.

## Phase 3: Root Cause Analysis

- **Action**: Use git blame if recent regression.
- **Action**: Formulate a hypothesis.
- **Action**: Verify hypothesis (read code/tests).

## Phase 4: Report

Output a structured report:

1.  **Root Cause Summary**
2.  **Affected Files**
3.  **Recommended Fix**
4.  **Risk Assessment**

**Do NOT write code to fix it yet. Only investigate.**

---

**Issue**: $ARGUMENTS
