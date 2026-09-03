#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

Write-Host "🔍 Linting PowerShell Scripts..." -ForegroundColor Blue

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "Error: 'PSScriptAnalyzer' module is not installed." -ForegroundColor Red
    Write-Host "Please install it with: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser"
    exit 1
}

# windows/ is excluded from Chezmoi, but windows/scripts/*.ps1 are still repo code and
# windows/AGENTS.md requires them to pass PSScriptAnalyzer -- lint them here too.
$searchPaths = @('scripts', 'windows/scripts') | Where-Object { Test-Path $_ }
$files = Get-ChildItem -Path $searchPaths -Recurse -Include *.ps1

if ($files.Count -eq 0) {
    Write-Host "No PowerShell scripts found to lint." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($files.Count) script(s) to check."

$settingsPath = Join-Path -Path $PSScriptRoot -ChildPath ".." -AdditionalChildPath "PSScriptAnalyzerSettings.psd1"

# -Path takes a single string, so passing $files.FullName (an array) threw
# "Cannot convert 'System.Object[]' to the type 'System.String'" and the lint never
# ran. Analyse one file at a time and collect the results.
$results = foreach ($file in $files) {
    Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath
}

if ($results) {
    $results | Format-Table -AutoSize
    Write-Host "❌ PSScriptAnalyzer found issues." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ PSScriptAnalyzer passed!" -ForegroundColor Green
    exit 0
}
