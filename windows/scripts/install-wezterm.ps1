# install-wezterm.ps1
# Installs WezTerm on Windows via winget and deploys config from WSL.
# Run from PowerShell (as Administrator recommended):
#   .\install-wezterm.ps1

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
