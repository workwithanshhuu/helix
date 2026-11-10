# Day 01 · Environment, repo skeleton, build system, sanitizer CI, documentation

| Field | Value |
| --- | --- |
| Date | 2026-11-10 |
| Milestone | Setup (before M1) |
| Branch / PR | `day-01-repo-skeleton` / opened by the owner after push |
| Day guide | [day-guide.md › Day 1](../plan/day-guide.md) |
| Status | **Repo work complete and verified. Owner steps remaining (§7).** |

## 1. Goal (from the day guide)
An empty but real Helix repo that builds C++ and Go and runs sanitizers in CI. Done when:
- [x] `make build test asan tsan race` all pass locally — verified in a Linux x86-64 environment (§4); **re-run in the OrbStack arm64 VM** (§7)
- [ ] CI is green on both architectures — needs the push (§7)
- [x] The deliberate race is detected — `make verify-sanitizers` and the `sanitizer-canary` CI job; the scratch-branch red run is an owner step (§7)

Beyond the guide (owner request): the full documentation tree — design, API, data model, concepts, interview prep, study guide, ADRs, runbooks, templates — so every later day has a written source of truth.

## 2. What was built

| Step | Result | Files |
| --- | --- | --- |
| Version source of truth | `VERSION` = `0.0.1`, read by CMake, compiled into C++, checked by a Go test | `VERSION` |
| C++ build | CMake ≥ 3.25, C++20, Ninja, `compile_commands.json`; options for tests, benchmarks, warnings-as-errors, sanitizer | `CMakeLists.txt`, `cmake/*.cmake` |
| Strict warnings | `-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion -Wold-style-cast …` + `-Werror` on Helix targets only | `cmake/HelixWarnings.cmake` |
| Sanitizers | `-DHELIX_SANITIZER=address\|thread\|undefined`, applied globally (incl. googletest) | `cmake/HelixSanitizers.cmake` |
| Dependencies | googletest v1.15.2 pinned by commit SHA (ADR-0001) | `cmake/HelixDependencies.cmake` |
| `helix_core` library | `helix::version()`, `helix::build_info()` | `core/include/helix/base/version.h`, `core/src/version.cc` |
| C++ tests | 4 tests: semver format, matches `VERSION`, build info consistent, safe under 8 concurrent threads | `core/test/version_test.cc` |
| Tool | `helix_version` prints build info | `core/tools/helix_version.cc` |
| Go module | `github.com/workwithanshhuu/helix`, Go 1.23; `meta.Version`, `meta.GetBuildInfo()` + 4 tests | `go.mod`, `meta/version.go`, `meta/version_test.go` |
| Makefile | build/test/asan/tsan/ubsan/race/lint/format/check/verify-sanitizers/env/clean + placeholders for later days | `Makefile` |
| Lint configs | clang-format (Google, 100 cols), clang-tidy (warnings as errors), golangci v2, editorconfig, gitattributes, gitignore | dotfiles |
| Sanitizer canary | Deliberate C++ and Go races that **must** be reported | `scripts/verify-sanitizers-catch-races.sh`, `scripts/race-demo/` |
| Environment tooling | `bootstrap-dev.sh` (apt + Go + sysctl), `check-env.sh` (markdown report) | `scripts/` |
| CI | lint · C++ × {release, ASan, TSan, UBSan} on x86-64 and arm64 · Go test + race on both · canary | `.github/workflows/ci.yml` |
| GitHub hygiene | PR template, issue templates | `.github/` |
| Claude Code workflow | Working agreement + slash commands (`/start-day`, `/finish-day`, `/check`, `/explain`, `/adr`, `/postmortem`) | `CLAUDE.md`, `.claude/commands/` |
| Documentation | README, ARCHITECTURE, SPEC, CONTRIBUTING, SECURITY, CoC, CHANGELOG, component READMEs, and `docs/` (see [docs/README.md](../README.md)) | many |

## 3. How it works (owner-level explanation)

**Build flow.** `make build` runs `cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo` then `cmake --build build`. The root `CMakeLists.txt` reads `VERSION`, sets C++20, includes three helper modules and adds `core/`. `core/CMakeLists.txt` passes the version, build type, sanitizer and compiler as **compile definitions** into `version.cc`, so the binary can report exactly how it was built. Tests link `gtest_main` and are registered with `gtest_discover_tests`, so `ctest` lists each test individually.

**Why separate sanitizer builds.** `make tsan` configures `build-tsan/` with `-DHELIX_SANITIZER=thread`. The sanitizer flags are added with `add_compile_options`/`add_link_options` **before** dependencies are fetched, so googletest is instrumented too (mixing instrumented and uninstrumented code causes false reports or misses). ASan and TSan use incompatible shadow memory, so they can never share a binary.

**Why the concurrent version test exists.** `SafeToCallConcurrently` calls `version()` from 8 threads. It is trivial today, but it means TSan runs a multi-threaded test from day 1, and the test pattern (start threads, join, assert) is the template for later stress tests.

**Version consistency across languages.** `VERSION` → CMake → `HELIX_VERSION_STRING` → `helix::version()`; the C++ test compares it against `HELIX_EXPECTED_VERSION` (also from `VERSION`), and the Go test reads `../VERSION` and compares it to `meta.Version`. Bumping one without the other fails CI.

**The canary.** `scripts/verify-sanitizers-catch-races.sh` compiles `race-demo/cpp/race.cc` (two threads increment a plain `int`) with `-fsanitize=thread` and runs `go run -race -tags racedemo ./scripts/race-demo/go`. It **passes only if both print a race report**. The Go demo has a `//go:build racedemo` tag so `go test ./...` and `go vet` never compile it.

**CI.** Every job installs only what it needs, lowers ASLR entropy for TSan (`vm.mmap_rnd_bits=28`), and calls the same `make` targets as a developer — so "works locally" and "works in CI" mean the same thing. arm64 jobs run only for public repos (free runners).

## 4. Evidence

Verified in a Linux build environment (Ubuntu 24.04.5, kernel 6.18, x86-64, 2 vCPU). The owner re-runs the same commands in the OrbStack arm64 VM.

### `make check` (lint + release + ASan + TSan + UBSan + Go race)
```text
$ time make check
# lint: format-check (clang-format --dry-run --Werror + gofmt -l: silent = clean),
#       go vet ./... (clean), clang-tidy -p build on core/*.cc (no findings; the
#       "N warnings generated" lines are suppressed system-header warnings)
ctest --test-dir build        → 100% tests passed, 0 tests failed out of 4
go test ./...                 → ok  github.com/workwithanshhuu/helix/meta
ctest --test-dir build-asan   → 100% tests passed, 0 tests failed out of 4
ctest --test-dir build-tsan   → 100% tests passed, 0 tests failed out of 4
ctest --test-dir build-ubsan  → 100% tests passed, 0 tests failed out of 4
go test -race -count=1 ./...  → ok  github.com/workwithanshhuu/helix/meta  1.013s
real 0m26.7s   (incremental; first clean run includes the googletest fetch and 4 configures)
```

### `make verify-sanitizers`
```text
==> C++: compiling scripts/race-demo/cpp/race.cc with -fsanitize=thread (clang++)
    OK: ThreadSanitizer detected the deliberate race
==> Go: running scripts/race-demo/go with -race
    OK: Go race detector detected the deliberate race
```

### Other checks
- GCC 13.3 build (`CC=gcc CXX=g++` configure in a fresh build dir): compiles with warnings-as-errors; 4/4 tests pass.
- `.github/workflows/ci.yml` parses as valid YAML.

### Environment (`make env`, build environment)
| Fact | Value |
| --- | --- |
| OS / kernel / arch | Ubuntu 24.04.5 LTS / 6.18.44 / x86_64 |
| CPUs / memory / page size | 2 / 7.8 GiB / 4096 B |
| L1d line / NUMA nodes / THP | 64 B / 1 / madvise |
| clang / gcc / cmake / ninja / go | 18.1.3 / 13.3.0 / 3.28.3 / 1.11.1 / 1.24.7 |

**Owner: paste the OrbStack `make env` output here** (expect aarch64, 8 CPUs, cache line 64/128 or 0 = not reported).

## 5. Decisions

| Decision | Alternatives | Why | ADR |
| --- | --- | --- | --- |
| CMake + FetchContent, SHA-pinned | Bazel, vcpkg/Conan, vendoring | Familiar, simple, enough for 2–3 deps; SHA = content-addressed | [0001](../adr/0001-build-system-cmake-fetchcontent.md) |
| gRPC control plane, custom data plane | gRPC everywhere, custom everywhere, eRPC | Right tool per plane; measurable comparison | [0002](../adr/0002-grpc-for-control-plane-custom-data-plane.md) |
| Go + C++20 | All C++, all Go, Rust | Strengths per plane; owner skills | [0003](../adr/0003-two-languages-go-and-cpp.md) |
| OrbStack arm64 dev, rented x86 for numbers | VirtualBox, UTM, cloud dev box | Free, fast, ARM finds ordering bugs | [0004](../adr/0004-dev-environment-orbstack-arm64.md) |
| Raft from scratch | etcd/raft, hashicorp/raft | Learning + interview signal, mitigated by simulator/Porcupine | [0005](../adr/0005-raft-from-scratch.md) |
| clang default compiler | gcc default | Best sanitizers + clang-tidy; GCC still verified | — |
| `RelWithDebInfo` default build type | Release, Debug | Optimized but debuggable; matches benchmarking needs | — |

## 6. Problems hit and how they were solved

| Problem | Root cause | Fix | Time |
| --- | --- | --- | --- |
| A starter `.gitignore` ignored `Makefile` and `*.mod` | Generic template | Wrote a Helix-specific `.gitignore` | 5 min |
| `make lint` failed on `version.cc` | Formatting differed from `.clang-format` | `make format`; CI enforces | 2 min |
| googletest download failed (HTTP 403) and the `URL_HASH` was of an error page | Network proxy blocks GitHub archive URLs but allows git | Pin by git commit SHA with `GIT_SHALLOW FALSE` (ADR-0001) | 15 min |
| Sanitizer link errors (`libclang_rt.*` not found) | Ubuntu's `clang` package doesn't always pull compiler-rt runtimes | `libclang-rt-18-dev` added to `bootstrap-dev.sh` and CI | 5 min |
| TSan "unexpected memory mapping" (known on Ubuntu 24.04 runners) | `vm.mmap_rnd_bits=32` conflicts with TSan's layout | `sysctl vm.mmap_rnd_bits=28` in CI and bootstrap; persisted via `/etc/sysctl.d` in the runbook | prevented |

## 7. Owner steps remaining (in order)

1. **Install OrbStack and create the VM** — [runbook §2](../runbooks/dev-environment.md#2-install-orbstack-and-create-the-machine-on-macos): `orb create ubuntu:noble helix`; set 8 cores / 14 GB.
2. **Bootstrap** inside the VM: `cd /Users/anshu/raft-v2.0/CS-6210_AOS/helix && scripts/bootstrap-dev.sh`, then persist `vm.mmap_rnd_bits=28` (runbook §3).
3. **Verify on arm64**: `make env` (paste into §4 above), `make check`, `make verify-sanitizers`. Also note the page size (`getconf PAGESIZE`: 4096 or 16384) — some ARM kernels use 16 KiB pages.
4. **Push** from macOS: `git push -u origin day-01-repo-skeleton`, open a PR (body: `.github/pull_request_template.md`).
5. **CI green**: all jobs pass. If the repo is private, arm64 jobs are skipped (run step 3 locally instead) — consider making it public to get free arm64 CI.
6. **Prove CI goes red**: follow [ci.md §3](../runbooks/ci.md#3-proving-the-gate-works-day-1-requirement) on a scratch branch; paste the failing run URL here; delete the branch.
7. **Merge** the PR, protect `main` ([ci.md §4](../runbooks/ci.md#4-branch-protection-set-once-on-github)), tick day 1 in [tracker.md](../plan/tracker.md).
8. **Learn block**: read ARCHITECTURE.md and SPEC.md §1; write what each of the five components owns in your own words; answer §9 aloud.

## 8. Docs updated
- [x] concept docs (all created; [build-and-sanitizers](../concepts/build-and-sanitizers.md) has day-1 field notes) · [x] API/DB docs · [x] SPEC · [x] design docs · [x] ADRs 0001–0005 · [x] CHANGELOG · [x] tracker note · [x] interview story ([deep-dive-stories](../interview/deep-dive-stories.md))

## 9. Explain it back

1. **Q: Why does TSan need its own build directory, and why can't it be combined with ASan?**
   **A:** Sanitizers change code generation and link a runtime; all code (including googletest) must be compiled with the same sanitizer, so each gets its own build tree. ASan and TSan both reserve huge shadow-memory regions with different layouts and replace allocator/threading functions differently, so they are mutually exclusive.

2. **Q: What does `-fsanitize=address` do to each memory access?**
   **A:** The compiler inserts a check before each load/store: compute the shadow address (`(addr >> 3) + offset`), read the shadow byte, and if it marks the bytes as unaddressable (redzone, freed memory) report an error. Allocations get redzones around them; freed memory is quarantined so use-after-free is detected.

3. **Q: Why does the project contain code that is supposed to fail?**
   **A:** A sanitizer that is misconfigured (missing runtime, wrong flags, ASLR conflict) can silently pass. The canary proves, on every CI run, that TSan and the Go race detector really report a known race.

4. **Q: How does a version mismatch get caught?**
   **A:** `VERSION` feeds CMake defines; the C++ test compares `helix::version()` to `HELIX_EXPECTED_VERSION`, and the Go test reads `../VERSION` and compares to `meta.Version`. Changing one without the other fails a test.

5. **Q: Why pin googletest to a commit SHA instead of `v1.15.2`?**
   **A:** Tags can move; a SHA names immutable content. It also worked when tarball downloads were blocked, because it uses git.

6. **Q (bonus): Why run CI on arm64?**
   **A:** ARM's weak memory model allows reorderings x86 forbids, so missing acquire/release bugs in lock-free code surface there; the dev VM is arm64 too.

## 10. Tomorrow (day 2)
Benchmark harness (Google Benchmark, pinned + ADR), kernel feature checks (io_uring probe incl. `send_zc`, bpftrace, perf availability in OrbStack), accounts, first measurements. Read [hardware-and-caches.md](../concepts/hardware-and-caches.md) and the foundations refresher's hardware section first.
