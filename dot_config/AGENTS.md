<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# dot_config

## Purpose
XDG-compliant application configuration files managed by Chezmoi. This directory maps to `~/.config/` on the target system. Contains templated and static configs for Fish shell, Git, Atuin, Starship, mise, and WezTerm.

## Key Files

| File | Description |
|------|-------------|
| `starship.toml` | Starship prompt theme configuration (static, not templated) |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `fish/` | Fish shell configuration and custom functions (see `fish/AGENTS.md`) |
| `git/` | Git configuration with platform-aware templating (see `git/AGENTS.md`) |
| `atuin/` | Atuin shell history sync configuration (see `atuin/AGENTS.md`) |
| `mise/` | mise (formerly rtx) runtime version manager config (see `mise/AGENTS.md`) |
| `wezterm/` | WezTerm terminal emulator Lua configuration (see `wezterm/AGENTS.md`) |

## For AI Agents

### Working In This Directory

- Files here become `~/.config/<subdir>/<file>` on the target system via Chezmoi's `dot_` prefix expansion.
- **Templated files** (`.tmpl` suffix) use Go template syntax with access to `.chezmoi.os`, `.chezmoi.arch`, and user-defined variables from `.chezmoi.toml.tmpl`.
- **Static files** (no `.tmpl` suffix) are copied as-is without template processing.
- When adding a new application config, create a subdirectory matching the app's XDG config name.

### Testing Requirements

- Test all `.tmpl` files: `chezmoi execute-template < dot_config/<subdir>/file.tmpl`
- Verify with `chezmoi diff` before applying

### Common Patterns

- Each subdirectory corresponds to one application
- Configs that need platform-specific logic use `.tmpl` extension
- Configs that are identical across platforms remain static

## Dependencies

### Internal

- `../.chezmoi.toml.tmpl` -- provides template variables used by `.tmpl` files
- `../.chezmoitemplates/brew-path.tmpl` -- Homebrew path partial used in some templates

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
