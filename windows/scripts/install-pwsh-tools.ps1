# Install PowerShell 7 and CLI tools on Windows via winget
# Mirrors the brew tools installed on macOS (fish config)

$packages = @(
    'Microsoft.PowerShell'
    'eza-community.eza'
    'sharkdp.bat'
    'Starship.Starship'
    'ajeetdsouza.zoxide'
    'junegunn.fzf'
    'dandavison.delta'
)

foreach ($pkg in $packages) {
    Write-Host "Installing $pkg..." -ForegroundColor Cyan
    winget install $pkg --accept-source-agreements --accept-package-agreements
}

Write-Host "`nAll tools installed. Restart your terminal for PATH changes to take effect." -ForegroundColor Green
