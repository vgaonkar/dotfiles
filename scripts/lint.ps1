#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

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


Write-Status "🔍 Linting PowerShell Scripts..." 'Blue'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Status "Error: 'PSScriptAnalyzer' module is not installed." 'Red'
    Write-Status "Please install it with: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser"
    exit 1
}

# windows/ is excluded from Chezmoi, but windows/scripts/*.ps1 are still repo code and
# windows/AGENTS.md requires them to pass PSScriptAnalyzer -- lint them here too.
$searchPaths = @('scripts', 'windows/scripts') | Where-Object { Test-Path $_ }
$files = Get-ChildItem -Path $searchPaths -Recurse -Include *.ps1

if ($files.Count -eq 0) {
    Write-Status "No PowerShell scripts found to lint." 'Green'
    exit 0
}

Write-Status "Found $($files.Count) script(s) to check."

$settingsPath = Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "PSScriptAnalyzerSettings.psd1"

# -Path takes a single string, so passing $files.FullName (an array) threw
# "Cannot convert 'System.Object[]' to the type 'System.String'" and the lint never
# ran. Analyse one file at a time and collect the results.
$results = foreach ($file in $files) {
    Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath
}

if ($results) {
    $results | Format-Table -AutoSize
    Write-Status "❌ PSScriptAnalyzer found issues." 'Red'
    exit 1
} else {
    Write-Status "✅ PSScriptAnalyzer passed!" 'Green'
    exit 0
}
