# Spec Refinement Protocol (Architect + Critic Loop)

Use this protocol for requirement-to-spec work where over-engineering risk is high.

## Goal

Produce implementation-ready specs that are:
- requirement-faithful
- minimal and maintainable
- explicit about scope and tradeoffs

## Workflow

1) Clarification Gate
- Ask at least 3 high-leverage questions when ambiguity exists.
- If no interactive user is available, document assumptions and unresolved
  questions in `findings/clarifications_needed.md`.

2) Documentation Gate
- Use local docs first.
- Fetch additional official docs only for missing pieces.

3) Draft A (Architect Pass)
- Produce a complete first draft quickly.
- Save as `...a-<topic>.md`.

4) Critic Pass (Anti-Bloat Review)
- Review Draft A with strict standards:
  - remove unnecessary abstractions
  - remove premature optimization
  - use framework-native primitives
  - delete out-of-scope features
- Save review as `...a-<topic>-critic-feedback.md`.

5) Draft B/C (Refinement Passes)
- Apply critic feedback in Draft B.
- Optionally repeat one more critic pass and produce Draft C.
- Stop once spec is implementation-ready and tightly scoped.

6) Handoff Summary
- Provide concise final summary:
  - final architecture
  - what was removed/simplified
  - known risks and validation plan

## Anti-Bloat Checklist

- Could this be done with existing framework/library features?
- Are we adding tables/components/services “just in case”?
- Is each element directly tied to a requirement?
- Are we solving current problems, not hypothetical future ones?

## Output Naming (recommended)

- `YYMMDD-XXa-<topic>.md` (first draft)
- `YYMMDD-XXa-<topic>-critic-feedback.md` (review)
- `YYMMDD-XXb-<topic>.md` (refined draft)
- `YYMMDD-XXc-<topic>.md` (final draft, optional)
