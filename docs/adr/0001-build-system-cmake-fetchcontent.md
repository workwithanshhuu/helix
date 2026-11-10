# ADR-0001: C++ build with CMake + FetchContent, dependencies pinned by commit SHA

| Field | Value |
| --- | --- |
| Status | Accepted |
| Date | 2026-11-10 |
| Day | 1 |
| Related | `CMakeLists.txt`, `cmake/HelixDependencies.cmake`, [build-and-sanitizers](../concepts/build-and-sanitizers.md) |

## Context
Helix needs a C++20 build that works on x86-64 and arm64 Linux, supports one build per sanitizer, produces `compile_commands.json` for clang-tidy, is familiar to interviewers and contributors, and fits a 45-day schedule. A handful of C++ dependencies are needed (googletest now; Google Benchmark day 2; possibly a BLAS and liburing later). System packages (liburing, libnuma, gRPC for Go-side tooling, OpenBLAS) are available from Ubuntu apt.

## Options considered
### A. CMake + FetchContent (source deps), apt for system libs
- Pros: industry default; first-class IDE/clang-tidy support; simple to read; sanitizers via flags; no extra tooling.
- Cons: dependency fetch at configure time (network needed once); no hermeticity guarantees.
### B. Bazel (or Buck2)
- Pros: hermetic, fast incremental and remote caching, multi-language (Go too); Google-style.
- Cons: steep setup cost; toolchain/sanitizer configuration is involved; heavier for a solo 45-day project; less familiar to most reviewers.
### C. CMake + vcpkg / Conan
- Pros: binary caching, version manifests.
- Cons: another tool and manifest format; sanitizer builds of deps need custom triplets; overkill for 2–3 deps.
### D. Vendoring sources (git submodules or copied)
- Pros: fully offline.
- Cons: bloats the repo; submodules are easy to misuse.

## Decision
**Option A.** Each FetchContent dependency is pinned to an **exact git commit SHA** (release tag in a comment) with `GIT_SHALLOW FALSE`. Not tags (movable), not tarball URLs.

Why SHA over tarball + `URL_HASH`: during day 1 the GitHub archive download returned HTTP 403 behind the sandbox proxy while git reads worked; a SHA-pinned git fetch is both content-addressed and portable across such networks. Offline builds remain possible with `make build CMAKE_ARGS=-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=/path/to/googletest`.

## Consequences
- Positive: one widely understood build; `make` wraps it; CI and dev identical.
- Negative: first configure needs network and a full clone of each dependency (googletest is small).
- Rules: new dependency ⇒ ADR or amendment; always SHA-pin; system libraries come from apt in `scripts/bootstrap-dev.sh` and CI.

## How we would know it was wrong
Configure + build time dominated by dependencies (> 2 min clean), or a need for hermetic multi-language builds (e.g. generating C++ and Go from shared protos becomes painful) → reconsider Bazel.
