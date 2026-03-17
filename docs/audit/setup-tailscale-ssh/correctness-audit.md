# Correctness Audit: setup-tailscale-ssh.ps1

**File**: `windows/scripts/setup-tailscale-ssh.ps1`
**Date**: 2026-03-17
**Auditor**: Code Reviewer (claude-opus-4-6)

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 2     |
| High     | 4     |
| Medium   | 5     |
| Low      | 3     |

**Overall Verdict**: REQUEST CHANGES -- 2 Critical and 4 High issues must be addressed before this script is safe to run on a fresh Windows machine.

---

## Critical

### C1. `ssh-keygen -N '""'` produces a passphrase of two literal quote characters on Windows

**Line**: 73
**Code**: `ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N '""'`

PowerShell single quotes (`'...'`) create literal strings. The value passed to `-N` is the two-character string `""`, not an empty string. On Unix shells, `-N ""` means empty passphrase because the shell strips quotes, but PowerShell passes the content as-is to the native executable. The key will be created with the passphrase `""` (two double-quote characters), meaning every subsequent `ssh` command using this key will fail with "bad passphrase" unless the user types two literal quote characters.

**Fix**: Use an empty string directly:
```powershell
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N ""
```
This passes an empty argument to the native command, which `ssh-keygen` interprets as an empty passphrase. On PowerShell 7.3+ with `$PSNativeCommandArgumentPassing = 'Standard'`, this works correctly. On older PowerShell 5.1 (Windows built-in), you may need:
```powershell
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N "`"`""
```
Or use `--` to stop argument parsing:
```powershell
& ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N '""'
```
The safest cross-version approach is:
```powershell
$emptyPass = '""'
# Actually, the truly safe approach for both PS 5.1 and 7:
cmd /c "ssh-keygen -t ed25519 -C `"$env:COMPUTERNAME`" -f `"$keyFile`" -N `"`""
```
**Recommendation**: Test on the target PowerShell version. For PowerShell 5.1 (the default on Windows), `-N ""` is correct. For PowerShell 7.3+ with `Standard` argument passing, `-N ""` is also correct. The current `-N '""'` is wrong on both.

### C2. Key-copy command injects unsanitized public key into a shell command string via single-quoted interpolation

**Lines**: 83-85
**Code**:
```powershell
$pubKey = Get-Content "$keyFile.pub"
$cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added successfully'"
& ssh ... $cmd
```

Two problems here:

1. **Shell injection**: The public key content is interpolated into a shell command string. While ed25519 public keys typically contain only `ssh-ed25519 AAAA... comment`, if the comment (`$env:COMPUTERNAME`) contains single quotes, backslashes, or shell metacharacters, the remote command will break or execute unintended commands. Computer names with special characters are unlikely but not impossible in enterprise environments.

2. **PowerShell argument passing to native commands**: When you write `& ssh user@host $cmd`, PowerShell passes `$cmd` as a single argument. However, `ssh` on Windows (OpenSSH for Windows) concatenates all non-option arguments into a single remote command string. If `$cmd` contains characters that PowerShell re-quotes when passing to the native process, the remote shell may receive unexpected quoting. This is a well-known pain point with PowerShell-to-native-command argument passing.

3. **Duplicate key entries**: Running the script multiple times appends the same key to `authorized_keys` each time with no deduplication check.

**Fix**:
```powershell
# Read the key
$pubKey = Get-Content "$keyFile.pub" -Raw
$pubKey = $pubKey.Trim()

# Escape single quotes for remote shell
$escapedKey = $pubKey -replace "'", "'\\''"

# Use a deduplication check
$cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qxF '$escapedKey' ~/.ssh/authorized_keys 2>/dev/null || echo '$escapedKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added successfully'"
```
Or better yet, use `ssh-copy-id` if available, or pipe the key via stdin:
```powershell
Get-Content "$keyFile.pub" | ssh "${InfinityUser}@${InfinityIP}" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

---

## High

### H1. `tailscale` may not be in PATH after winget install even after PATH refresh

**Lines**: 29-31
**Code**:
```powershell
winget install --id Tailscale.Tailscale ...
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
```

Tailscale installs as a GUI application with a system service. The `tailscale` CLI is typically located at `C:\Program Files\Tailscale\tailscale.exe`. However, the Tailscale MSI/winget installer does not always add this to the system PATH. The PATH refresh only picks up environment variable changes that the installer wrote; if Tailscale does not modify PATH (which it historically does not on all versions), the refresh has no effect.

Additionally, Tailscale on Windows primarily runs as a Windows service (`tailscale-ipn`). The `tailscale` CLI may require the service to be running, which may need a reboot or manual service start after fresh installation.

**Fix**: After install, explicitly check for the binary and add to PATH if needed:
```powershell
winget install --id Tailscale.Tailscale ...
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Fallback: check known install locations
if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    $knownPaths = @(
        "$env:ProgramFiles\Tailscale",
        "${env:ProgramFiles(x86)}\Tailscale"
    )
    foreach ($p in $knownPaths) {
        if (Test-Path "$p\tailscale.exe") {
            $env:Path += ";$p"
            break
        }
    }
}

if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: tailscale not found in PATH after install. You may need to restart your shell." -ForegroundColor Red
    exit 1
}
```

### H2. `tailscale ping --c 1` uses wrong flag syntax

**Line**: 50
**Code**: `& tailscale ping --c 1 infinity 2>&1 | Out-Null`

The Tailscale CLI uses `--c` which is ambiguous. The correct flag is `--count` or `-c` (single dash for short form). `--c` may work due to prefix matching in some CLI parsers but is not the documented form and could break in future Tailscale versions.

Additionally, the ping target is `infinity` (a hostname), but this is the SSH config alias, not a Tailscale MagicDNS name. Tailscale may not resolve `infinity` -- it would need `infinity.cinnebar-alhena.ts.net` or the Tailscale IP.

**Fix**:
```powershell
& tailscale ping -c 1 $InfinityDNS 2>&1 | Out-Null
```
Or use the IP:
```powershell
& tailscale ping -c 1 $InfinityIP 2>&1 | Out-Null
```

### H3. WezTerm regex replacement is fragile and can corrupt config files

**Lines**: 178-179
**Code**:
```powershell
$content = $content -replace '(return config)', "$additions`$1"
```

Several problems:

1. **Multiple matches**: If `return config` appears more than once in the Lua file (e.g., in a comment, a conditional return, or a string), the replacement inserts the additions block at every occurrence.

2. **Backreference escaping**: The `$1` backreference is escaped with a backtick (`` `$1 ``), which is correct in a double-quoted PowerShell string. However, the `$additions` variable is expanded first, and if its content contains `$` characters, those will be interpreted as regex replacement backreferences, corrupting the output.

3. **No backup**: The original file is overwritten with no backup. If the replacement goes wrong, the user loses their WezTerm config.

**Fix**:
```powershell
# Create backup
Copy-Item $weztermConfig "$weztermConfig.bak"

# Use a more targeted approach -- find the LAST occurrence of 'return config'
$lines = Get-Content $weztermConfig
$insertIdx = -1
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    if ($lines[$i] -match '^\s*return config') {
        $insertIdx = $i
        break
    }
}
if ($insertIdx -ge 0) {
    $before = $lines[0..($insertIdx - 1)]
    $after = $lines[$insertIdx..($lines.Count - 1)]
    $newContent = $before + $additions.Split("`n") + $after
    Set-Content -Path $weztermConfig -Value $newContent
}
```

### H4. No administrator check despite the header recommending it

**Lines**: 3-4
**Code**: `# Run from PowerShell (as Administrator recommended):`

The script header says "as Administrator recommended" but does not check for or enforce elevation. Several operations may fail silently or behave unexpectedly without admin:
- `winget install` for machine-wide packages
- Service management for Tailscale
- `tailscale up` which interacts with the Tailscale service

**Fix**: Add an elevation check at the top:
```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Running without Administrator privileges. Some steps may fail." -ForegroundColor Yellow
    Write-Host "  Re-run with: Start-Process powershell -Verb RunAs -ArgumentList '-File', '$PSCommandPath'" -ForegroundColor Yellow
}
```

---

## Medium

### M1. SSH config "Host infinity" match is too broad

**Lines**: 118-121
**Code**:
```powershell
if ($existing -match "Host infinity") {
    Write-Host "  SSH config already has infinity entry -- skipping"
```

The regex `Host infinity` also matches `Host infinity.cinnebar-alhena.ts.net`, `Host infinity-dev`, `Host infinitypool`, or even a comment like `# Host infinity was removed`. This means:
- If only the DNS entry exists, the IP-based entry will be incorrectly skipped.
- If a comment mentions "Host infinity", the block will be skipped entirely.

**Fix**: Use a more precise pattern:
```powershell
if ($existing -match '(?m)^Host\s+infinity\s*$') {
```

### M2. `Get-Content "$keyFile.pub"` returns an array, not a string

**Line**: 83

`Get-Content` without `-Raw` returns an array of lines. When interpolated into a string in `$cmd`, PowerShell joins them with spaces, which happens to work for single-line public keys. However, if the pub key file somehow contains multiple lines (unlikely but possible with some key types or editors), the command would break.

**Fix**: Use `-Raw` and trim:
```powershell
$pubKey = (Get-Content "$keyFile.pub" -Raw).Trim()
```

### M3. SSH config block has incorrect `HostName` for the DNS entry

**Lines**: 110-111
**Code**:
```powershell
Host infinity.cinnebar-alhena.ts.net
  HostName $InfinityDNS
```

The `Host` directive is the alias you type. The `HostName` directive is what SSH actually connects to. Here, both `Host` and `HostName` are set to the same DNS name (`infinity.cinnebar-alhena.ts.net`). This is technically functional (SSH resolves the HostName via DNS), but it is redundant -- the `Host` line alone without a `HostName` would produce the same behavior. More importantly, it means typing `ssh infinity.cinnebar-alhena.ts.net` matches this block but connects to itself, which is the intended behavior. This is not a bug per se, but it adds an unnecessary config block that provides no value over just using `ssh infinity.cinnebar-alhena.ts.net` directly.

**Fix**: Either remove the duplicate Host block entirely, or if you want the DNS name as an alias, set `HostName` to the IP for failover:
```
Host infinity.ts infinity.cinnebar-alhena.ts.net
  HostName 100.121.147.56
  User vijayg
  ...
```

### M4. Hardcoded personal values reduce reusability

**Lines**: 6-8
```powershell
$InfinityIP = "100.121.147.56"
$InfinityUser = "vijayg"
$InfinityDNS = "infinity.cinnebar-alhena.ts.net"
```

**Line**: 43
```powershell
Write-Host "  Please sign in with: tech.vrg@gmail.com"
```

The Tailscale IP, username, DNS name, and email are hardcoded. This is a personal dotfiles repo so this is expected and not necessarily wrong, but:
- The Tailscale IP (`100.x.x.x`) can change if the device is re-registered.
- The email on line 43 is a personal email embedded in a script that could be shared.

**Fix** (optional): Accept parameters or pull from a config file:
```powershell
param(
    [string]$InfinityIP = "100.121.147.56",
    [string]$InfinityUser = "vijayg",
    [string]$InfinityDNS = "infinity.cinnebar-alhena.ts.net"
)
```

### M5. No `Set-StrictMode` or `$ErrorActionPreference` at script level

The script does not set `$ErrorActionPreference = 'Stop'` or `Set-StrictMode -Version Latest`. This means:
- Cmdlet failures (like `Set-Content` failing due to permissions) are silently swallowed unless explicitly checked.
- Typos in variable names produce `$null` instead of errors.
- Only native commands are checked via `$LASTEXITCODE`, and even then only sometimes.

**Fix**: Add at the top of the script:
```powershell
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
```
Then wrap native command calls in try/catch or check `$LASTEXITCODE` consistently.

---

## Low

### L1. `tailscale up` may block indefinitely on Windows

**Line**: 41

On Windows, `tailscale up` opens the Tailscale GUI login flow in a browser. The CLI command itself may return immediately (before login completes) or may block waiting for authentication. The script then shows a "Press Enter" prompt, but there is no verification that login actually succeeded before proceeding.

**Fix**: After the `Read-Host` prompt, re-check `tailscale status` before proceeding:
```powershell
$status = & tailscale status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Tailscale still not connected. Please complete login and re-run." -ForegroundColor Red
    exit 1
}
```

### L2. Step 5 SSH test uses `BatchMode=yes` which will fail if the key was not copied successfully

**Line**: 135

The `BatchMode=yes` flag disables password prompts. If step 3 failed to copy the key (which the script allows, printing only a warning), step 5 will always fail. This is not inherently wrong -- the test correctly reports the state -- but the error message on line 139 does not mention "key may not have been copied" as a troubleshooting step.

**Fix**: Add to the troubleshooting output:
```powershell
Write-Host "    4. Verify your SSH key was copied (check step 3 output above)" -ForegroundColor White
```

### L3. Script does not handle Ctrl+C gracefully

If the user presses Ctrl+C during the SSH key copy or WezTerm config modification, partially-written files could be left behind. This is a minor concern for a setup script that is run interactively, but worth noting.

**Fix**: No action needed for a personal setup script. For a production tool, wrap file writes in try/finally blocks.

---

## Positive Observations

- **Clear step-by-step structure**: The 6-step organization with numbered headers and color-coded output is excellent for a setup script.
- **Idempotency attempts**: Each step checks for existing state before acting (Tailscale installed? Key exists? SSH config has entry? WezTerm has launch_menu?).
- **Graceful degradation**: When steps fail (e.g., cannot reach Infinity, cannot copy key), the script warns and continues rather than hard-failing, which is appropriate for a setup script.
- **Helpful output**: The final summary with usage commands is a nice touch for discoverability.
- **Consistent style**: Color usage is consistent (Yellow for step headers, Cyan for actions, Green for success, Red for errors).

---

## Idempotency Assessment

| Step | Idempotent? | Notes |
|------|-------------|-------|
| 1. Install Tailscale | Yes | Checks `Get-Command` first |
| 2. Tailscale login | Mostly | Re-checks status, but `tailscale up` on already-connected is a no-op |
| 3. SSH key gen | Partial | Checks for existing key, but key copy appends duplicates (see C2) |
| 4. SSH config | Yes | Checks for existing "Host infinity" before appending |
| 5. SSH test | Yes | Read-only operation |
| 6. WezTerm config | Mostly | Checks for existing entries, but regex replacement could double-insert on edge cases |

---

## Recommendations (Priority Order)

1. **Fix `-N '""'` passphrase issue** (C1) -- keys generated with this will be unusable
2. **Fix key-copy shell injection and duplication** (C2) -- security and idempotency issue
3. **Fix `tailscale ping` flag and target** (H2) -- will fail on fresh setup
4. **Add PATH fallback for Tailscale** (H1) -- script will fail at step 2 on fresh install
5. **Harden WezTerm config replacement** (H3) -- risk of config corruption
6. **Add admin check** (H4) -- prevent confusing failures
7. **Address Medium and Low issues** as time permits
