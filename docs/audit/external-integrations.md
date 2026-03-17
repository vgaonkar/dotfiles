# External Integrations Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /Users/vijayg/Development/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 8 external integrations
**Critical issues:** None
**Key facts:**
- No database connections, message queues, or backend services
- All integrations are tool-level (package managers, shell plugins, cloud services)
- GitHub is the primary external dependency (repo hosting, CLI auth, Fisher plugins)
- Atuin can optionally sync history to atuin.sh cloud (configured but sync not forced)

**Dependencies:** GitHub, Homebrew, Atuin cloud (optional), Fisher (GitHub-hosted)

---

## Critical Findings

No critical integration issues. All external dependencies are optional or degrade gracefully.

## Inventory

### External Service Integrations

| Service | Used By | Required | Behavior When Unavailable |
|---------|---------|----------|---------------------------|
| GitHub (git) | Repo hosting, `chezmoi update` | Yes (for updates) | Local copy works offline |
| GitHub (API) | `gh` CLI, Fisher plugins | No | CLI commands fail; shell works |
| Homebrew/Linuxbrew | Package installation | Yes (for initial setup) | Scripts exit with error message |
| brew.sh | Homebrew install script | One-time | Manual install alternative exists |
| get.chezmoi.io | Chezmoi install script | One-time | Manual install alternative exists |
| Atuin sync (atuin.sh) | Shell history cloud sync | No | Local history still works |
| Fisher (GitHub raw) | Fish plugin manager install | No | Plugins not installed; Fish still works |
| Starship (GitHub release) | Prompt installed via brew | No | Plain prompt used |

### Tool-Specific Integrations

| Tool | External Service | Config Location | Auth Required |
|------|-----------------|-----------------|---------------|
| `gh` (GitHub CLI) | api.github.com | `~/.config/gh/` (not managed) | Yes (OAuth/token) |
| `atuin` | atuin.sh sync server | `dot_config/atuin/config.toml` | Optional |
| `direnv` | None (local only) | `.envrc` files (per-project) | No |
| `chezmoi` | GitHub repo | `.chezmoi.toml` | SSH key or token |
| `starship` | None (local only) | `dot_config/starship.toml` | No |
| `fzf` | None (local only) | Shell init | No |
| `zoxide` | None (local only) | Shell init | No |

### CDN/Download Dependencies

| URL | Used By | Purpose | Pinned |
|-----|---------|---------|--------|
| `get.chezmoi.io` | `scripts/install.sh`, CI | Install Chezmoi | No |
| `raw.githubusercontent.com/jorgebucaran/fisher/main/...` | `run_onchange_install_brew_tools.sh.tmpl` | Install Fisher | No (main branch) |
| `brew.sh` | Manual prerequisite | Install Homebrew | No |

## Configuration

### Atuin Configuration (`dot_config/atuin/config.toml`)

The Atuin config is a static file (not templated). Key settings affect cloud sync behavior. The config is managed but not templated, meaning all machines get the same Atuin settings.

### Git Config Integration (`dot_config/git/config.tmpl`)

- Core pager: `delta` (external tool)
- Diff/merge tool: VS Code (`code --wait`)
- GPG signing: conditional on `signing_key` or `work_signing_key` in secrets
- Push: `autoSetupRemote = true` (GitHub-friendly default)

## Dependencies

| Integration | Depends On |
|-------------|------------|
| GitHub auth | SSH key or `gh auth login` |
| Atuin sync | Account at atuin.sh (optional) |
| Fisher install | curl, GitHub access |
| Homebrew | Xcode CLT (macOS) or build-essential (Linux) |

## Impact Assessment

| Change | Impact |
|--------|--------|
| GitHub outage | Cannot update dotfiles, install Fisher plugins, or use gh CLI |
| Atuin server outage | History sync stops; local history unaffected |
| Homebrew outage | Cannot install packages; existing installs unaffected |
| Fisher main branch broken | Plugin manager install fails; existing plugins unaffected |
| get.chezmoi.io down | Cannot auto-install Chezmoi; manual install possible |

## Evidence

| Check | Result |
|-------|--------|
| API dependencies | GitHub API (via gh CLI) only |
| Database connections | None |
| Message queues | None |
| Caches | None (brew has its own cache) |
| CDN dependencies | 3 URLs (chezmoi, fisher, brew) |
| Third-party SDK versions | None -- all tools are CLI binaries |
| Offline capability | Partial -- works after initial setup |
