<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# .github

## Purpose
GitHub-specific configuration including CI/CD workflows for automated linting and template validation.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `workflows/` | GitHub Actions workflow definitions |

## Key Files (nested)

| File | Description |
|------|-------------|
| `workflows/ci.yml` | CI pipeline: runs ShellCheck linting and Chezmoi template rendering tests on push/PR to main |

## For AI Agents

### Working In This Directory

- The CI pipeline has **two jobs**: `lint` (ShellCheck via `scripts/lint.sh`) and `template-test` (Chezmoi template rendering with non-interactive env vars).
- Template tests use environment variables to bypass interactive prompts: `CHEZMOI_DEFAULT_SHELL=bash`, `CHEZMOI_INSTALL_TOOLS=false`, `CHEZMOI_WORK_MACHINE=false`.
- Workflow runs on `ubuntu-latest`.
- Triggers: push to `main`, pull requests targeting `main`.

### Testing Requirements

- Validate YAML syntax before committing workflow changes
- Test locally with `act` or by running the equivalent commands: `bash scripts/lint.sh` and template init/diff

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
