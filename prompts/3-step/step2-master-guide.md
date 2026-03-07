# Step 2 — Master Guide (Interview / Context Framework)

> **CLAUDE:** Use this guide to scope any dotfiles task. Work through the applicable sections before generating a plan or implementation.

---

## Section A — Change Classification

Before starting, classify the request:

| Class | Examples | Key risk |
|-------|---------|----------|
| **Template logic** | Add new `.tmpl` variable, change platform guard | Breaks render on one OS |
| **Bootstrap script** | Add/remove brew formula, change Fisher plugins | Non-idempotent install, missing `run_onchange` hash |
| **Shell config** | Alias, env var, tool init in fish/zsh/bash | Works on one shell, breaks another |
| **Secrets / permissions** | Add `private_` file, age-encrypted data | Leaks sensitive data if prefix wrong |
| **New managed file** | `chezmoi add`, new `dot_*` file | Chezmoi naming convention mismatch |
| **CI / tooling** | Workflow YAML, `scripts/lint.sh`, ShellCheck rules | CI red, blocks merges |

---

## Section B — Platform Matrix

Always consider all supported targets:

| Platform | OS value | Brew prefix | Shell default | Notes |
|---------|----------|-------------|--------------|-------|
| macOS Apple Silicon | `darwin` / `arm64` | `/opt/homebrew` | fish | Most common dev machine |
| macOS Intel | `darwin` / `amd64` | `/usr/local` | fish | Legacy; still tested |
| Linux (Ubuntu/Fedora/Arch) | `linux` | `/home/linuxbrew/.linuxbrew` | fish | Linuxbrew required |
| WSL2 | `linux` | `/home/linuxbrew/.linuxbrew` | fish | Interop with Windows paths |
| Windows native | `windows` | N/A | PowerShell | Brew scripts skip; Scoop/winget |
| CI / container | any + `$CI`/`$CODESPACES` | varies | non-interactive | `is_container=true` skips installs |

**Brew path template**: always use `{{ template "brew-path.tmpl" . }}` — never hardcode.

---

## Section C — Template Variable Inventory

Available in all `.tmpl` files:

```
.chezmoi.os           darwin | linux | windows
.chezmoi.arch         amd64 | arm64
.chezmoi.hostname     machine hostname string
.chezmoi.homeDir      absolute home path

.default_shell        fish | zsh | bash  (user prompt or $CHEZMOI_DEFAULT_SHELL)
.install_tools        true | false       (user prompt or $CHEZMOI_INSTALL_TOOLS)
.work_machine         true | false       (user prompt or $CHEZMOI_WORK_MACHINE)
.is_mac               bool (derived)
.is_linux             bool (derived)
.is_windows           bool (derived)
.is_arm64             bool (derived)
.is_amd64             bool (derived)
.is_ci                bool (derived from $CI)
.is_container         bool (ci OR codespaces)
```

---

## Section D — Verification Checklist

Run after every change before committing:

```bash
# 1. Template renders without error
chezmoi execute-template < <changed-file>.tmpl

# 2. Dry-run shows expected diff
chezmoi apply --dry-run

# 3. Shell scripts pass linting
scripts/lint.sh                  # runs shellcheck on all .sh files

# 4. Full diff review
chezmoi diff

# 5. Apply to live system
chezmoi apply
```

For bootstrap script changes also verify:
- `run_onchange_*` hash line includes the right `include` source
- Script is idempotent (safe to run twice)
- Container guard at top (`is_container` check)

---

## Section E — Key File Map

| File | Purpose | Change triggers |
|------|---------|----------------|
| `.chezmoi.toml.tmpl` | User prompts + machine data | Adding new user-configurable variable |
| `run_once_before_00_set_default_shell.sh.tmpl` | Sets default shell pre-apply | Shell preference changes |
| `run_onchange_install_brew_tools.sh.tmpl` | Installs brew formulas + Fisher plugins | Tool list changes, plugin list changes |
| `run_onchange_setup_wezterm.sh.tmpl` | WezTerm terminal setup | Terminal config changes |
| `dot_config/fish/config.fish.tmpl` | Fish interactive config | Aliases, tool inits, env vars |
| `dot_zshrc.tmpl` | Zsh interactive config | Same as above for zsh |
| `dot_bashrc.tmpl` | Bash interactive config | Fallback shell config |
| `dot_profile.tmpl` | POSIX login profile | PATH, env vars shared across shells |
| `dot_config/git/config.tmpl` | Git global config | Git identity, delta pager |
| `dot_config/starship.toml` | Starship prompt theme | Prompt appearance (not a template) |
| `dot_config/fish/fish_plugins` | Fisher plugin list | Plugin add/remove (triggers hash change) |
