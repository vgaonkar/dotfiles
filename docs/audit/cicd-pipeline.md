# CI/CD Pipeline Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /Users/vijayg/Development/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 1 workflow file, 2 jobs
**Critical issues:** 1 -- CI is reportedly failing (per project health report)
**Key facts:**
- GitHub Actions workflow at `.github/workflows/ci.yml`
- 2 jobs: `lint` (ShellCheck) and `template-test` (Chezmoi render)
- Triggers: push to main, PR to main
- No deployment stage (dotfiles are applied locally, not deployed)
- CI has had 5 consecutive fix commits recently, suggesting instability

**Dependencies:** GitHub Actions, ubuntu-latest runner, ShellCheck (apt), Chezmoi (curl install)

---

## Critical Findings

1. **CI reportedly failing.** The project health report from 2026-03-07 flags dotfiles CI as failing. The 5 most recent commits are all CI fixes, suggesting ongoing instability in the template-test job.

2. **No branch protection.** The workflow runs on push to main and PRs to main, but there is no evidence of required status checks or branch protection rules. Direct pushes to main bypass CI.

3. **Chezmoi installed via curl in CI.** The `template-test` job fetches Chezmoi via `curl -fsLS get.chezmoi.io`. This is the official method but depends on external infrastructure. No version pinning.

## Inventory

### Workflow: `.github/workflows/ci.yml`

| Job | Runner | Steps | Duration (est.) |
|-----|--------|-------|-----------------|
| `lint` | ubuntu-latest | checkout, install shellcheck, run lint.sh | ~30s |
| `template-test` | ubuntu-latest | checkout, install chezmoi, init + diff | ~60s |

### Job Details

**Job: `lint`**
1. `actions/checkout@v4` -- checkout repo
2. `apt-get install -y shellcheck` -- install linter
3. `bash scripts/lint.sh` -- run ShellCheck on `scripts/*.sh`

**Job: `template-test`**
1. `actions/checkout@v4` -- checkout repo
2. Install chezmoi via `get.chezmoi.io` to `$HOME/bin`
3. Set env vars: `CHEZMOI_DEFAULT_SHELL=bash`, `CHEZMOI_INSTALL_TOOLS=false`, `CHEZMOI_WORK_MACHINE=false`, `CI=true`
4. `chezmoi init --source=. --no-tty` -- initialize without prompts
5. `chezmoi diff --source=. --no-pager` -- verify templates render

### Pipeline Characteristics

| Aspect | Status |
|--------|--------|
| Lint stage | Yes (ShellCheck) |
| Test stage | Yes (template rendering) |
| Build stage | N/A |
| Deploy stage | N/A (local apply) |
| Matrix testing | No (single OS/config) |
| Caching | No |
| Artifacts | No |
| Notifications | No |
| Branch protection | Unknown (not in repo config) |
| Required checks | Unknown |

## Configuration

### Trigger Configuration

```yaml
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
```

- No path filters (all pushes/PRs trigger CI)
- No scheduled runs
- No manual dispatch

### Environment Variables (template-test)

| Variable | Value | Purpose |
|----------|-------|---------|
| `CHEZMOI_DEFAULT_SHELL` | `bash` | Avoid interactive prompt |
| `CHEZMOI_INSTALL_TOOLS` | `false` | Skip brew install in CI |
| `CHEZMOI_WORK_MACHINE` | `false` | Use personal config path |
| `CI` | `true` | Skip delta/vimdiff/code config |

### Recent CI Fix History

| Commit | Fix |
|--------|-----|
| `1f59ae9` | Skip delta/vimdiff/code config in CI |
| `e05b8bd` | Pass `--source=.` to chezmoi diff |
| `800a55c` | Remove invalid `--config` flag |
| `0ebee4f` | Fix PATH override breaking chezmoi install |
| `f406762` | Replace nonexistent action with official install script |

## Dependencies

- `actions/checkout@v4` -- GitHub-maintained action
- `get.chezmoi.io` -- external script for Chezmoi installation
- `apt-get` -- Ubuntu package manager for ShellCheck
- GitHub Actions runner infrastructure

## Impact Assessment

| Change | Impact |
|--------|--------|
| Add macOS matrix | Catches darwin template bugs, doubles CI time |
| Pin Chezmoi version | Prevents breakage from upstream changes |
| Add path filters | Reduces unnecessary CI runs for docs-only changes |
| Add PowerShell lint job | Catches PS script issues |
| Add variable matrix | Tests fish/zsh/work_machine permutations |

## Evidence

| Check | Result |
|-------|--------|
| Workflow syntax | Valid YAML, correct GitHub Actions schema |
| Job independence | Yes -- lint and template-test run in parallel |
| Secrets in CI | None -- no secrets used in workflow |
| CI failure rate | High recently -- 5 consecutive fix commits |
| Pipeline duration | ~1-2 minutes total (estimated) |
| Deployment strategy | N/A (no deployment) |
