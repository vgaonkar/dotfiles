<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# fish

## Purpose
Fish shell configuration managed by Chezmoi. Fish is the **primary recommended shell** for this dotfiles project. Contains the main config, plugin list, and custom functions.

## Key Files

| File | Description |
|------|-------------|
| `config.fish.tmpl` | Main Fish configuration (templated): sets paths, loads tools (starship, zoxide, fzf, atuin, direnv), defines aliases |
| `fish_plugins` | Fisher plugin manager plugin list (static): `PatrickF1/fzf.fish`, `meaningful-ooo/sponge` |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `functions/` | Custom Fish functions (autoloaded by Fish) |

## For AI Agents

### Working In This Directory

- `config.fish.tmpl` is a **Go template** -- uses `{{ if eq .chezmoi.os "darwin" }}` for platform logic and `{{ template "brew-path.tmpl" . }}` for Homebrew path.
- Fish functions in `functions/` are **autoloaded** by Fish shell -- each file defines one function matching the filename (e.g., `alert.fish` defines the `alert` function).
- The `fish_plugins` file is consumed by [Fisher](https://github.com/jorgebucaran/fisher) plugin manager. One plugin per line.
- Tool integrations use Fish's `type -q` for existence checks (not `command -v`).

### Testing Requirements

- Template: `chezmoi execute-template < dot_config/fish/config.fish.tmpl`
- Syntax: `fish -n config.fish` (after rendering)
- Functions: `fish -n functions/alert.fish`

### Common Patterns

- `type -q toolname; and ...` for conditional tool loading in Fish
- `fish_add_path` for PATH modifications (Fish-native, idempotent)
- Abbreviations (`abbr`) preferred over aliases in Fish

## Dependencies

### Internal

- `../../.chezmoitemplates/brew-path.tmpl` -- Homebrew path partial
- `../../.chezmoi.toml.tmpl` -- template variables (`install_tools`, `default_shell`)

### External

- **Fisher** -- Fish plugin manager
- **fzf.fish** -- fzf integration for Fish
- **sponge** -- cleans command history of failed commands

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
