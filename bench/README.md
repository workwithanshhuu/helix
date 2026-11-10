# bench — load generation, baselines and results

| Path | Day | Content |
| --- | --- | --- |
| `loadgen/` | 17, 41 | Open-loop load generator (Poisson arrivals, latency from scheduled time, HdrHistogram) |
| `baselines/grpc/` | 17 | gRPC C++ async echo + streaming baseline |
| `baselines/ray/` | 43 | Equivalent Ray workloads |
| `results/<date>-<name>/` | all | Raw CSV/JSON per run + `env.md` (never edited by hand) |
| `plot/` | 2 | Scripts that turn raw results into charts |
| `env.sh` | 2 | Captures machine/toolchain facts |

Rules: [SPEC.md §10](../SPEC.md#10-benchmark-methodology). Reports: [docs/benchmarks/](../docs/benchmarks/).
