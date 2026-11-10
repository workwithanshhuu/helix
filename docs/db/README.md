# Data model and storage formats ("DB docs")

Helix has no external database. Its durable state lives in three places, all designed in-house:

| Store | Where | Durable? | Doc |
| --- | --- | --- | --- |
| Metadata state machine (nodes, jobs, tasks, leases, objects, dedup) | helix-meta memory, rebuilt from WAL + snapshots | Yes (Raft + fsync) | [metadata-schema.md](metadata-schema.md) |
| Raft write-ahead log | `<data_dir>/wal/*.seg` on each meta replica | Yes | [wal-format.md](wal-format.md) |
| Snapshots | `<data_dir>/snap/*.snap` | Yes | [snapshot-format.md](snapshot-format.md) |
| Object store (tensors) | helixd memory (`memfd` + `mmap`) | **No** — a cache; lost objects are recomputed via lineage | [object-store-layout.md](object-store-layout.md) |

Authoritative summary: [SPEC.md §4](../../SPEC.md#4-data-model-and-state-machines). Status: 🛠 specified; implemented days 23–25 (meta) and 30 (store).
