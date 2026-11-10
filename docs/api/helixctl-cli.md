# helixctl CLI reference

Status: 🛠 specified; commands arrive on the days shown. Global flags: `--meta host:port[,host:port...]` (default `localhost:7000`), `--timeout 5s`, `--output text|json`.

| Command | Day | Purpose | Example |
| --- | --- | --- | --- |
| `helixctl status` | 27 | Leader, term, commit index, node count | `helixctl status` |
| `helixctl leader` | 27 | Print the current leader address | `helixctl leader` |
| `helixctl nodes` | 27 | Nodes with state, cores, queue depth, free store | `helixctl nodes --output json` |
| `helixctl submit <dag.json>` | 27 | Submit a DAG; prints job id | `helixctl submit examples/fanout.json` |
| `helixctl job <id> [--wait]` | 27 | Job state and progress; `--wait` blocks until final | `helixctl job 1042 --wait` |
| `helixctl cancel <id>` | 29 | Cancel a job | |
| `helixctl matmul --n N --tile T [--verify]` | 32 | Generate and submit a tiled matmul DAG | `helixctl matmul --n 4096 --tile 1024 --verify` |
| `helixctl trace <job> -o out.json` | 40 | Collect flight-recorder spans as Perfetto JSON | open in ui.perfetto.dev |

Exit codes: 0 success, 1 usage error, 2 RPC/cluster error, 3 job failed or cancelled.

## DAG JSON format

```json
{
  "request_id": "optional-16-byte-hex-or-generated",
  "tasks": [
    { "kernel": "random", "params": {"rows": 1024, "cols": 1024, "seed": 1}, "inputs": [], "outputs": 1 },
    { "kernel": "random", "params": {"rows": 1024, "cols": 1024, "seed": 2}, "inputs": [], "outputs": 1 },
    { "kernel": "matmul_tile", "params": {}, "inputs": [{"task": 0, "output": 0}, {"task": 1, "output": 0}], "outputs": 1 },
    { "kernel": "checksum", "params": {}, "inputs": [{"task": 2, "output": 0}], "outputs": 1 }
  ]
}
```

Rules: inputs reference earlier task indices (the DAG must be acyclic) or an existing object `{"object": {"job": J, "task": T, "output": O}}`; `kernel` must exist in the worker's registry (`noop`, `random`, `add`, `matmul_tile`, `softmax`, `layernorm`, `gelu`, `attention`, `checksum`).
