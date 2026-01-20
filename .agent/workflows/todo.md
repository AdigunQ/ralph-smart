---
description: Interactive wizard to create a Bootstrap-compliant Atomic Todo
argument-hint: [task-summary]
---

# /todo Protocol

**Goal**: Create a perfect "Atomic Todo" with Acceptance Criteria and Test Cases.

## 1. Description Phase

- **Ask**: "What specific task are we doing?" (if not provided)
- **Ask**: "Why is this needed?" (to understand value)
- **Draft**: Create a 1-paragraph description.

## 2. Acceptance Criteria Phase

- **Prompt**: "What must be true for this to be done? Give me 2-4 binary (yes/no) criteria."
- **Refine**: Ensure they are specific and measurable.

## 3. Test Cases Phase (The TDD Core)

- **Prompt**: "Give me 3-5 specific inputs and expected outputs."
- **Table**: Structure as Input | Expected | Notes.

## 4. Verification

- **Output Draft**: Show the full markdown block.
- **Ask**: "Is this small enough (S/M)? Does this cover the edge cases?"

## 5. Finalize

- **Action**: Append the finalized block to `task.md` (or `_project_specs/todos/active.md`).
- **Next**: Suggest running `/tdd` on this new ID.

**Starting Todo Wizard for: $ARGUMENTS**
