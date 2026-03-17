# File Structure & Architecture Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /Users/vijayg/Development/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 47 tracked files (excluding .git, .omc, .claude)
**Critical issues:** None
**Key facts:**
- Well-organized Chezmoi source directory with clear naming conventions (dot_, run_once_, run_onchange_)
- 4 shell configs (Fish, Bash, Zsh, POSIX profile) + 1 PowerShell for Windows
- Documentation is thorough: 10 numbered guides + 18 tool docs + research + site
- No orphan files or dead code detected

**Dependencies:** Chezmoi (template engine), Homebrew/Linuxbrew (package manager), Fish shell (primary)

---

## Critical Findings

No critical structural issues found. The project follows Chezmoi conventions correctly.

## Inventory

### Root-Level Chezmoi Managed Files

| File | Type | Target | Platform |
|------|------|--------|----------|
| `.chezmoi.toml.tmpl` | Config template | `~/.config/chezmoi/chezmoi.toml` | All |
| `dot_bashrc.tmpl` | Shell config | `~/.bashrc` | All |
| `dot_bash_profile.tmpl` | Shell config | `~/.bash_profile` | All |
| `dot_zshrc.tmpl` | Shell config | `~/.zshrc` | All |
| `dot_zprofile.tmpl` | Shell config | `~/.zprofile` | All |
| `dot_profile.tmpl` | Shell config | `~/.profile` | All |
| `run_once_before_00_set_default_shell.sh.tmpl` | Run-once script | N/A (executed) | darwin, linux |
| `run_onchange_install_brew_tools.sh.tmpl` | Run-on-change script | N/A (executed) | darwin, linux |
| `run_onchange_setup_wezterm.sh.tmpl` | Run-on-change script | N/A (executed) | darwin, linux |

### Config Directory (`dot_config/`)

| Path | Type | Target |
|------|------|--------|
| `fish/config.fish.tmpl` | Template | `~/.config/fish/config.fish` |
| `fish/fish_plugins` | Static | `~/.config/fish/fish_plugins` |
| `fish/functions/alert.fish` | Static | `~/.config/fish/functions/alert.fish` |
| `git/config.tmpl` | Template | `~/.config/git/config` |
| `starship.toml` | Static | `~/.config/starship.toml` |
| `atuin/config.toml` | Static | `~/.config/atuin/config.toml` |
| `mise/config.toml` | Static | `~/.config/mise/config.toml` |
| `wezterm/wezterm.lua` | Static | `~/.config/wezterm/wezterm.lua` |

### Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `install.sh` | Main installer (macOS/Linux) |
| `install.ps1` | Main installer (Windows/PowerShell) |
| `bootstrap/install.sh` | Browser-login bootstrap (HTTPS) |
| `bootstrap/install.ps1` | Browser-login bootstrap (Windows) |
| `lint.sh` | ShellCheck linter for scripts/ |
| `test-setup.sh` | Verify all tools installed |
| `setup-age-key.sh` | Bootstrap age encryption key |
| `import-existing.sh` | Import existing dotfiles |

### Templates (`.chezmoitemplates/`)

| Template | Purpose |
|----------|---------|
| `brew-path.tmpl` | Resolves Homebrew prefix per OS/arch |

### Documentation (`docs/`)

- 10 numbered guides (00-09): TOC, quick start, installation, configuration, customization, troubleshooting, secrets, platform-specific, migration, development
- 18 tool-specific docs in `docs/tools/`
- 1 research document: `docs/research/dotfiles-chezmoi-architecture.md`
- 1 starship themes guide
- 1 secrets example file

### Other

| Path | Purpose |
|------|---------|
| `site/index.html` | Showcase website |
| `screenshots/` | SVG terminal previews (6 SVGs + VHS tapes) |
| `windows/` | Windows-specific configs (Terminal settings, WezTerm installer) |
| `.shellcheckrc` | ShellCheck config (severity=error) |
| `PSScriptAnalyzerSettings.psd1` | PowerShell linter settings |
| `.github/workflows/ci.yml` | GitHub Actions CI pipeline |

## Configuration

### Naming Conventions
- `dot_` prefix for hidden files (Chezmoi standard)
- `.tmpl` suffix for Go-template files
- `run_once_before_` / `run_onchange_` for Chezmoi script ordering
- `executable_` prefix not used (scripts use shebang + Chezmoi auto-detect)
- Numbered docs (00-09) for ordered reading

### Environment Variables Used in Templates
- `CI`, `CODESPACES` -- container/CI detection
- `CHEZMOI_DEFAULT_SHELL`, `CHEZMOI_INSTALL_TOOLS`, `CHEZMOI_WORK_MACHINE` -- CI overrides
- `DOTFILES_BREW_BIN` -- passed to Fish subprocess in brew installer

### Template Variables (from `.chezmoi.toml.tmpl`)
- `default_shell` (string: fish/zsh/bash)
- `install_tools` (bool)
- `work_machine` (bool)
- `os`, `arch`, `hostname` (auto-detected)
- `is_mac`, `is_linux`, `is_windows`, `is_arm64`, `is_amd64` (derived booleans)
- `is_ci`, `is_container` (derived booleans)

## Dependencies

- Chezmoi depends on Go templates and `.chezmoi.toml.tmpl` for user data
- Shell configs depend on `dot_profile.tmpl` for PATH setup
- `run_onchange_install_brew_tools.sh.tmpl` depends on `run_once_before_00_set_default_shell.sh.tmpl` (fish must be installed first)
- `brew-path.tmpl` is included by both run scripts and `config.fish.tmpl`
- Fish plugins list (`fish_plugins`) drives Fisher plugin installation in the brew tools script

## Impact Assessment

| Change | Impact |
|--------|--------|
| Modify `brew-path.tmpl` | Breaks all Homebrew-dependent scripts and Fish config |
| Change `.chezmoi.toml.tmpl` variables | All template files affected |
| Rename/move `dot_config/fish/fish_plugins` | Brew tools script hash changes, triggers reinstall |
| Delete any `run_once_` script | Cannot be re-run without `chezmoi state delete` |
| Modify CI workflow | Only affects GitHub Actions, not local usage |

## Evidence

| Check | Result |
|-------|--------|
| Orphan files | None found -- all files serve a documented purpose |
| Dead code | No unreachable template branches detected |
| Naming consistency | All managed files follow Chezmoi conventions |
| Config file locations | XDG-compliant (`dot_config/`) |
| Platform coverage | macOS (darwin), Linux, Windows, WSL2 |
