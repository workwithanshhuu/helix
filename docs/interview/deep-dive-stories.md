# Deep-dive stories (STAR)

Appended **every day** (CLAUDE.md §6.8). Each story: **Situation**, **Task**, **Action**, **Result** (with a number or a test), plus **What I learned** and **Evidence** (links to commits, day log, postmortem, plot). Aim for 2–3 minutes spoken.

Template:

```markdown
## <date> · day NN · <short title>
- **Situation:** …
- **Task:** …
- **Action:** …
- **Result:** … (number / test)
- **What I learned:** …
- **Evidence:** [day log](../progress/day-NN.md), commit `abc1234`, …
- **Likely follow-up questions:** …
```

---

## 2026-11-10 · day 1 · A CI that proves it can fail
- **Situation:** Starting a 45-day concurrent-systems project where most bugs will be data races and memory-ordering errors that tests don't reliably hit.
- **Task:** Make sure the safety net (sanitizers, race detector, CI on two architectures) actually works before writing any concurrent code.
- **Action:** Set up one build per sanitizer (ASan, TSan, UBSan) plus Go `-race`, ran CI on x86-64 and arm64, and added a **canary**: a deliberate C++ and Go data race that the pipeline must detect, failing CI if the detectors stay silent. Pinned dependencies by commit SHA after the tarball download was blocked behind a proxy, and documented the TSan/ASLR incompatibility (`vm.mmap_rnd_bits=28`).
- **Result:** `make check` runs lint + 4 tests under release/ASan/TSan/UBSan + Go race; `make verify-sanitizers` reports both deliberate races. Every later lock-free structure inherits this gate.
- **What I learned:** A green CI is only meaningful if you've seen it go red for the right reason; sanitizers have environmental requirements (runtimes, ASLR) that silently break them.
- **Evidence:** [day 1 log](../progress/day-01.md), `scripts/verify-sanitizers-catch-races.sh`, `.github/workflows/ci.yml`.
- **Likely follow-up questions:** How does TSan detect races (vector clocks, shadow memory)? Why not combine ASan and TSan? What can TSan miss (races not executed; fences)?
