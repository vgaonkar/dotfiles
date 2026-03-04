# Chezmoi-Based Cross-Platform Dotfiles — Research Reference

> **CLAUDE:** Scan `## Quick Reference` to assess relevance (5 seconds). Load `## Deep Reference` only when actively executing work in this domain. **Researched:** 2026-03-04. **Review by:** 2026-09-04.

---

## Quick Reference

**Applies when:** Managing dotfiles across multiple machines or platforms; cross-platform shell/tool configuration; handling secrets in dotfiles; designing idempotent bootstrap workflows; comparing dotfiles management tools; implementing machine-specific configuration variants.

### Decision Rules

| Situation | Action |
|-----------|--------|
| Managing 2+ machines or mixed OS (macOS/Linux/Windows) | Use chezmoi — template-based source-state manager with native secrets support, real-file generation (not symlinks), and password manager integration |
| Need to store machine-specific or secret-containing config | Use `.chezmoi.toml.tmpl` with `promptBoolOnce` / `promptStringOnce` to capture variables once at init, store in `.chezmoidata/` (gitignored), reference in templates via `{{ .variableName }}` |
| Writing one-time bootstrap scripts | Use `run_once_before_` prefix; make scripts idempotent (check before installing); track per content hash, not per machine state |
| Installing packages or tools across multiple machines | Declare in Brewfile (macOS/Linux) or via templates, managed by chezmoi as a `.tmpl` file; use platform-detection templates `{{ if eq .chezmoi.os "darwin" }}` for conditionals |
| Storing secrets (API keys, tokens, SSH keys) | Use chezmoi's native password manager integration (1Password, Bitwarden, age, GPG) OR pre-fetch secrets once to `.chezmoidata/secrets.yml` (gitignored) and reference `{{ .secrets.token }}` in templates |
| Running scripts in containers or ephemeral environments | Use chezmoi's `v2.65+` remote SSH feature or devenv/Devbox for per-project environments; single binary chezmoi ships without system deps |
| Need cross-machine rollback or diff preview | Use `chezmoi diff` (built-in) before `chezmoi apply` — chezmoi shows exact changes, unlike symlink-based managers |

### Hard Constraints

- **Never:** Commit unencrypted secrets or API keys to git, even to private repos — irreversible exposure risk if key is ever compromised
- **Never:** Assume script execution order — scripts in `.chezmoiscripts/` may run before files are applied; check for file existence inside scripts or use `run_after_` prefix
- **Never:** Make `run_once_` scripts non-idempotent — script content hash drives re-execution; if not idempotent, only recourse is `chezmoi state reset` (all state)
- **Always:** Use `chezmoi diff` before `chezmoi apply` on new machines — catch surprises (permissions, missing variables) before applying
- **Always:** Make bootstrap scripts resilient — check if tools exist before installing; detect OS and respond accordingly; fail loudly if prerequisites missing
- **Always:** Test templates in isolation — use `chezmoi execute-template < file.tmpl` to verify variable interpolation before applying

### Default

> Use chezmoi with templates for any multi-machine setup. Detect machine type at `chezmoi init` time via `.chezmoi.toml.tmpl` prompts, store choices in `.chezmoidata/` (gitignored), and template all config files accordingly. Never commit secrets; use age encryption or a password manager backend.

---

## Deep Reference

### Summary

Chezmoi is the industry-standard dotfiles manager for complex, multi-machine setups due to its template system, password manager integration, encrypted secrets support, and cross-platform file handling. It generates real files (not symlinks), provides diffing and rollback capabilities, and runs scripts with tracked state. The core design is a "desired state" model: store canonical dotfiles in `~/.local/share/chezmoi`, compute target state (source + templates + data), and apply minimum changes to bring home directory into that state. This is fundamentally superior to symlink-based tools (GNU Stow, rcm, Homesick) when handling secrets, encrypted files, private-permission files, or machine-specific variants. For simpler setups, bare git or GNU Stow remain viable. For full-system reproducibility (packages + dotfiles), Nix Home Manager is the only full-featured alternative but carries a steep learning curve.

### Key Findings

#### Core Architecture — Source, Target, Destination States

Chezmoi operates on three distinct states:
1. **Source state** — the canonical truth in `~/.local/share/chezmoi` (or a custom source directory)
2. **Target state** — computed desired state: source files + templates evaluated with data
3. **Destination state** — your actual home directory (`~$HOME`)

When you run `chezmoi apply`, chezmoi computes the difference and applies the minimum set of changes. This is fundamentally different from symlink managers, which only create or remove symlinks.

**File naming attributes encode metadata directly into filenames** using strict, ordered prefixes:
- `dot_` → symlink/file starts with dot (hidden)
- `private_` → file permissions 0600
- `executable_` → add execute bit
- `empty_` → create empty file
- `readonly_` → file permissions 0444
- `encrypted_` → encrypt at rest (requires configuration)
- `.tmpl` suffix → file is a Go template

Example: `private_dot_ssh/config.tmpl` becomes `~/.ssh/config` with 0600 permissions, rendered as a template.

**Scripts escape hatch** — use for imperative actions (package installation, system configuration):
- `run_once_` — runs once per unique content hash; state persisted
- `run_onchange_` — runs when rendered content hash differs from last successful run
- `run_before_` / `run_after_` — execution order relative to file updates

**Official documentation**: [chezmoi.io/what-does-chezmoi-do/](https://www.chezmoi.io/what-does-chezmoi-do/), [chezmoi.io/reference/source-state-attributes/](https://www.chezmoi.io/reference/source-state-attributes/)

#### Templating System — Machine-to-Machine Differences Without Branching

Chezmoi uses Go's `text/template` with Sprig extensions. Template variables come from:
1. Built-in `.chezmoi.*` namespace (`os`, `arch`, `hostname`, `username`, `homeDir`)
2. `.chezmoidata.*` files (JSON/YAML/TOML/JSONC) read alphabetically
3. `data` section in `chezmoi.toml` config

**Key pattern: Machine-type detection at init time, not runtime**

Instead of runtime conditionals in templates, capture machine type once:

```toml
# .chezmoi.toml.tmpl
[data]
  {{- $isWork := promptBoolOnce . "isWork" "Work machine?" false }}
  {{- $defaultShell := promptStringOnce . "defaultShell" "Shell (fish/zsh)" "fish" }}

  isWork = {{ $isWork }}
  defaultShell = {{ $defaultShell | quote }}
```

Then all templates reference boolean flags:

```
# dot_zshrc.tmpl
{{ if .isWork -}}
# Work-specific config
{{- end }}
```

This avoids repeated prompts on re-applies and keeps logic centralized.

**`.chezmoitemplates/` for reusable fragments** — define templates once, include in many files:

```
# ~/.local/share/chezmoi/.chezmoitemplates/aliases.tmpl
alias ll='ls -lah'
alias gs='git status'

# dot_bashrc.tmpl
{{ template "aliases.tmpl" . }}
```

**Testing templates**:
```bash
chezmoi data              # inspect all variables
chezmoi execute-template '{{ .chezmoi.os }}'
chezmoi execute-template < ~/.local/share/chezmoi/dot_gitconfig.tmpl
```

**Official documentation**: [chezmoi.io/user-guide/templating/](https://www.chezmoi.io/user-guide/templating/), [chezmoi.io/user-guide/manage-machine-to-machine-differences/](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/)

#### Secrets Handling — The Non-Negotiable Constraint

**Critical constraint**: Secrets management is the sharpest differentiator from symlink-based managers. Chezmoi is the only tool in its class with native password manager integration and whole-file encryption.

**Supported backends** (as of 2025):
1Password, AWS Secrets Manager, Azure Key Vault, Bitwarden, Dashlane, Doppler, gopass, KeePassXC, Keeper, LastPass, pass, passage, Vault, macOS Keychain, GNOME Keyring, age, GPG

**Recommended patterns**:

Pattern A — **Direct password manager integration** (for unencrypted dotfiles repo):
```
# dot_gitconfig.tmpl
[github]
    token = {{ onepasswordRead "op://Personal/github-token/credential" }}
```
Downside: prompts for authentication on each `chezmoi apply`.

Pattern B — **Secrets cache (emerging as 2026 best practice)**:
1. Fetch secrets once to `.chezmoidata/secrets.yml` (gitignored)
2. Reference in templates via `{{ .secrets.token }}`
3. Avoids repeated prompts; separates secret metadata from secret storage

```bash
# Fetch once
op item get github-token --format json > ~/.local/share/chezmoi/.chezmoidata/secrets.json
```

Pattern C — **Whole-file encryption with age**:
```toml
# chezmoi.toml
[age]
    identity = "~/.config/chezmoi/key.txt"
    recipient = "age1ql3z7hjy54pw..."
```

```bash
chezmoi add --encrypt ~/.ssh/id_rsa  # encrypts in source
chezmoi edit ~/.ssh/id_rsa           # transparent decrypt/re-encrypt
```

**Hard constraint**: Never commit unencrypted secrets, and be cautious about encrypted secrets in public repos — key compromise is irreversible.

**Official documentation**: [chezmoi.io/user-guide/password-managers/](https://www.chezmoi.io/user-guide/password-managers/), [chezmoi.io/user-guide/encryption/age/](https://www.chezmoi.io/user-guide/encryption/age/)

#### Scripts and Idempotency — The Escape Hatch

Scripts are Chezmoi's mechanism for imperative actions (package installation, system configuration). The **golden rule: all scripts must be idempotent**.

**Script types**:

| Prefix | Execution | Idempotency requirement |
|--------|-----------|---|
| `run_` | Every apply | Strict idempotent (runs every time) |
| `run_once_` | Once per content hash | Strict idempotent (hash persisted, only re-runs if script content changes) |
| `run_onchange_` | When content hash changes | Strict idempotent (tracks last successful run hash) |

**Key behavior**: script hash is computed *after* template rendering. So a `run_once_before_install.sh.tmpl` that contains conditional Bash code will only re-run if the *rendered* output changes, not if the source `.tmpl` changes.

**Idempotency patterns**:
```bash
#!/bin/bash
# run_once_before_install_homebrew.sh.tmpl

# Check before installing (idempotent)
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Platform-specific tool installs via template
{{- if eq .chezmoi.os "darwin" }}
brew install starship eza bat fzf
{{- else if eq .chezmoi.os "linux" }}
sudo apt-get install -y starship eza bat fzf  # or brew if using Linuxbrew
{{- end }}
```

**Dependency tracking trick** — force re-run when another file changes:
```bash
# run_onchange_install_packages.sh.tmpl
# Packages list: [[ include "dot_Brewfile" | sha256sum ]]

brew bundle install --global
```

If `dot_Brewfile` content changes, its SHA changes, rendered script content changes, hash changes, script re-runs.

**Script limitations**:
- Script execution directory is a temp directory, not the source repo — use absolute paths or `$HOME`-relative paths
- No direct access to other scripts — inline shared logic or `source $HOME/.local/bin/utils.sh` (managed by chezmoi)
- Script ordering can be surprising — `.chezmoiscripts/` processed before some file updates; use `run_after_` or check for file existence

**Official documentation**: [chezmoi.io/user-guide/use-scripts-to-perform-actions/](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/), [chezmoi.io/user-guide/frequently-asked-questions/usage/](https://www.chezmoi.io/user-guide/frequently-asked-questions/usage/)

#### Cross-Platform Strategy — OS Detection and Conditional Logic

Chezmoi natively handles macOS, Linux, Windows, and WSL2. Platform detection uses templates:

```
{{ if eq .chezmoi.os "darwin" }}
  # macOS-specific
{{ else if eq .chezmoi.os "linux" }}
  # Linux-specific
{{ else if eq .chezmoi.os "windows" }}
  # Windows-specific
{{ end }}
```

**Critical gotchas**:
- **Line endings**: Windows Notepad breaks on Unix `\n`. Use chezmoi's `{{ joinPath ... }}` for paths, avoid hardcoded `/home/` on Windows.
- **File permissions**: Windows has no direct concept of 0600. Chezmoi's `private_` prefix is ignored on Windows.
- **Shell differences**: `bash` exists on all platforms but `fish` and `zsh` need platform-specific install. Detect via `{{ if (eq .chezmoi.os "darwin") }}{{ if (lookPath "fish") }}...{{ end }}{{ end }}`.

**Recommended pattern for tool installs**:
```bash
# run_before_01_install_tools.sh.tmpl
{{ if eq .chezmoi.os "darwin" -}}
# Homebrew on macOS
if ! command -v brew &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew install starship zoxide eza bat fzf
{{ else if eq .chezmoi.os "linux" -}}
# Linuxbrew on Linux (if no system package manager installed it)
if ! command -v apt-get &>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
brew install starship zoxide eza bat fzf
{{ end -}}
```

**Tool ecosystem (2025-2026 dominant stack)**:
- **Shell**: Fish (rising), Zsh (stable), Bash (fallback)
- **Prompt**: Starship (near-universal)
- **Plugin manager (Zsh)**: Sheldon (Rust-based, replacing zinit/antigen)
- **Version manager**: Mise (Rust, replacing asdf)
- **Packages (macOS/Linux)**: Homebrew + Brewfile
- **Terminal mux**: Tmux (stable) or Zellij (Rust alternative)
- **Editor**: Neovim (Lua configs tracked by chezmoi) or VSCode settings

#### Chezmoi vs Alternatives — Why Chezmoi Dominates (2024-2025)

Chezmoi is the clear leader among dedicated dotfiles managers:

| Feature | chezmoi | GNU Stow | bare git | YADM | Home Manager |
|---------|---------|----------|----------|------|--------------|
| Templates with custom variables | Yes | No | No | Limited (Jinja) | Yes (Nix) |
| Password manager integration | Yes | No | No | No | No |
| Whole-file encryption | Yes | No | No | Partial | Via plugins |
| Private file permissions (0600) | Yes | No | No | No | N/A |
| Run-once scripts | Yes | No | No | Hooks only | N/A |
| Windows support | Full | No | Partial | No | No |
| Single binary | Yes | No | Yes | No | No |
| Diff before apply | Yes | No | Yes | No | No |
| GitHub Stars | 18,196 | N/A | N/A | 6,179 | 9,415 |

**When to use alternatives**:
- **GNU Stow**: Single machine, one OS, minimal setup, symlink comfort — no secrets, no cross-platform
- **Bare git**: Minimalist, zero dependencies, Git-native; requires discipline to avoid accidental secret commits
- **YADM**: Git-compatible, modest cross-platform via `##os.Linux` alternates; community lost confidence when template deps became unmaintained
- **Home Manager (Nix)**: Bit-for-bit reproducible full-user environment (packages + configs); steep learning curve; NixOS users only

**Community consensus (2024-2025)**: chezmoi is the safe default for any multi-machine setup. Nix Home Manager is the preferred choice for NixOS users willing to invest in the Nix ecosystem. GNU Stow and bare git remain viable for single-machine setups prioritizing simplicity.

#### Emerging Trends and Future Directions (2026)

**Trend 1: Container-aware dotfiles** — Detecting `CODESPACES`, `REMOTE_CONTAINERS`, DevPod environments in `.chezmoi.toml.tmpl` is now standard. Repos bootstrap stripped-down config in containers, full config on workstations.

**Trend 2: Per-project environments over per-machine dotfiles** — devenv.sh, Devbox, Flox provide declarative per-project environments using Nix as the resolver but with a gentle API (TOML/Nix with options). The unit of configuration is shifting from "one machine, one dotfiles repo" to "one project, one dev environment".

**Trend 3: Mise replacing asdf** — Rust-based `mise` reads `.tool-versions`, `.nvmrc`, `.python-version` directly; zero-friction drop-in replacement, faster, adds task running and env var management.

**Trend 4: Nix Flakes + Home Manager stabilization** — Flakes are production-adopted despite "experimental" status. Home Manager is the dominant dotfiles replacement for NixOS users. The Nix ecosystem continues to diverge from other tools but is growing steadily.

**Trend 5: AI assistant configuration as a dotfiles layer** — As of early 2026, a pattern has emerged where developers treat Claude Code/Cursor rule config (`CLAUDE.md`, `.cursorrules`, `~/.claude/`) with the same rigor as shell config. This is versioned in dotfiles and synced across machines.

**Effective obsolescence**: GNU Stow (symlink only, no templating), unencrypted secrets in dotfiles (use age/1Password), manual brew installs (use Brewfile templates), shell-specific config only (use cross-shell), asdf without mise migration (Rust tooling consolidation).

### Trade-offs

| Approach | Best when | Avoid when |
|----------|-----------|-----------|
| Chezmoi | 2+ machines, multiple OSes, secrets needed, cross-platform support required | Single machine with no secrets |
| GNU Stow | Single machine, one OS, symlink comfort, zero dependencies desired | Cross-platform, secrets, machine-specific variants |
| Bare git | Minimalist, Git-native, single machine | Secrets risk (discipline required), no cross-platform help |
| Home Manager (Nix) | NixOS user, full reproducibility needed, packages + dotfiles unified | Non-NixOS users, impatience with learning curve |
| Devenv/Devbox | Per-project reproducibility (not per-machine), Nix unfamiliar but needs declarative, containers | Single-machine simple setups, no package pinning needed |

### Common Mistakes

1. **Inline password manager calls in every template** — causes credential prompts on every apply. **Fix**: Pre-fetch secrets once into `.chezmoidata/secrets.yml` (gitignored), reference `{{ .secrets.token }}` in templates.

2. **Non-idempotent `run_once_` scripts** — script content hash drives re-execution; if not idempotent, only escape hatch is `chezmoi state reset` (all state lost). **Fix**: Always check for existing installations before running. Use `command -v brew &>/dev/null && ...` pattern.

3. **Script ordering assumption violations** — `.chezmoiscripts/` processed before some file updates (issue #1734). Scripts depending on chezmoi-managed files can fail on first run. **Fix**: Use `run_after_` prefix or check for file existence inside script.

4. **Relative path sourcing in scripts** — scripts execute from temp directory, not source repo. `source ../../scripts/utils.sh` breaks silently. **Fix**: Source from absolute `$HOME`-relative path managed by chezmoi (`source $HOME/.local/bin/utils.sh`).

5. **Committing encrypted secrets to public repos** — key compromise is irreversible exposure. **Fix**: Use only external secret stores (1Password, Bitwarden, Vault) or do not commit secrets in any form. If encrypting, use private repos only and rotate keys on any suspected compromise.

6. **Neglecting cross-platform line endings and paths** — Windows Notepad breaks on Unix `\n`, hardcoded `/home/` paths fail on macOS. **Fix**: Use chezmoi's template path functions, test on multiple OSes, use `.chezmoiignore` with platform conditionals.

### Tools & Resources

- **[chezmoi.io](https://www.chezmoi.io/)** — Official documentation, quick start, reference
- **[shunk031/dotfiles](https://github.com/shunk031/dotfiles)** — Production example with Bats testing and CI/CD
- **[abrauner/dotfiles](https://github.com/abrauner/dotfiles)** — Secret-vault-centric example using 1Password
- **[webpro/awesome-dotfiles](https://github.com/webpro/awesome-dotfiles)** — Curated list of tools, articles, and examples
- **[Nathaniel Landau: Managing Dotfiles with Chezmoi](https://natelandau.com/managing-dotfiles-with-chezmoi/)** — In-depth real-world patterns including custom data flags
- **[Homebrew](https://brew.sh/)** — Package manager for macOS/Linux; integrate via Brewfile
- **[Mise](https://mise.jdx.dev/)** — Rust version manager, asdf drop-in replacement
- **[Starship](https://starship.rs/)** — Cross-shell prompt; near-universal in modern dotfiles
- **[devenv.sh](https://devenv.sh/)** — Per-project reproducible environments using Nix
- **[Jetify Devbox](https://www.jetify.com/devbox)** — Simplified per-project Nix environments (alternative to devenv)
- **[NixOS Home Manager](https://github.com/nix-community/home-manager)** — Full-user-environment declarative manager (Nix-only)

### Current State (2026)

**New**: chezmoi v2.65+ remote SSH management (`chezmoi apply --source-path /remote/path` over SSH); `mise` rapid adoption as asdf successor; per-project devenv/Devbox as alternative to per-machine dotfiles; AI assistant configuration as dotfiles layer.

**Stable**: chezmoi remains v2.x with monthly releases; Homebrew + Brewfile as de facto standard for macOS/Linux package declaration; Starship as near-universal shell prompt.

**Declining**: GNU Stow usage in new projects; unencrypted secrets in dotfiles (security discipline enforced); shell-specific config only (cross-shell patterns now expected); asdf without migration path (mise is the clear successor).

**Watch**: Nix Flakes stabilization timeline (RFC 136 enumerates path but no hard deadline); Home Manager adoption in non-NixOS communities (still niche as of early 2026); DevContainer and Codespaces dotfiles integration becoming first-class (official GitHub feature).

### Sources

**Architecture & Design**:
- [What does chezmoi do? — chezmoi.io](https://www.chezmoi.io/what-does-chezmoi-do/)
- [Source State Attributes — chezmoi.io](https://www.chezmoi.io/reference/source-state-attributes/)
- [Configuration File Reference — chezmoi.io](https://www.chezmoi.io/reference/configuration-file/)

**Templating & Cross-Platform**:
- [Templating — chezmoi.io](https://www.chezmoi.io/user-guide/templating/)
- [Manage Machine-to-Machine Differences — chezmoi.io](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/)
- [Cross-Platform Dotfile Management with Dotbot — brianschiller.com](https://brianschiller.com/blog/2024/08/05/cross-platform-dotbot/)

**Secrets & Security**:
- [Password Manager Integration — chezmoi.io](https://www.chezmoi.io/user-guide/password-managers/)
- [Age Encryption — chezmoi.io](https://www.chezmoi.io/user-guide/encryption/age/)
- [Dotfiles Secrets in Chezmoi — mikekasberg.com](https://www.mikekasberg.com/blog/2026/01/31/dotfiles-secrets-in-chezmoi.html)

**Scripts & Workflows**:
- [Use Scripts to Perform Actions — chezmoi.io](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)
- [Testable Dotfiles Management with Chezmoi — shunk031.me](https://shunk031.me/post/testable-dotfiles-management-with-chezmoi/)

**Comparisons & Trends**:
- [Chezmoi Comparison Table — chezmoi.io](https://www.chezmoi.io/comparison-table/)
- [Why Use Chezmoi — chezmoi.io](https://www.chezmoi.io/why-use-chezmoi/)
- [Dotfile Management Tools Battle — biggo.com](https://biggo.com/news/202412191324_dotfile-management-tools-comparison)
- [Migrating from Nix to Homebrew + Chezmoi — htdocs.dev](https://htdocs.dev/posts/migrating-from-nix-and-home-manager-to-homebrew-and-chezmoi/)
- [From Dotfiles to Portable Dev Environments — dakaiser.substack.com](https://dakaiser.substack.com/p/from-dotfiles-to-portable-dev-environments)

**Emerging Patterns**:
- [Dotfiles for Consistent AI-Assisted Development — dylanbochman.com](https://dylanbochman.com/blog/2026-01-25-dotfiles-for-ai-assisted-development/)
- [devenv.sh Official Docs](https://devenv.sh/)
- [Nix Flakes Explained — determinate.systems](https://determinate.systems/blog/nix-flakes-explained/)
- [RFC 136: Incremental Flakes Stabilization — nixos.org](https://github.com/NixOS/rfcs/pull/136)

---

*Researched: 2026-03-04 | Review by: 2026-09-04 | Slug: `dotfiles-chezmoi-architecture`*
