<!-- Parent: ../AGENTS.md -->
<!-- Generated: 2026-03-14 | Updated: 2026-03-14 -->

# dotfiles

## Purpose
Cross-platform dotfiles manager built on [Chezmoi](https://www.chezmoi.io/). Provides one-command setup for consistent development environments across macOS, Linux, Windows, and WSL2 with support for Fish (primary), Zsh, Bash, and PowerShell.

## Key Files

| File | Description |
|------|-------------|
| `.chezmoi.toml.tmpl` | Chezmoi configuration with interactive prompts for user preferences (shell, tools, work machine) |
| `.chezmoiignore` | Patterns excluded from Chezmoi management (OS artifacts, IDE files, `windows/`, `home/`) |
| `run_once_before_00_set_default_shell.sh.tmpl` | One-time script to set the user's default shell on first run |
| `run_onchange_install_brew_tools.sh.tmpl` | Installs 20+ CLI tools via Homebrew/Linuxbrew (runs on content change) |
| `run_onchange_setup_wezterm.sh.tmpl` | Installs and configures WezTerm terminal emulator |
| `dot_bashrc.tmpl` | Bash shell configuration (sources `dot_profile.tmpl`, conditionally loads tools) |
| `dot_zshrc.tmpl` | Zsh shell configuration (sources `dot_profile.tmpl`, conditionally loads tools) |
| `dot_bash_profile.tmpl` | Bash login profile (sources `.bashrc`) |
| `dot_zprofile.tmpl` | Zsh login profile (sources `.zshrc`) |
| `dot_profile.tmpl` | POSIX profile with common variables shared across shells |
| `.shellcheckrc` | ShellCheck linter configuration |
| `PSScriptAnalyzerSettings.psd1` | PowerShell script analyzer rules |
| `CLAUDE.md` | AI agent instructions for this repository |
| `README.md` | Project documentation and usage guide |

## Subdirectories

| Directory | Purpose |
|-----------|---------|
| `dot_config/` | XDG-compliant application configs managed by Chezmoi (see `dot_config/AGENTS.md`) |
| `scripts/` | Helper scripts for installation, testing, and linting (see `scripts/AGENTS.md`) |
| `docs/` | User documentation, tool guides, audit reports, and research (see `docs/AGENTS.md`) |
| `windows/` | Windows-specific configs: PowerShell, Windows Terminal, WezTerm installer (see `windows/AGENTS.md`) |
| `site/` | Static showcase website for the dotfiles project (see `site/AGENTS.md`) |
| `screenshots/` | SVG terminal previews and VHS tape definitions (see `screenshots/AGENTS.md`) |
| `prompts/` | AI prompt templates for project planning (see `prompts/AGENTS.md`) |
| `home/` | Legacy/scaffold directory with empty XDG subdirectories (excluded from Chezmoi via `.chezmoiignore`) |
| `.chezmoitemplates/` | Reusable Go template partials (e.g., `brew-path.tmpl` for Homebrew path detection) |
| `.chezmoidata/` | Secrets and sensitive data (gitignored) |
| `.chezmoi.d/` | Chezmoi extensions directory (currently empty) |
| `.github/` | GitHub Actions CI workflows (see `.github/AGENTS.md`) |
| `.claude/` | Claude Code editor settings |

## For AI Agents

### Working In This Directory

- **Chezmoi naming conventions are critical**: `dot_` prefix maps to `.` (hidden files), `executable_` sets +x, `private_` sets 0600, `.tmpl` suffix enables Go template processing. Forgetting these conventions will produce broken configs.
- **Template variables** come from `.chezmoi.toml.tmpl` prompts: `default_shell` (fish/zsh/bash), `install_tools` (bool), `work_machine` (bool). Platform detection via `.chezmoi.os` and `.chezmoi.arch`.
- **Always test templates** before committing: `chezmoi execute-template < file.tmpl`
- **Shell configs share a pattern**: source `dot_profile.tmpl` for common vars, then conditionally load tools only if they exist on the system (use `command -v` / `type -q` guards).
- **CI environment variables** (`CHEZMOI_DEFAULT_SHELL`, `CHEZMOI_INSTALL_TOOLS`, `CHEZMOI_WORK_MACHINE`) bypass interactive prompts.
- **Run scripts** follow Chezmoi naming: `run_once_` (first time only), `run_onchange_` (when content hash changes), `run_once_before_` (before other scripts).

### Testing Requirements

```bash
scripts/test-all.sh          # Full test suite (shellcheck + templates)
scripts/test-shellcheck.sh   # Lint shell scripts with ShellCheck
scripts/test-templates.sh    # Verify all .tmpl files render
scripts/lint.sh              # ShellCheck lint (also used by CI)
chezmoi diff                 # Preview what chezmoi would change
chezmoi apply --dry-run      # Dry run to catch errors
```

### Common Patterns

- **Platform conditionals**: `{{ if eq .chezmoi.os "darwin" }}...{{ end }}`
- **Tool existence guards**: `command -v tool >/dev/null 2>&1 && ...` (bash/zsh) or `type -q tool; and ...` (fish)
- **Brew path detection**: Uses `.chezmoitemplates/brew-path.tmpl` partial for cross-platform Homebrew location
- **Conventional commits**: `feat:`, `fix:`, `chore:`, `docs:` prefixes

## Dependencies

### External

- **Chezmoi** >= 2.x -- dotfile manager (required)
- **Homebrew / Linuxbrew** -- package manager for CLI tool installation
- **ShellCheck** -- shell script linter (CI and local)
- **Go templates** -- Chezmoi's template engine (built-in)

<!-- MANUAL: Any manually added notes below this line are preserved on regeneration -->
