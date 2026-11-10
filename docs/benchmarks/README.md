# Benchmarks

**No results yet.** Numbers appear here only after they are measured in this repository, following [SPEC.md §10](../../SPEC.md#10-benchmark-methodology). Raw data lives in `bench/results/<YYYY-MM-DD>-<name>/`; this page summarises and links.

## Planned benchmarks

| Day | Benchmark | Compared against | Metric | Machine |
| --- | --- | --- | --- | --- |
| 3 | SPSC ring push/pop | `std::mutex` + `std::queue`, folly/rigtorp SPSC | ops/s, ns/op | dev VM (relative only) |
| 4–5 | Slab allocator | glibc `malloc`, mimalloc | ns/op, 64 B–256 KiB, 1/8 threads, cross-thread frees | dev VM |
| 6 | Chase–Lev deque | mutex deque | push/pop/steal ns/op, steal contention | dev VM |
| 7 | Work-stealing pool | `std::async`, mutex-queue pool | fib(30) time, 10 M empty tasks/s, speed-up 1→N | dev VM |
| 9–10 | SGEMM + tiled matmul DAG | OpenBLAS | GFLOP/s, roofline | dev VM → rented x86 (day 42) |
| 36 | CUDA SGEMM | cuBLAS | GFLOP/s on T4 | Kaggle (free) |
| 17 | helix-rpc ping-pong + throughput | gRPC C++ async, epoll transport | p50/p99/p99.9 at fixed load; GB/s at 4 KiB–64 MiB | dev VM loopback → cloud (42) |
| 23 | WAL append | fsync per entry vs group commit | entries/s, p99 commit | dev VM + cloud disk |
| 26 | Raft | — | commits/s, failover time | dev VM, docker |
| 33 | Placement under skew | random placement | max/mean queue depth over time | docker |
| 42–43 | End-to-end DAGs | Ray (same DAGs) | job latency, throughput, recovery time | rented cloud machines |

## Result entry template

```markdown
## <name> · <date> · commit <sha>
- Machine: <instance type / CPU / cores / RAM / kernel>
- Build: <compiler, flags, build type>
- Config: <non-default settings>
- Command: `make bench ...`
- Results: <table: median and spread over ≥ 5 runs>
- Plot: ![..](../../bench/results/<dir>/plot.png)
- Raw data: [bench/results/<dir>/](../../bench/results/<dir>/)
- Interpretation: <what explains the numbers; where the baseline wins>
```
