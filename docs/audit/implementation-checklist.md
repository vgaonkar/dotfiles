# Implementation Checklist -- dotfiles

> **Generated:** 2026-03-06 | **Source:** deep-verify baseline audit

## Before Starting Any Changes

- [ ] Verify CI status: `gh run list --repo vgaonkar/dotfiles --limit 5`
- [ ] Verify local chezmoi state: `chezmoi doctor`
- [ ] Read audit findings: `docs/audit/FINAL-VERDICT.md`

## Priority 1: Fix CI Pipeline (High)

- [ ] Pre-check: Review last CI run logs via `gh run view --log-failed`
- [ ] Investigate: Run `chezmoi init --source=. --no-tty` locally with CI env vars
- [ ] Fix: Address root cause of template-test job failure
- [ ] Verify: Push fix and confirm both jobs pass
- [ ] Rollback trigger: CI still fails after fix -- revert and debug locally

## Priority 2: Fix Documentation (Low effort, High value)

- [ ] Update CLAUDE.md: Change `run_once_install_default_brew_tools.sh.tmpl` to `run_onchange_install_brew_tools.sh.tmpl`
- [ ] Verify: Grep for any other references to the old filename
- [ ] Verify: `chezmoi diff` still clean after doc change

## Priority 3: Fix Age Encryption Config (Medium)

- [ ] Decide: Is age encryption actively used?
- [ ] If yes: Add `recipient` value from secrets data or prompt
- [ ] If no: Remove or comment out the `[age]` section in `.chezmoi.toml.tmpl`
- [ ] Update `docs/06-secrets-management.md` to reflect the decision
- [ ] Verify: `chezmoi doctor` shows no age-related warnings

## Priority 4: Improve CI Coverage (Medium)

- [ ] Add macOS runner to CI matrix
- [ ] Add template variable matrix: test with `default_shell=fish`, `work_machine=true`
- [ ] Consider: Add `workflow_dispatch` trigger for manual CI runs
- [ ] Verify: All matrix combinations pass

## Priority 5: Git Config Conditional Editor (Medium)

- [ ] Make `core.editor` conditional on VS Code availability
- [ ] Make `difftool` and `mergetool` sections conditional
- [ ] Provide fallback editor (vim or nano)
- [ ] Verify: Template renders correctly with and without VS Code

## Priority 6: PowerShell Lint (Low)

- [ ] Add PowerShell lint CI job using PSScriptAnalyzer
- [ ] Or: Document that PowerShell linting is manual-only
- [ ] Verify: PS scripts pass lint if job added

## Priority 7: Supply Chain Hardening (Low)

- [ ] Pin Fisher install URL to a specific commit or release tag
- [ ] Verify: Fisher still installs correctly with pinned URL

## Priority 8: WSL2 Edge Case (Low)

- [ ] Add `test -d ~/Projects` check before `cd ~/Projects` in Fish config
- [ ] Verify: Fish config loads correctly when ~/Projects does not exist

## After All Changes

- [ ] Run `chezmoi diff` -- should show only intended changes
- [ ] Run `chezmoi apply --dry-run` -- should complete without errors
- [ ] Run `scripts/lint.sh` -- should pass
- [ ] Run CI -- all jobs should pass
- [ ] Run `scripts/test-setup.sh` locally -- all tools present
- [ ] Commit with conventional commit messages
