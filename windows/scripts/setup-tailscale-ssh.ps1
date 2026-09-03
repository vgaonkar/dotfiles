# setup-tailscale-ssh.ps1
# Sets up Tailscale + WezTerm + SSH to Infinity (Mac) from Windows.
# Run from PowerShell (Administrator recommended for winget):
#   .\setup-tailscale-ssh.ps1
#
# Safe to re-run -- all steps are idempotent.

$ErrorActionPreference = "Stop"

# Write-Host is the only console writer Start-Transcript captures ($Host.UI.WriteLine
# is not), so the analyzer rule against it is suppressed on this single helper.
function Write-Status {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Write-Host is the only console writer captured by Start-Transcript. Confined to this helper.')]
    param(
        [string]$Message = '',
        [string]$Color = ''
    )
    # Write-Host, not $Host.UI.WriteLine: Start-Transcript captures Write-Host but
    # NOT $Host.UI.WriteLine, so the run log would otherwise be empty. Verified by
    # test on pwsh 7.6.5. PSAvoidUsingWriteHost is suppressed for this one function.
    if ([string]::IsNullOrEmpty($Color)) {
        Write-Host $Message
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
}


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

Write-Status ""
Write-Status "============================================" 'Cyan'
Write-Status "  Tailscale SSH to Infinity - Setup Script  " 'Cyan'
Write-Status "============================================" 'Cyan'
Write-Status ""

if (-not (Test-Admin)) {
    Write-Status "  NOTE: Running without admin. Winget install may fail." 'Yellow'
    Write-Status "  Re-run as Administrator if Step 1 fails." 'Yellow'
    Write-Status ""
}

# Check OpenSSH client is available
$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshCmd) {
    Write-Status "  OpenSSH client not found. Attempting to install..." 'Yellow'
    try {
        Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0 | Out-Null
        Write-Status "  OpenSSH client installed." 'Green'
    } catch {
        Write-Status "  ERROR: Cannot install OpenSSH client. Install manually:" 'Red'
        Write-Status "  Settings > Apps > Optional Features > OpenSSH Client" 'White'
        exit 1
    }
}

# -- Step 1: Install WezTerm --------------------------------------------------
Write-Status "[1/9] Checking WezTerm..." 'Yellow'

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
    Write-Status "  WezTerm already installed." 'Green'
} else {
    $response = Read-Host "  WezTerm not found. Install via winget? [Y/n]"
    if ($response -match '^[Nn]') {
        Write-Status "  Skipping WezTerm. You can install later from https://wezfurlong.org/wezterm/" 'Yellow'
    } else {
        Write-Status "  Installing WezTerm..." 'Cyan'
        $ErrorActionPreference = "Continue"
        winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -ne 0) {
            Write-Status "  WARNING: WezTerm install failed. Install manually from https://wezfurlong.org/wezterm/" 'Yellow'
        } else {
            Write-Status "  WezTerm installed." 'Green'
        }
    }
}

# Install JetBrainsMono Nerd Font (required by wezterm.lua config)
$fontCheck = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Fonts\JetBrains*Nerd*" -ErrorAction SilentlyContinue
if (-not $fontCheck) {
    $fontCheck = Get-ChildItem "$env:WINDIR\Fonts\JetBrains*Nerd*" -ErrorAction SilentlyContinue
}
if ($fontCheck) {
    Write-Status "  JetBrainsMono Nerd Font already installed." 'Green'
} else {
    Write-Status "  Installing JetBrainsMono Nerd Font (used by WezTerm config)..." 'Cyan'
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
        Write-Status "  JetBrainsMono Nerd Font installed." 'Green'
    } else {
        Write-Status "  WARNING: Could not auto-install font. Download manually:" 'Yellow'
        Write-Status "  https://github.com/ryanoasis/nerd-fonts/releases/latest" 'White'
        Write-Status "  Search for JetBrainsMono.zip, extract and install .ttf files." 'White'
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
    Write-Status "  Deployed wezterm.lua from dotfiles (Tango Dark, JetBrainsMono, acrylic)" 'Green'
} elseif ($dotfilesConfig -and (Test-Path $weztermConfig)) {
    Write-Status "  WezTerm config already exists - keeping current config" 'Green'
} elseif (-not $dotfilesConfig) {
    Write-Status "  Dotfiles wezterm.lua not found. Will create minimal config in Step 7." 'Yellow'
}

# -- Step 2: Install Tailscale ------------------------------------------------
Write-Status ""
Write-Status "[2/9] Checking Tailscale..." 'Yellow'

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
    Write-Status "  Tailscale already installed at $($tsPath.Source)" 'Green'
} else {
    $response = Read-Host "  Tailscale not found. Install via winget? [Y/n]"
    if ($response -match '^[Nn]') {
        Write-Status "  Skipping. Install manually from https://tailscale.com/download/windows" 'Red'
        exit 1
    }
    Write-Status "  Installing Tailscale..." 'Cyan'
    $ErrorActionPreference = "Continue"
    winget install --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements
    $ErrorActionPreference = "Stop"
    if ($LASTEXITCODE -ne 0) {
        Write-Status "  ERROR: Tailscale installation failed (exit code $LASTEXITCODE)." 'Red'
        Write-Status "  Install manually from https://tailscale.com/download/windows" 'Yellow'
        exit 1
    }
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

    # Verify tailscale is now available
    $tsPath = Get-Command tailscale -ErrorAction SilentlyContinue
    if (-not $tsPath) {
        Write-Status "  WARNING: Tailscale installed but not in PATH. You may need to restart your terminal." 'Yellow'
    }
}

# -- Step 3: Check Tailscale login --------------------------------------------
Write-Status ""
Write-Status "[3/9] Checking Tailscale connection..." 'Yellow'

# Guard: verify tailscale is in PATH before calling it (fresh install may need terminal restart)
if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    Write-Status "  ERROR: 'tailscale' is not in PATH." 'Red'
    Write-Status "  Close this terminal, open a new one, and re-run this script." 'Yellow'
    exit 1
}

$ErrorActionPreference = "Continue"
$status = & tailscale status 2>&1
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0 -or $status -match "Logged out|NeedsLogin|stopped") {
    Write-Status "  Tailscale is not connected. Opening login..." 'Cyan'
    & tailscale up
    if ($LASTEXITCODE -ne 0) {
        Write-Status "  WARNING: tailscale up may have failed. Check the system tray." 'Yellow'
    }
    Write-Status ""
    Write-Status "  Sign in with your Tailscale account." 'Yellow'
    Write-Status "  Approve the device at: https://login.tailscale.com/admin/machines" 'Yellow'
    Read-Host "  Press Enter after you've logged in and approved the device"
}

# Verify connectivity
Write-Status "  Testing connection to Infinity..." 'Cyan'
$ErrorActionPreference = "Continue"  # ping returns non-zero for relay connections -- not a real error
$pingResult = & tailscale ping -c 1 $InfinityDNS 2>&1
$ErrorActionPreference = "Stop"
if ("$pingResult" -match "pong") {
    Write-Status "  Connected to Infinity!" 'Green'
    if ("$pingResult" -match "via DERP") {
        Write-Status "  (via relay -- direct connection may establish over time)" 'DarkGray'
    }
} else {
    Write-Status "  WARNING: Cannot reach Infinity. It may be offline." 'Red'
    Write-Status "  Continuing setup - you can test later." 'Yellow'
}

# -- Step 4: Generate SSH key -------------------------------------------------
Write-Status ""
Write-Status "[4/9] Setting up SSH key..." 'Yellow'

$sshDir = "$env:USERPROFILE\.ssh"
$keyFile = "$sshDir\id_ed25519"

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
}

if (Test-Path "$keyFile.pub") {
    Write-Status "  SSH key already exists at $keyFile" 'Green'
} else {
    Write-Status "  Generating new SSH key..." 'Cyan'
    # Use empty string for passphrase -- double quotes in PS pass empty string correctly
    ssh-keygen -t ed25519 -C "$env:COMPUTERNAME" -f "$keyFile" -N ""
    if ($LASTEXITCODE -ne 0) {
        Write-Status "  ERROR: ssh-keygen failed." 'Red'
        exit 1
    }
    Write-Status "  Key generated at $keyFile" 'Green'
}

# Copy public key to Infinity (idempotent -- checks for duplicates)
Write-Status ""
Write-Status "  Copying public key to Infinity..." 'Cyan'
Write-Status "  You may be prompted for your Mac password (one time only)." 'Yellow'
Write-Status ""

# Pipe key via stdin to avoid shell injection -- never interpolate key into command string
$pubKeyContent = Get-Content "$keyFile.pub" -Raw
$remoteCmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && key=`$(cat) && grep -qxF `"`$key`" ~/.ssh/authorized_keys 2>/dev/null || echo `"`$key`" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key configured successfully'"
$ErrorActionPreference = "Continue"
$pubKeyContent | & ssh -o StrictHostKeyChecking=accept-new "${InfinityUser}@${InfinityIP}" $remoteCmd
$ErrorActionPreference = "Stop"

if ($LASTEXITCODE -eq 0) {
    Write-Status "  SSH key deployed to Infinity!" 'Green'
} else {
    Write-Status "  WARNING: Could not copy key automatically." 'Red'
    Write-Status "  Manually copy contents of $keyFile.pub to ~/.ssh/authorized_keys on your Mac." 'Yellow'
}

# -- Step 5: Create SSH config ------------------------------------------------
Write-Status ""
Write-Status "[5/9] Configuring SSH..." 'Yellow'

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
  RemoteCommand cd ~/Development/Projects && exec `$SHELL -l

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
  RemoteCommand cd ~/Development/Projects && exec `$SHELL -l
"@

if (Test-Path $sshConfig) {
    $existing = Get-Content $sshConfig -Raw
    # Use regex with line anchor to avoid substring false matches
    if ($existing -match '(?m)^Host\s+infinity\s*$') {
        # Remove old infinity block(s) and replace with updated config
        # Strip everything from "# --- Tailscale:" to the next blank-line-then-Host or EOF
        $cleaned = $existing -replace '(?ms)\r?\n?# --- Tailscale: Remote Claude Code on Infinity.*?(?=\r?\n\r?\n(?!Host\s+(infinity|infinity-plain)\b)|$)', ''
        # Also remove any standalone infinity/infinity-plain/FQDN host blocks
        $cleaned = $cleaned -replace '(?ms)\r?\nHost\s+infinity\s*\r?\n.*?(?=\r?\nHost\s|\z)', ''
        $cleaned = $cleaned -replace '(?ms)\r?\nHost\s+infinity-plain\s*\r?\n.*?(?=\r?\nHost\s|\z)', ''
        $cleaned = $cleaned -replace "(?ms)\r?\nHost\s+$([regex]::Escape($InfinityDNS))\s*\r?\n.*?(?=\r?\nHost\s|\z)", ''
        $newContent = $cleaned.TrimEnd() + "`n" + $infinityBlock + "`n"
        Write-UTF8 -Path $sshConfig -Content $newContent
        Write-Status "  Updated infinity SSH config (replaced old entry)" 'Green'
    } else {
        # Append using UTF-8 without BOM
        $newContent = $existing.TrimEnd() + "`n" + $infinityBlock + "`n"
        Write-UTF8 -Path $sshConfig -Content $newContent
        Write-Status "  Added infinity to $sshConfig" 'Green'
    }
} else {
    Write-UTF8 -Path $sshConfig -Content ($infinityBlock.TrimStart() + "`n")
    Write-Status "  Created $sshConfig with infinity entry" 'Green'
}

# -- Step 6: Test SSH connection ----------------------------------------------
Write-Status ""
Write-Status "[6/9] Testing SSH connection..." 'Yellow'

$ErrorActionPreference = "Continue"
$testResult = & ssh -o ConnectTimeout=5 -o BatchMode=yes infinity "echo SSH_OK" 2>&1
$ErrorActionPreference = "Stop"
if ("$testResult" -match "SSH_OK") {
    Write-Status "  SSH to Infinity works!" 'Green'
} else {
    Write-Status "  SSH test failed." 'Red'
    Write-Status "  Troubleshooting:" 'Yellow'
    Write-Status "    1. Ensure Infinity (Mac) is awake and connected to Tailscale" 'White'
    Write-Status "    2. Run: tailscale ping $InfinityDNS" 'White'
    Write-Status "    3. Run: ssh -v infinity" 'White'
}

# -- Step 7: Configure WezTerm ------------------------------------------------
Write-Status ""
Write-Status "[7/9] Configuring WezTerm..." 'Yellow'

$weztermConfig = "$env:USERPROFILE\.config\wezterm\wezterm.lua"

if (Test-Path $weztermConfig) {
    $content = Get-Content $weztermConfig -Raw

    if ($content -match "launch_menu") {
        Write-Status "  WezTerm already has launch_menu - skipping auto-config" 'Yellow'
        Write-Status "  Add this entry manually to your launch_menu:" 'Yellow'
        Write-Status "    { label = 'Claude Code (Infinity)', args = { 'ssh', 'infinity' } }," 'White'
    }
    elseif ($content -match "Claude Code.*Infinity") {
        Write-Status "  WezTerm already configured for Infinity - skipping" 'Green'
    }
    else {
        # Back up config before modifying
        $backupPath = "$weztermConfig.bak.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $weztermConfig $backupPath
        Write-Status "  Backed up WezTerm config to $backupPath" 'Cyan'

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
            Write-Status "  Added launch menu with Infinity entry to WezTerm config" 'Green'
        } else {
            Write-Status "  WARNING: Could not find 'return config' in wezterm.lua" 'Yellow'
            Write-Status "  Add the launch_menu manually (see guide)." 'Yellow'
        }
    }
} else {
    # No WezTerm config exists -- create a minimal one optimized for SSH to Infinity
    Write-Status "  No WezTerm config found. Creating one optimized for remote access..." 'Cyan'

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
    Write-Status "  Created WezTerm config with Infinity launch menu at $weztermConfig" 'Green'
}

# -- Step 8: Install mosh in WSL (optional) -----------------------------------
Write-Status ""
Write-Status "[8/9] Checking mosh in WSL..." 'Yellow'

$wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue
if ($wslAvailable) {
    $ErrorActionPreference = "Continue"
    $moshCheck = & wsl -- which mosh 2>&1
    $ErrorActionPreference = "Stop"
    if ($moshCheck -match "/mosh") {
        Write-Status "  mosh already installed in WSL." 'Green'
    } else {
        $response = Read-Host "  mosh not found in WSL. Install for resilient SSH sessions? [Y/n]"
        if ($response -notmatch '^[Nn]') {
            Write-Status "  Installing mosh in WSL..." 'Cyan'
            $ErrorActionPreference = "Continue"
            & wsl -- sudo apt-get update -qq "&&" sudo apt-get install -y -qq mosh 2>&1 | Out-Null
            $ErrorActionPreference = "Stop"
            if ($LASTEXITCODE -eq 0) {
                Write-Status "  mosh installed in WSL." 'Green'
            } else {
                Write-Status "  WARNING: mosh install failed. Run manually: wsl sudo apt install mosh" 'Yellow'
            }
        } else {
            Write-Status "  Skipping mosh. Install later: wsl sudo apt install mosh" 'Yellow'
        }
    }
} else {
    Write-Status "  WSL not available - skipping mosh install." 'Yellow'
    Write-Status "  mosh is optional -- SSH works without it." 'White'
}

# -- Step 9: Create remote cleanup shortcut ------------------------------------
Write-Status ""
Write-Status "[9/9] Creating remote cleanup shortcut..." 'Yellow'

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
    Write-Status "  Added $cleanupDir to user PATH" 'Green'
}

Write-Status "  Created $cleanupScript" 'Green'
Write-Status "  Usage: omc-cleanup           (clean stale state)" 'White'
Write-Status "         omc-cleanup -Connect  (clean + reconnect)" 'White'

# -- Done ---------------------------------------------------------------------
Write-Status ""
Write-Status "============================================" 'Green'
Write-Status "  Setup Complete!                           " 'Green'
Write-Status "============================================" 'Green'
Write-Status ""
Write-Status "  Connect to your Mac:" 'Cyan'
Write-Status "    ssh infinity                    Plain SSH" 'White'
Write-Status "    ssh -t infinity                 SSH + auto-attach tmux" 'White'
Write-Status "    mosh $InfinityUser@$InfinityDNS -- tmux a -t claude" 'White'
Write-Status "                                    Resilient session (from WSL)" 'DarkGray'
Write-Status ""
Write-Status "  WezTerm:" 'Cyan'
Write-Status "    Launch menu:  'Claude Code (Infinity)'" 'White'
Write-Status "    Or just type: ssh infinity" 'White'
Write-Status ""
Write-Status "  Tailscale:" 'Cyan'
Write-Status "    tailscale status                Check all devices" 'White'
Write-Status "    tailscale ping $InfinityDNS     Test connectivity" 'White'
Write-Status "    tailscale up --exit-node=infinity  Route traffic through home (public Wi-Fi)" 'White'
Write-Status ""
