# Logic audit — `windows/scripts/fix-stuck-driver-update.ps1`

> Read-only audit against `docs/audit/ps-lint-and-driver-fix/SPEC.md` Change 1 (D1–D11).
> Target: `windows/scripts/fix-stuck-driver-update.ps1` @ `b7cec8d`, branch `main`.
> Toolchain used: PowerShell 7.6.5 (macOS arm64) + PSScriptAnalyzer, for language-semantics
> experiments only. The script itself was never executed — it requires Windows.
> Microsoft Learn was consulted for `Get-WindowsDriver -All` and `DenyDeviceIDs` semantics.

**Headline:** D1 (dry-run purity) holds — verified exhaustively, all 30 mutation-capable
lines are gated. D2's ordering and counting are also sound. The defects are elsewhere:
an unbounded vendor regex on a force-delete path, a `-Verify` that cannot detect the
recurrence it exists to detect, a `DenyDeviceIDs` append that clobbers, and a run log
that captures nothing.

---

## Findings

| # | Sev | Location | What breaks |
|---|-----|----------|-------------|
| F1 | **CRITICAL** | `:89`, `:205`, `:445-459` | `-Vendor` is an unvalidated regex matched against full DriverStore paths, with no match cap, no confirmation, no `ShouldProcess`. `-Vendor ''` force-deletes every driver package on the machine. |
| F2 | **HIGH** | `:204` | `Get-WindowsDriver -Online -All` includes Microsoft inbox drivers (per MS docs). No `oem*.inf` / non-Microsoft guard before `pnputil /delete-driver /force`. |
| F3 | **HIGH** | `:720-732` | `-Verify` dedups new failures by `Title\|Code` with no date. The same driver failing again post-fix — the exact symptom — is filtered out as "already seen" and reported as VERIFIED. |
| F4 | **HIGH** | `:606-613` | `$index = $existing.Count` uses the *count*, not the *max*, of existing `DenyDeviceIDs` names. Non-contiguous entries (1,2,5) cause entry 5 to be overwritten. Violates D7. |
| F5 | **HIGH** | `:106-119`, `:809` | `Write-Status` uses `$Host.UI.WriteLine`, which `Start-Transcript` does **not** capture. `run.log` gets header + footer only. The script twice tells the user to read it. Violates W4. |
| F6 | MEDIUM | `:464-472` | Ghost-device removal never reads `$LASTEXITCODE` and prints success unconditionally. Also raises no warning, so it can't trip the diagnostic-capture path. |
| F7 | MEDIUM | `:812`, `:423` | Main `try` has `finally` but no `catch`. An unguarded `Restart-Service Spooler` failure exits **1** — which D10 defines as "not elevated / bad arguments" — after printers were already removed. |
| F8 | MEDIUM | `:722-725` | With a null baseline, `$newFailures` = *all* historical failures, so `-Verify` reports failure for the very problem it was asked to confirm gone. |
| F9 | MEDIUM | `:178-190` | Only `ResultCode -eq 2` is skipped. `InProgress` (1) and `SucceededWithErrors` (3) count as failures → spurious exit 3. |
| F10 | MEDIUM | `:711-714` | Partial purge prints `WARN` in yellow but appends to `$failures`, producing "NOT VERIFIED" + exit 3. Label and outcome disagree. |
| F11 | MEDIUM | `:87` | `[CmdletBinding()]` without `SupportsShouldProcess`. `-WhatIf` does not exist; the only safety gate is the custom `-Execute`. PSSA flags this but the repo settings file excludes the rule. |
| F12 | LOW | `:321-326` | `Sort-Object Name -Descending` over all subdirs. A non-timestamped directory containing a `diagnosis.json` outranks the real newest run. Does not crash. |
| F13 | LOW | `:516-525` | All five services are unconditionally started afterwards, leaving `msiserver` running when it was stopped before. Disclosed in the dry-run plan. |
| F14 | LOW | `:452-457`, `:887-902` | A run where every `pnputil` delete failed still exits 0 and prints "Done. REBOOT now." No "completed with errors" code exists in D10. |
| F15 | INFO | file header | No `#Requires -Version` / `-RunAsAdministrator`. 5.1-reachable; I grepped for PS6+ constructs and found none, so compat appears intact, but the floor is undeclared. |

---

## Detail

### F1 — CRITICAL — unbounded vendor regex on a force-delete path

`[string]$Vendor = 'Canon'` (`:89`) has no `ValidateNotNullOrEmpty` / `ValidatePattern`.
It flows into `Get-VendorDriverPackage` (`:205`):

```powershell
Where-Object { $_.ProviderName -match $Match -or $_.OriginalFileName -match $Match }
```

and the result is force-deleted at `:449`:

```powershell
$output = & pnputil.exe /delete-driver $pkg.Driver /uninstall /force 2>&1
```

Two independent over-match routes, both confirmed:

1. **Empty or trivial regex.** I ran the filter against a provider list: `-Vendor ''`
   matched 4/4 and `-Vendor '.'` matched 4/4. `''` is the realistic trigger — an unset
   shell variable (`-Vendor $env:PRINTER_VENDOR`) collapses to the empty string, and the
   script accepts it silently, prints `vendor: ` in the banner, and proceeds.
2. **`OriginalFileName` is a full path.** It looks like
   `C:\Windows\System32\DriverStore\FileRepository\...`, so `-Vendor 'system'`,
   `'win'`, `'store'`, or `'repository'` match every package regardless of vendor.

There is no cap on `$packages.Count`, no "about to delete N packages, continue?" prompt,
and no `-WhatIf` (F11). The dry run *would* show the over-match — but the whole point of
a dry-run/execute pair is that people skip the dry run on the second invocation.

**Trigger:** `.\fix-stuck-driver-update.ps1 -Vendor '' -Execute`
**Blast radius:** every third-party *and* inbox driver package, exported first (so
recoverable in principle) but uninstalled from live devices with `/force`.

### F2 — HIGH — `-All` pulls inbox drivers into the delete set

`Get-WindowsDriver -Online -All` (`:204`). Microsoft Learn, `Get-WindowsDriver`, `-All`
parameter, verbatim:

> "Displays information about default drivers. If you do not specify this parameter, only third-party drivers and listed." *(sic — typo is Microsoft's)*

So `-All` deliberately widens the set from out-of-box-only to include Microsoft's default
drivers. Nothing downstream re-narrows it: there is no `$_.Driver -like 'oem*.inf'` filter
and no `$_.ProviderName -ne 'Microsoft'` filter before the delete loop.

For the documented Canon case this mostly does not bite — inbox Canon print INFs are named
`prnca*.inf` with `ProviderName` "Microsoft", so neither field matches `Canon`. It bites
for any vendor whose name *is* the inbox `ProviderName`: `-Vendor 'Intel'`, `'Realtek'`,
`'AMD'`, `'Microsoft'`. Note Phase 6's `sfc /scannow` may then contend with the same
packages the script just deleted.

*Confirmed:* `-All` semantics, from the primary source above.
*Suspected:* that `pnputil /delete-driver` on an inbox package is refused with a non-zero
exit (→ `Write-Warn`) rather than succeeding. Not verifiable without Windows.

### F3 — HIGH — `-Verify` cannot see a recurrence of the original failure

```powershell
$seen = @(@($baseline.Data.UpdateFailure) | ForEach-Object { "$($_.Title)|$($_.Code)" })
$newFailures = @($now.UpdateFailure | Where-Object { $seen -notcontains "$($_.Title)|$($_.Code)" })
```

The dedup key carries no date and no occurrence count. The failure mode this script exists
to fix is "the queued job replays forever" — every replay produces a history entry with the
*identical* Title and the *identical* `0x800f020b`. That is precisely the key that is in
`$seen`.

I ran it: baseline `{2026-08-01, 'Canon - Printer - 2.90.2.30', 0x800f020b}` vs post-reboot
`{2026-09-02, same Title, same Code}` → `newFailures = 0` → `PASS no new failed update
attempts` → exit 0, `VERIFIED -- the fix held.`

SPEC D9 says "only *new* failures relative to the baseline **count**". A count comparison
would have caught this; set membership does not. Suggested key: include `$_.Date`, or
compare per-key occurrence counts rather than presence.

Partial mitigation: the pending-reboot check at `:701` is independent and would usually
still fail. The dangerous case is a flag that cleared while the update keeps failing —
which is exactly the `0x80070103` downgrade-loop scenario the script's own help calls out
at `:281-284`.

### F4 — HIGH — `DenyDeviceIDs` append overwrites existing entries (D7)

The *enumeration* is correct — I verified `PSObject.Properties` filtered by `^\d+$`
properly skips `PSPath`/`PSParentPath`/`PSChildName`/`PSDrive`/`PSProvider` and returns
only the numbered values. The *index* is wrong:

```powershell
$index = $existing.Count        # :606  -- count, not max
foreach ($id in $HardwareId) { ...; $index++; Set-ItemProperty -Path $denyKey -Name "$index" ... }
```

Simulated with existing entries `{1, 2, 5}` and two new hardware IDs:

```
existing values found: ...PID_1111, ...PID_2222, ...PID_5555  (count=3)
  would Set-ItemProperty -Name '4' -Value ...PID_AAAA
  would Set-ItemProperty -Name '5' -Value ...PID_BBBB
  *** CLOBBERS existing entry 5 which held ...PID_5555
```

MS Learn's `PreventInstallationOfMatchingDeviceIDs` confirms the list is a set of numbered
value names under `Software\Policies\Microsoft\Windows\DeviceInstall\Restrictions\DenyDeviceIDs`
(their example: `1`→`USB\Composite`, `2`→`USB\Class_FF`). Whether contiguity is *required*
is not stated — but that is beside the point: writing name `5` over an existing name `5`
destroys a block the user previously configured, silently, and prints `denied <new id>` in
green. D7 says "never clobbers entries it did not create."

**Triggers:** a `Remove-ItemProperty` of one entry between runs; a prior partially-completed
run; entries seeded by another tool or by GPO with a different numbering base.
**Fix:** `$index = ($names | Measure-Object -Maximum).Maximum` over the numeric *names*,
and skip any name already present.

### F5 — HIGH — `run.log` captures nothing (W4)

`Write-Status` writes via `$Host.UI.WriteLine`. Under `Start-Transcript` on pwsh 7.6.5 I
compared three writers in one transcript:

| writer | in transcript? |
|---|---|
| `Write-Host` (plain and `-ForegroundColor`) | yes |
| `Write-Warning` | yes |
| `$Host.UI.WriteLine(...)` | **no** |

Identical result piped and unpiped. So the `run.log` created at `:808-809` contains the
`PowerShell transcript start` header, the `end` footer, and nothing else — no diagnosis, no
"deleted oem12.inf", no pnputil warnings. Meanwhile the script directs the user to it twice:

- `:786` — "Packages remain -> re-run with -Execute (check the log for pnputil errors)"
- `:898` — "N warning(s) were raised -- review run.log before rebooting."

For a script whose only record of what it destroyed is that file, this is the finding with
the worst recovery consequences after F1.

This is a **regression from Change 2** (the repo-wide `Write-Host` → `Write-Status`
conversion), not from Change 1 — but it lands hardest here. It also means W4 as written in
the SPEC is currently false.

*Confirmed:* on PowerShell 7.6.5 / macOS.
*Suspected / must be checked on Windows:* Windows PowerShell 5.1 implements transcription
differently inside `ConsoleHost` and may capture host writes. The script has no `#Requires`,
so both hosts are reachable and both need checking before this is called fixed.

### F6 — MEDIUM — ghost removal always claims success

```powershell
& pnputil.exe /remove-device $ghost.InstanceId 2>&1 | Out-Null
$ErrorActionPreference = 'Stop'
Write-Status "      removed $($ghost.FriendlyName)" 'Green'
```

Compare the driver-package loop 20 lines above, which does read `$LASTEXITCODE` and
downgrades to `Write-Warn` on failure. Here nothing is checked. Because no warning is
raised, `$script:WarningCount` stays put, so the failure also fails to trigger the
`Save-UpdateLog` diagnostic capture at `:880-883`.

### F7 — MEDIUM — exit-code collision on unexpected failures

`$ErrorActionPreference = 'Stop'` is script-scope. The main `try` at `:812` has a `finally`
(Stop-Transcript) but **no `catch`**. I confirmed the behaviour: an uncaught terminating
error inside `try{}finally{}` runs the `finally`, then the script exits **1**.

D10 assigns 1 to "not elevated / bad arguments". So an operator seeing exit 1 will re-launch
elevated rather than investigate. The most likely source is `:423`:

```powershell
if ($drivers.Count -gt 0) {
    Write-Plan 'restart the print spooler to release driver locks'
    if ($Execute) { Restart-Service -Name Spooler -Force }   # not in try/catch
}
```

Every other service operation in the script *is* wrapped (`:495`, `:508`, `:520`). This one
is not, and it runs *after* `Remove-Printer` has already deleted the user's print queues —
so the failure leaves a partially-purged machine behind a misleading exit code.

### F8 / F9 / F10 — `-Verify` correctness around the edges

- **F8, null baseline.** `:683-685` explicitly handles "No previous diagnosis.json found --
  checking absolute state only", but `:722` then does `$newFailures = $now.UpdateFailure`
  and applies the relative check anyway. Every historical vendor failure counts as new →
  exit 3. Triggered by verifying without a prior `-Execute`, with a different `-BackupRoot`,
  or after the backup dir was cleaned. *Suspected mitigation:* Phase 4's
  `SoftwareDistribution` rename should discard update history (the DataStore lives there),
  which would mask this — but with `-SkipUpdateReset` the history survives and the false
  FAIL is deterministic. I did not verify the history-location claim from a primary source.
- **F9.** `:179` skips only `ResultCode -eq 2`. Codes 1 (InProgress) and 3
  (SucceededWithErrors) are recorded as failures and feed `$newFailures`. A verify run that
  happens to catch an unrelated matching update mid-install reports NOT VERIFIED.
- **F10.** `:712` prints `WARN ... partial purge` in yellow, then `:714` appends to
  `$failures` — so the run exits 3 and prints "NOT VERIFIED -- the fix did not fully hold"
  in red. If a partial purge is meant to be a failure, the label should say FAIL.

### F12 — LOW — baseline selection can pick a non-run directory

`Get-ChildItem -Directory | Sort-Object Name -Descending` over `$BackupRoot`. Confirmed:
`'zz-old-manual-backup'` sorts above `'20260902-120000'`. The pipeline does **not** crash on
unrelated directories — `Where-Object { Test-Path $_ }` drops any without a `diagnosis.json`
— but any stray directory that *does* contain one (a restored copy, a user's own archive
folder) silently becomes the baseline for every subsequent `-Verify`.
Fix: `Where-Object { $_.Name -match '^\d{8}-\d{6}$' }` before sorting.

---

## What I checked and found correct

Stated explicitly so the fix loop does not churn on these.

- **D1 holds.** I enumerated every mutation-capable line in the file (30 of them:
  `New-Item`, `Set-Content`, `Set-ItemProperty`, `Rename-Item`, `Stop`/`Start`/`Restart-Service`,
  `Remove-Printer`, `Remove-PrinterDriver`, `Start-Transcript`, `reg.exe`, all 3 `pnputil`
  invocations, `dism.exe`, `sfc.exe`, `Get-WindowsUpdateLog`) and traced each to its gate.
  Every one sits behind an `if ($Execute)` or an early `if (-not $Execute) { return }`:
  `:313`→gated at `:819`; `:352-361`→`:347`; `:403`,`:423`,`:430/435`,`:449`,`:468`→inline
  `if ($Execute)`; `:495/508/520`→`:489`; `:540-554`→`:538`; `:581-613`→`:579`;
  `:632/642`→`:627`; `:658`→`:880`; `:807/809`→`:806`. **No dry-run leakage found.**
  Specifically clearing the items called out in the brief: `Restart-Service Spooler` (`:423`)
  is gated; no `New-Item` is reachable without `-Execute`; `Start-Transcript` is gated;
  no `Set-ItemProperty` or `reg.exe` is reachable; no `pnputil` invocation is reachable.
- **D2 ordering holds.** Phase 2 (`:836`) strictly precedes Phase 3 (`:844`), and a false
  return trips `exit 2` at `:840` before `Remove-VendorDriver` is ever called. Nothing can
  delete ahead of the export.
- **D2 counting is sound — no scalar/array bug.** `[object[]]$Package = @()` coerces its
  argument, so `.Count` is 1 for a single bare object, 1 for a 1-element array, 0 for
  absent — all three verified. `$files.Count` at `:365` is likewise safe (scalars expose
  `.Count` = 1 in PS 3+, and `$files -and ...` short-circuits on `$null`).
- **The abort path really aborts.** Verified `exit 2` inside `try{}` runs the
  `finally{ Stop-Transcript }` and then exits with code 2 — finally-before-exit, code
  preserved. `Export-VendorDriver` returning `$true` in dry run (`:350`) is correct, since
  every delete is independently gated; it does mean D2's guard is never exercised by a dry run.
- **D3 and D4 both fire before any other work**, and D4 (`:744`) precedes D3 (`:751`).
- **D5 holds** — `Rename-Item` only; no `Remove-Item` touches either folder.
- **D6 holds** — `reg.exe export` (`:542`, `:583`) precedes every `Set-ItemProperty`
  (`:551`, `:594-595`, `:613`) in both policy functions.
- **D11 holds** — parsed the help: 9 parameters, 4 examples, no shebang.
- **`$ErrorActionPreference` juggling is correct everywhere.** I verified the scoping
  empirically: assigning inside a function creates a function-local copy that child
  functions inherit and that is discarded on return. All 7 external-command sites set
  `'Continue'` before and `'Stop'` after; because the assignment is function-local there is
  no mechanism by which `'Continue'` could leak to script scope (confirmed: script scope
  read `Stop` after a function set it to `Continue`). **I found no path leaving it on
  `'Continue'`.** The pattern is also load-bearing, not decorative — it is what stops
  `2>&1` native stderr from being promoted to a terminating error under 5.1.
- **`$LASTEXITCODE` is read correctly.** All three sites that read it do so on the very
  next line with no interleaved command: `:449→450`, `:632→633`, `:642→643`. The four sites
  that don't read it substitute a `Test-Path`/file-presence check, which is defensible —
  except `:468`, which checks nothing (F6).
- **`Test-FixResult`'s return contract is correct** despite array unrolling. Verified a
  1-element `$failures` returns as a bare `String` and an empty one returns `$null` — but
  the caller wraps it, `@(Test-FixResult -Match $Vendor)` at `:765`, so `.Count -eq 0` is
  right for 0, 1 and N. No pipeline pollution either: `Write-Status`/`Show-Diagnosis` write
  to the host, not the success stream, so they cannot contaminate the return value. (This
  is a place where the `Write-Host`→`Write-Status` conversion happens to be load-bearing.)
- **`$Diagnosis.UpdateFailure.Code -contains '0x800f020b'`** (`:278`, `:281`) works with a
  single-element array — verified `-contains` against a scalar left operand compares by
  equality (`True` on match, `False` otherwise).
- **`"$script:WarningCount"`** expands correctly inside double-quoted strings (`:881`,
  `:898`) — verified.
- **`$drivers.Count -gt 0`** (`:421`) is safe for 0/1/N: `$null.Count` → 0, scalar → 1.
- **`Write-Status`'s `-1` handling works.** Confirmed `$Host.UI.RawUI.BackgroundColor`
  is `-1` under a non-console host and `WriteLine(fg, -1, msg)` does not throw.
- **`Get-LastDiagnosis` does not crash** on unrelated directories (F12 is mis-selection,
  not an exception).
- **Phase 5 reads `$diagnosis.HardwareId` from the pre-purge snapshot**, which is correct —
  after the purge the devices are gone and the IDs would be unavailable.
- **No use-before-assignment, no unreachable code**, and no off-by-one other than F4.
- **PSScriptAnalyzer** with the repo settings file: clean. Without it: only
  `PSUseShouldProcessForStateChangingFunctions` at `:383` and `:475` (see F11).
- **5.1 compatibility appears intact** — grepped for `??`, `&&`, `||`, `?.`, ternary,
  `::new()`, `-Parallel`, `-AdditionalChildPath`; none present.

---

## Confirmed vs Suspected

**CONFIRMED — read from the code, and where noted reproduced in `pwsh` 7.6.5 or quoted from
Microsoft Learn:**

- F1 — regex over-match reproduced (`''` and `'.'` each matched 4/4 providers); absence of
  validation, cap, confirmation and `ShouldProcess` read directly from the source.
- F2 — `-All` includes default drivers: quoted verbatim from MS Learn `Get-WindowsDriver`.
  Absence of a downstream `oem*.inf` / non-Microsoft filter read from the source.
- F3 — dedup false-negative reproduced end to end; identical Title+Code yields
  `newFailures = 0` → PASS.
- F4 — clobber reproduced with existing `{1,2,5}`; overwrite of entry 5 demonstrated.
  Numbered-value-name scheme corroborated by MS Learn `PreventInstallationOfMatchingDeviceIDs`.
- F5 — `$Host.UI.WriteLine` absent from `Start-Transcript` output while `Write-Host` and
  `Write-Warning` are present; reproduced piped and unpiped. **On pwsh 7 only.**
- F6, F10, F11, F13, F14, F15 — read directly from the source; F11 corroborated by PSSA,
  F15 by grep.
- F7 — uncaught terminating error in `try{}finally{}` exits 1 with the finally run:
  reproduced. The `Restart-Service Spooler` call being unguarded: read from the source.
- F9, F12 — read from the source; F12's sort order reproduced.
- All items in "What I checked and found correct", including the full D1 gate enumeration.

**SUSPECTED — needs a Windows machine or a further primary source:**

- **F5 on Windows PowerShell 5.1** (and on pwsh 7 *on Windows*). 5.1's `ConsoleHost`
  transcription differs and may capture host writes. This changes F5 from HIGH to
  cosmetic if 5.1 captures. **Highest-value single check to run.**
- **F2's runtime consequence** — whether `pnputil /delete-driver` against an inbox package
  is refused (non-zero exit → `Write-Warn`) or succeeds. The selection bug is confirmed;
  the damage is not.
- **F8's mitigation** — that Phase 4's `SoftwareDistribution` rename discards update
  history. Asserted from general knowledge, *not* verified from a primary source. If false,
  F8 is worse than rated.
- `Get-PnpDeviceProperty -KeyName 'DEVPKEY_Device_HardwareIds'` returning `.Data` as a
  string array (`:235-237`) — assumed, not verified.
- Every Windows-only cmdlet's failure mode (`Get-WindowsDriver`, `Get-PnpDevice`,
  `Get-Printer`, `Get-PrinterDriver`, `Get-WindowsUpdateLog`) under the specific hosts and
  builds the user will run. Per SPEC, ASSUMED not VERIFIED.

**Recommended order of fixes:** F1 (validate `-Vendor`, cap the match, require confirmation
above N packages) → F4 (max-not-count) → F3 (date in the dedup key) → F5 (verify on Windows
first, then decide) → F2 (filter to `oem*.inf`) → F7 (`catch` + a distinct exit code).
