# Runbook: continuous integration

Workflow: [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). Runs on every push and pull request.

## 1. Jobs

| Job | Runner | What it runs | Fails when |
| --- | --- | --- | --- |
| `lint` | ubuntu-24.04 | `make format-check` (clang-format + gofmt), `make vet`, `make tidy` (clang-tidy) | Formatting differs, vet/tidy finding |
| `cpp (test-cpp)` | ubuntu-24.04 (x86-64) | Release build + ctest | Build error/warning, test failure |
| `cpp (asan)` / `(tsan)` / `(ubsan)` | ubuntu-24.04 | Sanitizer builds + ctest | Sanitizer report |
| `cpp-arm (X)` | ubuntu-24.04-arm | Same four targets on arm64 | Same; catches weak-memory bugs. **Skipped for private repos** (arm runners are free for public repos) |
| `go (os)` | ubuntu-24.04 and ubuntu-24.04-arm (arm skipped if private) | `make test-go` and `make race` | Test failure, race |
| `sanitizer-canary` | ubuntu-24.04 | `make verify-sanitizers` | Deliberate races **not** detected |

Every job that runs TSan first does `sudo sysctl -w vm.mmap_rnd_bits=28`.

## 2. Reproducing a CI failure locally
| Failing job | Local command |
| --- | --- |
| lint | `make lint` (fix with `make format`) |
| cpp (X) | `make X` (e.g. `make tsan`) |
| cpp-arm | `make tsan` in the arm64 OrbStack VM |
| go | `make race` |
| sanitizer-canary | `make verify-sanitizers` |

Flaky failures are bugs (CLAUDE.md §5). Repeat locally: `build-tsan/core/helix_core_tests --gtest_repeat=100 --gtest_filter=<Test>` or `go test -race -count=100 -run <Test> ./meta/...`.

## 3. Proving the gate works (day 1 requirement)
1. Create a throwaway branch.
2. Introduce a race in a test, e.g. in `core/test/version_test.cc` add a test where two threads increment a plain `int`.
3. Push → `cpp (tsan)` must fail with "WARNING: ThreadSanitizer: data race".
4. Delete the branch. Record the run URL in the day-1 log.
The `sanitizer-canary` job proves the same continuously without a broken branch.

## 4. Branch protection (set once on GitHub)
Settings → Branches → Add rule for `main`: require a PR, require status checks `lint`, `cpp (test-cpp)`, `cpp (asan)`, `cpp (tsan)`, `cpp (ubsan)`, `go (ubuntu-24.04)`, `sanitizer-canary` (and the arm64 jobs once the repo is public), disallow force pushes.

## 5. Adding a job
Keep jobs < 10 minutes; cache nothing until it hurts; pin action versions (`actions/checkout@v4`, `actions/setup-go@v5`); update this runbook in the same PR.
