# proto — gRPC / protobuf definitions (days 25–27)

| File | Services / messages | Used by |
| --- | --- | --- |
| `meta.proto` | `Cluster`, `Jobs`, `Tasks`, `Objects`; Raft state-machine commands | helix-meta, helixd, helixctl |
| `raft.proto` | `RequestVote`, `PreVote`, `AppendEntries`, `InstallSnapshot` | helix-meta replicas |

Generated code is produced by the build, never committed. Reference: [docs/api/meta-grpc-api.md](../docs/api/meta-grpc-api.md).
