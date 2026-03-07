# Step 2 — Interview Context (Extracted Project State)

> **CLAUDE:** This is the factual snapshot of the project as of compile time. Treat as ground truth for current architecture. Update after significant structural changes.

---

## Project Identity

- **Name**: dotfiles
- **Manager**: Chezmoi (Go template engine)
- **Install command**: `sh -c "$(curl -fsLS chezmoi.io/get)" -- init --apply vgaonkar`
- **GitHub**: `github.com/vgaonkar/dotfiles`
- **Primary shell**: Fish (recommended default)

---

## Supported Platforms

- macOS (Apple Silicon + Intel) — fully supported
- Linux (Ubuntu, Debian, Fedora, RHEL, Arch) — fully supported
- WSL2 (Ubuntu in WSL2) — fully supported
- Windows native — partial (PowerShell + Scoop, no Homebrew)

---

## Configuration Architecture

### User-Configurable Variables (from `.chezmoi.toml.tmpl`)

| Variable | Type | Default | Env override |
|----------|------|---------|-------------|
| `default_shell` | string | `fish` | `$CHEZMOI_DEFAULT_SHELL` |
| `install_tools` | bool | `true` | `$CHEZMOI_INSTALL_TOOLS` |
| `work_machine` | bool | `false` | `$CHEZMOI_WORK_MACHINE` |

All three use `promptStringOnce` / `promptBoolOnce` — interactive on first run, cached on subsequent runs. CI/container environments skip prompts via env vars.

### Brew Path Abstraction

A shared template partial `brew-path.tmpl` (in `home/` or `.chezmoi.toml.tmpl` context) resolves the correct Homebrew prefix per platform. All scripts and templates reference it as:
```
{{ template "brew-path.tmpl" . }}
```
Never hardcode `/opt/homebrew` or `/home/linuxbrew/.linuxbrew`.

### Change Detection

`run_onchange_install_brew_tools.sh.tmpl` re-executes when the Fisher plugin list changes:
```bash
# Hash: {{ include "dot_config/fish/fish_plugins" | sha256sum }}
```
This is the only dynamic hash line; adding more tracked files requires additional `include` + `sha256sum` in the header comment.

---

## Installed Tool Inventory

### Brew Formulas (installed by `run_onchange_install_brew_tools.sh.tmpl`)

**Shell / prompt**: starship, fish
**Navigation**: zoxide, fzf, fd
**File viewing**: eza, bat
**Dev tools**: git, gh, direnv, atuin, ripgrep, mise
**Data / docs**: jq, pandoc, git-delta
**PDF / OCR**: poppler, qpdf, tesseract, ocrmypdf
**System monitoring**: procs, bottom (btm), dust, gping

### Fisher Plugins (from `dot_config/fish/fish_plugins`)

- `jorgebucaran/fisher` — plugin manager
- `PatrickF1/fzf.fish` — fzf integration
- `jethrokuan/z` — zoxide-compatible z
- `nickeb96/puffer-fish` — puffer completion helpers

---

## Shell Config Patterns

### Fish (`dot_config/fish/config.fish.tmpl`)
- PATH: `fish_add_path ~/bin ~/.local/bin ~/.dotnet/tools`
- SSH keychain via `keychain` (if installed)
- Brew init: platform-guarded (`darwin` vs `linux`), checks directory existence on Linux
- Work machine guard: `{{ if .work_machine }}` sets `$WORK_MACHINE`
- Tool inits: all wrapped in `type -q <tool>` guards
- Abbreviations: `ls`→`eza`, `ll`→`eza -al`, `cat`→`bat`, `grep`→color

### Zsh (`dot_zshrc.tmpl`)
- History: 10,000 lines, `share_history`, dedup, ignore-space
- Completion: `compinit`
- Tool aliases: `command -v` guards for bat, eza
- Tool inits: `command -v` guards for zoxide, fzf, direnv, atuin, starship
- Work machine: `{{ if .work_machine }}` sets `$WORK_MACHINE`

### Bash (`dot_bashrc.tmpl`)
- Fallback/compatibility shell
- Sources `dot_profile.tmpl` for shared PATH/env

### POSIX Profile (`dot_profile.tmpl`)
- Shared `PATH` exports
- Common environment variables used by all shells

---

## Bootstrap Lifecycle

```
chezmoi init --apply
  └─► .chezmoi.toml.tmpl          (renders config, runs prompts)
  └─► run_once_before_00_set_default_shell.sh.tmpl  (sets default shell)
  └─► [apply all dot_* files]
  └─► run_onchange_install_brew_tools.sh.tmpl        (installs tools + plugins)
  └─► run_onchange_setup_wezterm.sh.tmpl             (configures WezTerm)
```

Container/CI environments: `is_container=true` causes bootstrap scripts to exit early with a log message (no tool installation).

---

## CI / Quality Gates

- **ShellCheck**: `scripts/lint.sh` lints all `.sh` files — blocks CI on warnings
- **GitHub Actions**: CI workflow runs on push/PR
- **Template validation**: `chezmoi execute-template` per file
- **PSScriptAnalyzer**: `PSScriptAnalyzerSettings.psd1` for PowerShell linting

---

## Known Conventions

- All Chezmoi-managed files follow prefix naming: `dot_`, `executable_`, `private_`, `.tmpl`
- Docs are sequentially numbered: `00-`, `01-`, `02-` ... in `docs/`
- Commits follow conventional commit style: `feat:`, `fix:`, `chore:`, `docs:`
- Secrets stored in `.chezmoidata/` (gitignored) — never committed
- `autoCommit = false`, `autoPush = false` in Chezmoi config — manual git workflow
