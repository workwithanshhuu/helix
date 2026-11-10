#!/usr/bin/env bash
# bootstrap-dev.sh — installs everything Helix needs inside the Ubuntu 24.04
# development machine (OrbStack on macOS, or any Ubuntu 24.04 VM/cloud box).
#
# Safe to re-run: apt skips installed packages and the Go step checks the
# installed version first. Run it INSIDE the Linux machine, not on macOS:
#
#   orb -m helix            # open a shell in the OrbStack machine
#   cd ~/src/helix && scripts/bootstrap-dev.sh
#
# See docs/runbooks/dev-environment.md for the full walkthrough.

set -euo pipefail

GO_MIN="1.23"
GO_INSTALL_VERSION="${GO_INSTALL_VERSION:-1.23.4}"

if [ "$(uname -s)" != Linux ]; then
  echo "error: run this inside the Linux machine (OrbStack/UTM/cloud), not on macOS" >&2
  exit 1
fi

echo "==> apt packages"
sudo apt-get update -y
sudo apt-get install -y --no-install-recommends \
  build-essential clang clang-format clang-tidy lld llvm libclang-rt-18-dev \
  cmake ninja-build git curl ca-certificates pkg-config \
  liburing-dev libnuma-dev numactl libopenblas-dev \
  protobuf-compiler libprotobuf-dev libgrpc++-dev protobuf-compiler-grpc \
  linux-tools-common linux-tools-generic bpftrace \
  python3 python3-pip python3-matplotlib \
  libmimalloc-dev

echo "==> Go (need >= ${GO_MIN})"
need_go=1
if command -v go >/dev/null 2>&1; then
  have="$(go env GOVERSION | sed 's/^go//')"
  if [ "$(printf '%s\n%s\n' "$GO_MIN" "$have" | sort -V | head -1)" = "$GO_MIN" ]; then
    echo "    go $have is new enough"
    need_go=0
  fi
fi
if [ "$need_go" -eq 1 ]; then
  arch="$(dpkg --print-architecture)"   # amd64 or arm64
  url="https://go.dev/dl/go${GO_INSTALL_VERSION}.linux-${arch}.tar.gz"
  echo "    installing go ${GO_INSTALL_VERSION} from ${url}"
  curl -fsSL "$url" -o /tmp/go.tgz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tgz
  if ! grep -q '/usr/local/go/bin' "$HOME/.profile" 2>/dev/null; then
    echo 'export PATH=/usr/local/go/bin:$HOME/go/bin:$PATH' >> "$HOME/.profile"
  fi
  export PATH=/usr/local/go/bin:$HOME/go/bin:$PATH
fi

echo "==> ThreadSanitizer compatibility"
bits="$(cat /proc/sys/vm/mmap_rnd_bits 2>/dev/null || echo 0)"
if [ "$bits" -gt 28 ]; then
  echo "    vm.mmap_rnd_bits=$bits; lowering to 28 so TSan can map its shadow memory"
  sudo sysctl -w vm.mmap_rnd_bits=28 || echo "    (could not change it; see docs/runbooks/dev-environment.md)"
fi

echo "==> done. Next: make check && make verify-sanitizers && make env"
