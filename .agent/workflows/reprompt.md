---
description: Convert rough voice input/ideas into a prompt structured for Agentic success
argument-hint: [rough-idea]
---

# /reprompt Protocol

**Goal**: Convert a messy, vague idea into a **Structured Agentic Prompt**.

## 1. Understand (The Interview)

I will ask you clarifying questions (one by one) to extract:

- **Goal**: What exactly are we doing?
- **Context**: relevant files? background info?
- **Constraints**: strict rules?
- **Success Criteria**: how do we know we're done?

## 2. Structure (The XML Builder)

Once I have the info, I will generate a prompt in this format:

```xml
<task>
  <goal>...</goal>
  <context>...</context>
  <constraints>...</constraints>
  <output>...</output>
</task>
```

## 3. Execute or Refine

You can then say "Execute this" or "Adjust X".

---

**Input**: $ARGUMENTS
