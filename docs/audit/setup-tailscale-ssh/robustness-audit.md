# Robustness Audit: `setup-tailscale-ssh.ps1`

**File audited**: `windows/scripts/setup-tailscale-ssh.ps1`
**Audit date**: 2026-03-17
**Auditor**: test-engineer agent

---

## Executive Summary

The script performs six steps: install Tailscale, verify Tailscale login, generate an SSH key,
copy the key to the Mac, write an SSH config block, and patch WezTerm's Lua config. It handles
the happy path well, but has twelve identifiable failure modes ranging from silent data corruption
(duplicate `authorized_keys` entries on every re-run) to hard crashes (unquoted paths with spaces,
absent `ssh-keygen` on a fresh Windows install). Three findings are HIGH severity and need fixes
before this script is safe to run on arbitrary Windows machines.

---

## Findings

---

### F-01 — Duplicate `authorized_keys` entries on every re-run

**Severity**: HIGH
**Lines**: 83–85

**What happens**: The key-copy command always appends (`>>`). There is no idempotency guard on
the Mac side. Running the script a second time appends the same public key again. Repeat this ten
times and `authorized_keys` has ten identical lines. This is harmless for authentication but
violates least-surprise, inflates the file, and can confuse audit tools.

**Root cause**: The remote shell snippet uses `echo '...' >> ~/.ssh/authorized_keys` with no
deduplication check.

**Fix**: Replace the remote append with an idempotent check:

```powershell
$pubKey = Get-Content "$keyFile.pub"
$cmd = @"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
key='$pubKey'
grep -qxF "$$key" ~/.ssh/authorized_keys 2>/dev/null || echo "$$key" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'Key added successfully'
"@
```

---

### F-02 — `ssh-keygen` passphrase argument is broken on Windows OpenSSH

**Severity**: HIGH
**Line**: 73

**What happens**:

```powershell
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N '""'
```

On Windows OpenSSH (the inbox build, `C:\Windows\System32\OpenSSH\ssh-keygen.exe`), the argument
`'""'` is passed literally as two double-quote characters, not as an empty string. The result is
that `ssh-keygen` either prompts interactively for a passphrase (breaking unattended runs) or
creates a key with the passphrase `""` (two literal quote characters), which then causes every
subsequent `ssh` call to fail with "bad passphrase".

**Root cause**: PowerShell quoting rules differ from bash. `'""'` in PowerShell is the two-char
string `""`. The Windows OpenSSH port does not strip surrounding quotes the way bash does.

**Fix**: Use the `-N ""` form with a direct empty string, or use `-N ''` carefully, or bypass the
issue entirely by passing the passphrase via stdin:

```powershell
# Safest cross-version approach: pass empty passphrase via -N with explicit empty string
& ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f "$keyFile" -N ""
```

If the PowerShell version is 5, use `--% ` (stop-parsing token):

```powershell
ssh-keygen --% -t ed25519 -C %COMPUTERNAME% -f "%USERPROFILE%\.ssh\id_ed25519" -N ""
```

---

### F-03 — Single-quoted public key breaks if the key comment contains a single quote

**Severity**: HIGH
**Lines**: 84, 92

**What happens**: The public key value is embedded inside a remote shell command that uses single
quotes as the string delimiter:

```powershell
$cmd = "... echo '$pubKey' >> ~/.ssh/authorized_keys ..."
```

A public key comment (set to `$env:COMPUTERNAME` on line 73) that contains a single quote — for
example a machine named `vijay's-pc` — causes the remote shell to receive malformed syntax. The
remote `sh` will either error out or execute unintended commands. Although hostnames rarely
contain apostrophes, this is still a shell injection surface.

**Root cause**: The public key is interpolated into a shell string without escaping.

**Fix**: Base64-encode the key for safe transport, or use `ssh-copy-id` (available via Git for
Windows), or write the key via a here-doc with careful escaping:

```powershell
# Option A: use ssh-copy-id if Git for Windows is present
& ssh-copy-id -i "$keyFile.pub" "${InfinityUser}@${InfinityIP}"

# Option B: base64 encode to avoid quoting issues
$b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pubKey))
$cmd = "echo $b64 | base64 -d | (grep -qxF - ~/.ssh/authorized_keys 2>/dev/null || cat >> ~/.ssh/authorized_keys)"
```

---

### F-04 — No SSH client existence check on a fresh Windows install

**Severity**: MEDIUM
**Lines**: 73, 85, 135

**What happens**: The script calls `ssh-keygen` and `ssh` without first verifying they are
available. On Windows 10 versions prior to 1809, and on some Windows Server editions, the
OpenSSH optional feature is not installed. The script will crash with "command not found" errors
mid-run, leaving a partial state (Tailscale installed, SSH key not generated, config not written).

**Root cause**: No pre-flight check for the OpenSSH client feature.

**Fix**: Add a pre-flight check before Step 3:

```powershell
$sshBin = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshBin) {
    Write-Host "  OpenSSH client not found. Installing..." -ForegroundColor Cyan
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}
```

`Add-WindowsCapability` requires elevation, which is already recommended in the script header.

---

### F-05 — `winget` install exit code is not checked

**Severity**: MEDIUM
**Lines**: 29–31

**What happens**: If `winget` fails (no internet, Windows App Installer not present, package
blocked by enterprise policy), the script silently continues. The PATH refresh at line 31 then
runs, `tailscale` is still not found, and Step 2 crashes with a confusing error rather than a
clear "Tailscale installation failed" message.

**Root cause**: `$LASTEXITCODE` is not checked after `winget`.

**Fix**:

```powershell
winget install --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: winget failed (exit $LASTEXITCODE). Install Tailscale manually." -ForegroundColor Red
    Write-Host "  https://tailscale.com/download/windows" -ForegroundColor Yellow
    exit 1
}
```

---

### F-06 — `tailscale up` is called without any flags; may open a browser or block

**Severity**: MEDIUM
**Line**: 41

**What happens**: `tailscale up` with no arguments will attempt to open a browser window for
authentication. In a headless or RDP session this either fails silently or hangs waiting for
browser interaction. The script then drops to a `Read-Host` prompt, so it does not hard-crash,
but the user may see confusing output if `tailscale up` itself returns an error before the prompt.

Additionally, `tailscale up` does not return until authentication completes on some versions, so
in a non-interactive context this is a blocking call with no timeout.

**Fix**: Use `--authkey` for unattended flows, or at minimum print the auth URL and use
`--login-server` appropriately. For interactive use, capture and display the auth URL explicitly:

```powershell
Write-Host "  Run: tailscale up" -ForegroundColor Cyan
Write-Host "  A browser window will open. Sign in with: tech.vrg@gmail.com" -ForegroundColor Yellow
& tailscale up
```

No structural fix changes the interactive nature, but checking `$LASTEXITCODE` after `tailscale up`
and before the `Read-Host` prevents the script from asking the user to "press Enter" when
Tailscale has already fatally errored.

---

### F-07 — SSH config idempotency check is too broad

**Severity**: MEDIUM
**Lines**: 118–129

**What happens**: The duplicate-check regex is `"Host infinity"`. This matches any occurrence of
that string anywhere in the file — including a comment like `# Old Host infinity entry` or a
`HostName infinity.example.com` line. A machine that had a previous, now-wrong `infinity` block
commented out will never get the updated block added.

The inverse problem also exists: if the user has a block named `Host infinitybox` (a different
host), the regex matches and the `infinity` block is silently skipped.

**Root cause**: The regex is a substring match, not a structured SSH config parse.

**Fix**: Use a more precise pattern anchored to a line boundary:

```powershell
if ($existing -match '(?m)^Host\s+infinity\s*$') {
    # exact Host stanza match
}
```

---

### F-08 — WezTerm config regex replace may corrupt the file

**Severity**: MEDIUM
**Lines**: 178–179

**What happens**:

```powershell
$content = $content -replace '(return config)', "$additions`$1"
Set-Content -Path $weztermConfig -Value $content -NoNewline
```

Two problems:

1. If `return config` appears more than once in the Lua file (e.g., inside a comment, a string
   literal, or a local function that also returns config), all occurrences are replaced. The `-replace`
   operator in PowerShell applies globally by default.

2. `$additions` contains Lua code with `--` comments. If `$additions` itself contained a regex
   special character (`.`, `*`, `(`, etc.) it would be misinterpreted — in this case it is safe
   because the additions are hard-coded, but it is a latent fragility.

3. `-NoNewline` removes the trailing newline from the file, which can cause "no newline at end of
   file" warnings in git and some Lua parsers.

**Fix**: Replace only the last occurrence, or use a more specific anchor:

```powershell
# Replace only the final 'return config' (handles multiple occurrences safely)
$lastIdx = $content.LastIndexOf('return config')
if ($lastIdx -ge 0) {
    $content = $content.Substring(0, $lastIdx) + $additions + $content.Substring($lastIdx)
}
Set-Content -Path $weztermConfig -Value $content  # drop -NoNewline to preserve trailing newline
```

---

### F-09 — `tailscale ping --c 1 infinity` — flag is wrong on Windows Tailscale CLI

**Severity**: LOW
**Line**: 50

**What happens**: The Unix `ping` convention `--c` (double-dash count) is not used by the
Tailscale CLI. The Tailscale Windows CLI uses `--count` (not `-c` or `--c`). The actual flag
is `tailscale ping --count 1 <host>`. Using `--c` may be interpreted as an unknown flag,
causing the ping to run indefinitely or error out (though `Out-Null` suppresses all output,
masking the failure).

**Root cause**: Copy from a Unix invocation; the Tailscale CLI flag differs.

**Fix**:

```powershell
& tailscale ping --count 1 infinity 2>&1 | Out-Null
```

Also consider adding a timeout: `tailscale ping --timeout 5s --count 1 infinity`.

---

### F-10 — Spaces in `$env:USERPROFILE` path are not quoted in SSH call

**Severity**: LOW
**Lines**: 85, 135

**What happens**: If the Windows username contains a space (e.g., `C:\Users\Vijay G\.ssh\...`),
the path in `$keyFile` will contain a space. When passed to `ssh -i $keyFile`, PowerShell will
word-split the argument and the SSH client will receive a broken path. This typically manifests as
`No such file or directory` for the identity file.

**Root cause**: Variables that may contain spaces are not surrounded by double-quotes in command
arguments.

**Fix**: Always quote path variables in external process calls:

```powershell
& ssh -o StrictHostKeyChecking=accept-new -o RequestTTY=auto "${InfinityUser}@${InfinityIP}" $cmd
# becomes:
& ssh -i "$keyFile" -o StrictHostKeyChecking=accept-new -o RequestTTY=auto "${InfinityUser}@${InfinityIP}" $cmd
```

More broadly, `$keyFile`, `$sshConfig`, `$sshDir`, and `$weztermConfig` should be quoted in every
external process invocation.

---

### F-11 — PowerShell 5 vs PowerShell 7 encoding difference for `Set-Content`

**Severity**: LOW
**Lines**: 127, 179

**What happens**: In PowerShell 5 (Windows PowerShell, ships with Windows), `Set-Content` writes
files using the system default encoding, which is typically UTF-16 LE with BOM on many Windows
locales. PowerShell 7 defaults to UTF-8 without BOM. The SSH config file and the Lua config file
are both expected to be UTF-8 (or ASCII). A UTF-16 LE SSH config will cause `ssh` to fail to
parse it, producing a confusing "bad configuration file" error.

**Root cause**: `Set-Content` encoding is not specified explicitly.

**Fix**: Always specify `-Encoding UTF8` (PowerShell 5 writes UTF-8 with BOM) or, for truly
portable UTF-8 without BOM, use `[System.IO.File]::WriteAllText`:

```powershell
# Cross-version UTF-8 without BOM:
[System.IO.File]::WriteAllText($sshConfig, $infinityBlock.TrimStart(), [System.Text.Encoding]::UTF8)
[System.IO.File]::WriteAllText($weztermConfig, $content, [System.Text.Encoding]::UTF8)
```

This is particularly important for `~/.ssh/config` — OpenSSH on Windows rejects BOM-prefixed
config files.

---

### F-12 — WSL SSH config is not affected, but the script implies shared usage

**Severity**: LOW / INFORMATIONAL
**Lines**: 99–129, guidance text throughout

**What happens**: The script writes `%USERPROFILE%\.ssh\config` (Windows native path). WSL
instances use their own `~/.ssh/config` under the Linux filesystem. A user who runs SSH from
inside WSL will not benefit from this config at all. The script's closing instructions say
`ssh infinity` without clarifying this is a Windows-native PowerShell command.

There is no data corruption risk, but users who primarily work in WSL may be confused when
`ssh infinity` works in PowerShell but not in their WSL terminal.

**Recommendation**: Add a note in the closing output:

```powershell
Write-Host "  Note: This config applies to Windows native SSH only." -ForegroundColor Yellow
Write-Host "        WSL users: add the same Host block to ~/.ssh/config inside WSL." -ForegroundColor Yellow
```

---

## Summary Table

| ID   | Area                         | Severity | One-line description                                           |
|------|------------------------------|----------|----------------------------------------------------------------|
| F-01 | authorized_keys append       | HIGH     | Duplicate key added on every re-run                           |
| F-02 | ssh-keygen passphrase arg    | HIGH     | `'""'` is a literal 2-char string, not empty passphrase       |
| F-03 | Shell injection via pubkey   | HIGH     | Single-quoted key breaks if hostname has apostrophe            |
| F-04 | No OpenSSH pre-flight check  | MEDIUM   | Script crashes mid-run on Windows without OpenSSH client       |
| F-05 | winget exit code unchecked   | MEDIUM   | Silent continue after failed Tailscale install                 |
| F-06 | `tailscale up` blocks/hangs  | MEDIUM   | No error check; may block in headless/RDP session              |
| F-07 | SSH config regex too broad   | MEDIUM   | `Host infinity` matches comments and prefix names              |
| F-08 | WezTerm regex replace unsafe | MEDIUM   | Replaces all `return config`, removes trailing newline         |
| F-09 | Wrong tailscale ping flag    | LOW      | `--c` is not a valid Tailscale CLI flag; use `--count`         |
| F-10 | Unquoted paths with spaces   | LOW      | Usernames with spaces break SSH `-i` argument                  |
| F-11 | Set-Content encoding         | LOW      | PS5 writes UTF-16 BOM; OpenSSH rejects BOM in ssh config       |
| F-12 | WSL vs native SSH confusion  | INFO     | Config is Windows-only; WSL users need separate ~/.ssh/config  |

---

## Fix Priority Order

1. **F-02** (passphrase arg) — will silently create a broken key on most Windows machines.
2. **F-01** (duplicate authorized_keys) — wrong on every second run.
3. **F-11** (UTF-16 BOM) — will make SSH config unparseable on PS5 systems.
4. **F-03** (shell injection) — low probability but high impact; fix during F-01 refactor.
5. **F-04** (OpenSSH pre-flight) — causes confusing mid-run crash on fresh installs.
6. **F-05** (winget exit code) — silent failure is hard to debug.
7. **F-07** (SSH config regex) — wrong idempotency on unusual but valid configs.
8. **F-08** (WezTerm regex) — can corrupt WezTerm config on edge-case Lua files.
9. **F-06**, **F-09**, **F-10**, **F-12** — low severity; fix in the same pass.
