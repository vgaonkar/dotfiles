# Test Coverage Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /Users/vijayg/Development/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 2 test mechanisms (ShellCheck lint + CI template test)
**Critical issues:** 1 -- No unit/integration test framework; testing relies entirely on CI template rendering and manual `test-setup.sh`
**Key facts:**
- ShellCheck lints 6 scripts in `scripts/` -- all pass
- CI runs `chezmoi init` + `chezmoi diff` to verify templates render
- `test-setup.sh` is a manual tool-presence checker, not automated in CI
- No test coverage metrics possible (no test framework)
- Template logic branches (OS/arch/work_machine) are only tested for the CI runner's environment (Ubuntu amd64)

**Dependencies:** ShellCheck, Chezmoi CLI, GitHub Actions runner

---

## Critical Findings

1. **No cross-platform CI testing.** Templates have darwin/linux/windows branches, but CI only runs on `ubuntu-latest`. macOS and Windows template paths are never tested in CI.

2. **`test-setup.sh` is not run in CI.** It checks tool presence but requires all 22 brew packages installed, which the CI environment does not have. This script is manual-only.

3. **No template logic unit tests.** Template conditionals (`{{ if eq .chezmoi.os "darwin" }}`, `{{ if .work_machine }}`) are never tested with varying inputs. Only the default CI values (`CHEZMOI_DEFAULT_SHELL=bash`, `CHEZMOI_INSTALL_TOOLS=false`, `CHEZMOI_WORK_MACHINE=false`) are exercised.

## Inventory

### Test Mechanisms

| Mechanism | Type | Automated | Coverage |
|-----------|------|-----------|----------|
| `scripts/lint.sh` | Static analysis (ShellCheck) | Yes (CI) | 6/6 bash scripts |
| CI template test | Integration | Yes (CI) | Template rendering on Ubuntu |
| `scripts/test-setup.sh` | Smoke test | No (manual) | Tool presence check |

### What Is Tested

| Area | Tested? | How |
|------|---------|-----|
| Bash script syntax | Yes | ShellCheck |
| Template rendering (Linux) | Yes | CI `chezmoi init` + `chezmoi diff` |
| Template rendering (macOS) | No | -- |
| Template rendering (Windows) | No | -- |
| Template rendering (work_machine=true) | No | -- |
| Template rendering (default_shell=fish) | No | CI uses bash |
| Template rendering (default_shell=zsh) | No | -- |
| Fish plugin installation | No | -- |
| Brew package installation | No | -- |
| Shell config loading (Fish) | No | -- |
| Shell config loading (Bash) | No | -- |
| Shell config loading (Zsh) | No | -- |
| Git config rendering | Yes (partial) | CI template test |
| Age encryption | No | -- |
| PowerShell scripts | No | -- |

### Missing Test Coverage (Critical Paths)

1. **macOS Homebrew path resolution** -- `brew-path.tmpl` returns `/opt/homebrew` (arm64) or `/usr/local` (amd64) on macOS, but this is never tested
2. **Fish shell config** -- The primary shell config is never validated in CI
3. **Work machine flag** -- `work_machine=true` path in git config, shell configs untested
4. **Age encryption setup** -- `setup-age-key.sh` is never tested
5. **Windows configs** -- `windows/` directory and PowerShell scripts entirely untested

## Configuration

### CI Test Environment

| Variable | CI Value | Other Valid Values |
|----------|----------|-------------------|
| `CHEZMOI_DEFAULT_SHELL` | `bash` | `fish`, `zsh` |
| `CHEZMOI_INSTALL_TOOLS` | `false` | `true` |
| `CHEZMOI_WORK_MACHINE` | `false` | `true` |
| OS | `ubuntu-latest` | `macos-latest`, `windows-latest` |

### ShellCheck Configuration

- Severity: error only (info/warning/style suppressed)
- SC1007 disabled
- Source paths relative to SCRIPTDIR

## Dependencies

- CI tests depend on Chezmoi being installable via `get.chezmoi.io`
- ShellCheck depends on `apt-get install shellcheck`
- `test-setup.sh` depends on all 22 brew packages being installed locally

## Impact Assessment

| Change | Impact |
|--------|--------|
| Add macOS CI matrix | Would catch darwin-specific template bugs |
| Add variable matrix to CI | Would catch work_machine/shell-specific bugs |
| Add `test-setup.sh` to CI | Would require brew install step (~5-10 min) |
| Reduce ShellCheck severity | Would surface warnings, potentially useful |
| Add PowerShell lint to CI | Would catch PS script issues |

## Evidence

| Check | Result |
|-------|--------|
| ShellCheck | PASS -- 6/6 scripts clean at error severity |
| CI template test | Configured -- runs on push/PR to main |
| Test framework | None -- no bats, shunit2, or pytest |
| Coverage percentage | Not measurable (no test framework) |
| Flaky test detection | N/A |
| Critical path coverage | Low -- only Linux/bash/non-work path tested |
