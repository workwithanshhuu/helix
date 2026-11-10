# Contributing to Helix

Helix is built in public as a 45-day project. These rules keep `main` always green and every change explainable. AI-assisted sessions follow [CLAUDE.md](CLAUDE.md), which is a superset of this file.

## Development setup

Use the Ubuntu 24.04 Linux machine described in [docs/runbooks/dev-environment.md](docs/runbooks/dev-environment.md), then:

```bash
scripts/bootstrap-dev.sh
make check
```

## Workflow

1. Branch from `main`: `day-NN-<topic>`, `feat/<topic>` or `fix/<topic>`.
2. Make the change with tests (see "Definition of Done").
3. Run `make check` locally. It must pass.
4. Open a PR using the template; CI must be green before merge. Squash-merge with a Conventional Commit title.

## Definition of Done (every change)

- [ ] Unit tests for the new behaviour, including at least one failure case
- [ ] Concurrent code: stress test run 100× under TSan (`--gtest_repeat=100`) and on arm64
- [ ] `make check` green (lint + tests + ASan + TSan + UBSan + Go race)
- [ ] Benchmark run and recorded if a hot path changed ([SPEC.md §10](SPEC.md#10-benchmark-methodology))
- [ ] [SPEC.md](SPEC.md), [docs/api/](docs/api/), [docs/db/](docs/db/) updated if an interface, format or default changed
- [ ] ADR added for any decision with a real alternative ([docs/adr/](docs/adr/))
- [ ] No `TODO` without `TODO(day-NN)`

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`

| Type | Use for |
| --- | --- |
| `feat` | New behaviour |
| `fix` | Bug fix |
| `perf` | Performance change (include before/after numbers in the body) |
| `test` | Tests only |
| `bench` | Benchmarks and results |
| `docs` | Documentation only |
| `build` / `ci` | Build system / CI |
| `refactor` / `chore` | No behaviour change |

Scopes: `core`, `rpc`, `store`, `worker`, `meta`, `raft`, `wal`, `sched`, `bench`, `deploy`, `docs`, `ci`.

## Code style

C++: clang-format (Google, 100 columns), clang-tidy clean, warnings are errors. Go: gofmt, go vet. Full rules in [SPEC.md §1](SPEC.md#1-conventions) and [CLAUDE.md §5](CLAUDE.md#5-engineering-rules-non-negotiable).

## Reporting bugs

Open an issue with the "Bug report" template. Include the commit, `make env` output and the smallest reproduction.
