---
description: Start day N of the Helix plan (load context, branch, plan the work)
argument-hint: <day number, e.g. 3>
---

You are starting **day $ARGUMENTS** of the Helix 45-day plan. Follow CLAUDE.md §4 exactly.

1. Read CLAUDE.md, then the "Day $ARGUMENTS ·" section of docs/plan/day-guide.md, the most recent file in docs/progress/, and every SPEC.md section the day references.
2. Run `make check`. If anything is red, stop and fix it first, explaining the cause.
3. `git switch main && git pull --ff-only` (skip pull if there is no remote access), then `git switch -c day-<NN>-<topic>` using a two-digit day number.
4. Reply with a short plan: the day's goal, the ordered build steps with time boxes, files to create/change, tests to write, the "Done when" checklist, and anything ambiguous.
5. Then start step 1 and continue through the plan, committing after each completed step with Conventional Commits and running `make check` before every commit.
