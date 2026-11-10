# API documentation

| Doc | Audience | Covers | Status |
| --- | --- | --- | --- |
| [core-api.md](core-api.md) | C++ code inside the worker | libhelix-core, helix-store and helix-rpc C++ interfaces: signatures, semantics, thread safety, errors, complexity | Day-1 API implemented; rest specified |
| [rpc-wire-protocol.md](rpc-wire-protocol.md) | Anyone implementing or debugging the data plane | Byte-level frame format, message types, flows, examples | Specified (days 12–17) |
| [meta-grpc-api.md](meta-grpc-api.md) | Workers, clients, helixctl | gRPC services of helix-meta, messages, errors, retry rules | Specified (days 25–29) |
| [helixctl-cli.md](helixctl-cli.md) | Operators and benchmarks | CLI commands, flags, DAG JSON format | Specified (days 27–40) |

## Stability policy

Pre-1.0, any API may change, but **only together with SPEC.md and these docs in the same commit**. Each entry is marked:

- ✅ **Implemented** — exists in the code, covered by tests.
- 🛠 **Specified** — agreed design; the day that implements it is named.

Rule for changes: if code and these docs disagree, it is a bug in one of them; fix it the same day (CLAUDE.md §6).
