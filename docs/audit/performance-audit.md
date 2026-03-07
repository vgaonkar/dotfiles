# Performance Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /home/dev/Projects/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 4 performance-relevant areas
**Critical issues:** None
**Key facts:**
- Shell startup time is the primary performance concern for dotfiles
- Fish config initializes 5 tools via `| source` (zoxide, fzf, direnv, atuin, starship) -- each adds ~10-50ms
- Bash/Zsh configs use `eval "$(tool init shell)"` pattern -- same overhead
- Brew tool installation is the slowest operation (~5-15 minutes on first run)
- All tool initializations are guarded by `command -v` / `type -q` checks (no errors on missing tools)

**Dependencies:** Shell startup chain, Homebrew, tool init scripts

---

## Critical Findings

No critical performance issues. Shell startup overhead is typical for a modern CLI setup.

## Inventory

### Shell Startup Overhead

| Tool | Init Method (Fish) | Init Method (Bash/Zsh) | Est. Overhead |
|------|-------------------|----------------------|---------------|
| zoxide | `zoxide init fish \| source` | `eval "$(zoxide init bash)"` | ~5-10ms |
| fzf | `fzf --fish \| source` | `source <(fzf --bash)` | ~10-20ms |
| direnv | `direnv hook fish \| source` | `eval "$(direnv hook bash)"` | ~5-10ms |
| atuin | `atuin init fish \| source` | `eval "$(atuin init bash)"` | ~10-30ms |
| starship | `starship init fish \| source` | `eval "$(starship init bash)"` | ~20-50ms |
| Homebrew shellenv | `eval (brew shellenv)` | `eval "$(brew shellenv)"` | ~5-10ms |

**Estimated total shell startup overhead:** ~55-130ms (acceptable for interactive use)

### One-Time Operations

| Operation | Duration | When |
|-----------|----------|------|
| `chezmoi init` | ~1-2s | First run |
| `run_once_before_00_set_default_shell.sh.tmpl` | ~30-120s | First run (installs Fish via brew) |
| `run_onchange_install_brew_tools.sh.tmpl` | ~5-15min | First run + when tool list changes |
| Fisher plugin install | ~10-30s | Part of brew tools script |

### Ongoing Operations

| Operation | Duration | When |
|-----------|----------|------|
| `chezmoi apply` | ~1-2s | Manual update |
| `chezmoi diff` | ~1s | Manual check |
| Shell startup | ~100-200ms total | Every new terminal |

## Configuration

### Fish Config Optimization

The Fish config follows best practices:
1. PATH modifications first (fast)
2. Environment variables set (fast)
3. Keychain SSH setup (conditional, ~20ms when keychain present)
4. Homebrew shellenv (required for tool paths)
5. Interactive-only block for tool inits (non-interactive shells skip all tool init)

The `if status is-interactive` guard ensures non-interactive Fish sessions (scripts, subshells) skip all tool initialization.

### Bash/Zsh Config Optimization

Both configs use `[[ $- != *i* ]] && return` (Bash) or implicit interactive-only loading to skip tool init for non-interactive sessions.

All tool inits are guarded:
```bash
if command -v tool >/dev/null 2>&1; then
    eval "$(tool init bash)"
fi
```
This prevents errors and skips overhead for missing tools.

### Brew Tool Installation

The `run_onchange_install_brew_tools.sh.tmpl` script:
1. Checks each of 22 packages individually (`brew list --formula --versions`)
2. Collects missing packages into a single `brew install` call
3. Re-triggered when `fish_plugins` file hash changes (sha256sum in template)

This is optimal -- avoids reinstalling existing packages.

## Dependencies

- Shell startup speed depends on tool binary startup time (Rust tools like starship, atuin are fast)
- Brew install speed depends on network and Homebrew bottle availability
- Fish plugin install depends on GitHub availability

## Impact Assessment

| Change | Impact |
|--------|--------|
| Add more tool inits | Each adds ~5-50ms to shell startup |
| Lazy-load tool inits | Could reduce startup by ~50-80ms |
| Remove `command -v` guards | Would cause errors on incomplete setups |
| Switch to compiled shell config | Not applicable for Fish/Bash/Zsh |
| Cache brew shellenv | Could save ~5-10ms per startup |

## Evidence

| Check | Result |
|-------|--------|
| Shell startup time | Estimated ~100-200ms (acceptable) |
| Non-interactive overhead | Minimal -- all tool inits guarded |
| Brew install optimization | Yes -- only missing packages installed |
| Fisher optimization | Yes -- installs/updates in batch |
| Memory usage | Negligible (config files, not services) |
| Disk usage | ~50KB managed configs + brew packages (~500MB-1GB typical) |
| Caching strategy | Homebrew bottle cache (managed by brew) |
| Connection pools | N/A |
| Rate limits | N/A |
