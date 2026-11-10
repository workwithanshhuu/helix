# Changelog

All notable changes are recorded here. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions follow [Semantic Versioning](https://semver.org/) (pre-1.0: minor bumps per milestone).

## [Unreleased]

### Added (day 1, 2026-11-10)
- Repository skeleton: C++20 CMake build (`helix_core` library, `helix_version` tool), Go module `github.com/workwithanshhuu/helix` with package `meta`.
- `VERSION` file as the single source of truth, checked by both C++ and Go tests.
- Makefile with `build`, `test`, `asan`, `tsan`, `ubsan`, `race`, `lint`, `format`, `check`, `verify-sanitizers`, `env`.
- Sanitizer support via `HELIX_SANITIZER`, one build directory per configuration.
- GoogleTest pinned to commit `b514bdc` (v1.15.2) via FetchContent.
- GitHub Actions CI: lint, C++ (release/ASan/TSan/UBSan) on x86_64 and arm64, Go with race detector, sanitizer canary.
- `scripts/bootstrap-dev.sh`, `scripts/check-env.sh`, `scripts/verify-sanitizers-catch-races.sh`.
- clang-format, clang-tidy, golangci-lint, EditorConfig configuration.
- Documentation: README, ARCHITECTURE, SPEC, CLAUDE.md, system design doc, milestone design drafts, API and data-model docs, 14 concept guides plus the foundations refresher, ADRs 0001–0005, runbooks (dev environment, CI, git workflow), benchmark plan, postmortem and progress templates, the day-1 progress log, interview prep (pitch, company talking points, stories, traps, question bank, design prompts), study guide (study plan, reading list, glossary), 45-day plan, day guide and tracker.
- Claude Code slash commands in `.claude/commands/` (`/start-day`, `/finish-day`, `/check`, `/explain`, `/adr`, `/postmortem`).

### Changed
- CI and `bootstrap-dev.sh` install `libclang-rt-18-dev` explicitly so sanitizer runtimes are always present.
- `.gitignore` replaced: the GitHub C++ template ignored `Makefile` and `*.mod`, which would have excluded the root Makefile and `go.mod`.

[Unreleased]: https://github.com/workwithanshhuu/helix/commits/main
