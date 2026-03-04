# install-wezterm.ps1
# Installs WezTerm on Windows via winget and deploys config from WSL.
# Run from PowerShell (as Administrator recommended):
#   .\install-wezterm.ps1

$response = Read-Host "Install WezTerm terminal emulator via winget? [y/N]"
if ($response -notmatch '^[Yy]') {
    Write-Host "Skipping WezTerm installation."
    exit 0
}

Write-Host "[wezterm] Installing WezTerm..."
winget install --id wez.wezterm --accept-source-agreements --accept-package-agreements

# Deploy wezterm config from WSL home if available
$wslConfig = "\\wsl.localhost\Ubuntu\home\dev\.config\wezterm\wezterm.lua"
$winConfig  = "$env:USERPROFILE\.config\wezterm\wezterm.lua"

if (Test-Path $wslConfig) {
    New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.config\wezterm" | Out-Null
    Copy-Item $wslConfig $winConfig -Force
    Write-Host "[wezterm] Config deployed from WSL to $winConfig"
} else {
    Write-Host "[wezterm] WSL config not found at $wslConfig"
    Write-Host "[wezterm] Run 'chezmoi apply' inside WSL first, then re-run this script."
}

Write-Host "[wezterm] Done. Launch WezTerm from the Start Menu."
