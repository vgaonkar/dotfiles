#Requires -Version 5.1
<#
.SYNOPSIS
    Dotfiles installer for Windows
.DESCRIPTION
    Installs chezmoi and applies dotfiles on Windows systems
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Configuration
$GithubUser = "vgaonkar"
$ChezmoiUrl = "https://get.chezmoi.io"

Write-Host "🏠 Dotfiles Installer for Windows" -ForegroundColor Blue
Write-Host ""

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
