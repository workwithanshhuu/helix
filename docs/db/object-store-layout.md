# Object store layout (helix-store, day 30)

The object store is a **cache of immutable tensors** on each worker. It is not durable: anything lost is recomputed from lineage.

## 1. Memory region

- One region per worker: `memfd_create("helix-store")` → `ftruncate(store.capacity_bytes)` → `mmap(PROT_READ|PROT_WRITE, MAP_SHARED)`.
- Why `memfd` + `MAP_SHARED`: another process (stretch: shared-memory transport) can map the same bytes; io_uring registered buffers and `send_zc` work directly on extents.
- Pre-faulted at startup (`MAP_POPULATE` or touching each page) so first-use page faults never hit the data path.

## 2. Extent allocator

- Granularity and alignment: `store.alignment_bytes` (4 KiB, page aligned — required for zero-copy send and DMA).
- Free space: an ordered map `offset → length` plus a size-ordered index for **best fit**; adjacent free extents are coalesced on free.
- Fragmentation is reported in `stats()`; compaction is a stretch goal.

## 3. Object table

| Field | Type | Meaning |
| --- | --- | --- |
| id | ObjectID (16 B) | producer identity |
| offset, size | u64 | location in the region |
| state | CREATING / SEALED | CREATING is writable by its creator only |
| token | u64 | fencing token it was sealed with |
| refcount | atomic u32 | readers (tasks, in-flight sends) |
| last_used | u64 (monotonic ns) | for LRU |

Protected by one mutex (operations are per task, not per byte, so contention is low); refcounts are atomics so readers release without the lock.

## 4. Lifecycle

```
create(id, n) ──► CREATING ──write──► seal(id, token) ──► SEALED ──get()──► refcount++ … release ──► refcount--
       │                                 │ token < existing → kStaleToken
       └── abort(id) frees the extent    └── evictable when refcount == 0 (LRU)
```

## 5. Eviction

When `create` cannot find space: evict SEALED objects with `refcount == 0`, least recently used first, until a large-enough extent exists; otherwise return `RESOURCE_EXHAUSTED` (the worker then refuses leases — spillback). Each eviction is reported to meta (`RemoveObjectLocation`) in the next batch.

## 6. Invariants

1. Extents never overlap; free + used = capacity.
2. A SEALED object's bytes never change.
3. An object with `refcount > 0` is never evicted.
4. The fetch server holds a reference for the whole duration of a send (including until the `send_zc` notification).
