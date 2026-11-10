# CLAUDE.md — working agreement for AI coding sessions

This file is read automatically by Claude Code at the start of every session. It is the operating manual for building Helix. Follow it exactly; when it conflicts with a habit, this file wins. When it conflicts with [SPEC.md](SPEC.md), SPEC.md wins on technical details and this file wins on process.

## 1. What this project is

Helix is a 45-day, 4-hours-a-day build of a distributed tensor-task runtime:

- `core/` (C++20): slab allocator, SPSC ring, Chase–Lev deque, work-stealing pool, DAG executor, tensors, SGEMM kernels.
- `rpc/` (C++20): io_uring data plane with registered buffers, `send_zc`, credit flow control.
- `store/` (C++20): mmap object store.
- `worker/` (C++20): `helixd` worker daemon.
- `meta/` (Go): Raft, WAL, snapshots, metadata state machine, scheduler, gRPC API, `helixctl`.

The owner does not write code by hand. **Every line is written by Claude Code, and the owner must be able to explain every line in an interview.** That makes explanation and documentation part of the deliverable, not an extra (§6).

## 2. Sources of truth, in order

1. [SPEC.md](SPEC.md): interfaces, wire format, data model, state machines, protocols, defaults, metrics, test and benchmark rules. Never invent an interface that contradicts it; change SPEC.md first (and say so) if a change is needed.
2. [docs/plan/day-guide.md](docs/plan/day-guide.md): what to build on each day, in what order, with "Done when" checks.
3. [docs/design/](docs/design/): design docs; [docs/adr/](docs/adr/): decisions already made.
4. [docs/progress/](docs/progress/): what has been done so far. Read the latest day log before starting.

## 3. Commands

| Command | Use |
| --- | --- |
| `make build` | Release build of C++ and Go |
| `make test` | Unit tests (ctest + go test) |
| `make asan` / `make tsan` / `make ubsan` | C++ tests under each sanitizer (separate build dirs) |
| `make race` | Go tests with the race detector |
| `make lint` | clang-format check, go vet, clang-tidy |
| `make format` | Apply clang-format and gofmt |
| `make check` | **Definition of Done gate**: lint + test + asan + tsan + ubsan + race |
| `make verify-sanitizers` | Proves TSan and the Go race detector catch a deliberate race |
| `make env` | Machine/toolchain report for the day log |
| `ctest --test-dir build -R <Regex>` | Run a subset of C++ tests |
| `go test ./meta/... -run <Regex> -count=100 -race` | Repeat a Go test to flush out flakiness |

Run everything inside the Linux dev machine (OrbStack `helix`), never on macOS directly. If this session itself runs on macOS, wrap every build/test command: `orb -m helix bash -lc "cd /Users/anshu/raft-v2.0/CS-6210_AOS/helix && make check"` (see [dev-environment runbook](docs/runbooks/dev-environment.md#where-to-run-claude-code)). Build directories contain Linux binaries; never run them from macOS. If TSan aborts with "unexpected memory mapping", run `sudo sysctl -w vm.mmap_rnd_bits=28`.

## 4. How a day runs (the owner will say "run day N")

1. **Load context.** Read `docs/plan/day-guide.md` for day N, the previous `docs/progress/day-NN.md`, and the SPEC sections the day references. Run `make check` and confirm it is green before changing anything. If it is red, fix that first and say so.
2. **Branch.** `git switch -c day-NN-<short-topic>` from an up-to-date `main`.
3. **Plan in one message.** List the steps you will take (from the day guide), the files you will create or change, and the tests you will write. Then proceed without waiting unless a decision is genuinely ambiguous.
4. **Build in small steps.** For each step: write the test first when practical, implement, run the narrowest test, then `make check` before committing. Commit at least once per completed step with Conventional Commits (§7).
5. **Measure.** If the day has a benchmark, run it, save raw output under `bench/results/<date>-<name>/`, and record the numbers.
6. **Document (mandatory, see §6).**
7. **Close the day.** Write `docs/progress/day-NN.md` from the template, tick the day in [docs/plan/tracker.md](docs/plan/tracker.md), update CHANGELOG.md, push the branch, and print the PR description for the owner.

If a step overruns by 50%, take the simplest path that satisfies "Done when", note the shortcut in the day log, and open a follow-up issue in the log's "Deferred" section.

## 5. Engineering rules (non-negotiable)

**General**
- `main` is always green. Never commit with `make check` failing.
- Never weaken, skip or delete a test to make it pass. A flaky test is a bug, usually a real race: investigate it.
- No new third-party dependency without an ADR (or an amendment to an existing one). Pin every dependency to an exact commit/version.
- No `TODO` without an owner context: write `TODO(day-NN): ...` naming the day that will resolve it.
- Do not edit generated files or anything under `build*/`.

**C++** (full list in SPEC.md §1)
- C++20, Google style via clang-format, 100 columns. Warnings are errors.
- No exceptions on hot paths; return `helix::Status` / `helix::Result<T>` (from day 3). Abort only for broken invariants via `HELIX_CHECK`.
- RAII everywhere; raw pointers never own; no `new`/`delete` outside allocators.
- **Every atomic operation names its memory order explicitly and carries a comment saying which operation it pairs with and why.** Example: `tail_.store(t + 1, std::memory_order_release);  // pairs with acquire load of tail_ in try_pop(): publishes slot[t]`.
- Fields written by different threads are padded to `helix::kCacheLine` (128).
- New concurrent code ships with: a single-threaded unit test, a multi-threaded stress test run 100× under TSan, and a reference-model comparison where applicable.
- Headers: `core/include/helix/<area>/<name>.h`, include guard `HELIX_<AREA>_<NAME>_H_`, file comment explaining purpose, thread-safety and ownership.

**Go**
- gofmt, go vet, `-race` clean. Contexts on every RPC; every goroutine has an owner that stops it; wrap errors with `%w`.
- `meta/sm` Apply must be deterministic: no clocks, no randomness, no I/O, no map-iteration order leaking into output.

**Tests**
- Randomized tests print their seed and honour `HELIX_SEED`.
- No sleeps for synchronization in tests; wait on conditions with timeouts.

## 6. Documentation duties (every day, every change)

Because the owner must defend this code in interviews, each day must leave behind:

1. **Code comments** that explain *why*, not *what*, on every non-obvious line (memory orders, invariants, lifetimes, error paths).
2. **`docs/progress/day-NN.md`** (template: [docs/progress/TEMPLATE.md](docs/progress/TEMPLATE.md)): what was built, files touched, test and benchmark evidence (commands + numbers), decisions, problems hit and how they were solved, deferred items, and **"Explain it back"**: 5 questions with model answers the owner should be able to answer about today's code.
3. **Concept docs**: if the day used a concept, update or extend the matching file in [docs/concepts/](docs/concepts/) with what was learned in practice (pitfalls actually hit, numbers actually measured).
4. **API/DB docs**: if a public interface, wire message, table, record format or config key changed, update [docs/api/](docs/api/), [docs/db/](docs/db/) and SPEC.md in the same commit.
5. **Design docs**: keep the milestone design doc in [docs/design/](docs/design/) current; finalize it on the milestone's last day.
6. **ADRs**: any decision with a real alternative gets an ADR in [docs/adr/](docs/adr/) (template inside).
7. **Postmortems**: any bug that took more than 30 minutes gets [docs/postmortems/](docs/postmortems/) `YYYY-MM-DD-<slug>.md`.
8. **Interview prep**: append the day's best story or talking point to [docs/interview/deep-dive-stories.md](docs/interview/deep-dive-stories.md).

When explaining a change to the owner in chat, lead with *what it does and why*, then the key invariant, then how it was verified.

## 7. Git conventions

- Branches: `day-NN-<topic>` (e.g. `day-03-spsc-ring`), `fix/<topic>`, `feat/<topic>`.
- Conventional Commits: `feat(core): add SPSC ring with cached indices`, `fix(meta): ...`, `perf(rpc): ...`, `test(...)`, `docs(...)`, `bench(...)`, `build(...)`, `ci(...)`, `chore(...)`.
- Commit body: what and why in 1–3 lines; mention the test that covers it.
- One PR per day into `main`; the PR description uses [.github/pull_request_template.md](.github/pull_request_template.md).
- Tags `v0.1`…`v0.5` at milestone ends (days 11, 17, 28, 38, 45).

## 8. Things to never do

- Never claim a benchmark number that was not measured in this repo; never estimate numbers in docs.
- Never push to `main` directly or force-push shared branches.
- Never commit secrets, cloud credentials, Terraform state, or large binaries.
- Never leave cloud machines running: every benchmark session ends with `terraform destroy` and a check.
- Never publish code that solves a Georgia Tech CS 6210 course project; Helix is a general runtime.

## 9. Useful context

- Dev machine: OrbStack Ubuntu 24.04 arm64 (Apple M5). ARM's weak memory model is a feature: run lock-free stress tests there.
- No hardware perf counters, real NUMA or CUDA on the Mac VM; CUDA runs on a free Kaggle GPU on day 36; perf counters, NUMA and published benchmarks on rented machines on days 42–43 (see [docs/plan/45-day-plan.md](docs/plan/45-day-plan.md)).
- Cache line: Apple Silicon reports 128 bytes, x86 64 bytes; Helix pads to 128 everywhere.
