#!/usr/bin/env pwsh

$ErrorActionPreference = "Stop"

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


Write-Status " Linting PowerShell Scripts..." 'Blue'

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
    Write-Status "[X] PSScriptAnalyzer found issues." 'Red'
    exit 1
}

Write-Status "[OK] PSScriptAnalyzer passed!" 'Green'

# ASCII-only check. These files are UTF-8 without a BOM, and Windows PowerShell 5.1
# reads such files as Windows-1252 -- so any non-ASCII character is mangled on the
# fresh-machine bootstrap path. An em dash became "a<euro>"" and terminated a string
# early, which cost a real debugging session. This is invisible in a diff, so it is
# checked rather than remembered.
Write-Status ''
Write-Status 'Checking scripts are pure ASCII...' 'Blue'

$nonAscii = foreach ($file in $files) {
    $lineNo = 0
    foreach ($line in (Get-Content -LiteralPath $file.FullName)) {
        $lineNo++
        foreach ($ch in $line.ToCharArray()) {
            if ([int]$ch -gt 127) {
                [pscustomobject]@{
                    Script = $file.Name
                    Line   = $lineNo
                    Char   = $ch
                    Code   = 'U+{0:X4}' -f [int]$ch
                }
            }
        }
    }
}

if ($nonAscii) {
    $nonAscii | Format-Table -AutoSize
    Write-Status "[X] Non-ASCII characters found. Windows PowerShell 5.1 will mangle these." 'Red'
    Write-Status "    Replace them with ASCII (em dash -> --, check mark -> [OK], etc.)." 'Yellow'
    exit 1
}

Write-Status "[OK] All scripts are pure ASCII!" 'Green'
exit 0
