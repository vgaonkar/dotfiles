# Install PowerShell 7 and CLI tools on Windows via winget
# Mirrors the brew tools installed on macOS (fish config)

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
