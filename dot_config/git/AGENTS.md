<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# git

## Purpose
Git configuration managed by Chezmoi. Contains a templated `config` file that sets user identity, aliases, diff/merge tools, and platform-specific settings.

## Key Files

| File | Description |
|------|-------------|
| `config.tmpl` | Git configuration (templated): user info, aliases, delta as diff pager, platform-aware settings |

## For AI Agents

### Working In This Directory

- `config.tmpl` is a **Go template** that becomes `~/.config/git/config` on the target system.
- Uses Chezmoi variables for user identity and platform-specific tool paths.
- Delta is configured as the default diff pager (installed via `run_onchange_install_brew_tools.sh.tmpl`).

### Testing Requirements

- Template: `chezmoi execute-template < dot_config/git/config.tmpl`

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
