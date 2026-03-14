<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# windows

## Purpose
Windows-specific configuration files that are NOT managed by Chezmoi (excluded via `.chezmoiignore`). Contains PowerShell profile, Windows Terminal settings, and WezTerm installation script. These files are manually copied or referenced on Windows machines.

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `Documents/PowerShell/` | PowerShell profile directory (currently empty placeholder) |
| `scripts/` | Windows-specific installation scripts |
| `AppData/Local/Packages/Microsoft.WindowsTerminal_.../LocalState/` | Windows Terminal settings |

## Key Files (nested)

| File | Description |
|------|-------------|
| `scripts/install-wezterm.ps1` | PowerShell script to install WezTerm on Windows |
| `AppData/.../LocalState/settings.json` | Windows Terminal settings (theme, keybindings, profiles) |

## For AI Agents

### Working In This Directory

- These files are **excluded from Chezmoi** via `.chezmoiignore` -- they are not automatically deployed.
- PowerShell scripts must pass PSScriptAnalyzer (`scripts/lint.ps1` from the parent `scripts/` directory).
- Windows Terminal settings use the standard `settings.json` schema from Microsoft.
- File paths follow Windows conventions but are stored with Unix-style separators in the repo.

### Testing Requirements

- PowerShell scripts: `pwsh scripts/lint.ps1` (requires PSScriptAnalyzer module)
- Windows Terminal settings: validate JSON syntax

### Common Patterns

- PowerShell uses `$ErrorActionPreference = 'Stop'` for strict error handling
- Winget or Scoop for package installation on Windows

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
