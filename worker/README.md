# worker — helixd (C++20), days 29–37

The per-machine daemon: registers with helix-meta, receives leases over a gRPC stream, fetches inputs from peers, runs tasks on the core work-stealing pool, stores outputs, and serves fetches to other workers.

Modules: `MetaClient`, `LeaseManager`, `Executor` (kernel registry), `DataServer`, `Fetcher`, `BatchingQueue` (day 37), `Metrics`.

Protocols it implements: [SPEC.md §5.2–5.6](../SPEC.md#5-protocols) · Design: [docs/design/m4-execution.md](../docs/design/m4-execution.md).
