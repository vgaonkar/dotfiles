# Risk Register -- dotfiles

> **Audited:** 2026-03-06 | **Target:** /Users/vijayg/Development/dotfiles

| # | Risk | Severity | Likelihood | Area | Mitigation | Status |
|---|------|----------|------------|------|------------|--------|
| 1 | CI pipeline failing | High | Confirmed | CI/CD | Investigate and fix workflow; add workflow_dispatch for manual re-runs | Open |
| 2 | Age encryption non-functional | Medium | Confirmed | Security | Populate recipient from secrets data or remove [age] section | Open |
| 3 | Fisher curl-pipe supply chain | Medium | Low | Security | Pin Fisher install to specific commit hash or tag | Open |
| 4 | No cross-platform CI testing | Medium | N/A | Testing | Add macOS matrix to GitHub Actions | Open |
| 5 | Template variable paths untested | Medium | N/A | Testing | Add CI matrix for default_shell and work_machine variations | Open |
| 6 | Git config hardcodes VS Code | Medium | Medium | Config | Make editor/difftool conditional on `command -v code` | Open |
| 7 | CLAUDE.md references wrong filename | Low | Confirmed | Docs | Update `run_once_install_default_brew_tools.sh.tmpl` to `run_onchange_install_brew_tools.sh.tmpl` | Open |
| 8 | PSScriptAnalyzer not wired in CI | Low | N/A | Build | Add PowerShell lint job or document as manual-only | Open |
| 9 | Fish plugins not version-pinned | Low | Low | Dependencies | Accept risk (standard practice) or pin to tags | Accepted |
| 10 | Brew packages not version-pinned | Low | Low | Dependencies | Accept risk (standard practice for dotfiles) | Accepted |
| 11 | Chezmoi API changes | Low | Very Low | Dependencies | Pin Chezmoi version in CI; test before upgrading | Accepted |
| 12 | WSL2 ~/Projects may not exist | Low | Low | Config | Add directory existence check before cd | Open |
| 13 | Eza --icons inconsistency | Low | Confirmed | Config | Fish uses abbreviations without --icons; Bash/Zsh aliases include --icons | Accepted |

## Summary

- **Open:** 8 risks requiring action
- **Accepted:** 5 risks acknowledged as low-impact or standard practice
- **Critical:** 0
- **High:** 1 (CI failure)
- **Medium:** 5
- **Low:** 7
