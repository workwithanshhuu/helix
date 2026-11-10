# Observability, tail latency and benchmarking

## 1. The idea

You cannot fix what you cannot see. **Metrics** (numbers over time), **traces** (one request's path across components) and **logs** (events) together explain behaviour. For latency, averages lie: users and fan-out systems feel the **tail** (p99, p99.9). And most published benchmarks are wrong because of how they measure.

## 2. Tail latency
- With fan-out *N*, a request is as slow as its slowest sub-request: P(all fast) = p^N. If 1% of calls are slow, a 100-way fan-out is slow 63% of the time (Dean & Barroso, "The Tail at Scale").
- Causes: GC pauses, page faults, lock convoys, queueing near saturation, interrupts, frequency scaling, background compaction, Nagle.
- Remedies: remove the source; hedged/backup requests; isolate cores; pre-fault memory; bound queues.

## 3. Coordinated omission (the benchmark bug)
A **closed-loop** load generator sends the next request only after the previous returns. When the server stalls for 1 s, the generator *also stops sending*, so only one request records the stall instead of the thousands that would have queued — p99 looks great. Fix: **open-loop** generator with a fixed arrival schedule; latency measured from the *intended* send time. HdrHistogram can also correct after the fact. Helix's load generator (day 41) is open-loop.

## 4. Queueing intuition
- Little's law: L = λW (items in system = arrival rate × time in system).
- For an M/M/1 queue, W = 1/(μ − λ): latency explodes as utilization → 100%. Always report latency **at a stated load**, and plot latency vs throughput curves, not single points.

## 5. Helix's observability (days 39–41)

| Piece | Design |
| --- | --- |
| Histograms | Per-thread HDR-style log-linear buckets; no shared atomics on hot paths; merged on scrape |
| Counters/gauges | Thread-local, aggregated lazily |
| Export | Prometheus text on 9100 (meta) / 9200 (worker) |
| Tracing | Trace id in gRPC metadata, lease, and the 32-B frame header; spans recorded in a per-thread **flight recorder** ring; dumped as Perfetto JSON |
| Kernel view | bpftrace scripts: run-queue latency, off-CPU time, syscall latency |
| Catalog | [SPEC §8](../../SPEC.md#8-metrics-and-tracing-catalog) |

USE method for resources (Utilization, Saturation, Errors); RED for services (Rate, Errors, Duration).

## 6. Benchmark rules (SPEC §10)
1. State hardware, kernel, compiler, flags, config, commit.
2. Warm up; run ≥ 5 repetitions; report median and spread.
3. Open-loop for latency; report p50/p99/p99.9/max at a stated throughput.
4. Compare against a properly tuned baseline (gRPC async, Ray) and say where the baseline wins.
5. Keep raw data under `bench/results/` and the script that made every plot.
6. Never publish VM-laptop numbers as performance claims.

## 7. Pitfalls
- Measuring with `std::chrono::system_clock` (can jump) → use `steady_clock` / `CLOCK_MONOTONIC`.
- Timer overhead larger than the thing measured → batch operations per sample.
- Dead-code elimination in microbenchmarks → `benchmark::DoNotOptimize`.
- CPU frequency scaling/turbo → fix governor, pin cores, report it.
- Averages of percentiles (wrong) → merge histograms, then compute.

## 8. Check yourself
1. *What is coordinated omission?* — The load generator backing off during server stalls, hiding latency.
2. *Why per-thread histograms?* — A shared atomic histogram becomes a contended cache line on the hot path.
3. *Why can't you average p99s across servers?* — Percentiles are not additive; merge the underlying histograms.
4. *What does Little's law say?* — L = λW.

## 9. Read more
- Dean & Barroso, "The Tail at Scale" (CACM 2013).
- Gil Tene, "How NOT to Measure Latency" (talk); HdrHistogram.
- Gregg, *Systems Performance* 2e (USE method, flame graphs, BPF).
- Sigelman et al., "Dapper" (2010) — tracing.

## Field notes
_(added by day logs)_
