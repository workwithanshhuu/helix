# The Helix pitch

Update the bracketed numbers as they are measured (CLAUDE.md §8: never quote an unmeasured number).

## 30 seconds
"I built Helix, a small distributed runtime for tensor-task DAGs — think a from-scratch Ray plus Plasma. The control plane is a Raft-replicated Go service I wrote, verified with Porcupine for linearizability. Workers are C++20: a lock-free work-stealing scheduler, a slab allocator, and an mmap object store; tensors move between workers over my own io_uring transport with zero copies. If you `kill -9` a worker mid-job, leases with fencing tokens and lineage recomputation finish the job with the right checksum. On [hardware], small-message p99 is [X] µs vs gRPC's [Y]."

## 2 minutes (structure)
1. **Problem**: running DAGs of tensor work across machines needs fast local execution, fast data movement and correct metadata under failures — three different kinds of systems problem.
2. **Design**: control plane (Go, Raft, scheduler, leases) vs data plane (C++, zero-copy); two-level scheduling; lineage instead of replication.
3. **Hardest part**: pick one — the Chase–Lev deque orderings on ARM, Raft's Figure-8 commit rule, or the paused-worker split brain fixed by fencing tokens.
4. **Evidence**: tests (TSan ×100 on arm64, deterministic Raft simulation, Porcupine, chaos with checksums) and benchmarks vs gRPC and Ray with raw data in the repo.
5. **Judgement**: where Ray/gRPC still win and why; what breaks at 10,000 nodes and how I'd shard it.

## 5-minute deep dives (pick per company)
- **Lock-free core** (NVIDIA): SPSC cached indices → Chase–Lev → the mutation test that proved the seq_cst fence matters → scaling graph.
- **Consensus** (Google): Raft + PreVote/CheckQuorum/ReadIndex → simulator with seeds → the bug Porcupine found → WAL group commit numbers.
- **Failure handling** (Anthropic/OpenAI): kill -9 timeline from the Perfetto trace: heartbeat miss → lease expiry → new token → stale completion rejected → lineage recompute.
- **Data path** (VMware/Nutanix): memfd store, registered buffers, `send_zc` notification lifetime, credit flow control, locality-aware placement.

## Questions to expect after the pitch
"Why not just use Ray?" — Learning and measurement: owning each layer lets me explain every number; Ray wins on ecosystem, autoscaling and Python ergonomics.
"Why Go for the control plane?" — Productivity, gRPC, goroutines for many slow connections; GC is fine off the data path.
"What would you do differently?" — Fill in from the day logs' "Deferred" sections and postmortems.
