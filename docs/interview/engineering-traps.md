# Engineering traps you will hit

Four traps, each with the symptom you'll see, the root cause, how to prove it, and the fix. Write each one up as a blog post or `docs/postmortems/` entry when you hit it; they are your best interview stories.

### Trap 1 — False sharing and cache-line bounce in the scheduler (M1)

- **Symptom:** throughput scales to \~8 threads, then flattens or *drops* at 16–32 threads; `perf stat` shows high cycles but low IPC (< 0.5).
- **Root cause:** the deque's `top` (written by thieves) and `bottom` (written by the owner) share a 64-byte line, or per-thread counters sit in one array; Intel's adjacent-line prefetcher makes even neighbouring 64 B lines contend, so 128 B padding is often needed. Every steal attempt also does a CAS on `top`, bouncing that line across sockets.
- **Prove it:** `perf c2c record` / `perf c2c report` shows HITM (hit-modified) loads on the exact offsets (run this on the rented x86 box: the Mac VM cannot see hardware counters); compare same-socket vs cross-socket runs with `numactl --cpunodebind`.
- **Fix:** pad hot fields to 128 B; keep counters thread-local and aggregate lazily; check `top` with a plain load before attempting CAS; steal NUMA-local first; batch-steal half the deque instead of one task.

### Trap 2 — Tail-latency spikes in the RPC path (M2, M5)

- **Symptom:** p50 is 15 µs but p99.9 is 2–5 ms, in periodic bursts.
- **Likely causes, in the order to check:** (1) coordinated omission in a closed-loop load generator hiding or creating spikes; (2) Nagle + delayed ACK interaction (40 ms stalls) if `TCP_NODELAY` is missing; (3) page faults on first touch of freshly mmap'd buffers or transparent-huge-page compaction (`khugepaged`); (4) the Go control plane's GC pauses or the Go scheduler preempting a hot goroutine; (5) IRQs and softirqs landing on your I/O cores; (6) CPU frequency scaling and C-state exits.
- **Prove it:** open-loop load with HdrHistogram; `bpftrace` on `runqlat` and `offcputime` for the Helix PIDs; `perf trace -F all` for page faults; `GODEBUG=gctrace=1`; `/proc/interrupts` per core.
- **Fix:** pre-fault and `mlock` buffers at startup; set THP to `madvise`; isolate I/O cores (`isolcpus`/`nohz_full` or cgroup cpusets) and steer IRQs away; in Go, reduce allocation on the hot path (`sync.Pool`, preallocated buffers) and tune `GOGC`/`GOMEMLIMIT`; add hedged requests for idempotent reads.

### Trap 3 — Split brain and stale leaders (M3, M4)

- **Symptom:** under a network partition, two workers both believe they own a task and both write its output; or a deposed Raft leader serves a stale read.
- **Root cause:** a partitioned old leader still thinks it is leader until it hears a higher term; lease-based reads rely on bounded clock drift; a paused worker (GC, VM stall, `SIGSTOP`) resumes after its lease expired and keeps writing.
- **Prove it:** a fault-injection harness: `iptables`/`tc netem` partitions, `SIGSTOP`/`SIGCONT` to simulate pauses, `libfaketime` for clock skew; record every client operation and run Porcupine to find a non-linearizable history.
- **Fix:** PreVote + CheckQuorum so a partitioned leader steps down; ReadIndex (confirm leadership with a heartbeat round) when you can't trust clocks; fencing tokens checked by the object store on every `seal`; tasks idempotent by (task id, attempt), and the first sealed attempt wins.

### Trap 4 — ABA and use-after-free in lock-free structures (M1)

- **Symptom:** rare crashes or corrupted tasks after hours of stress, never under a debugger; ASan is silent because memory is recycled by your own slab.
- **Root cause:** a thread reads a node pointer, is preempted, the node is freed and reallocated at the same address, and the CAS succeeds on a different object (ABA); or a missing `acquire` lets a thief read a task slot before its contents are visible.
- **Prove it:** TSan with your allocator compiled in a mode that forwards to `malloc` (so ASan/TSan see real frees); a model checker (Relacy, CDSChecker or GenMC) on the deque with 2–3 threads; run stress tests on ARM (your Mac's Linux machine), whose weaker memory model exposes ordering bugs x86 hides.
- **Fix:** tagged pointers / version counters for ABA; epoch-based reclamation so nodes are freed only after every thread has passed a quiescent point; document every `memory_order` with a comment saying which store it pairs with.

### Bonus traps to expect

- **Raft log fsync cost:** each commit waits \~0.5–5 ms on `fdatasync`; fix with group commit and pipelining, and measure on the actual disk (cloud volumes vary widely).
- **LSM write stalls:** L0 file count exceeds the threshold and writes stall; fix with rate-limited compaction and monitoring of write amplification.
- **Pipeline bubbles:** in pipeline-parallel inference, stages idle while waiting; fix with micro-batching and measure bubble fraction in the trace.
