# install-wezterm.ps1
# Installs WezTerm on Windows via winget and deploys config from WSL.
# Run from PowerShell (as Administrator recommended):
#   .\install-wezterm.ps1

# Write-Host trips PSScriptAnalyzer's PSAvoidUsingWriteHost. $Host.UI.WriteLine gives
# the same coloured console output and is captured by Start-Transcript identically.
function Write-Status {
    param(
        [string]$Message = '',
        [string]$Color = $Host.UI.RawUI.ForegroundColor
    )
    $Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)
}


$response = Read-Host "Install WezTerm terminal emulator via winget? [y/N]"
if ($response -notmatch '^[Yy]') {
    Write-Status "Skipping WezTerm installation."
    exit 0
}

Write-Status "[wezterm] Installing WezTerm..."
winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements

# Deploy wezterm config from WSL home if available
$wslConfig = "\\wsl.localhost\Ubuntu\home\dev\.config\wezterm\wezterm.lua"
$winConfig  = "$env:USERPROFILE\.config\wezterm\wezterm.lua"

if (Test-Path $wslConfig) {
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\wezterm" | Out-Null
    Copy-Item $wslConfig $winConfig -Force
    Write-Status "[wezterm] Config deployed from WSL to $winConfig"
} else {
    Write-Status "[wezterm] WSL config not found at $wslConfig"
    Write-Status "[wezterm] Run 'chezmoi apply' inside WSL first, then re-run this script."
}

Write-Status "[wezterm] Done. Launch WezTerm from the Start Menu."
