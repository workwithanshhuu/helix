# scripts

| Script | Purpose |
| --- | --- |
| `bootstrap-dev.sh` | Install the toolchain inside the Ubuntu 24.04 dev machine (idempotent) |
| `check-env.sh` | Markdown report of machine/toolchain facts + requirement checks (`make env`) |
| `verify-sanitizers-catch-races.sh` | Builds the deliberately racy programs in `race-demo/` and asserts TSan and the Go race detector report them (`make verify-sanitizers`, CI job `sanitizer-canary`) |
| `race-demo/` | Deliberately broken programs; excluded from the normal build (`racedemo` build tag for Go) |
