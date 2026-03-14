<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# scripts

## Purpose
Helper scripts for installation, testing, linting, and maintenance of the dotfiles setup. Includes both Unix shell scripts and PowerShell scripts for cross-platform support.

## Key Files

| File | Description |
|------|-------------|
| `install.sh` | Unix installer: detects OS, installs Chezmoi, initializes dotfiles |
| `install.ps1` | PowerShell installer: Windows equivalent of `install.sh` |
| `test-all.sh` | Runs the full test suite (shellcheck + template rendering) |
| `test-shellcheck.sh` | Lints all shell scripts with ShellCheck, respects `.shellcheckrc` |
| `test-templates.sh` | Verifies all `.tmpl` files render without errors via `chezmoi execute-template` |
| `test-setup.sh` | Validates that all expected CLI tools are installed and working |
| `lint.sh` | ShellCheck linting (used by CI pipeline) |
| `lint.ps1` | PowerShell linting via PSScriptAnalyzer |
| `import-existing.sh` | Imports existing dotfiles into Chezmoi management |
| `setup-age-key.sh` | Sets up age encryption key for Chezmoi secrets |
| `patch-omc-skill-protection.sh` | Patches oh-my-claudecode skill protection bug (unrelated to dotfiles) |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `bootstrap/` | Full bootstrap installers for fresh machines (see `bootstrap/AGENTS.md`) |

## For AI Agents

### Working In This Directory

- All `.sh` scripts must pass ShellCheck (`scripts/lint.sh`). Use `#!/bin/bash` or `#!/usr/bin/env bash`.
- Scripts should be **idempotent** -- safe to run multiple times without side effects.
- Use `command -v` to check for tool availability before using it.
- Scripts targeting CI must work without interactive prompts (check `$CI` environment variable).
- PowerShell scripts (`.ps1`) are linted separately via `scripts/lint.ps1` using PSScriptAnalyzer.

### Testing Requirements

```bash
scripts/test-all.sh          # Full suite
scripts/test-shellcheck.sh   # Shell lint only
scripts/test-templates.sh    # Template render only
bash scripts/lint.sh         # CI-compatible lint
```

### Common Patterns

- `set -euo pipefail` at the top of bash scripts for strict error handling
- `command -v tool >/dev/null 2>&1` for tool existence checks
- Platform detection via `uname -s` (scripts run outside Chezmoi template context)
- Exit codes: 0 = success, non-zero = failure (used by CI)

## Dependencies

### External

- **ShellCheck** -- shell script linter
- **PSScriptAnalyzer** -- PowerShell linter
- **Chezmoi** -- required by template test scripts

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
