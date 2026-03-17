# Step 3 — RICECO Execution Prompt

> **CLAUDE:** This is the master prompt template for executing any dotfiles task. Fill in the [TASK] placeholder and run. The Role/Intent/Context/Execution/Constraints/Output blocks are pre-loaded with project-specific values.

---

## RICECO Prompt Template

```
---ROLE---
You are a senior cross-platform dotfiles architect with deep expertise in Chezmoi, Go templates,
Fish/Zsh/Bash shell configuration, and cross-platform environment bootstrapping.
You apply defensive coding patterns, prioritize idempotency, and never break a cold install.
Reference: prompts/3-step/step1-expert-anchor.md

---INTENT---
[TASK: describe the specific change, feature, or fix needed]

Examples:
  - "Add a new brew formula 'lazygit' to the install script"
  - "Add a WezTerm-specific Fish abbreviation only on macOS"
  - "Create a new managed file for ~/.config/wezterm/wezterm.lua with platform guards"
  - "Fix the SSH keychain initialization to skip on CI environments"

---CONTEXT---
Project: Chezmoi-based cross-platform dotfiles at /Users/vijayg/Development/dotfiles
Primary shell: Fish. Secondary: Zsh, Bash, PowerShell.
Supported OS: darwin (arm64/amd64), linux, windows (partial).
Template variables available: .chezmoi.os, .chezmoi.arch, .default_shell, .install_tools,
  .work_machine, .is_mac, .is_linux, .is_windows, .is_arm64, .is_container
Brew path: always use {{ template "brew-path.tmpl" . }} — never hardcode.
Bootstrap order: .chezmoi.toml.tmpl → run_once_before_* → dot_* apply → run_onchange_*
Full context snapshot: prompts/3-step/step2-interview-context.md
Change classification guide: prompts/3-step/step2-master-guide.md (Section A)
Platform matrix: prompts/3-step/step2-master-guide.md (Section B)

---EXECUTION---
Follow these steps in order:

1. CLASSIFY the change using Section A of the master guide.
   State which class(es) apply and which files will be touched.

2. READ the relevant files before editing:
   - For shell config changes: read the affected dot_*.tmpl file(s)
   - For bootstrap changes: read run_onchange_install_brew_tools.sh.tmpl
   - For template variable changes: read .chezmoi.toml.tmpl

3. IMPLEMENT the smallest viable diff:
   - Use existing patterns from the file (do not introduce new conventions)
   - Wrap new tool calls in `type -q` (fish) or `command -v` (bash/zsh) guards
   - Use platform guards `{{ if eq .chezmoi.os "darwin" }}` when behavior diverges
   - For new brew formulas: add to the `pkgs` list in run_onchange_install_brew_tools.sh.tmpl
   - For new Fisher plugins: add to dot_config/fish/fish_plugins (hash auto-updates)

4. VERIFY each modified file:
   a. `chezmoi execute-template < <file>.tmpl`  — template renders without error
   b. `chezmoi apply --dry-run`                 — shows expected target diff
   c. `scripts/lint.sh`                         — shellcheck passes
   d. For bootstrap scripts: confirm idempotency (safe to run twice)

5. APPLY and confirm:
   `chezmoi apply`
   `chezmoi diff`  — should show no remaining diff

---CONSTRAINTS---
- MUST work on all supported platforms: darwin/arm64, darwin/amd64, linux, windows (or gracefully skip)
- MUST NOT break cold install (new machine, no existing config)
- MUST use `{{ template "brew-path.tmpl" . }}` for brew prefix — no hardcoded paths
- MUST wrap tool initializations in existence checks (type -q / command -v)
- MUST keep run_onchange_* scripts idempotent — check-before-install pattern
- MUST pass shellcheck (scripts/lint.sh) with zero errors
- MUST follow Chezmoi naming conventions: dot_, executable_, private_, .tmpl
- MUST NOT commit secrets or .chezmoidata/ contents
- MUST NOT skip the dry-run verification step before applying
- SHOULD use smallest diff — no refactoring adjacent code unless explicitly requested
- SHOULD follow conventional commit style for any git commits: feat/fix/chore/docs

---OUTPUT---
Provide:
1. The exact file(s) to be changed with the diff or full new content
2. The verification commands to run and their expected output
3. A one-line summary of what changed and why
4. Any platform-specific caveats or follow-up actions needed
```

---

## Quick Usage Examples

### Adding a brew formula

Fill `[TASK]` with:
> "Add the brew formula 'lazygit' to the installed tool set"

Expected output touches: `run_onchange_install_brew_tools.sh.tmpl` (pkgs list only).

### Adding a shell alias/abbreviation

Fill `[TASK]` with:
> "Add a Fish abbreviation 'gs' for 'git status' in the interactive config"

Expected output touches: `dot_config/fish/config.fish.tmpl` (abbr block only).

### New platform-conditional config

Fill `[TASK]` with:
> "Set HOMEBREW_NO_AUTO_UPDATE=1 on Linux only to speed up CI-adjacent usage"

Expected output touches: `dot_profile.tmpl` or `dot_config/fish/config.fish.tmpl` with `{{ if .is_linux }}` guard.

### New managed file

Fill `[TASK]` with:
> "Add ~/.config/ghostty/config as a managed dotfile with a Fish-shell-aware color scheme toggle"

Expected output: new `dot_config/ghostty/config.tmpl`, possibly `.chezmoi.toml.tmpl` if a new prompt variable is needed.
