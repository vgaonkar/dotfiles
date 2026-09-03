<#
.SYNOPSIS
    Fixes a Windows Update driver that installs forever and nags on every shutdown.

.DESCRIPTION
    Symptom this solves: Windows Update shows a vendor driver (e.g. Canon 2.90.2.30)
    as pending, the install fails every time (typically 0x800f020b), and Windows asks
    to "update and shut down" on every shutdown because the pending-reboot flag never
    clears.

    Root cause is almost always an orphaned vendor driver package left in the driver
    store: Windows Update offers a driver for a device/print-queue whose old package is
    stale, the install fails against the missing device, and the queued job replays.

    Phases:
      1. Diagnose  - pending-reboot flags, failed update history, matching driver packages
      2. Back up   - pnputil /export-driver each matched package, then VERIFY the export
      3. Purge     - remove printers, printer drivers, and the driver-store packages
      4. Reset     - stop update services, rename SoftwareDistribution + catroot2
      5. Block     - (opt-in) stop Windows Update from offering drivers at all

    DRY RUN BY DEFAULT. Nothing is changed until you pass -Execute.

.PARAMETER Vendor
    Case-insensitive regex matched against driver provider / printer driver names.
    Default 'Canon'.

.PARAMETER Execute
    Actually make changes. Without this the script only reports what it would do.

.PARAMETER DisableDriverUpdate
    Also set the policy that stops Windows Update from delivering drivers, so the
    failing driver is not re-offered. Backs up the registry key first.

.PARAMETER SkipDriverPurge
    Skip phases 2-3 (backup + purge). Use when you only want the update-state reset.

.PARAMETER SkipUpdateReset
    Skip phase 4 (SoftwareDistribution / catroot2 reset).

.PARAMETER BackupRoot
    Where driver exports, registry exports, and the run log are written.

.EXAMPLE
    .\fix-stuck-driver-update.ps1
    Dry run against Canon. Shows the diagnosis and every action it would take.

.EXAMPLE
    .\fix-stuck-driver-update.ps1 -Execute -DisableDriverUpdate
    Full fix, plus block Windows Update from pushing drivers again.

.EXAMPLE
    .\fix-stuck-driver-update.ps1 -Vendor 'Brother' -Execute
    Same fix for a different vendor.

.NOTES
    Requires an elevated PowerShell session (Run as Administrator).
    Reboot after a successful -Execute run, then reinstall the driver from the
    vendor's own site -- not from Windows Update.
#>

[CmdletBinding()]
param(
    [string]$Vendor = 'Canon',
    [switch]$Execute,
    [switch]$DisableDriverUpdate,
    [switch]$SkipDriverPurge,
    [switch]$SkipUpdateReset,
    [string]$BackupRoot = "$env:USERPROFILE\dotfiles-backups\driver-fix"
)

$ErrorActionPreference = 'Stop'

# -- Output helpers -----------------------------------------------------------
# $Host.UI.WriteLine keeps colour without tripping PSAvoidUsingWriteHost.

function Write-Status {
    param(
        [string]$Message = '',
        [string]$Color = 'Gray'
    )
    $Host.UI.WriteLine($Color, $Host.UI.RawUI.BackgroundColor, $Message)
}

function Write-Phase {
    param([string]$Message = '')
    Write-Status ''
    Write-Status "== $Message" 'Cyan'
}

function Write-Plan {
    param([string]$Message = '')
    if ($Execute) {
        Write-Status "   -> $Message" 'White'
    } else {
        Write-Status "   [dry run] would: $Message" 'DarkGray'
    }
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identity
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# -- Diagnosis ----------------------------------------------------------------

function Get-PendingRebootFlag {
    $flags = @()
    $cbs = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    $wu = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $sm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'

    if (Test-Path $cbs) { $flags += 'CBS RebootPending' }
    if (Test-Path $wu) { $flags += 'WindowsUpdate RebootRequired' }

    $pending = Get-ItemProperty -Path $sm -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
    if ($null -ne $pending -and $pending.PendingFileRenameOperations) {
        $flags += "PendingFileRenameOperations ($($pending.PendingFileRenameOperations.Count) entries)"
    }
    return $flags
}

function Get-UpdateFailure {
    param([string]$Match = '')

    $results = @()
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        $count = $searcher.GetTotalHistoryCount()
        if ($count -le 0) { return $results }

        foreach ($entry in $searcher.QueryHistory(0, $count)) {
            if ($entry.Title -notmatch $Match) { continue }
            # ResultCode: 1 in progress, 2 succeeded, 3 succeeded w/ errors, 4 failed, 5 aborted
            if ($entry.ResultCode -eq 2) { continue }
            $results += [pscustomobject]@{
                Date  = $entry.Date
                Title = $entry.Title
                Code  = '0x{0:x8}' -f $entry.HResult
                Result = switch ($entry.ResultCode) {
                    1 { 'InProgress' }
                    3 { 'SucceededWithErrors' }
                    4 { 'Failed' }
                    5 { 'Aborted' }
                    default { "Unknown($($entry.ResultCode))" }
                }
            }
        }
    } catch {
        Write-Status "   (could not read update history: $($_.Exception.Message))" 'Yellow'
    }
    return $results
}

function Get-VendorDriverPackage {
    param([string]$Match = '')

    $packages = @()
    try {
        $packages = Get-WindowsDriver -Online -All |
            Where-Object { $_.ProviderName -match $Match -or $_.OriginalFileName -match $Match } |
            Select-Object Driver, OriginalFileName, ProviderName, ClassName, Version, Date
    } catch {
        Write-Status "   (Get-WindowsDriver failed: $($_.Exception.Message))" 'Yellow'
        Write-Status '   Fall back to: pnputil /enum-drivers' 'Yellow'
    }
    return $packages
}

# -- Actions ------------------------------------------------------------------

function Export-VendorDriver {
    param(
        [object[]]$Package = @(),
        [string]$Destination = ''
    )

    if (-not $Execute) {
        foreach ($pkg in $Package) { Write-Plan "export $($pkg.Driver) to $Destination" }
        return $true
    }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $exported = 0

    foreach ($pkg in $Package) {
        $target = Join-Path $Destination ($pkg.Driver -replace '\.inf$', '')
        New-Item -ItemType Directory -Force -Path $target | Out-Null
        Write-Status "   -> exporting $($pkg.Driver)" 'White'

        $ErrorActionPreference = 'Continue'
        & pnputil.exe /export-driver $pkg.Driver $target 2>&1 | Out-Null
        $ErrorActionPreference = 'Stop'

        $files = Get-ChildItem -Path $target -Recurse -File -ErrorAction SilentlyContinue
        if ($files -and $files.Count -gt 0) {
            $exported++
            Write-Status "      backed up $($files.Count) file(s)" 'Green'
        } else {
            Write-Status "      WARNING: export produced no files for $($pkg.Driver)" 'Red'
        }
    }

    # Global safety rule: never delete until the backup is confirmed on disk.
    if ($exported -ne $Package.Count) {
        Write-Status ''
        Write-Status "   BACKUP INCOMPLETE: $exported of $($Package.Count) packages exported." 'Red'
        Write-Status '   Refusing to delete anything. Investigate before re-running.' 'Red'
        return $false
    }
    return $true
}

function Remove-VendorDriver {
    param(
        [object[]]$Package = @(),
        [string]$Match = ''
    )

    # 1. Printer queues using the vendor driver
    $printers = @()
    try {
        $printers = Get-Printer -ErrorAction SilentlyContinue |
            Where-Object { $_.DriverName -match $Match }
    } catch {
        # PrintManagement module absent (e.g. Server Core) -- not fatal, skip this step.
        Write-Status "   (Get-Printer unavailable: $($_.Exception.Message))" 'Yellow'
    }

    foreach ($printer in $printers) {
        Write-Plan "remove printer '$($printer.Name)' (driver: $($printer.DriverName))"
        if ($Execute) {
            try {
                Remove-Printer -Name $printer.Name
                Write-Status "      removed printer $($printer.Name)" 'Green'
            } catch {
                Write-Status "      WARNING: could not remove $($printer.Name): $($_.Exception.Message)" 'Yellow'
            }
        }
    }

    # 2. Printer drivers registered with the spooler
    $drivers = @()
    try {
        $drivers = Get-PrinterDriver -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $Match }
    } catch {
        # PrintManagement module absent -- pnputil below still handles the driver store.
        Write-Status "   (Get-PrinterDriver unavailable: $($_.Exception.Message))" 'Yellow'
    }

    if ($drivers.Count -gt 0) {
        Write-Plan 'restart the print spooler to release driver locks'
        if ($Execute) { Restart-Service -Name Spooler -Force }
    }

    foreach ($driver in $drivers) {
        Write-Plan "remove printer driver '$($driver.Name)'"
        if ($Execute) {
            try {
                Remove-PrinterDriver -Name $driver.Name -RemoveFromDriverStore -ErrorAction Stop
                Write-Status "      removed printer driver $($driver.Name)" 'Green'
            } catch {
                # -RemoveFromDriverStore is unavailable on some builds; retry without it.
                try {
                    Remove-PrinterDriver -Name $driver.Name -ErrorAction Stop
                    Write-Status "      removed printer driver $($driver.Name) (store entry left for pnputil)" 'Green'
                } catch {
                    Write-Status "      WARNING: could not remove $($driver.Name): $($_.Exception.Message)" 'Yellow'
                }
            }
        }
    }

    # 3. Driver-store packages
    foreach ($pkg in $Package) {
        Write-Plan "delete driver package $($pkg.Driver) [$($pkg.ProviderName) $($pkg.Version)]"
        if ($Execute) {
            $ErrorActionPreference = 'Continue'
            $output = & pnputil.exe /delete-driver $pkg.Driver /uninstall /force 2>&1
            $code = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'
            if ($code -eq 0) {
                Write-Status "      deleted $($pkg.Driver)" 'Green'
            } else {
                Write-Status "      WARNING: pnputil exit $code for $($pkg.Driver)" 'Yellow'
                Write-Status "      $output" 'DarkGray'
            }
        }
    }

    # 4. Ghost (disconnected) devices still holding the driver
    $ghosts = @()
    try {
        $ghosts = Get-PnpDevice -ErrorAction SilentlyContinue |
            Where-Object { $_.FriendlyName -match $Match -and $_.Status -eq 'Unknown' }
    } catch {
        # PnpDevice cmdlets absent -- remove ghosts manually via Device Manager
        # (View > Show hidden devices).
        Write-Status "   (Get-PnpDevice unavailable: $($_.Exception.Message))" 'Yellow'
    }

    foreach ($ghost in $ghosts) {
        Write-Plan "remove ghost device '$($ghost.FriendlyName)' ($($ghost.InstanceId))"
        if ($Execute) {
            $ErrorActionPreference = 'Continue'
            & pnputil.exe /remove-device $ghost.InstanceId 2>&1 | Out-Null
            $ErrorActionPreference = 'Stop'
            Write-Status "      removed $($ghost.FriendlyName)" 'Green'
        }
    }
}

function Reset-UpdateComponent {
    $services = @('wuauserv', 'bits', 'cryptsvc', 'msiserver', 'usosvc')
    $folders = @(
        "$env:SystemRoot\SoftwareDistribution",
        "$env:SystemRoot\System32\catroot2"
    )
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    foreach ($svc in $services) { Write-Plan "stop service $svc" }
    foreach ($folder in $folders) {
        if (Test-Path $folder) { Write-Plan "rename $folder -> $(Split-Path $folder -Leaf).old.$stamp" }
    }
    foreach ($svc in $services) { Write-Plan "start service $svc" }

    if (-not $Execute) { return }

    foreach ($svc in $services) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($null -eq $service) { continue }
        try {
            Stop-Service -Name $svc -Force -ErrorAction Stop
            Write-Status "      stopped $svc" 'Green'
        } catch {
            Write-Status "      WARNING: could not stop $svc : $($_.Exception.Message)" 'Yellow'
        }
    }

    Start-Sleep -Seconds 3

    foreach ($folder in $folders) {
        if (-not (Test-Path $folder)) { continue }
        $newName = "$(Split-Path $folder -Leaf).old.$stamp"
        try {
            Rename-Item -Path $folder -NewName $newName -ErrorAction Stop
            Write-Status "      renamed $folder -> $newName" 'Green'
        } catch {
            Write-Status "      WARNING: could not rename $folder : $($_.Exception.Message)" 'Yellow'
            Write-Status '      A service still holds it. Reboot and re-run with -SkipDriverPurge.' 'Yellow'
        }
    }

    foreach ($svc in $services) {
        $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($null -eq $service) { continue }
        try {
            Start-Service -Name $svc -ErrorAction Stop
            Write-Status "      started $svc" 'Green'
        } catch {
            Write-Status "      WARNING: could not start $svc : $($_.Exception.Message)" 'Yellow'
        }
    }
}

function Disable-DriverUpdate {
    param([string]$Destination = '')

    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $regPath = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $backup = Join-Path $Destination 'WindowsUpdate-policy.reg'

    Write-Plan "export $regPath -> $backup"
    Write-Plan 'set ExcludeWUDriversInQualityUpdate = 1 (Windows Update stops offering drivers)'

    if (-not $Execute) { return }

    New-Item -ItemType Directory -Force -Path $Destination | Out-Null
    $ErrorActionPreference = 'Continue'
    & reg.exe export $regPath $backup /y 2>&1 | Out-Null
    $ErrorActionPreference = 'Stop'
    if (Test-Path $backup) {
        Write-Status "      registry backed up to $backup" 'Green'
    } else {
        Write-Status '      (no existing policy key to back up -- it will be created)' 'DarkGray'
    }

    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    Set-ItemProperty -Path $key -Name 'ExcludeWUDriversInQualityUpdate' -Value 1 -Type DWord
    Write-Status '      driver delivery via Windows Update disabled' 'Green'
    Write-Status '      undo with:' 'DarkGray'
    Write-Status "        Remove-ItemProperty -Path '$key' -Name ExcludeWUDriversInQualityUpdate" 'DarkGray'
}

# -- Main ---------------------------------------------------------------------

Write-Status ''
Write-Status '=================================================' 'Cyan'
Write-Status "  Stuck driver update fix  --  vendor: $Vendor" 'Cyan'
Write-Status '=================================================' 'Cyan'

if (-not (Test-Administrator)) {
    Write-Status ''
    Write-Status 'ERROR: this script must run in an elevated PowerShell session.' 'Red'
    Write-Status 'Right-click PowerShell/Terminal > Run as Administrator, then re-run.' 'Yellow'
    exit 1
}

if ($Execute) {
    Write-Status ''
    Write-Status 'MODE: EXECUTE -- changes will be made.' 'Yellow'
} else {
    Write-Status ''
    Write-Status 'MODE: DRY RUN -- nothing will be changed. Add -Execute to apply.' 'Green'
}

$runStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $BackupRoot $runStamp
$transcript = $null

if ($Execute) {
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    $transcript = Join-Path $runDir 'run.log'
    Start-Transcript -Path $transcript | Out-Null
}

try {
    # -- Phase 1: diagnose ----------------------------------------------------
    Write-Phase 'Phase 1/5  Diagnose'

    $rebootFlags = Get-PendingRebootFlag
    if ($rebootFlags.Count -gt 0) {
        Write-Status '   Pending-reboot flags set (this is the shutdown nag):' 'Yellow'
        foreach ($flag in $rebootFlags) { Write-Status "     - $flag" 'White' }
    } else {
        Write-Status '   No pending-reboot flags set.' 'Green'
    }

    Write-Status ''
    $failures = Get-UpdateFailure -Match $Vendor
    if ($failures.Count -gt 0) {
        Write-Status "   Non-successful update history matching '$Vendor':" 'Yellow'
        foreach ($f in $failures) {
            Write-Status "     $($f.Date.ToString('yyyy-MM-dd HH:mm'))  $($f.Result)  $($f.Code)" 'White'
            Write-Status "       $($f.Title)" 'DarkGray'
        }
        if ($failures.Code -contains '0x800f020b') {
            Write-Status '   0x800f020b confirms the orphaned-driver diagnosis.' 'Green'
        }
        if ($failures.Code -contains '0x80070103') {
            Write-Status '   NOTE: 0x80070103 means the driver is already installed and Windows' 'Yellow'
            Write-Status '   Update is offering a downgrade. Skip the purge -- run with' 'Yellow'
            Write-Status '   -SkipDriverPurge -DisableDriverUpdate instead.' 'Yellow'
        }
    } else {
        Write-Status "   No failed update history matching '$Vendor'." 'Green'
    }

    Write-Status ''
    $packages = @(Get-VendorDriverPackage -Match $Vendor)
    if ($packages.Count -gt 0) {
        Write-Status "   Driver-store packages matching '$Vendor':" 'Yellow'
        foreach ($pkg in $packages) {
            Write-Status "     $($pkg.Driver)  $($pkg.ProviderName)  $($pkg.ClassName)  v$($pkg.Version)" 'White'
            Write-Status "       original: $($pkg.OriginalFileName)" 'DarkGray'
        }
    } else {
        Write-Status "   No driver-store packages match '$Vendor'." 'Green'
    }

    # -- Phase 2 + 3: back up, then purge -------------------------------------
    if ($SkipDriverPurge) {
        Write-Phase 'Phase 2/5  Back up driver packages  [SKIPPED]'
        Write-Phase 'Phase 3/5  Purge driver packages  [SKIPPED]'
    } elseif ($packages.Count -eq 0) {
        Write-Phase 'Phase 2/5  Back up driver packages  [nothing to back up]'
        Write-Phase 'Phase 3/5  Purge driver packages  [nothing to purge]'
    } else {
        Write-Phase 'Phase 2/5  Back up driver packages'
        $driverBackup = Join-Path $runDir 'drivers'
        $backupOk = Export-VendorDriver -Package $packages -Destination $driverBackup
        if (-not $backupOk) {
            Write-Status ''
            Write-Status 'Aborting before any deletion. Backup verification failed.' 'Red'
            exit 2
        }

        Write-Phase 'Phase 3/5  Purge driver packages'
        Remove-VendorDriver -Package $packages -Match $Vendor
    }

    # -- Phase 4: reset update state ------------------------------------------
    if ($SkipUpdateReset) {
        Write-Phase 'Phase 4/5  Reset Windows Update state  [SKIPPED]'
    } else {
        Write-Phase 'Phase 4/5  Reset Windows Update state'
        Write-Status '   The old folders are renamed, not deleted -- Windows rebuilds them.' 'DarkGray'
        Reset-UpdateComponent
    }

    # -- Phase 5: block driver delivery ---------------------------------------
    if ($DisableDriverUpdate) {
        Write-Phase 'Phase 5/5  Block Windows Update driver delivery'
        Disable-DriverUpdate -Destination $runDir
    } else {
        Write-Phase 'Phase 5/5  Block Windows Update driver delivery  [SKIPPED]'
        Write-Status '   Re-run with -DisableDriverUpdate if the driver comes back.' 'DarkGray'
    }

    # -- Summary --------------------------------------------------------------
    Write-Status ''
    Write-Status '=================================================' 'Green'
    if ($Execute) {
        Write-Status '  Done. Next steps:' 'Green'
        Write-Status '=================================================' 'Green'
        Write-Status ''
        Write-Status '  1. REBOOT now.' 'White'
        Write-Status '  2. Shut down twice and confirm the update nag is gone.' 'White'
        Write-Status "  3. Install the driver from $Vendor's own website, not Windows Update." 'White'
        Write-Status '  4. If the nag persists, a real servicing operation is pending:' 'White'
        Write-Status '       dism /online /cleanup-image /restorehealth' 'DarkGray'
        Write-Status '       sfc /scannow' 'DarkGray'
        Write-Status ''
        Write-Status "  Backups + log: $runDir" 'Cyan'
        Write-Status '  Restore a driver: pnputil /add-driver <path-to-inf> /install' 'DarkGray'
    } else {
        Write-Status '  Dry run complete. Nothing was changed.' 'Green'
        Write-Status '=================================================' 'Green'
        Write-Status ''
        Write-Status '  Review the plan above, then run:' 'White'
        Write-Status "    .\fix-stuck-driver-update.ps1 -Vendor $Vendor -Execute" 'Cyan'
    }
    Write-Status ''
} finally {
    if ($transcript) { Stop-Transcript | Out-Null }
}
