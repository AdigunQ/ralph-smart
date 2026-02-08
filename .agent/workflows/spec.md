---
description: Build a tight implementation spec using architect/critic refinement loops
trigger: /spec [requirements-file]
---

# /spec - Requirement-to-Spec Refinement Loop

Turn a requirements document into an implementation-ready spec with anti-bloat
review loops.

## Inputs

- Requirements file path from `$ARGUMENT`
- Existing docs in `docs/` or `specs/`

## Protocol

1. **Clarification Gate**
   - Identify ambiguity and ask high-leverage questions.
   - If user is unavailable, write assumptions/questions to
     `findings/clarifications_needed.md`.

2. **Documentation Gate**
   - Use local docs first.
   - Fetch official docs only when local docs are insufficient.

3. **Draft A (Architect)**
   - Produce first complete spec draft quickly.
   - Save to `docs/plans/*a-*.md` (or `specs/plans/*a-*.md` if using specs/).

4. **Critic Pass (Hard-Nosed Reviewer)**
   - Review Draft A for:
     - over-engineering
     - unnecessary abstractions
     - premature optimization
     - out-of-scope additions
   - Save feedback to `*-critic-feedback.md`.

5. **Draft B/C (Refinement)**
   - Apply critic feedback and produce Draft B.
   - Optionally repeat once for Draft C.

6. **Review Handoff**
   - Pause and summarize:
     - final architecture
     - simplifications made
     - explicit out-of-scope items preserved

## Non-Negotiables

- Requirements fidelity beats feature creep
- Simplicity over cleverness
- Framework conventions over custom machinery
- No implementation starts before user review of final spec
