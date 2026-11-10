# store — helix-store object store (C++20), day 30

Per-node store for immutable tensor objects: `create` → write → `seal(token)` → `get` (refcounted) → LRU eviction when unreferenced. Backed by one `memfd` + `mmap(MAP_SHARED)` region with a 4 KiB-aligned extent allocator, so network receives and `send_zc` can work on the same memory.

API: [docs/api/core-api.md §store](../docs/api/core-api.md#helix-store--day-30) · Layout: [docs/db/object-store-layout.md](../docs/db/object-store-layout.md) · Design: [docs/design/m4-execution.md](../docs/design/m4-execution.md).
