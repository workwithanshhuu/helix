# Runbook: development environment (OrbStack Ubuntu 24.04 arm64)

Decision: [ADR-0004](../adr/0004-dev-environment-orbstack-arm64.md). Time: ~30–45 minutes the first time.

## 1. Requirements
| Item | Minimum | Why |
| --- | --- | --- |
| Host | Apple Silicon Mac (M-series), macOS 14+ | OrbStack arm64 VMs |
| Linux kernel in VM | ≥ 6.1 (6.6+ preferred) | io_uring features (`send_zc` ≥ 6.0, provided buffer rings ≥ 5.19) |
| Disk | ~15 GB free | toolchains + 4 build dirs |
| RAM for VM | OrbStack shares dynamically; 8 GB+ recommended | TSan builds |

## 2. Install OrbStack and create the machine (on macOS)
```bash
brew install orbstack            # or download from orbstack.dev
open -a OrbStack                 # finish the first-run setup
orb create ubuntu:noble helix    # Ubuntu 24.04 (arm64) machine named "helix"
orb -m helix uname -a            # sanity check: Linux ... aarch64
ssh helix@orb                    # or: orb -m helix   (opens a shell)
```
Resources: OrbStack → Settings → System: give Linux machines **8 CPU cores and 14 GB** memory limit (the day guide's values; leaves ~10 GB for macOS).

OrbStack mounts your macOS home at `/Users/<you>` inside the machine, so the repo at `/Users/anshu/raft-v2.0/CS-6210_AOS/helix` is visible from Linux at the same path. **Build inside Linux** (never on macOS): build directories are Linux binaries.

Performance tip: Linux-native filesystem is faster than the shared mount for builds with many small files. If builds feel slow, clone a second copy inside the VM (`~/src/helix`) and push/pull through GitHub, or keep the shared repo but put build dirs on Linux FS (not needed at day-1 sizes).

### Where to run Claude Code
Two workable setups; pick one and stay with it:
- **A (simplest, matches where the repo lives):** run Claude Code on macOS in `/Users/anshu/raft-v2.0/CS-6210_AOS/helix`, and have it run build/test commands inside Linux with `orb -m helix -w /Users/anshu/raft-v2.0/CS-6210_AOS/helix make check` (`-w` sets the working directory; confirm with `orb --help` on your version — `orb -m helix bash -lc "cd <repo> && make check"` works everywhere). Add that rule to your session prompt or `.claude/settings.local.json` allow-list.
- **B (fastest builds, per the day guide's pitfall note):** install Node + Claude Code inside the VM, clone the repo into `~/src/helix` on the Linux filesystem, and run everything there. macOS editors can still open it at `~/OrbStack/helix/home/<user>/src/helix`.

## 3. Bootstrap the toolchain (inside the machine)
```bash
cd /Users/anshu/raft-v2.0/CS-6210_AOS/helix
scripts/bootstrap-dev.sh
```
It installs (apt): clang/clang-format/clang-tidy/lld/llvm, `libclang-rt-18-dev` (sanitizer runtimes), cmake, ninja, git, liburing, libnuma, numactl, OpenBLAS, protobuf + gRPC, linux-tools, bpftrace, python3 + matplotlib, mimalloc; installs Go ≥ 1.23 if missing; sets `vm.mmap_rnd_bits=28` for TSan.

### Persist the TSan setting across reboots
```bash
echo 'vm.mmap_rnd_bits=28' | sudo tee /etc/sysctl.d/60-helix-tsan.conf
sudo sysctl --system
sysctl vm.mmap_rnd_bits          # expect 28
```

### Go on PATH
```bash
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc && source ~/.bashrc
go version                       # >= go1.23
```

## 4. Verify
```bash
make env                 # machine/toolchain report; paste into docs/progress/day-01.md
make check               # lint + test + asan + tsan + ubsan + race — must be green
make verify-sanitizers   # must print OK for C++ TSan and Go race detector
build/core/helix_version
```
Expected: every step exits 0; `make check` runs 4 C++ tests in each of 4 configurations and the Go tests twice.

## 5. Git and GitHub from the Mac or the VM
SSH keys live on macOS; pushing from macOS is simplest:
```bash
# on macOS, in the repo
git push -u origin day-01-repo-skeleton
```
To push from the VM, either forward the agent (`ssh -A helix@orb`) or create a key in the VM and add it to GitHub.

## 6. Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `FATAL: ThreadSanitizer: unexpected memory mapping` | ASLR entropy too high | §3 sysctl |
| `cannot find ... libclang_rt.asan` / `tsan` | Sanitizer runtimes missing | `sudo apt install libclang-rt-18-dev` |
| `clang-tidy: command not found` during `make lint` | Not installed | `sudo apt install clang-tidy` |
| FetchContent fails to download googletest | No network/proxy blocks GitHub | Retry with network; or clone googletest at the pinned SHA and `make build CMAKE_ARGS=-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=$PWD/../googletest` |
| `go: go.mod requires go >= 1.23` | Old Go from apt | Use `/usr/local/go` from bootstrap; check `which go` |
| Builds very slow on the shared folder | virtiofs overhead | Clone inside the VM (§2 tip) |
| `make check` passes locally, fails in CI | Different compiler/flags/arch | Read the failing job; reproduce with the same target (`make tsan`); see [ci.md](ci.md) |
| io_uring `EPERM` | `kernel.io_uring_disabled` set | `sysctl kernel.io_uring_disabled` → 0 (day 2 check) |
| `perf` shows no hardware events | VM has no PMU access | Expected; use the rented machine (day 42) |

## 7. Fallback: UTM with a stock Ubuntu kernel
Use if day 2's kernel smoke test finds missing io_uring/eBPF features.
1. Install UTM (`brew install --cask utm`); create an Ubuntu Server 24.04 arm64 VM via Apple Virtualization, 4+ vCPU, 8 GB, 40 GB disk.
2. Enable SSH; clone the repo inside the VM; run `scripts/bootstrap-dev.sh`.
3. Re-run day 2's smoke test.

## 8. Rebuild from scratch
```bash
orb delete helix && orb create ubuntu:noble helix   # destroys the VM (repo on macOS is untouched)
```
