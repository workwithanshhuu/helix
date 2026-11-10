# Helix documentation map

Everything about Helix, in reading order for a newcomer, then by purpose. **Sources of truth** (CLAUDE.md §2): [SPEC.md](../SPEC.md) for technical contracts, [plan/day-guide.md](plan/day-guide.md) for what to build when, [design/](design/) and [adr/](adr/) for why.

## Start here (60–90 minutes)
1. [README.md](../README.md) — what Helix is, quickstart, roadmap.
2. [ARCHITECTURE.md](../ARCHITECTURE.md) — processes, components, request lifecycle, failure handling.
3. [design/000-system-design.md](design/000-system-design.md) — goals, non-goals, key decisions and alternatives.
4. [SPEC.md](../SPEC.md) §1 — conventions; skim the rest.
5. [plan/45-day-plan.md](plan/45-day-plan.md) and [plan/tracker.md](plan/tracker.md) — the schedule and progress.
6. [CLAUDE.md](../CLAUDE.md) — how every coding session works.

## By purpose

| Folder | What's in it | Key files |
| --- | --- | --- |
| [plan/](plan/) | The 45-day plan, the step-by-step day guide, the tracker, the full proposal | [day-guide.md](plan/day-guide.md), [tracker.md](plan/tracker.md), [45-day-plan.md](plan/45-day-plan.md), [full-proposal.md](plan/full-proposal.md) |
| [progress/](progress/) | One log per day with evidence and "Explain it back" | [day-01.md](progress/day-01.md), [TEMPLATE.md](progress/TEMPLATE.md) |
| [design/](design/) | System design doc + one per milestone | [000](design/000-system-design.md), [m1](design/m1-core.md), [m2](design/m2-rpc.md), [m3](design/m3-control-plane.md), [m4](design/m4-execution.md), [m5](design/m5-observability.md) |
| [api/](api/) | C++ API, data-plane wire protocol, gRPC API, CLI | [core-api](api/core-api.md), [rpc-wire-protocol](api/rpc-wire-protocol.md), [meta-grpc-api](api/meta-grpc-api.md), [helixctl-cli](api/helixctl-cli.md) |
| [db/](db/) | Data model and storage formats | [metadata-schema](db/metadata-schema.md), [wal-format](db/wal-format.md), [snapshot-format](db/snapshot-format.md), [object-store-layout](db/object-store-layout.md) |
| [concepts/](concepts/) | Theory behind each component, tied to Helix code | [README](concepts/README.md) (reading order), [foundations-refresher](concepts/foundations-refresher.md) |
| [adr/](adr/) | Architecture decision records | [README](adr/README.md) |
| [runbooks/](runbooks/) | Procedures: dev environment, CI, git workflow | [dev-environment](runbooks/dev-environment.md), [ci](runbooks/ci.md), [git-workflow](runbooks/git-workflow.md) |
| [benchmarks/](benchmarks/) | Published, reproducible results (none yet) and the plan | [README](benchmarks/README.md) |
| [postmortems/](postmortems/) | Write-ups of bugs that took > 30 min | [TEMPLATE](postmortems/TEMPLATE.md) |
| [interview/](interview/) | Pitch, company talking points, stories, question bank, design prompts, traps | [README](interview/README.md) |
| [study-guide/](study-guide/) | Study plan, reading list, glossary | [study-plan](study-guide/study-plan.md), [glossary](study-guide/glossary.md) |
| [images/](images/) | Architecture, task lifecycle, timeline diagrams | — |

## Component READMEs
[core](../core/README.md) · [rpc](../rpc/README.md) · [store](../store/README.md) · [worker](../worker/README.md) · [meta](../meta/README.md) · [proto](../proto/README.md) · [bench](../bench/README.md) · [test/chaos](../test/chaos/README.md) · [deploy](../deploy/README.md) · [tools/bpf](../tools/bpf/README.md) · [scripts](../scripts/README.md)

## Status markers used across docs
✅ implemented and tested · 🛠 specified, not yet implemented (with the day it lands) · ⚠ known limitation.

## Keeping docs true
Docs change in the same commit as the code they describe (CLAUDE.md §6). If a doc and the code disagree, the code is wrong or the doc is stale — fix one of them in the same PR, never leave both.
