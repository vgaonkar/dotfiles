# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **cross-platform dotfiles manager** using [Chezmoi](https://www.chezmoi.io/). It provides a one-command setup for consistent development environments across macOS, Linux, Windows, and WSL2, with support for Fish, Zsh, Bash, and PowerShell.

## Key Concepts

### Chezmoi File Naming
- `dot_`: Files prefixed with `dot_` become hidden files (e.g., `dot_zshrc` → `~/.zshrc`)
- `executable_`: Files prefixed with `executable_` have the execute bit set
- `private_`: Files prefixed with `private_` have restricted permissions (0600)
- `.tmpl`: Files ending with `.tmpl` are processed as Go templates with user data and platform detection
- Regular files are managed as-is

### Template System
All `.tmpl` files use Go's template syntax and have access to:
- `.chezmoi.os` — `darwin`, `linux`, or `windows`
- `.chezmoi.arch` — `amd64`, `arm64`, etc.
- `.chezmoi.hostname` — Machine hostname
- User-supplied variables from `.chezmoi.toml.tmpl` prompts (e.g., `default_shell`, `work_machine`, `install_tools`)

Example platform-specific logic:
```go
{{ if eq .chezmoi.os "darwin" }}
  # macOS-specific configuration
{{ else if eq .chezmoi.os "linux" }}
  # Linux-specific configuration
{{ end }}
```

### Bootstrap & Installation
- **`.chezmoi.toml.tmpl`** — Main Chezmoi configuration with interactive prompts for user preferences
- **`run_once_install_default_brew_tools.sh.tmpl`** — One-time bootstrap script that installs 20+ CLI tools (starship, zoxide, eza, bat, fzf, etc.) via Homebrew or Linuxbrew
- Secrets stored in `.chezmoidata/` (gitignored) to avoid committing sensitive data

## Common Development Commands

### Testing & Validation
```bash
# Check what changes would be applied
chezmoi diff

# Dry run (preview without applying)
chezmoi apply --dry-run

# Test a specific template
chezmoi execute-template < dot_config/fish/config.fish.tmpl

# Run setup tests (verifies all tools are installed)
scripts/test-setup.sh

# Lint all shell scripts with ShellCheck
scripts/lint.sh
```

### Managing Files
```bash
# Add a new dotfile to be managed
chezmoi add ~/.config/myconfig

# Edit a managed file
chezmoi edit ~/.config/fish/config.fish

# Check diff before applying updates
chezmoi diff

# Apply changes to your system
chezmoi apply

# Update from GitHub
chezmoi update
```

### Working with Templates
When adding a new configuration file that needs platform-specific or user-specific logic:

1. Add the file: `chezmoi add ~/.newconfig`
2. Rename to template: `chezmoi cd` then `mv dot_newconfig dot_newconfig.tmpl`
3. Add template logic using Chezmoi syntax
4. Test: `chezmoi execute-template < dot_newconfig.tmpl`

## Repository Structure

```
dotfiles/
├── .chezmoi.toml.tmpl                           # Config with prompts & user data
├── run_once_install_default_brew_tools.sh.tmpl  # Tool bootstrap (one-time)
├── dot_bashrc.tmpl                              # Bash config
├── dot_zshrc.tmpl                               # Zsh config
├── dot_profile.tmpl                             # POSIX profile
├── dot_config/                                  # XDG config templates
│   ├── fish/
│   │   ├── config.fish.tmpl                     # Fish shell config
│   │   └── fish_plugins                         # Fisher plugins list
│   ├── starship.toml                            # Starship prompt theme
│   ├── git/config.tmpl                          # Git config
│   └── atuin/config.toml                        # Atuin history config
├── docs/                                        # 10 markdown guides + tools
├── site/                                        # Showcase website
├── screenshots/                                 # Terminal previews
├── scripts/                                     # Helper & bootstrap scripts
└── .chezmoidata/                                # Secrets & sensitive data (gitignored)
```

## Testing Changes Locally

Before committing or pushing:

1. **Check the diff** to see what would change:
   ```bash
   chezmoi diff
   ```

2. **Verify all templates render correctly**:
   ```bash
   chezmoi execute-template < path/to/file.tmpl
   ```

3. **Dry-run the apply** to catch any issues:
   ```bash
   chezmoi apply --dry-run
   ```

4. **Test on multiple platforms** if touching shared shell configs:
   - Use conditional `{{ if eq .chezmoi.os "darwin" }}` for platform-specific changes
   - Verify tools used are available on all supported platforms or wrapped in existence checks

5. **Run the test suite**:
   ```bash
   scripts/test-setup.sh    # Verify all tools are installed
   scripts/lint.sh          # Check shell script syntax
   ```

## Documentation Guidelines

Documentation lives in `docs/` with sequential numbering:
- Keep files numbered (e.g., `10-topic.md`, `20-another-topic.md`)
- Link related documents at the bottom
- Use clear headings and code block examples
- See `docs/00-table-of-contents.md` for the overall structure

## Key Included Tools

The `run_once_install_default_brew_tools.sh.tmpl` script installs these CLI tools via Homebrew/Linuxbrew:

**Core tools**: starship (prompt), zoxide (smart cd), eza (modern ls), bat (syntax cat), fzf (fuzzy find), direnv (env management), atuin (shell history), fd, ripgrep, git, gh (GitHub CLI)

**Utilities**: jq (JSON), poppler (PDF), qpdf (PDF edit), tesseract (OCR), ocrmypdf (PDF OCR), pandoc (format conversion), git-delta (diff), procs (process viewer), bottom (system monitor), dust (disk usage), gping (ping with graph)

## Shell Configuration Strategy

The setup supports **four shells** with a unified approach:
- **Fish** (primary, recommended) — Modern, user-friendly syntax
- **Zsh** — Macros and plugin ecosystem
- **Bash** — Fallback for compatibility
- **PowerShell** — Windows native support

Each shell's config file (`dot_bashrc.tmpl`, `dot_zshrc.tmpl`, `dot_config/fish/config.fish.tmpl`) is templated to:
1. Source common variables from `dot_profile.tmpl`
2. Use conditional logic to detect OS and installed tools
3. Only load tools if available, avoiding errors on incomplete setups

## Contributing

When adding new configuration:
- Follow the naming conventions (`dot_`, `executable_`, `.tmpl`)
- Test changes with `chezmoi diff` and `chezmoi apply --dry-run`
- Keep related documentation updated
- Use atomic commits with conventional commit style
- Ensure changes work on supported platforms before submitting a PR

## Research References

- **Chezmoi-Based Cross-Platform Dotfiles Architecture**: `docs/research/dotfiles-chezmoi-architecture.md` — Comprehensive research on Chezmoi architecture, templating system, secrets management, cross-platform strategies, and comparison with alternatives (researched 2026-03-04)
