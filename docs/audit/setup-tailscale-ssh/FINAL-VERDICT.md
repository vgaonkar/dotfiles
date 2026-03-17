# Verification Verdict — setup-tailscale-ssh.ps1

> **Audited:** 2026-03-17 | **Target:** dotfiles/windows/scripts/setup-tailscale-ssh.ps1 | **QA Agents:** 3 | **Fix Rounds:** 1

## Overall Verdict: GO (after fixes applied)

## Issues Found and Fixed

| # | Issue | Severity | Fix Applied |
|---|-------|----------|-------------|
| 1 | `ssh-keygen -N '""'` passes literal two-char passphrase | **Critical** | Changed to `-N ""` (correct empty passphrase) |
| 2 | Shell injection via pubkey interpolation into remote command | **Critical** | Pipe key via stdin + `grep -qxF` dedup |
| 3 | Duplicate authorized_keys on re-run | **High** | `grep -qxF` idempotency guard before append |
| 4 | `tailscale ping --c 1` wrong flag | **High** | Changed to `-c 1` with FQDN target |
| 5 | WezTerm regex replaces all `return config` | **High** | `LastIndexOf` targets only final occurrence + backup |
| 6 | SSH config missing security directives | **Medium** | Added `IdentityFile`, `IdentitiesOnly`, `PreferredAuthentications`, `ForwardAgent no` |
| 7 | `Set-Content` writes UTF-16 BOM (breaks OpenSSH on PS5) | **Medium** | `Write-UTF8` helper using `System.IO.File.WriteAllText` |
| 8 | No OpenSSH pre-flight check | **Medium** | `Add-WindowsCapability` fallback for pre-1809 Windows |
| 9 | SSH config idempotency uses substring match | **Medium** | Regex with line anchor `(?m)^Host\s+infinity\s*$` |
| 10 | Hardcoded email in sign-in prompt | **High** | Removed — generic "Sign in with your Tailscale account" |
| 11 | No admin privilege check | **Medium** | `Test-Admin` warns if not elevated |
| 12 | No winget exit code check | **Medium** | Check `$LASTEXITCODE` after winget install |
| 13 | Tailscale not in PATH after install | **High** | Probe known install locations as fallback |
| 14 | No WezTerm backup before modification | **Medium** | Timestamped `.bak` copy before editing |

## Remaining Accepted Risks

| Risk | Severity | Rationale |
|------|----------|-----------|
| `StrictHostKeyChecking=accept-new` on first connect | Low | Mitigated by Tailscale WireGuard encryption; manual fingerprint verification impractical for setup script |
| Hardcoded IP/user/tailnet in script | Low | Personal dotfiles repo; values are not secrets (Tailscale IPs are private network only) |
