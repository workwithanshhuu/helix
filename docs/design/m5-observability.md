# Design doc M5: observability, benchmarks, release

| Field | Value |
| --- | --- |
| Status | **Draft** (finalize on day 45) |
| Days | 39–45 · release v0.5 |
| Related | SPEC §8, §10; [observability concept](../concepts/observability-and-tail-latency.md); [docs/benchmarks/](../benchmarks/) |

## 1. Summary
Make Helix explainable: per-thread HDR histograms and counters exported to Prometheus, trace context through every hop, a per-thread flight recorder dumped as Perfetto JSON, an open-loop job load generator, eBPF scripts, and reproducible cloud benchmarks against gRPC and Ray.

## 2. Goals
| Goal | Target |
| --- | --- |
| Metrics overhead | < 3% on B3 |
| Trace of a recovery | one Perfetto timeline showing kill → expiry → re-lease → completion |
| Benchmarks | B3, B5, B6, B7, B10, B11 on rented x86 with raw data and env |
| Release | v0.5 tag, README with 3 charts, demo video, blog post |

## 3. Design
Telemetry registry with per-thread shards merged every second by a collector thread; text exposition on 9200/9100; spans per SPEC §8; flight-recorder events `{ts_ns,type,arg0,arg1}`; dump via flag set in signal handler and a dumper thread; `bench/run_all.sh` with Terraform-managed machines destroyed after each session.

## 4. Results
_To be filled on day 45._
