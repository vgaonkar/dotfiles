#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

# Write-Host trips PSScriptAnalyzer's PSAvoidUsingWriteHost. $Host.UI.WriteLine gives
# the same coloured console output and is captured by Start-Transcript identically.
function Write-Status {
    param(
        [string]$Message = '',
        [string]$Color = ''
    )
    # RawUI reports -1 for its colours when there is no real console (redirected
    # output, CI). $Host.UI.WriteLine rejects -1 as a foreground, so when no colour
    # is requested use the uncoloured overload rather than the host's current one.
    if ([string]::IsNullOrEmpty($Color)) {
        $Host.UI.WriteLine($Message)
    } else {
        $Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)
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
