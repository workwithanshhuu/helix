# Design documents

Design docs explain **how and why** something is built; [SPEC.md](../../SPEC.md) records **what** the binding interfaces are; [ADRs](../adr/) record individual decisions.

Process: each milestone doc is drafted before the milestone starts (status Draft), kept current while building, and finalized with measured results on the milestone's last day (status Implemented). Template: [TEMPLATE.md](TEMPLATE.md).

| Doc | Scope | Status |
| --- | --- | --- |
| [000-system-design.md](000-system-design.md) | Whole system: goals, decisions, consistency, failure model, risks | Accepted |
| [m1-core.md](m1-core.md) | Allocator, rings, deque, pool, DAG, kernels (days 3–11) | Draft |
| [m2-rpc.md](m2-rpc.md) | io_uring data plane (days 12–18) | Draft |
| [m3-control-plane.md](m3-control-plane.md) | Raft, WAL, state machine, helix-meta (days 19–28) | Draft |
| [m4-execution.md](m4-execution.md) | Worker, store, scheduler, recovery (days 29–38) | Draft |
| [m5-observability.md](m5-observability.md) | Metrics, tracing, benchmarks, release (days 39–45) | Draft |
