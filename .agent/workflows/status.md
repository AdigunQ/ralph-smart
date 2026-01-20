---
description: Check context usage and health
---

# /status Protocol

**Goal**: precise Context Health Check.

1.  **Report**:

    - Current Context Usage (Estimate).
    - Files currently in context (if retrievable).
    - Conversation depth.

2.  **Health Check**:

    - **< 40%**: 🟢 Green (Go flow).
    - **40-70%**: 🟡 Yellow (Be mindful).
    - **> 70%**: 🔴 Red (Plan compaction/clear).

3.  **Recommendation**:
    - If Red, suggest `notify_user` to clear or compact.
