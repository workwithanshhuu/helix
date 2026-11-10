---
description: Close day N (verify Done-when, write the day log and docs, prepare the PR)
argument-hint: <day number>
---

Close **day $ARGUMENTS** following CLAUDE.md §4 step 7 and §6.

1. Run `make check` and `make verify-sanitizers`; paste the summary lines.
2. Walk through every "Done when" item for day $ARGUMENTS in docs/plan/day-guide.md and state pass/fail with evidence (command + output or file path).
3. Write docs/progress/day-<NN>.md from docs/progress/TEMPLATE.md, including the "Explain it back" section (5 questions with model answers about today's code).
4. Update, as applicable: docs/concepts/*, docs/api/*, docs/db/*, SPEC.md, the milestone design doc, ADRs, postmortems, docs/interview/deep-dive-stories.md, CHANGELOG.md.
5. Tick day $ARGUMENTS in docs/plan/tracker.md with a link to the day log (only if every Done-when item passed; otherwise list what is missing).
6. Commit (`docs(progress): day NN log`), push the branch, and print a ready-to-paste PR description using .github/pull_request_template.md.
