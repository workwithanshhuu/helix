# Study guide

How to learn what Helix needs, alongside building it, in ~1 hour of the daily 4 hours.

| Doc | Purpose |
| --- | --- |
| [study-plan.md](study-plan.md) | Week-by-week what to read/watch and which concept doc to master, aligned to the 45-day plan |
| [reading-list.md](reading-list.md) | Every book, paper, course and codebase, by milestone (★ = must read) |
| [glossary.md](glossary.md) | Every term used in the docs, one or two lines each |
| [../concepts/](../concepts/) | The concept docs (theory tied to Helix code) |
| [../concepts/foundations-refresher.md](../concepts/foundations-refresher.md) | Rusty-basics refresher with experiments and a self-check bank |

## Daily rhythm (4 h)
| Block | Time | What |
| --- | --- | --- |
| Learn | 45 min | The day's "Learn" item from [day-guide.md](../plan/day-guide.md) + the matching concept doc |
| Build | 2 h 30 min | Claude Code builds; you review each step, run the tests, ask "why" until you could rewrite it |
| Explain | 30 min | Answer the day log's "Explain it back" questions aloud without notes; fix gaps |
| Log | 15 min | Tick the tracker, add field notes to the concept doc, add a story |

## How to study code you didn't type
1. Read the test first: it is the specification.
2. For each function, say its precondition, postcondition and invariant.
3. For each atomic, say what it pairs with and what goes wrong if it's relaxed.
4. Break it on purpose (comment out a line, weaken an order) and predict which test fails; run it.
5. Re-derive one key algorithm on paper each week (ring push/pop, deque take/steal, Raft vote rule, lease expiry).
6. Use `/explain <file>` in Claude Code for a guided walkthrough.
