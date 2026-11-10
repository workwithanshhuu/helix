# Day 1, from zero: a complete beginner's guide

This guide assumes you know nothing about systems, build tools or distributed systems. It explains every word Day 1 uses, every file Day 1 created, and every command you still have to run, in the order you run them.

**How to use it:** read Parts 1–3 once, slowly (about 90 minutes). Then do Part 4 step by step with a terminal open. Keep Part 7 (the glossary) open in another tab and look up any word you don't know.

---

## Contents

- [Part 0 · Where you are right now](#part-0--where-you-are-right-now)
- [Part 1 · What Helix is, in plain English](#part-1--what-helix-is-in-plain-english)
- [Part 2 · The Day 1 task list, translated](#part-2--the-day-1-task-list-translated)
- [Part 3 · The concepts Day 1 uses, from zero](#part-3--the-concepts-day-1-uses-from-zero)
  - [3.1 Linux, kernels, VMs and OrbStack](#31-linux-kernels-virtual-machines-and-orbstack)
  - [3.2 The terminal, in 15 commands](#32-the-terminal-in-15-commands)
  - [3.3 How C++ code becomes a program](#33-how-c-code-becomes-a-program)
  - [3.4 Build systems: Make, CMake and Ninja](#34-build-systems-make-cmake-and-ninja)
  - [3.5 Go modules and packages](#35-go-modules-and-packages)
  - [3.6 Tests](#36-tests)
  - [3.7 Threads and data races](#37-threads-and-data-races)
  - [3.8 Sanitizers](#38-sanitizers-asan-tsan-ubsan-and-the-go-race-detector)
  - [3.9 Formatters and linters](#39-formatters-and-linters)
  - [3.10 Git and GitHub](#310-git-and-github)
  - [3.11 Continuous integration (CI)](#311-continuous-integration-ci)
  - [3.12 Hardware facts you record today](#312-hardware-facts-you-record-today)
- [Part 4 · Do it: finish Day 1 step by step](#part-4--do-it-finish-day-1-step-by-step)
- [Part 5 · A tour of every Day 1 file](#part-5--a-tour-of-every-day-1-file)
- [Part 6 · Troubleshooting](#part-6--troubleshooting)
- [Part 7 · Glossary](#part-7--glossary)
- [Part 8 · Self-check, with answers](#part-8--self-check-with-answers)
- [Part 9 · Day 1 "Done when" checklist](#part-9--day-1-done-when-checklist)

---

## Part 0 · Where you are right now

Day 1's goal, in one sentence: **build an empty but real project that compiles C++ and Go code, tests it, checks it for memory and threading bugs, and has GitHub re-run all of that on every change.**

Nothing on Day 1 is "Helix" yet. Day 1 builds the workshop, not the product. Every later day assumes the workshop works, which is why it comes first.

A previous session already wrote all the code and documentation for Day 1. What's left is the part only you can do on your own machine and GitHub account.

| Item | State today (10 Nov 2026) |
| --- | --- |
| Repo files: build system, tests, Makefile, CI, lint configs, docs | ✅ Written and committed on branch `day-01-repo-skeleton` |
| Tests pass on a Linux x86 machine | ✅ Verified in an earlier build environment |
| OrbStack installed on your Mac | ✅ Yes |
| Linux machine `helix` | ⚠️ **Exists, but it is Ubuntu 22.04. The plan needs 24.04.** It has no tools installed yet, so replacing it loses nothing. Fix: [Step 1](#step-1--replace-the-linux-machine-with-ubuntu-2404-15-min) |
| Toolchain inside the Linux machine | ❌ Not installed ([Step 2](#step-2--install-the-toolchain-30-min)) |
| Tests pass on *your* arm64 machine | ❌ Not run yet ([Step 4](#step-4--build-and-test-everything-30-min)) |
| Branch pushed to GitHub | ❌ Not yet. Only `main` (one "Initial commit") is on GitHub ([Step 5](#step-5--push-the-branch-and-open-a-pull-request-15-min)) |
| CI green on x86 and arm64 | ❌ Waits on the push ([Step 6](#step-6--watch-ci-go-green-15-min)) |
| CI proven to go red on a race | ❌ Not yet ([Step 7](#step-7--prove-ci-goes-red-on-a-data-race-20-min)) |
| Learn block: notes in your own words | ❌ Yours to do ([Step 9](#step-9--the-learn-block-60-min)) |

Your GitHub repo `workwithanshhuu/helix` is **public**, which matters: GitHub gives public repos free ARM (arm64) CI machines, so both architectures will run.

### Why 22.04 won't work

Ubuntu 22.04's package manager ships CMake 3.22 and clang 14. This repo's `CMakeLists.txt` says `cmake_minimum_required(VERSION 3.25)`, and the plan is written for clang 18. On 22.04, the very first `make build` would fail. Ubuntu 24.04 ships CMake 3.28 and clang 18, exactly what the spec and CI use.

Careful: OrbStack's default `ubuntu` is now 26.04, so you must name the version: `ubuntu:noble` (noble = 24.04).

---

## Part 1 · What Helix is, in plain English

### The one-paragraph version

Helix is a program that runs big math jobs (the kind AI models do) across several computers at once. You hand it a list of math steps where some steps need others' results first. It decides which computer does which step, moves the results between computers as fast as the hardware allows, and if a computer dies halfway through, it notices and redoes the lost work somewhere else, so the job still finishes.

### The kitchen analogy

Picture a restaurant kitchen that cooks huge banquet orders.

| Kitchen | Helix | Technical name |
| --- | --- | --- |
| A banquet order with many dishes | A **job** | Job |
| One cooking step, e.g. "chop onions", "make sauce" | A **task**, e.g. multiply two matrices | Task |
| "Make sauce" can't start until "chop onions" is done | Dependencies between tasks | **DAG** (directed acyclic graph) |
| The ingredients and the dishes in progress | Big grids of numbers | **Tensors** |
| Three managers in the office, each keeping an identical order book, so if one quits the other two carry on | The control plane, kept identical on 3 machines | `helix-meta` + **Raft** |
| The managers decide which station cooks which dish | Picking a worker for each task | **Scheduler** / placement |
| A cooking station with several cooks | One worker computer with several CPU cores | `helixd` worker |
| A cook who runs out of work grabs a ticket from a busy colleague's pile | Idle CPU cores take tasks from busy ones | **Work stealing** |
| Each station's fridge, holding finished dishes | Each worker's store of finished tensors | `helix-store` (object store) |
| Station A hands a finished sauce straight to station B, not through the office | Tensors go worker → worker directly, never through the control plane | **Data plane** vs **control plane** |
| Handing over the actual pot instead of pouring it into a new one | Sending data without copying it in memory | **Zero-copy** |
| A ticket that says "station B owns this dish until 9:05; ticket #42" | Permission to run a task for a limited time, with a number that only goes up | **Lease** + **fencing token** |
| A cook collapses; the manager sees the ticket expired, re-assigns the dish, and re-cooks any lost dishes from the recipe | `kill -9` a worker; the job still finishes | **Fault tolerance by lineage** |

### The five components and what each one owns

"Owns" means: this component is the only one allowed to change that thing. That rule keeps the system understandable. If two components could both change the same data, you'd never know who broke it.

| Component | Language | Owns (is the only one that changes) | Kitchen version |
| --- | --- | --- | --- |
| `libhelix-core` | C++ | Memory allocation, fast thread-safe queues, the per-machine task scheduler, the math kernels | The cooks' techniques and tools: how to chop fast, how to share tickets |
| `helix-rpc` | C++ | The message format on the wire, network connections, bulk data transfer | The hatch between stations and the rules for passing pots through it |
| `helix-store` | C++ | The bytes of finished tensors on one machine | Each station's fridge |
| `helixd` (worker) | C++ | Running tasks on one machine; it glues core + store + rpc together | One cooking station |
| `helix-meta` | Go | All cluster facts: which machines exist, jobs, tasks, leases, where each tensor lives | The managers and their identical order books |

(`helixctl` is a sixth, tiny piece: a command-line tool for talking to `helix-meta`. It owns nothing.)

**Your Learn-block task** is to write this table again *in your own words*, without looking. That's the whole point: if you can explain it, you understand it.

### Why two languages?

- **C++** for the parts where every nanosecond and every byte matters (memory, queues, network bytes, math). C++ gives direct control over memory and CPU.
- **Go** for the control plane, which is about correctness and coordination, not raw speed. Go makes networking and concurrency simpler and safer. (Decision recorded in [ADR-0003](../adr/0003-two-languages-go-and-cpp.md).)

### The 45-day shape

| Days | Milestone | What gets built | Release |
| --- | --- | --- | --- |
| 1–2 | Setup | The workshop: build, tests, CI, benchmarks | — |
| 3–11 | M1 | Single-machine core: allocator, lock-free queues, work-stealing scheduler, matrix math | v0.1 |
| 12–18 | M2 | Fast networking (io_uring, zero-copy) | v0.2 |
| 19–28 | M3 | Raft consensus and the control plane | v0.3 |
| 29–38 | M4 | Workers, object store, scheduling, crash recovery | v0.4 |
| 39–45 | M5 | Metrics, tracing, benchmarks vs Ray and gRPC | v0.5 |

You do **not** need to understand M1–M5 today. Today you only need the five-component table above.

---

## Part 2 · The Day 1 task list, translated

Here is each line of the official day guide ([day-guide.md › Day 1](../plan/day-guide.md)), followed by what it means in plain English.

> **Goal:** an empty but real Helix repo that builds C++ and Go and runs sanitizers in CI.

A project folder that compiles code in both languages, and on every change GitHub automatically runs the bug-detecting tools ("sanitizers") on it. "Empty but real" means: almost no actual code, but all the machinery is real.

> **1.** Install OrbStack; create an Ubuntu 24.04 arm64 machine `helix` with 8 cores and 14 GB. Inside it: `sudo apt install -y build-essential clang lld cmake …`

Your Mac runs macOS, but Helix needs Linux features. OrbStack runs a lightweight Linux computer inside your Mac. "arm64" means it uses the same chip type as your Mac (Apple Silicon is ARM). Then install every tool Helix needs with Ubuntu's installer, `apt`. (You'll use the repo's `scripts/bootstrap-dev.sh`, which installs this list and a bit more.)

> Check `go version` is 1.23+; if apt's is older, install Go from go.dev.

Ubuntu 24.04's Go is 1.22, too old. The bootstrap script installs 1.23.4 from Go's website.

> **2.** Smoke tests: `uname -r` (want 6.1+), `getconf PAGESIZE`, `getconf LEVEL1_DCACHE_LINESIZE`, `nproc`, `lscpu`. Write all values into `notes/day-01.md`.

"Smoke test" = a quick check that something basically works ("turn it on, see if smoke comes out"). These commands print facts about your machine: Linux version, memory page size, cache line size, number of CPUs, CPU details. Later days depend on these numbers, so you write them down. Explained in [3.12](#312-hardware-facts-you-record-today).

> **3.** Create the repo with the layout from Spec §1. Add a root `CMakeLists.txt` with a `helix_core` library holding one function, a GoogleTest test for it (via `FetchContent`), and `go.mod` with one package and one test.

Make the folder structure. Write the C++ build recipe. Write one tiny C++ function (`helix::version()`) and one test for it. Write the Go equivalent. **Already done** — you'll read it in [Part 5](#part-5--a-tour-of-every-day-1-file).

> **4.** `Makefile` targets: `build`, `test`, `asan`, `tsan`, `ubsan`, `race`, `lint`. Sanitizer builds use separate build directories.

A `Makefile` is a menu of named commands. `make tsan` should "build everything with the thread-bug detector and run the tests". Each detector gets its own output folder. **Already done.**

> **5.** GitHub Actions: Ubuntu runners (x86 and `ubuntu-24.04-arm`), jobs for build + test, ASan, TSan, UBSan, Go race. Add `.clang-format`, `.clang-tidy`, `.golangci.yml`.

Tell GitHub to rent fresh Linux machines (both Intel-style x86 and ARM) on every push and run all the checks. Add the config files for the code-style tools. **Already done.**

> **6.** `README.md` with a one-paragraph pitch and "status: day 1"; Apache-2.0 `LICENSE`; push to GitHub.

Front-page description and an open-source license. **Written; the push is yours.**

> **Tests:** one trivial test per language; deliberately add a data race in a scratch branch and confirm the TSan job fails, then delete it.

Prove the safety net actually catches something: write broken code on purpose, watch CI turn red, throw the broken code away. A detector you've never seen fire might be switched off without you knowing.

> **Pitfalls:** building inside the macOS-mounted folder is slow… TSan and ASan can't be combined… Some ARM kernels use 16 KB pages.

Three warnings. (1) Files shared between macOS and Linux are slower to read; fine at today's size. (2) The memory detector and thread detector can't be in the same program. (3) Your page size may be 16 KB instead of the usual 4 KB; write down which.

> **Done when:** `make build test asan tsan race` all pass locally · CI is green on both architectures · The deliberate race made CI red.

Three checks, all must pass. Part 9 is the checklist.

---

## Part 3 · The concepts Day 1 uses, from zero

### 3.1 Linux, kernels, virtual machines and OrbStack

**Operating system (OS).** The software that manages the hardware and runs your programs: macOS, Windows, Linux.

**Kernel.** The core of the OS. It is the only code allowed to touch hardware directly: memory, disks, network cards, CPU scheduling. Your programs ask the kernel for things through **system calls** ("syscalls"), such as "open this file" or "send these bytes".

**Why Linux and not macOS?** Helix uses Linux-only kernel features:

- **io_uring** (Day 12+): a very fast way to do network and disk I/O.
- **futex**, **memfd**, **huge pages**, **NUMA** controls (Days 4–16).
- **eBPF / bpftrace** (Day 2, 41): tools to watch the kernel from inside.
- **perf**: Linux's performance profiler.

Also, real AI infrastructure runs on Linux servers, so that's where the skills transfer.

**Virtual machine (VM).** Software pretending to be a whole computer, running inside your real one. The "guest" (Linux) thinks it has its own CPU, memory and disk; the "host" (your Mac) actually provides them.

**OrbStack.** A Mac app that runs lightweight Linux VMs ("machines") and Docker. Chosen because it starts in seconds, shares files with macOS quickly, and includes Docker for the multi-node cluster later ([ADR-0004](../adr/0004-dev-environment-orbstack-arm64.md)).

Key facts about OrbStack for this project:

- Your Mac's `/Users/anshu` folder appears inside Linux at the same path. So the repo at `/Users/anshu/raft-v2.0/CS-6210_AOS/helix` exists in both places. **Edit on the Mac, build and run in Linux.**
- `orb -m helix` opens a Linux shell in the machine named `helix`. `orb -m helix <command>` runs one command there.
- CPU and memory limits are set for OrbStack as a whole (Settings → System), not per machine. Yours are currently 10 CPUs and 12 GB; the plan asks for 8 and 14 GB (Step 1).
- OrbStack machines share one kernel that OrbStack provides; yours is version 7.2. So `uname -r` will say something like `7.2.12-orbstack-…`, which satisfies "6.1 or newer".

**arm64 vs x86-64.** Two families of CPU, with different instruction sets:

| | arm64 (aarch64) | x86-64 (amd64) |
| --- | --- | --- |
| Found in | Apple Silicon Macs, phones, AWS Graviton | Intel and AMD PCs and most servers |
| Memory ordering | **Weak**: the CPU may reorder memory operations more freely | **Strong**: fewer reorderings allowed |
| Why it matters for Helix | Lock-free bugs show up here that x86 hides | Where the published benchmarks run |

A program compiled for one can't run on the other (OrbStack can emulate, slowly). That's why CI tests both.

**Ubuntu versions have nicknames:** 22.04 = jammy, 24.04 = noble, 26.04 = resolute. "LTS" means long-term support (5 years of updates).

**apt.** Ubuntu's package manager. `sudo apt install <name>` downloads and installs software. `sudo` means "run as administrator" (it will ask for your Linux password, which in OrbStack is usually not set, so it just works).

### 3.2 The terminal, in 15 commands

The terminal is a text window where you type commands. Each line you type is run by a program called the **shell** (zsh on macOS, bash in Ubuntu).

| Command | Does | Example |
| --- | --- | --- |
| `pwd` | Print the folder you're in | `pwd` |
| `ls` | List files (`ls -la` shows hidden ones too) | `ls -la` |
| `cd <folder>` | Change folder (`cd ..` goes up one) | `cd /Users/anshu/raft-v2.0/CS-6210_AOS/helix` |
| `cat <file>` | Print a file | `cat VERSION` |
| `less <file>` | Scroll through a file (`q` quits) | `less Makefile` |
| `mkdir -p <dir>` | Make a folder (and parents) | `mkdir -p notes` |
| `echo` | Print text | `echo hello` |
| `>` / `>>` | Send output to a file (overwrite / append) | `uname -r >> notes/day-01.md` |
| `\|` (pipe) | Feed one command's output into another | `lscpu \| head -20` |
| `grep <text>` | Show lines containing text | `grep -n tsan Makefile` |
| `which <tool>` | Where a program lives (empty = not installed) | `which clang` |
| `sudo` | Run as administrator | `sudo apt update` |
| `Ctrl+C` | Stop the running command | — |
| `↑` arrow | Re-show your previous command | — |
| `echo $?` | Exit status of the last command: `0` = success, anything else = failure | `make test; echo $?` |

**Exit status** matters a lot: `make`, CI and scripts all decide "pass or fail" purely from whether a command exits `0`.

**PATH** is the list of folders the shell searches for programs. If `go` is installed in `/usr/local/go/bin` but that folder isn't in `PATH`, typing `go` says "command not found".

### 3.3 How C++ code becomes a program

C++ source code is text. The computer runs machine code. Turning one into the other happens in stages:

```
 version.h  ──┐
              ├─► [1 preprocessor] ─► [2 compiler] ─► version.o ─┐
 version.cc ──┘     (#include,          (C++ →        (object     │
                     #define)            machine code)  file)      ├─► [3 linker] ─► helix_core_tests
                                                                   │                 (executable you run)
 version_test.cc ─────────► same 2 stages ─► version_test.o ──────┤
 googletest library (gtest_main) ──────────────────────────────────┘
```

1. **Preprocessor.** Handles lines starting with `#`. `#include "x.h"` pastes in another file's text. `#define NAME value` creates a text substitution (a **macro**). `#ifndef X / #define X / #endif` is an **include guard**, which stops a header from being pasted twice.
2. **Compiler** (`clang++` here). Turns one `.cc` file into one **object file** (`.o`) of machine code. This is where warnings and errors appear.
3. **Linker** (`lld`, or the system `ld`). Glues object files and libraries into one **executable** and connects function calls to the functions they call.

**Header vs source.** A header (`.h`) *declares* things ("there is a function `version()` that returns a `string_view`"). A source file (`.cc`) *defines* them (the actual body). Other code includes the header to know what exists; the linker finds the body.

**Library.** A bundle of compiled code other programs link against. `helix_core` is a **static library** (`libhelix_core.a`): its code gets copied into each program that uses it.

**Compiler flags** change how the compiler behaves:

| Flag | Meaning |
| --- | --- |
| `-std=c++20` | Use the C++20 language version |
| `-O2`, `-O1` | Optimize (higher = faster code, harder to debug) |
| `-g` | Include debug info (so errors show file and line) |
| `-Wall -Wextra …` | Turn on warnings |
| `-Werror` | Treat every warning as an error (the build fails) |
| `-fsanitize=address` | Build with AddressSanitizer ([3.8](#38-sanitizers-asan-tsan-ubsan-and-the-go-race-detector)) |
| `-D NAME="value"` | Define a macro from the command line (how the version number gets into the code) |

**Build types** in CMake: `Debug` (no optimization), `Release` (optimized, no debug info), `RelWithDebInfo` (optimized *and* debuggable, Helix's default, because benchmarks need speed and crashes need line numbers).

### 3.4 Build systems: Make, CMake and Ninja

Typing compiler commands by hand for hundreds of files is impossible, so tools do it. Helix uses three, stacked:

```
 you type:  make test
              │
              ▼
 ┌──────────────────────┐   "the menu"     Makefile: named shortcuts for long commands
 │  Make                │   make build / test / asan / tsan / ubsan / race / lint / check
 └─────────┬────────────┘
           │ runs
           ▼
 ┌──────────────────────┐   "the planner"  CMakeLists.txt: WHAT to build (libraries, programs,
 │  CMake               │   tests, flags). Generates a detailed build plan in build/.
 └─────────┬────────────┘
           │ generates a plan for
           ▼
 ┌──────────────────────┐   "the worker"   Runs the actual compiler commands, in parallel,
 │  Ninja               │   and only re-builds what changed.
 └─────────┬────────────┘
           │ calls
           ▼
        clang++ / lld      the compiler and linker
```

**Make and Makefiles.** A Makefile lists **targets** and the commands that produce them:

```make
test: test-cpp test-go        # "test" needs test-cpp and test-go done first
test-cpp: build-cpp           # test-cpp needs build-cpp first
	ctest --test-dir build    # the recipe (MUST start with a Tab character)
```

`.PHONY: test` tells Make "test is a name for a command, not a file". `BUILD_TYPE ?= RelWithDebInfo` means "use this value unless the user already set one". `make` with no target prints the help menu (the repo sets `.DEFAULT_GOAL := help`).

**CMake** has two phases:

1. **Configure:** `cmake -S . -B build -G Ninja` — read `CMakeLists.txt` from the source folder (`-S .`), write a build plan into the build folder (`-B build`), using the Ninja generator (`-G Ninja`). Options like `-DHELIX_SANITIZER=thread` are remembered in `build/CMakeCache.txt`.
2. **Build:** `cmake --build build` — run the plan (CMake calls Ninja).

Core CMake vocabulary in Helix's files:

| Command | Meaning |
| --- | --- |
| `project(helix …)` | Name the project and its version |
| `add_library(helix_core src/version.cc)` | Build a library from these sources |
| `add_executable(helix_core_tests test/version_test.cc)` | Build a runnable program |
| `target_link_libraries(A PRIVATE B)` | A uses B; link them |
| `target_include_directories(...)` | Where to look for headers |
| `target_compile_definitions(...)` | Add `-D` macros |
| `add_subdirectory(core)` | Also read `core/CMakeLists.txt` |
| `option(...)` / `set(... CACHE ...)` | A user-settable switch |
| `FetchContent_Declare / MakeAvailable` | Download another project (googletest) at configure time and build it with ours |
| `enable_testing()` + `gtest_discover_tests(...)` | Register each test so `ctest` can run it |

**Build directory.** All generated files go in `build/` (or `build-asan/`, …), never mixed with source. Delete it any time; `make` re-creates it. Git ignores these folders.

**Why one build directory per sanitizer?** A build directory remembers its settings. If `build/` were reused for TSan, every switch between normal and TSan would recompile everything. Separate folders keep each configuration built and ready. (Also, ASan and TSan can't be combined, [3.8](#38-sanitizers-asan-tsan-ubsan-and-the-go-race-detector).)

**ctest** is CMake's test runner. `ctest --test-dir build` runs every registered test and prints `100% tests passed, 0 tests failed out of 4`.

**`compile_commands.json`.** A file CMake writes listing the exact compiler command for every source file. Editors use it for autocomplete; clang-tidy uses it to analyze code with the right flags.

### 3.5 Go modules and packages

Go is simpler: the build tool is built into the language.

- A **module** is one project, defined by `go.mod`. Helix's says `module github.com/workwithanshhuu/helix` and `go 1.23` (minimum Go version).
- A **package** is one folder of `.go` files. `meta/` is package `meta`.
- `go build ./...` compiles every package (`./...` means "this folder and everything below it").
- `go test ./...` runs every test. Test files end in `_test.go`; test functions look like `func TestXxx(t *testing.T)`.
- `go test -race ./...` runs them with the race detector.
- `go vet ./...` looks for suspicious code.
- `gofmt` formats code. Go has exactly one style, so nobody argues about it.
- **Build tags**: a first line `//go:build racedemo` means "only compile this file if someone passes `-tags racedemo`". The deliberate-race demo uses this so normal builds never see it.

### 3.6 Tests

A **unit test** is a small program that calls your code and checks the result. If any check fails, the test fails, and the build turns red.

**GoogleTest** (C++) looks like this:

```cpp
TEST(VersionTest, MatchesVersionFile) {        // TEST(group name, test name)
  EXPECT_EQ(version(), HELIX_EXPECTED_VERSION); // check: are these equal?
}
```

- `EXPECT_*` records a failure and keeps going; `ASSERT_*` records a failure and stops this test.
- `EXPECT_THAT(x, MatchesRegex("..."))` uses **matchers** from GoogleMock for richer checks.
- `gtest_main` provides the `main()` function, so test files don't need one.

**Go tests** look like this:

```go
func TestVersionIsSemantic(t *testing.T) {
	if !semver.MatchString(Version) {
		t.Fatalf("Version %q is not MAJOR.MINOR.PATCH", Version) // fail and stop
	}
}
```

`t.Errorf` = fail but continue; `t.Fatalf` = fail and stop.

**Why test something as trivial as a version string?** Day 1's tests aren't about the version. They prove the whole chain works: the build finds the code, the test framework runs, sanitizers instrument it, CI executes it. When Day 3's real code arrives, the chain is already trusted.

**Semantic version (semver):** `MAJOR.MINOR.PATCH`, e.g. `0.0.1`. Helix starts at `0.0.1` and tags `v0.1` on Day 11.

### 3.7 Threads and data races

This is the concept behind sanitizers, and the heart of all of M1. Take your time here.

**Process.** A running program, with its own private memory.

**Thread.** A sequence of instructions running inside a process. One process can have many threads, and **they all share the same memory**. On a machine with 8 cores, 8 threads can truly run at the same instant.

**Why threads?** To use all CPU cores at once. Helix's scheduler runs one thread per core.

**The problem: shared memory.** Look at this line, run by two threads at the same time:

```cpp
++counter;
```

It looks like one step, but the CPU does three:

```
1. LOAD  counter from memory into a register
2. ADD   1 to the register
3. STORE the register back to memory
```

Now interleave two threads, starting at `counter = 5`:

```
   Thread A                   Thread B                 counter in memory
   LOAD  (reg = 5)                                       5
                              LOAD  (reg = 5)            5
   ADD   (reg = 6)                                       5
                              ADD   (reg = 6)            5
   STORE                                                 6
                              STORE                      6   ← should be 7. One increment lost.
```

That's a **data race**: two threads access the same memory at the same time, at least one of them writes, and nothing forces them to take turns. Results:

- Wrong answers that change from run to run.
- In C++, a data race is **undefined behavior**: the language makes no promises at all, and the optimizer may produce code that does surprising things.
- Races often hide. They may happen once in a million runs, or only on ARM, or only under load.

**The fixes** (you'll build these from Day 3 on):

- A **mutex** (lock): only one thread at a time may enter a section of code.
- An **atomic** variable: the CPU does LOAD+ADD+STORE as one indivisible step (`std::atomic<int>` in C++).
- **Don't share**: give each thread its own data (what Helix does for speed wherever it can).

The repo's deliberate race, [`scripts/race-demo/cpp/race.cc`](../../scripts/race-demo/cpp/race.cc), is exactly the example above: two threads each add 1 to a plain `int` 100,000 times. The correct answer is 200,000; the race usually prints less.

**Goroutine** is Go's lightweight thread. Same rules: unsynchronized shared writes are races.

### 3.8 Sanitizers: ASan, TSan, UBSan and the Go race detector

A **sanitizer** is a bug detector the compiler builds *into* your program. The compiler inserts extra checking code around memory accesses. The program runs slower, but the instant it does something illegal, it stops and prints exactly what and where.

| Tool | Flag | Catches | Cost |
| --- | --- | --- | --- |
| **ASan** — AddressSanitizer | `-fsanitize=address` | Reading/writing past the end of an array (**buffer overflow**), using memory after freeing it (**use-after-free**), freeing twice, memory leaks | ~2× slower, ~3× memory |
| **TSan** — ThreadSanitizer | `-fsanitize=thread` | **Data races** between threads | ~5–15× slower, ~5–10× memory |
| **UBSan** — UndefinedBehaviorSanitizer | `-fsanitize=undefined` | **Undefined behavior**: signed integer overflow, misaligned pointers, invalid shifts, null dereferences, and more | Small |
| **Go race detector** | `go test -race` | Data races in Go (it is built on TSan's runtime) | ~5–10× slower |

**How ASan works (one of the self-check questions).** ASan sets aside a large region called **shadow memory**: 1 shadow byte describes every 8 bytes of your program's memory, saying whether those bytes are OK to touch. When you allocate an array, ASan surrounds it with "poisoned" **redzones**; when you free memory, it poisons it and holds it in **quarantine** so it isn't reused straight away. Then before **every** load and store, the compiler inserts a check:

```
shadow = *((addr >> 3) + offset)    // look up the shadow byte for this address
if (shadow says "poisoned") report_error_and_stop();
do the real load/store
```

So reading one byte past an array lands in a redzone, the shadow says "poisoned", and you get a report with the exact line.

**How TSan works.** TSan also uses shadow memory, but it records *who* touched each location and *when*, in terms of "which thread, at what point in its history". It tracks **happens-before**: if thread A unlocks a mutex and then thread B locks it, everything A did before the unlock "happened before" what B does after the lock. When two accesses to the same address come from different threads, at least one is a write, and neither happened before the other, TSan reports `WARNING: ThreadSanitizer: data race` with both stack traces.

**Why they need separate builds.** ASan and TSan each reserve huge shadow regions at fixed addresses, with incompatible layouts, and each replaces `malloc` and thread functions in its own way. They can't live in one program. And *every* piece of code in the program, including googletest, must be compiled with the same sanitizer, or TSan sees half the picture and reports false races or misses real ones. Hence `build-asan/`, `build-tsan/`, `build-ubsan/`, each built entirely one way.

**`vm.mmap_rnd_bits=28` (a TSan quirk).** Linux places memory at random addresses to make attacks harder (**ASLR**, address space layout randomization). Some newer systems randomize so widely (32 bits) that memory can land where TSan wants its shadow region, and TSan aborts with `FATAL: ThreadSanitizer: unexpected memory mapping`. Lowering the randomness to 28 bits fixes it. The bootstrap script does this, and Step 2 makes it permanent.

**The canary.** A sanitizer that's misconfigured (missing runtime, wrong flag) can silently pass everything. So the repo contains code that is *supposed* to be caught. [`scripts/verify-sanitizers-catch-races.sh`](../../scripts/verify-sanitizers-catch-races.sh) runs the deliberate C++ and Go races and **passes only if both detectors complain**. CI runs it on every push as the `sanitizer-canary` job. (Named after the canaries miners carried: if the bird stops singing, something is wrong.)

### 3.9 Formatters and linters

| Tool | Language | What it does | Config |
| --- | --- | --- | --- |
| `clang-format` | C++ | Re-formats code to one style (Google style, 100-char lines) | [`.clang-format`](../../.clang-format) |
| `clang-tidy` | C++ | Static analysis: finds likely bugs and bad patterns without running the code | [`.clang-tidy`](../../.clang-tidy) |
| `gofmt` | Go | Formats Go code | built in |
| `go vet` | Go | Finds suspicious Go code | built in |
| `golangci-lint` | Go | Runs many Go linters at once (optional locally) | [`.golangci.yml`](../../.golangci.yml) |

A **formatter** changes layout only. A **linter** points out problems. "Static" means "by reading the code", as opposed to sanitizers, which are "dynamic" (they watch it run).

`make format` fixes formatting for you. `make format-check` (run by CI) fails if anything isn't formatted. If CI's lint job fails on formatting, run `make format`, commit, push.

### 3.10 Git and GitHub

**Git** records snapshots of your project's files over time, on your machine.

| Word | Meaning |
| --- | --- |
| **Repository (repo)** | A project folder whose history Git tracks (the hidden `.git/` folder holds the history) |
| **Commit** | One saved snapshot, with a message saying what changed and why |
| **Branch** | A named line of commits. `main` is the official one; you do work on a side branch like `day-01-repo-skeleton` |
| **Remote** | A copy of the repo elsewhere, here on GitHub, called `origin` |
| **Push** | Send your commits to the remote |
| **Pull** | Fetch the remote's commits into yours |
| **Merge** | Combine one branch's commits into another |

**GitHub** hosts the remote repo and adds:

- **Pull request (PR):** "please merge my branch into `main`". It shows the changes, runs CI, and has a merge button. You use PRs even working alone, because they create a reviewable record of each day.
- **Actions:** GitHub's CI service ([3.11](#311-continuous-integration-ci)).
- **Branch protection:** a rule that `main` can only change through a PR whose CI passed.

**Conventional Commits** is a message format: `type(area): summary`, for example `feat(core): add SPSC ring`, `fix(meta): …`, `build: …`, `ci: …`, `docs: …`, `test: …`. Day 1's commit is `build: day 1 repo skeleton, sanitizer CI and full documentation`.

**The Helix rule:** `main` is always green. Every day gets a branch `day-NN-topic` and a PR.

**License (Apache-2.0).** Says how others may use your code. Apache-2.0 allows almost anything, requires keeping the copyright notice, and includes a patent grant. Industry projects (Kubernetes, TensorFlow) use it.

### 3.11 Continuous integration (CI)

**CI** means: every time you push, a fresh computer somewhere downloads your code and runs all the checks. If any fails, you get a red ❌; if all pass, a green ✅. It catches "works on my machine" problems, because the CI machine has nothing installed except what your instructions install.

**GitHub Actions vocabulary** (the file is [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml), written in **YAML**, an indentation-based config format):

| Word | Meaning | In Helix's file |
| --- | --- | --- |
| **Workflow** | One YAML file in `.github/workflows/` | `ci.yml`, named `ci` |
| **Trigger** (`on:`) | When it runs | pushes to `main`, `day-*`, `feat/*`, `fix/*`; every pull request; a manual button |
| **Job** | A group of steps that runs on one fresh machine; jobs run in parallel | `lint`, `cpp`, `cpp-arm`, `go`, `sanitizer-canary` |
| **Runner** | The machine a job runs on | `ubuntu-24.04` (x86-64), `ubuntu-24.04-arm` (arm64) |
| **Step** | One command or action | `make tsan` |
| **`uses:`** | Run a ready-made action | `actions/checkout@v4` downloads your code; `actions/setup-go@v5` installs Go |
| **Matrix** | Run the same job several times with different values | `target: [test-cpp, asan, tsan, ubsan]` → 4 copies of the `cpp` job |

Helix's CI, drawn out:

```
 push / pull request
        │
        ├── lint ─────────────── format-check, go vet, clang-tidy            (x86)
        ├── cpp  × 4 ─────────── test-cpp | asan | tsan | ubsan              (x86)
        ├── cpp-arm × 4 ──────── test-cpp | asan | tsan | ubsan              (arm64, public repos only)
        ├── go × 2 ───────────── go test + go test -race                     (x86 and arm64)
        └── sanitizer-canary ─── deliberate races MUST be detected           (x86)

     = 12 jobs. All green → ✅ on the commit and the PR.
```

Each job calls the **same `make` targets you run locally**. That's deliberate: "passes locally" and "passes in CI" mean the same thing.

### 3.12 Hardware facts you record today

| Command | Prints | Why Helix cares | Expected on your Mac VM |
| --- | --- | --- | --- |
| `uname -r` | Linux kernel version | io_uring features need ≥ 6.1 (`send_zc` needs 6.0) | `7.2.x-orbstack…` ✅ |
| `uname -m` | CPU architecture | arm64 vs x86 code paths | `aarch64` |
| `getconf PAGESIZE` | Memory **page** size in bytes | The allocator (Day 4) carves memory in pages | `4096` (some ARM kernels: `16384`) |
| `getconf LEVEL1_DCACHE_LINESIZE` | **Cache line** size | Padding against false sharing (Day 3+) | `64` (or `0` = VM doesn't say) |
| `nproc` | Number of CPUs Linux can use | Thread pool size (Day 7) | Matches your OrbStack CPU setting |
| `lscpu` | Detailed CPU info, caches, flags | NEON support, cache sizes (Day 9) | — |

**Page.** The kernel hands out memory in fixed chunks called pages, usually 4 KB. Every memory address belongs to one page.

**Cache line.** The CPU doesn't read single bytes from memory; it reads 64-byte (sometimes 128-byte) blocks into its fast **cache**. If two threads on different cores write two *different* variables that happen to sit in the same cache line, the cores keep stealing the line from each other and everything slows down. That's **false sharing** (Day 3 and [engineering trap 1](../interview/engineering-traps.md)). Apple Silicon's real line is 128 bytes even if the VM reports 64, which is why Helix pads hot data to 128 bytes everywhere.

---

## Part 4 · Do it: finish Day 1 step by step

**Two terminals.** Commands marked **[Mac]** run in the macOS Terminal app. Commands marked **[Linux]** run inside the OrbStack machine. To get a Linux shell in the repo folder:

```bash
cd /Users/anshu/raft-v2.0/CS-6210_AOS/helix
```

```bash
orb -m helix
```

The prompt changes (to something like `anshu@helix:…$`) and you're in Linux, in the same folder. Type `exit` to leave.

**Where the code lives.** The repo stays on the Mac at `/Users/anshu/raft-v2.0/CS-6210_AOS/helix`; Linux sees it at the same path. Edit files in VS Code on the Mac; build and test in Linux. The day guide warns that the shared folder is slower; at Day 1's size that doesn't matter. If builds feel slow in later weeks, the [dev-environment runbook §2](../runbooks/dev-environment.md#2-install-orbstack-and-create-the-machine-on-macos) has the faster setup.

### Step 1 · Replace the Linux machine with Ubuntu 24.04 (15 min)

**[Mac]** Your current `helix` machine is Ubuntu 22.04 with nothing installed. Delete it and make a 24.04 one with the same name. The repo is on your Mac, so it is not touched.

```bash
orb delete helix
```

```bash
orb create ubuntu:noble helix
```

Check it:

```bash
orb -m helix bash -lc '. /etc/os-release; echo $PRETTY_NAME; uname -r; uname -m'
```

Expected: `Ubuntu 24.04.x LTS`, a kernel `7.x…orbstack…`, and `aarch64`.

**Set resources to 8 CPUs and 14 GB.** Either open OrbStack → Settings → System and set CPU limit 8 and memory limit 14 GB, or **[Mac]**:

```bash
orb config set cpu 8
```

```bash
orb config set memory_mib 14336
```

Then restart OrbStack (quit from the menu bar icon and reopen it) so the limits apply. 14 GB leaves your Mac (24 GB) about 10 GB.

### Step 2 · Install the toolchain (30 min)

**[Linux]** In the repo folder:

```bash
scripts/bootstrap-dev.sh
```

What it does, in order:

1. Refuses to run on macOS (it checks `uname -s` says Linux).
2. `apt install`s compilers (clang 18, gcc), sanitizer runtimes (`libclang-rt-18-dev`), CMake, Ninja, git, and libraries for later days: liburing (io_uring), libnuma (NUMA), OpenBLAS (fast math), protobuf + gRPC (control-plane RPC), perf tools, bpftrace, Python + matplotlib (charts), mimalloc (allocator baseline).
3. Checks Go. Ubuntu's is 1.22, too old, so it downloads Go 1.23.4 from go.dev into `/usr/local/go` and adds it to `PATH` in `~/.profile`.
4. Lowers `vm.mmap_rnd_bits` to 28 if it's higher, for TSan.

It takes 5–15 minutes, mostly downloading. Then make two settings permanent:

**TSan setting survives reboots** **[Linux]**:

```bash
echo 'vm.mmap_rnd_bits=28' | sudo tee /etc/sysctl.d/60-helix-tsan.conf
```

```bash
sudo sysctl --system
```

**Go on PATH in every shell** **[Linux]**:

```bash
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc && source ~/.bashrc
```

Check everything is there **[Linux]**:

```bash
clang++ --version | head -1; cmake --version | head -1; ninja --version; go version; clang-tidy --version | head -2
```

Expected: clang 18.x, cmake 3.28.x, ninja 1.11.x, go1.23.x or newer.

### Step 3 · Smoke tests and your notes file (20 min)

**[Linux]** Create your private notes (the `notes/` folder is git-ignored, so it never goes to GitHub):

```bash
mkdir -p notes
```

Run each smoke test and look at the output before moving on:

```bash
uname -r
```

```bash
getconf PAGESIZE
```

```bash
getconf LEVEL1_DCACHE_LINESIZE
```

```bash
nproc
```

```bash
lscpu
```

```bash
sysctl vm.mmap_rnd_bits
```

Now write `notes/day-01.md` (open it in VS Code on the Mac). Copy this template and fill it in:

```markdown
# Day 1 notes

## Machine facts
| Fact | Command | My value | What it means |
| --- | --- | --- | --- |
| Kernel | uname -r | | need ≥ 6.1 for io_uring send_zc |
| Arch | uname -m | | aarch64 = ARM |
| Page size | getconf PAGESIZE | | 4096 or 16384? |
| Cache line | getconf LEVEL1_DCACHE_LINESIZE | | Helix pads to 128 anyway |
| CPUs | nproc | | should match OrbStack setting |
| mmap_rnd_bits | sysctl vm.mmap_rnd_bits | | must be ≤ 28 for TSan |
| L1d / L2 / L3 size | lscpu | | |

## The five components, in my own words
- libhelix-core:
- helix-rpc:
- helix-store:
- helixd:
- helix-meta:

## 5 things I learned today
1.
2.
3.
4.
5.

## Problems I hit and how I fixed them

## Left for tomorrow
```

`make env` (Step 4) prints a fuller report; paste it into the Evidence section of [docs/progress/day-01.md](../progress/day-01.md) where it says "Owner: paste the OrbStack `make env` output here".

### Step 4 · Build and test everything (30 min)

**[Linux]** in the repo folder. Run these one at a time and read each output. The first build downloads googletest from GitHub, so it needs internet and takes a minute or two.

**4a. See the menu:**

```bash
make
```

Prints every target with a one-line description.

**4b. Build:**

```bash
make build
```

What happens: CMake configures `build/` (you'll see little output, because the Makefile hides the configure chatter), Ninja compiles `version.cc`, the test file, googletest and the `helix_version` tool, then `go build ./...` compiles the Go package. Success = it ends without the word `Error` and `echo $?` prints `0`.

Try the tool you just built:

```bash
build/core/helix_version
```

Expected:

```
helix 0.0.1
compiler   Clang-18.1.3
build_type RelWithDebInfo
sanitizer  none
```

**4c. Test:**

```bash
make test
```

Expected (C++ then Go):

```
100% tests passed, 0 tests failed out of 4
ok  	github.com/workwithanshhuu/helix/meta	0.00Xs
```

The 4 C++ tests: `IsSemanticVersion`, `MatchesVersionFile`, `BuildInfoIsConsistent`, `SafeToCallConcurrently`.

**4d. Each sanitizer:**

```bash
make asan
```

```bash
make tsan
```

```bash
make ubsan
```

Each builds a separate folder (`build-asan/`, `build-tsan/`, `build-ubsan/`) with that sanitizer, then runs the same 4 tests. Each should end with `100% tests passed … out of 4`. If TSan aborts with "unexpected memory mapping", Step 2's sysctl didn't apply: run `sudo sysctl -w vm.mmap_rnd_bits=28` and retry.

See the difference for yourself:

```bash
build-tsan/core/helix_version
```

It says `sanitizer  thread`.

**4e. Go race detector:**

```bash
make race
```

Expected: `ok  github.com/workwithanshhuu/helix/meta  1.0XXs` (slower than plain `go test`, because every memory access is being watched).

**4f. Lint:**

```bash
make lint
```

Runs `clang-format` in check mode, `gofmt -l`, `go vet` and `clang-tidy`. Silence means clean. clang-tidy may print "N warnings generated"; those are suppressed warnings from system headers and are fine. A real problem prints the file, line and check name, and the command fails.

**4g. Watch the safety net fire:**

```bash
make verify-sanitizers
```

Expected:

```
==> C++: compiling scripts/race-demo/cpp/race.cc with -fsanitize=thread (clang++)
    OK: ThreadSanitizer detected the deliberate race
==> Go: running scripts/race-demo/go with -race
    OK: Go race detector detected the deliberate race
```

To *see* a TSan report yourself (worth doing once):

```bash
clang++ -std=c++20 -g -O1 -fsanitize=thread -pthread scripts/race-demo/cpp/race.cc -o /tmp/race && /tmp/race
```

Read the report top to bottom: `WARNING: ThreadSanitizer: data race`, then `Write of size 4 … by thread T2`, a stack pointing at `race.cc` line with `++counter`, then `Previous write … by thread T1`, the same line. That's TSan telling you: two threads wrote the same 4-byte `int` with nothing ordering them. Then run it without TSan and compare the counter:

```bash
clang++ -std=c++20 -O2 -pthread scripts/race-demo/cpp/race.cc -o /tmp/race-plain && /tmp/race-plain
```

It may print 200000 (got lucky) or less (lost increments). Either way the program is wrong; only TSan reliably tells you.

**4h. The whole gate in one command:**

```bash
make check
```

Runs lint + test + asan + tsan + ubsan + race. This is the **Definition of Done** gate for every future day. It must end green before you commit anything, ever.

**4i. Environment report:**

```bash
make env
```

Copy its Markdown output into [docs/progress/day-01.md](../progress/day-01.md), §4, replacing the "Owner: paste…" line.

✅ Done-when #1 is now met: `make build test asan tsan race` all pass locally.

Commit the updated progress log **[Mac or Linux]**:

```bash
git add docs/progress/day-01.md docs/study-guide/
```

```bash
git commit -m "docs(progress): record arm64 environment for day 1"
```

### Step 5 · Push the branch and open a pull request (15 min)

**[Mac]** (your GitHub login lives on the Mac):

```bash
cd /Users/anshu/raft-v2.0/CS-6210_AOS/helix
```

```bash
git push -u origin day-01-repo-skeleton
```

`-u` links your local branch to the GitHub one, so later you can just type `git push`.

If it says `Permission denied (publickey)`, your Mac has no SSH key registered with GitHub. Quickest fix: switch the remote to HTTPS and let the GitHub CLI (already logged in) handle the password:

```bash
git remote set-url origin https://github.com/workwithanshhuu/helix.git
```

```bash
gh auth setup-git
```

Then push again.

Open the PR:

```bash
gh pr create --base main --head day-01-repo-skeleton --title "build: day 1 repo skeleton, sanitizer CI and docs" --body-file .github/pull_request_template.md
```

Then edit the description on GitHub to fill in the template (what changed, how it was tested). Or click "Compare & pull request" on the repo page in your browser.

### Step 6 · Watch CI go green (15 min)

Open the PR page, or the **Actions** tab on `github.com/workwithanshhuu/helix`. You'll see 12 jobs (see the [diagram in 3.11](#311-continuous-integration-ci)). Each takes 1–5 minutes. From the Mac you can also watch:

```bash
gh pr checks --watch
```

**Reading a failure:** click the red job → click the red step → read the log from the bottom up; the real error is usually just above `Error: Process completed with exit code 2`. Reproduce it locally with the same make target (e.g. the `cpp (tsan)` job runs `make tsan`). [docs/runbooks/ci.md](../runbooks/ci.md) has more.

✅ Done-when #2: CI green on both architectures (the `cpp-arm` and `go (ubuntu-24.04-arm)` jobs are the arm64 ones).

### Step 7 · Prove CI goes red on a data race (20 min)

You'll add a racy test on a throwaway branch, watch CI fail, then delete it.

**Branch name matters.** CI only runs on pushes to branches named `main`, `day-*`, `feat/*` or `fix/*`. A branch called `scratch` would never trigger CI and you'd wait forever. Use `day-01-race-check`.

**[Mac]**:

```bash
git switch -c day-01-race-check
```

Add this test at the bottom of [core/test/version_test.cc](../../core/test/version_test.cc), just above the closing `}  // namespace`:

```cpp
// DELIBERATELY BROKEN: proves the TSan CI job fails on a data race. Never merge.
TEST(ScratchRaceTest, DeliberateDataRace) {
  int counter = 0;
  auto bump = [&counter] {
    for (int i = 0; i < 100000; ++i) {
      ++counter;  // two threads, plain int, no lock: a data race
    }
  };
  std::thread a(bump);
  std::thread b(bump);
  a.join();
  b.join();
  EXPECT_GT(counter, 0);
}
```

Notice: `EXPECT_GT(counter, 0)` passes even with lost increments. So the **normal** test job stays green. Only TSan sees the bug. That's the lesson: ordinary tests can't be trusted to find races.

Optionally check locally first **[Linux]**: `make tsan` should now fail with `WARNING: ThreadSanitizer: data race`, while `make test` still passes.

Push it **[Mac]**:

```bash
git commit -am "test: deliberate data race to prove TSan CI fails (do not merge)"
```

```bash
git push -u origin day-01-race-check
```

On the Actions tab, expect: `cpp (tsan)` ❌ and `cpp-arm (tsan)` ❌ with "ThreadSanitizer: data race" in the log; `cpp (test-cpp)` ✅. (The `lint` job might also complain about the new test; that's fine. What matters is that TSan went red.)

Copy the failing run's URL into [docs/progress/day-01.md](../progress/day-01.md) §7, step 6. Then throw the branch away **[Mac]**:

```bash
git switch day-01-repo-skeleton
```

```bash
git branch -D day-01-race-check
```

```bash
git push origin --delete day-01-race-check
```

✅ Done-when #3: the deliberate race made CI red.

### Step 8 · Merge, protect `main`, tick the tracker (10 min)

1. Commit and push the progress-log URL from Step 7 (`git commit -am "docs(progress): link the red TSan run"` then `git push`). Wait for green.
2. Merge the PR on GitHub ("Squash and merge" or "Create a merge commit"; either is fine solo).
3. Protect `main`: GitHub → Settings → Branches → Add rule for `main` → require a pull request, require status checks to pass (pick `lint`, the `cpp (…)` jobs, `go (…)`, `sanitizer-canary`), block force pushes. ([ci.md §4](../runbooks/ci.md#4-branch-protection-set-once-on-github))
4. Update your local `main` **[Mac]**:

   ```bash
   git switch main && git pull
   ```

5. Tick Day 1 in [docs/plan/tracker.md](../plan/tracker.md) and in `helix-reference/tracker/45-day-checklist.md`.

### Step 9 · The Learn block (60 min)

The day guide's reading: **Overview sections 1–3** and **Engineering spec section 1**. In this repo they're [docs/plan/full-proposal.md](../plan/full-proposal.md) (or `helix-reference/plan/00-full-proposal.md`) and [SPEC.md](../../SPEC.md) §1. Here's what to pull out of each, so the reading has a purpose:

| Section | Read for | Skip for now |
| --- | --- | --- |
| Overview §1 Vision | The headline demo (kill a worker, job still finishes); the 5 design goals; non-goals; the "Development environment" table (why Mac + OrbStack, what needs rented machines) | GPU rental details |
| Overview §2 Architecture | The diagram ([docs/images/architecture.png](../images/architecture.png)); the 7-step request lifecycle; control traffic goes down, tensor bytes go sideways | The Interfaces table's formats (FlatBuffers etc.) |
| Overview §3 Milestones | One sentence per milestone: what it delivers. Use the 45-day table in [Part 1](#the-45-day-shape) | Every bullet. You'll re-read each milestone when you start it |
| Spec §1 Conventions | Repo layout; Make targets; code rules (no exceptions on hot paths, RAII, explicit memory orders, pad to 128); git workflow; Definition of Done | — |

A translation of the request lifecycle (Overview §2), using the kitchen:

1. Customer places a banquet order. The head manager writes it in the order book; once 2 of 3 managers have it written down, it's official ("committed").
2. Managers pick a station for each group of dishes and write a ticket with an ever-increasing number.
3. At the station, the dish tickets go on cooks' piles; idle cooks grab from busy cooks' piles.
4. A cook cooks the dish straight into a fridge slot and labels it with the ticket number.
5. The station tells the managers "dish X is in my fridge".
6. Another station that needs dish X takes it straight from this station's fridge.
7. If a ticket expires (station went silent), managers issue a new, higher-numbered ticket elsewhere and re-cook any lost ingredients.

Then: write the five-component table in your own words in `notes/day-01.md` (no peeking), write 5 bullets of what you learned, and answer the [self-check questions](#part-8--self-check-with-answers) out loud.

---

## Part 5 · A tour of every Day 1 file

Read these with the files open side by side. Understanding these ~400 lines means you understand Day 1.

### The map

```
helix/
├── VERSION                       "0.0.1": the one place the version is written
├── Makefile                      the command menu (make build/test/tsan/…)
├── CMakeLists.txt                C++ root build recipe
├── cmake/
│   ├── HelixWarnings.cmake       the strict warning flags
│   ├── HelixSanitizers.cmake     turns -DHELIX_SANITIZER=… into compiler flags
│   └── HelixDependencies.cmake   downloads googletest (pinned)
├── core/                         libhelix-core (C++)
│   ├── CMakeLists.txt            builds the library, tool and tests
│   ├── include/helix/base/version.h   the public declaration
│   ├── src/version.cc            the implementation
│   ├── test/version_test.cc      4 GoogleTest tests
│   └── tools/helix_version.cc    small program that prints build info
├── go.mod                        Go module definition
├── meta/                         helix-meta (Go)
│   ├── version.go                Version constant + GetBuildInfo()
│   └── version_test.go           4 Go tests
├── scripts/
│   ├── bootstrap-dev.sh          installs the toolchain in Linux
│   ├── check-env.sh              prints the machine report (make env)
│   ├── verify-sanitizers-catch-races.sh   the canary
│   └── race-demo/{cpp,go}/       the deliberately broken programs
├── .github/workflows/ci.yml      the CI pipeline
├── .clang-format .clang-tidy .golangci.yml .editorconfig   style and lint configs
├── .gitignore .gitattributes     what git ignores; line-ending rules
├── rpc/ store/ worker/ proto/ bench/ deploy/ tools/ test/   empty placeholders (README only) for later days
├── docs/                         all documentation (this guide lives in docs/study-guide/)
├── README.md ARCHITECTURE.md SPEC.md CHANGELOG.md LICENSE …   front-page docs
└── CLAUDE.md .claude/commands/   instructions for Claude Code sessions
```

### How the version number flows (the clever part of Day 1)

```
                 VERSION  ("0.0.1")
                    │
     ┌──────────────┴─────────────────┐
     │ read by CMakeLists.txt         │ read by meta/version_test.go
     ▼                                ▼
 PROJECT_VERSION = 0.0.1         compared with const Version = "0.0.1"
     │                                in meta/version.go
     ├─► -DHELIX_VERSION_STRING="0.0.1"  ──► compiled into version.cc ──► helix::version()
     └─► -DHELIX_EXPECTED_VERSION="0.0.1" ─► compiled into the test   ──┘ compared in
                                                                          MatchesVersionFile
```

Change `VERSION` without updating `meta/version.go` → the Go test fails. Build from a stale configuration → the C++ test fails. One fact, written once, checked in both languages.

### `core/include/helix/base/version.h`

```cpp
#ifndef HELIX_BASE_VERSION_H_   // include guard: if not yet defined…
#define HELIX_BASE_VERSION_H_   // …define it, so a second #include skips everything

#include <string_view>          // std::string_view: a read-only window onto text, no copy

namespace helix {               // all Helix names live in "helix::" to avoid clashes

struct BuildInfo {              // a plain bundle of four text fields
  std::string_view version;     // "0.0.1"
  std::string_view compiler;    // "Clang-18.1.3"
  std::string_view build_type;  // "RelWithDebInfo"
  std::string_view sanitizer;   // "none" / "address" / "thread" / "undefined"
};

[[nodiscard]] std::string_view version() noexcept;
[[nodiscard]] BuildInfo build_info() noexcept;
}  // namespace helix
#endif
```

- `[[nodiscard]]`: the compiler warns if someone calls the function and ignores the result (calling `version();` alone is surely a mistake).
- `noexcept`: promises the function never throws an exception. Helix avoids exceptions on fast paths (Spec §1).
- Why `string_view` and not `std::string`? The text is a **string literal** baked into the program, which lives forever. A `string_view` points at it without copying or allocating memory. That makes the function thread-safe for free: nothing is ever written.

### `core/src/version.cc`

```cpp
#ifndef HELIX_VERSION_STRING
#define HELIX_VERSION_STRING "0.0.0-unknown"   // fallback if CMake didn't pass -D…
#endif
…
std::string_view version() noexcept { return HELIX_VERSION_STRING; }

BuildInfo build_info() noexcept {
  return BuildInfo{
      .version = HELIX_VERSION_STRING,   // C++20 "designated initializers": name each field
      .compiler = HELIX_COMPILER_STRING,
      …
  };
}
```

The macros come from `core/CMakeLists.txt` (`target_compile_definitions`). The fallbacks keep the file compilable for tools like editors that don't see CMake's flags; the test `Not(StrEq("unknown"))` catches a real build that lost them.

### `core/test/version_test.cc`

| Test | Checks | Why it exists |
| --- | --- | --- |
| `IsSemanticVersion` | The version matches `digits.digits.digits` | Pins the format |
| `MatchesVersionFile` | `version()` equals `HELIX_EXPECTED_VERSION` from the `VERSION` file | Catches stale builds |
| `BuildInfoIsConsistent` | Fields aren't empty, sanitizer is one of 4 known names, compiler isn't "unknown" | Catches broken CMake wiring |
| `SafeToCallConcurrently` | 8 threads × 10,000 calls each, all see the right version | Gives TSan a multi-threaded test to watch from Day 1; a template for later stress tests |

The concurrent test pattern (you'll reuse it constantly):

```cpp
std::vector<std::thread> threads;
for (int t = 0; t < kThreads; ++t) {
  threads.emplace_back([] { /* work */ });   // start a thread running this lambda
}
for (auto& th : threads) th.join();          // wait for every thread to finish
```

A **lambda** (`[] { … }`) is an unnamed function written inline. `[&counter]` in the scratch test means "this lambda may use the outer `counter` by reference".

### `core/CMakeLists.txt`

```cmake
add_library(helix_core src/version.cc)             # build libhelix_core.a
add_library(helix::core ALIAS helix_core)          # nicer name others link to
target_include_directories(helix_core PUBLIC …/include)   # users see headers as "helix/base/version.h"
target_compile_definitions(helix_core PRIVATE HELIX_VERSION_STRING="${PROJECT_VERSION}" …)
helix_set_warnings(helix_core)                     # apply the strict warnings (cmake/HelixWarnings.cmake)

add_executable(helix_version tools/helix_version.cc)
target_link_libraries(helix_version PRIVATE helix::core)

add_executable(helix_core_tests test/version_test.cc)
target_link_libraries(helix_core_tests PRIVATE helix::core GTest::gtest_main GTest::gmock)
gtest_discover_tests(helix_core_tests)             # ctest lists each TEST() separately
```

`PUBLIC` = applies to this target and to anyone who links it. `PRIVATE` = only this target.

### `CMakeLists.txt` (root) and `cmake/*.cmake`

- Reads `VERSION`, sets C++20 strictly (`CMAKE_CXX_EXTENSIONS OFF` means no compiler-specific dialect), turns on `compile_commands.json`, defaults to `RelWithDebInfo`.
- Declares the options `HELIX_BUILD_TESTS`, `HELIX_WARNINGS_AS_ERRORS`, `HELIX_SANITIZER`.
- **HelixWarnings.cmake**: `-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wsign-conversion …` plus `-Werror`. Strict on purpose: `-Wconversion` catches silent number truncation (e.g. a 64-bit size squeezed into 32 bits), a classic source of allocator and network bugs. Applied only to Helix's own targets, not googletest.
- **HelixSanitizers.cmake**: turns `address` / `thread` / `undefined` into flags, applied **globally** (`add_compile_options`) **before** googletest is downloaded, so googletest is instrumented too. `-fno-omit-frame-pointer` keeps stack traces readable.
- **HelixDependencies.cmake**: downloads googletest at an exact **commit SHA** (`b514bdc…`, which is v1.15.2). A tag like `v1.15.2` can be moved by its owner; a SHA is a fingerprint of the exact content, so it can't change ([ADR-0001](../adr/0001-build-system-cmake-fetchcontent.md)).

### `Makefile`

The pieces you'll actually use:

```make
BUILD_TYPE ?= RelWithDebInfo                 # overridable: make build BUILD_TYPE=Debug
define configure                             # a reusable snippet: configure(dir, extra args)
	cmake -S . -B $(1) -G "$(GENERATOR)" -DCMAKE_BUILD_TYPE=$(BUILD_TYPE) $(CMAKE_ARGS) $(2) >/dev/null
endef

tsan:
	$(call configure,build-tsan,-DHELIX_SANITIZER=thread)   # configure build-tsan/ with TSan
	cmake --build build-tsan -j $(JOBS)                      # compile using all CPUs
	TSAN_OPTIONS=halt_on_error=1:… ctest --test-dir build-tsan …   # stop at the first race

check: lint test asan tsan ubsan race        # the Definition-of-Done gate
```

`TSAN_OPTIONS`, `ASAN_OPTIONS`, `UBSAN_OPTIONS` are environment variables the sanitizer runtimes read. `halt_on_error=1` makes the first report fail the test (otherwise it might print a warning and still "pass"). `detect_leaks=1` turns on leak checking for ASan.

Placeholder targets (`bench`, `cluster-up`, `chaos`) exist today but just print "arrives on day N", so the menu matches the spec from day one.

### `meta/version.go` and `meta/version_test.go`

```go
package meta                    // this folder is package "meta"

import "runtime"                // Go's standard library: info about the running program

const Version = "0.0.1"         // must equal the VERSION file (a test enforces it)

type BuildInfo struct {         // like the C++ struct
	Version, GoVersion, OS, Arch string
}

func GetBuildInfo() BuildInfo { // capital letter = exported (usable from other packages)
	return BuildInfo{Version: Version, GoVersion: runtime.Version(), OS: runtime.GOOS, Arch: runtime.GOARCH}
}
```

`TestBuildInfoConcurrent` starts 8 goroutines with a `sync.WaitGroup` (a counter you `Add(1)` per goroutine, each calls `Done()`, and `Wait()` blocks until it reaches zero), the Go twin of the C++ concurrent test.

### `.github/workflows/ci.yml`

Walk through one job:

```yaml
cpp:
  runs-on: ubuntu-24.04                 # a fresh x86-64 Ubuntu machine
  strategy:
    fail-fast: false                    # if asan fails, still finish tsan/ubsan so you see everything
    matrix:
      target: [test-cpp, asan, tsan, ubsan]   # → 4 parallel copies of this job
  steps:
    - uses: actions/checkout@v4         # download the repo
    - run: sudo apt-get update && sudo apt-get install -y clang libclang-rt-18-dev ninja-build cmake
    - run: sudo sysctl -w vm.mmap_rnd_bits=28   # the TSan ASLR fix
    - run: make ${{ matrix.target }}    # e.g. "make tsan"
```

Other details:

- `concurrency: cancel-in-progress: true`: if you push twice quickly, the older run is cancelled, saving time.
- `permissions: contents: read`: the workflow can read the repo but not change it (least privilege).
- `if: ${{ !github.event.repository.private }}` on `cpp-arm`: arm64 runners are free only for public repos, so the job skips itself on a private repo. Yours is public, so it runs.

### `scripts/`

- **bootstrap-dev.sh**: covered in [Step 2](#step-2--install-the-toolchain-30-min). `set -euo pipefail` at the top means: stop on any error (`-e`), treat unset variables as errors (`-u`), and fail a pipeline if any part fails (`pipefail`). Every Helix script starts this way so failures are never silent.
- **check-env.sh**: prints the machine report as Markdown and exits non-zero if a hard requirement (Linux, kernel ≥ 6.1, a C++ compiler, cmake, Go) is missing. Soft requirements (liburing, libnuma, bpftrace) only warn, because they're needed later.
- **verify-sanitizers-catch-races.sh**: compiles the racy C++ program with TSan, runs it, and `grep`s the output for `WARNING: ThreadSanitizer: data race`; runs the Go one with `-race` and looks for `DATA RACE`. Exit 0 only if both appear. Note the inversion: this script **succeeds when the code fails**.

### Docs that came with Day 1

You don't need to read these today, but know they exist:

| Folder | Contains | Read when |
| --- | --- | --- |
| [docs/concepts/](../concepts/) | Deep explanations (build & sanitizers, caches, memory ordering, Raft…) | Before each day that uses the concept |
| [docs/adr/](../adr/) | 5 decision records: why CMake, why gRPC for control, why Go+C++, why OrbStack, why Raft from scratch | When asked "why did you choose X?" |
| [docs/design/](../design/) | One design doc per milestone | Start of each milestone |
| [docs/runbooks/](../runbooks/) | How-to procedures: dev environment, CI, git | When doing that task |
| [docs/progress/](../progress/) | One log per day | End of each day |
| [docs/interview/](../interview/) | Pitch, stories, question bank | Interview prep |
| [docs/study-guide/glossary.md](glossary.md) | Short glossary for the whole project | Any time |

---

## Part 6 · Troubleshooting

| What you see | Why | Fix |
| --- | --- | --- |
| `CMake 3.25 or higher is required. You are running version 3.22` | You're on the Ubuntu 22.04 machine | [Step 1](#step-1--replace-the-linux-machine-with-ubuntu-2404-15-min) |
| `bootstrap-dev.sh: error: run this inside the Linux machine` | You ran it in the Mac terminal | `orb -m helix` first |
| `go: command not found` after bootstrap | New `PATH` not loaded in this shell | `source ~/.profile` or open a new shell; check Step 2's `.bashrc` line |
| `go: go.mod requires go >= 1.23` | Old apt Go found first on `PATH` | `which go` should print `/usr/local/go/bin/go`; fix `PATH` order |
| `FATAL: ThreadSanitizer: unexpected memory mapping` | ASLR entropy too high | `sudo sysctl -w vm.mmap_rnd_bits=28`, and Step 2's permanent file |
| `cannot find …libclang_rt.asan…` / `tsan` at link time | Sanitizer runtimes missing | `sudo apt install libclang-rt-18-dev` |
| `clang-tidy: command not found` during `make lint` | Not installed | `sudo apt install clang-tidy` |
| googletest download fails during the first build | No internet, or GitHub blocked | Check the network and retry; offline fallback in the [runbook](../runbooks/dev-environment.md#6-troubleshooting) |
| `make format-check` fails / CI `lint` red on formatting | Code doesn't match `.clang-format` | `make format`, commit, push |
| `error: … [-Werror,-Wsign-conversion]` | A warning, promoted to an error | Fix the code (usually an explicit `static_cast<…>`); don't turn warnings off |
| Weird errors after changing CMake options | Stale build directory | `make clean` then rebuild |
| `exec format error` running something in `build/` from macOS | Those are Linux binaries | Run them inside `orb -m helix` |
| `Permission denied (publickey)` on push | No SSH key on GitHub | Step 5's HTTPS fix |
| Pushed the race branch but no CI run appears | Branch name doesn't match the triggers | Name it `day-…`, `feat/…` or `fix/…` |
| `cpp-arm` jobs show "skipped" | Repo is private | Make it public, or rely on local arm64 runs |
| Builds feel very slow | Shared macOS folder overhead | Fine for now; see the faster setup in the [runbook §2](../runbooks/dev-environment.md#2-install-orbstack-and-create-the-machine-on-macos) |

**General debugging habit:** read the *first* error, not the last. Compilers often print one real error followed by many consequences of it.

---

## Part 7 · Glossary

Every technical word Day 1 uses, alphabetically.

| Term | Plain-English meaning |
| --- | --- |
| **ADR** | Architecture Decision Record: a short document saying what was decided, why, and what alternatives were rejected |
| **apt** | Ubuntu's tool for installing software |
| **arm64 / aarch64** | The CPU family in Apple Silicon Macs and phones |
| **ASan** | AddressSanitizer: catches memory errors (overflows, use-after-free, leaks) |
| **ASLR** | Address Space Layout Randomization: Linux places memory at random addresses for security |
| **Assertion** | A check in a test that a value is what you expect |
| **Atomic** | An operation the CPU does as one indivisible step, so threads can't interleave inside it |
| **Benchmark** | A program that measures how fast something is (Day 2) |
| **Branch** | A named line of commits in git |
| **Build directory** | The folder where all generated build files go (`build/`, `build-tsan/`) |
| **Build type** | Debug / Release / RelWithDebInfo: how much to optimize and whether to keep debug info |
| **Cache (CPU)** | Small, very fast memory on the CPU holding recently used data |
| **Cache line** | The block size (64 or 128 bytes) the CPU moves between memory and cache |
| **CI** | Continuous Integration: automatic checks on every push |
| **clang / clang++** | The C / C++ compiler Helix uses (from the LLVM project) |
| **clang-format / clang-tidy** | C++ formatter / C++ static analyzer |
| **CMake** | Tool that reads `CMakeLists.txt` and generates a build plan |
| **Commit** | A saved snapshot of the project in git |
| **Compiler** | Program that turns source code into machine code |
| **Concurrency** | Several things in progress at once (threads, goroutines) |
| **Configure** | CMake's first phase: read the recipe, write the build plan |
| **Control plane** | The part of a distributed system that makes decisions and holds metadata (Helix: `helix-meta`) |
| **ctest** | CMake's test runner |
| **DAG** | Directed Acyclic Graph: tasks with arrows "A must finish before B", and no loops |
| **Data plane** | The part that moves the actual data (Helix: `helix-rpc` between workers) |
| **Data race** | Two threads access the same memory at once, at least one writes, with no synchronization |
| **Definition of Done** | The checklist every change must pass (`make check` green, tests, docs) |
| **Dependency** | (1) Code your project uses from someone else, like googletest. (2) A task that must finish before another starts |
| **Distributed system** | Several computers working together as one system over a network |
| **Executable** | A program file you can run |
| **Exit status** | A number a command returns: 0 = success |
| **False sharing** | Threads writing different variables in the same cache line, slowing each other down |
| **Fault tolerance** | Keeps working when parts fail |
| **FetchContent** | CMake feature that downloads a dependency during configure |
| **Fencing token** | An ever-increasing number on a lease; stale holders with old numbers get rejected |
| **Flag** | An option passed to a command, like `-O2` or `-race` |
| **Formatter** | Tool that rewrites code layout to a standard style |
| **gcc / g++** | The GNU C / C++ compiler (an alternative to clang) |
| **Generator** | What CMake produces a plan for (Ninja, Unix Makefiles) |
| **Git / GitHub** | Version-control tool / website that hosts git repos and runs CI |
| **GitHub Actions** | GitHub's CI service |
| **Go** | Programming language used for the control plane |
| **go.mod** | File defining a Go module (project) and its minimum Go version |
| **GoogleTest (gtest) / GoogleMock (gmock)** | C++ test framework / its matcher and mocking library |
| **Goroutine** | Go's lightweight thread |
| **Happens-before** | A guaranteed ordering between two events in different threads (e.g. via a lock) |
| **Header (.h)** | C++ file that declares what exists |
| **Huge pages** | 2 MB memory pages instead of 4 KB, fewer lookups for big data (Day 4) |
| **Include guard** | `#ifndef X / #define X / #endif` so a header is only pasted once |
| **Instrumentation** | Extra checking code a sanitizer inserts into your program |
| **io_uring** | Fast Linux interface for network and disk I/O (Day 12) |
| **Job** | One user request to Helix: a whole DAG of tasks |
| **Kernel** | The core of the OS that controls hardware |
| **Lambda** | An unnamed function written inline: `[] { … }` |
| **Latency / p99** | Time one operation takes / the time 99% of operations beat (the slowest 1% are slower) |
| **Lease** | Time-limited permission, e.g. "worker 3 runs task 7 until 9:05" |
| **Library** | Compiled code other programs link against |
| **License** | Legal terms for using the code (Helix: Apache-2.0) |
| **Lineage** | The record of which tasks produced which data, so lost data can be recomputed |
| **Linker** | Joins object files and libraries into an executable |
| **Linter** | Tool that reads code and flags likely problems |
| **Lock-free** | Thread-safe data structures that use atomics instead of locks (Day 3+) |
| **Macro** | A `#define` text substitution done by the preprocessor |
| **Make / Makefile** | Tool that runs named commands / the file listing them |
| **Matrix (CI)** | Running one job several times with different parameters |
| **Memory ordering** | Rules about when one thread's writes become visible to another, and in what order (Day 3) |
| **Module (Go)** | One Go project, defined by `go.mod` |
| **Mutex** | A lock: only one thread at a time may hold it |
| **Namespace** | A name prefix (`helix::`) that keeps names from clashing |
| **Ninja** | Fast tool that executes the build plan CMake generates |
| **`noexcept`** | C++ promise that a function never throws |
| **`[[nodiscard]]`** | C++ attribute: warn if the caller ignores the return value |
| **NUMA** | Non-Uniform Memory Access: on big servers, memory near one CPU socket is faster for that socket |
| **Object file (.o)** | Machine code for one source file, before linking |
| **Object store** | Per-machine storage for finished tensors (`helix-store`) |
| **OrbStack** | Mac app that runs Linux machines and Docker |
| **Package (Go)** | One folder of Go files |
| **Page** | The unit (usually 4 KB) in which the kernel manages memory |
| **PATH** | List of folders the shell searches for programs |
| **Pipeline (shell)** | `a \| b`: b reads a's output |
| **Preprocessor** | First compile stage; handles `#include`, `#define` |
| **Process** | A running program with its own memory |
| **Pull request (PR)** | A GitHub request to merge one branch into another, with review and CI |
| **Push** | Send commits to GitHub |
| **Raft** | An algorithm that keeps several copies of a log identical across machines, even if some fail (Day 19) |
| **RAII** | C++ pattern: an object's constructor acquires a resource, its destructor releases it, so cleanup is automatic |
| **Race detector (Go)** | `go test -race`: Go's TSan-based race finder |
| **Redzone** | Poisoned bytes ASan places around allocations to catch overflows |
| **Remote** | A copy of the repo elsewhere (`origin` = GitHub) |
| **Repository (repo)** | A project folder tracked by git |
| **RPC** | Remote Procedure Call: calling a function on another machine over the network |
| **Runner** | The machine a CI job runs on |
| **Sanitizer** | Compiler-inserted bug detector that checks the program while it runs |
| **Scheduler** | Decides which task runs where and when |
| **Semver** | Semantic versioning: MAJOR.MINOR.PATCH |
| **Shadow memory** | A sanitizer's private memory describing the state of your program's memory |
| **SHA (commit SHA)** | A unique fingerprint of a git commit's exact content |
| **Shell** | The program that reads your terminal commands (bash, zsh) |
| **Smoke test** | A quick "does it basically work?" check |
| **Source file (.cc)** | C++ file with the actual code |
| **Static analysis** | Finding bugs by reading code, without running it |
| **Static library (.a)** | A library whose code is copied into each program that uses it |
| **`std::string_view`** | A read-only view of text that doesn't copy it |
| **sudo** | Run a command as administrator |
| **Syscall** | A program's request to the kernel |
| **sysctl** | Command to read/change kernel settings |
| **Target (Make/CMake)** | A named thing to build or do |
| **Task** | One unit of work in a Helix job, e.g. one matrix multiply |
| **Tensor** | A multi-dimensional grid of numbers (the data of AI models) |
| **Thread** | A line of execution inside a process; threads share memory |
| **Throughput** | How many operations complete per second |
| **Toolchain** | The set of tools needed to build: compiler, linker, CMake, Go… |
| **TSan** | ThreadSanitizer: catches data races |
| **UBSan** | UndefinedBehaviorSanitizer: catches undefined behavior |
| **Ubuntu (jammy / noble)** | A Linux distribution (22.04 / 24.04) |
| **Undefined behavior (UB)** | C++ code the language standard gives no meaning to; anything can happen |
| **Unit test** | A small test of one piece of code |
| **VM** | Virtual machine: a computer simulated in software |
| **Work stealing** | Idle threads take tasks from busy threads' queues (Day 6–7) |
| **Worker** | A machine (process `helixd`) that runs tasks |
| **YAML** | Indentation-based config format used by GitHub Actions |
| **Zero-copy** | Moving data without the CPU copying bytes from one buffer to another |

---

## Part 8 · Self-check, with answers

Try each question out loud first, then read the answer. If you can't answer, re-read the linked section.

**The day guide's two questions**

1. **Why does TSan need its own build?**
   Every piece of code in the program, including libraries like googletest, has to be compiled with TSan's instrumentation, or TSan only sees part of the memory accesses and gets races wrong. And TSan can't be combined with ASan: both reserve huge shadow-memory regions at fixed, incompatible addresses and replace memory and thread functions in their own ways. So each sanitizer gets its own fully-instrumented build in its own directory. ([3.8](#38-sanitizers-asan-tsan-ubsan-and-the-go-race-detector))

2. **What does `-fsanitize=address` do to each memory access?**
   Before every load and store, the compiler inserts a check: compute the shadow address (`(addr >> 3) + offset`), read that shadow byte, and if it says those bytes are poisoned (a redzone around an allocation, or freed memory in quarantine), stop and report the error with a stack trace. ([3.8](#38-sanitizers-asan-tsan-ubsan-and-the-go-race-detector))

**Your own understanding**

3. **What is a data race, and why can't a normal test find it reliably?**
   Two threads touch the same memory at the same time, at least one writes, with nothing ordering them. Whether it goes wrong depends on exact timing, which changes every run, so a normal test may pass a million times. TSan tracks happens-before and reports the race even on runs where the answer happens to come out right. ([3.7](#37-threads-and-data-races))

4. **Why does the repo contain code that is supposed to fail?**
   A misconfigured sanitizer silently passes everything. The canary proves on every CI run that TSan and the Go race detector really fire on a known race. ([3.8](#38-sanitizers-asan-tsan-ubsan-and-the-go-race-detector))

5. **What are the three layers between `make test` and the compiler?**
   Make (the menu) runs CMake (the planner), which generates a plan that Ninja (the worker) executes by calling clang++. ([3.4](#34-build-systems-make-cmake-and-ninja))

6. **Why does CI run on arm64 as well as x86?**
   ARM's weaker memory ordering allows reorderings x86 forbids, so lock-free bugs from Day 3 on surface on ARM and hide on x86. Your dev machine is ARM, and the published benchmarks are on x86; both must work. ([3.1](#31-linux-kernels-virtual-machines-and-orbstack))

7. **How would a mismatched version get caught?**
   `VERSION` feeds CMake, which compiles it into both `helix::version()` and the test's expected value; the Go test reads `VERSION` and compares it to `meta.Version`. Changing one without the other fails a test. ([Part 5](#how-the-version-number-flows-the-clever-part-of-day-1))

8. **Why pin googletest to a commit SHA instead of the tag `v1.15.2`?**
   A tag can be moved to different code; a SHA is a fingerprint of exact content and can't change. Builds stay reproducible.

9. **What's the difference between the control plane and the data plane in Helix?**
   The control plane (`helix-meta`, Go, Raft) decides and remembers: jobs, tasks, leases, where data lives. The data plane (`helix-rpc`, C++) moves the actual tensor bytes directly between workers. Bytes never go through the control plane. ([Part 1](#part-1--what-helix-is-in-plain-english))

10. **Why Linux in a VM instead of building on macOS directly?**
    Helix depends on Linux-only kernel features (io_uring, futex, memfd, huge pages, NUMA, eBPF, perf), and real AI infrastructure runs on Linux. ([3.1](#31-linux-kernels-virtual-machines-and-orbstack))

11. **What does `make check` run, and when must it be green?**
    lint + test + asan + tsan + ubsan + race. Before every commit, starting today.

12. **What is false sharing, and why does Helix pad to 128 bytes?**
    Two threads on different cores writing different variables in the same cache line keep stealing that line from each other. Apple Silicon's line is 128 bytes and x86 prefetches lines in pairs, so 128-byte padding avoids it on both. ([3.12](#312-hardware-facts-you-record-today))

**Interview version (30 seconds):** "Day 1 was the build and verification foundation: CMake + Ninja for C++20, a Go module, one Makefile entry point, and GitHub Actions running unit tests plus ASan, TSan and UBSan builds and the Go race detector on both x86 and arm64. Each sanitizer has its own build tree because they need whole-program instrumentation and ASan and TSan are mutually exclusive. I added a canary job with deliberate races that must be detected, so a misconfigured sanitizer can never pass silently."

---

## Part 9 · Day 1 "Done when" checklist

Tick each one only when you've seen it with your own eyes.

**Environment**

- [ ] `orb list` shows `helix` running **ubuntu noble arm64**
- [ ] OrbStack limits are 8 CPUs, 14 GB
- [ ] `scripts/bootstrap-dev.sh` finished; `go version` ≥ 1.23; `clang++ --version` is 18
- [ ] `sysctl vm.mmap_rnd_bits` prints 28, and `/etc/sysctl.d/60-helix-tsan.conf` exists
- [ ] Smoke-test values written in `notes/day-01.md`; page size noted (4 KB or 16 KB)

**Local builds (official Done-when #1)**

- [ ] `make build` ✅ and `build/core/helix_version` prints `helix 0.0.1`
- [ ] `make test` ✅ (4 C++ tests + Go)
- [ ] `make asan` ✅ · `make tsan` ✅ · `make ubsan` ✅
- [ ] `make race` ✅
- [ ] `make lint` ✅
- [ ] `make verify-sanitizers` prints two `OK` lines
- [ ] `make check` ✅
- [ ] `make env` output pasted into [docs/progress/day-01.md](../progress/day-01.md)

**GitHub (official Done-when #2 and #3)**

- [ ] Branch `day-01-repo-skeleton` pushed and a PR opened
- [ ] All 12 CI jobs green, including the arm64 ones
- [ ] `day-01-race-check` made `cpp (tsan)` red; run URL saved in the progress log; branch deleted locally and on GitHub
- [ ] PR merged; `main` protected

**Learning**

- [ ] Read Overview §1–3 and SPEC §1
- [ ] Wrote the five components in your own words, without looking
- [ ] Answered all 12 self-check questions out loud
- [ ] Ticked Day 1 in the tracker

When every box is ticked, Day 1 is done. Tomorrow (Day 2) adds the benchmark harness and checks the kernel features (io_uring, bpftrace). Before it, read [docs/concepts/hardware-and-caches.md](../concepts/hardware-and-caches.md).
