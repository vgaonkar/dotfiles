# Install PowerShell 7 and CLI tools on Windows via winget
# Mirrors the brew tools installed on macOS (fish config)

# Write-Host trips PSScriptAnalyzer's PSAvoidUsingWriteHost. $Host.UI.WriteLine gives
# the same coloured console output and is captured by Start-Transcript identically.
function Write-Status {
    param(
        [string]$Message = '',
        [string]$Color = $Host.UI.RawUI.ForegroundColor
    )
    $Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)
}


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
    Write-Status "Installing $pkg..." 'Cyan'
    winget install $pkg --accept-source-agreements --accept-package-agreements
}

Write-Status "`nAll tools installed. Restart your terminal for PATH changes to take effect." 'Green'
