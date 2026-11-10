---
description: Explain a file or concept for interview preparation
argument-hint: <file path or concept>
---

Explain **$ARGUMENTS** so the owner can defend it in a senior systems interview:

1. What it does and why it exists in Helix (one paragraph).
2. Walk through the code (or mechanism) step by step, quoting the key lines.
3. The invariants and why they hold; for concurrent code, every memory order and what it pairs with.
4. What breaks if a key line is removed or changed (at least 3 concrete examples).
5. The alternatives considered and the trade-off taken (link the ADR if one exists).
6. Five likely interview questions with concise model answers.

Then offer to append the best of it to docs/interview/deep-dive-stories.md.
