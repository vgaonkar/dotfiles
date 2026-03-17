# Security Audit: setup-tailscale-ssh.ps1

> **Audited:** 2026-03-17 | **File:** `windows/scripts/setup-tailscale-ssh.ps1` | **Agent:** security-reviewer (opus)

---

## Quick Reference

**Risk Level:** HIGH
**Critical Issues:** 1
**High Issues:** 3
**Medium Issues:** 4
**Low Issues:** 3

---

## Critical Issues (Fix Immediately)

### 1. Command Injection via SSH Public Key Content

**Severity:** CRITICAL
**Category:** A03 Injection (CWE-78: OS Command Injection)
**Location:** `setup-tailscale-ssh.ps1:84`
**Exploitability:** Local -- requires attacker to control or modify the public key file before the script runs
**Blast Radius:** Arbitrary command execution as the target user (`vijayg`) on the remote Mac host

**Issue:**
The public key content is interpolated directly into a shell command string using single quotes:

```powershell
$pubKey = Get-Content "$keyFile.pub"
$cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added successfully'"
& ssh ... "${InfinityUser}@${InfinityIP}" $cmd
```

If the public key file contains a single quote (or is replaced by a malicious file containing shell metacharacters), the single-quote boundary in the `echo` command is broken, enabling arbitrary command execution on the remote host. An SSH public key comment field is user-controlled (line 73 uses `$env:COMPUTERNAME` which could theoretically contain special characters, though typical hostnames are alphanumeric). More critically, if an attacker replaces the `.pub` file before this script runs (TOCTOU -- see Finding 8), they can inject arbitrary commands.

**Remediation:**

```powershell
# BAD -- string interpolation into shell command
$cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && ..."

# GOOD -- pipe the key content via stdin to avoid shell interpretation entirely
$pubKey = Get-Content "$keyFile.pub"
$pubKey | & ssh -o StrictHostKeyChecking=accept-new -o RequestTTY=no "${InfinityUser}@${InfinityIP}" `
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added successfully'"
```

This pipes the key through stdin to `cat`, eliminating any shell metacharacter interpretation of the key content.

---

## High Issues

### 2. SSH Passphrase Set to Empty String -- Private Key Unprotected

**Severity:** HIGH
**Category:** A02 Cryptographic Failures (CWE-311: Missing Encryption of Sensitive Data)
**Location:** `setup-tailscale-ssh.ps1:73`
**Exploitability:** Local -- anyone with file system access to the Windows machine can read the private key
**Blast Radius:** Unauthorized SSH access to the remote Mac host as `vijayg`

**Issue:**

```powershell
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N '""'
```

The `-N '""'` flag sets an empty passphrase. On Windows/PowerShell, this is interpreted as a literal empty string (or possibly double-quote characters depending on shell escaping). Either way, the intent is clearly to generate a key with no passphrase protection. If the Windows machine is compromised, the private key can be used immediately without any additional secret.

Additionally, the quoting is incorrect for PowerShell. In PowerShell, `-N '""'` passes the literal string `""` (two quote characters) as the passphrase, which is non-empty but trivially guessable and will cause confusion when the user tries to use the key. The correct PowerShell syntax for an empty passphrase would be `-N ""` or `-N ''`.

**Remediation:**

```powershell
# BAD -- empty passphrase, key is unprotected at rest
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N '""'

# GOOD -- prompt user for passphrase (interactive, most secure)
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile

# ACCEPTABLE -- empty passphrase with clear intent (if automation requires it)
# Document the risk and ensure Windows disk encryption (BitLocker) is enabled
ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N ""
Write-Host "  WARNING: Key generated without passphrase. Ensure BitLocker is enabled." -ForegroundColor Yellow
```

### 3. Hardcoded Personal Email Address Exposed in Source Control

**Severity:** HIGH
**Category:** A02 Cryptographic Failures / Sensitive Data Exposure (CWE-200: Exposure of Sensitive Information)
**Location:** `setup-tailscale-ssh.ps1:43`
**Exploitability:** Public -- anyone with access to the repository
**Blast Radius:** Phishing target, social engineering, account enumeration at Tailscale

**Issue:**

```powershell
Write-Host "  Please sign in with: tech.vrg@gmail.com" -ForegroundColor Yellow
```

The personal email address associated with the Tailscale account is hardcoded in a file that is checked into version control. This is a public dotfiles repository, meaning this email is exposed to anyone.

**Remediation:**

```powershell
# BAD -- hardcoded email in source
Write-Host "  Please sign in with: tech.vrg@gmail.com"

# GOOD -- generic instruction without exposing the email
Write-Host "  Please sign in with your Tailscale account email." -ForegroundColor Yellow
Write-Host "  Check your password manager for the correct credentials." -ForegroundColor Yellow
```

### 4. StrictHostKeyChecking=accept-new Enables First-Connection MITM

**Severity:** HIGH
**Category:** A07 Identification and Authentication Failures (CWE-295: Improper Certificate Validation)
**Location:** `setup-tailscale-ssh.ps1:85`
**Exploitability:** Network-adjacent -- requires attacker to be on the Tailscale network or to have compromised DNS at the moment of first connection
**Blast Radius:** Full MITM of the SSH session; attacker intercepts the public key being deployed and can capture the password prompt

**Issue:**

```powershell
& ssh -o StrictHostKeyChecking=accept-new -o RequestTTY=auto "${InfinityUser}@${InfinityIP}" $cmd
```

`StrictHostKeyChecking=accept-new` automatically accepts the host key on first connection without verification. If an attacker can impersonate the target IP during this initial connection (e.g., ARP poisoning on Tailscale subnet, compromised Tailscale relay, or DNS spoofing of the `.ts.net` domain), they can perform a full MITM attack. The user is prompted for their Mac password during this step (line 80), meaning the password would be captured by the attacker.

While Tailscale provides WireGuard encryption that significantly mitigates this (traffic is encrypted point-to-point), the risk is not zero -- especially if Tailscale's coordination server or DERP relays are compromised.

**Remediation:**

```powershell
# BAD -- auto-accept unknown host key
& ssh -o StrictHostKeyChecking=accept-new ...

# GOOD -- pin the known host key fingerprint in the script
$knownHostEntry = "100.121.147.56 ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA..."  # Get this from: ssh-keyscan 100.121.147.56
$knownHostsFile = "$sshDir\known_hosts"
if (-not (Select-String -Path $knownHostsFile -Pattern "100.121.147.56" -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content -Path $knownHostsFile -Value $knownHostEntry
}
& ssh -o StrictHostKeyChecking=yes "${InfinityUser}@${InfinityIP}" $cmd

# ALTERNATIVE -- show fingerprint and ask user to verify
Write-Host "  Verify the host key fingerprint matches what is shown on your Mac." -ForegroundColor Yellow
Write-Host "  On your Mac, run: ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub" -ForegroundColor Cyan
& ssh -o StrictHostKeyChecking=ask "${InfinityUser}@${InfinityIP}" $cmd
```

---

## Medium Issues

### 5. Hardcoded Tailscale IP Address and Username

**Severity:** MEDIUM
**Category:** A05 Security Misconfiguration (CWE-798: Use of Hard-coded Credentials)
**Location:** `setup-tailscale-ssh.ps1:6-8`
**Exploitability:** Public -- IP and username visible to anyone with repo access
**Blast Radius:** Network reconnaissance; attacker knows exact Tailscale IP, username, and DNS name of the target machine

**Issue:**

```powershell
$InfinityIP = "100.121.147.56"
$InfinityUser = "vijayg"
$InfinityDNS = "infinity.cinnebar-alhena.ts.net"
```

While Tailscale IPs are within the CGNAT range (100.64.0.0/10) and not publicly routable, exposing these values in a public repo gives an attacker the exact targeting information needed if they gain access to the Tailscale network. The DNS name also reveals the tailnet name (`cinnebar-alhena`).

**Remediation:**

```powershell
# BAD -- hardcoded values in source control
$InfinityIP = "100.121.147.56"

# GOOD -- use chezmoi data or environment variables
$InfinityIP = $env:TAILSCALE_INFINITY_IP
$InfinityUser = $env:TAILSCALE_INFINITY_USER
if (-not $InfinityIP -or -not $InfinityUser) {
    $InfinityIP = Read-Host "Enter Infinity's Tailscale IP"
    $InfinityUser = Read-Host "Enter Infinity's username"
}

# ALTERNATIVE -- resolve dynamically via Tailscale CLI
$InfinityIP = (& tailscale status --json | ConvertFrom-Json).Peer.Values |
    Where-Object { $_.HostName -eq "infinity" } |
    Select-Object -ExpandProperty TailscaleIPs -First 1
```

### 6. SSH Config Missing Security-Hardening Options

**Severity:** MEDIUM
**Category:** A05 Security Misconfiguration (CWE-16: Configuration)
**Location:** `setup-tailscale-ssh.ps1:100-116`
**Exploitability:** Network -- weakens protections for all SSH sessions to this host
**Blast Radius:** Broader attack surface for SSH sessions

**Issue:**

The SSH config block is missing several security-hardening options:

```
Host infinity
  HostName 100.121.147.56
  User vijayg
  ServerAliveInterval 30
  ServerAliveCountMax 6
  Compression yes
```

Missing hardening:
- No `IdentityFile` -- SSH will try all keys, potentially leaking key existence to a rogue server
- No `IdentitiesOnly yes` -- SSH agent may offer unintended keys
- No `ForwardAgent no` -- agent forwarding is not explicitly disabled (default is off, but defense-in-depth)
- No `AddKeysToAgent` directive
- No `PreferredAuthentications` to enforce publickey-only after setup

**Remediation:**

```
Host infinity
  HostName 100.121.147.56
  User vijayg
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  PreferredAuthentications publickey
  ForwardAgent no
  ServerAliveInterval 30
  ServerAliveCountMax 6
  Compression yes
```

### 7. Duplicate Key Append -- No Idempotency Check on authorized_keys

**Severity:** MEDIUM
**Category:** A04 Insecure Design (CWE-405: Asymmetric Resource Consumption)
**Location:** `setup-tailscale-ssh.ps1:84`
**Exploitability:** Local -- running the script multiple times
**Blast Radius:** Bloated `authorized_keys` file; makes audit of authorized keys harder; potential denial of service with many entries

**Issue:**

```powershell
$cmd = "... echo '$pubKey' >> ~/.ssh/authorized_keys ..."
```

The `>>` operator always appends. Running this script multiple times adds duplicate entries to `authorized_keys`. This makes security auditing of authorized keys more difficult and can bloat the file.

**Remediation:**

```powershell
# BAD -- always appends
$cmd = "echo '$pubKey' >> ~/.ssh/authorized_keys"

# GOOD -- check before appending (using stdin approach from Finding 1)
$pubKey | & ssh ... "${InfinityUser}@${InfinityIP}" `
    "mkdir -p ~/.ssh && chmod 700 ~/.ssh && KEY=`$(cat) && grep -qF `"`$KEY`" ~/.ssh/authorized_keys 2>/dev/null || echo `"`$KEY`" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key configured successfully'"
```

### 8. WezTerm Config Regex Replacement Could Corrupt File

**Severity:** MEDIUM
**Category:** A04 Insecure Design (CWE-94: Improper Control of Generation of Code)
**Location:** `setup-tailscale-ssh.ps1:178`
**Exploitability:** Local -- requires specific WezTerm config content
**Blast Radius:** Corrupted WezTerm configuration; potential Lua code injection if combined with other config sources

**Issue:**

```powershell
$content = $content -replace '(return config)', "$additions`$1"
```

This regex replacement operates on the raw Lua source. If `return config` appears in a string literal or comment in the WezTerm config, the replacement would inject Lua code at the wrong location, potentially breaking the config or creating unexpected behavior. The `$additions` variable contains Lua code that is injected verbatim.

While not directly exploitable for remote code execution (the injected Lua is static and controlled by the script), this pattern is fragile and could corrupt the user's WezTerm configuration.

**Remediation:**

```powershell
# BAD -- regex on source code
$content = $content -replace '(return config)', "$additions`$1"

# GOOD -- append before the last 'return config' using line-based approach
$lines = Get-Content $weztermConfig
$insertIndex = -1
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    if ($lines[$i] -match '^\s*return config\s*$') {
        $insertIndex = $i
        break
    }
}
if ($insertIndex -ge 0) {
    $newLines = $lines[0..($insertIndex-1)] + $additions.Split("`n") + $lines[$insertIndex..($lines.Count-1)]
    Set-Content -Path $weztermConfig -Value $newLines
}
```

---

## Low Issues

### 9. No .ssh Directory Permission Enforcement on Windows

**Severity:** LOW
**Category:** A05 Security Misconfiguration (CWE-276: Incorrect Default Permissions)
**Location:** `setup-tailscale-ssh.ps1:65-67`
**Exploitability:** Local -- other users on the same Windows machine
**Blast Radius:** Private key exposure to other local users

**Issue:**

```powershell
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
}
```

On Windows, `New-Item` creates directories with inherited ACLs. The `.ssh` directory and key files may be readable by other users on the system. Unlike Unix where `ssh-keygen` sets `0600` on the private key, Windows requires explicit ACL configuration.

**Remediation:**

```powershell
# After creating the directory, restrict ACLs
if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
    $acl = Get-Acl $sshDir
    $acl.SetAccessRuleProtection($true, $false)  # Disable inheritance
    $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($rule)
    Set-Acl $sshDir $acl
}
```

### 10. SSH Config File Created Without Restricted Permissions

**Severity:** LOW
**Category:** A05 Security Misconfiguration (CWE-276: Incorrect Default Permissions)
**Location:** `setup-tailscale-ssh.ps1:123-128`
**Exploitability:** Local
**Blast Radius:** SSH configuration visible to other local users; reveals target hosts and usernames

**Issue:**

Both `Add-Content` and `Set-Content` create/modify files with default (inherited) Windows permissions. The SSH config file reveals target hostnames, IPs, and usernames, which should be restricted to the current user.

**Remediation:** Apply the same ACL restriction as recommended in Finding 9 to the SSH config file after creation.

### 11. Error Output May Leak Connection Details

**Severity:** LOW
**Category:** A09 Security Logging and Monitoring Failures (CWE-209: Generation of Error Message Containing Sensitive Information)
**Location:** `setup-tailscale-ssh.ps1:139`
**Exploitability:** Local -- requires viewing console output or logs
**Blast Radius:** Information disclosure of SSH error details

**Issue:**

```powershell
Write-Host "  SSH test failed. Output: $testResult" -ForegroundColor Red
```

SSH error output can contain hostnames, IP addresses, key fingerprints, and configuration details. Dumping the full error output to the console could expose this information in terminal logs, screen recordings, or shared screen sessions.

**Remediation:**

```powershell
# BAD -- dump full SSH error output
Write-Host "  SSH test failed. Output: $testResult"

# GOOD -- generic error with opt-in verbose mode
Write-Host "  SSH test failed. Run 'ssh -v infinity' for details." -ForegroundColor Red
```

---

## OWASP Top 10 Coverage Matrix

| OWASP Category | Applicable | Findings |
|---|---|---|
| A01: Broken Access Control | Yes | #9, #10 (file permissions) |
| A02: Cryptographic Failures | Yes | #2 (empty passphrase), #3 (email exposure) |
| A03: Injection | Yes | #1 (command injection via pubkey) |
| A04: Insecure Design | Yes | #7 (no idempotency), #8 (fragile code injection) |
| A05: Security Misconfiguration | Yes | #5 (hardcoded values), #6 (missing SSH hardening), #9, #10 |
| A06: Vulnerable Components | N/A | No third-party dependencies beyond system tools |
| A07: Auth Failures | Yes | #4 (MITM on first connect) |
| A08: Software/Data Integrity | Partial | WezTerm config modification (#8) |
| A09: Logging Failures | Yes | #11 (verbose error output) |
| A10: SSRF | N/A | No outbound URL fetching from user input |

---

## Security Checklist

- [x] Ed25519 key algorithm used (strong, modern)
- [ ] **FAIL** -- No passphrase on generated SSH key (#2)
- [ ] **FAIL** -- Command injection via public key interpolation (#1)
- [ ] **FAIL** -- Host key not pre-verified, accept-new allows MITM (#4)
- [ ] **FAIL** -- Personal email hardcoded in source (#3)
- [ ] **FAIL** -- SSH config missing IdentityFile, IdentitiesOnly, ForwardAgent directives (#6)
- [ ] **FAIL** -- No idempotency check on authorized_keys (#7)
- [ ] **FAIL** -- Windows file permissions not explicitly set (#9, #10)
- [x] Tailscale provides WireGuard encryption layer (mitigates network-level attacks)
- [x] No secrets or passwords stored in the script
- [x] No use of Invoke-Expression or other dangerous PowerShell patterns
- [x] Script does not require or elevate to Administrator (recommended but not required)

---

## Remediation Priority

| Priority | Finding | Effort |
|---|---|---|
| 1 (Immediate) | #1 Command Injection | Low -- switch to stdin pipe |
| 2 (Urgent) | #4 MITM on first connect | Medium -- pre-pin host key |
| 3 (Urgent) | #2 Empty passphrase | Low -- fix quoting or prompt |
| 4 (This week) | #3 Hardcoded email | Low -- remove from source |
| 5 (This week) | #5 Hardcoded IP/user | Medium -- use env vars or CLI |
| 6 (This week) | #6 SSH config hardening | Low -- add directives |
| 7 (Planned) | #7 Idempotency check | Low -- grep before append |
| 8 (Planned) | #8 WezTerm injection | Medium -- improve insertion logic |
| 9 (Backlog) | #9, #10 File permissions | Medium -- Windows ACL management |
| 10 (Backlog) | #11 Error output | Low -- sanitize output |
