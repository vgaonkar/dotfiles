#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

function Write-Header([string]$Message) { Write-Host $Message -ForegroundColor Blue }
function Write-Info([string]$Message) { Write-Host "INFO $Message" -ForegroundColor Blue }
function Write-Ok([string]$Message) { Write-Host "OK   $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) { Write-Host "WARN $Message" -ForegroundColor Yellow }
function Write-Err([string]$Message) { Write-Host "ERR  $Message" -ForegroundColor Red }

trap [System.Management.Automation.PipelineStoppedException] {
    Write-Warn "Cancelled. You can re-run this script safely."
    exit 1
}

trap [System.OperationCanceledException] {
    Write-Warn "Cancelled. You can re-run this script safely."
    exit 1
}

function To-Bool([string]$Value) {
    if ($null -eq $Value) { return $false }
    switch ($Value.ToLowerInvariant()) {
        "true" { return $true }
        "1" { return $true }
        "yes" { return $true }
        "y" { return $true }
        default { return $false }
    }
}

function Ensure-EnvDefault([string]$Name, [string]$DefaultValue) {
    $current = $null
    try {
        $item = Get-Item -Path ("Env:{0}" -f $Name) -ErrorAction SilentlyContinue
        if ($null -ne $item) {
            $current = $item.Value
        }
    } catch {
        $current = $null
    }

    if ([string]::IsNullOrEmpty($current)) {
        Set-Item -Path ("Env:{0}" -f $Name) -Value $DefaultValue
        $current = $DefaultValue
    }

    return $current
}

function Ensure-Chezmoi {
    if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
        Write-Ok "chezmoi already installed"
        return
    }

    Write-Info "Installing chezmoi (get.chezmoi.io)"
    Invoke-Expression (Invoke-RestMethod -Uri "https://get.chezmoi.io")

    $localBin = Join-Path $env:USERPROFILE ".local\bin"
    if (Test-Path (Join-Path $localBin "chezmoi.exe")) {
        $env:PATH = "$localBin;$env:PATH"
    }

    if (-not (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
        throw "chezmoi installation completed but chezmoi is not in PATH (expected $localBin\\chezmoi.exe)"
    }

    Write-Ok "chezmoi installed"
}

function Install-GhWithWinget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
    Write-Info "Installing gh via winget"
    & winget install -e --id GitHub.cli --source winget --accept-package-agreements --accept-source-agreements | Out-Null
    return $true
}

function Install-GhWithScoop {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { return $false }
    Write-Info "Installing gh via scoop"
    & scoop install gh | Out-Null
    return $true
}

function Add-ToPathIfExeExists([string]$Dir, [string]$ExeName) {
    if ([string]::IsNullOrEmpty($Dir)) { return $false }

    $exePath = $null
    try {
        $exePath = Join-Path $Dir $ExeName
    } catch {
        return $false
    }

    if (-not (Test-Path -LiteralPath $exePath)) { return $false }

    $currentPath = $env:PATH
    $parts = @()
    if (-not [string]::IsNullOrEmpty($currentPath)) {
        $parts = $currentPath -split ";"
    }

    $dirNorm = $Dir.Trim().TrimEnd("\\")
    foreach ($p in $parts) {
        if ($p.Trim().TrimEnd("\\") -ieq $dirNorm) {
            return $false
        }
    }

    if ([string]::IsNullOrEmpty($currentPath)) {
        $env:PATH = $Dir
    } else {
        $env:PATH = "$Dir;$currentPath"
    }

    return $true
}

function Refresh-PathForGh {
    $changed = $false
    $candidateDirs = @()

    if (-not [string]::IsNullOrEmpty($env:ProgramFiles)) {
        $candidateDirs += (Join-Path $env:ProgramFiles "GitHub CLI")
    }

    $programFilesX86 = ${env:ProgramFiles(x86)}
    if (-not [string]::IsNullOrEmpty($programFilesX86)) {
        $candidateDirs += (Join-Path $programFilesX86 "GitHub CLI")
    }

    if (-not [string]::IsNullOrEmpty($env:USERPROFILE)) {
        $candidateDirs += (Join-Path $env:USERPROFILE "scoop\shims")
    }

    foreach ($dir in $candidateDirs) {
        try {
            if (Add-ToPathIfExeExists -Dir $dir -ExeName "gh.exe") {
                $changed = $true
            }
        } catch {
            # best-effort; ignore
        }
    }

    return $changed
}

function Ensure-Gh {
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Write-Ok "gh already installed"
        return
    }

    $installed = $false
    try {
        $installed = (Install-GhWithWinget)
    } catch {
        $installed = $false
    }

    if (-not $installed) {
        try {
            $installed = (Install-GhWithScoop)
        } catch {
            $installed = $false
        }
    }

    if (-not $installed) {
        throw "No supported package manager found (winget/scoop). Please install GitHub CLI manually: https://cli.github.com"
    }

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        $refreshed = $false
        try {
            $refreshed = (Refresh-PathForGh)
        } catch {
            $refreshed = $false
        }

        if ($refreshed -and (Get-Command gh -ErrorAction SilentlyContinue)) {
            Write-Ok "gh discovered after PATH refresh"
        } else {
            throw "gh installation completed but gh is not in PATH"
        }
    }

    Write-Ok "gh installed"
}

function Test-GhAuth([string]$Hostname) {
    & gh auth status --hostname $Hostname 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}

function Ensure-GhAuth([string]$Hostname, [bool]$Headless, [bool]$NonInteractive) {
    if (Test-GhAuth -Hostname $Hostname) {
        Write-Ok "gh authenticated for $Hostname"
        return
    }

    if (-not [string]::IsNullOrEmpty($env:GH_TOKEN)) {
        Write-Warn "GH_TOKEN is set but gh has no stored auth; continuing without interactive login"
        return
    }

    if ($NonInteractive) {
        throw "Non-interactive mode detected but no GH_TOKEN provided. Run in a TTY to complete 'gh auth login', or set GH_TOKEN."
    }

    Write-Info "Authenticating with GitHub ($Hostname)"

    $oldBrowser = $env:BROWSER
    try {
        if ($Headless) {
            Write-Info "Headless mode detected (BROWSER=false or GH_BROWSER=none); using device-code flow"
            Write-Info "Follow the prompts from gh: open the URL it prints and enter the one-time code."
            $env:BROWSER = "false"
        }

        & gh auth login --web --hostname $Hostname --git-protocol https -s repo
        if ($LASTEXITCODE -ne 0) {
            throw "gh auth login failed"
        }
    } finally {
        $env:BROWSER = $oldBrowser
    }

    if (-not (Test-GhAuth -Hostname $Hostname)) {
        throw "Authentication failed or was cancelled. Bootstrap cannot proceed without GitHub access."
    }

    Write-Ok "gh authenticated"
}

function Maybe-SetupGit([string]$Hostname, [bool]$Skip) {
    if ($Skip) {
        Write-Warn "Skipping 'gh auth setup-git' (DOTFILES_NO_GH_SETUP_GIT=true)"
        return
    }
    Write-Info "Configuring git to use gh for HTTPS auth"
    & gh auth setup-git --hostname $Hostname
    if ($LASTEXITCODE -ne 0) {
        throw "gh auth setup-git failed"
    }
    Write-Ok "gh auth setup-git complete"
}

function Run-Chezmoi {
    Write-Info "Applying dotfiles with chezmoi"

    $sourcePath = $null
    try {
        $sourcePath = (& chezmoi source-path 2>$null | Select-Object -First 1)
        if (-not [string]::IsNullOrEmpty($sourcePath)) {
            $sourcePath = $sourcePath.Trim()
        }
    } catch {
        $sourcePath = $null
    }

    $shouldApply = $false
    if (-not [string]::IsNullOrEmpty($sourcePath)) {
        try {
            $gitDir = Join-Path $sourcePath ".git"
            if (Test-Path -LiteralPath $gitDir -PathType Container) {
                $shouldApply = $true
            }
        } catch {
            $shouldApply = $false
        }
    }

    if ($shouldApply) {
        & chezmoi apply
        if ($LASTEXITCODE -ne 0) {
            throw "chezmoi apply/init failed"
        }
    } else {
        $overrideData = '{"git":{"user_name":"","user_email":""}}'
        $errPath = $null
        try {
            $errPath = (New-TemporaryFile).FullName
        } catch {
            $errPath = [System.IO.Path]::GetTempFileName()
        }

        try {
            $p = Start-Process -FilePath "chezmoi" -ArgumentList @("init", "--apply", "vgaonkar") -NoNewWindow -Wait -PassThru -RedirectStandardError $errPath
            if ($p.ExitCode -ne 0) {
                $errText = ""
                try {
                    $errText = (Get-Content -LiteralPath $errPath -Raw -ErrorAction SilentlyContinue)
                } catch {
                    $errText = ""
                }

                if ((-not [string]::IsNullOrEmpty($errText)) -and $errText.Contains('map has no entry for key "git"')) {
                    Write-Warn "chezmoi init failed due to missing git template data; retrying with minimal override-data"
                    Remove-Item -LiteralPath $errPath -Force -ErrorAction SilentlyContinue
                    $p = Start-Process -FilePath "chezmoi" -ArgumentList @("init", "--apply", "vgaonkar", "--override-data", $overrideData) -NoNewWindow -Wait -PassThru -RedirectStandardError $errPath
                } else {
                    if (-not [string]::IsNullOrEmpty($errText)) {
                        Write-Host $errText
                    }
                }

                if ($p.ExitCode -ne 0) {
                    throw "chezmoi apply/init failed"
                }
            }
        } finally {
            if (-not [string]::IsNullOrEmpty($errPath)) {
                Remove-Item -LiteralPath $errPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Ok "chezmoi apply complete"
}

$DotfilesGithubHost = Ensure-EnvDefault -Name "DOTFILES_GITHUB_HOST" -DefaultValue "github.com"
$DotfilesGitProtocol = Ensure-EnvDefault -Name "DOTFILES_GIT_PROTOCOL" -DefaultValue "https"
$DotfilesNoGhSetupGit = Ensure-EnvDefault -Name "DOTFILES_NO_GH_SETUP_GIT" -DefaultValue "false"

Write-Header "Dotfiles Bootstrap (Windows)"
Write-Info "GitHub host: $DotfilesGithubHost"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-Warn "Warning: Running as Administrator. Some features may not work correctly."
    Write-Warn "It's recommended to run this as a regular user."
}

if ($DotfilesGitProtocol.ToLowerInvariant() -ne "https") {
    Write-Warn "DOTFILES_GIT_PROTOCOL='$DotfilesGitProtocol' ignored for bootstrap; forcing https"
}

$hasTty = (-not [Console]::IsInputRedirected) -and (-not [Console]::IsOutputRedirected)
$ci = ($env:CI -eq "true") -or ($env:CI -eq "1")
$debianNonInteractive = ($env:DEBIAN_FRONTEND -eq "noninteractive")
$nonInteractive = (-not $hasTty) -or $ci -or $debianNonInteractive

$headless = (([string]$env:BROWSER).ToLowerInvariant() -eq "false") -or (([string]$env:GH_BROWSER).ToLowerInvariant() -eq "none")

Ensure-Chezmoi
Ensure-Gh
Ensure-GhAuth -Hostname $DotfilesGithubHost -Headless:$headless -NonInteractive:$nonInteractive
Maybe-SetupGit -Hostname $DotfilesGithubHost -Skip:(To-Bool $DotfilesNoGhSetupGit)
Run-Chezmoi

Write-Ok "Bootstrap complete"
