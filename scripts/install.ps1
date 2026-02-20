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

# Configuration
$GithubUser = "vgaonkar"
$ChezmoiUrl = "https://get.chezmoi.io"

Write-Host "🏠 Dotfiles Installer for Windows" -ForegroundColor Blue
Write-Host ""

# Parity with Unix installer flag style
if ($args -contains "--browser-login") {
    $BrowserLogin = $true
}

if ($BrowserLogin) {
    Write-Host "🔐 Browser-login bootstrap selected; handing off to scripts/bootstrap/install.ps1" -ForegroundColor Yellow
    $bootstrapPath = Join-Path $PSScriptRoot "bootstrap\install.ps1"

    if (-not (Test-Path -Path $bootstrapPath)) {
        Write-Host "❌ Bootstrap script not found: $bootstrapPath" -ForegroundColor Red
        exit 1
    }

    try {
        & $bootstrapPath
        exit $LASTEXITCODE
    } catch {
        Write-Host "❌ Bootstrap failed" -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-Host "⚠️  Warning: Running as Administrator. Some features may not work correctly." -ForegroundColor Yellow
    Write-Host "   It's recommended to run this as a regular user." -ForegroundColor Yellow
    Write-Host ""
}

# Install chezmoi if not present
if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    Write-Host "📦 Installing chezmoi..." -ForegroundColor Yellow
    
    try {
        Invoke-Expression (Invoke-RestMethod -Uri $ChezmoiUrl)
    } catch {
        Write-Host "❌ Failed to install chezmoi" -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
} else {
    Write-Host "✓ chezmoi already installed" -ForegroundColor Green
}

# Add to PATH if needed
$localBin = "$env:USERPROFILE\.local\bin"
if (Test-Path "$localBin\chezmoi.exe") {
    $env:PATH = "$localBin;$env:PATH"
}

# Initialize and apply dotfiles
Write-Host ""
Write-Host "🚀 Initializing dotfiles..." -ForegroundColor Yellow
Write-Host "Repository: https://github.com/$GithubUser/dotfiles" -ForegroundColor Blue
Write-Host ""

try {
    chezmoi init --apply $GithubUser
    
    Write-Host ""
    Write-Host "✅ Dotfiles installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Blue
    Write-Host "  1. Restart PowerShell or run: . \$PROFILE"
    Write-Host "  2. Review the installed configurations"
    Write-Host "  3. Read the docs: chezmoi cd; Get-Content docs\01-quick-start.md"
} catch {
    Write-Host "❌ Installation failed" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit 1
}
