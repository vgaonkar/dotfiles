# Verification Results -- dotfiles

> **CLAUDE:** Scan cycle verdicts for pass/fail status. Load detailed findings only when investigating specific failures.

---

## QA Cycle 1: Data Loss & Integrity

### Findings
| # | Risk | Severity | Area | Description | Mitigation |
|---|------|----------|------|-------------|------------|
| 1 | Secrets exposure | Medium | Security | `.chezmoidata/secrets.yml` exists locally but gitignore prevents commit. No `.git/info/exclude` backup. | Verified `.gitignore` covers `.chezmoidata/`. Consider adding to `.git/info/exclude` as defense-in-depth. |
| 2 | Template data loss | Low | Config | `chezmoi state delete` removes all run_once markers, forcing re-execution of shell change script | Document in troubleshooting guide that state reset re-runs shell setup |
| 3 | Config overwrite | Low | Apply | `chezmoi apply` overwrites target files without backup by default | Users should run `chezmoi diff` first (documented in CLAUDE.md) |

### Cycle Verdict
**Pass** -- No data loss risks beyond standard Chezmoi behavior. Secrets are properly gitignored.

---

## QA Cycle 2: Service Continuity

### Findings
| # | Risk | Severity | Area | Description | Mitigation |
|---|------|----------|------|-------------|------------|
| 1 | Shell change disruption | Low | Bootstrap | `run_once_before_00_set_default_shell.sh.tmpl` changes login shell, which affects current sessions | Script warns if non-interactive; change takes effect on next login |
| 2 | Tool init failure | Low | Shell config | If a tool binary is corrupted or removed, `eval "$(tool init shell)"` could produce errors | All inits guarded by `command -v` / `type -q` checks -- safe |
| 3 | Brew install interruption | Medium | Install | If `brew install` is interrupted mid-batch, some packages may be partially installed | `brew install` is atomic per package; re-run completes remaining |

### Cycle Verdict
**Pass** -- Shell configs degrade gracefully. Tool initialization guards prevent errors.

---

## QA Cycle 3: Rollback & Recovery

### Findings
| # | Risk | Severity | Area | Description | Mitigation |
|---|------|----------|------|-------------|------------|
| 1 | No rollback mechanism | Medium | Apply | `chezmoi apply` has no built-in rollback. Overwritten files are lost unless backed up. | Use `chezmoi diff` before applying. Git history preserves source templates. |
| 2 | Shell change irreversible | Low | Bootstrap | Once fish is set as login shell, reverting requires manual `chsh -s /bin/bash` | Document rollback in troubleshooting guide |
| 3 | Brew uninstall cascades | Low | Packages | Removing a brew package could remove shared dependencies | Homebrew tracks dependencies; `brew autoremove` is opt-in |

### Cycle Verdict
**Pass** -- Rollback is manual but straightforward. `chezmoi diff` provides preview capability.

---

## QA Cycle 4: Edge Cases & Historical Misses

### Findings
| # | Risk | Severity | Area | Description | Mitigation |
|---|------|----------|------|-------------|------------|
| 1 | Fish not in /etc/shells | Medium | Bootstrap | On some Linux distros, `sudo` may not be available or user may not have sudo access. Script warns but cannot add fish to `/etc/shells`. | Script handles this gracefully with warning message |
| 2 | Brew prefix mismatch | Low | Templates | If Homebrew is installed in a non-standard location, `brew-path.tmpl` returns wrong path | `brew-path.tmpl` covers standard locations; `command -v brew` fallback in scripts |
| 3 | WSL2 path issues | Low | Config | Fish config does `cd ~/Projects` on login, which may not exist on WSL2 fresh install | Directory checked via `test "$PWD" = "$HOME"` but target dir not checked |
| 4 | Keychain binary differences | Low | Fish config | `keychain` behavior varies across distros; Fish config spawns bash subprocess for keychain eval | Works on tested distros; may fail silently on exotic setups |
| 5 | `--icons` flag in eza aliases | Low | Shell config | Bash/Zsh use `eza --icons` but Fish uses plain `eza`. Inconsistent behavior. | Minor UX difference; Fish uses abbreviations vs aliases |
| 6 | Git config hardcodes VS Code | Medium | Git config | `core.editor`, `difftool`, `mergetool` all reference `code` (VS Code). Users without VS Code get errors. | Should be conditional on `command -v code` or templated from user preference |

### Cycle Verdict
**Pass with notes** -- Edge cases are minor. Git config VS Code dependency is the most impactful finding (Medium severity).

---

## Overall Verification Summary

| Cycle | Category | Verdict | Critical Issues |
|-------|----------|---------|-----------------|
| 1 | Data Loss & Integrity | Pass | None |
| 2 | Service Continuity | Pass | None |
| 3 | Rollback & Recovery | Pass | None |
| 4 | Edge Cases | Pass (with notes) | Git config VS Code dependency |

**Total findings:** 14
**Critical:** 0
**High:** 0
**Medium:** 4
**Low:** 10
