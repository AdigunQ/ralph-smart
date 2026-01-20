---
description: Check for code duplication before implementation
allowed-tools: grep_search, find_by_name
argument-hint: [functionality-keywords]
---

# /dedup Protocol

**Goal**: Prevent semantic duplication for "$ARGUMENTS".

1.  **Search**:

    - Run `grep_search` for keywords related to "$ARGUMENTS" (concepts, not just names).
    - Run `find_by_name` for related file names.

2.  **Evaluate**:

    - List any existing functions/classes that do something similar.
    - Answser: "Can we extend existing code instead of creating new?"

3.  **Recommendation**:
    - **Extend**: [Function Name] in [File]
    - **Create New**: (Justification required)

**Searching now...**
