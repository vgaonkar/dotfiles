# setup-tailscale-ssh.ps1
# Sets up Tailscale + WezTerm + SSH to Infinity (Mac) from Windows.
# Run from PowerShell (Administrator recommended for winget):
#   .\setup-tailscale-ssh.ps1
#
# Safe to re-run -- all steps are idempotent.

$ErrorActionPreference = "Stop"

$InfinityIP   = "100.121.147.56"
$InfinityUser = "vijayg"
$InfinityDNS  = "infinity.cinnebar-alhena.ts.net"

# -- Helpers ------------------------------------------------------------------

function Write-UTF8 {
    param([string]$Path, [string]$Content)
    # Avoid UTF-16 BOM that PowerShell 5 Set-Content writes -- OpenSSH rejects BOM
    [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($false))
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -- Pre-flight checks --------------------------------------------------------

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

# -- Step 1: Install WezTerm --------------------------------------------------
Write-Host "[1/9] Checking WezTerm..." -ForegroundColor Yellow

$weztermExe = Get-Command wezterm -ErrorAction SilentlyContinue
if (-not $weztermExe) {
    # Check known install locations
    $weztermPaths = @(
        "${env:ProgramFiles}\WezTerm\wezterm.exe",
        "${env:ProgramFiles(x86)}\WezTerm\wezterm.exe",
        "${env:LOCALAPPDATA}\Programs\WezTerm\wezterm.exe"
    )
    foreach ($p in $weztermPaths) {
        if (Test-Path $p) {
            $weztermExe = $p
            break
        }
    }
}

if ($weztermExe) {
    Write-Host "  WezTerm already installed." -ForegroundColor Green
} else {
    $response = Read-Host "  WezTerm not found. Install via winget? [Y/n]"
    if ($response -match '^[Nn]') {
        Write-Host "  Skipping WezTerm. You can install later from https://wezfurlong.org/wezterm/" -ForegroundColor Yellow
    } else {
        Write-Host "  Installing WezTerm..." -ForegroundColor Cyan
        $ErrorActionPreference = "Continue"
        winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARNING: WezTerm install failed. Install manually from https://wezfurlong.org/wezterm/" -ForegroundColor Yellow
        } else {
            Write-Host "  WezTerm installed." -ForegroundColor Green
        }
    }
}

# Install JetBrainsMono Nerd Font (required by wezterm.lua config)
$fontCheck = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\JetBrains*Nerd*" -ErrorAction SilentlyContinue
if (-not $fontCheck) {
    $fontCheck = Get-ChildItem "$env:WINDIR\Fonts\JetBrains*Nerd*" -ErrorAction SilentlyContinue
}
if ($fontCheck) {
    Write-Host "  JetBrainsMono Nerd Font already installed." -ForegroundColor Green
} else {
    Write-Host "  Installing JetBrainsMono Nerd Font (used by WezTerm config)..." -ForegroundColor Cyan
    $fontInstalled = $false
    # Try winget first (cleanest)
    $ErrorActionPreference = "Continue"
    $wingetFont = & winget search "JetBrainsMono" 2>&1
    $ErrorActionPreference = "Stop"
    if ($wingetFont -match "DEVCOM.JetBrainsMonoNerdFont") {
        $ErrorActionPreference = "Continue"
        winget install --id DEVCOM.JetBrainsMonoNerdFont --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -eq 0) { $fontInstalled = $true }
    }
    # Try oh-my-posh font install as fallback
    if (-not $fontInstalled) {
        $ompPath = Get-Command oh-my-posh -ErrorAction SilentlyContinue
        if ($ompPath) {
            $ErrorActionPreference = "Continue"
            & oh-my-posh font install JetBrainsMono 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            if ($LASTEXITCODE -eq 0) { $fontInstalled = $true }
        }
    }
    if ($fontInstalled) {
        Write-Host "  JetBrainsMono Nerd Font installed." -ForegroundColor Green
    } else {
        Write-Host "  WARNING: Could not auto-install font. Download manually:" -ForegroundColor Yellow
        Write-Host "  https://github.com/ryanoasis/nerd-fonts/releases/latest" -ForegroundColor White
        Write-Host "  Search for JetBrainsMono.zip, extract and install .ttf files." -ForegroundColor White
    }
}

# Deploy wezterm.lua from dotfiles (the cross-platform config with Tango Dark theme, etc.)
$weztermConfigDir = "$env:USERPROFILE\.config\wezterm"
if (-not (Test-Path $weztermConfigDir)) {
    New-Item -ItemType Directory -Force -Path $weztermConfigDir | Out-Null
}

$weztermConfig = "$weztermConfigDir\wezterm.lua"
$dotfilesConfig = $null
# Check WSL dotfiles (chezmoi source)
$wslPaths = @(
    "\\wsl.localhost\Ubuntu\home\$InfinityUser\.config\wezterm\wezterm.lua",
    "\\wsl.localhost\Ubuntu\home\dev\.config\wezterm\wezterm.lua"
)
foreach ($p in $wslPaths) {
    if (Test-Path $p) { $dotfilesConfig = $p; break }
}
# Check local dotfiles clone
if (-not $dotfilesConfig) {
    $localPaths = @(
        "$env:USERPROFILE\dotfiles\dot_config\wezterm\wezterm.lua",
        "$env:USERPROFILE\Development\dotfiles\dot_config\wezterm\wezterm.lua"
    )
    foreach ($p in $localPaths) {
        if (Test-Path $p) { $dotfilesConfig = $p; break }
    }
}

if ($dotfilesConfig -and -not (Test-Path $weztermConfig)) {
    Copy-Item $dotfilesConfig $weztermConfig -Force
    Write-Host "  Deployed wezterm.lua from dotfiles (Tango Dark, JetBrainsMono, acrylic)" -ForegroundColor Green
} elseif ($dotfilesConfig -and (Test-Path $weztermConfig)) {
    Write-Host "  WezTerm config already exists - keeping current config" -ForegroundColor Green
} elseif (-not $dotfilesConfig) {
    Write-Host "  Dotfiles wezterm.lua not found. Will create minimal config in Step 7." -ForegroundColor Yellow
}

# -- Step 2: Install Tailscale ------------------------------------------------
Write-Host ""
Write-Host "[2/9] Checking Tailscale..." -ForegroundColor Yellow

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
    $ErrorActionPreference = "Continue"
    winget install --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
    $ErrorActionPreference = "Stop"
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

# -- Step 3: Check Tailscale login --------------------------------------------
Write-Host ""
Write-Host "[3/9] Checking Tailscale connection..." -ForegroundColor Yellow

# Guard: verify tailscale is in PATH before calling it (fresh install may need terminal restart)
if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    Write-Host "  ERROR: 'tailscale' is not in PATH." -ForegroundColor Red
    Write-Host "  Close this terminal, open a new one, and re-run this script." -ForegroundColor Yellow
    exit 1
}

$ErrorActionPreference = "Continue"
$status = & tailscale status 2>&1
$ErrorActionPreference = "Stop"
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
$ErrorActionPreference = "Continue"  # ping returns non-zero for relay connections -- not a real error
$pingResult = & tailscale ping -c 1 $InfinityDNS 2>&1
$ErrorActionPreference = "Stop"
if ("$pingResult" -match "pong") {
    Write-Host "  Connected to Infinity!" -ForegroundColor Green
    if ("$pingResult" -match "via DERP") {
        Write-Host "  (via relay -- direct connection may establish over time)" -ForegroundColor DarkGray
    }
} else {
    Write-Host "  WARNING: Cannot reach Infinity. It may be offline." -ForegroundColor Red
    Write-Host "  Continuing setup - you can test later." -ForegroundColor Yellow
}

# -- Step 4: Generate SSH key -------------------------------------------------
Write-Host ""
Write-Host "[4/9] Setting up SSH key..." -ForegroundColor Yellow

$sshDir = "$env:USERPROFILE\.ssh"
$keyFile = "$sshDir\id_ed25519"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
}

if (Test-Path "$keyFile.pub") {
    Write-Host "  SSH key already exists at $keyFile" -ForegroundColor Green
} else {
    Write-Host "  Generating new SSH key..." -ForegroundColor Cyan
    # Use empty string for passphrase -- double quotes in PS pass empty string correctly
    ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f "$keyFile" -N ""
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: ssh-keygen failed." -ForegroundColor Red
        exit 1
    }
    Write-Host "  Key generated at $keyFile" -ForegroundColor Green
}

# Copy public key to Infinity (idempotent -- checks for duplicates)
Write-Host ""
Write-Host "  Copying public key to Infinity..." -ForegroundColor Cyan
Write-Host "  You may be prompted for your Mac password (one time only)." -ForegroundColor Yellow
Write-Host ""

# Pipe key via stdin to avoid shell injection -- never interpolate key into command string
$pubKeyContent = Get-Content "$keyFile.pub" -Raw
$remoteCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && key=`$(cat) && grep -qxF `"`$key`" ~/.ssh/authorized_keys 2>/dev/null || echo `"`$key`" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key configured successfully'"
$ErrorActionPreference = "Continue"
$pubKeyContent | & ssh -o StrictHostKeyChecking=accept-new "${InfinityUser}@${InfinityIP}" $remoteCmd
$ErrorActionPreference = "Stop"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  SSH key deployed to Infinity!" -ForegroundColor Green
} else {
    Write-Host "  WARNING: Could not copy key automatically." -ForegroundColor Red
    Write-Host "  Manually copy contents of $keyFile.pub to ~/.ssh/authorized_keys on your Mac." -ForegroundColor Yellow
}

# -- Step 5: Create SSH config ------------------------------------------------
Write-Host ""
Write-Host "[5/9] Configuring SSH..." -ForegroundColor Yellow

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
  RequestTTY yes
  RemoteCommand cd ~/Development/Projects && tmux attach -t claude 2>/dev/null || tmux new -s claude -c ~/Development/Projects

# Plain SSH (no auto-tmux) — for file transfers, one-off commands
Host infinity-plain
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
  RequestTTY yes
  RemoteCommand cd ~/Development/Projects && tmux attach -t claude 2>/dev/null || tmux new -s claude -c ~/Development/Projects
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

# -- Step 6: Test SSH connection ----------------------------------------------
Write-Host ""
Write-Host "[6/9] Testing SSH connection..." -ForegroundColor Yellow

$ErrorActionPreference = "Continue"
$testResult = & ssh -o ConnectTimeout=5 -o BatchMode=yes infinity "echo SSH_OK" 2>&1
$ErrorActionPreference = "Stop"
if ("$testResult" -match "SSH_OK") {
    Write-Host "  SSH to Infinity works!" -ForegroundColor Green
} else {
    Write-Host "  SSH test failed." -ForegroundColor Red
    Write-Host "  Troubleshooting:" -ForegroundColor Yellow
    Write-Host "    1. Ensure Infinity (Mac) is awake and connected to Tailscale" -ForegroundColor White
    Write-Host "    2. Run: tailscale ping $InfinityDNS" -ForegroundColor White
    Write-Host "    3. Run: ssh -v infinity" -ForegroundColor White
}

# -- Step 7: Configure WezTerm ------------------------------------------------
Write-Host ""
Write-Host "[7/9] Configuring WezTerm..." -ForegroundColor Yellow

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

        # Neutralize default_domain if present -- conflicts with default_prog on Windows host
        # (default_domain makes default_prog run inside WSL instead of on the Windows host)
        $content = $content -replace '(?m)^(config\.default_domain\s*=)', '-- $1'

        $additions = @"

-- Tailscale: default to SSH into Mac (Claude Code)
-- If Mac is offline, use launch menu for local shell: right-click tab bar or Ctrl+Shift+P
config.default_prog = { 'ssh', 'infinity' }

config.launch_menu = {
  { label = 'Claude Code (Infinity)', args = { 'ssh', 'infinity' } },
  { label = 'PowerShell (local)',     args = { 'powershell.exe' } },
  { label = 'WSL (Ubuntu)',           args = { 'wsl.exe' } },
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
    # No WezTerm config exists -- create a minimal one optimized for SSH to Infinity
    Write-Host "  No WezTerm config found. Creating one optimized for remote access..." -ForegroundColor Cyan

    $minimalConfig = @"
-- WezTerm configuration -- optimized for remote Claude Code access
local wezterm = require 'wezterm'
local config  = wezterm.config_builder()
local act     = wezterm.action

-- Font
config.font      = wezterm.font('JetBrainsMono Nerd Font Mono', { weight = 'Regular' })
config.font_size = 12.0

-- Colors
config.color_scheme = 'Tango (terminal.sexy)'
config.window_background_opacity = 0.85

-- Cursor
config.default_cursor_style = 'SteadyBlock'

-- Window
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = 'TITLE | RESIZE'
config.window_padding = { left = 4, right = 4, top = 4, bottom = 4 }
config.scrollback_lines = 10000
config.check_for_updates = false

-- Default: SSH directly into Mac (Claude Code)
-- If Mac is offline, use launch menu for local shell: right-click tab bar or Ctrl+Shift+P
config.default_prog = { 'ssh', 'infinity' }

-- Launch menu -- right-click tab bar or use Ctrl+Shift+P
config.launch_menu = {
  { label = 'Claude Code (Infinity)', args = { 'ssh', 'infinity' } },
  { label = 'PowerShell (local)',     args = { 'powershell.exe' } },
  { label = 'WSL (Ubuntu)',           args = { 'wsl.exe' } },
}

-- Keybindings
config.keys = {
  { key = 'c', mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v', mods = 'CTRL',       action = act.PasteFrom 'Clipboard' },
  { key = 'f', mods = 'CTRL|SHIFT', action = act.Search { CaseSensitiveString = '' } },
  { key = 't', mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w', mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'p', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
}

return config
"@
    New-Item -ItemType Directory -Force -Path $weztermConfigDir | Out-Null
    Write-UTF8 -Path $weztermConfig -Content $minimalConfig
    Write-Host "  Created WezTerm config with Infinity launch menu at $weztermConfig" -ForegroundColor Green
}

# -- Step 8: Install mosh in WSL (optional) -----------------------------------
Write-Host ""
Write-Host "[8/9] Checking mosh in WSL..." -ForegroundColor Yellow

$wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue
if ($wslAvailable) {
    $ErrorActionPreference = "Continue"
    $moshCheck = & wsl -- which mosh 2>&1
    $ErrorActionPreference = "Stop"
    if ($moshCheck -match "/mosh") {
        Write-Host "  mosh already installed in WSL." -ForegroundColor Green
    } else {
        $response = Read-Host "  mosh not found in WSL. Install for resilient SSH sessions? [Y/n]"
        if ($response -notmatch '^[Nn]') {
            Write-Host "  Installing mosh in WSL..." -ForegroundColor Cyan
            $ErrorActionPreference = "Continue"
            & wsl -- sudo apt-get update -qq "&&" sudo apt-get install -y -qq mosh 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  mosh installed in WSL." -ForegroundColor Green
            } else {
                Write-Host "  WARNING: mosh install failed. Run manually: wsl sudo apt install mosh" -ForegroundColor Yellow
            }
        } else {
            Write-Host "  Skipping mosh. Install later: wsl sudo apt install mosh" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host "  WSL not available - skipping mosh install." -ForegroundColor Yellow
    Write-Host "  mosh is optional -- SSH works without it." -ForegroundColor White
}

# -- Step 9: Create remote cleanup shortcut ------------------------------------
Write-Host ""
Write-Host "[9/9] Creating remote cleanup shortcut..." -ForegroundColor Yellow

# Create a local script that SSHs into Infinity and runs the OMC cleanup
$cleanupDir = "$env:USERPROFILE\.local\bin"
if (-not (Test-Path $cleanupDir)) {
    New-Item -ItemType Directory -Force -Path $cleanupDir | Out-Null
}

$cleanupScript = "$cleanupDir\omc-cleanup.ps1"
$cleanupContent = @"
# omc-cleanup.ps1 — Clean stale OMC state on Infinity (Mac) after disconnect
# Run this if Claude Code behaves erratically after closing WezTerm without detaching.
#
# Usage:
#   .\omc-cleanup.ps1           # clean and report
#   .\omc-cleanup.ps1 -Connect  # clean then SSH into tmux session
param([switch]`$Connect)

`$InfinityHost = "infinity"

Write-Host "Cleaning OMC state on Infinity..." -ForegroundColor Cyan
ssh `$InfinityHost "~/.local/bin/omc-session-cleanup.sh"

if (`$LASTEXITCODE -eq 0) {
    Write-Host "Cleanup complete." -ForegroundColor Green
} else {
    Write-Host "WARNING: Cleanup may have failed (exit `$LASTEXITCODE)" -ForegroundColor Yellow
}

if (`$Connect) {
    Write-Host "Connecting to Claude Code session..." -ForegroundColor Cyan
    ssh -t `$InfinityHost "tmux attach -t claude 2>/dev/null || tmux new -s claude"
}
"@
Write-UTF8 -Path $cleanupScript -Content $cleanupContent

# Add to PATH if not already there
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notmatch [regex]::Escape($cleanupDir)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$userPath;$cleanupDir", "User")
    $env:Path += ";$cleanupDir"
    Write-Host "  Added $cleanupDir to user PATH" -ForegroundColor Green
}

Write-Host "  Created $cleanupScript" -ForegroundColor Green
Write-Host "  Usage: omc-cleanup           (clean stale state)" -ForegroundColor White
Write-Host "         omc-cleanup -Connect  (clean + reconnect)" -ForegroundColor White

# -- Done ---------------------------------------------------------------------
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup Complete!                           " -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Connect to your Mac:" -ForegroundColor Cyan
Write-Host "    ssh infinity                    Plain SSH" -ForegroundColor White
Write-Host "    ssh -t infinity                 SSH + auto-attach tmux" -ForegroundColor White
Write-Host "    mosh $InfinityUser@$InfinityDNS -- tmux a -t claude" -ForegroundColor White
Write-Host "                                    Resilient session (from WSL)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  WezTerm:" -ForegroundColor Cyan
Write-Host "    Launch menu:  'Claude Code (Infinity)'" -ForegroundColor White
Write-Host "    Or just type: ssh infinity" -ForegroundColor White
Write-Host ""
Write-Host "  Tailscale:" -ForegroundColor Cyan
Write-Host "    tailscale status                Check all devices" -ForegroundColor White
Write-Host "    tailscale ping $InfinityDNS     Test connectivity" -ForegroundColor White
Write-Host "    tailscale up --exit-node=infinity  Route traffic through home (public Wi-Fi)" -ForegroundColor White
Write-Host ""
