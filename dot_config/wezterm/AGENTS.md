<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# wezterm

## Purpose
Configuration for [WezTerm](https://wezfurlong.org/wezterm/), a GPU-accelerated cross-platform terminal emulator. Uses Lua for configuration, providing programmatic control over appearance, keybindings, and behavior.

## Key Files

| File | Description |
|------|-------------|
| `wezterm.lua` | Complete WezTerm configuration: color scheme, font, keybindings, tab bar, window settings |

## For AI Agents

### Working In This Directory

- WezTerm config is written in **Lua** (not TOML or YAML) -- it is a full programming language with access to the WezTerm API.
- This is a **static file** (not templated) -- same config across all platforms.
- WezTerm is installed separately via `run_onchange_setup_wezterm.sh.tmpl` (Unix) or `windows/scripts/install-wezterm.ps1` (Windows).
- See [WezTerm docs](https://wezfurlong.org/wezterm/config/files.html) for configuration reference.

### Testing Requirements

- Validate Lua syntax: `luac -p wezterm.lua` (if luac is available)
- Visual verification: restart WezTerm after changes

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
