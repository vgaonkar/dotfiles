<#
.SYNOPSIS
    Fixes a Windows Update driver that installs forever and nags on every shutdown.

.DESCRIPTION
    Symptom this solves: Windows Update shows a vendor driver (e.g. Canon 2.90.2.30)
    as pending, the install fails every time (typically 0x800f020b), and Windows asks
    to "update and shut down" on every shutdown because the pending-reboot flag never
    clears.

    Root cause is normally an orphaned vendor driver package in the driver store: the
    update targets a device or print queue whose old package is stale, the install
    fails against the missing device, and the queued job replays forever.

    Phases:
      1. Diagnose  - pending-reboot flags, failed update history, matching packages
      2. Back up   - pnputil /export-driver each package, then VERIFY the export
      3. Purge     - remove printers, printer drivers, packages, ghost devices
      4. Reset     - stop update services, rename SoftwareDistribution + catroot2
      5. Block     - (opt-in) stop the driver being offered again
      6. Repair    - (opt-in) DISM restorehealth + sfc /scannow

    DRY RUN BY DEFAULT. Nothing changes until you pass -Execute.

    After rebooting, re-run with -Verify to confirm the fix actually held. Verify
    compares against the diagnosis.json snapshot written during the -Execute run.

.PARAMETER Vendor
    Case-insensitive regex matched against driver provider and printer driver names.
    Default 'Canon'.

.PARAMETER Execute
    Actually make changes. Without this the script only reports what it would do.

.PARAMETER Verify
    Read-only post-reboot check: pending-reboot flags cleared, vendor packages gone,
    no new failed updates. Compares against the last run's diagnosis.json. Exits 3 if
    verification fails. Cannot be combined with -Execute.

.PARAMETER DisableDriverUpdate
    Blunt block: stop Windows Update delivering ANY drivers. Backs up the registry
    key first. Use when you want no driver updates at all.

.PARAMETER BlockByHardwareId
    Surgical block: deny installation of only the matched device's hardware IDs via
    Device Installation Restrictions. Leaves GPU/chipset driver updates working.
    Prefer this over -DisableDriverUpdate.

.PARAMETER RepairImage
    Run 'dism /online /cleanup-image /restorehealth' then 'sfc /scannow'. Use when a
    pending-reboot flag survives the update reset. Slow: typically 10-30 minutes.

.PARAMETER SkipDriverPurge
    Skip phases 2-3 (backup + purge). Use when you only want the update-state reset.

.PARAMETER SkipUpdateReset
    Skip phase 4 (SoftwareDistribution / catroot2 reset).

.PARAMETER BackupRoot
    Where driver exports, registry exports, snapshots, and run logs are written.

.EXAMPLE
    .\fix-stuck-driver-update.ps1
    Dry run against Canon. Shows the diagnosis and every action it would take.

.EXAMPLE
    .\fix-stuck-driver-update.ps1 -Execute -BlockByHardwareId
    Full fix, blocking only the Canon device from being reinstalled.

.EXAMPLE
    .\fix-stuck-driver-update.ps1 -Verify
    After rebooting: confirm the flags cleared and the packages are gone.

.EXAMPLE
    .\fix-stuck-driver-update.ps1 -Execute -SkipDriverPurge -RepairImage
    Reset update state and repair the component store, without touching drivers.

.NOTES
    Requires an elevated PowerShell session (Run as Administrator).
    Reboot after a successful -Execute run, re-run with -Verify, then install the
    driver from the vendor's own site -- not from Windows Update.

    Exit codes: 0 ok, 1 not elevated / bad arguments, 2 backup verification failed,
    3 -Verify found the fix did not hold.
#>

[CmdletBinding()]
param(
    [string]$Vendor = 'Canon',
    [switch]$Execute,
    [switch]$Verify,
    [switch]$DisableDriverUpdate,
    [switch]$BlockByHardwareId,
    [switch]$RepairImage,
    [switch]$SkipDriverPurge,
    [switch]$SkipUpdateReset,
    [string]$BackupRoot = "$env:USERPROFILE\dotfiles-backups\driver-fix"
)

$ErrorActionPreference = 'Stop'
$script:WarningCount = 0

# -- Output helpers -----------------------------------------------------------
# $Host.UI.WriteLine keeps colour without tripping PSAvoidUsingWriteHost.

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

function Write-Phase {
    param([string]$Message = '')
    Write-Status ''
    Write-Status "== $Message" 'Cyan'
}

function Write-Warn {
    param([string]$Message = '')
    $script:WarningCount++
    Write-Status "      WARNING: $Message" 'Yellow'
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

function Get-VendorDevice {
    param([string]$Match = '')

    $devices = @()
    try {
        $devices = Get-PnpDevice -ErrorAction SilentlyContinue |
            Where-Object { $_.FriendlyName -match $Match -or $_.InstanceId -match $Match }
    } catch {
        # PnpDevice cmdlets absent -- inspect manually in Device Manager
        # (View > Show hidden devices).
        Write-Status "   (Get-PnpDevice unavailable: $($_.Exception.Message))" 'Yellow'
    }
    return $devices
}

function Get-VendorHardwareId {
    param([object[]]$Device = @())

    $ids = @()
    foreach ($dev in $Device) {
        try {
            $prop = Get-PnpDeviceProperty -InstanceId $dev.InstanceId `
                -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop
            if ($null -ne $prop -and $prop.Data) { $ids += $prop.Data }
        } catch {
            Write-Status "   (no hardware IDs for $($dev.InstanceId): $($_.Exception.Message))" 'DarkGray'
        }
    }
    return ($ids | Where-Object { $_ } | Sort-Object -Unique)
}

function Get-Diagnosis {
    param([string]$Match = '')

    $devices = @(Get-VendorDevice -Match $Match)
    return [pscustomobject]@{
        TakenAt        = (Get-Date).ToString('o')
        Vendor         = $Match
        ComputerName   = $env:COMPUTERNAME
        RebootFlag     = @(Get-PendingRebootFlag)
        UpdateFailure  = @(Get-UpdateFailure -Match $Match)
        DriverPackage  = @(Get-VendorDriverPackage -Match $Match)
        Device         = @($devices | Select-Object FriendlyName, InstanceId, Status, Class)
        HardwareId     = @(Get-VendorHardwareId -Device $devices)
    }
}

function Show-Diagnosis {
    param([object]$Diagnosis = $null)

    if ($Diagnosis.RebootFlag.Count -gt 0) {
        Write-Status '   Pending-reboot flags set (this is the shutdown nag):' 'Yellow'
        foreach ($flag in $Diagnosis.RebootFlag) { Write-Status "     - $flag" 'White' }
    } else {
        Write-Status '   No pending-reboot flags set.' 'Green'
    }

    Write-Status ''
    if ($Diagnosis.UpdateFailure.Count -gt 0) {
        Write-Status "   Non-successful update history matching '$($Diagnosis.Vendor)':" 'Yellow'
        foreach ($f in $Diagnosis.UpdateFailure) {
            Write-Status "     $($f.Date.ToString('yyyy-MM-dd HH:mm'))  $($f.Result)  $($f.Code)" 'White'
            Write-Status "       $($f.Title)" 'DarkGray'
        }
        if ($Diagnosis.UpdateFailure.Code -contains '0x800f020b') {
            Write-Status '   0x800f020b confirms the orphaned-driver diagnosis.' 'Green'
        }
        if ($Diagnosis.UpdateFailure.Code -contains '0x80070103') {
            Write-Status '   NOTE: 0x80070103 means the driver is already installed and Windows' 'Yellow'
            Write-Status '   Update is offering a downgrade. Skip the purge -- run with' 'Yellow'
            Write-Status '   -SkipDriverPurge -BlockByHardwareId instead.' 'Yellow'
        }
    } else {
        Write-Status "   No failed update history matching '$($Diagnosis.Vendor)'." 'Green'
    }

    Write-Status ''
    if ($Diagnosis.DriverPackage.Count -gt 0) {
        Write-Status "   Driver-store packages matching '$($Diagnosis.Vendor)':" 'Yellow'
        foreach ($pkg in $Diagnosis.DriverPackage) {
            Write-Status "     $($pkg.Driver)  $($pkg.ProviderName)  $($pkg.ClassName)  v$($pkg.Version)" 'White'
            Write-Status "       original: $($pkg.OriginalFileName)" 'DarkGray'
        }
    } else {
        Write-Status "   No driver-store packages match '$($Diagnosis.Vendor)'." 'Green'
    }

    if ($Diagnosis.HardwareId.Count -gt 0) {
        Write-Status ''
        Write-Status "   Hardware IDs matching '$($Diagnosis.Vendor)':" 'DarkGray'
        foreach ($id in $Diagnosis.HardwareId) { Write-Status "     $id" 'DarkGray' }
    }
}

function Save-Diagnosis {
    param(
        [object]$Diagnosis = $null,
        [string]$Path = ''
    )
    $Diagnosis | ConvertTo-Json -Depth 5 | Set-Content -Path $Path -Encoding UTF8
    Write-Status "   snapshot saved: $Path" 'DarkGray'
}

function Get-LastDiagnosis {
    param([string]$Root = '')

    if (-not (Test-Path $Root)) { return $null }
    $candidate = Get-ChildItem -Path $Root -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object { Join-Path $_.FullName 'diagnosis.json' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1

    if (-not $candidate) { return $null }
    try {
        return [pscustomobject]@{
            Path = $candidate
            Data = Get-Content -Path $candidate -Raw | ConvertFrom-Json
        }
    } catch {
        Write-Status "   (could not read $candidate : $($_.Exception.Message))" 'Yellow'
        return $null
    }
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
            Write-Warn "export produced no files for $($pkg.Driver)"
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
        Write-Warn "Get-Printer unavailable: $($_.Exception.Message)"
    }

    foreach ($printer in $printers) {
        Write-Plan "remove printer '$($printer.Name)' (driver: $($printer.DriverName))"
        if ($Execute) {
            try {
                Remove-Printer -Name $printer.Name
                Write-Status "      removed printer $($printer.Name)" 'Green'
            } catch {
                Write-Warn "could not remove $($printer.Name): $($_.Exception.Message)"
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
        Write-Warn "Get-PrinterDriver unavailable: $($_.Exception.Message)"
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
                    Write-Warn "could not remove $($driver.Name): $($_.Exception.Message)"
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
                Write-Warn "pnputil exit $code for $($pkg.Driver)"
                Write-Status "      $output" 'DarkGray'
            }
        }
    }

    # 4. Ghost (disconnected) devices still holding the driver
    $ghosts = @(Get-VendorDevice -Match $Match | Where-Object { $_.Status -eq 'Unknown' })

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
            Write-Warn "could not stop $svc : $($_.Exception.Message)"
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
            Write-Warn "could not rename $folder : $($_.Exception.Message)"
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
            Write-Warn "could not start $svc : $($_.Exception.Message)"
        }
    }
}

function Disable-DriverUpdate {
    param([string]$Destination = '')

    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $regPath = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $backup = Join-Path $Destination 'WindowsUpdate-policy.reg'

    Write-Plan "export $regPath -> $backup"
    Write-Plan 'set ExcludeWUDriversInQualityUpdate = 1 (blocks ALL Windows Update drivers)'

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
    Write-Status '      all Windows Update driver delivery disabled' 'Green'
    Write-Status '      undo with:' 'DarkGray'
    Write-Status "        Remove-ItemProperty -Path '$key' -Name ExcludeWUDriversInQualityUpdate" 'DarkGray'
}

function Disable-DeviceInstall {
    param(
        [string[]]$HardwareId = @(),
        [string]$Destination = ''
    )

    $key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
    $denyKey = "$key\DenyDeviceIDs"
    $regPath = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
    $backup = Join-Path $Destination 'DeviceInstall-policy.reg'

    if ($HardwareId.Count -eq 0) {
        Write-Status '   No hardware IDs were found for this vendor -- nothing to block.' 'Yellow'
        Write-Status '   The device may already be removed. Re-run before purging, or use' 'Yellow'
        Write-Status '   -DisableDriverUpdate for the blunt block.' 'Yellow'
        return
    }

    Write-Plan "export $regPath -> $backup"
    Write-Plan 'set DenyDeviceIDs = 1 and DenyDeviceIDsRetroactive = 1'
    foreach ($id in $HardwareId) { Write-Plan "deny hardware ID $id" }

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
    if (-not (Test-Path $denyKey)) { New-Item -Path $denyKey -Force | Out-Null }

    Set-ItemProperty -Path $key -Name 'DenyDeviceIDs' -Value 1 -Type DWord
    Set-ItemProperty -Path $key -Name 'DenyDeviceIDsRetroactive' -Value 1 -Type DWord

    # Existing entries are numbered "1", "2", ... -- append rather than clobber.
    $existing = @()
    $props = Get-ItemProperty -Path $denyKey -ErrorAction SilentlyContinue
    if ($null -ne $props) {
        $existing = @($props.PSObject.Properties |
            Where-Object { $_.Name -match '^\d+$' } |
            ForEach-Object { $_.Value })
    }

    $index = $existing.Count
    foreach ($id in $HardwareId) {
        if ($existing -contains $id) {
            Write-Status "      already denied: $id" 'DarkGray'
            continue
        }
        $index++
        Set-ItemProperty -Path $denyKey -Name "$index" -Value $id -Type String
        Write-Status "      denied $id" 'Green'
    }

    Write-Status '      device install blocked; other driver updates still work' 'Green'
    Write-Status '      undo with:' 'DarkGray'
    Write-Status "        Remove-Item -Path '$denyKey' -Recurse" 'DarkGray'
    Write-Status "        Set-ItemProperty -Path '$key' -Name DenyDeviceIDs -Value 0" 'DarkGray'
}

function Invoke-ImageRepair {
    Write-Plan 'run dism /online /cleanup-image /restorehealth (slow)'
    Write-Plan 'run sfc /scannow (slow)'

    if (-not $Execute) { return }

    Write-Status '   This takes 10-30 minutes. Do not interrupt.' 'Yellow'

    $ErrorActionPreference = 'Continue'
    & dism.exe /online /cleanup-image /restorehealth
    $dismCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($dismCode -eq 0) {
        Write-Status '      DISM restorehealth completed' 'Green'
    } else {
        Write-Warn "DISM exited $dismCode -- see $env:SystemRoot\Logs\DISM\dism.log"
    }

    $ErrorActionPreference = 'Continue'
    & sfc.exe /scannow
    $sfcCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($sfcCode -eq 0) {
        Write-Status '      sfc /scannow completed' 'Green'
    } else {
        Write-Warn "sfc exited $sfcCode -- see $env:SystemRoot\Logs\CBS\CBS.log"
    }
}

function Save-UpdateLog {
    param([string]$Destination = '')

    $target = Join-Path $Destination 'WindowsUpdate.log'
    Write-Status "   Capturing Windows Update log -> $target" 'Cyan'
    try {
        Get-WindowsUpdateLog -LogPath $target -ErrorAction Stop | Out-Null
        if (Test-Path $target) {
            Write-Status "      captured ($('{0:N0}' -f (Get-Item $target).Length) bytes)" 'Green'
        } else {
            Write-Status '      (Get-WindowsUpdateLog produced no file)' 'Yellow'
        }
    } catch {
        Write-Status "      (could not capture: $($_.Exception.Message))" 'Yellow'
        Write-Status "      Raw ETL traces remain in $env:SystemRoot\Logs\WindowsUpdate\" 'DarkGray'
    }
}

# -- Verification -------------------------------------------------------------

function Test-FixResult {
    param([string]$Match = '')

    $now = Get-Diagnosis -Match $Match
    $baseline = Get-LastDiagnosis -Root $BackupRoot
    $failures = @()

    Write-Status '   Current state:' 'White'
    Show-Diagnosis -Diagnosis $now

    Write-Status ''
    if ($null -eq $baseline) {
        Write-Status '   No previous diagnosis.json found -- checking absolute state only.' 'Yellow'
        Write-Status "   (Run with -Execute first to write a baseline under $BackupRoot.)" 'DarkGray'
    } else {
        Write-Status "   Baseline: $($baseline.Path)" 'DarkGray'
        Write-Status ("   Before: {0} flag(s), {1} package(s), {2} failed update(s)" -f `
            @($baseline.Data.RebootFlag).Count,
            @($baseline.Data.DriverPackage).Count,
            @($baseline.Data.UpdateFailure).Count) 'DarkGray'
        Write-Status ("   After:  {0} flag(s), {1} package(s), {2} failed update(s)" -f `
            $now.RebootFlag.Count,
            $now.DriverPackage.Count,
            $now.UpdateFailure.Count) 'DarkGray'
    }

    Write-Status ''
    Write-Status '   Checks:' 'White'

    if ($now.RebootFlag.Count -eq 0) {
        Write-Status '     PASS  no pending-reboot flags (the shutdown nag is gone)' 'Green'
    } else {
        Write-Status '     FAIL  pending-reboot flags still set:' 'Red'
        foreach ($flag in $now.RebootFlag) { Write-Status "             $flag" 'Red' }
        $failures += 'pending-reboot flags still set'
    }

    if ($now.DriverPackage.Count -eq 0) {
        Write-Status "     PASS  no '$Match' packages left in the driver store" 'Green'
    } elseif ($null -ne $baseline -and $now.DriverPackage.Count -lt @($baseline.Data.DriverPackage).Count) {
        Write-Status ("     WARN  {0} '{1}' package(s) remain (was {2}) -- partial purge" -f `
            $now.DriverPackage.Count, $Match, @($baseline.Data.DriverPackage).Count) 'Yellow'
        $failures += 'driver packages partially removed'
    } else {
        Write-Status "     FAIL  '$Match' packages still present in the driver store" 'Red'
        $failures += 'driver packages still present'
    }

    # A reinstalled printer is expected and fine -- only flag NEW failures.
    $newFailures = $now.UpdateFailure
    if ($null -ne $baseline) {
        $seen = @(@($baseline.Data.UpdateFailure) | ForEach-Object { "$($_.Title)|$($_.Code)" })
        $newFailures = @($now.UpdateFailure | Where-Object { $seen -notcontains "$($_.Title)|$($_.Code)" })
    }
    if (@($newFailures).Count -eq 0) {
        Write-Status '     PASS  no new failed update attempts since the baseline' 'Green'
    } else {
        Write-Status "     FAIL  $(@($newFailures).Count) new failed update attempt(s):" 'Red'
        foreach ($f in $newFailures) { Write-Status "             $($f.Code)  $($f.Title)" 'Red' }
        $failures += 'new failed update attempts'
    }

    return $failures
}

# -- Main ---------------------------------------------------------------------

Write-Status ''
Write-Status '=================================================' 'Cyan'
Write-Status "  Stuck driver update fix  --  vendor: $Vendor" 'Cyan'
Write-Status '=================================================' 'Cyan'

if ($Execute -and $Verify) {
    Write-Status ''
    Write-Status 'ERROR: -Verify is read-only and cannot be combined with -Execute.' 'Red'
    Write-Status 'Run -Execute, reboot, then run -Verify.' 'Yellow'
    exit 1
}

if (-not (Test-Administrator)) {
    Write-Status ''
    Write-Status 'ERROR: this script must run in an elevated PowerShell session.' 'Red'
    Write-Status 'Right-click PowerShell/Terminal > Run as Administrator, then re-run.' 'Yellow'
    exit 1
}

# -- Verify mode: read-only, exits early --------------------------------------

if ($Verify) {
    Write-Status ''
    Write-Status 'MODE: VERIFY -- read-only post-reboot check.' 'Green'
    Write-Phase 'Verifying the fix held'

    $verifyFailures = @(Test-FixResult -Match $Vendor)

    Write-Status ''
    if ($verifyFailures.Count -eq 0) {
        Write-Status '=================================================' 'Green'
        Write-Status '  VERIFIED -- the fix held.' 'Green'
        Write-Status '=================================================' 'Green'
        Write-Status ''
        Write-Status "  Install the driver from $Vendor's own website now." 'White'
        Write-Status ''
        exit 0
    }

    Write-Status '=================================================' 'Red'
    Write-Status '  NOT VERIFIED -- the fix did not fully hold.' 'Red'
    Write-Status '=================================================' 'Red'
    Write-Status ''
    foreach ($f in $verifyFailures) { Write-Status "  - $f" 'Red' }
    Write-Status ''
    Write-Status '  Next steps:' 'White'
    Write-Status '    Flags still set   -> re-run with -Execute -SkipDriverPurge -RepairImage' 'DarkGray'
    Write-Status '    Packages remain   -> re-run with -Execute (check the log for pnputil errors)' 'DarkGray'
    Write-Status '    New failures      -> re-run with -Execute -BlockByHardwareId' 'DarkGray'
    Write-Status ''
    exit 3
}

# -- Fix mode -----------------------------------------------------------------

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
    Write-Phase 'Phase 1/6  Diagnose'

    $diagnosis = Get-Diagnosis -Match $Vendor
    Show-Diagnosis -Diagnosis $diagnosis

    if ($Execute) {
        Write-Status ''
        Save-Diagnosis -Diagnosis $diagnosis -Path (Join-Path $runDir 'diagnosis.json')
    }

    $packages = @($diagnosis.DriverPackage)

    # -- Phase 2 + 3: back up, then purge -------------------------------------
    if ($SkipDriverPurge) {
        Write-Phase 'Phase 2/6  Back up driver packages  [SKIPPED]'
        Write-Phase 'Phase 3/6  Purge driver packages  [SKIPPED]'
    } elseif ($packages.Count -eq 0) {
        Write-Phase 'Phase 2/6  Back up driver packages  [nothing to back up]'
        Write-Phase 'Phase 3/6  Purge driver packages  [nothing to purge]'
    } else {
        Write-Phase 'Phase 2/6  Back up driver packages'
        $driverBackup = Join-Path $runDir 'drivers'
        $backupOk = Export-VendorDriver -Package $packages -Destination $driverBackup
        if (-not $backupOk) {
            Write-Status ''
            Write-Status 'Aborting before any deletion. Backup verification failed.' 'Red'
            exit 2
        }

        Write-Phase 'Phase 3/6  Purge driver packages'
        Remove-VendorDriver -Package $packages -Match $Vendor
    }

    # -- Phase 4: reset update state ------------------------------------------
    if ($SkipUpdateReset) {
        Write-Phase 'Phase 4/6  Reset Windows Update state  [SKIPPED]'
    } else {
        Write-Phase 'Phase 4/6  Reset Windows Update state'
        Write-Status '   The old folders are renamed, not deleted -- Windows rebuilds them.' 'DarkGray'
        Reset-UpdateComponent
    }

    # -- Phase 5: block redelivery --------------------------------------------
    if ($BlockByHardwareId -or $DisableDriverUpdate) {
        Write-Phase 'Phase 5/6  Block the driver being offered again'
        if ($BlockByHardwareId) {
            Disable-DeviceInstall -HardwareId $diagnosis.HardwareId -Destination $runDir
        }
        if ($DisableDriverUpdate) {
            Disable-DriverUpdate -Destination $runDir
        }
    } else {
        Write-Phase 'Phase 5/6  Block the driver being offered again  [SKIPPED]'
        Write-Status '   Re-run with -BlockByHardwareId if the driver comes back.' 'DarkGray'
    }

    # -- Phase 6: repair component store --------------------------------------
    if ($RepairImage) {
        Write-Phase 'Phase 6/6  Repair the component store'
        Invoke-ImageRepair
    } else {
        Write-Phase 'Phase 6/6  Repair the component store  [SKIPPED]'
        Write-Status '   Re-run with -RepairImage if a reboot flag survives.' 'DarkGray'
    }

    # -- Log capture ----------------------------------------------------------
    if ($Execute -and $script:WarningCount -gt 0) {
        Write-Phase "Capturing diagnostics ($script:WarningCount warning(s) raised)"
        Save-UpdateLog -Destination $runDir
    }

    # -- Summary --------------------------------------------------------------
    Write-Status ''
    if ($Execute) {
        Write-Status '=================================================' 'Green'
        Write-Status '  Done. Next steps:' 'Green'
        Write-Status '=================================================' 'Green'
        Write-Status ''
        Write-Status '  1. REBOOT now.' 'White'
        Write-Status '  2. Confirm the fix held:' 'White'
        Write-Status "       .\fix-stuck-driver-update.ps1 -Vendor $Vendor -Verify" 'Cyan'
        Write-Status "  3. Install the driver from $Vendor's own website, not Windows Update." 'White'
        Write-Status ''
        if ($script:WarningCount -gt 0) {
            Write-Status "  $script:WarningCount warning(s) were raised -- review run.log before rebooting." 'Yellow'
            Write-Status ''
        }
        Write-Status "  Backups + log: $runDir" 'Cyan'
        Write-Status '  Restore a driver: pnputil /add-driver <path-to-inf> /install' 'DarkGray'
    } else {
        Write-Status '=================================================' 'Green'
        Write-Status '  Dry run complete. Nothing was changed.' 'Green'
        Write-Status '=================================================' 'Green'
        Write-Status ''
        Write-Status '  Review the plan above, then run:' 'White'
        Write-Status "    .\fix-stuck-driver-update.ps1 -Vendor $Vendor -Execute -BlockByHardwareId" 'Cyan'
    }
    Write-Status ''
} finally {
    if ($transcript) { Stop-Transcript | Out-Null }
}
