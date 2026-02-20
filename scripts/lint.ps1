#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

Write-Host "🔍 Linting PowerShell Scripts..." -ForegroundColor Blue

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    Write-Host "Error: 'PSScriptAnalyzer' module is not installed." -ForegroundColor Red
    Write-Host "Please install it with: Install-Module -Name PSScriptAnalyzer -Scope CurrentUser"
    exit 1
}

$files = Get-ChildItem -Path scripts -Recurse -Include *.ps1

if ($files.Count -eq 0) {
    Write-Host "No PowerShell scripts found to lint." -ForegroundColor Green
    exit 0
}

Write-Host "Found $($files.Count) script(s) to check."

$settingsPath = Join-Path $PSScriptRoot ".." "PSScriptAnalyzerSettings.psd1"
$results = Invoke-ScriptAnalyzer -Path $files.FullName -Settings $settingsPath -Recurse

if ($results) {
    $results | Format-Table -AutoSize
    Write-Host "❌ PSScriptAnalyzer found issues." -ForegroundColor Red
    exit 1
} else {
    Write-Host "✅ PSScriptAnalyzer passed!" -ForegroundColor Green
    exit 0
}
