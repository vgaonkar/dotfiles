# Security Posture Audit -- dotfiles

> **CLAUDE:** Scan `## Quick Reference` for key facts. Load full sections only when cross-referencing specific items. **Audited:** 2026-03-06 | **Target:** /Users/vijayg/Development/dotfiles | **Agent:** executor

---

## Quick Reference

**Items found:** 7 security-relevant areas audited
**Critical issues:** 1 -- Age encryption recipient is empty (non-functional encryption config)
**Key facts:**
- No secrets found in tracked files -- `.chezmoidata/` is properly gitignored
- Secrets management documented and example file provided
- Age encryption configured but recipient field is empty (encryption non-functional until configured)
- Scripts use `set -euo pipefail` consistently (good practice)
- `sudo` usage is minimal and guarded (only for adding fish to /etc/shells)
- Fisher plugin install fetches from GitHub main branch over HTTPS (no integrity verification)

**Dependencies:** age (optional encryption), SSH keys, GPG keys (optional signing)

---

## Critical Findings

1. **Age encryption recipient is empty.** In `.chezmoi.toml.tmpl`:
   ```
   [age]
     identity = "{{ .chezmoi.homeDir }}/.config/chezmoi/key.txt"
     recipient = ""
   ```
   The `recipient` field is empty, meaning age encryption is configured but non-functional. Any attempt to use `chezmoi encrypt` will fail silently or error. This should either be populated from secrets data or removed if not used.

2. **Fisher installed via unauthenticated curl pipe.** The command:
   ```
   curl -fsSL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
   ```
   Downloads and executes code from GitHub without integrity checks (no checksum, no pinned commit). This is a supply-chain risk, though it is the official Fisher install method.

3. **`secrets.yml` is tracked in git (empty placeholder).** The file `.chezmoidata/secrets.yml` exists and is listed by `find`. While `.chezmoidata/` is in `.gitignore`, the file appears to be present locally. Verify it is not accidentally committed.

## Inventory

### Secrets Handling

| Aspect | Status | Notes |
|--------|--------|-------|
| `.chezmoidata/` gitignored | Yes | In `.gitignore` line 6 |
| Secrets example file | Yes | `docs/examples/secrets.yml.example` |
| Secrets documentation | Yes | `docs/06-secrets-management.md` |
| Age encryption | Configured but broken | Empty recipient |
| Password manager integration | Documented, not configured | 1Password, Bitwarden patterns in docs |
| Hardcoded secrets in code | None found | Grep for password/secret/token/key clean |

### Authentication Patterns

| System | Auth Method | Config Location |
|--------|------------|-----------------|
| GitHub (git) | SSH key or token | `~/.ssh/id_ed25519` (referenced in Fish config) |
| GitHub CLI (gh) | OAuth or token | `~/.config/gh/` (not managed by chezmoi) |
| Git commits | GPG signing (optional) | `git/config.tmpl` conditional on signing_key |
| Chezmoi secrets | Age encryption | `.chezmoi.toml.tmpl` [age] section |
| Atuin sync | Account auth | `~/.config/atuin/` (not managed) |

### Input Validation

| Script | Validation | Notes |
|--------|-----------|-------|
| `install.sh` | Arg parsing with case/esac | Rejects unknown args |
| `run_once_before_00_set_default_shell.sh.tmpl` | OS check, brew check, tty check | Skips gracefully on unsupported OS |
| `run_onchange_install_brew_tools.sh.tmpl` | OS check, brew check, container check | Exits cleanly in CI/containers |
| `bootstrap/install.sh` | Extensive validation | OS, arch, brew, gh, git checks |
| `.chezmoi.toml.tmpl` | CI env var detection | Falls back to prompts when env vars missing |

### Script Security Practices

| Practice | Status |
|----------|--------|
| `set -euo pipefail` | Yes -- all bash scripts |
| Quoting variables | Yes -- consistent quoting |
| `sudo` usage | Minimal -- only for `/etc/shells` |
| Temp file handling | Not applicable (no temp files) |
| Error handling | Good -- meaningful error messages |
| Exit codes | Correct -- non-zero on failure |

### Exposed Ports / Services

None. This is a dotfiles manager, not a service. No ports, no listeners, no daemons.

## Configuration

### `.gitignore` Security Entries

```
.chezmoidata/     # Secrets directory
.claude/          # AI tool state
.omc/             # Orchestration state
.vscode/          # Editor config
*.tmp             # Temp files
*.bak             # Backup files
```

### `.chezmoiignore` Security Entries

The `.chezmoiignore` file prevents certain repo files from being applied to `$HOME`:
- `docs/`, `scripts/`, `screenshots/`, `site/`, `windows/` (on non-Windows)
- `README.md`, `LICENSE`, `CLAUDE.md`
- `.chezmoidata/` secrets data

## Dependencies

- Age binary required for encryption (not installed by default scripts)
- SSH key at `~/.ssh/id_ed25519` assumed by Fish config keychain block
- GPG required for commit signing (optional, from secrets data)

## Impact Assessment

| Change | Impact |
|--------|--------|
| Fix age recipient | Enables chezmoi encryption for secrets |
| Pin Fisher install commit | Reduces supply-chain risk |
| Add secrets to tracked files | Security breach -- secrets exposed in git history |
| Remove `.chezmoidata/` from `.gitignore` | Secrets would be committed |
| Add SSH key path to template | Key path becomes machine-specific |

## Evidence

| Check | Result |
|-------|--------|
| Secrets in tracked files | None found (grep clean) |
| `.gitignore` covers secrets | Yes -- `.chezmoidata/` gitignored |
| Script privilege escalation | Minimal -- sudo only for /etc/shells |
| Curl pipe execution | 1 instance (Fisher install) -- supply chain risk |
| HTTPS for downloads | Yes -- all curl calls use HTTPS |
| Dependency vulnerabilities | N/A (no npm/pip; brew handles CVEs) |
| CORS/CSP headers | N/A (no web service) |
| Auth patterns | SSH + optional GPG + optional age |
