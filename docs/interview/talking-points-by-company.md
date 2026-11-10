# Talking points by company

Each company probes a different layer of Helix, so prepare one 5-minute deep dive per company and lead with the matching component.

### NVIDIA — GPU, driver and low-level systems

- **What they probe:** memory hierarchy, DMA, pinned memory, latency hiding, lock-free host-side runtimes (the CUDA driver and NCCL are full of SPSC rings and doorbells).
- **Your evidence:** the slab allocator with NUMA binding and huge pages; registered io\_uring buffers that are also `cudaHostRegister`'d so a network receive lands in DMA-able memory (the same idea as GPUDirect RDMA); the SGEMM roofline plot; a tiled CUDA SGEMM benchmarked against cuBLAS, with a CUDA-streams executor backend as the next step.
- **Talking point:** "I measured that pinning cut H2D transfer time by X% and that overlapping three streams hid Y% of copy latency" — a concrete number from your own `nsys` trace.
- **Stretch that impresses most:** an NCCL-style ring all-reduce over Helix RPC between workers, benchmarked against NCCL/Gloo on CPU.

### Anthropic / OpenAI — large-scale distributed AI infrastructure

- **What they probe:** cluster scheduling for accelerator fleets, failure handling at scale (a node dies every few hours in a large cluster), inference serving efficiency, and debugging distributed systems you didn't write.
- **Your evidence:** lineage-based recovery with fencing tokens; a request-batching queue (continuous batching, a paged KV cache and pipeline-parallel inference are the stretch); tail-latency charts with coordinated omission corrected; a Ray comparison with an honest explanation of where Ray wins.
- **Talking point:** the kill -9 demo and the timeline of what happened in the 2 seconds after — lease expiry, token bump, lineage walk, recompute — shown in your Perfetto trace.
- **Signal they look for:** you wrote ADRs explaining trade-offs (e.g. why lineage over checkpointing), and you can say what breaks at 10,000 nodes (the global scheduler, the object directory) and how you would shard it.

### Google — Borg, gRPC, distributed storage

- **What they probe:** consensus correctness, storage engine internals, RPC design, and rigorous testing.
- **Your evidence:** Raft with PreVote, snapshots and fencing tokens, verified with Porcupine (ReadIndex, membership changes and an LSM-tree are the stretch); Helix RPC with deadlines, cancellation and flow control, benchmarked against gRPC; Borg-style placement scoring.
- **Talking point:** a bug Porcupine caught that unit tests missed, and the fix; why your RPC beats gRPC on small messages (no HTTP/2 framing, no protobuf parse, registered buffers) and where gRPC is still the right choice.

### VMware / Nutanix — virtualization and hyper-converged storage

- **What they probe:** shared-memory data paths between isolated components, storage I/O paths, data locality, and metadata services (Nutanix's Medusa/Cassandra-based metadata and Stargate I/O path).
- **Your evidence:** the SPSC rings, and the stretch memfd shared-memory transport (the same pattern as virtio rings between guest and host); the mmap object store, with a stretch path that spills to NVMe via `O_DIRECT` + io\_uring; locality-aware placement that moves compute to data, which is the core idea of hyper-converged infrastructure; a Raft-replicated metadata tier.
- **Talking point:** how you would turn the shm transport into a vhost-user-style interface for a VM, and how the store would replicate extents across nodes (RF=2/3) for durability.

## Mapping table: company → Helix component → evidence file

| Company | Lead with | Evidence to show | Concept doc |
| --- | --- | --- | --- |
| NVIDIA | Slab allocator, SPSC ring, registered buffers, SGEMM roofline | `core/`, `rpc/`, `bench/results/*sgemm*`, flame graph | [hardware](../concepts/hardware-and-caches.md), [allocators](../concepts/virtual-memory-and-allocators.md) |
| Anthropic / OpenAI | Fault tolerance (leases, fencing, lineage), tail latency, Ray comparison | Perfetto trace of the kill -9 run, chaos results, ADRs | [leases](../concepts/leases-and-fencing.md), [tail latency](../concepts/observability-and-tail-latency.md) |
| Google | Raft + Porcupine, RPC vs gRPC, placement | `meta/raft`, Porcupine HTML of a caught bug, RPC benchmarks | [raft](../concepts/raft-consensus.md), [linearizability](../concepts/linearizability-and-testing.md) |
| VMware / Nutanix | Shared-memory rings, object store, locality, Raft metadata tier | `store/`, SPSC ring, locality benchmark | [io_uring](../concepts/io-uring-and-zero-copy.md), [scheduling](../concepts/scheduling-and-placement.md) |

> Items marked "stretch" above (CUDA executor, NCCL-style all-reduce, continuous batching, LSM, membership changes, shm transport) are post-day-45 goals. In an interview, present them as "designed, next step", never as done.
