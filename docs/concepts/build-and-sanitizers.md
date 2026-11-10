# Build systems, sanitizers and CI (day 1)

## 1. The idea

A systems project is only as trustworthy as the machinery that builds and checks it. Day 1 builds that machinery: a reproducible build (CMake + pinned dependencies), automatic bug detectors (sanitizers), style and static analysis (clang-format, clang-tidy, go vet), and CI that runs all of it on every push on both x86-64 and arm64.

## 2. How Helix uses it

| Piece | File | Why |
| --- | --- | --- |
| CMake ≥ 3.25, C++20, Ninja | `CMakeLists.txt` | Industry standard; `compile_commands.json` feeds clang-tidy and editors |
| Warnings as errors | `cmake/HelixWarnings.cmake` | `-Wconversion -Wsign-conversion -Wshadow -Wold-style-cast` catch real bugs in index/size arithmetic used everywhere in rings and allocators |
| Sanitizers | `cmake/HelixSanitizers.cmake`, `-DHELIX_SANITIZER=address\|thread\|undefined` | One sanitizer per build directory; they cannot be combined freely |
| Pinned deps | `cmake/HelixDependencies.cmake` | googletest pinned by **commit SHA** (ADR-0001) |
| Version | `VERSION` → CMake define → `helix::version()`; Go test reads the same file | One source of truth checked by tests in both languages |
| Makefile | `Makefile` | Human-friendly front door: `make check` is the Definition of Done |
| CI | `.github/workflows/ci.yml` | lint, C++ × {release, ASan, TSan, UBSan}, arm64, Go `-race`, sanitizer canary |
| Canary | `scripts/verify-sanitizers-catch-races.sh` | Proves the detectors actually fire — a CI that cannot fail is worthless |

## 3. Details that matter

### Sanitizers: what each one does

| Sanitizer | Flag | Finds | How it works | Cost |
| --- | --- | --- | --- | --- |
| AddressSanitizer (ASan) | `-fsanitize=address` | Out-of-bounds, use-after-free, double free, leaks (LSan) | Shadow memory: 1 shadow byte per 8 bytes says which are addressable; redzones around allocations; freed memory quarantined | ~2× CPU, ~3× memory |
| ThreadSanitizer (TSan) | `-fsanitize=thread` | Data races (two accesses, ≥1 write, no happens-before) | Instruments every memory access; vector clocks per thread; shadow cells record recent accesses | 5–15× CPU, 5–10× memory |
| UndefinedBehaviorSanitizer (UBSan) | `-fsanitize=undefined` | Signed overflow, misaligned access, bad shifts, null deref, invalid enum/bool | Inserts checks around operations | Small |
| Go race detector | `go test -race` | Data races in Go | Same TSan runtime under the hood | 5–10× |

Key facts interviewers like:
- **TSan only finds races that happen in the run.** It is dynamic: no execution, no report. That is why stress tests run 100× and on arm64.
- **TSan understands `std::atomic` and mutexes** as synchronization; it does not understand hand-rolled fences well (`atomic_thread_fence` support is limited) — prefer orderings on the atomic operations.
- **Custom allocators hide bugs from ASan**: memory recycled by the slab never goes back to `free`. Helix's slab gets a `HELIX_ALLOCATOR_PASSTHROUGH` mode (day 4) that forwards to `malloc` under sanitizers.
- **TSan needs a fixed address-space layout.** Newer kernels randomize mmap more (`vm.mmap_rnd_bits=32`), which collides with TSan's shadow layout → "FATAL: ThreadSanitizer: unexpected memory mapping". Fix: `sudo sysctl -w vm.mmap_rnd_bits=28` (CI does this; the dev runbook persists it).

### Why pin by commit SHA, not tag or tarball hash
A tag can be moved; a tarball URL can be served differently by a mirror; a commit SHA names exact content. Day 1 also learned a practical lesson: in restricted networks GitHub archive downloads may be blocked while `git` reads work, so `GIT_TAG <sha>` with `GIT_SHALLOW FALSE` is the most portable pin.

### Why one build directory per sanitizer
Sanitized and unsanitized objects must not be mixed (ABI/runtime differences), and ASan and TSan cannot be linked together. `build/`, `build-asan/`, `build-tsan/`, `build-ubsan/` keep incremental builds fast.

### Why clang by default
Best sanitizer support, clang-tidy integration, and same compiler on x86 and arm. GCC is verified too (it caught different warnings on day 1).

## 4. Pitfalls

| Symptom | Cause | Fix |
| --- | --- | --- |
| TSan aborts at startup: "unexpected memory mapping" | ASLR entropy too high | `sysctl vm.mmap_rnd_bits=28` |
| `cannot find -lclang_rt.asan` | Compiler-rt runtimes not installed | `apt install libclang-rt-18-dev` |
| ASan silent on a slab bug | Allocator recycles memory | Passthrough mode under sanitizers |
| TSan false negative | The racy interleaving never happened | Stress loops, more threads, arm64, `--gtest_repeat` |
| FetchContent 403 | Network blocks archive downloads | Git SHA pin (as Helix does) or `-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=...` via `CMAKE_ARGS` |
| CI green but tests not run | Test not registered | `gtest_discover_tests`; CI prints test count |

## 5. Try it

```bash
make verify-sanitizers            # both detectors must report the deliberate race
cat scripts/race-demo/cpp/race.cc # read the race; then add std::atomic and watch TSan go quiet
make tsan                         # 4 tests under TSan
```
Experiment: in `race.cc` change `int counter` to `std::atomic<int>` with `memory_order_relaxed` — TSan stops reporting (relaxed atomics are not data races), even though the program has no ordering guarantees beyond atomicity. Explain why that is still correct for a counter.

## 6. Check yourself

1. *Why does the project have a test that is supposed to fail?* — To prove the detector works in this toolchain and CI; otherwise a misconfigured sanitizer silently passes everything.
2. *Can ASan and TSan run in the same binary?* — No: incompatible shadow-memory layouts and runtimes.
3. *What is a data race in C++ terms?* — Two conflicting accesses (≥ 1 write) to the same memory location from different threads, not ordered by happens-before, where at least one is non-atomic. It is undefined behaviour.
4. *Why `-Wconversion`?* — Implicit narrowing (`size_t` → `uint32_t`) in ring indices and sizes is a classic silent bug.
5. *Why does CI run on arm64?* — ARM's weaker memory model exposes missing acquire/release that x86's TSO hides.

## 7. Read more
- Google sanitizers wiki: AddressSanitizerAlgorithm, ThreadSanitizerAlgorithm.
- Serebryany & Iskhodzhanov, "ThreadSanitizer: data race detection in practice" (WBIA 2009).
- CMake docs: FetchContent; "Professional CMake" (Craig Scott), ch. on dependencies.

## Field notes
- Day 1: googletest tarball download returned HTTP 403 behind a proxy; switched to SHA-pinned git fetch. Container lacked `libclang-rt-18-dev`; bootstrap installs it.
