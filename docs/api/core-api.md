# C++ API reference (core, store, rpc)

Conventions for every API below:

- Namespace `helix`. Headers under `<component>/include/helix/<area>/`.
- Errors: functions that can fail return `helix::Status` or `helix::Result<T>` (day 3). Programming errors (broken invariants) abort via `HELIX_CHECK`. No exceptions on hot paths.
- Thread safety is stated per type: **thread-safe** (any thread, concurrently), **owner-only** (only the owning thread), or **SPSC** (exactly one producer thread and one consumer thread).
- Ownership: values returned by value are owned by the caller; views (`std::string_view`, `std::span`) never own.

---

## helix/base/version.h ✅ (day 1)

```cpp
namespace helix {
struct BuildInfo {
  std::string_view version;     // e.g. "0.0.1" (VERSION file)
  std::string_view compiler;    // e.g. "Clang-18.1.3"
  std::string_view build_type;  // CMake build type, e.g. "RelWithDebInfo"
  std::string_view sanitizer;   // "none" | "address" | "thread" | "undefined"
};
[[nodiscard]] std::string_view version() noexcept;
[[nodiscard]] BuildInfo build_info() noexcept;
}
```

| Function | Returns | Thread safety | Cost |
| --- | --- | --- | --- |
| `version()` | Semantic version string literal | thread-safe | O(1), no allocation |
| `build_info()` | Struct of views to static literals | thread-safe | O(1), no allocation |

Values are injected at compile time by `core/CMakeLists.txt` (`HELIX_VERSION_STRING`, `HELIX_COMPILER_STRING`, `HELIX_BUILD_TYPE_STRING`, `HELIX_SANITIZER_STRING`). Tests: `core/test/version_test.cc` (format, matches VERSION, consistency, concurrent reads under TSan). Tool: `build/core/helix_version`.

---

## helix/base/{config,check,status}.h 🛠 (day 3)

```cpp
inline constexpr std::size_t kCacheLine = 128;   // covers x86 adjacent-line prefetch and Apple's 128 B lines

#define HELIX_CHECK(cond) /* aborts with file:line and the condition text if false */

enum class StatusCode : uint16_t { kOk, kCancelled, kDeadlineExceeded, kNotFound, kStaleToken,
                                   kResourceExhausted, kUnsupported, kInvalid, kInternal };
class Status { public: static Status Ok(); bool ok() const; StatusCode code() const; std::string_view message() const; };
template <class T> class Result { public: bool ok() const; const Status& status() const; T& value(); T* operator->(); };
```

Status codes mirror the wire status codes in [SPEC.md §3](../../SPEC.md#status-codes).

---

## helix/sync/spsc_ring.h 🛠 (day 3)

```cpp
template <class T, std::size_t N>   // N must be a power of two
class SpscRing {
 public:
  bool try_push(T&& v);             // false if full
  std::optional<T> try_pop();       // nullopt if empty
  std::size_t capacity() const noexcept { return N; }
};
```

- **Thread safety:** SPSC — exactly one producer thread calls `try_push`, exactly one consumer thread calls `try_pop`.
- **Progress:** wait-free; each call does a bounded number of steps.
- **Memory ordering:** producer stores the slot, then `tail_.store(release)`; consumer `tail_.load(acquire)` then reads the slot. Mirror image for `head_`.
- **Layout:** `head_`, `tail_` and each side's cached copy of the other index live on separate 128-byte lines.

---

## helix/mem/* 🛠 (days 4–5)

```cpp
class PageSource {
 public:
  static Result<PageSource> create(std::size_t reserve_bytes, int numa_node /* -1 = any */, bool huge);
  Result<std::span<std::byte>> commit(std::size_t bytes);   // 2 MiB granularity
  void release(std::span<std::byte> region);
};

class SlabAllocator {   // size classes 64 B .. 256 KiB; larger requests go to PageSource
 public:
  void* allocate(std::size_t bytes, std::size_t align = 64);
  void deallocate(void* p, std::size_t bytes);
  SlabStats stats() const;   // per-class allocations, frees, bytes in use, depot transfers
};

class Arena { public: void* allocate(std::size_t bytes, std::size_t align); void reset(); };
```

| Type | Thread safety | Notes |
| --- | --- | --- |
| `PageSource` | thread-safe | Reserve once (`PROT_NONE`, `MAP_NORESERVE`), commit lazily; NUMA binding via `mbind` when available |
| `SlabAllocator` | thread-safe | Per-thread caches (day 5) make the common path lock-free; `deallocate` must receive the same size as `allocate` |
| `Arena` | owner-only | Bump allocation; `reset()` frees everything at once |

Build option `HELIX_MALLOC_PASSTHROUGH=ON` forwards to `malloc` so ASan sees heap errors.

---

## helix/sync/ws_deque.h 🛠 (day 6)

```cpp
template <class T> class WsDeque {        // T is a pointer type; fixed capacity (power of two)
 public:
  bool push(T item);                      // owner-only; false if full (caller runs the task inline)
  std::optional<T> pop();                 // owner-only; LIFO from the bottom
  StealResult<T> steal();                 // any thread; FIFO from the top: {kSuccess, kEmpty, kAbort}
};
```

`kAbort` means a CAS race was lost; the thief should try another victim. Orderings follow Lê et al. (PPoPP 2013) — see [lock-free structures](../concepts/lock-free-structures.md).

---

## helix/sched/* 🛠 (days 7–8)

```cpp
struct PoolConfig { int threads = 0 /* 0 = physical cores */; bool pin = true; bool numa_aware = true;
                    std::chrono::microseconds spin_before_park{20}; };
class ThreadPool {
 public:
  explicit ThreadPool(PoolConfig cfg);
  ~ThreadPool();                 // drains or cancels outstanding tasks, joins threads
  void spawn(Task t);            // from a worker: local deque; otherwise the injection queue
  void wait_idle();              // returns when no task is queued or running
  PoolStats stats() const;       // tasks, steals (local/remote NUMA), parks, idle time
};

class TaskGraph {
 public:
  NodeId add(TaskFn fn, std::span<const NodeId> deps);
  Status run(ThreadPool& pool);  // first error wins; remaining nodes are skipped
};
```

Thread safety: `ThreadPool` methods are thread-safe; a `TaskGraph` is built by one thread, then `run` is called once.

---

## helix/tensor/tensor.h and helix/kernels/* 🛠 (days 8–10)

```cpp
enum class DType : uint8_t { kF32, kF16, kI32 };
struct Shape { std::array<int64_t, 4> dims; int rank; };
struct Tensor { DType dtype; Shape shape; std::byte* data; std::size_t bytes; };  // 64 B aligned, row-major

Status sgemm(const Tensor& a, const Tensor& b, Tensor& c, Backend backend = Backend::kBlas);
// Backend: kNaive | kBlocked | kNeon | kAvx2 (day 42) | kBlas
Status tiled_matmul(const Tensor& a, const Tensor& b, Tensor& c, int64_t tile, ThreadPool& pool);
```

---

## helix-store 🛠 (day 30)

```cpp
class ObjectStore {
 public:
  static Result<ObjectStore> open(StoreConfig cfg);          // memfd + mmap(MAP_SHARED), capacity
  Result<WritableObject> create(ObjectId id, std::size_t bytes);  // state CREATING
  Status seal(ObjectId id, FencingToken token);              // CREATING -> SEALED; kStaleToken if lower
  Result<ObjectRef> get(ObjectId id);                        // refcount++; RAII release
  Status abort(ObjectId id);                                 // drop a CREATING object
  StoreStats stats() const;
};
```

Thread-safe. Sealed objects are immutable. Only unreferenced sealed objects are evicted (LRU). Layout: [object-store-layout.md](../db/object-store-layout.md).

---

## helix-rpc 🛠 (days 12–16)

```cpp
class Transport {                              // UringTransport, EpollTransport
 public:
  virtual Result<ConnId> connect(const Endpoint&) = 0;
  virtual Status listen(const Endpoint&, AcceptFn) = 0;
  virtual Status send(ConnId, Frame&&) = 0;     // takes ownership of the payload buffer
  virtual void run() = 0;                       // event loop; one per I/O thread
};
class Client {
 public:
  Future<Response> call(ConnId, MsgType, std::span<const std::byte> meta, Deadline);
  Future<ObjectView> fetch(ConnId, ObjectId, StoreSink&);   // payload lands in a store extent
};
class Server { public: void handle(MsgType, Handler); };
```

Callbacks run on the I/O thread and must not block. Calls from other threads are queued to the owning I/O thread. Wire format: [rpc-wire-protocol.md](rpc-wire-protocol.md).
