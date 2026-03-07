# Gap Analysis -- dotfiles

> **CLAUDE:** Scan Quick Reference for gap count and severity. Load detailed findings only when resolving specific gaps.

## Quick Reference

**Matches:** 12 | **Gaps:** 6 | **Risks:** 3
**Critical gaps:** Age encryption non-functional
**Blocking phases:** None (standalone audit, no implementation plan)

---

## Matches (What Aligns)

| # | Claim | Evidence | Status |
|---|-------|----------|--------|
| 1 | Cross-platform support (macOS, Linux, Windows, WSL2) | Templates have darwin/linux/windows branches | Match |
| 2 | 4 shell support (Fish, Bash, Zsh, PowerShell) | Config files exist for all 4 | Match |
| 3 | Chezmoi-based management | All files follow Chezmoi conventions | Match |
| 4 | 20+ CLI tools installed | 22 brew packages + mise in install script | Match |
| 5 | Secrets gitignored | `.chezmoidata/` in `.gitignore` | Match |
| 6 | ShellCheck linting | Passes with 0 errors | Match |
| 7 | Template rendering works | CI job configured and recent fixes applied | Match |
| 8 | Fish as primary shell | Fish config is most feature-rich | Match |
| 9 | Tool-presence guards | All shell configs use `command -v` / `type -q` | Match |
| 10 | Documentation | 10 numbered guides + 18 tool docs | Match |
| 11 | Conventional commits | Git history shows consistent commit style | Match |
| 12 | Idempotent installation | Scripts check before installing | Match |

## Detailed Findings

### Gap 1: Age encryption is non-functional
- **Project claims:** Age encryption for secrets management (configured in `.chezmoi.toml.tmpl`, documented in `docs/06-secrets-management.md`)
- **Audit found:** `recipient = ""` in age config -- empty recipient makes encryption impossible
- **Risk level:** Medium
- **Affected areas:** Secrets management, security posture
- **Recommendation:** Either populate the recipient from secrets data (`{{ .secrets.age_recipient }}`) or remove the age config if not used. Document the decision.

### Gap 2: CI is failing
- **Project claims:** CI pipeline for linting and template testing (CLAUDE.md verification workflow)
- **Audit found:** Project health report flags CI as failing. 5 consecutive fix commits suggest instability.
- **Risk level:** High
- **Affected areas:** Quality assurance, confidence in changes
- **Recommendation:** Investigate and fix the CI failure. Consider adding a `workflow_dispatch` trigger for manual re-runs.

### Gap 3: No cross-platform CI testing
- **Project claims:** Cross-platform support for macOS, Linux, Windows, WSL2
- **Audit found:** CI only runs on `ubuntu-latest`. macOS and Windows template branches are never tested.
- **Risk level:** Medium
- **Affected areas:** Template correctness on non-Linux platforms
- **Recommendation:** Add a matrix strategy with `macos-latest` runner. Windows testing is less critical since PowerShell scripts are separate.

### Gap 4: PowerShell linting not wired
- **Project claims:** PowerShell support with PSScriptAnalyzer config
- **Audit found:** `PSScriptAnalyzerSettings.psd1` exists but no CI job or script uses it. PowerShell scripts are not linted.
- **Risk level:** Low
- **Affected areas:** Windows/PowerShell script quality
- **Recommendation:** Add a PowerShell lint job to CI or document that PS linting is manual-only.

### Gap 5: CLAUDE.md references non-existent file
- **Project claims:** CLAUDE.md references `run_once_install_default_brew_tools.sh.tmpl`
- **Audit found:** The actual file is `run_onchange_install_brew_tools.sh.tmpl` (changed from `run_once_` to `run_onchange_`)
- **Risk level:** Low
- **Affected areas:** Developer documentation accuracy
- **Recommendation:** Update CLAUDE.md to reference the correct filename.

### Gap 6: Template variable coverage in CI
- **Project claims:** Template system supports `default_shell`, `install_tools`, `work_machine` variables
- **Audit found:** CI only tests one combination (`bash`/`false`/`false`). Fish, zsh, and work_machine=true paths untested.
- **Risk level:** Medium
- **Affected areas:** Template correctness for non-default configurations
- **Recommendation:** Add a matrix or additional CI steps testing `default_shell=fish` and `work_machine=true`.

## Risks

### Risk 1: Supply chain -- Fisher curl-pipe install
- **Description:** Fisher plugin manager installed via `curl | source` without integrity checks
- **Likelihood:** Low (popular, maintained project)
- **Impact:** High (arbitrary code execution in Fish shell)
- **Mitigation:** Pin to a specific commit hash or tag

### Risk 2: Brew package availability
- **Description:** No version pinning for 22 brew packages; package rename/removal breaks install
- **Likelihood:** Low (stable packages)
- **Impact:** Medium (install script fails for affected package)
- **Mitigation:** Accept risk (standard dotfiles practice) or add a Brewfile

### Risk 3: Chezmoi API changes
- **Description:** Template functions (`promptStringOnce`, `promptBoolOnce`) could change in future Chezmoi versions
- **Likelihood:** Very Low (Chezmoi has stable API)
- **Impact:** High (all templates break)
- **Mitigation:** Pin Chezmoi version in CI; test before upgrading locally
