# Install PowerShell 7 and CLI tools on Windows via winget
# Mirrors the brew tools installed on macOS (fish config)

# Write-Host is the only console writer Start-Transcript captures ($Host.UI.WriteLine
# is not). PSAvoidUsingWriteHost is switched off in PSScriptAnalyzerSettings.psd1.
function Write-Status {
    param(
        [string]$Message = '',
        [string]$Color = ''
    )
    # Write-Host, not $Host.UI.WriteLine: Start-Transcript captures Write-Host but
    # NOT $Host.UI.WriteLine, so the run log would otherwise be empty (verified on
    # pwsh 7.6.5). Route all output through here so there is one place to change.
    if ([string]::IsNullOrEmpty($Color)) {
        Write-Host $Message
    } else {
        Write-Host $Message -ForegroundColor $Color
    }
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
