# Dependency Graph Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /Users/vijayg/Development/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 22 brew packages + 4 Fish plugins + 6 external tools
**Critical issues:** None
**Key facts:**
- No package.json, requirements.txt, or lockfile -- dependencies are managed via Homebrew formulae list in a Chezmoi template
- No known CVEs in brew formulae (Homebrew handles security updates via `brew upgrade`)
- 4 Fish plugins fetched from GitHub at install time (no pinned versions)
- Age encryption key dependency is optional (only if secrets are encrypted)

**Dependencies:** Homebrew/Linuxbrew (package manager), GitHub (Fish plugin source), Chezmoi (orchestrator)

---

## Critical Findings

1. **Fish plugins are not version-pinned.** The `fish_plugins` file references GitHub repos without tags or commits. A breaking change upstream could break the shell. Risk: Low (these are stable, popular plugins).

2. **Brew packages are not version-pinned.** The install script uses `brew install <pkg>` without version constraints. Homebrew defaults to latest. This is standard practice for dotfiles but means reproducibility is not guaranteed.

## Inventory

### Homebrew Packages (22 formulae)

| Package | Purpose | Category |
|---------|---------|----------|
| starship | Cross-shell prompt | Core |
| zoxide | Smart directory jumper | Core |
| eza | Modern ls replacement | Core |
| bat | Syntax-highlighted cat | Core |
| fzf | Fuzzy finder | Core |
| direnv | Per-directory env vars | Core |
| atuin | Shell history sync | Core |
| fd | Modern find | Core |
| ripgrep | Fast grep | Core |
| git | Version control | Core |
| gh | GitHub CLI | Core |
| jq | JSON processor | Utility |
| poppler | PDF utilities | Utility |
| qpdf | PDF editor | Utility |
| tesseract | OCR engine | Utility |
| ocrmypdf | PDF OCR | Utility |
| pandoc | Document converter | Utility |
| git-delta | Better diff | Utility |
| procs | Process viewer | Utility |
| bottom | System monitor | Utility |
| dust | Disk usage | Utility |
| gping | Ping with graphs | Utility |
| mise | Runtime version manager | Core |

### Fish Plugins (from `fish_plugins`)

| Plugin | Source | Purpose |
|--------|--------|---------|
| jorgebucaran/fisher | GitHub | Plugin manager |
| PatrickF1/fzf.fish | GitHub | FZF integration for Fish |
| jethrokuan/z | GitHub | Directory jumper (z) |
| nickeb96/puffer-fish | GitHub | Text expansion |

### External Tools (not managed by this repo)

| Tool | Required By | How Installed |
|------|------------|---------------|
| Homebrew/Linuxbrew | All brew packages | Manual (brew.sh) |
| Chezmoi | Everything | `curl -fsLS get.chezmoi.io` |
| curl | Fisher install, Chezmoi install | OS default |
| sudo | Adding fish to /etc/shells | OS default |
| chsh | Setting default shell | OS default |
| keychain | SSH agent (Fish config) | Optional, detected at runtime |

### Optional Dependencies

| Tool | Used In | Behavior When Missing |
|------|---------|----------------------|
| delta | `.chezmoi.toml.tmpl` diff config | Chezmoi diff falls back to default |
| code (VS Code) | Git config, chezmoi edit | Git/chezmoi use fallback editor |
| vimdiff | `.chezmoi.toml.tmpl` merge config | Chezmoi merge uses default |
| keychain | Fish config SSH setup | SSH block skipped silently |

## Configuration

### Dependency Resolution Order

```
1. Homebrew/Linuxbrew (must be pre-installed)
2. run_once_before_00_set_default_shell.sh.tmpl
   -> installs Fish via brew
   -> sets Fish as login shell
3. run_onchange_install_brew_tools.sh.tmpl
   -> installs 22 brew packages
   -> installs Fisher plugin manager
   -> installs 4 Fish plugins
4. Shell configs loaded (Fish/Bash/Zsh)
   -> each tool initialized only if `command -v` succeeds
```

### Transitive Dependencies

Homebrew manages transitive dependencies automatically. Key transitive chains:
- `ocrmypdf` -> `tesseract` + `ghostscript` + `pngquant`
- `git-delta` -> `git` (peer dependency)
- `fzf.fish` (Fish plugin) -> `fzf` (brew package)

## Dependencies (cross-file)

| Source File | Depends On |
|-------------|------------|
| `run_onchange_install_brew_tools.sh.tmpl` | `brew-path.tmpl`, `fish_plugins`, Homebrew, Fish |
| `run_once_before_00_set_default_shell.sh.tmpl` | `brew-path.tmpl`, Homebrew |
| `config.fish.tmpl` | `brew-path.tmpl`, all brew packages (conditional) |
| `dot_bashrc.tmpl` | brew packages (conditional via `command -v`) |
| `dot_zshrc.tmpl` | brew packages (conditional via `command -v`) |
| `dot_profile.tmpl` | Homebrew |
| `git/config.tmpl` | delta, VS Code |

## Impact Assessment

| Change | Impact |
|--------|--------|
| Homebrew unavailable | All tool installation fails; shell configs degrade gracefully |
| Fish plugin repo deleted | Fisher install fails; shell still works without plugins |
| Brew package renamed | Install script fails for that package; other packages unaffected |
| GitHub down | Fisher plugin install fails; brew packages unaffected (bottles cached) |
| `brew-path.tmpl` broken | All scripts and Fish config break |

## Evidence

| Check | Result |
|-------|--------|
| Package lockfile exists | No -- Homebrew does not use lockfiles for formulae |
| Version pinning | No -- standard for dotfiles repos |
| Vulnerability scan | N/A -- no npm/pip/go dependencies; Homebrew handles CVE patches |
| Circular dependencies | None detected |
| License compatibility | All tools are open source (MIT, Apache 2.0, GPL) |
| Outdated dependencies | Cannot determine without `brew outdated` on each target machine |
