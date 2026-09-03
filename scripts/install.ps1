#Requires -Version 5.1
<#
.SYNOPSIS
    Dotfiles installer for Windows
.DESCRIPTION
    Installs chezmoi and applies dotfiles on Windows systems

.PARAMETER BrowserLogin
    Run the browser-login bootstrap flow (HTTPS + gh auth) by invoking scripts/bootstrap/install.ps1.
    This will exit with the bootstrap script's exit code.

.EXAMPLE
    .\scripts\install.ps1

.EXAMPLE
    .\scripts\install.ps1 -BrowserLogin

.EXAMPLE
    .\scripts\install.ps1 --browser-login
#>

[CmdletBinding()]
param(
    [switch]$BrowserLogin
)

$ErrorActionPreference = "Stop"

# Write-Host trips PSScriptAnalyzer's PSAvoidUsingWriteHost. $Host.UI.WriteLine gives
# the same coloured console output and is captured by Start-Transcript identically.
function Write-Status {
    param(
        [string]$Message = '',
        [string]$Color = ''
    )
    # RawUI reports -1 for its colours when there is no real console (redirected
    # output, CI). $Host.UI.WriteLine rejects -1 as a foreground, so when no colour
    # is requested use the uncoloured overload rather than the host's current one.
    if ([string]::IsNullOrEmpty($Color)) {
        $Host.UI.WriteLine($Message)
    } else {
        $Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)
    }
}


# Configuration
$GithubUser = "vgaonkar"
$ChezmoiUrl = "https://get.chezmoi.io"

Write-Status "🏠 Dotfiles Installer for Windows" 'Blue'
Write-Status ""

# Parity with Unix installer flag style
if ($args -contains "--browser-login") {
    $BrowserLogin = $true
}

if ($BrowserLogin) {
    Write-Status "🔐 Browser-login bootstrap selected; handing off to scripts/bootstrap/install.ps1" 'Yellow'
    $bootstrapPath = Join-Path $PSScriptRoot "bootstrap\install.ps1"

    if (-not (Test-Path -Path $bootstrapPath)) {
        Write-Status "❌ Bootstrap script not found: $bootstrapPath" 'Red'
        exit 1
    }

    try {
        & $bootstrapPath
        exit $LASTEXITCODE
    } catch {
        Write-Status "❌ Bootstrap failed" 'Red'
        Write-Status $_.Exception.Message
        exit 1
    }
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-Status "⚠️  Warning: Running as Administrator. Some features may not work correctly." 'Yellow'
    Write-Status "   It's recommended to run this as a regular user." 'Yellow'
    Write-Status ""
}

# Install chezmoi if not present
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Status "📦 Installing chezmoi..." 'Yellow'
    
    try {
        Invoke-Expression (Invoke-RestMethod -Uri $ChezmoiUrl)
    } catch {
        Write-Status "❌ Failed to install chezmoi" 'Red'
        Write-Status $_.Exception.Message
        exit 1
    }
} else {
    Write-Status "✓ chezmoi already installed" 'Green'
}

# Add to PATH if needed
$localBin = "$env:USERPROFILE\.local\bin"
if (Test-Path "$localBin\chezmoi.exe") {
    $env:PATH = "$localBin;$env:PATH"
}

# Initialize and apply dotfiles
Write-Status ""
Write-Status "🚀 Initializing dotfiles..." 'Yellow'
Write-Status "Repository: https://github.com/$GithubUser/dotfiles" 'Blue'
Write-Status ""

try {
    chezmoi init --apply $GithubUser
    
    Write-Status ""
    Write-Status "✅ Dotfiles installed successfully!" 'Green'
    Write-Status ""
    Write-Status "Next steps:" 'Blue'
    Write-Status "  1. Restart PowerShell or run: . \$PROFILE"
    Write-Status "  2. Review the installed configurations"
    Write-Status "  3. Read the docs: chezmoi cd; Get-Content docs\01-quick-start.md"
} catch {
    Write-Status "❌ Installation failed" 'Red'
    Write-Status $_.Exception.Message
    exit 1
}
