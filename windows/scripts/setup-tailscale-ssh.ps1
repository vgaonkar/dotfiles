# setup-tailscale-ssh.ps1
# Sets up Tailscale + SSH to Infinity (Mac) from Windows.
# Run from PowerShell (Administrator recommended for winget):
#   .\setup-tailscale-ssh.ps1
#
# Safe to re-run — all steps are idempotent.

$ErrorActionPreference = "Stop"

$InfinityIP   = "100.121.147.56"
$InfinityUser = "vijayg"
$InfinityDNS  = "infinity.cinnebar-alhena.ts.net"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-UTF8 {
    param([string]$Path, [string]$Content)
    # Avoid UTF-16 BOM that PowerShell 5 Set-Content writes — OpenSSH rejects BOM
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ── Pre-flight checks ────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Tailscale SSH to Infinity - Setup Script  " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Admin)) {
    Write-Host "  NOTE: Running without admin. Winget install may fail." -ForegroundColor Yellow
    Write-Host "  Re-run as Administrator if Step 1 fails." -ForegroundColor Yellow
    Write-Host ""
}

# Check OpenSSH client is available
$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshCmd) {
    Write-Host "  OpenSSH client not found. Attempting to install..." -ForegroundColor Yellow
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
        Write-Host "  OpenSSH client installed." -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Cannot install OpenSSH client. Install manually:" -ForegroundColor Red
        Write-Host "  Settings > Apps > Optional Features > OpenSSH Client" -ForegroundColor White
        exit 1
    }
}

# ── Step 1: Install Tailscale ────────────────────────────────────────────────
Write-Host "[1/6] Checking Tailscale..." -ForegroundColor Yellow

$tsPath = Get-Command tailscale -ErrorAction SilentlyContinue
if (-not $tsPath) {
    # Check known install locations before giving up
    $knownPaths = @(
        "${env:ProgramFiles}\Tailscale\tailscale.exe",
        "${env:ProgramFiles(x86)}\Tailscale\tailscale.exe",
        "${env:LOCALAPPDATA}\Tailscale\tailscale.exe"
    )
    foreach ($p in $knownPaths) {
        if (Test-Path $p) {
            $env:Path += ";$(Split-Path $p)"
            $tsPath = Get-Command tailscale -ErrorAction SilentlyContinue
            break
        }
    }
}

if ($tsPath) {
    Write-Host "  Tailscale already installed at $($tsPath.Source)" -ForegroundColor Green
} else {
    $response = Read-Host "  Tailscale not found. Install via winget? [Y/n]"
    if ($response -match '^[Nn]') {
        Write-Host "  Skipping. Install manually from https://tailscale.com/download/windows" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Installing Tailscale..." -ForegroundColor Cyan
    winget install --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Tailscale installation failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "  Install manually from https://tailscale.com/download/windows" -ForegroundColor Yellow
        exit 1
    }
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Verify tailscale is now available
    $tsPath = Get-Command tailscale -ErrorAction SilentlyContinue
    if (-not $tsPath) {
        Write-Host "  WARNING: Tailscale installed but not in PATH. You may need to restart your terminal." -ForegroundColor Yellow
    }
}

# ── Step 2: Check Tailscale login ────────────────────────────────────────────
Write-Host ""
Write-Host "[2/6] Checking Tailscale connection..." -ForegroundColor Yellow

$status = & tailscale status 2>&1
if ($LASTEXITCODE -ne 0 -or $status -match "Logged out|NeedsLogin|stopped") {
    Write-Host "  Tailscale is not connected. Opening login..." -ForegroundColor Cyan
    & tailscale up
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  WARNING: tailscale up may have failed. Check the system tray." -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "  Sign in with your Tailscale account." -ForegroundColor Yellow
    Write-Host "  Approve the device at: https://login.tailscale.com/admin/machines" -ForegroundColor Yellow
    Read-Host "  Press Enter after you've logged in and approved the device"
}

# Verify connectivity
Write-Host "  Testing connection to Infinity..." -ForegroundColor Cyan
& tailscale ping -c 1 $InfinityDNS 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Connected to Infinity!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Cannot reach Infinity. It may be offline." -ForegroundColor Red
    Write-Host "  Continuing setup - you can test later." -ForegroundColor Yellow
}

# ── Step 3: Generate SSH key ─────────────────────────────────────────────────
Write-Host ""
Write-Host "[3/6] Setting up SSH key..." -ForegroundColor Yellow

$sshDir = "$env:USERPROFILE\.ssh"
$keyFile = "$sshDir\id_ed25519"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
}

if (Test-Path "$keyFile.pub") {
    Write-Host "  SSH key already exists at $keyFile" -ForegroundColor Green
} else {
    Write-Host "  Generating new SSH key..." -ForegroundColor Cyan
    # Use empty string for passphrase — double quotes in PS pass empty string correctly
    ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f "$keyFile" -N ""
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: ssh-keygen failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Key generated at $keyFile" -ForegroundColor Green
}

# Copy public key to Infinity (idempotent — checks for duplicates)
Write-Host ""
Write-Host "  Copying public key to Infinity..." -ForegroundColor Cyan
Write-Host "  You may be prompted for your Mac password (one time only)." -ForegroundColor Yellow
Write-Host ""

# Pipe key via stdin to avoid shell injection — never interpolate key into command string
$pubKeyContent = Get-Content "$keyFile.pub" -Raw
$remoteCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && key=`$(cat) && grep -qxF `"`$key`" ~/.ssh/authorized_keys 2>/dev/null || echo `"`$key`" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key configured successfully'"
$pubKeyContent | & ssh -o StrictHostKeyChecking=accept-new "${InfinityUser}@${InfinityIP}" $remoteCmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "  SSH key deployed to Infinity!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Could not copy key automatically." -ForegroundColor Red
    Write-Host "  Manually copy contents of $keyFile.pub to ~/.ssh/authorized_keys on your Mac." -ForegroundColor Yellow
}

# ── Step 4: Create SSH config ────────────────────────────────────────────────
Write-Host ""
Write-Host "[4/6] Configuring SSH..." -ForegroundColor Yellow

$sshConfig = "$sshDir\config"
$infinityBlock = @"

# --- Tailscale: Remote Claude Code on Infinity (Mac) ---
Host infinity
  HostName $InfinityIP
  User $InfinityUser
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  PreferredAuthentications publickey
  ForwardAgent no
  ServerAliveInterval 30
  ServerAliveCountMax 6
  Compression yes

Host $InfinityDNS
  HostName $InfinityDNS
  User $InfinityUser
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
  PreferredAuthentications publickey
  ForwardAgent no
  ServerAliveInterval 30
  ServerAliveCountMax 6
  Compression yes
"@

if (Test-Path $sshConfig) {
    $existing = Get-Content $sshConfig -Raw
    # Use regex with line anchor to avoid substring false matches
    if ($existing -match '(?m)^Host\s+infinity\s*$') {
        Write-Host "  SSH config already has infinity entry - skipping" -ForegroundColor Green
    } else {
        # Append using UTF-8 without BOM
        $newContent = $existing.TrimEnd() + "`n" + $infinityBlock + "`n"
        Write-UTF8 -Path $sshConfig -Content $newContent
        Write-Host "  Added infinity to $sshConfig" -ForegroundColor Green
    }
} else {
    Write-UTF8 -Path $sshConfig -Content ($infinityBlock.TrimStart() + "`n")
    Write-Host "  Created $sshConfig with infinity entry" -ForegroundColor Green
}

# ── Step 5: Test SSH connection ──────────────────────────────────────────────
Write-Host ""
Write-Host "[5/6] Testing SSH connection..." -ForegroundColor Yellow

$testResult = & ssh -o ConnectTimeout=5 -o BatchMode=yes infinity "echo SSH_OK" 2>&1
if ("$testResult" -match "SSH_OK") {
    Write-Host "  SSH to Infinity works!" -ForegroundColor Green
} else {
    Write-Host "  SSH test failed." -ForegroundColor Red
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "    1. Ensure Infinity (Mac) is awake and connected to Tailscale" -ForegroundColor White
    Write-Host "    2. Run: tailscale ping $InfinityDNS" -ForegroundColor White
    Write-Host "    3. Run: ssh -v infinity" -ForegroundColor White
}

# ── Step 6: Configure WezTerm ────────────────────────────────────────────────
Write-Host ""
Write-Host "[6/6] Configuring WezTerm..." -ForegroundColor Yellow

$weztermConfig = "$env:USERPROFILE\.config\wezterm\wezterm.lua"

if (Test-Path $weztermConfig) {
    $content = Get-Content $weztermConfig -Raw

    if ($content -match "launch_menu") {
        Write-Host "  WezTerm already has launch_menu - skipping auto-config" -ForegroundColor Yellow
        Write-Host "  Add this entry manually to your launch_menu:" -ForegroundColor Yellow
        Write-Host "    { label = 'Claude Code (Infinity)', args = { 'ssh', 'infinity' } }," -ForegroundColor White
    }
    elseif ($content -match "Claude Code.*Infinity") {
        Write-Host "  WezTerm already configured for Infinity - skipping" -ForegroundColor Green
    }
    else {
        # Back up config before modifying
        $backupPath = "$weztermConfig.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $weztermConfig $backupPath
        Write-Host "  Backed up WezTerm config to $backupPath" -ForegroundColor Cyan

        $additions = @"

-- Tailscale: SSH to Infinity (Mac)
-- Launch menu: right-click tab bar or Ctrl+Shift+P then "launcher"
config.launch_menu = {
  { label = 'Claude Code (Infinity)', args = { 'ssh', 'infinity' } },
  { label = 'WSL (Ubuntu)',           args = { 'wsl.exe' } },
  { label = 'PowerShell',            args = { 'powershell.exe' } },
}

"@
        # Replace only the LAST occurrence of 'return config'
        $lastIdx = $content.LastIndexOf('return config')
        if ($lastIdx -ge 0) {
            $newContent = $content.Substring(0, $lastIdx) + $additions + $content.Substring($lastIdx)
            Write-UTF8 -Path $weztermConfig -Content $newContent
            Write-Host "  Added launch menu with Infinity entry to WezTerm config" -ForegroundColor Green
        } else {
            Write-Host "  WARNING: Could not find 'return config' in wezterm.lua" -ForegroundColor Yellow
            Write-Host "  Add the launch_menu manually (see guide)." -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  WezTerm config not found at $weztermConfig" -ForegroundColor Yellow
    Write-Host "  Run chezmoi apply in WSL first, or run install-wezterm.ps1" -ForegroundColor Yellow
}

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup Complete!                           " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Usage:" -ForegroundColor Cyan
Write-Host "    ssh infinity          Connect to Mac (plain shell)" -ForegroundColor White
Write-Host "    ssh -t infinity       Connect + auto-attach tmux" -ForegroundColor White
Write-Host ""
Write-Host "  WezTerm:" -ForegroundColor Cyan
Write-Host "    Launch menu entry:    'Claude Code (Infinity)'" -ForegroundColor White
Write-Host "    Or just type:         ssh infinity" -ForegroundColor White
Write-Host ""
Write-Host "  Tailscale:" -ForegroundColor Cyan
Write-Host "    tailscale status           Check all devices" -ForegroundColor White
Write-Host "    tailscale ping $InfinityDNS   Test connectivity" -ForegroundColor White
Write-Host ""
