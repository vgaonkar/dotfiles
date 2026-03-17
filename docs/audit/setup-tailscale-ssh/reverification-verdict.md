# Reverification Verdict — setup-tailscale-ssh.ps1

> **Audited:** 2026-03-17 | **Reviewer:** code-reviewer (opus) | **Against:** FINAL-VERDICT.md (14 fixes) + research findings

## Verdict: CONDITIONAL GO

### Previous fixes verified: 14/14

All 14 fixes from the original audit are present and intact in the current script.

| # | Fix | Status | Line(s) |
|---|-----|--------|---------|
| 1 | `ssh-keygen -N ""` correct empty passphrase | Present | 144 |
| 2 | Pipe key via stdin (no shell injection) | Present | 158-161 |
| 3 | `grep -qxF` dedup guard | Present | 160 |
| 4 | `tailscale ping -c 1` correct flag | Present | 120 |
| 5 | `LastIndexOf` for last `return config` | Present | 267 |
| 6 | `IdentitiesOnly`, `PreferredAuthentications`, `ForwardAgent no` | Present | 182-184, 193-195 |
| 7 | `Write-UTF8` helper (no BOM) | Present | 16-20 |
| 8 | OpenSSH pre-flight check | Present | 42-54 |
| 9 | Regex idempotency `(?m)^Host\s+infinity\s*$` | Present | 204 |
| 10 | Removed hardcoded email | Present | 113 |
| 11 | `Test-Admin` privilege check | Present | 22-26, 36-40 |
| 12 | Winget `$LASTEXITCODE` check | Present | 86-89 |
| 13 | Tailscale PATH fallback (known locations) | Present | 61-74 |
| 14 | WezTerm timestamped backup | Present | 251-253 |

### New issues found: 2

---

### Issues

**[MEDIUM] Tailscale command called without verifying it is in PATH**
File: `windows/scripts/setup-tailscale-ssh.ps1:105`

After Tailscale is installed via winget, line 97 emits a WARNING that tailscale may not be in PATH. However, execution continues to line 105 where `& tailscale status 2>&1` is called unconditionally. Because `$ErrorActionPreference = "Stop"` (line 8), if the binary is not found, this throws a terminating error with a cryptic .NET exception rather than a helpful message.

**Fix:** Guard the tailscale calls in Step 2 with a check:

```powershell
$tsCmd = Get-Command tailscale -ErrorAction SilentlyContinue
if (-not $tsCmd) {
    Write-Host "  Tailscale is installed but not in PATH." -ForegroundColor Red
    Write-Host "  Close and reopen PowerShell, then re-run this script." -ForegroundColor Yellow
    exit 1
}
```

Insert this between line 99 (end of Step 1) and line 102 (start of Step 2).

---

**[LOW] WezTerm `LastIndexOf('return config')` matches inside comments or strings**
File: `windows/scripts/setup-tailscale-ssh.ps1:267`

`LastIndexOf` is a plain string search. If the user's `wezterm.lua` contains `return config` inside a Lua comment (`-- return config`) or string literal, the insertion point would be wrong. In practice this is extremely unlikely since `return config` at the end of the file is the universal WezTerm pattern, and `LastIndexOf` already targets the final occurrence.

**Fix (optional):** No action required. Document the assumption with a comment:

```powershell
# Targets the final 'return config' in the file — standard WezTerm config pattern
$lastIdx = $content.LastIndexOf('return config')
```

---

### Research Gap Analysis

| Research Topic | In Script? | Assessment |
|----------------|-----------|------------|
| **mosh install on Windows** | No | **Out of scope** — mosh has no native Windows port; requires WSL. This script targets native PowerShell. If mosh is desired, it belongs in a WSL setup script, not here. |
| **IdentitiesOnly / PreferredAuthentications** | Yes | Both directives present on both Host blocks (lines 182-183, 193-194). Matches research hard constraint about `ForwardAgent no`. |
| **grep -qxF dedup via stdin** | Yes | **Works correctly.** `key=$(cat)` uses bash command substitution which strips trailing newlines from the piped input, so `-qxF` matches the single-line public key exactly. No duplicate risk. |
| **Write-UTF8 for PS5 and PS7** | Yes | **Correct on both.** `[System.Text.UTF8Encoding]::new($false)` is available in .NET Framework 4.x (PS5) and .NET Core (PS7). The `::new()` constructor syntax requires PS5+, which is the minimum target. |
| **WezTerm LastIndexOf** | Yes | **Correct.** Inserts additions immediately before the last `return config`, preserving the return statement. Backup is taken first. |
| **Exit codes** | Partial | Steps 1-3 exit on critical failures. Steps 4-6 warn and continue on non-fatal failures (SSH test, WezTerm config). The one gap is the MEDIUM issue above (Step 2 calling tailscale without PATH verification). |

### Positive Observations

- **Idempotency is thorough**: Every step checks for existing state before acting (SSH key exists, SSH config already has entry, WezTerm already configured). Safe to re-run.
- **Security posture is strong**: `ForwardAgent no`, `IdentitiesOnly yes`, `PreferredAuthentications publickey`, stdin piping for key copy, no secrets in script.
- **UTF-8 handling is correct**: The `Write-UTF8` helper avoids the well-known PS5 BOM issue that breaks OpenSSH config parsing.
- **Error messaging is excellent**: Every failure path gives the user a concrete next step (manual install URL, troubleshooting commands, etc.).
- **The `grep -qxF` + stdin pattern is elegant**: It avoids both shell injection and duplicate keys in a single pipeline.

### Recommendation

**CONDITIONAL GO** — The script is production-ready with one condition:

- **Must fix** the MEDIUM issue (tailscale PATH guard before Step 2) to prevent a confusing terminating error when the user needs to restart their terminal after install.

The LOW issue (WezTerm comment/string edge case) is informational only and does not block deployment.
