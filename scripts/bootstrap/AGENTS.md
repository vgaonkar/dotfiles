<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# bootstrap

## Purpose
Full bootstrap installers for setting up a fresh machine from scratch. These are comprehensive scripts that handle the entire initial setup process including Homebrew, Chezmoi, shell configuration, and tool installation.

## Key Files

| File | Description |
|------|-------------|
| `install.sh` | Unix bootstrap: installs Homebrew/Linuxbrew, Chezmoi, initializes dotfiles, sets default shell, installs Fisher plugins |
| `install.ps1` | Windows bootstrap: installs Scoop/Winget, Chezmoi, initializes dotfiles, installs PowerShell modules |

## For AI Agents

### Working In This Directory

- These scripts are designed to run on a **completely fresh machine** with no prior setup.
- They must be **idempotent** -- safe to re-run without breaking an existing setup.
- `install.sh` handles both macOS (Homebrew) and Linux (Linuxbrew) platforms.
- `install.ps1` handles Windows with PowerShell.
- These are more comprehensive than `../install.sh` and `../install.ps1` (which are lighter-weight wrappers).
- Must work without any tools pre-installed beyond the OS default shell and `curl`/`git`.

### Testing Requirements

- Test in a clean VM or container for each target platform
- Verify idempotency by running twice
- ShellCheck: `shellcheck scripts/bootstrap/install.sh`

### Common Patterns

- Check for existing installations before installing
- Use `set -euo pipefail` for strict error handling
- Print clear progress messages for each step
- Exit with meaningful error messages on failure

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
