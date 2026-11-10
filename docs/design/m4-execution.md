# Design doc M4: execution, object store, scheduling, recovery

| Field | Value |
| --- | --- |
| Status | **Draft** (finalize on day 38) |
| Days | 29–38 · release v0.4 |
| Related | SPEC §2 (worker, store), §5.2–5.6, §6; [object-store-layout.md](../db/object-store-layout.md); concepts: [scheduling](../concepts/scheduling-and-placement.md), [leases](../concepts/leases-and-fencing.md) |

## 1. Summary
`helixd` joins the C++ runtime to the Go control plane: it takes leases, fetches inputs zero-copy into an mmap object store, executes on the work-stealing pool, and reports completions guarded by fencing tokens. The leader places tasks by locality and load, balances with spillback, and recovers from worker loss by lease expiry plus lineage re-execution.

## 2. Goals
| Goal | Measure | Target |
| --- | --- | --- |
| Distributed correctness | tiled matmul across 3 workers vs single node | identical (allclose) |
| Locality | bytes fetched, locality on vs off | measurably fewer |
| Balance under skew | max/mean queue depth | < 1.3 within 2 s |
| Recovery | kill -9 / SIGSTOP mid-job | 20/20 correct; stale completions rejected |
| Chaos | 20 × 10-minute runs | no wrong results, nothing stuck > 60 s |

## 3. Design
- **Worker modules**: MetaClient (gRPC, NOT_LEADER handling), LeaseManager (renew every ttl/3, self-cancel after ttl without leader), Executor (kernel registry), ObjectStore, DataServer, Fetcher (dedup in-flight fetches), Metrics.
- **Object store**: memfd + mmap region, 4 KiB-aligned best-fit extents with coalescing, table `ObjectId → {offset,size,state,refcount,last_used}`, LRU eviction of unreferenced sealed objects, seal rejects lower tokens.
- **Scheduler**: tick 5 ms; score = 4·locality + 2·(1 − queue/capacity) + 1·(free_store/capacity) over best-locality + 2 random nodes; batch `GrantLease`.
- **Spillback**: worker refuses with RESOURCE_EXHAUSTED above threshold; leader re-places without counting an attempt, excluding the node for 1 s.
- **Recovery**: DEAD node → expire leases, remove locations; LOST objects → producer back to READY recursively; client-provided inputs that are lost fail the job.

## 4. Results
_To be filled on day 38._
