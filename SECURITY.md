# Security policy

Helix is a research/portfolio runtime. It has **no authentication, authorization or encryption** on its control or data plane (non-goal, see [docs/design/000-system-design.md](docs/design/000-system-design.md#3-non-goals)). Run it only on trusted, isolated networks.

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private vulnerability reporting ("Security" tab → "Report a vulnerability"). Expect an acknowledgement within 7 days.

## Hardening that does exist

- The wire protocol validates magic, version and header CRC before trusting any length, and caps metadata (64 KiB) and payload (1 GiB) sizes ([SPEC.md §3](SPEC.md#3-wire-format-helix-rpc-data-plane)).
- Parsers (frame codec, WAL reader, command decoder) are fuzzed with libFuzzer and `go test -fuzz`.
- Dependencies are pinned to exact commits ([ADR-0001](docs/adr/0001-build-system-cmake-fetchcontent.md)).
- No secrets are stored in the repository; cloud credentials stay outside it.
