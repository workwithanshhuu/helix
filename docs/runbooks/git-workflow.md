# Runbook: daily git workflow

Conventions: [CLAUDE.md §7](../../CLAUDE.md#7-git-conventions).

```bash
git switch main && git pull --ff-only
git switch -c day-NN-<topic>          # e.g. day-03-spsc-ring
# ... Claude Code builds in small steps; make check before each commit ...
git commit -m "feat(core): add SPSC ring with cached indices" -m "Covered by SpscRingTest.*; TSan x100."
git push -u origin day-NN-<topic>
gh pr create --fill                    # or open in the browser; body from .github/pull_request_template.md
# wait for CI green → squash or merge → delete branch
git switch main && git pull --ff-only
```

Milestone tags: `git tag -a v0.1 -m "M1: low-level core" && git push origin v0.1` (days 11, 17, 28, 38, 45).

Never: push to `main`, force-push a shared branch, commit build outputs, secrets or Terraform state.
