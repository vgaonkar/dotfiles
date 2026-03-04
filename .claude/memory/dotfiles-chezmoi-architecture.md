## Chezmoi-Based Dotfiles Management (researched 2026-03-04)

**Applies when:** Multi-machine setups, cross-platform dotfiles, secrets management, bootstrap automation, or machine-specific config variants.

**Rules:**
- Use chezmoi for any 2+ machine setup — only tool with templates + password manager integration + encrypted secrets + Windows support
- Template everything via `.chezmoi.toml.tmpl` with `promptBoolOnce` variables to detect machine type once at init; store in `.chezmoidata/` (gitignored)
- Make all `run_once_` and `run_onchange_` scripts idempotent — hash-based re-execution means non-idempotent scripts are impossible to re-run without `chezmoi state reset`
- Pre-fetch secrets once to `.chezmoidata/secrets.yml` (gitignored) and reference `{{ .secrets.token }}` in templates — avoids repeated password manager prompts
- Use `chezmoi diff` before any `chezmoi apply` — only way to preview changes without applying

**Never:**
- Commit unencrypted or encrypted secrets to git — irreversible exposure if key compromised
- Assume script ordering — `.chezmoiscripts/` may run before files are applied; check for file existence inside scripts
- Make run_once_ scripts non-idempotent — only recovery is `chezmoi state reset` (loses all state)
- Use relative paths in scripts — they run from temp dir, not source repo; use absolute `$HOME`-relative paths

**Default:** Use chezmoi with `.chezmoi.toml.tmpl` prompts for machine-type detection. Template all platform-specific and secret-containing configs. Encrypt secrets via age or 1Password. Never commit secrets.

**Full reference:** `docs/research/dotfiles-chezmoi-architecture.md`
**Review by:** 2026-09-04
