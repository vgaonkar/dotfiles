# setup-tailscale-ssh.ps1
# Sets up Tailscale + SSH to Infinity (Mac) from Windows.
# Run from PowerShell (as Administrator recommended):
#   .\setup-tailscale-ssh.ps1

$InfinityIP = "100.121.147.56"
$InfinityUser = "vijayg"
$InfinityDNS = "infinity.cinnebar-alhena.ts.net"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Tailscale SSH to Infinity — Setup Script  " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Install Tailscale ────────────────────────────────────────────────
Write-Host "[1/6] Checking Tailscale..." -ForegroundColor Yellow

$tsPath = Get-Command tailscale -ErrorAction SilentlyContinue
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
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# ── Step 2: Check Tailscale login ────────────────────────────────────────────
Write-Host ""
Write-Host "[2/6] Checking Tailscale connection..." -ForegroundColor Yellow

$status = & tailscale status 2>&1
if ($LASTEXITCODE -ne 0 -or $status -match "Logged out|NeedsLogin|stopped") {
    Write-Host "  Tailscale is not connected. Opening login..." -ForegroundColor Cyan
    & tailscale up
    Write-Host ""
    Write-Host "  Please sign in with: tech.vrg@gmail.com" -ForegroundColor Yellow
    Write-Host "  Approve the device at: https://login.tailscale.com/admin/machines" -ForegroundColor Yellow
    Read-Host "  Press Enter after you've logged in and approved the device"
}

# Verify connectivity
Write-Host "  Testing connection to Infinity..." -ForegroundColor Cyan
& tailscale ping --c 1 infinity 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  Connected to Infinity!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Cannot reach Infinity. It may be offline." -ForegroundColor Red
    Write-Host "  Continuing setup — you can test later." -ForegroundColor Yellow
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
    ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f $keyFile -N '""'
    Write-Host "  Key generated at $keyFile" -ForegroundColor Green
}

# Copy public key to Infinity
Write-Host ""
Write-Host "  Copying public key to Infinity..." -ForegroundColor Cyan
Write-Host "  You may be prompted for your Mac password (one time only)." -ForegroundColor Yellow
Write-Host ""

$pubKey = Get-Content "$keyFile.pub"
$cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo '$pubKey' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added successfully'"
& ssh -o StrictHostKeyChecking=accept-new -o RequestTTY=auto "${InfinityUser}@${InfinityIP}" $cmd

if ($LASTEXITCODE -eq 0) {
    Write-Host "  SSH key copied to Infinity!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Could not copy key automatically." -ForegroundColor Red
    Write-Host "  Manually run on your Mac:" -ForegroundColor Yellow
    Write-Host "    echo '$pubKey' >> ~/.ssh/authorized_keys" -ForegroundColor White
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
  ServerAliveInterval 30
  ServerAliveCountMax 6
  Compression yes

Host infinity.cinnebar-alhena.ts.net
  HostName $InfinityDNS
  User $InfinityUser
  ServerAliveInterval 30
  ServerAliveCountMax 6
  Compression yes
"@

if (Test-Path $sshConfig) {
    $existing = Get-Content $sshConfig -Raw
    if ($existing -match "Host infinity") {
        Write-Host "  SSH config already has infinity entry — skipping" -ForegroundColor Green
    } else {
        Add-Content -Path $sshConfig -Value $infinityBlock
        Write-Host "  Added infinity to $sshConfig" -ForegroundColor Green
    }
} else {
    Set-Content -Path $sshConfig -Value $infinityBlock.TrimStart()
    Write-Host "  Created $sshConfig with infinity entry" -ForegroundColor Green
}

# ── Step 5: Test SSH connection ──────────────────────────────────────────────
Write-Host ""
Write-Host "[5/6] Testing SSH connection..." -ForegroundColor Yellow

$testResult = & ssh -o ConnectTimeout=5 -o BatchMode=yes infinity "echo SSH_OK" 2>&1
if ($testResult -match "SSH_OK") {
    Write-Host "  SSH to Infinity works!" -ForegroundColor Green
} else {
    Write-Host "  SSH test failed. Output: $testResult" -ForegroundColor Red
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "    1. Ensure Infinity (Mac) is awake and connected to Tailscale" -ForegroundColor White
    Write-Host "    2. Run: tailscale ping infinity" -ForegroundColor White
    Write-Host "    3. Try: ssh -v infinity" -ForegroundColor White
}

# ── Step 6: Configure WezTerm ────────────────────────────────────────────────
Write-Host ""
Write-Host "[6/6] Configuring WezTerm..." -ForegroundColor Yellow

$weztermConfig = "$env:USERPROFILE\.config\wezterm\wezterm.lua"

if (Test-Path $weztermConfig) {
    $content = Get-Content $weztermConfig -Raw

    # Check if launch_menu already exists
    if ($content -match "launch_menu") {
        Write-Host "  WezTerm already has launch_menu — skipping auto-config" -ForegroundColor Yellow
        Write-Host "  Add this entry manually to your launch_menu:" -ForegroundColor Yellow
        Write-Host "    { label = 'Claude Code (Infinity)', args = { 'ssh', 'infinity' } }," -ForegroundColor White
    }
    # Check if infinity keybinding already exists
    elseif ($content -match "infinity") {
        Write-Host "  WezTerm already configured for Infinity — skipping" -ForegroundColor Green
    }
    else {
        # Add launch menu and keybinding before 'return config'
        $additions = @"

-- ── Tailscale: SSH to Infinity (Mac) ────────────────────────────────────────
-- Launch menu: right-click tab bar or Ctrl+Shift+P → "launcher"
config.launch_menu = {
  { label = 'Claude Code (Infinity)', args = { 'ssh', 'infinity' } },
  { label = 'WSL (Ubuntu)',           args = { 'wsl.exe' } },
  { label = 'PowerShell',            args = { 'powershell.exe' } },
}

"@
        $content = $content -replace '(return config)', "$additions`$1"
        Set-Content -Path $weztermConfig -Value $content -NoNewline
        Write-Host "  Added launch menu with Infinity entry to WezTerm config" -ForegroundColor Green
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
Write-Host "    tailscale status      Check all devices" -ForegroundColor White
Write-Host "    tailscale ping infinity   Test connectivity" -ForegroundColor White
Write-Host ""
